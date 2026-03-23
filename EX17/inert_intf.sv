module inert_intf(clk,rst_n,strt_cal,cal_done,heading,rdy,IR_Dtrm,
                  SS_n,SCLK,MOSI,MISO,INT,moving,en_fusion);

  // FAST_SIM is passed down into the provided inertial_integrator.
  // Usually this just shortens calibration timing in simulation.
  parameter FAST_SIM = 1;

  //////////////////////////////////////////
  // Inputs from top-level / sensor world //
  //////////////////////////////////////////
  input  logic clk, rst_n;
  input  logic MISO;       // SPI serial data back from inertial sensor
  input  logic INT;        // data-ready interrupt from inertial sensor
  input  logic strt_cal;   // command to start calibration in integrator
  input  logic moving;     // tells integrator whether robot is moving
  input  logic en_fusion;  // enable IR correction / fusion in integrator
  input  logic [8:0] IR_Dtrm;

  //////////////////////////////////////////
  // Outputs to top-level / downstream    //
  //////////////////////////////////////////
  output logic cal_done;              // calibration complete from integrator
  output logic signed [11:0] heading; // integrated heading from integrator
  output logic rdy;                   // sample accepted / ready pulse from integrator
  output logic SS_n, SCLK, MOSI;      // SPI outputs to inertial sensor

  ///////////////////////////////////////////////////////////
  // SPI commands required by the exercise spec
  //
  // 0x0D <= 0x02 : enable interrupt generation
  // 0x11 <= 0x60 : configure gyro rate / range
  // 0x14 <= 0x40 : enable wraparound / burst behavior
  //
  // Read commands fetch yaw low byte and yaw high byte.
  ///////////////////////////////////////////////////////////
  localparam logic [15:0] CMD_CFG_INT  = 16'h0D02;
  localparam logic [15:0] CMD_CFG_GYRO = 16'h1160;
  localparam logic [15:0] CMD_CFG_WRAP = 16'h1440;

  localparam logic [15:0] CMD_RD_YAWL  = 16'hA600;
  localparam logic [15:0] CMD_RD_YAWH  = 16'hA700;

  ///////////////////////////////////////////////////////////
  // FSM states
  //
  // WAIT_RST  : sit after reset long enough for sensor startup
  // CFG_INT   : send first config write
  // CFG_GYRO  : send second config write
  // CFG_WRAP  : send third config write
  // IDLE      : wait for INT rising edge saying sample is ready
  // READ_L    : read yaw low byte
  // READ_H    : read yaw high byte
  // PULSE_VLD : tell integrator a fresh full yaw sample is ready
  //
  // Note:
  // We are intentionally keeping this compact. We do not split
  // each command into separate LAUNCH/WAIT states; instead we
  // use the "issued" flag to remember whether the command for
  // the current state has already been launched.
  ///////////////////////////////////////////////////////////
  typedef enum logic [2:0] {
    WAIT_RST,
    CFG_INT,
    CFG_GYRO,
    CFG_WRAP,
    IDLE,
    READ_L,
    READ_H,
    PULSE_VLD
  } state_t;

  state_t state, nstate;

  //////////////////////////////////////////
  // Internal control / datapath signals  //
  //////////////////////////////////////////
  logic [15:0] timer;      // startup delay timer used in WAIT_RST
  logic [15:0] cmd;        // command currently being sent to SPI block
  logic        wrt;        // pulse to launch an SPI transaction
  logic        done;       // SPI block raises this when transaction finishes
  logic [15:0] inert_data; // full 16-bit word shifted back from SPI
  logic        vld;        // one-cycle pulse into integrator when yaw_rt is fresh

  ///////////////////////////////////////////////////////////
  // Holding registers for the two bytes we care about
  //
  // The SPI block shifts back 16 bits, but the useful sensor
  // read data byte is in inert_data[7:0], so we store low and
  // high bytes separately, then concatenate them into yaw_rt.
  ///////////////////////////////////////////////////////////
  logic [7:0] yaw_low, yaw_high;
  logic       C_Y_L, C_Y_H;  // capture enables for low/high byte registers

  ///////////////////////////////////////////////////////////
  // INT synchronizer
  //
  // INT is asynchronous relative to clk, so we double-flop it
  // before using it in state logic. Then int_rise detects the
  // synchronized rising edge.
  ///////////////////////////////////////////////////////////
  logic INT_ff1, INT_ff2;

  ///////////////////////////////////////////////////////////
  // issued / nissued
  //
  // This is the key trick that lets each "command state" do
  // both launch and wait behavior without needing extra states.
  //
  // For example in CFG_INT:
  //   - if issued==0, assert wrt for one cycle and set issued=1
  //   - then remain in CFG_INT until done goes high
  //   - when done arrives, clear issued and advance
  //
  // This prevents us from repeatedly re-launching the same SPI
  // command every cycle while waiting for done.
  ///////////////////////////////////////////////////////////
  logic issued, nissued;

  //////////////////////////////////////////
  // Full signed yaw rate sent downstream //
  //////////////////////////////////////////
  logic signed [15:0] yaw_rt;
  logic               int_rise;

  // Reassemble final 16-bit yaw word from captured bytes
  assign yaw_rt   = {yaw_high, yaw_low};

  // Rising-edge detect on synchronized INT
  assign int_rise = INT_ff1 & ~INT_ff2;

  ///////////////////////////////////////////////////////////
  // SPI master instance
  //
  // We provide:
  //   wrt     -> start transaction
  //   wt_data -> 16-bit command word
  //
  // It gives back:
  //   done    -> transaction complete
  //   rd_data -> received 16-bit shift-register contents
  ///////////////////////////////////////////////////////////
  SPI_main iSPI(
    .clk(clk),
    .rst_n(rst_n),
    .wrt(wrt),
    .wt_data(cmd),
    .MISO(MISO),
    .SS_n(SS_n),
    .SCLK(SCLK),
    .MOSI(MOSI),
    .done(done),
    .rd_data(inert_data)
  );

  ///////////////////////////////////////////////////////////
  // Provided inertial integrator
  //
  // This block handles calibration and heading integration.
  // Our job in inert_intf is simply to:
  //   1. configure the sensor
  //   2. fetch yaw samples when INT says ready
  //   3. pulse vld once a complete yaw_rt sample is assembled
  ///////////////////////////////////////////////////////////
  inertial_integrator #(FAST_SIM) iINT(
    .clk(clk),
    .rst_n(rst_n),
    .strt_cal(strt_cal),
    .cal_done(cal_done),
    .vld(vld),
    .rdy(rdy),
    .yaw_rt(yaw_rt),
    .IR_Dtrm(IR_Dtrm),
    .heading(heading),
    .moving(moving),
    .en_fusion(en_fusion)
  );

  ///////////////////////////////////////////////////////////
  // State register + issued register
  ///////////////////////////////////////////////////////////
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state  <= WAIT_RST;
      issued <= 1'b0;
    end else begin
      state  <= nstate;
      issued <= nissued;
    end
  end

  ///////////////////////////////////////////////////////////
  // Startup delay timer
  //
  // The exercise says to wait after reset before writing the
  // sensor configuration registers. We just count up while in
  // WAIT_RST until the timer saturates.
  ///////////////////////////////////////////////////////////
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n)
      timer <= 16'h0000;
    else if (state == WAIT_RST && !(&timer))
      timer <= timer + 16'h0001;
  end

  ///////////////////////////////////////////////////////////
  // Double-flop synchronizer for INT
  ///////////////////////////////////////////////////////////
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      INT_ff1 <= 1'b0;
      INT_ff2 <= 1'b0;
    end else begin
      INT_ff1 <= INT;
      INT_ff2 <= INT_ff1;
    end
  end

  ///////////////////////////////////////////////////////////
  // Byte holding registers
  //
  // We only load them when the corresponding capture enable is
  // asserted by the FSM at the moment the read transaction is
  // complete.
  ///////////////////////////////////////////////////////////
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      yaw_low  <= 8'h00;
      yaw_high <= 8'h00;
    end else begin
      if (C_Y_L)
        yaw_low  <= inert_data[7:0];
      if (C_Y_H)
        yaw_high <= inert_data[7:0];
    end
  end

  ///////////////////////////////////////////////////////////
  // Main FSM next-state / output logic
  //
  // Default style:
  //   - hold state unless a condition moves us forward
  //   - deassert all controls by default
  //   - only assert wrt/capture/vld in the specific cycle needed
  ///////////////////////////////////////////////////////////
  always_comb begin
    nstate  = state;
    nissued = issued;

    cmd   = 16'h0000;
    wrt   = 1'b0;
    vld   = 1'b0;
    C_Y_L = 1'b0;
    C_Y_H = 1'b0;

    case (state)

      /////////////////////////////////////////////////////////
      // Wait for the startup delay to finish before touching
      // the sensor configuration registers.
      /////////////////////////////////////////////////////////
      WAIT_RST: begin
        if (&timer)
          nstate = CFG_INT;
      end

      /////////////////////////////////////////////////////////
      // Send config write #1
      //
      // First cycle in this state:
      //   launch SPI transaction by pulsing wrt
      //
      // Later cycles:
      //   wait for SPI_main to assert done
      //
      // Once done arrives:
      //   clear issued so the next state can launch its own cmd
      /////////////////////////////////////////////////////////
      CFG_INT: begin
        cmd = CMD_CFG_INT;
        if (!issued) begin
          wrt     = 1'b1;
          nissued = 1'b1;
        end else if (done) begin
          nissued = 1'b0;
          nstate  = CFG_GYRO;
        end
      end

      /////////////////////////////////////////////////////////
      // Send config write #2
      /////////////////////////////////////////////////////////
      CFG_GYRO: begin
        cmd = CMD_CFG_GYRO;
        if (!issued) begin
          wrt     = 1'b1;
          nissued = 1'b1;
        end else if (done) begin
          nissued = 1'b0;
          nstate  = CFG_WRAP;
        end
      end

      /////////////////////////////////////////////////////////
      // Send config write #3
      /////////////////////////////////////////////////////////
      CFG_WRAP: begin
        cmd = CMD_CFG_WRAP;
        if (!issued) begin
          wrt     = 1'b1;
          nissued = 1'b1;
        end else if (done) begin
          nissued = 1'b0;
          nstate  = IDLE;
        end
      end

      /////////////////////////////////////////////////////////
      // Normal operating wait state
      //
      // Stay here until the synchronized INT has a rising edge.
      // That means a fresh yaw sample is ready in the sensor.
      /////////////////////////////////////////////////////////
      IDLE: begin
        if (int_rise)
          nstate = READ_L;
      end

      /////////////////////////////////////////////////////////
      // Read yaw low byte
      //
      // Same launch/wait pattern as init states.
      // Once done comes back, capture inert_data[7:0] into
      // yaw_low and advance to high-byte read.
      /////////////////////////////////////////////////////////
      READ_L: begin
        cmd = CMD_RD_YAWL;
        if (!issued) begin
          wrt     = 1'b1;
          nissued = 1'b1;
        end else if (done) begin
          C_Y_L   = 1'b1;
          nissued = 1'b0;
          nstate  = READ_H;
        end
      end

      /////////////////////////////////////////////////////////
      // Read yaw high byte
      //
      // Once done comes back, capture inert_data[7:0] into
      // yaw_high and move to the vld pulse state.
      /////////////////////////////////////////////////////////
      READ_H: begin
        cmd = CMD_RD_YAWH;
        if (!issued) begin
          wrt     = 1'b1;
          nissued = 1'b1;
        end else if (done) begin
          C_Y_H   = 1'b1;
          nissued = 1'b0;
          nstate  = PULSE_VLD;
        end
      end

      /////////////////////////////////////////////////////////
      // One-cycle valid pulse
      //
      // At this point yaw_low and yaw_high have both been
      // captured, so yaw_rt is now a fresh complete sample.
      // Pulse vld for exactly one cycle into integrator, then
      // return to idle to wait for the next INT.
      /////////////////////////////////////////////////////////
      PULSE_VLD: begin
        vld    = 1'b1;
        nstate = IDLE;
      end

      /////////////////////////////////////////////////////////
      // Safety fallback
      /////////////////////////////////////////////////////////
      default: begin
        nstate  = WAIT_RST;
        nissued = 1'b0;
      end

    endcase
  end

endmodule