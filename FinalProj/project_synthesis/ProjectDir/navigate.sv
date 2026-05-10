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
  output en_fusion;					// Only enable fusion (IR reading affect on nav) when moving forward at decent speed.
  input at_hdng;					// from PID, indicates heading close enough to consider heading complete.
  input logic lft_opn,rght_opn,frwrd_opn;	// from IR sensors, indicates available direction.  Might stop at rise of lft/rght
  output reg [10:0] frwrd_spd;		// unsigned forward speed setting to PID			

  //Internal signals
  logic inc_frwrd;	
  logic [5:0] frwrd_inc;
  logic init_frwrd;
  logic dec_frwrd;
  logic dec_frwrd_fast;

  localparam MAX_FRWRD = 11'h2A0;		// max forward speed
  localparam MIN_FRWRD = 11'h0D0;		// minimum duty at which wheels will turn

  assign frwrd_inc = (FAST_SIM) ? 6'h18 : 6'h02;	// how much to increment forward speed at each step.  Adjust for faster sim.

  typedef enum logic [2:0] {IDLE, HDNG_INIT, HDNG, MOVE_INIT, MOVE, MV_STOP, MV_STOP_FAST} state_t; 
  state_t state, nxt_state;

  // Delayed versions of IR sensor inputs for edge detection
  logic lft_opn_d, rght_opn_d; 
  logic lft_rise, rght_rise;
  
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

// Ancillary circuits and state machine
always_comb begin
moving = 0;
mv_cmplt = 0;
init_frwrd = 0;
inc_frwrd = 0;
dec_frwrd = 0;
dec_frwrd_fast = 0;
  case(state)
  IDLE : begin
  if(strt_hdng) begin
    nxt_state = HDNG_INIT;
  end
  else if(strt_mv) begin
    nxt_state = MOVE_INIT;
    init_frwrd = 1;
  end
  end
  HDNG_INIT : begin
    moving = 1;
    nxt_state = HDNG;
  end
  HDNG : begin
    moving = 1;
    if(at_hdng) begin
      mv_cmplt = 1;
      nxt_state = IDLE;  
    end
  end
  MOVE_INIT : begin
    moving = 1;
    inc_frwrd = 1;
    nxt_state = MOVE;
  end
  MOVE : begin
    moving = 1;
    inc_frwrd = 1;
    if(~frwrd_opn) begin
      nxt_state = MV_STOP_FAST;
    end
    else if(stp_lft && lft_rise) begin
      nxt_state = MV_STOP;
    end
    else if(stp_rght && rght_rise) begin
      nxt_state = MV_STOP;
    end
  end
  MV_STOP_FAST : begin
    dec_frwrd_fast = 1;
    moving = 1;
    if(frwrd_spd == 0) begin
      mv_cmplt = 1;
      nxt_state = IDLE;
    end
  end
  MV_STOP : begin
    dec_frwrd = 1;
    moving = 1;
    if(frwrd_spd == 0) begin
      mv_cmplt = 1;
      nxt_state = IDLE;
    end
  end
  default : nxt_state = IDLE;
  endcase
end

always_ff @(posedge clk or negedge rst_n) begin
  if(!rst_n) begin
    lft_opn_d <= 0;
    rght_opn_d <= 0;
  end
  else begin
    lft_opn_d <= lft_opn;
    rght_opn_d <= rght_opn;
  end
end

assign lft_rise  = lft_opn  & ~lft_opn_d;
assign rght_rise = rght_opn & ~rght_opn_d;

always_ff @(posedge clk, negedge rst_n) begin
  if(!rst_n) 
    state <= IDLE;
  else
    state <= nxt_state;
end

//Assert en_fusion if frwrd_spd is greater than 1/2 max speed, allowing IR readings to affect nav decisions only when moving at decent speed.
assign en_fusion = (frwrd_spd > (MAX_FRWRD >> 1)) ? 1 : 0;
endmodule
  