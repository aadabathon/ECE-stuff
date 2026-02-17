`timescale 1ns/1ps

module ring_osc_tb();
	logic stim1 = 0, stim2;
	logic snap;
	
	ring_osc iDUT(.En(stim1), .Out(stim2));
	
	initial begin
	  #15;
	  stim1 = 1;
	  
	  wait (stim2 === 1'b0 || stim2 === 1'b1);

	  @(stim2);
	  if (stim2 === 1'b0)
		  $display ("Pass");
	  else
		  $display("Fail");
	  
	  @(stim2);
	  if(stim2 === 1'b1)
		  $display("Pass");
	  else
		  $display("Fail");
	  #25;
	  stim1 = 0;
	  #5;
	  snap = stim2;
	  #10;
      if (stim2 === snap) $display("Pass"); else $display("Fail");

	  $stop;
	end
endmodule