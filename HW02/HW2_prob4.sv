
module SRFF(// SR Flop with an asynch active low reset
	input logic clk, rst_n,
	input logic S, R,
	output logic Q
);	
	always_ff @(posedge clk or negedge rst_n) begin //begin upon clk -> 1 or rst_n -> 0
		if (!rst_n) Q <= 1'b0; //asynch rst takes priority, load 0
		else if (R) Q <= 1'b0; //Else check for R, load 0
		else if (S) Q <= 1'b1; //else if check for S and load 1
	end //implicit else hold
endmodule

module dff( // D Flop with an synch active low reset
	input logic clk, rst_n,
	input logic d,
	output logic q
);
	always_ff @(posedge clk) begin //begin upon clk -> 1 or rst_n -> 0 
		if (!rst_n) q <= 1'b0; //load 0 if our synch rst is low
		else q <= d; //else load d
	end 
endmodule

module dff_en( //D Flop with a asynch active-low reset and an enable
	input logic d,
	input logic clk, rst_n,
	input logic en,
	output logic q
);
	always_ff @(posedge clk or negedge rst_n) begin //begin upon clk -> 1 or rst_n -> 0
		if (!rst_n) q <= 1'b0; // load 0 if our asnych rst is low
		else if (en) q <= d; //else if enable load d
	end //implicit else hold
endmodule
