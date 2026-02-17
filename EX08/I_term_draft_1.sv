module I_term_draft_1(
		input wire clk, rst_n,
		input logic hdng_vld, moving
		input logic [9:0] err_sat,
		output logic [11:0] I_term
);

	wire ov;
	logic [15:0] err_sat_sext;
	logic [15:0] zero = 16'h0000;
	logic [15:0] integrator;
	logic [15:0] ov_hdng_vld_mux_1, moving_mux_1;
	
	d_ff nxt_integrator_ff.D(nxt_integrator), .clk(clk), .rst_n(rst_n), .Q(integrator));
	

	assign ov_hdng_vld_mux_1 = err_sat_sext + integrator;
	assign moving_mux_1 = (hdng_vld && !ov) ? ov_hdng_vld_mux_1 : integrator;
	assign nxt_integrator = (moving) ? moving_mux_1 : zero;
	assign ov = (!(integrator[15] ^ err_sat_sext[15]) & (integrator[15] ^ ov_hdng_vld_mux_1[15]);
	assign err_sat_sext = $signed(err_sat);
	
	assign I_term = integrator[15:4];
endmodule