module Dterm( 
	input wire hdng_vld, // enables update of derivative history
	input wire clk, rst_n, // clock + active-low async reset
	input wire signed [9:0] err_sat, // saturated error input (from upstream)
	output wire signed [12:0] D_term // derivative term output
);
	
	localparam signed [4:0] D_COEFF = 5'h0E; // D-term gain (fixed-point coefficient used by the Ex10 spec)
	localparam signed [10:0] D_diff_max = 11'sd127; // Clamp limits for the error difference before applying gain
	localparam signed [10:0] D_diff_min = -11'sd128; // (keeps derivative spikes bounded)
	
	// Two-stage history of the error sampled only when hdng_vld is asserted.
	// flop1 holds the most recent valid err_sat, flop2 holds the previous valid err_sat.
	reg signed [9:0] flop1, flop2;
	wire signed [10:0] D_diff;
	reg signed [7:0] D_diff_sat;
	
	// Capture current error when hdng_vld is high (otherwise hold value).
	always_ff @(posedge clk or negedge rst_n) begin
		if (!rst_n) flop1 <= '0;
		else flop1 <= (hdng_vld) ? err_sat : flop1;
	end
	
	// Delay line stage 2: previous captured error (updates only on hdng_vld).
	always_ff @(posedge clk or negedge rst_n) begin	
		if (!rst_n) flop2 <= '0;
		else flop2 <= (hdng_vld) ? flop1 : flop2;
	end
	
	assign D_diff = err_sat - flop2; // Raw derivative input = current error - previous error sample.
	
	// Saturate the difference into an 8-bit signed range before multiplying by D_COEFF.
	// This prevents large step changes in error from producing an excessively large D_term.	
	always_comb begin
		if (D_diff > D_diff_max) D_diff_sat = 8'sd127;
		else if (D_diff < D_diff_min) D_diff_sat = -8'sd128;
		else D_diff_sat = D_diff[7:0];
	end
	
	// Apply derivative gain. Sign-extend operands to ensure signed multiply.
	assign D_term = $signed(D_COEFF) * $signed(D_diff_sat);

endmodule