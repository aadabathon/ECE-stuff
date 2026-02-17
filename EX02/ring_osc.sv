`timescale 1ns/1ps

module ring_osc(
	input logic En,
	output logic Out
);
	logic n1, n2, n3;
	
	nand #3 (n1, En, n3);
	not #1 (n2, n1);
	not #1 (n3, n2);
	
	assign Out = n3;

endmodule
	
