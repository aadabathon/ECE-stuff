module UART_tx_tb();

  logic clk, rst_n;
  logic trmt;
  logic [7:0] tx_data;
  logic TX, tx_done;

  UART_tx iDUT(.clk(clk), .rst_n(rst_n), .trmt(trmt), .tx_data(tx_data), .TX(TX), .tx_done(tx_done));

  initial clk = 0;
  always #10 clk = ~clk; // 50 MHz -> 20 ns period

  task send_byte(input [7:0] b);
    begin
      @(negedge clk);
      tx_data = b;
      trmt = 1;
      @(negedge clk);
      trmt = 0;
    end
  endtask

  initial begin
    trmt = 0;
    tx_data = 8'h00;
    rst_n = 0;
    repeat (5) @(negedge clk);
    rst_n = 1;

    send_byte(8'hA5);
    wait (tx_done);
    repeat (2000) @(negedge clk);

    send_byte(8'h3C);
    wait (tx_done);
    repeat (2000) @(negedge clk);

    $finish;
  end

endmodule