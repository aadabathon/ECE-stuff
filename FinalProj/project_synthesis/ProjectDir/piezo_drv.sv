module piezo_drv #(
    // FAST_SIM is a compile-time parameter.
    // When FAST_SIM = 1, we make note durations advance 16x faster
    // so simulation does not take forever.
    parameter bit FAST_SIM = 0
)(
    input  logic clk,
    input  logic rst_n,
    input  logic batt_low,
    input  logic fanfare,
    output logic piezo,
    output logic piezo_n
);

///////////////////////////////////////////////////////////////////////////////
// STATE MACHINE
//
// This FSM does not use one state per musical note.
// Instead:
//
//   state_q tells us WHICH MODE we are in:
//      - IDLE
//      - BATTERY_LOW
//      - FANFARE
//
//   idx_q tells us WHICH NOTE within that mode's sequence we are currently on.
//
// This is cleaner than exploding the FSM into many note states.
///////////////////////////////////////////////////////////////////////////////
typedef enum logic [1:0] {
    IDLE,
    BATTERY_LOW,
    FANFARE
} state_t;

state_t state_q, state_d;

///////////////////////////////////////////////////////////////////////////////
// SEQUENCE INDEX
//
// idx_q is the current position in the active note sequence.
//
// For BATTERY_LOW:
//   idx = 0 -> G6
//   idx = 1 -> C7
//   idx = 2 -> E7
//   then wraps back to 0 and repeats forever while batt_low stays high
//
// For FANFARE:
//   idx = 0 -> G6
//   idx = 1 -> C7
//   idx = 2 -> E7
//   idx = 3 -> G7
//   idx = 4 -> E7
//   idx = 5 -> G7
//   then sequence ends
///////////////////////////////////////////////////////////////////////////////
logic [2:0] idx_q, idx_d;

///////////////////////////////////////////////////////////////////////////////
// COUNTERS
//
// cyc_counter_q:
//   counts clock cycles within ONE PERIOD of the current note
//   this determines the output pitch / frequency
//
// dur_counter_q:
//   counts how long the CURRENT NOTE has been played
//   this determines when we move on to the next note in the sequence
///////////////////////////////////////////////////////////////////////////////
logic [15:0] cyc_counter_q, cyc_counter_d;
logic [24:0] dur_counter_q, dur_counter_d;

///////////////////////////////////////////////////////////////////////////////
// CURRENT NOTE SETTINGS
//
// cyc_limit = how many 50 MHz clocks make up one note period
// dur_limit = how long to hold the current note before advancing
//
// These are derived combinationally from (state_q, idx_q).
///////////////////////////////////////////////////////////////////////////////
logic [15:0] cyc_limit;
logic [24:0] dur_limit;

///////////////////////////////////////////////////////////////////////////////
// NOTE PERIOD CONSTANTS
//
// These are the period counts for the square wave at 50 MHz.
//
// Example:
//   If cyc_limit = 31888, then we let cyc_counter run from 0 to 31887,
//   and that forms one full waveform period for that note.
///////////////////////////////////////////////////////////////////////////////
localparam logic [15:0] CYC_G6 = 16'd31888;
localparam logic [15:0] CYC_C7 = 16'd23889;
localparam logic [15:0] CYC_E7 = 16'd18961;
localparam logic [15:0] CYC_G7 = 16'd15944;

///////////////////////////////////////////////////////////////////////////////
// DURATION CONSTANTS
//
// These encode the note lengths from the spec.
//
// DUR_2P22 = 2^22
// DUR_2P23 = 2^23
// DUR_3P22 = 2^23 + 2^22 = 3 * 2^22
// DUR_2P24 = 2^24
//
// The fanfare uses different note lengths; battery-low uses 2^23 for each note.
///////////////////////////////////////////////////////////////////////////////
localparam logic [24:0] DUR_2P22 = 25'd4194304;
localparam logic [24:0] DUR_2P23 = 25'd8388608;
localparam logic [24:0] DUR_3P22 = 25'd12582912;
localparam logic [24:0] DUR_2P24 = 25'd16777216;

///////////////////////////////////////////////////////////////////////////////
// DURATION INCREMENT
//
// In hardware mode: increment duration counter by 1 each cycle
// In fast simulation mode: increment by 16 each cycle
//
// This effectively makes note durations 16x shorter in simulation.
///////////////////////////////////////////////////////////////////////////////
localparam logic [24:0] DUR_INC = FAST_SIM ? 25'd16 : 25'd1;

