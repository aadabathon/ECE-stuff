`timescale 1ns/1ps

module inert_intf_tb;

  localparam logic [15:0] CMD_CFG_INT  = 16'h0D02;
  localparam logic [15:0] CMD_CFG_GYRO = 16'h1160;
  localparam logic [15:0] CMD_CFG_WRAP = 16'h1440;
  localparam logic [15:0] CMD_RD_YAWL  = 16'hA600;
  localparam logic [15:0] CMD_RD_YAWH  = 16'hA700;

  localparam int MAX_WAIT_INIT = 80000;
  localparam int MAX_WAIT_CMD  = 2000;
  localparam int MAX_WAIT_RDY  = 3000;
  localparam int MAX_WAIT_CAL  = 200000;

  logic clk;
  logic rst_n;
  logic strt_cal;
  logic signed [8:0] IR_Dtrm;
  logic MISO;
  logic INT;
  logic moving;
  logic en_fusion;

  logic cal_done;
  logic signed [11:0] heading;
  logic rdy;
  logic SS_n;
  logic SCLK;
  logic MOSI;

  int sample_count;

  inert_intf dut (
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

  initial clk = 1'b0;
  always #5 clk = ~clk;

  always @(posedge clk) begin
    if (rdy) begin
      sample_count <= sample_count + 1;
      $display("[%0t] INFO: rdy pulse seen, heading=%0d, sample_count=%0d",
               $time, heading, sample_count + 1);
    end
    if (cal_done) begin
      $display("[%0t] INFO: cal_done asserted", $time);
    end
  end

  task automatic expect(input bit cond, input string msg);
    if (!cond) begin
      $error("[%0t] FAIL: %s", $time, msg);
      $fatal;
    end
    else begin
      $display("[%0t] PASS: %s", $time, msg);
    end
  endtask

  task automatic wait_for_wrt_and_check
  (
    input logic [15:0] expected_cmd,
    input int max_cycles,
    input string msg
  );
    int i;
    bit seen;
    logic [15:0] observed_cmd;

    seen = 1'b0;
    observed_cmd = 16'h0000;

    for (i = 0; i < max_cycles; i++) begin
      @(posedge clk);
      if (dut.iSPI.wrt) begin
        seen = 1'b1;
        observed_cmd = dut.iSPI.wt_data;
        $display("[%0t] INFO: SPI wrt seen, cmd=0x%04h", $time, observed_cmd);
        break;
      end
    end

    expect(seen, msg);
    expect(observed_cmd == expected_cmd,
           $sformatf("%s (expected 0x%04h, got 0x%04h)", msg, expected_cmd, observed_cmd));
  endtask

  task automatic wait_for_done_and_check(input int max_cycles, input string msg);
    int i;
    bit seen_done;

    seen_done = 1'b0;

    for (i = 0; i < max_cycles; i++) begin
      @(posedge clk);
      if (dut.iSPI.done) begin
        seen_done = 1'b1;
        break;
      end
    end

    expect(seen_done, msg);
    expect(SS_n == 1'b1, "SS_n returned high after SPI transaction");
  endtask

  task automatic check_spi_transaction
  (
    input logic [15:0] expected_cmd,
    input int max_wrt_cycles,
    input int max_done_cycles,
    input string name
  );
    wait_for_wrt_and_check(expected_cmd, max_wrt_cycles,
                           {name, ": saw SPI launch"});
    wait_for_done_and_check(max_done_cycles,
                            {name, ": saw SPI done"});
  endtask

  task automatic assert_no_wrt_for_cycles(input int ncycles, input string msg);
    int i;
    bit saw_wrt;

    saw_wrt = 1'b0;

    for (i = 0; i < ncycles; i++) begin
      @(posedge clk);
      if (dut.iSPI.wrt)
        saw_wrt = 1'b1;
    end

    expect(!saw_wrt, msg);
  endtask

  task automatic pulse_INT;
    begin
      @(negedge clk);
      INT = 1'b1;
      @(negedge clk);
      INT = 1'b0;
      $display("[%0t] INFO: INT pulse driven", $time);
    end
  endtask

  task automatic wait_for_rdy(input int max_cycles, input string msg);
    int i;
    bit seen_rdy;

    seen_rdy = 1'b0;

    for (i = 0; i < max_cycles; i++) begin
      @(posedge clk);
      if (rdy) begin
        seen_rdy = 1'b1;
        break;
      end
    end

    expect(seen_rdy, msg);
    expect(!$isunknown(heading), "heading is not X when rdy asserts");
  endtask

  task automatic do_one_sample(input string tag);
    begin
      pulse_INT();
      check_spi_transaction(CMD_RD_YAWL, MAX_WAIT_CMD, MAX_WAIT_CMD,
                            {tag, ": yaw low read"});
      check_spi_transaction(CMD_RD_YAWH, MAX_WAIT_CMD, MAX_WAIT_CMD,
                            {tag, ": yaw high read"});
      wait_for_rdy(MAX_WAIT_RDY, {tag, ": rdy asserted after read pair"});
    end
  endtask

  task automatic wait_for_cal_done(input int max_cycles, input string msg);
    int i;
    bit seen_cal;

    seen_cal = 1'b0;

    for (i = 0; i < max_cycles; i++) begin
      @(posedge clk);
      if (cal_done) begin
        seen_cal = 1'b1;
        break;
      end
    end

    expect(seen_cal, msg);
  endtask

  initial begin
    sample_count = 0;

    rst_n     = 1'b0;
    strt_cal  = 1'b0;
    IR_Dtrm   = 9'sd0;
    MISO      = 1'b0;
    INT       = 1'b0;
    moving    = 1'b0;
    en_fusion = 1'b0;

    $display("==============================================");
    $display("Starting inert_intf self-checking TB");
    $display("==============================================");

    repeat (5) @(posedge clk);
    rst_n = 1'b1;
    $display("[%0t] INFO: reset released", $time);

    check_spi_transaction(CMD_CFG_INT,  MAX_WAIT_INIT, MAX_WAIT_CMD,
                          "Init transaction 1");
    check_spi_transaction(CMD_CFG_GYRO, MAX_WAIT_CMD,  MAX_WAIT_CMD,
                          "Init transaction 2");
    check_spi_transaction(CMD_CFG_WRAP, MAX_WAIT_CMD,  MAX_WAIT_CMD,
                          "Init transaction 3");

    assert_no_wrt_for_cycles(50,
      "DUT remains idle after init while waiting for INT");

    do_one_sample("Sample 1");
    assert_no_wrt_for_cycles(20,
      "DUT returns to idle after servicing one INT");

    do_one_sample("Sample 2");

    strt_cal = 1'b1;
    @(posedge clk);
    strt_cal = 1'b0;
    $display("[%0t] INFO: strt_cal pulsed", $time);

    repeat (20) begin
      do_one_sample("Calibration sample");
      if (cal_done)
        break;
    end

    wait_for_cal_done(MAX_WAIT_CAL,
      "cal_done eventually asserts after repeated valid samples");

    $display("==============================================");
    $display("TB COMPLETE");
    $display("Final heading      = %0d", heading);
    $display("Total rdy pulses   = %0d", sample_count);
    $display("==============================================");

    $stop;
  end

endmodule