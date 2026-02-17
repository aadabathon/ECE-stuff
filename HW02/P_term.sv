module P_term( //Module defined as per the Ex06 pdf specifies
	input signed [11:0] error, //Error signal to sat to 10 bits
	output signed [13:0] P_term // P term to return
);
	logic signed [9:0] err_sat;
	localparam signed [4:0] P_COEFF = 5'sd3; //Const for our signed multiply
	localparam signed [11:0] ERR_MAX = 12'sd511; // Const for conditional
	localparam signed [11:0] ERR_MIN = -12'sd512; // Const for conditional

	always_comb begin
		if (error < ERR_MIN) begin // If we are under the min, we saturate to the most negative value our 10 bit vector can be ie ERR_MIN
			err_sat = ERR_MIN;
		end	
		else if (error > ERR_MAX) begin // If we are over the max, we saturate to the most positive value our 10 bit vector can be. ie ERR_MAX
			err_sat = ERR_MAX;
		end
		else begin
			err_sat = error[9:0]; //Else we truncate our error signal, since we checked if error was out of range, in this case we lose no information in chopping of the two MSB.
		end
	end
	assign P_term = err_sat * P_COEFF; //Signed multiply
	
endmodule