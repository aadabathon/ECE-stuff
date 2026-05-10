//////////////////////////////////////////////////////
// Interfaces with ST 6-axis inertial sensor.  In  //
// this application we only use Z-axis gyro for   //
// heading of mazeRunner.  Fusion correction     //
// comes from IR_Dtrm when en_fusion is high.   //
/////////////////////////////////////////////////
module inert_intf#(parameter FAST_SIM = 0)(clk,rst_n,strt_cal,cal_done,heading,rdy,IR_Dtrm,
                  SS_n,SCLK,MOSI,MISO,INT,moving,en_fusion);
  localparam fast_sim = FAST_SIM;
  input clk, rst_n;
  input MISO;							// SPI input from inertial sensor
  input INT;							// goes high when measurement ready
  input strt_cal;						// initiate claibration of yaw readings
  input moving;							// Only integrate yaw when going
  input en_fusion;						// do fusion corr only when forward at decent clip
  input [8:0] IR_Dtrm;					// derivative term of IR sensors (used for fusion)
  
  output cal_done;				// pulses high for 1 clock when calibration done
  output signed [11:0] heading;	// heading of robot.  000 = Orig dir 3FF = 90 CCW 7FF = 180 CCW
  output rdy;					// goes high for 1 clock when new outputs ready (from inertial_integrator)
  output SS_n,SCLK,MOSI;		// SPI outputs
 

  ////////////////////////////////////////////
  // Declare any needed internal registers //
  //////////////////////////////////////////
  // << holding registers, timer, double flop of INT, ...>>
  logic [15:0] timer;
  logic [7:0] yaw_high, yaw_low;	
  logic C_Y_H, C_Y_L;
  
  //////////////////////////////////////
  // Outputs of SM are of type logic //
  ////////////////////////////////////
  // << declare all the output signals of your SM >>
  logic wrt;

  //////////////////////////////////////////////////////////////
  // Declare any needed internal signals that connect blocks //
  ////////////////////////////////////////////////////////////
  wire done;
  wire [15:0] inert_data;		// Data back from inertial sensor (only lower 8-bits used)
  wire signed [15:0] yaw_rt;
  logic vld;
  logic INT_ff1, INT_ff2;
  logic [15:0] cmd;

  
  
  ///////////////////////////////////////
  // Create enumerated type for state //
  /////////////////////////////////////
 typedef enum logic [2:0] {INIT1,INIT2,READ1_WAIT,READ1_GET,READ2_WAIT,READ2_GET,VLD} state_t;
 state_t state, next_state;
  
  ////////////////////////////////////////////////////////////
  // Instantiate SPI monarch for Inertial Sensor interface //
  //////////////////////////////////////////////////////////
  SPI_main iSPI(.clk(clk),.rst_n(rst_n),.SS_n(SS_n),.SCLK(SCLK),
                 .MISO(MISO),.MOSI(MOSI),.wrt(wrt),.done(done),
				 .rd_data(inert_data),.wt_data(cmd));
				  
  ////////////////////////////////////////////////////////////////////
  // Instantiate Angle Engine that takes in angular rate readings  //
  // and gaurdrail info and produces a heading reading            //
  /////////////////////////////////////////////////////////////////
  inertial_integrator #(fast_sim) iINT(.clk(clk), .rst_n(rst_n), .strt_cal(strt_cal),
                        .vld(vld),.rdy(rdy),.cal_done(cal_done), .yaw_rt(yaw_rt),.moving(moving),
						.en_fusion(en_fusion),.IR_Dtrm(IR_Dtrm),.heading(heading));
	

  //<< remaining logic (SM, timer, holding registers...) >>
  //timer counter
  always_ff @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
      timer <= 0;
    end
    else begin
      timer <= timer + 1;
    end
  end
  
//next state ff
always_ff @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
      state <= INIT1;
    end
    else begin
      state <= next_state;
    end
  end
  
  //state output and transition logic
  always_comb begin
    //defaults
    wrt = 0;
    cmd = 16'h0D02;
    vld = 0;
    next_state = state;
    C_Y_H = 0;
    C_Y_L = 0;
    case(state)
      //2 init states (see pdf may need something to call 0x1440)
      INIT1: begin
        cmd = 16'h0D02;
        if(&timer) begin
          next_state = INIT2;
          wrt = 1;
        end
      end
      INIT2: begin
        cmd = 16'h1160;
        if(done) begin
          next_state = READ1_WAIT;
          wrt = 1;
        end
      end
      //read yaw low and wait until done to load to register
      READ1_WAIT: begin
        if(INT_ff1 && !INT_ff2) begin
          next_state = READ1_GET;
          cmd = 16'hA600;
          wrt = 1;
        end
      end
      READ1_GET: begin
        if(done) begin
          next_state = READ2_GET;
          C_Y_L = 1;
          cmd = 16'hA700;
          wrt = 1;
        end
      end
      READ2_GET: begin
        if(done) begin
          next_state = VLD;
          C_Y_H = 1;
        end
      end
      VLD: begin
        vld = 1;
        next_state = READ1_WAIT;
      end
      default: begin
        next_state = READ1_WAIT;
      end
    endcase
  end
  
//INT double flop
always_ff @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        INT_ff1 <= 0;
        INT_ff2 <= 0;
    end else begin
        INT_ff1 <= INT;
        INT_ff2 <= INT_ff1;
    end
end

//yaw low register
always_ff @(posedge clk or negedge rst_n) begin
  if (!rst_n) begin
    yaw_low <= 0;
  end else if(C_Y_L) begin
    yaw_low <= inert_data[7:0];
  end
end

//yaw high register
always_ff @(posedge clk or negedge rst_n) begin
  if (!rst_n) begin
    yaw_high <= 0;
  end else if(C_Y_H) begin
    yaw_high <= inert_data[7:0];
  end
end

//combine yaw high and low into one signal to send to integrator
assign yaw_rt = {yaw_high, yaw_low};
 
endmodule
	  