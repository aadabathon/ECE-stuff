module Dterm( 
	input wire hdng_vld,
	input wire clk, rst_n,
	input wire signed [9:0] err_sat,
	output wire signed [12:0] D_term
);
	localparam signed [4:0] D_COEFF = 5'h0E;
	localparam signed [10:0] D_diff_max = 11'sd127;
	localparam signed [10:0] D_diff_min = -11'sd128;

	reg signed [9:0] flop1, flop2; //Intermediate signals
	wire signed [10:0] D_diff;
	reg signed [7:0] D_diff_sat; // 
	
	always_ff @(posedge clk or negedge rst_n) begin
		if (!rst_n) flop1 <= '0;
		else flop1 <= (hdng_vld) ? err_sat : flop1;
	end
	
	always_ff @(posedge clk or negedge rst_n) begin	
		if (!rst_n) flop2 <= '0;
		else flop2 <= (hdng_vld) ? flop1 : flop2;
	end
	
	assign D_diff = err_sat - flop2;
	
	always_comb begin
		if (D_diff > D_diff_max) D_diff_sat = D_diff_max;
		else if (D_diff < D_diff_min) D_diff_sat = D_diff_min;
		else D_diff_sat = D_diff[7:0];
	end

	assign D_term = $signed(D_COEFF) * $signed(D_diff_sat);


endmodule