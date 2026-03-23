module SPI_main(
    input  logic        clk,
    input  logic        rst_n,
    input  logic        wrt,
    input  logic [15:0] wt_data,
    input  logic        MISO,
    output logic        SS_n,
    output logic        SCLK,
    output logic        MOSI,
    output logic        done,
    output logic [15:0] rd_data
);

    typedef enum logic [1:0] {IDLE, ACTIVE, FINISH} state_t;
    state_t state, nxt_state;

    logic [4:0]  SCLK_div;
    logic [15:0] shft_reg;
    logic [3:0]  bit_cntr;
    logic        MISO_smpl;

    logic ld_SCLK, init, shft, set_done, clr_done;
    logic set_SS_n, clr_SS_n;
    logic smpl, shft_imm, done15;

    // SCLK is generated from the MSB of the divider so it toggles slowly
    assign SCLK = SCLK_div[4];

    // MOSI always drives the current MSB of the shift register
    assign MOSI = shft_reg[15];

    // Received data is just the final contents of the shift register
    assign rd_data = shft_reg;

    // Sample point for MISO: near the rising edge of SCLK
    assign smpl     = (SCLK_div == 5'b01111);

    // Shift point: near the falling edge of SCLK
    assign shft_imm = (SCLK_div == 5'b11111);

    // Indicates 15 shifts have already occurred, so the next one is the last
    assign done15   = &bit_cntr;

    // State register
    always_ff @(posedge clk, negedge rst_n) begin
        if (!rst_n)
            state <= IDLE;
        else
            state <= nxt_state;
    end

    // FSM next-state logic and control outputs
    always_comb begin
        nxt_state = state;

        ld_SCLK   = 1'b0;
        init      = 1'b0;
        shft      = 1'b0;
        set_done  = 1'b0;
        clr_done  = 1'b0;
        set_SS_n  = 1'b0;
        clr_SS_n  = 1'b0;

        case (state)
            IDLE: begin
                // Keep slave deselected when idle
                set_SS_n = 1'b1;

                // Start a new transaction when wrt is asserted
                if (wrt) begin
                    nxt_state = ACTIVE;
                    ld_SCLK   = 1'b1;
                    init      = 1'b1;
                    clr_done  = 1'b1;
                    clr_SS_n  = 1'b1;
                end
            end

            ACTIVE: begin
                // Shift once per full SCLK period at the shift point
                if (shft_imm) begin
                    if (done15)
                        nxt_state = FINISH;
                    else
                        shft = 1'b1;
                end
            end

            FINISH: begin
                // Perform the final shift so the last received bit enters rd_data
                shft      = 1'b1;
                set_done  = 1'b1;
                nxt_state = IDLE;
            end

            default: begin
                nxt_state = IDLE;
            end
        endcase
    end

    // Divider used to generate SPI clock timing
    // It is preloaded so SCLK starts high and the transfer begins with a front porch
    always_ff @(posedge clk, negedge rst_n) begin
        if (!rst_n)
            SCLK_div <= 5'b10111;
        else if (ld_SCLK)
            SCLK_div <= 5'b10111;
        else if (state == ACTIVE)
            SCLK_div <= SCLK_div + 5'd1;
        else
            SCLK_div <= 5'b10111;
    end

    // Sample incoming MISO data before shifting it into the register
    always_ff @(posedge clk, negedge rst_n) begin
        if (!rst_n)
            MISO_smpl <= 1'b0;
        else if (smpl)
            MISO_smpl <= MISO;
    end

    // Shift register holds both transmitted and received data
    // On init, load the transmit word
    // On each shift, move left and insert sampled MISO into the LSB
    always_ff @(posedge clk, negedge rst_n) begin
        if (!rst_n)
            shft_reg <= 16'h0000;
        else if (init)
            shft_reg <= wt_data;
        else if (shft)
            shft_reg <= {shft_reg[14:0], MISO_smpl};
    end

    // Bit counter counts completed shifts
    always_ff @(posedge clk, negedge rst_n) begin
        if (!rst_n)
            bit_cntr <= 4'h0;
        else if (init)
            bit_cntr <= 4'h0;
        else if (shft)
            bit_cntr <= bit_cntr + 4'h1;
    end

    // done goes high at the end of a transaction
    // It stays high until the next wrt clears it
    always_ff @(posedge clk, negedge rst_n) begin
        if (!rst_n)
            done <= 1'b0;
        else if (clr_done)
            done <= 1'b0;
        else if (set_done)
            done <= 1'b1;
    end

    // SS_n is registered so it does not glitch from combinational FSM outputs
    // High when idle, low during an active SPI transaction
    always_ff @(posedge clk, negedge rst_n) begin
        if (!rst_n)
            SS_n <= 1'b1;
        else if (set_SS_n)
            SS_n <= 1'b1;
        else if (clr_SS_n)
            SS_n <= 1'b0;
    end

endmodule