module ShiftReg( //Does this instream of bits match a goal at any point? ShiftReg and always_comb flag
	input clk, rst_n,
	input wire in_stream,
	output wire match
);
	localparam goal = 8'hAB;
	reg [7:0] shift_out;
	
	
	always (@posedge clk) begin
		if (!rst_n) shift_out <= 8'b0;
		else shift_out <= {shift_out[6:0], in_stream};
	end
	
	always_comb match  = shift_out == goal;
endmodule
	
		
	