///////////////////////////////////////////////////////////////////////////////
// NOTE LOOKUP LOGIC
//
// Based on the current FSM state and sequence index, choose:
//   1) the note frequency (cyc_limit)
//   2) the note duration  (dur_limit)
//
// Important:
//   - In BATTERY_LOW, only indices 0,1,2 matter
//   - In FANFARE, indices 0..5 matter
//   - Defaults are just safe fallbacks
///////////////////////////////////////////////////////////////////////////////
always_comb begin
    // Safe defaults in case no case branch overrides them
    cyc_limit = CYC_G6;
    dur_limit = DUR_2P23;

    case (state_q)

        ///////////////////////////////////////////////////////////////////////
        // BATTERY_LOW repeating pattern:
        //   G6, C7, E7, then wrap
        ///////////////////////////////////////////////////////////////////////
        BATTERY_LOW: begin
            case (idx_q)
                3'd0: begin
                    cyc_limit = CYC_G6;
                    dur_limit = DUR_2P23;
                end
                3'd1: begin
                    cyc_limit = CYC_C7;
                    dur_limit = DUR_2P23;
                end
                default: begin
                    // idx 2 (or anything unexpected) plays E7
                    cyc_limit = CYC_E7;
                    dur_limit = DUR_2P23;
                end
            endcase
        end

        ///////////////////////////////////////////////////////////////////////
        // FANFARE sequence:
        //   0: G6   for 2^23
        //   1: C7   for 2^23
        //   2: E7   for 2^23
        //   3: G7   for 2^23 + 2^22
        //   4: E7   for 2^22
        //   5: G7   for 2^24
        ///////////////////////////////////////////////////////////////////////
        FANFARE: begin
            case (idx_q)
                3'd0: begin
                    cyc_limit = CYC_G6;
                    dur_limit = DUR_2P23;
                end
                3'd1: begin
                    cyc_limit = CYC_C7;
                    dur_limit = DUR_2P23;
                end
                3'd2: begin
                    cyc_limit = CYC_E7;
                    dur_limit = DUR_2P23;
                end
                3'd3: begin
                    cyc_limit = CYC_G7;
                    dur_limit = DUR_3P22;
                end
                3'd4: begin
                    cyc_limit = CYC_E7;
                    dur_limit = DUR_2P22;
                end
                default: begin
                    // idx 5 (or anything unexpected) plays the final G7
                    cyc_limit = CYC_G7;
                    dur_limit = DUR_2P24;
                end
            endcase
        end

        ///////////////////////////////////////////////////////////////////////
        // In IDLE the outputs are off anyway, but we still give safe defaults.
        ///////////////////////////////////////////////////////////////////////
        default: begin
            cyc_limit = CYC_G6;
            dur_limit = DUR_2P23;
        end
    endcase
end

