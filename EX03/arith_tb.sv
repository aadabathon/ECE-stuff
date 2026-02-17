module arith_tb();
logic [7:0] stimA, stimB;
logic stimSUB;
logic [7:0] testSUM;
logic testOV;

arith iDUT(.A(stimA), .B(stimB), .SUB(stimSUB), .SUM(testSUM), .OV(testOV));

initial begin
	// Test 1: addition 8 + 15 = 23
	stimA = 8'b00001000;
	stimB = 8'b00001111;
	stimSUB = 1'b0;
	#1;
	if (testSUM === 8'b00010111 && testOV === 1'b0)
		$display("Regular addition test passed");
	else $display("Fail");

	// Test 2: subtraction 21 - 21 = 0
	stimA = 8'b00010101;
	stimB = 8'b00010101;
	stimSUB = 1'b1;
	#1;
	if (testSUM === 8'b00000000 && testOV === 1'b0)
		$display("Regular subtraction test passed");
	else $display("Fail");
	
	//Test 3: overflow 127+1
	stimA = 8'b01111111;
	stimB = 8'b00000001;
	stimSUB = 1'b0;	
	#1;
	if(testOV === 1)
		$display("Additive overflow test passed");
	else $display("fail");
	
	//Test4: overflow 100 - (-50)
	stimA = 8'b01100100;
	stimB = 8'b11001110;
	stimSUB = 1'b1;	
	#1;
	if(testOV === 1)
		$display("Subtractive overflow test passed");
	else $display("Fail");

	$stop;
end
	
endmodule

