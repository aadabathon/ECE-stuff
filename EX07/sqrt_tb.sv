`timescale 1ns/1ps

module sqrt_tb;

  logic        clk, rst_n, go; //Variable instantiation for our DUT
  logic [15:0] stim;
  logic        done, err;
  logic [7:0]  sqrt;

  sqrt iDUT( //DUT instantiation for sqrt module
    .clk  (clk),
    .rst_n(rst_n),
    .go   (go),
    .op   (stim),
    .sqrt (sqrt),
    .done (done),
    .err  (err)
  );

  initial clk = 1'b0;
  always #5 clk = ~clk;

  task automatic reset_DUT; //Task resets the DUT and precludes metastability.
    begin
      rst_n = 1'b0;
      go    = 1'b0;
      stim  = '0;
      repeat (2) @(negedge clk);
      rst_n = 1'b1;
      @(negedge clk);
    end
  endtask

  task automatic start_calc(input logic [15:0] stim_in); //Task for starting the calculator for each test case
    begin
      @(negedge clk);
      stim <= stim_in;
      go   <= 1'b1;
      @(negedge clk);
      go   <= 1'b0;
      @(posedge done);
      @(negedge clk);
    end
  endtask

  initial begin
    reset_DUT();

    start_calc(16'd64); // sqrt(64) = 8
    if (!err && sqrt == 8'd8) $display("PASS: sqrt(64) = %0d", sqrt);
    else                      $display("FAIL: sqrt(64) got=%0d err=%b", sqrt, err);

    start_calc(16'd256); // sqrt(256) = 16
    if (!err && sqrt == 8'd16) $display("PASS: sqrt(256) = %0d", sqrt);
    else                       $display("FAIL: sqrt(256) got=%0d err=%b", sqrt, err);

    start_calc(16'h8000); // negative -> err
    if (err) $display("PASS: negative operand correctly set err");
    else     $display("FAIL: negative operand did not set err");

    start_calc(16'd132); // floor(sqrt(132)) = 11
    if (!err && sqrt == 8'd11) $display("PASS: sqrt(132) = %0d", sqrt);
    else                       $display("FAIL: sqrt(132) got=%0d err=%b", sqrt, err);

    $finish;
  end

endmodule
