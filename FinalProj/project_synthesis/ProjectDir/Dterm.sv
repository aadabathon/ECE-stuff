module Dterm(clk, rst_n, hdng_vld, err_sat, D_term);
//declare input/output
input clk, rst_n;
input hdng_vld;
input logic signed [9:0] err_sat;
output logic signed [12:0] D_term;
localparam logic signed [4:0] D_COEFF = 5'h0E;

//declare internal variables
logic signed [9:0] mux1out;
logic signed [9:0] ff1out;
logic signed [9:0] mux2out;
logic signed [9:0] ff2out;
logic signed [10:0] D_diff;
logic signed [7:0] D_diff_sat;


//first mux - ff block
assign mux1out = (hdng_vld) ? err_sat : ff1out;

always_ff@(posedge clk, negedge rst_n) begin
    if(!rst_n)
	    ff1out <= 10'h0;
    else
	    ff1out <= mux1out;
end


//second mux - ff block
assign mux2out = (hdng_vld) ? ff1out : ff2out;

always_ff@(posedge clk, negedge rst_n) begin
    if(!rst_n)
	    ff2out <= 10'h0;
    else
	    ff2out <= mux2out;
end

//subtract and saturate
assign D_diff = err_sat - ff2out;

always_comb begin
    if ((D_diff[10] == 1'b1) && (D_diff[10:7] != 4'b1111))
        D_diff_sat = 8'b10000000;
    else if ((D_diff[10] == 1'b0) && (D_diff[10:7] != 4'b0000))
        D_diff_sat = 8'b01111111;
    else
        D_diff_sat = D_diff[7:0];
end

//signed multiply
assign D_term = D_diff_sat * D_COEFF;

endmodule