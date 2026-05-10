module PID(clk, rst_n, moving, dsrd_hdng, actl_hdng, hdng_vld, frwrd_spd, at_hdng, lft_spd, rght_spd);

input clk, rst_n;
input moving;
input [11:0] dsrd_hdng;
input [11:0] actl_hdng;
input hdng_vld;
input [10:0] frwrd_spd;
output logic at_hdng;
output logic [11:0] lft_spd;
output logic [11:0] rght_spd;

logic signed [13:0] P_term;
logic signed [11:0] I_term;
logic signed [12:0] D_term;
logic signed [12:0] err;
logic signed [9:0] err_sat;
logic signed [9:0] err_sat_pipe;
logic signed [14:0] P_term_ext;
logic signed [14:0] I_term_ext;
logic signed [14:0] D_term_ext;
logic signed [14:0] PID_out;
logic signed [11:0] PID_out_div8;
logic signed [11:0] spd_ext;
logic signed [11:0] lft_pid;
logic signed [11:0] rght_pid;

localparam logic signed [3:0] P_COEFF = 4'h3;

assign err = $signed(actl_hdng - dsrd_hdng);

always_comb begin
    if ((err[12] == 1'b1) && (err[12:9] != 4'b1111))
        err_sat = 10'b1000000000;
    else if ((err[12] == 1'b0) && (err[12:9] != 4'b0000))
        err_sat = 10'b0111111111;
    else
        err_sat = err[9:0];
end

always_ff @(posedge clk, negedge rst_n) begin
    if (!rst_n)
        err_sat_pipe <= 10'h000;
    else if (hdng_vld)
        err_sat_pipe <= err_sat;
end

I_term iIterm(.clk(clk), .rst_n(rst_n), .hdng_vld(hdng_vld), .moving(moving), .err_sat(err_sat_pipe), .I_term(I_term));
Dterm iDterm(.clk(clk), .rst_n(rst_n), .hdng_vld(hdng_vld), .err_sat(err_sat_pipe), .D_term(D_term));

assign P_term = err_sat_pipe * P_COEFF;
assign P_term_ext = P_term;
assign I_term_ext = I_term;
assign D_term_ext = D_term;

assign PID_out = P_term_ext + I_term_ext + D_term_ext;
assign PID_out_div8 = PID_out[14:3];

assign spd_ext = {1'b0, frwrd_spd};
assign lft_pid = spd_ext + PID_out_div8;
assign rght_pid = spd_ext - PID_out_div8;

assign lft_spd = (moving) ? lft_pid : 12'h000;
assign rght_spd = (moving) ? rght_pid : 12'h000;

assign at_hdng = ((err_sat_pipe[9] == 1'b0 && err_sat_pipe < 10'd30) ||
                  (err_sat_pipe[9] == 1'b1 && err_sat_pipe > 10'b1111100010)) ? 1'b1 : 1'b0;

endmodule
