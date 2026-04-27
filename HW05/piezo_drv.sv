module piezo_drv #( //The Goopers hw05.
    // speeds up note timing in sim
    parameter bit FAST_SIM = 0
)(
    input  logic clk,
    input  logic rst_n,
    input  logic batt_low,
    input  logic fanfare,
    output logic piezo,
    output logic piezo_n
);

// mode select
typedef enum logic [1:0] {
    IDLE,
    BATTERY_LOW,
    FANFARE
} state_t;

state_t state_q, state_d;

// note index
logic [2:0] idx_q, idx_d;

// pitch + duration counters
logic [15:0] cyc_counter_q, cyc_counter_d;
logic [24:0] dur_counter_q, dur_counter_d;

// current note settings
logic [15:0] cyc_limit;
logic [24:0] dur_limit;

// note periods
localparam logic [15:0] CYC_G6 = 16'd31888;
localparam logic [15:0] CYC_C7 = 16'd23889;
localparam logic [15:0] CYC_E7 = 16'd18961;
localparam logic [15:0] CYC_G7 = 16'd15944;

// note lengths
localparam logic [24:0] DUR_2P22 = 25'd4194304;
localparam logic [24:0] DUR_2P23 = 25'd8388608;
localparam logic [24:0] DUR_3P22 = 25'd12582912;
localparam logic [24:0] DUR_2P24 = 25'd16777216;

// sim speedup
localparam logic [24:0] DUR_INC = FAST_SIM ? 25'd16 : 25'd1;

// pick current note
always_comb begin
    cyc_limit = CYC_G6;
    dur_limit = DUR_2P23;

    case (state_q)
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
                    cyc_limit = CYC_E7;
                    dur_limit = DUR_2P23;
                end
            endcase
        end

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
                    cyc_limit = CYC_G7;
                    dur_limit = DUR_2P24;
                end
            endcase
        end

        default: begin
            cyc_limit = CYC_G6;
            dur_limit = DUR_2P23;
        end
    endcase
end

// next-state logic
always_comb begin
    state_d       = state_q;
    idx_d         = idx_q;
    cyc_counter_d = cyc_counter_q;
    dur_counter_d = dur_counter_q;

    case (state_q)
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

        BATTERY_LOW: begin
            if (!batt_low) begin
                state_d       = IDLE;
                idx_d         = 3'd0;
                cyc_counter_d = '0;
                dur_counter_d = '0;
            end
            else begin
                if (cyc_counter_q == cyc_limit - 1)
                    cyc_counter_d = '0;
                else
                    cyc_counter_d = cyc_counter_q + 1'b1;

                if (dur_counter_q + DUR_INC >= dur_limit) begin
                    dur_counter_d = '0;
                    cyc_counter_d = '0;

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

        FANFARE: begin
            if (cyc_counter_q == cyc_limit - 1)
                cyc_counter_d = '0;
            else
                cyc_counter_d = cyc_counter_q + 1'b1;

            if (dur_counter_q + DUR_INC >= dur_limit) begin
                dur_counter_d = '0;
                cyc_counter_d = '0;

                if (idx_q == 3'd5) begin
                    idx_d = 3'd0;

                    if (batt_low)
                        state_d = BATTERY_LOW;
                    else
                        state_d = IDLE;
                end
                else begin
                    idx_d = idx_q + 1'b1;
                end
            end
            else begin
                dur_counter_d = dur_counter_q + DUR_INC;
            end
        end

        default: begin
            state_d       = IDLE;
            idx_d         = 3'd0;
            cyc_counter_d = '0;
            dur_counter_d = '0;
        end
    endcase
end

// registers
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

// square-wave output
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