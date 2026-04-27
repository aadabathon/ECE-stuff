module P_term(
	input signed [11:0] error,
	output signed [13:0] P_term
);
	// Saturated 10-bit version of heading error
	logic signed [9:0] err_sat;

	// Proportional gain and saturation limits
	localparam signed [4:0] P_COEFF = 5'sd3;
	localparam signed [11:0] ERR_MAX = 12'sd511;
	localparam signed [11:0] ERR_MIN = -12'sd512;

	// Saturate 12-bit error down to signed 10-bit range
	always_comb begin
		if (error < ERR_MIN)
			err_sat = 10'b1000000000;
		else if (error > ERR_MAX)
			err_sat = 10'b0111111111;
		else
			err_sat = error[9:0];
	end

	// P = Kp * error
	assign P_term = err_sat * P_COEFF;
endmodule

module I_term(
	input  logic              clk,
	input  logic              rst_n,
	input  logic              hdng_vld,
	input  logic              moving,
	input  logic signed [9:0] err_sat,
	output logic signed [11:0] I_term
);

	// 16-bit accumulator for integral action
	logic signed [15:0] integrator, nxt_integrator, sum;
	logic signed [15:0] err_sext;
	logic ov;

	// Sign-extend 10-bit error before accumulation
	assign err_sext = {{6{err_sat[9]}}, err_sat};
	assign sum      = integrator + err_sext;

	// Overflow detection for signed addition
	assign ov = (~(integrator[15] ^ err_sext[15])) & (integrator[15] ^ sum[15]);

	// Integral register
	always_ff @(posedge clk or negedge rst_n) begin
		if (!rst_n)
			integrator <= '0;
		else
			integrator <= nxt_integrator;
	end

	// Clear when not moving, hold on invalid heading or overflow
	always_comb begin
		if (!moving)
			nxt_integrator = '0;
		else if (!hdng_vld || ov)
			nxt_integrator = integrator;
		else
			nxt_integrator = sum;
	end

	// Scale integral term down before output
	assign I_term = integrator[15:4];
endmodule

module Dterm(
	input  wire               hdng_vld,
	input  wire               clk,
	input  wire               rst_n,
	input  wire signed [9:0]  err_sat,
	output wire signed [12:0] D_term
);
	// Derivative gain and derivative saturation limits
	localparam signed [4:0]  D_COEFF    = 5'h0E;
	localparam signed [10:0] D_diff_max = 11'sd127;
	localparam signed [10:0] D_diff_min = -11'sd128;

	// Two delayed samples of error
	reg  signed [9:0] flop1, flop2;
	wire signed [10:0] D_diff;
	reg  signed [7:0]  D_diff_sat;

	// Capture current error when heading is valid
	always_ff @(posedge clk or negedge rst_n) begin
		if (!rst_n)
			flop1 <= '0;
		else
			flop1 <= hdng_vld ? err_sat : flop1;
	end

	// Second delay stage for discrete derivative
	always_ff @(posedge clk or negedge rst_n) begin
		if (!rst_n)
			flop2 <= '0;
		else
			flop2 <= hdng_vld ? flop1 : flop2;
	end

	// Approximate derivative = current - delayed
	assign D_diff = err_sat - flop2;

	// Saturate derivative before gain multiply
	always_comb begin
		if (D_diff > D_diff_max)
			D_diff_sat = D_diff_max;
		else if (D_diff < D_diff_min)
			D_diff_sat = D_diff_min;
		else
			D_diff_sat = D_diff[7:0];
	end

	// D = Kd * derivative
	assign D_term = $signed(D_COEFF) * $signed(D_diff_sat);
endmodule

module PID(
	input  wire               clk,
	input  wire               rst_n,
	input  wire               hdng_vld,
	input  wire               moving,
	input  wire signed [11:0] dsrd_hdng,
	input  wire signed [11:0] actl_hdng,
	input  wire [10:0]        frwrd_spd,
	output wire               at_hdng,
	output wire [11:0]        lft_spd,
	output wire [11:0]        rght_spd
);
	// Raw heading error
	wire signed [11:0] hdng_err;

	// Individual PID contributions
	wire signed [13:0] P_term_out;
	wire signed [11:0] I_term_out;
	wire signed [12:0] D_term_out;

	// Intermediate speed/control signals
	wire signed [11:0] lft_spd_mux_1, rgt_spd_mux_1;
	wire signed [14:0] sext_term_sum;
	wire signed [14:0] ctrl15;
	reg  signed [9:0]  err_sat;

	// Heading error and simple "close enough" flag
	assign hdng_err = actl_hdng - dsrd_hdng;
	assign at_hdng  = (err_sat < 10'sd30) && (err_sat > -10'sd30);

	// Saturate heading error for I and D paths
	always_comb begin
		if (hdng_err > 12'sd511)
			err_sat = 10'sd511;
		else if (hdng_err < -12'sd512)
			err_sat = -10'sd512;
		else
			err_sat = hdng_err[9:0];
	end

	// Instantiate PID sub-blocks
	P_term pTerm(
		.error(hdng_err),
		.P_term(P_term_out)
	);

	I_term iTerm(
		.clk(clk),
		.rst_n(rst_n),
		.hdng_vld(hdng_vld),
		.moving(moving),
		.err_sat(err_sat),
		.I_term(I_term_out)
	);

	Dterm dTerm(
		.hdng_vld(hdng_vld),
		.clk(clk),
		.rst_n(rst_n),
		.err_sat(err_sat),
		.D_term(D_term_out)
	);

	// Sum PID terms with sign extension
	assign sext_term_sum = {{1{P_term_out[13]}}, P_term_out} +
	                       {{3{I_term_out[11]}}, I_term_out} +
	                       {{2{D_term_out[12]}}, D_term_out};

	// Overall control scaling
	assign ctrl15 = sext_term_sum >>> 3;

	// Differential steering: add to left, subtract from right
	assign lft_spd_mux_1 = $signed(ctrl15[11:0]) + $signed({1'b0, frwrd_spd});
	assign rgt_spd_mux_1 = $signed({1'b0, frwrd_spd}) - $signed(ctrl15[11:0]);

	// Motors off when not moving
	assign lft_spd  = moving ? lft_spd_mux_1 : 12'h000;
	assign rght_spd = moving ? rgt_spd_mux_1 : 12'h000;

endmodule