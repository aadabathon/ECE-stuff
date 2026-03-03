module PID(
	input  wire clk, rst_n, hdng_vld, moving,
	input  wire signed [11:0] dsrd_hdng, actl_hdng, // desired/actual headings
	input  wire [10:0] frwrd_spd, // base forward speed (unsigned)
	output wire at_hdng, // within heading tolerance
	output wire [11:0] lft_spd, rght_spd // commanded wheel speeds
);
	// Heading error and saturated version used by I/D logic
	wire signed [11:0] hdng_err;
	reg  signed [9:0]  err_sat;

	// Individual PID term outputs
	wire signed [13:0] P_term_out;
	wire signed [11:0] I_term_out;
	wire signed [12:0] D_term_out;

	// Sum PID terms in wider signed domain, then scale down (>>3 per spec)
	wire signed [14:0] sext_term_sum;
	wire signed [14:0] ctrl15;

	// Intermediate speed computations
	wire signed [11:0] lft_spd_mux_1, rgt_spd_mux_1;

	// Define error sign convention (verify this matches the provided TB/spec)
	assign hdng_err = actl_hdng - dsrd_hdng;

	// "At heading" flag based on saturated error magnitude
	assign at_hdng = (err_sat < 10'sd30) && (err_sat > -10'sd30);

	// Saturate hdng_err into 10-bit range for I/D paths
	always_comb begin
		if (hdng_err > 12'sd511) err_sat = 10'sd511;
		else if (hdng_err < -12'sd512) err_sat = -10'sd512;
		else err_sat = hdng_err[9:0];
	end

	// Term generators
	P_term pTerm(.error(hdng_err), .P_term(P_term_out));
	I_term iTerm(.clk(clk), .rst_n(rst_n), .hdng_vld(hdng_vld), .moving(moving),
	             .err_sat(err_sat), .I_term(I_term_out));
	Dterm  dTerm(.hdng_vld(hdng_vld), .clk(clk), .rst_n(rst_n),
	             .err_sat(err_sat), .D_term(D_term_out));

	// Sign-extend each term into common width then sum
	assign sext_term_sum =
		{{1{P_term_out[13]}}, P_term_out} +
		{{3{I_term_out[11]}}, I_term_out} +
		{{2{D_term_out[12]}}, D_term_out};

	// Controller scaling (>>3 per spec)
	assign ctrl15 = sext_term_sum >>> 3;

	// Mix forward speed with steering correction to get left/right commands
	assign lft_spd_mux_1 = $signed(ctrl15[11:0]) + $signed({1'b0, frwrd_spd});
	assign rgt_spd_mux_1 = $signed({1'b0, frwrd_spd}) - $signed(ctrl15[11:0]);

	// Output gating: when not moving, command 0
	assign lft_spd  = (moving) ? lft_spd_mux_1 : 12'h000;
	assign rght_spd = (moving) ? rgt_spd_mux_1 : 12'h000;

endmodule


module P_term(
	input  signed [11:0] error, // raw heading error (12-bit signed)
	output signed [13:0] P_term // proportional contribution
);
	// Saturate error down to signed 10-bit range [-512, 511] before multiplying
	logic signed [9:0] err_sat;

	localparam signed [4:0]  P_COEFF = 5'sd3; // P gain
	localparam signed [11:0] ERR_MAX = 12'sd511;
	localparam signed [11:0] ERR_MIN = -12'sd512;

	always_comb begin
		if (error < ERR_MIN) err_sat = 10'sb1000000000; // -512
		else if (error > ERR_MAX)  err_sat = 10'sb0111111111; // +511
		else err_sat = error[9:0];
	end

	// Apply P gain (signed multiply)
	assign P_term = err_sat * P_COEFF;

endmodule


module I_term(
  input  logic clk, rst_n,
  input  logic hdng_vld, moving, // integrate only when moving and sample is valid
  input  logic [9:0]  err_sat, // saturated error (10-bit)
  output logic [11:0] I_term // integrator contribution (scaled/truncated)
);

  // Internal accumulator uses extra width to reduce overflow risk
  logic signed [15:0] integrator, nxt_integrator, sum;
  logic signed [15:0] err_sext;
  logic ov;

  // Sign-extend 10-bit error to integrator width
  assign err_sext = {{6{err_sat[9]}}, err_sat};
  assign sum = integrator + err_sext;

  // Signed overflow detect on addition
  assign ov = (~(integrator[15] ^ err_sext[15])) & (integrator[15] ^ sum[15]);

  // Register the integrator state
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) integrator <= '0;
    else integrator <= nxt_integrator;
  end

  // Integration policy:
  // - if not moving: clear integrator (prevents windup while stopped)
  // - if sample not valid or overflow would occur: hold value
  // - else: accumulate error
  always_comb begin
    if (!moving) nxt_integrator = '0;
    else if (!hdng_vld || ov) nxt_integrator = integrator;
    else nxt_integrator = sum;
  end

  // Output scaling: take upper bits (effectively divide by 16)
  assign I_term = integrator[15:4];

endmodule


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


