module CommTB;

  logic        clk;
  logic        rst_n;

  // Cross-coupled UART wires
  logic        TX_RX;          // RemoteComm TX -> UART_wrapper RX
  logic        RX_TX;          // UART_wrapper TX -> RemoteComm RX

  // RemoteComm-side stimulus / observe
  logic [15:0] tb_cmd;
  logic        snd_cmd;
  logic        cmd_snt;
  logic [7:0]  resp;
  logic        resp_rdy;

  // UART_wrapper-side stimulus / observe
  logic [7:0]  tb_resp;
  logic        trmt;
  logic        clr_cmd_rdy;
  logic [15:0] dut_cmd;
  logic        cmd_rdy;
  logic        tx_done;

  localparam int TIMEOUT_CYCLES = 150000;

  RemoteComm iRC (
    .clk(clk),
    .rst_n(rst_n),
    .RX(RX_TX),
    .cmd(tb_cmd),
    .snd_cmd(snd_cmd),
    .TX(TX_RX),
    .cmd_snt(cmd_snt),
    .resp(resp),
    .resp_rdy(resp_rdy)
  );

  UART_wrapper iDUT (
    .clk(clk),
    .rst_n(rst_n),
    .RX(TX_RX),
    .clr_cmd_rdy(clr_cmd_rdy),
    .trmt(trmt),
    .resp(tb_resp),
    .TX(RX_TX),
    .cmd_rdy(cmd_rdy),
    .tx_done(tx_done),
    .cmd(dut_cmd)
  );

  // 50 MHz clock -> 20 ns period
  always #10 clk = ~clk;

  task automatic reset_dut;
    begin
      clk         = 1'b0;
      rst_n       = 1'b0;
      tb_cmd      = 16'h0000;
      snd_cmd     = 1'b0;
      tb_resp     = 8'h00;
      trmt        = 1'b0;
      clr_cmd_rdy = 1'b0;

      repeat (5) @(posedge clk);
      rst_n = 1'b1;
      repeat (5) @(posedge clk);
    end
  endtask

  task automatic pulse_snd_cmd(input logic [15:0] cmd_in);
    begin
      tb_cmd  = cmd_in;
      snd_cmd = 1'b1;
      @(posedge clk);
      snd_cmd = 1'b0;
    end
  endtask

  task automatic pulse_trmt(input logic [7:0] resp_in);
    begin
      tb_resp = resp_in;
      trmt    = 1'b1;
      @(posedge clk);
      trmt    = 1'b0;
    end
  endtask

  task automatic pulse_clr_cmd_rdy;
    begin
      clr_cmd_rdy = 1'b1;
      @(posedge clk);
      clr_cmd_rdy = 1'b0;
    end
  endtask

  task automatic wait_for_cmd_rdy;
    int i;
    begin
      for (i = 0; i < TIMEOUT_CYCLES; i++) begin
        @(posedge clk);
        if (cmd_rdy) return;
      end
      $error("TIMEOUT: cmd_rdy never asserted");
      $fatal;
    end
  endtask

  task automatic wait_for_cmd_snt;
    int i;
    begin
      for (i = 0; i < TIMEOUT_CYCLES; i++) begin
        @(posedge clk);
        if (cmd_snt) return;
      end
      $error("TIMEOUT: cmd_snt never asserted");
      $fatal;
    end
  endtask

task automatic wait_for_new_resp_rdy;
  int i;
  begin
    // If previous response is still marked ready, wait for the new
    // incoming start bit to knock resp_rdy low first.
    if (resp_rdy) begin
      for (i = 0; i < TIMEOUT_CYCLES; i++) begin
        @(posedge clk);
        if (!resp_rdy) break;
      end
      if (resp_rdy) begin
        $error("TIMEOUT: resp_rdy never deasserted before next response");
        $fatal;
      end
    end

    // Now wait for the fresh response to arrive
    for (i = 0; i < TIMEOUT_CYCLES; i++) begin
      @(posedge clk);
      if (resp_rdy) return;
    end
    $error("TIMEOUT: new resp_rdy never asserted");
    $fatal;
  end
endtask

  task automatic expect_equal_16(
    input logic [15:0] got,
    input logic [15:0] exp,
    input string msg
  );
    begin
      if (got !== exp) begin
        $error("FAIL: %s Expected %h, got %h", msg, exp, got);
        $fatal;
      end
    end
  endtask

  task automatic expect_equal_8(
    input logic [7:0] got,
    input logic [7:0] exp,
    input string msg
  );
    begin
      if (got !== exp) begin
        $error("FAIL: %s Expected %h, got %h", msg, exp, got);
        $fatal;
      end
    end
  endtask

  task automatic expect_equal_1(
    input logic got,
    input logic exp,
    input string msg
  );
    begin
      if (got !== exp) begin
        $error("FAIL: %s Expected %b, got %b", msg, exp, got);
        $fatal;
      end
    end
  endtask

  // End-to-end transaction:
  // 1) RemoteComm sends 16-bit command
  // 2) UART_wrapper reconstructs it
  // 3) testbench verifies cmd and handshakes
  // 4) UART_wrapper sends 8-bit response
  // 5) RemoteComm receives response
  task automatic run_transaction(
    input logic [15:0] cmd_in,
    input logic [7:0]  resp_in
  );
    begin
      $display("INFO: Starting transaction cmd=%h resp=%h", cmd_in, resp_in);

      // Start command transmission from RemoteComm
      pulse_snd_cmd(cmd_in);

      // cmd_snt should clear when a new snd_cmd begins
      @(posedge clk);
      expect_equal_1(cmd_snt, 1'b0, "cmd_snt should clear after snd_cmd");

      // Wrapper should eventually reconstruct full command
      wait_for_cmd_rdy();
      expect_equal_16(dut_cmd, cmd_in, "UART_wrapper reconstructed wrong 16-bit command");

      // Once full command is sent on RemoteComm side, cmd_snt should assert
      wait_for_cmd_snt();
      expect_equal_1(cmd_snt, 1'b1, "cmd_snt should assert after both bytes transmit");

      // cmd_rdy should stay high until explicitly cleared
      repeat (5) @(posedge clk);
      expect_equal_1(cmd_rdy, 1'b1, "cmd_rdy should remain high until clr_cmd_rdy");

      // Clear wrapper ready flag and make sure it drops
      pulse_clr_cmd_rdy();
      @(posedge clk);
      expect_equal_1(cmd_rdy, 1'b0, "cmd_rdy did not clear after clr_cmd_rdy");

      // Send response byte back through wrapper TX path
      pulse_trmt(resp_in);

      // Wait for RemoteComm to receive response
      wait_for_new_resp_rdy();
      expect_equal_8(resp, resp_in, "RemoteComm received wrong response byte");

      $display("INFO: Transaction passed cmd=%h resp=%h", cmd_in, resp_in);
    end
  endtask

  initial begin
    reset_dut();

    // Basic reset sanity
    expect_equal_1(cmd_rdy, 1'b0, "cmd_rdy should be low after reset");
    expect_equal_1(cmd_snt, 1'b0, "cmd_snt should be low after reset");
    expect_equal_16(dut_cmd, 16'h0000, "cmd should reset to 0");

    // Transaction 1: mixed hex pattern
    run_transaction(16'hABCD, 8'h5A);

    // Transaction 2: asymmetric bytes to catch swapped order bugs
    run_transaction(16'h1234, 8'hC3);

    // Transaction 3: edge-ish byte pattern
    run_transaction(16'h00FF, 8'h81);

    $display("PASS: All CommTB end-to-end checks succeeded.");
    $finish;
  end

endmodule