///////////////////////////////////////////////////////////////////////////////
// NEXT-STATE / NEXT-DATA LOGIC
//
// This block decides what the NEXT values should be for:
//   - FSM state
//   - sequence index
//   - cycle counter
//   - duration counter
//
// Standard pattern:
//   start with "hold current value"
//   then override as needed
///////////////////////////////////////////////////////////////////////////////
always_comb begin
    // Default: hold present values
    state_d       = state_q;
    idx_d         = idx_q;
    cyc_counter_d = cyc_counter_q;
    dur_counter_d = dur_counter_q;

    case (state_q)

        ///////////////////////////////////////////////////////////////////////
        // IDLE
        //
        // No sound is playing.
        // Counters are kept reset to zero.
        //
        // Priority rule:
        //   batt_low has priority over fanfare
        ///////////////////////////////////////////////////////////////////////
        IDLE: begin
            idx_d         = 3'd0;
            cyc_counter_d = '0;
            dur_counter_d = '0;

            if (batt_low) begin
                state_d = BATTERY_LOW;
                idx_d   = 3'd0;
            end
            else if (fanfare) begin
                state_d = FANFARE;
                idx_d   = 3'd0;
            end
        end

        ///////////////////////////////////////////////////////////////////////
        // BATTERY_LOW
        //
        // Repeats a 3-note pattern as long as batt_low remains asserted.
        //
        // Behavior:
        //   - frequency counter runs continuously within the current note
        //   - duration counter tracks how long current note has played
        //   - when note duration expires, move to next note
        //   - if at last note (idx 2), wrap back to idx 0
        ///////////////////////////////////////////////////////////////////////
        BATTERY_LOW: begin

            // If battery is no longer low, stop the warning sound
            if (!batt_low) begin
                state_d       = IDLE;
                idx_d         = 3'd0;
                cyc_counter_d = '0;
                dur_counter_d = '0;
            end
            else begin
                ///////////////////////////////////////////////////////////////
                // Frequency counter:
                // Count from 0 up to cyc_limit-1, then wrap to 0.
                //
                // This forms the period of the square wave for the current note.
                ///////////////////////////////////////////////////////////////
                if (cyc_counter_q == cyc_limit - 1)
                    cyc_counter_d = '0;
                else
                    cyc_counter_d = cyc_counter_q + 1'b1;

                ///////////////////////////////////////////////////////////////
                // Duration counter:
                // Count how long the current note has been active.
                //
                // When it reaches dur_limit, advance to the next note and reset
                // both counters so the new note starts cleanly.
                ///////////////////////////////////////////////////////////////
                if (dur_counter_q + DUR_INC >= dur_limit) begin
                    dur_counter_d = '0;
                    cyc_counter_d = '0;

                    // 3-note repeating loop: 0 -> 1 -> 2 -> 0 -> ...
                    if (idx_q == 3'd2)
                        idx_d = 3'd0;
                    else
                        idx_d = idx_q + 1'b1;
                end
                else begin
                    dur_counter_d = dur_counter_q + DUR_INC;
                end
            end
        end

        ///////////////////////////////////////////////////////////////////////
        // FANFARE
        //
        // Plays the 6-note "Charge!" sequence once.
        //
        // Important behavior from the spec:
        //   once fanfare starts, let it complete
        //   do not preempt it in the middle
        //
        // So while in FANFARE, we ignore new fanfare pulses and do not jump
        // away immediately just because batt_low changes.
        // We only check batt_low after the final note finishes.
        ///////////////////////////////////////////////////////////////////////
        FANFARE: begin

            // Frequency counter for current note
            if (cyc_counter_q == cyc_limit - 1)
                cyc_counter_d = '0;
            else
                cyc_counter_d = cyc_counter_q + 1'b1;

            // When current fanfare note is done, move to next note
            if (dur_counter_q + DUR_INC >= dur_limit) begin
                dur_counter_d = '0;
                cyc_counter_d = '0;

                // If this was the final note in the fanfare...
                if (idx_q == 3'd5) begin
                    idx_d = 3'd0;

                    // After completing fanfare, if battery is low, switch into
                    // repeating battery-low warning. Otherwise go idle.
                    if (batt_low)
                        state_d = BATTERY_LOW;
                    else
                        state_d = IDLE;
                end
                else begin
                    // Otherwise continue through the 6-note sequence
                    idx_d = idx_q + 1'b1;
                end
            end
            else begin
                dur_counter_d = dur_counter_q + DUR_INC;
            end
        end

        ///////////////////////////////////////////////////////////////////////
        // Safety default
        ///////////////////////////////////////////////////////////////////////
        default: begin
            state_d       = IDLE;
            idx_d         = 3'd0;
            cyc_counter_d = '0;
            dur_counter_d = '0;
        end
    endcase
end

///////////////////////////////////////////////////////////////////////////////
// SEQUENTIAL STATE / REGISTER UPDATE
//
// On each positive clock edge:
//   q <= d
//
// On asynchronous reset:
//   clear everything back to a safe idle condition
///////////////////////////////////////////////////////////////////////////////
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state_q       <= IDLE;
        idx_q         <= '0;
        cyc_counter_q <= '0;
        dur_counter_q <= '0;
    end
    else begin
        state_q       <= state_d;
        idx_q         <= idx_d;
        cyc_counter_q <= cyc_counter_d;
        dur_counter_q <= dur_counter_d;
    end
end

///////////////////////////////////////////////////////////////////////////////
// PIEZO OUTPUT GENERATION
//
// piezo is driven as a square wave while not in IDLE.
//
// If cyc_counter is in the first half of the current note period,
// output 1. Otherwise output 0.
//
// That gives approximately 50% duty cycle.
//
// piezo_n is simply the inverted version so the piezo is driven
// differentially for larger swing / louder sound.
///////////////////////////////////////////////////////////////////////////////
always_comb begin
    if (state_q == IDLE)
        piezo = 1'b0;
    else if (cyc_counter_q < (cyc_limit >> 1))
        piezo = 1'b1;
    else
        piezo = 1'b0;
end

assign piezo_n = ~piezo;

endmodule