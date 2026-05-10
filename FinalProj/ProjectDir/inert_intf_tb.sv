module inert_intf_tb();

  // --------------------------------------------------------
  // Signal Declarations
  // --------------------------------------------------------
  logic clk;
  logic rst_n;
  logic strt_cal;
  logic moving;
  logic en_fusion;
  logic [8:0] IR_Dtrm;

  logic MISO;
  logic INT;

  logic cal_done;
  logic signed [11:0] heading;
  logic rdy;
  logic SS_n;
  logic SCLK;
  logic MOSI;

  // --------------------------------------------------------
  // Clock Generation (50MHz -> 20ns period)
  // --------------------------------------------------------
  initial begin
    clk = 0;
    forever #10 clk = ~clk; // Toggle every 10ns for 20ns period
  end

  // --------------------------------------------------------
  // DUT Instantiation
  // --------------------------------------------------------
  inert_intf #(
    .FAST_SIM(1) // Speed up calibration for simulation
  ) iDUT (
    .clk(clk),
    .rst_n(rst_n),
    .strt_cal(strt_cal),
    .cal_done(cal_done),
    .heading(heading),
    .rdy(rdy),
    .IR_Dtrm(IR_Dtrm),
    .SS_n(SS_n),
    .SCLK(SCLK),
    .MOSI(MOSI),
    .MISO(MISO),
    .INT(INT),
    .moving(moving),
    .en_fusion(en_fusion)
  );

  // --------------------------------------------------------
  // iNEMO Sensor Model Instantiation
  // --------------------------------------------------------
  SPI_iNEMO2 iNEMO (
    .SS_n(SS_n),
    .SCLK(SCLK),
    .MISO(MISO),
    .MOSI(MOSI),
    .INT(INT)
  );

  // --------------------------------------------------------
  // Test Sequence
  // --------------------------------------------------------
  initial begin

    // 1. Reset the DUT 
    @(negedge clk);
    rst_n = 0;
    @(negedge clk);
    rst_n = 1;
    moving = 1; // Assume the system is moving for valid readings
    en_fusion = 1; // Enable sensor fusion for testing
      IR_Dtrm = 9'h000;
    strt_cal = 0;
      // Wait a few cycles for the system to stabilize after rese
    // 2. Wait for NEMO_setup inside SPI_iNEMO2 to get asserted
    // Using fork/join_any for timeout protection
    //Write a command to into the nemo to initiate setup
    
    $display("Waiting for NEMO_setup to assert...");
    fork
      begin
        wait(iNEMO.NEMO_setup == 1'b1);
        $display("SUCCESS: NEMO_setup asserted.");
      end
      begin
        repeat(500000) @(posedge clk);
        $display("ERROR: Timed out waiting for NEMO_setup.");
        $stop;
      end
    join_any
    disable fork; // Kill the timeout thread if wait succeeds

    // 3. Assert strt_cal for 1 clk cycle
    @(posedge clk);
    strt_cal = 1;
    @(posedge clk);
    strt_cal = 0;

    // 4. Wait for cal_done to be asserted
    $display("Waiting for calibration to complete...");
    fork
      begin
        @(posedge cal_done);
        $display("SUCCESS: Calibration finished.");
      end
      begin
        // Timeout loop (~1 million cycles) 
        repeat(1000000) @(posedge clk); 
        $display("ERROR: Timed out waiting for cal_done.");
        $stop;
      end
    join_any
    disable fork; // Kill the timeout thread if wait succeeds

    // 5. Let it run for 8 million more cycles and plot the results
    $display("Running simulation to collect heading data...");
    repeat(8000000) @(posedge clk);

    $display("Simulation complete");
    $stop;
  end

endmodule