module pattern_match(
	input logic clk, rst_n, in_stream,
	output logic match
);
	localparam goal = 8'hAB; //8'b10101011
	logic [7:0] check = '0;
	
	always_ff @(posedge clk or negedge rst_n) begin
		if (!rst_n) check <= '0;
		else check <= {check[6:0], in_stream};
	end
	
	always_comb match = (check == goal);
endmodule
			