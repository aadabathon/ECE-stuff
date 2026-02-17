`timescale 1ps/1ps

module MSFF_tb();
	logic stim1, stim2, clk;
	
	MSFF iDUT(.D(stim1), .clk(clk), .Q(stim2));

	initial clk = 0; //clk with a 30ps period
	always #15 clk = ~clk;
	
	
	initial begin
	  stim1 = 0;
	  #16
	  if(stim2 === 1'b0) $display("Pass");
	  else $display("Fail");
	  
	  stim1 = 1;
	  #30 
	  if (stim2 === 1'b1) $display("Pass");
	  else $display("Fail");
	  
	  stim1 = 0;
	  #28
	  if (stim2 === 1'b1) $display("Pass");
	  else $display("Fail");
	  
	  #2
	  if(stim2 === 1'b0) $display("Pass");
	  else $display("Fail");
	  
	  $stop;
	end
endmodule
