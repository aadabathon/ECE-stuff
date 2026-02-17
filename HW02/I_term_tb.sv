`timescale 1ns/1ps

module I_term_tb(); // self-checking TB for I_term

  logic        clk;
  logic        rst_n; // async active-low reset
  logic        hdng_vld; // when 1, accumulate (unless overflow)
  logic        moving; // when 0, clear integrator
  logic [9:0]  err_sat; // signed 10-bit error input
  logic [11:0] I_term; // DUT output = integrator[15:4] (scaled)

  always #5 clk = ~clk; // 100MHz clock (10ns period) 

  I_term iDUT( // instantiate DUT
    .clk      (clk),
    .rst_n    (rst_n),
    .hdng_vld (hdng_vld),
    .moving   (moving),
    .err_sat  (err_sat),
    .I_term   (I_term)
  );

  // Step N full cycles and land on negedge so flop outputs are stable for checking
  task automatic step(input int n);
    repeat (n) begin
      @(posedge clk);
      @(negedge clk); // check between edges (post-update)
    end
  endtask

  // Simple self-check helper: compares signed I_term to expected integer exp
  task automatic check_iterm(input int exp, input string tag);
    int got;
    got = $signed(I_term); // interpret I_term as signed 12-bit
    if (got !== exp) $fatal(1, "[%0t] %s | I_term got=%0d exp=%0d", $time, tag, got, exp);
    else             $display("[%0t] %s | I_term=%0d OK", $time, tag, got);
  endtask

  int exp; // expected I_term (integrator/16)

  initial begin
    // Init everything to known values
    clk      = 1'b0; // start clock low
    rst_n    = 1'b0; // hold reset asserted
    hdng_vld = 1'b0; // default: do not accumulate
    moving   = 1'b0; // default: not moving -> clears
    err_sat  = '0; // default error 0
    exp = 0; // expected output 0

    #2;
    check_iterm(0, "after init reset low"); // async reset should force 0

    // Release reset in a safe spot (negedge) so we don't race a posedge update
    @(negedge clk);
    rst_n = 1'b1; // deassert reset
    step(1); // wait a cycle
    check_iterm(0, "after reset release"); // should still be 0 (moving=0)

    // --- Accumulate +16 (=> +1 per cycle at I_term output) ---
    moving   = 1'b1; // enable integrator
    hdng_vld = 1'b1; // heading valid -> accumulate
    err_sat  = 10'sd16; // +16 at integrator => +1 at I_term (since [15:4])

    repeat (5) begin
      step(1);
      exp += 1; // expected +1 per cycle
      check_iterm(exp, "accum +16");
    end

    hdng_vld = 1'b0; // invalid heading -> hold integrator constant
    repeat (3) begin
      step(1);
      check_iterm(exp, "hold hdng_vld=0"); // should not change
    end
	
    hdng_vld = 1'b1; // valid again -> accumulate
    repeat (2) begin
      step(1);
      exp += 1;
      check_iterm(exp, "resume accum +16");
    end

    moving = 1'b0; // not moving forces nxt_integrator=0
    step(1);
    exp = 0;
    check_iterm(exp, "clear moving=0");

    moving   = 1'b1; // enable integrator
    hdng_vld = 1'b1; // valid -> accumulate
    err_sat  = -10'sd16; // -16 at integrator => -1 at I_term

    repeat (3) begin
      step(1);
      exp -= 1;
      check_iterm(exp, "accum -16");
    end

    #3;
    rst_n = 1'b0; // assert async reset
    #1;
    exp = 0;
    check_iterm(exp, "async reset mid-run"); // should go to 0 immediately

    hdng_vld = 1'b0; // park: prevent accumulation after reset
    err_sat  = '0; // park: neutral error (extra safety)

    @(negedge clk);
    rst_n = 1'b1; // deassert reset away from posedge

    step(1); // one full cycle while parked
    check_iterm(exp, "post-reset stable"); // guaranteed to still be 0 now

    $display("TB done.");
    $finish;
  end

endmodule
