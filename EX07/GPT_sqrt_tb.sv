`timescale 1ns/1ps

module sqrt_tb;

  logic        clk, rst_n, go;
  logic [15:0] op;
  logic [7:0]  sqrt;
  logic        done, err;

  sqrt dut(
    .clk  (clk),
    .rst_n(rst_n),
    .go   (go),
    .op   (op),
    .sqrt (sqrt),
    .done (done),
    .err  (err)
  );

  initial clk = 1'b0;
  always  #5 clk = ~clk;

  function automatic int unsigned isqrt16(input logic [15:0] n);
    int unsigned x;
    begin
      x = 0;
      while (((x+1)*(x+1)) <= n) x++;
      return x;
    end
  endfunction

  task automatic reset_dut;
    begin
      rst_n = 1'b0;
      go    = 1'b0;
      op    = '0;
      repeat (2) @(negedge clk);
      rst_n = 1'b1;
      @(negedge clk);
    end
  endtask

  task automatic start_calc(input logic [15:0] op_in);
    begin
      @(negedge clk);
      op <= op_in;
      go <= 1'b1;
      @(negedge clk);
      go <= 1'b0;
      @(posedge done);
    end
  endtask

  task automatic expect_calc(input logic [15:0] op_in);
    int unsigned exp_sqrt;
    logic        exp_err;
    begin
      exp_err  = op_in[15];
      exp_sqrt = exp_err ? 0 : isqrt16(op_in);

      start_calc(op_in);

      if (done !== 1'b1)
        $fatal(1, "DONE not asserted when expected. op=%h done=%b", op_in, done);

      if (err !== exp_err)
        $fatal(1, "ERR mismatch. op=%h got=%b exp=%b", op_in, err, exp_err);

      if (!exp_err && sqrt !== exp_sqrt[7:0])
        $fatal(1, "SQRT mismatch. op=%0d got=%0d exp=%0d", op_in, sqrt, exp_sqrt);

      $display("PASS: op=%h sqrt=%0d err=%b", op_in, sqrt, err);
    end
  endtask

  initial begin
    reset_dut();

    expect_calc(16'd9);
    expect_calc(16'd256);
    expect_calc(16'd65535);
    expect_calc(16'h8001);

    @(negedge clk);
    $finish;
  end

endmodule
