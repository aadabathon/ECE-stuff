module arith(A,B,SUB,SUM,OV);

input [7:0] A,B;		// two 8-bit quantities to be addes/subtracted
input SUB;				// if high operation is A - B, otherwise A + B
output [7:0] SUM;		// result of arithmetic operation
output OV;				// overflow if operands are interpretted as signed.

wire [7:0] B_comp;
wire ov_add, ov_sub;

assign B_comp = (SUB) ? ~B : B;		// 1's complement if subtracting
assign SUM = A + B_comp + SUB;		// if subtracting we are inverting and adding 1

//This was erroneous overflow logic, I've overriden it below.

assign ov_add = ~(A[7] ^ B[7]) & (A[7] ^ SUM[7]); //if the MSB on A and B are the and SUM doesn't share that, additive overflow has occured.
assign ov_sub =  (A[7] ^ B[7]) & (A[7] ^ SUM[7]); //if the MSB on A and B arent the same and A doesn't share an MSB with SUM, subtractive overflow has occured.

////////////////////////////////////////////////////////////
// If both operands into adder are positive and result   //
// is negative then overflow occurred.  If both operands//
// are negative and result is positive then overflow ////
// occurred.  Overflow can't happen if operands are // 
// of different sign.                              //
////////////////////////////////////////////////////
assign OV = SUB ? ov_sub : ov_add;

endmodule 
