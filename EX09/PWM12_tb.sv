`timescale 1ns/1ps

module PWM12_tb;

  logic clk;
  logic rst_n;
  logic [11:0] duty;
  logic PWM1, PWM2;

  PWM12 iDUT (
    .clk (clk),
    .rst_n(rst_n),
    .duty(duty),
    .PWM1(PWM1),
    .PWM2(PWM2)
  );

  initial clk = 1'b0;
  always #10 clk = ~clk; // 50 MHz (20 ns period)

  initial begin
    $dumpfile("PWM12.vcd");
    $dumpvars(0, PWM12_tb);

    rst_n = 1'b0;
    duty  = 12'h000;
    repeat (5) @(posedge clk);
    rst_n = 1'b1;

    duty = 12'h080;  // small
    repeat (5000) @(posedge clk);

    duty = 12'h800;  // medium
    repeat (5000) @(posedge clk);

    duty = 12'hF00;  // large
    repeat (5000) @(posedge clk);

    $finish;
  end

endmodule
