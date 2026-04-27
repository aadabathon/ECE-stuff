`timescale 1ns/1ps

module SPI_main(
    input  logic        clk,
    input  logic        rst_n,
    input  logic        wrt,
    input  logic [15:0] wt_data,
    input  logic        MISO,   // Main In Secondary Out: data coming back from the slave
    output logic        SS_n,   // Slave Select, active low
    output logic        SCLK,   // Serial Clock
    output logic        MOSI,   // Main Out Secondary In: data sent to the slave
    output logic        done,
    output logic [15:0] rd_data
);

    // FSM (finite state machine) states
    // IDLE   : waiting for a transaction request
    // ACTIVE : transaction in progress, divider running, SCLK toggling
    // FINISH : special end state to do the final internal shift and deassert SS_n
    typedef enum logic [1:0] {IDLE, ACTIVE, FINISH} state_t;
    state_t state, nxt_state;

    // SCLK_div:
    // 5-bit divider used to generate the slower SPI timing from the faster system clock.
    // Its MSB is used as SCLK.
    logic [4:0]  SCLK_div;

    // shft_reg:
    // Holds the outgoing command/data and gradually gets overwritten by incoming MISO bits.
    logic [15:0] shft_reg;

    // bit_cntr:
    // Counts how many actual shifts have happened.
    // Used to know when we are on the final bit.
    logic [3:0]  bit_cntr;

    // MISO_smpl:
    // A one-bit register that captures MISO at the sample point.
    // This is important because sampling and shifting happen at different internal moments.
    logic        MISO_smpl;

    // FSM-generated control signals
    logic ld_SCLK, init, shft, set_done, clr_done;
    logic set_SS_n, clr_SS_n;

    // Timing/event decode signals
    logic smpl, shft_imm, done15;

    // front_porch_done:
    // This is the key "skip the first fall" flag.
    // The very first falling edge after SS_n goes low is just the front porch.
    // We are NOT supposed to shift there.
    logic front_porch_done;

    // SCLK is the MSB of the divider.
    // As the divider counts, this bit toggles slowly enough to act as the SPI clock.
    assign SCLK = SCLK_div[4];

    // MOSI always drives the current MSB of the shift register.
    // As shft_reg shifts left, the next outgoing bit appears on MOSI.
    assign MOSI = shft_reg[15];

    // At the end of the transfer, rd_data is just the final value of the shift register.
    assign rd_data = shft_reg;

    // smpl:
    // Internal event chosen to line up with the rising edge of SCLK.
    // This is when we sample MISO.
    assign smpl     = (SCLK_div == 5'b01111);

    // shft_imm:
    // Internal event chosen to line up with the falling edge of SCLK.
    // This is when we normally shift the register.
    assign shft_imm = (SCLK_div == 5'b11111);

    // done15:
    // True once 15 shifts have already occurred.
    // That means the next sampled bit is the 16th/final bit.
    assign done15   = &bit_cntr;

    // State register
    always_ff @(posedge clk, negedge rst_n) begin
        if (!rst_n)
            state <= IDLE;
        else
            state <= nxt_state;
    end

    // FSM next-state logic and combinational control output logic
    always_comb begin
        nxt_state = state;

        // Default all control signals low unless a state explicitly asserts them
        ld_SCLK   = 1'b0;
        init      = 1'b0;
        shft      = 1'b0;
        set_done  = 1'b0;
        clr_done  = 1'b0;
        set_SS_n  = 1'b0;
        clr_SS_n  = 1'b0;

        case (state)

            IDLE: begin
                // If wrt is asserted, begin a new SPI transaction.
                if (wrt) begin
                    nxt_state = ACTIVE;

                    // Load/preload the divider so SCLK starts in the correct phase.
                    ld_SCLK   = 1'b1;

                    // Load wt_data into the shift register and reset helper state.
                    init      = 1'b1;

                    // done should clear when a new transaction starts.
                    clr_done  = 1'b1;

                    // Assert SS_n low to select the slave.
                    clr_SS_n  = 1'b1;
                end
                else begin
                    // While idle and not starting a transfer, keep SS_n high.
                    set_SS_n  = 1'b1;
                end
            end

            ACTIVE: begin
                // Normal shifting behavior:
                // shift on the falling-edge event, EXCEPT for the first one.
                if (shft_imm) begin
                    if (!front_porch_done) begin
                        // First fall after SS_n goes low:
                        // this is the front porch, so DO NOT shift yet.
                    end
                    else begin
                        // After front porch is consumed, every later shft_imm does a real shift.
                        shft = 1'b1;
                    end
                end

                // This is the critical end condition:
                // leave ACTIVE on the LAST SAMPLE, not on the next falling-edge event.
                //
                // Why?
                // Because once the final bit is sampled, we want to prevent one more external SCLK fall.
                // Then FINISH can do one final INTERNAL shift while ending the transaction.
                if (smpl && done15) begin
                    nxt_state = FINISH;
                end
            end

            FINISH: begin
                // FINISH is the special "end the transfer cleanly" state.
                //
                // We do 3 things together:
                // 1. deassert SS_n (transaction ends)
                // 2. perform the final shift to insert the last sampled MISO bit
                // 3. assert done
                //
                // This matches the intended timing:
                // last bit sampled on final SCLK rise,
                // then transaction ends,
                // then final internal shift happens without allowing another SCLK fall.
                set_SS_n  = 1'b1;
                shft      = 1'b1;
                set_done  = 1'b1;
                nxt_state = IDLE;
            end

            default: begin
                nxt_state = IDLE;
            end
        endcase
    end

    // Divider / SPI clock generation
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            // Reset divider to a value whose MSB keeps SCLK high.
            SCLK_div <= 5'b10111;
        else if (ld_SCLK)
            // On new transaction, preload divider so the first timing is correct.
            SCLK_div <= 5'b10111;
        else if (state == ACTIVE)
            // Only count while ACTIVE.
            // This is what makes SCLK actually toggle during a transaction.
            SCLK_div <= SCLK_div + 5'd1;
        else
            // Outside ACTIVE, force divider back to its resting preload.
            // This keeps SCLK high in IDLE/FINISH.
            SCLK_div <= 5'b10111;
    end

    // Sample MISO near the rising edge of SCLK
    always_ff @(posedge clk, negedge rst_n) begin
        if (!rst_n)
            MISO_smpl <= 1'b0;
        else if (smpl)
            MISO_smpl <= MISO;
    end

    // Main shift register
    always_ff @(posedge clk, negedge rst_n) begin
        if (!rst_n)
            shft_reg <= 16'h0000;
        else if (init)
            // At transaction start, load the outgoing 16-bit word.
            shft_reg <= wt_data;
        else if (shft)
            // Shift left and insert the previously sampled MISO bit into the LSB.
            shft_reg <= {shft_reg[14:0], MISO_smpl};
    end

    // Bit counter
    always_ff @(posedge clk, negedge rst_n) begin
        if (!rst_n)
            bit_cntr <= 4'h0;
        else if (init)
            // Reset count at the start of each transaction.
            bit_cntr <= 4'h0;
        else if (shft)
            // Count each actual shift.
            bit_cntr <= bit_cntr + 4'h1;
    end

    // done flag
    always_ff @(posedge clk, negedge rst_n) begin
        if (!rst_n)
            done <= 1'b0;
        else if (clr_done)
            done <= 1'b0;
        else if (set_done)
            done <= 1'b1;
    end

    // Registered SS_n
    // Registering SS_n avoids combinational glitches.
    always_ff @(posedge clk, negedge rst_n) begin
        if (!rst_n)
            SS_n <= 1'b1;
        else if (set_SS_n)
            SS_n <= 1'b1;
        else if (clr_SS_n)
            SS_n <= 1'b0;
    end

    // front_porch_done tracking
    always_ff @(posedge clk, negedge rst_n) begin
        if (!rst_n)
            front_porch_done <= 1'b0;
        else if (init)
            // New transaction: front porch has not been consumed yet.
            front_porch_done <= 1'b0;
        else if (state == ACTIVE && shft_imm && !front_porch_done)
            // The first falling-edge event marks the front porch as consumed.
            // After this, future shft_imm events cause real shifts.
            front_porch_done <= 1'b1;
    end

endmodule