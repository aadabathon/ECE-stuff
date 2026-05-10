module PID(clk, rst_n, moving, dsrd_hdng, actl_hdng, hdng_vld, frwrd_spd, at_hdng, lft_spd, rght_spd);
//declare input/output
input logic clk, rst_n;
input logic moving;
input logic signed [11:0] dsrd_hdng;
input logic signed [11:0] actl_hdng;
input logic hdng_vld;
input logic [10:0] frwrd_spd;
output logic at_hdng;
output logic signed [11:0] lft_spd;
output logic signed [11:0] rght_spd;

//declare internal variables
logic signed [13:0] P_term;
logic signed [11:0] I_term;
logic signed [12:0] D_term;
logic signed [12:0] err;
logic signed [9:0] err_sat;
logic signed [14:0] P_term_ext;
logic signed [14:0] I_term_ext;
logic signed [14:0] D_term_ext;
logic signed [14:0] PID_out;
logic signed [11:0] PID_out_div8;
logic signed [11:0] spd_ext;
logic signed [11:0] lft_pid;
logic signed [11:0] rght_pid;
localparam logic signed [3:0] P_COEFF = 4'h0003;

//calculate err_sat
assign err = $signed(actl_hdng - dsrd_hdng);
always_comb begin
    if ((err[12] == 1'b1) && (err[12:9] != 4'b1111))
        err_sat = 10'b1000000000;
    else if ((err[12] == 1'b0) && (err[12:9] != 4'b0000))
        err_sat = 10'b0111111111;
    else
        err_sat = err[9:0];
end


//instantiate terms
//P_term iPterm(.error(err), .P_term(P_term));
I_term iIterm(.clk(clk), .rst_n(rst_n), .hdng_vld(hdng_vld), .moving(moving), .err_sat(err_sat), .I_term(I_term));
Dterm iDterm(.clk(clk), .rst_n(rst_n), .hdng_vld(hdng_vld), .err_sat(err_sat), .D_term(D_term));

assign P_term = err_sat * P_COEFF;
assign P_term_ext = P_term;
assign I_term_ext = I_term;
assign D_term_ext = D_term;

//calculate PID_out
assign PID_out = P_term_ext + I_term_ext + D_term_ext;
assign PID_out_div8 = PID_out[14:3];

//calculate right and left adjusted speeds
//assign spd_ext = {frwrd_spd[10], frwrd_spd};
assign spd_ext = {1'b0, frwrd_spd};
assign lft_pid = spd_ext + PID_out_div8;
assign rght_pid = spd_ext - PID_out_div8;

//assign if moving, otherwise 0
assign lft_spd = (moving) ? lft_pid : 12'h000;
assign rght_spd = (moving) ? rght_pid : 12'h000;

//check if at heading
assign at_hdng = ((err_sat[9] == 1'b0 && err_sat < 10'd30) || (err_sat[9] == 1'b1 && err_sat > 10'b1111100010)) ? 1'b1 : 1'b0;

endmodule