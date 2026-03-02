module P_term(
	input signed [11:0] error, //signal to sat to 10 bits
	output signed [13:0] P_term
);
	logic signed [9:0] err_sat;
	localparam signed [4:0] P_COEFF = 5'sd3;
	localparam signed [11:0] ERR_MAX = 12'sd511;
	localparam signed [11:0] ERR_MIN = -12'sd512;

	always_comb begin
		if (error < ERR_MIN) begin
			err_sat = 10'b1000000000;
		end	
		else if (error > ERR_MAX) begin
			err_sat = 10'b0111111111;
		end
		else begin
			err_sat = error[9:0];
		end
	end
	assign P_term = err_sat * P_COEFF;
	
endmodule

module I_term(
  input  logic        clk, rst_n,
  input  logic        hdng_vld, moving,
  input  logic [9:0]  err_sat,
  output logic [11:0] I_term
);

  logic signed [15:0] integrator, nxt_integrator, sum;
  logic signed [15:0] err_sext;
  logic              ov;

  assign err_sext = {{6{err_sat[9]}}, err_sat};
  assign sum      = integrator + err_sext;

  assign ov = (~(integrator[15] ^ err_sext[15])) & (integrator[15] ^ sum[15]);

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) integrator <= '0;
    else        integrator <= nxt_integrator;
  end

  always_comb begin
    if (!moving)              nxt_integrator = '0;
    else if (!hdng_vld || ov) nxt_integrator = integrator;
    else                      nxt_integrator = sum;
  end

  assign I_term = integrator[15:4];

endmodule

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

module PID(
	input wire clk, rst_n, hdng_vld, moving,
	input wire signed [11:0] dsrd_hdng, actl_hdng,
	input wire [10:0] frwrd_spd,
	output wire at_hdng,
	output wire [11:0] lft_spd, rght_spd
);
	wire signed [11:0] hdng_err;
	wire signed [13:0] P_term_out;
	wire signed [11:0] I_term_out;
	wire signed [12:0] D_term_out;
	wire signed [11:0] lft_spd_mux_1, rgt_spd_mux_1;
	wire signed [14:0] sext_term_sum;
	wire signed [14:0] ctrl15;
	reg signed [9:0] err_sat;
	
	assign hdng_err = actl_hdng - dsrd_hdng;
	assign at_hdng = (err_sat < 10'sd30) && (err_sat > -10'sd30);


    always @(*) begin
        if (hdng_err > 12'sd511)       err_sat = 10'sd511;
        else if (hdng_err < -12'sd512) err_sat = -10'sd512;
        else                           err_sat = hdng_err[9:0];
    end
	P_term pTerm(.error(hdng_err), .P_term(P_term_out));
	I_term iTerm(.clk(clk), .rst_n(rst_n), .hdng_vld(hdng_vld), .moving(moving), .err_sat(err_sat), .I_term(I_term_out));
	Dterm dTerm(.hdng_vld(hdng_vld), .clk(clk), .rst_n(rst_n), .err_sat(err_sat), .D_term(D_term_out));
	
	assign ctrl15 = sext_term_sum >>> 3;
	
	assign sext_term_sum = {{1{P_term_out[13]}}, P_term_out} + {{3{I_term_out[11]}}, I_term_out} +  {{2{D_term_out[12]}}, D_term_out};
	assign lft_spd_mux_1  = $signed(ctrl15[11:0]) + $signed({1'b0, frwrd_spd});
	assign rgt_spd_mux_1  = $signed({1'b0, frwrd_spd}) - $signed(ctrl15[11:0]);

	
	
	assign lft_spd = (moving) ? lft_spd_mux_1 : 12'h000;
	assign rght_spd = (moving) ? rgt_spd_mux_1 : 12'h000;
endmodule