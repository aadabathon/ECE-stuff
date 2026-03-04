module navigate_tb();

  //// Declare stimulus as type reg ////
  reg clk,rst_n;			// 50MHz clock and asynch active low reset
  reg strt_hdng;			// indicates to start a new heading sequence
  reg strt_mv;				// indicates a new forward movement occurring
  reg stp_lft;				// indicates move should stop at a left opening
  reg stp_rght;				// indicates move should stop at a right opening
  reg hdng_rdy;				// used to pace frwrd_spd increments
  reg at_hdng;				// asserted by PID when new heading is close enough
  reg lft_opn;				// from IR sensor....indicates opening in maze to left
  reg rght_opn;				// from IR sensor....indicates opening in maze to right
  reg frwrd_opn;			// from IR sensor....indicates opening in front
  
  //// declare outputs monitored of type wire ////
  wire mv_cmplt;			// should be asserted at end of move
  wire moving;				// should be asserted at all times not in IDLE
  wire en_fusion;			// should be asserted whenever frwrd_spd>MAX_FRWRD
  wire [10:0] frwrd_spd;	// the primary output...forward motor speed

  localparam FAST_SIM  = 1;			// we always simulate with FAST_SIM on
  localparam MIN_FRWRD = 11'h0D0;		// minimum duty at which wheels will turn
  localparam MAX_FRWRD = 11'h2A0;		// match DUT
  localparam HALF_MAX  = (MAX_FRWRD >> 1);

  //////////////////////
  // Instantiate DUT //
  ////////////////////
  navigate #(FAST_SIM) iDUT(.clk(clk),.rst_n(rst_n),.strt_hdng(strt_hdng),.strt_mv(strt_mv),
                .stp_lft(stp_lft),.stp_rght(stp_rght),.mv_cmplt(mv_cmplt),.hdng_rdy(hdng_rdy),
				.moving(moving),.en_fusion(en_fusion),.at_hdng(at_hdng),.lft_opn(lft_opn),
				.rght_opn(rght_opn),.frwrd_opn(frwrd_opn),.frwrd_spd(frwrd_spd));
  
  initial begin
    clk = 0;
	rst_n = 0;
	strt_hdng = 0;
	strt_mv = 0;
	stp_lft = 1;
	stp_rght = 0;
	hdng_rdy = 1;		// allow increments of frwrd_spd initially
	at_hdng = 0;
	lft_opn = 0;
	rght_opn = 0;
	frwrd_opn = 1;		// no wall in front of us
	
	@(negedge clk);		// after negege clk
	rst_n = 1;			// deassert reset
	
	assert (!moving) $display("GOOD0: moving should not be asserted when IDLE");
	else $error("ERR0: why is moving asserted now?");	

	//////////////////////////////////////////////
	// First testcase will be a heading change //
	////////////////////////////////////////////
	strt_hdng = 1;
	@(negedge clk);
	strt_hdng = 0;
	assert (moving) $display("GOOD1: moving asserted during heading change");
	else $error("ERR1: expecting moving asserted during heading change");
	repeat(5) @(negedge clk);
	at_hdng = 1;				// end the heading
	#1;							// give DUT time to respond
	assert (mv_cmplt) $display("GOOD2: mv_cmplt should be asserted when at_hdng");
	else $error("ERR2: expecting mv_cmplt to be asserted at time %t",$time);
	@(negedge clk);
	at_hdng = 0;
	
	///////////////////////////////////////////////////////////////////////////////////
	// Second testcase will be move forward looking for lft_opn, but hit wall first //
	/////////////////////////////////////////////////////////////////////////////////
	strt_mv = 1;
	@(negedge clk);
	strt_mv = 0;
	assert (moving) $display("GOOD3: moving asserted during forward move");
	else $error("ERR3: expecting moving asserted during forward move");
	assert (frwrd_spd===MIN_FRWRD) $display("GOOD4: frwrd spd should have changed to MIN_FRWRD");
	else $error("ERR4: expecting frwrd_spd to have loaded MIN_FRWRD at time %t",$time);

	@(negedge clk);
	assert (frwrd_spd===MIN_FRWRD+11'h018) $display("GOOD5: frwrd spd should have incrementd to MIN_FRWRD+0x018");
	else $error("ERR5: expecting frwrd_spd to have incremented by 0x018 at time %t",$time);	
	
	/// Now lower hdng_rdy to ensure frwrd_spd does not increment ////
	hdng_rdy = 0;
	@(negedge clk);
	assert (frwrd_spd===MIN_FRWRD+11'h018) $display("GOOD6: frwrd spd should still be MIN_FRWRD+0x018");
	else $error("ERR6: expecting frwrd_spd to have maintained at MIN_FRWRD+0x018");	
	
	/// Now raise hdng_rdy back up
	hdng_rdy = 1;
	@(negedge clk);
	assert (moving) $display("GOOD7: moving should still be asserted");
	else $error("ERR7: why is moving not still asserted?");
	assert (frwrd_spd===MIN_FRWRD+11'h030) $display("GOOD8: frwrd spd should have incremented to MIN_FRWRD+0x030");
	else $error("ERR8: expecting frwrd_spd to have incremented to MIN_FRWRD+0x030 at time %t",$time);
	
	/// Now let it increment 6 more times (so 9 in total) ////
	repeat(6) @(negedge clk);
	
	/// Now let it know it has an obstacle in front ////
	frwrd_opn = 0;
	repeat(2) @(negedge clk);
	assert (frwrd_spd===MIN_FRWRD+11'h018) $display("GOOD9: frwrd spd should have decremented fast to MIN_FRWRD+0x018");
	else $error("ERR9: expecting a fast decrement of frwrd_spd at time %t",$time);	
	
	/// Now check that it properly decrements to zero ////
	repeat(2) @(negedge clk);
	assert (frwrd_spd===11'h000) $display("GOOD10: frwrd spd should be zero now");
	else $error("ERR10: expecting frwrd_spd to have decremented to zero by time %t",$time);	
	assert (mv_cmplt) $display("GOOD11: mv_cmplt should be asserted when speed hits zero");
	else $error("ERR11: expecting mv_cmplt to be asserted at time %t",$time);	


	///////////////////////////////////////////////////////
	// Added TC3: stop at LEFT opening (rise-based stop) //
	// + en_fusion threshold checks                      //
	///////////////////////////////////////////////////////
	$display("=== TC3: stop at LEFT opening rise + en_fusion ===");
	frwrd_opn = 1;
	lft_opn   = 0;
	rght_opn  = 0;
	stp_lft   = 1;
	stp_rght  = 0;
	hdng_rdy  = 1;
	@(negedge clk);

	strt_mv = 1;
	@(negedge clk);
	strt_mv = 0;

	assert (frwrd_spd===MIN_FRWRD) $display("GOOD12: MIN_FRWRD loaded (TC3)");
	else $error("ERR12: expected MIN_FRWRD (TC3) at time %t",$time);

	assert (!en_fusion) $display("GOOD13: en_fusion low at MIN_FRWRD (TC3)");
	else $error("ERR13: en_fusion should be low at time %t",$time);

	// accelerate 5 ticks: MIN + 5*0x18 = MIN + 0x78 = 0x148 (< 0x150)
	repeat(5) @(negedge clk);
	assert (frwrd_spd===MIN_FRWRD+11'h078) $display("GOOD14: speed below HALF_MAX (TC3)");
	else $error("ERR14: expected MIN+0x078 (TC3) at time %t",$time);
	assert (!en_fusion) $display("GOOD15: en_fusion still low below HALF_MAX (TC3)");
	else $error("ERR15: en_fusion should still be low at time %t",$time);

	// one more tick: MIN + 0x90 = 0x160 (> 0x150) -> en_fusion should go high
	@(negedge clk);
	assert (frwrd_spd===MIN_FRWRD+11'h090) $display("GOOD16: speed above HALF_MAX (TC3)");
	else $error("ERR16: expected MIN+0x090 (TC3) at time %t",$time);
	assert (en_fusion) $display("GOOD17: en_fusion high above HALF_MAX (TC3)");
	else $error("ERR17: en_fusion should be high at time %t",$time);

	// now create a left opening RISE to trigger normal decel
	lft_opn = 1;
	repeat(2) @(negedge clk);

	assert (moving) $display("GOOD18: still moving during normal decel (TC3)");
	else $error("ERR18: moving should stay high during decel (TC3)");

	// after 2 negedges of decel, expect down by 2*0x30 = 0x60 from 0x160 -> 0x100? BUT depends on exact cycle boundary.
	// We only sanity check: should be decreasing and should eventually stop.
	assert (frwrd_spd < (MIN_FRWRD+11'h090)) $display("GOOD19: speed decreasing after left rise (TC3)");
	else $error("ERR19: speed did not start decreasing after left rise (TC3)");

	// fusion should eventually drop once below threshold
	repeat(2) @(negedge clk);
	assert (!en_fusion) $display("GOOD20: en_fusion dropped as speed fell (TC3)");
	else $error("ERR20: en_fusion should drop once speed <= HALF_MAX (TC3) at time %t",$time);

	wait (mv_cmplt===1'b1);
	#1;
	assert (frwrd_spd===11'h000) $display("GOOD21: speed is zero at mv_cmplt (TC3)");
	else $error("ERR21: expected speed 0 at mv_cmplt (TC3) at time %t",$time);
	@(negedge clk);
	lft_opn = 0;


	////////////////////////////////////////////////////////
	// Added TC4: stop at RIGHT opening (rise-based stop) //
	////////////////////////////////////////////////////////
	$display("=== TC4: stop at RIGHT opening rise ===");
	frwrd_opn = 1;
	lft_opn   = 0;
	rght_opn  = 0;
	stp_lft   = 0;
	stp_rght  = 1;
	hdng_rdy  = 1;
	@(negedge clk);

	strt_mv = 1;
	@(negedge clk);
	strt_mv = 0;

	assert (frwrd_spd===MIN_FRWRD) $display("GOOD22: MIN_FRWRD loaded (TC4)");
	else $error("ERR22: expected MIN_FRWRD (TC4) at time %t",$time);

	repeat(4) @(negedge clk); // get moving a bit
	rght_opn = 1;             // create rise
	repeat(2) @(negedge clk);

	assert (frwrd_spd < (MIN_FRWRD+11'h060)) $display("GOOD23: speed decreasing after right rise (TC4)");
	else $error("ERR23: speed did not start decreasing after right rise (TC4)");

	wait (mv_cmplt===1'b1);
	#1;
	assert (frwrd_spd===11'h000) $display("GOOD24: speed is zero at mv_cmplt (TC4)");
	else $error("ERR24: expected speed 0 at mv_cmplt (TC4) at time %t",$time);
	@(negedge clk);
	rght_opn = 0;


	////////////////////////////////////////////////////////////////////////
	// Added TC5: opening already asserted should NOT insta-stop (edge det) //
	////////////////////////////////////////////////////////////////////////
	$display("=== TC5: opening already high should not stop until NEW rise ===");
	frwrd_opn = 1;
	stp_lft   = 1;
	stp_rght  = 0;
	hdng_rdy  = 1;

	// keep left opening high before starting move
	lft_opn = 1;
	repeat(3) @(negedge clk);

	strt_mv = 1;
	@(negedge clk);
	strt_mv = 0;

	@(negedge clk);
	assert (frwrd_spd===MIN_FRWRD+11'h018) $display("GOOD25: did not insta-stop w/ lft_opn already high (TC5)");
	else $error("ERR25: insta-stopped with lft_opn already high (TC5) at time %t",$time);

	// now force a new rise: drop then raise
	lft_opn = 0;
	@(negedge clk);
	lft_opn = 1;
	repeat(2) @(negedge clk);

	wait (mv_cmplt===1'b1);
	#1;
	assert (frwrd_spd===11'h000) $display("GOOD26: stopped on NEW left rise (TC5)");
	else $error("ERR26: expected speed 0 at mv_cmplt (TC5) at time %t",$time);
	@(negedge clk);
	lft_opn = 0;


	$display("All tests completed...did all pass?");
	$stop();
	
  end
  
  always
    #5 clk = ~clk;
	
endmodule