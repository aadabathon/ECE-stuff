`timescale 1ns/1ps
module UART_tb;

  // ------------------------------------------------------------
  // Loopback UART self-checking testbench
  // - Instantiates UART_tx and UART_rx
  // - Connects TX -> RX
  // - Sends a mix of directed + randomized bytes
  // - Checks rx_data matches transmitted byte and that rdy can be cleared
  // ------------------------------------------------------------

  logic clk, rst_n;

  // TX-side stimulus / outputs
  logic trmt;
  logic [7:0]  tx_data;
  logic TX, tx_done;

  // RX-side inputs / outputs
  logic RX;
  logic clr_rdy;
  logic [7:0]  rx_data;
  logic rdy;

  // ------------------------------------------------------------
  // DUT instances
  // ------------------------------------------------------------
  UART_tx iDUT_tx(
    .clk(clk), .rst_n(rst_n),
    .trmt(trmt),
    .tx_data(tx_data),
    .TX(TX),
    .tx_done(tx_done)
  );

  UART_rx iDUT_rx(
    .clk(clk), .rst_n(rst_n),
    .RX(RX),
    .clr_rdy(clr_rdy),
    .rx_data(rx_data),
    .rdy(rdy)
  );

  // Loopback connection (TX drives RX)
  assign RX = TX;

  // ------------------------------------------------------------
  // Clock: 50 MHz (20 ns period)
  // ------------------------------------------------------------
  initial clk = 1'b0;
  always #10 clk = ~clk;

  // ------------------------------------------------------------
  // Reset helper: hold reset low, initialize TB-controlled inputs,
  // then release reset cleanly on clock boundaries.
  // ------------------------------------------------------------
  task automatic reset_dut;
    begin
      rst_n = 1'b0;
      trmt = 1'b0;
      tx_data = 8'd0;
      clr_rdy = 1'b0;

      repeat (20) @(posedge clk);
      rst_n = 1'b1;
      repeat (10) @(posedge clk);
    end
  endtask

  // ------------------------------------------------------------
  // Pulse trmt for one cycle to start a transmit.
  // tx_data is held stable across the request.
  // ------------------------------------------------------------
  task automatic send_byte(input logic [7:0] b);
    begin
      @(posedge clk);
      tx_data = b;
      trmt = 1'b1;
      @(posedge clk);
      trmt = 1'b0;
    end
  endtask

  // ------------------------------------------------------------
  // Wait for tx_done with a timeout so the TB cannot hang forever.
  // ------------------------------------------------------------
  task automatic wait_tx_done(input int unsigned timeout_cycles = 200000);
    int unsigned t;
    begin
      t = 0;
      while (!tx_done && t < timeout_cycles) begin
        @(posedge clk);
        t++;
      end
      if (!tx_done) $fatal(1, "TIMEOUT waiting for tx_done");
    end
  endtask

  // ------------------------------------------------------------
  // Wait for RX to assert rdy (valid received byte latched).
  // Timeout prevents infinite hangs.
  // ------------------------------------------------------------
  task automatic wait_rdy(input int unsigned timeout_cycles = 300000);
    int unsigned t;
    begin
      t = 0;
      while (!rdy && t < timeout_cycles) begin
        @(posedge clk);
        t++;
      end
      if (!rdy) $fatal(1, "TIMEOUT waiting for rdy");
    end
  endtask

  // ------------------------------------------------------------
  // Clear rdy using the clr_rdy handshake and verify it deasserts.
  // ------------------------------------------------------------
  task automatic clear_rdy_pulse;
    begin
      @(posedge clk);
      clr_rdy = 1'b1;
      @(posedge clk);
      clr_rdy = 1'b0;

      // allow a couple cycles for rdy to drop cleanly
      repeat (2) @(posedge clk);
      if (rdy) $fatal(1, "rdy did not clear after clr_rdy");
    end
  endtask

  // ------------------------------------------------------------
  // Full transaction:
  //   1) send byte
  //   2) wait for TX completion and RX ready
  //   3) check loopback byte matches
  //   4) clear rdy and confirm it clears
  // ------------------------------------------------------------
  task automatic send_and_check(input logic [7:0] b);
    begin
      send_byte(b);

      // tx_done proves TX finished its frame
      // rdy proves RX validated stop bit + latched data
      wait_tx_done();
      wait_rdy();

      if (rx_data !== b)
        $fatal(1, "MISMATCH: sent 0x%02h got 0x%02h", b, rx_data);

      clear_rdy_pulse();
      $display("[%0t] PASS: 0x%02h", $time, b);
    end
  endtask

  // ------------------------------------------------------------
  // Test sequence
  // ------------------------------------------------------------
  initial begin
    reset_dut();

    // Directed tests (corners + patterns)
    send_and_check(8'h00);
    send_and_check(8'hA5);
    send_and_check(8'hFF);
    send_and_check(8'h12);
    send_and_check(8'h34);

    // Random regression
    for (int i = 0; i < 20; i++) begin
      logic [7:0] b;
      b = $urandom_range(0, 255);
      send_and_check(b);
    end

    $display("UART_tb: PASS");
    $finish;
  end

endmodule