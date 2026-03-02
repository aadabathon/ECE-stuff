`timescale 1ns/1ps

module UART_tb;

  logic clk, rst_n;

  logic        trmt;
  logic [7:0]  tx_data;
  logic        TX, tx_done;

  logic        RX;
  logic        clr_rdy;
  logic [7:0]  rx_data;
  logic        rdy;

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

  assign RX = TX;

  initial clk = 1'b0;
  always #10 clk = ~clk; 

  function automatic logic [7:0] bit_reverse8(input logic [7:0] b);
    bit_reverse8 = {b[0], b[1], b[2], b[3], b[4], b[5], b[6], b[7]};
  endfunction

  task automatic reset_dut;
    begin
      rst_n   = 1'b0;
      trmt    = 1'b0;
      tx_data = 8'd0;
      clr_rdy = 1'b0;
      repeat (20) @(posedge clk);
      rst_n = 1'b1;
      repeat (10) @(posedge clk);
    end
  endtask

  task automatic send_byte(input logic [7:0] b);
    begin
      @(posedge clk);
      tx_data <= b;
      trmt    <= 1'b1;
      @(posedge clk);
      trmt    <= 1'b0;
    end
  endtask

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

  task automatic clear_rdy_pulse;
    begin
      @(posedge clk);
      clr_rdy <= 1'b1;
      @(posedge clk);
      clr_rdy <= 1'b0;
      repeat (2) @(posedge clk);
      if (rdy) $fatal(1, "rdy did not clear after clr_rdy");
    end
  endtask

  task automatic send_and_check(input logic [7:0] b);
    logic [7:0] exp;
    begin
      exp = bit_reverse8(b); 
      send_byte(b);
      wait_tx_done();
      wait_rdy();
      if (rx_data !== exp) $fatal(1, "MISMATCH: sent 0x%02h expected rx 0x%02h got 0x%02h", b, exp, rx_data);
      clear_rdy_pulse();
    end
  endtask

  initial begin
    reset_dut();

    send_and_check(8'h00);
    send_and_check(8'hA5);
    send_and_check(8'hFF);
    send_and_check(8'h12);
    send_and_check(8'h34);

    for (int i = 0; i < 20; i++) begin
      logic [7:0] b;
      b = $urandom_range(0,255);
      send_and_check(b);
    end

    $display("UART_tb: PASS");
    $finish;
  end

endmodule