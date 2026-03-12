module navigate(clk,rst_n,strt_hdng,strt_mv,stp_lft,stp_rght,mv_cmplt,hdng_rdy,moving,
                en_fusion,at_hdng,lft_opn,rght_opn,frwrd_opn,frwrd_spd);
				
  parameter FAST_SIM = 1;		// speeds up incrementing of frwrd register for faster simulation
				
  input clk,rst_n;					// 50MHz clock and asynch active low reset
  input strt_hdng;					// indicates should start a new heading
  input strt_mv;					// indicates should start a new forward move
  input stp_lft;					// indicates should stop at first left opening
  input stp_rght;					// indicates should stop at first right opening
  input hdng_rdy;					// new heading reading ready....used to pace frwrd_spd increments
  output logic mv_cmplt;			// asserted when heading or forward move complete
  output logic moving;				// enables integration in PID and in inertial_integrator
  output logic en_fusion;					// Only enable fusion (IR reading affect on nav) when moving forward at decent speed.
  input at_hdng;					// from PID, indicates heading close enough to consider heading complete.
  input lft_opn,rght_opn,frwrd_opn;	// from IR sensors, indicates available direction.  Might stop at rise of lft/rght
  output reg [10:0] frwrd_spd;		// unsigned forward speed setting to PID
  
  // << Your declarations of states, regs, wires, ...>>
  
	logic init_frwrd, inc_frwrd, dec_frwrd, dec_frwrd_fast;

	typedef enum logic [2:0] {
	IDLE,
	HDNG_CHANGE,
	MV_ACCEL,
	DECEL,
	DECEL_FAST
	} nav_state_t;
	
	nav_state_t nav_state_q, nav_state_d;
  
  localparam MAX_FRWRD = 11'h2A0;		// max forward speed
  localparam MIN_FRWRD = 11'h0D0;		// minimum duty at which wheels will turn
  logic [5:0] frwrd_inc;
  
	generate
		if (FAST_SIM) begin : GEN_FAST
			assign frwrd_inc = 6'h18;
		end else begin : GEN_NORM
			assign frwrd_inc = 6'h02;
		end
	endgenerate		
   
	assign en_fusion = moving && (frwrd_spd > (MAX_FRWRD >> 1));
	
  ////////////////////////////////
  // Now form forward register //
  //////////////////////////////
  always_ff @(posedge clk, negedge rst_n)
    if (!rst_n)
	  frwrd_spd <= 11'h000;
	else if (init_frwrd)
	  frwrd_spd <= MIN_FRWRD;									// min speed to get motors moving
	else if (hdng_rdy && inc_frwrd && (frwrd_spd<MAX_FRWRD))	// max out at 400 of 7FF for control head room
	  frwrd_spd <= frwrd_spd + {5'h00,frwrd_inc};
	else if (hdng_rdy && (frwrd_spd>11'h000) && (dec_frwrd | dec_frwrd_fast))
	  frwrd_spd <= ((dec_frwrd_fast) && (frwrd_spd>{2'h0,frwrd_inc,3'b000})) ? frwrd_spd - {2'h0,frwrd_inc,3'b000} : // 8x accel rate
                    (dec_frwrd_fast) ? 11'h000 :	  // if non zero but smaller than dec amnt set to zero.
	                (frwrd_spd>{4'h0,frwrd_inc,1'b0}) ? frwrd_spd - {4'h0,frwrd_inc,1'b0} : // slow down at 2x accel rate
					11'h000;

  // << Your implementation of ancillary circuits and SM >>	
	logic lft_opn_q, rght_opn_q;
	logic lft_opn_rise, rght_opn_rise;
	
	always_ff @(posedge clk or negedge rst_n) begin //edge detector on rght and lft opn signals for FSM
		if (!rst_n) begin
			lft_opn_q <= 1'b0;
			rght_opn_q <= 1'b0;
		end else begin
			lft_opn_q <= lft_opn;
			rght_opn_q <= rght_opn;
		end
	end
	
	assign lft_opn_rise = lft_opn & ~lft_opn_q;
	assign rght_opn_rise = rght_opn & ~rght_opn_q;
	
	wire stop_opening = (stp_lft & lft_opn_rise) | (stp_rght & rght_opn_rise);
	wire stop_wall = ~frwrd_opn;
	
	always_ff @(posedge clk or negedge rst_n) begin
		if (!rst_n) nav_state_q <= IDLE;
		else nav_state_q <= nav_state_d; //Load Current state with next on every clk edge. FF for our FSM
	end
	
	always_comb begin
	  nav_state_d = nav_state_q;

	  moving = 1'b0;
	  mv_cmplt = 1'b0;
	  init_frwrd = 1'b0;
	  inc_frwrd = 1'b0;
	  dec_frwrd = 1'b0;
	  dec_frwrd_fast = 1'b0;

	  case (nav_state_q)
		IDLE: begin
		  if (strt_hdng) begin
			nav_state_d = HDNG_CHANGE;
		  end else if (strt_mv) begin
			moving     = 1'b1;
			init_frwrd = 1'b1;
			nav_state_d = MV_ACCEL;
		  end
		end

		HDNG_CHANGE: begin
		  moving = 1'b1;
		  if (at_hdng) begin
			mv_cmplt    = 1'b1;
			nav_state_d = IDLE;
		  end
		end

		MV_ACCEL: begin
		  moving    = 1'b1;
		  inc_frwrd = 1'b1;
		  if (stop_wall)         nav_state_d = DECEL_FAST;
		  else if (stop_opening) nav_state_d = DECEL;
		end

		DECEL: begin
		  moving    = 1'b1;
		  dec_frwrd = 1'b1;
		  if (stop_wall) nav_state_d = DECEL_FAST;
		  else if (frwrd_spd == 11'h000) begin
			mv_cmplt    = 1'b1;
			nav_state_d = IDLE;
		  end
		end

		DECEL_FAST: begin
		  moving         = 1'b1;
		  dec_frwrd_fast = 1'b1;
		  if (frwrd_spd == 11'h000) begin
			mv_cmplt    = 1'b1;
			nav_state_d = IDLE;
		  end
		end

		default: nav_state_d = IDLE;
	  endcase
	end
endmodule
  