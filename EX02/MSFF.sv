module MSFF( //Master Slave Flip Flop
	input logic D, clk,
	output wire Q
);
	tri md, sd;
	wire mq, sq, NOTclk;
	
	not not1(NOTclk, clk);
	
	notif1 pass_m(md, D, NOTclk); //Master
	not (weak0, weak1) keep_m(md, mq);
	not inv_m(mq, md);
	
	notif1 pass_s(sd, mq, clk); //Slave
	not (weak0, weak1) keep_s(sd, sq);
	not inv_s(sq, sd);
	
	assign Q = sq;
	
endmodule 
	
	
	
	