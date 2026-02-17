`timescale 1ns/1ps

module PWM12_tb;

  logic clk;
  logic rst_n;
  logic [11:0] duty;
  logic PWM1, PWM2;

  localparam int unsigned PERIOD_CLKS = 4096;
  localparam int unsigned NONOVERLAP  = 12'h02C;

  PWM12 iDUT (
    .clk (clk),
    .rst_n(rst_n),
    .duty(duty),
    .PWM1(PWM1),
    .PWM2(PWM2)
  );

  initial clk = 1'b0;
  always #10 clk = ~clk;

  task automatic run_cycles(int unsigned n);
    repeat (n) @(posedge clk);
  endtask

  task automatic run_periods(int unsigned p);
    run_cycles(PERIOD_CLKS * p);
  endtask

  logic PWM1_d, PWM2_d;
  int unsigned deadcnt_1to2, deadcnt_2to1;
  logic wait_1to2, wait_2to1;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      PWM1_d <= 1'b0;
      PWM2_d <= 1'b0;
      deadcnt_1to2 <= 0;
      deadcnt_2to1 <= 0;
      wait_1to2 <= 1'b0;
      wait_2to1 <= 1'b0;
    end else begin
      assert (!(PWM1 && PWM2)) else $fatal(1, "[%0t] OVERLAP: PWM1 and PWM2 both high", $time);

      if (PWM1_d && !PWM1) begin
        wait_1to2 <= 1'b1;
        deadcnt_1to2 <= 0;
      end
      if (wait_1to2) begin
        if (!PWM1 && !PWM2) deadcnt_1to2 <= deadcnt_1to2 + 1;
        if (PWM2) begin
          assert (deadcnt_1to2 >= NONOVERLAP)
            else $fatal(1, "[%0t] DEADTIME 1->2 too small: %0d", $time, deadcnt_1to2);
          wait_1to2 <= 1'b0;
        end
      end

      if (PWM2_d && !PWM2) begin
        wait_2to1 <= 1'b1;
        deadcnt_2to1 <= 0;
      end
      if (wait_2to1) begin
        if (!PWM1 && !PWM2) deadcnt_2to1 <= deadcnt_2to1 + 1;
        if (PWM1) begin
          assert (deadcnt_2to1 >= NONOVERLAP)
            else $fatal(1, "[%0t] DEADTIME 2->1 too small: %0d", $time, deadcnt_2to1);
          wait_2to1 <= 1'b0;
        end
      end

      PWM1_d <= PWM1;
      PWM2_d <= PWM2;
    end
  end

  initial begin
    $timeformat(-9, 1, " ns", 10);
    $dumpfile("PWM12.vcd");
    $dumpvars(0, PWM12_tb);

    rst_n = 1'b0;
    duty  = 12'h000;
    run_cycles(5);
    rst_n = 1'b1;

    run_periods(1);

    duty = 12'h010;
    run_periods(2);

    duty = 12'h800;
    run_periods(2);

    duty = 12'hF00;
    run_periods(2);

    duty = 12'hFFF;
    run_periods(2);

    $finish;
  end

endmodule
