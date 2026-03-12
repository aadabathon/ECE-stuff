module RemoteComm(
	input clk, rst_n,
	input RX, clr_cmd_rdy, trmt
	input [7:0] resp,
	output TX, cmd_rdy, tx_done,
	output cmd[15:0]
	);
	
endmodule