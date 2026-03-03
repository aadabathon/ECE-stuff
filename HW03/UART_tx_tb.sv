`timescale 1ns/1ps
module UART_tx_tb;

  // ------------------------------------------------------------
  // TB signals
  // ------------------------------------------------------------
  logic        clk, rst_n;
  logic        trmt;
  logic [7:0]  tx_data;
  logic        TX, tx_done;

  // ------------------------------------------------------------
  // DUT
  // ------------------------------------------------------------
  UART_tx iDUT(
    .clk    (clk),
    .rst_n  (rst_n),
    .trmt   (trmt),
    .tx_data(tx_data),
    .TX     (TX),
    .tx_done(tx_done)
  );

  // ------------------------------------------------------------
  // Clock: 50 MHz (20 ns period)
  // ------------------------------------------------------------
  initial clk = 1'b0;
  always  #10 clk = ~clk;

  // Must match the DUT divider (50 MHz / 19200 ≈ 2604)
  localparam int BAUD_DIV = 2604;

  // ------------------------------------------------------------
  // Drive a 1-cycle transmit request (trmt) with stable tx_data
  // ------------------------------------------------------------
  task automatic pulse_trmt(input logic [7:0] b);
    begin
      @(negedge clk);
      tx_data = b;
      trmt    = 1'b1;
      @(negedge clk);
      trmt    = 1'b0;
    end
  endtask

  // ------------------------------------------------------------
  // Observe TX and check one full 8N1 UART frame:
  //   start(0), 8 data bits LSB-first, stop(1)
  //
  // Sampling:
  //   - wait for TX falling edge (start)
  //   - sample mid-bit: BAUD_DIV/2 after edge, then every BAUD_DIV
  //   - use #1 after clk edge to avoid sampling before NBAs settle
  // ------------------------------------------------------------
  task automatic check_frame(input logic [7:0] exp);
    int i;
    logic [7:0] got;
    begin
      got = '0;

      // Wait for start bit edge
      @(negedge TX);

      // Middle of start bit
      repeat (BAUD_DIV/2) @(posedge clk);
      #1;
      if (TX !== 1'b0)
        $fatal(1, "FAIL: start bit not 0 at t=%0t", $time);

      // 8 data bits (LSB first)
      for (i = 0; i < 8; i++) begin
        repeat (BAUD_DIV) @(posedge clk);
        #1;
        got[i] = TX;
      end

      // stop bit
      repeat (BAUD_DIV) @(posedge clk);
      #1;
      if (TX !== 1'b1)
        $fatal(1, "FAIL: stop bit not 1 at t=%0t", $time);

      if (got !== exp)
        $fatal(1, "FAIL: data mismatch got=0x%02h exp=0x%02h at t=%0t", got, exp, $time);

      $display("[%0t] PASS frame: 0x%02h", $time, exp);
    end
  endtask

  // ------------------------------------------------------------
  // Send a byte and check it (checker armed before trmt asserted)
  // ------------------------------------------------------------
  task automatic send_and_check(input logic [7:0] b);
    begin
      fork
        check_frame(b);
        pulse_trmt(b);
      join

      // tx_done is a pulse in your design; this wait makes intent explicit
      wait (tx_done);

      // idle gap for clean waveform separation
      repeat (BAUD_DIV*2) @(posedge clk);
    end
  endtask

  // ------------------------------------------------------------
  // Test sequence
  // ------------------------------------------------------------
  initial begin
    trmt    = 1'b0;
    tx_data = 8'h00;
    rst_n   = 1'b0;

    repeat (5) @(posedge clk);
    rst_n = 1'b1;

    send_and_check(8'hA5);
    send_and_check(8'h3C);
    send_and_check(8'h00);
    send_and_check(8'hFF);

    $display("YAHOO! UART_tx_tb passed.");
    $finish;
  end

endmodule