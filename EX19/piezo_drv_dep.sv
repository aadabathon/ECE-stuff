module piezo_drv #(
    parameter bit FAST_SIM = 0
)(
    input  logic clk, //50 MHz
    input  logic rst_n,
    input  logic batt_low,
    input  logic fanfare,
    output logic piezo,
    output logic piezo_n
);

typedef enum logic [1:0] {
    IDLE        = 2'b00,
    BATTERY_LOW = 2'b01,
    FANFARE     = 2'b10
} state_t;

typedef enum logic [1:0] {
    G6,
    C7,
    E7,
    G7
} note_t;

localparam logic [15:0] CYC_G6 = 16'd31888;
localparam logic [15:0] CYC_C7 = 16'd23889;
localparam logic [15:0] CYC_E7 = 16'd18961;
localparam logic [15:0] CYC_G7 = 16'd15944;

localparam int DURATION = (1 << 24) / (FAST_SIM ? 16 : 1);

logic [23:0] dur_counter_ff;
logic [15:0] cyc_counter_ff;
logic dur_counter_rst, cyc_counter_rst;

state_t state_q, state_d;

task automatic play_note(input note_t i, input int dur);
    logic [15:0] cyc;
    case (i)
        G6: cyc = CYC_G6;
        C7: cyc = CYC_C7;
        E7: cyc = CYC_E7;
        G7: cyc = CYC_G7;
        default: cyc = CYC_G6;
    endcase
endtask

always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) dur_counter_ff <= '0;
    else if (dur_counter_rst) dur_counter_ff <= '0;
    else dur_counter_ff <= dur_counter_ff + 1'b1;
end

always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) cyc_counter_ff <= '0;
    else if (cyc_counter_rst) cyc_counter_ff <= '0;
    else cyc_counter_ff <= cyc_counter_ff + 1'b1;
end

always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) state_q <= IDLE;
    else state_q <= state_d;
end

always_comb begin
    state_d = state_q;
    piezo = '0;
    piezo_n = '1;

    case (state_q)
        IDLE: begin
            if (batt_low) state_d = BATTERY_LOW;
            else if (fanfare) state_d = FANFARE;
            else state_d = IDLE;
        end
        BATTERY_LOW: begin
        end
        FANFARE: begin
        end
        default: begin
            state_d = IDLE;
        end
    endcase
end

endmodule