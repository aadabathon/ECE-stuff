module cmd_proc(
    input logic clk,
    input logic rst_n,
    input wire [15:0] cmd,
    input wire cmd_rdy,
    output logic clr_cmd_rdy,
    output logic send_resp,
    // ------------------------------
    output logic strt_cal,
    input logic cal_done,
    output logic in_cal,
    // ------------------------------
    output logic strt_hdng,
    output logic strt_mv,
    output logic stp_lft,
    output logic stp_rght,
    output logic [11:0] dsrd_hdng,
    input logic mv_cmplt,
    // ------------------------------
    output logic cmd_md,
    //-------------------------------
    input logic sol_cmplt
);

typedef enum logic [2:0] {
    IDLE,
    EXECUTE,
    CAL,
    HDNG,
    MVNG} 
    state_t;
state_t state, next_state;

always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) state <= IDLE;
    else state <= next_state;
end

// Flop dsrd_hdng so it persists after leaving HDNG state
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) dsrd_hdng <= 12'h000;
    else if (state == EXECUTE && cmd[15:13] == 3'b001)
        dsrd_hdng <= cmd[11:0];
end

always_comb begin
    //Default values
    next_state = state;
    clr_cmd_rdy = 0;
    send_resp = 0;
    strt_cal = 0;
    in_cal = 0;
    strt_hdng = 0;
    strt_mv = 0;
    stp_lft = 0;
    stp_rght = 0;
    cmd_md = 1;
    case(state)
        IDLE : begin
            if (cmd_rdy) begin
                next_state = EXECUTE;
                clr_cmd_rdy = 1;
            end
        end
        EXECUTE : begin
            casex(cmd[15:13])
                3'b000 : begin
                    strt_cal = 1;
                    next_state = CAL;
                end
                3'b001 : begin
                    strt_hdng = 1;
                    next_state = HDNG;
                end
                3'b010 : begin
                    strt_mv = 1;
                    next_state = MVNG;
                end
                //Solve cmd does not need its own state
                3'b011 : begin
                    cmd_md = 0;
                    if(sol_cmplt) next_state = IDLE;
                end
            endcase
        end
        CAL : begin
            in_cal = 1;
            if(cal_done) begin
                send_resp = 1;
                next_state = IDLE;
            end
        end
        HDNG : begin
            if (mv_cmplt) begin
                send_resp = 1;
                next_state = IDLE;
            end
        end
        MVNG : begin
            if (cmd[1]) stp_lft = 1;
            else if (cmd[0]) stp_rght = 1;
            if(mv_cmplt) begin
                send_resp = 1;
                next_state = IDLE;
            end
        end
    endcase
end
endmodule