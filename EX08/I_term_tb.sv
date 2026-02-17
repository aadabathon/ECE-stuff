`timescale 1ns/1ps

module I_term_tb;

  logic        clk;
  logic        rst_n;
  logic        hdng_vld;
  logic        moving;
  logic [9:0]  err_sat;
  logic [11:0] I_term;

  always #5 clk = ~clk;

  I_term dut (
    .clk      (clk),
    .rst_n    (rst_n),
    .hdng_vld (hdng_vld),
    .moving   (moving),
    .err_sat  (err_sat),
    .I_term   (I_term)
  );

task automatic step(input int n);
  repeat (n) begin
    @(posedge clk);
    @(negedge clk); // guarantees flop output has updated
  end
endtask


  task automatic check_iterm(input int exp, input string tag);
    int got;
    got = $signed(I_term);
    if (got !== exp) $error("[%0t] %s | I_term got=%0d exp=%0d", $time, tag, got, exp);
    else             $display("[%0t] %s | I_term=%0d OK", $time, tag, got);
  endtask

  int exp;

  initial begin
    clk      = 1'b0;
    rst_n    = 1'b0;
    hdng_vld = 1'b0;
    moving   = 1'b0;
    err_sat  = '0;
    exp      = 0;

    #2;
    check_iterm(0, "after init reset low");

    rst_n = 1'b1;
    step(1);
    check_iterm(0, "after reset release");

    moving   = 1'b1;
    hdng_vld = 1'b1;
    err_sat  = 10'sd16;

    repeat (5) begin
      step(1);
      exp += 1;
      check_iterm(exp, "accum +16");
    end

    hdng_vld = 1'b0;
    repeat (3) begin
      step(1);
      check_iterm(exp, "hold hdng_vld=0");
    end

    hdng_vld = 1'b1;
    repeat (2) begin
      step(1);
      exp += 1;
      check_iterm(exp, "resume accum +16");
    end

    moving = 1'b0;
    step(1);
    exp = 0;
    check_iterm(exp, "clear moving=0");

    moving   = 1'b1;
    hdng_vld = 1'b1;
    err_sat  = -10'sd16;

    repeat (3) begin
      step(1);
      exp -= 1;
      check_iterm(exp, "accum -16");
    end

    #3;
    rst_n = 1'b0;
    #1;
    exp = 0;
    check_iterm(exp, "async reset mid-run");
    rst_n = 1'b1;

    step(1);
    check_iterm(exp, "post-reset stable");

    $display("TB done.");
    $finish;
  end

endmodule
