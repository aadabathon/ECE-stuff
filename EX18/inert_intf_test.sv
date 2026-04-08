module inert_intf_test(
    input  logic       clk,    // 50 MHz system clock
    input  logic       RST_n,  // asynchronous active-low reset from board
    output logic [7:0] LED,    // board LEDs
    output logic       SS_n,   // SPI slave select to inertial sensor
    output logic       SCLK,   // SPI clock
    output logic       MOSI,   // SPI master-out slave-in
    input  logic       MISO,   // SPI master-in slave-out
    input  logic       INT     // interrupt from inertial sensor
);

logic rst_n;                   // synchronized/debounced internal reset
logic strt_cal;                // command into inert_intf to start calibration
logic cal_done;                // asserted by inert_intf when calibration is complete
logic signed [11:0] heading;   // heading output from inert_intf

logic [16:0] tmr;              // 17-bit timer used to wait after reset before calibration

// Simple 3-state controller:
// IDLE -> wait after reset
// CAL  -> request calibration
// DISP -> display heading on LEDs
typedef enum logic [1:0] {
    IDLE = 2'b00,
    CAL  = 2'b01,
    DISP = 2'b10
} inert_state_t;

inert_state_t state_q, state_d;

// Reset synchronizer:
// external reset is asynchronous and active low,
// internal rst_n is released synchronously
reset_synch rs1(
    .RST_n(RST_n),
    .clk(clk),
    .rst_n(rst_n)
);

// DUT / lower-level inertial interface
// This block handles the actual SPI traffic and heading computation.
// Here we only control when calibration starts and observe completion/heading.
inert_intf interface1(
    .clk(clk),
    .rst_n(rst_n),
    .strt_cal(strt_cal),
    .cal_done(cal_done),
    .heading(heading),
    .rdy(),            // unused in this wrapper
    .IR_Dtrm(9'h000),  // no IR input used here
    .SS_n(SS_n),
    .SCLK(SCLK),
    .MOSI(MOSI),
    .MISO(MISO),
    .INT(INT),
    .moving(1'b0),     // fixed inputs for this wrapper
    .en_fusion(1'b1)
);

// Sequential block:
// holds FSM state, timer, and registered LED output
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        // reset everything to known startup values
        state_q <= IDLE;
        tmr     <= 17'd0;
        LED     <= 8'h00;
    end else begin
        // advance FSM
        state_q <= state_d;

        // timer only runs in IDLE
        // once we leave IDLE, it just holds its final value
        if (state_q == IDLE)
            tmr <= tmr + 17'd1;
        else
            tmr <= tmr;

        // LED behavior is tied to the next state choice
        // IDLE: blank LEDs
        // CAL : show calibration pattern
        // DISP: show upper 8 bits of heading
        case (state_d)
            IDLE:    LED <= 8'h00;
            CAL:     LED <= 8'hA5;
            DISP:    LED <= heading[11:4];
            default: LED <= 8'h00;
        endcase
    end
end

// Combinational next-state / control logic
always_comb begin
    // defaults first:
    // stay in current state unless a condition causes transition
    // do not request calibration unless we're in CAL
    state_d  = state_q;
    strt_cal = 1'b0;

    case (state_q)
        IDLE: begin
            // wait until timer fully counts up
            // &tmr means "all bits of tmr are 1"
            if (&tmr)
                state_d = CAL;
        end

        CAL: begin
            // while in CAL, request calibration
            strt_cal = 1'b1;

            // once inert_intf reports calibration complete,
            // move to display mode
            if (cal_done)
                state_d = DISP;
        end

        DISP: begin
            // remain in display state forever
            state_d = DISP;
        end

        default: begin
            // safety recovery path
            state_d = IDLE;
        end
    endcase
end

endmodule