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