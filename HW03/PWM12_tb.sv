`timescale 1ns/1ps
module PWM12_tb;

  logic clk;
  logic rst_n;
  logic [11:0] duty;
  logic PWM1, PWM2;

  // waveform marker so you can see where each duty region begins
  logic tag;

  PWM12 iDUT (
    .clk (clk),
    .rst_n(rst_n),
    .duty(duty),
    .PWM1(PWM1),
    .PWM2(PWM2)
  );

  initial clk = 1'b0;
  always #10 clk = ~clk; // 50 MHz

  task automatic mark_and_hold(input logic [11:0] d, input int periods, input string name);
    int i;
    begin
      duty = d;
      tag  = 1'b1;  // 1-cycle marker pulse
      @(posedge clk);
      tag  = 1'b0;

      $display("[%0t] DUTY=%s (0x%03h). Holding for %0d PWM periods.", $time, name, d, periods);

      // Hold duty for N full PWM periods (each period = 4096 clk cycles)
      for (i = 0; i < periods; i++) begin
        repeat (4096) @(posedge clk);
      end
    end
  endtask
  
	always @(posedge clk) begin
	  if (PWM1 && PWM2) $fatal(1, "Overlap detected at time %0t", $time);
	end
	
  initial begin
    $dumpfile("PWM12.vcd");
    $dumpvars(0, PWM12_tb);

    tag  = 1'b0;
    rst_n = 1'b0;
    duty  = 12'h000;
    repeat (10) @(posedge clk);
    rst_n = 1'b1;

    // Hold each duty long enough that the PWM windows are easy to see,
    // even when zoomed out (each block is multiple full PWM periods).
    mark_and_hold(12'h000, 6, "0%");
    mark_and_hold(12'h080, 6, "small");
    mark_and_hold(12'h800, 6, "mid");
    mark_and_hold(12'hF00, 6, "large");
    mark_and_hold(12'hFFF, 6, "max");

    $display("[%0t] done", $time);
    $finish;
  end

endmodule