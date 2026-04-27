module CommTB;

  // ---------------------------------------------------------------------------
  // Testbench signals
  // ---------------------------------------------------------------------------
  logic        clk;
  logic        rst_n;

  // Cross-connected UART serial lines:
  // TX_RX = RemoteComm TX feeding UART_wrapper RX
  // RX_TX = UART_wrapper TX feeding RemoteComm RX
  logic        TX_RX;
  logic        RX_TX;

  // Inputs to RemoteComm
  logic [15:0] tb_cmd;
  logic        snd_cmd;

  // Outputs from RemoteComm
  logic        cmd_snt;
  logic [7:0]  resp;
  logic        resp_rdy;

  // Inputs to UART_wrapper
  logic [7:0]  tb_resp;
  logic        trmt;
  logic        clr_cmd_rdy;

  // Outputs from UART_wrapper
  logic [15:0] dut_cmd;
  logic        cmd_rdy;
  logic        tx_done;

  // Timeout limit for polling/wait tasks so simulation does not hang forever
  localparam int TIMEOUT_CYCLES = 150000;

  // ---------------------------------------------------------------------------
  // Instantiate RemoteComm
  // Sends a 16-bit command as two UART bytes and receives 1-byte response
  // ---------------------------------------------------------------------------
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

  // ---------------------------------------------------------------------------
  // Instantiate UART_wrapper
  // Receives two UART bytes, reconstructs 16-bit command, and transmits response
  // ---------------------------------------------------------------------------
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

  // 50 MHz clock: 20 ns period
  always #10 clk = ~clk;

  // ---------------------------------------------------------------------------
  // Reset task
  // Initializes all TB-driven signals, holds reset low, then releases reset
  // ---------------------------------------------------------------------------
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

  // ---------------------------------------------------------------------------
  // Pulse snd_cmd for one clock to tell RemoteComm to begin sending tb_cmd
  // ---------------------------------------------------------------------------
  task automatic pulse_snd_cmd(input logic [15:0] cmd_in);
    begin
      tb_cmd  = cmd_in;
      snd_cmd = 1'b1;
      @(posedge clk);
      snd_cmd = 1'b0;
    end
  endtask

  // ---------------------------------------------------------------------------
  // Pulse trmt for one clock to tell UART_wrapper to transmit tb_resp
  // ---------------------------------------------------------------------------
  task automatic pulse_trmt(input logic [7:0] resp_in);
    begin
      tb_resp = resp_in;
      trmt    = 1'b1;
      @(posedge clk);
      trmt    = 1'b0;
    end
  endtask

  // ---------------------------------------------------------------------------
  // Pulse clr_cmd_rdy for one clock to clear UART_wrapper's command-ready flag
  // ---------------------------------------------------------------------------
  task automatic pulse_clr_cmd_rdy;
    begin
      clr_cmd_rdy = 1'b1;
      @(posedge clk);
      clr_cmd_rdy = 1'b0;
    end
  endtask

  // ---------------------------------------------------------------------------
  // Wait until UART_wrapper asserts cmd_rdy
  // Fatal error if it never happens within TIMEOUT_CYCLES
  // ---------------------------------------------------------------------------
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

  // ---------------------------------------------------------------------------
  // Wait until RemoteComm asserts cmd_snt
  // Indicates both command bytes have been transmitted
  // ---------------------------------------------------------------------------
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

  // ---------------------------------------------------------------------------
  // Wait until UART_wrapper asserts tx_done after response transmission
  // ---------------------------------------------------------------------------
  task automatic wait_for_tx_done;
    int i;
    begin
      for (i = 0; i < TIMEOUT_CYCLES; i++) begin
        @(posedge clk);
        if (tx_done) return;
      end
      $error("TIMEOUT: tx_done never asserted");
      $fatal;
    end
  endtask

  // ---------------------------------------------------------------------------
  // Wait until RemoteComm indicates a response byte has been received
  // Note: this checks for assertion only; it does not require resp_rdy to pulse
  // ---------------------------------------------------------------------------
  task automatic wait_for_resp_rdy;
    int i;
    begin
      for (i = 0; i < TIMEOUT_CYCLES; i++) begin
        @(posedge clk);
        if (resp_rdy) return;
      end
      $error("TIMEOUT: resp_rdy never asserted");
      $fatal;
    end
  endtask

  // ---------------------------------------------------------------------------
  // 16-bit equality check helper
  // ---------------------------------------------------------------------------
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

  // ---------------------------------------------------------------------------
  // 8-bit equality check helper
  // ---------------------------------------------------------------------------
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

  // ---------------------------------------------------------------------------
  // 1-bit equality check helper
  // ---------------------------------------------------------------------------
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

  // ---------------------------------------------------------------------------
  // End-to-end transaction task
  //
  // Sequence:
  // 1. Tell RemoteComm to send a 16-bit command
  // 2. Wait for UART_wrapper to reconstruct that command
  // 3. Wait for RemoteComm to indicate command transmission complete
  // 4. Clear cmd_rdy in UART_wrapper
  // 5. Tell UART_wrapper to transmit a 1-byte response
  // 6. Wait for RemoteComm to receive that response
  // ---------------------------------------------------------------------------
  task automatic run_transaction(
    input logic [15:0] cmd_in,
    input logic [7:0]  resp_in
  );
    begin
      $display("INFO: Starting transaction cmd=%h resp=%h", cmd_in, resp_in);

      // Start command transmission from RemoteComm
      pulse_snd_cmd(cmd_in);

      // cmd_snt should not already be high immediately after request
      @(posedge clk);
      expect_equal_1(cmd_snt, 1'b0, "cmd_snt should clear after snd_cmd");

      // Wait until UART_wrapper has received and assembled the 16-bit command
      wait_for_cmd_rdy();
      expect_equal_16(dut_cmd, cmd_in, "UART_wrapper reconstructed wrong 16-bit command");

      // Wait until RemoteComm reports that both bytes have been sent
      wait_for_cmd_snt();
      expect_equal_1(cmd_snt, 1'b1, "cmd_snt should assert after both bytes transmit");

      // While cmd_rdy is high, command should remain stable
      repeat (5) @(posedge clk);
      expect_equal_1(cmd_rdy, 1'b1, "cmd_rdy should remain high until clr_cmd_rdy");
      expect_equal_16(dut_cmd, cmd_in, "dut_cmd should hold reconstructed command while cmd_rdy is high");

      // Clear command-ready flag and verify cmd_rdy drops
      pulse_clr_cmd_rdy();
      @(posedge clk);
      expect_equal_1(cmd_rdy, 1'b0, "cmd_rdy did not clear after clr_cmd_rdy");

      // Command register may still legally hold last value even after cmd_rdy clears
      expect_equal_16(dut_cmd, cmd_in, "dut_cmd should still hold last reconstructed command after clr_cmd_rdy");

      // Ask UART_wrapper to send a 1-byte response back to RemoteComm
      pulse_trmt(resp_in);

      // Confirm UART_wrapper reports TX completion
      wait_for_tx_done();
      expect_equal_1(tx_done, 1'b1, "tx_done should assert after wrapper transmits response byte");

      // Optional warning if tx_done is not a one-cycle pulse
      @(posedge clk);
      if (tx_done !== 1'b0)
        $display("WARNING: tx_done did not drop after one cycle; this may still be okay depending on UART implementation");

      // Wait until RemoteComm receives the response byte and check data correctness
      wait_for_resp_rdy();
      expect_equal_8(resp, resp_in, "RemoteComm received wrong response byte");

      $display("INFO: Transaction passed cmd=%h resp=%h", cmd_in, resp_in);
    end
  endtask

  // ---------------------------------------------------------------------------
  // Main test sequence
  // ---------------------------------------------------------------------------
  initial begin
    // Apply reset and initialize DUT/testbench state
    reset_dut();

    // Basic post-reset checks
    expect_equal_1(cmd_rdy, 1'b0, "cmd_rdy should be low after reset");
    expect_equal_1(cmd_snt, 1'b0, "cmd_snt should be low after reset");
    expect_equal_1(tx_done, 1'b0, "tx_done should be low after reset");
    expect_equal_16(dut_cmd, 16'h0000, "cmd should reset to 0");

    // Run several end-to-end command/response tests
    run_transaction(16'hABCD, 8'h5A);
    run_transaction(16'h1234, 8'hC3);
    run_transaction(16'h00FF, 8'h81);

    $display("PASS: All CommTB end-to-end checks succeeded.");
    $finish;
  end

endmodule