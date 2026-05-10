module maze_solve(
    input  logic        clk,
    input  logic        rst_n,

    input  logic        cmd_md,
    input  logic        cmd0,

    input  logic        lft_opn,
    input  logic        rght_opn,

    input  logic        mv_cmplt,
    input  logic        sol_cmplt,

    output logic        strt_hdng,
    output logic [11:0] dsrd_hdng,

    output logic        strt_mv,

    output logic        stp_lft,
    output logic        stp_rght
);

logic [11:0] dsrd_hdng_next;

typedef enum logic [2:0] {
    IDLE,
    START_MOVE,
    MOVE_UNTIL_OPN,
    START_HEADING,
    TURN
} state_t;

enum logic [11:0] {
    NORTH = 12'h000,
    EAST  = 12'hC00,
    SOUTH = 12'h7FF,
    WEST  = 12'h3FF
} direction;

state_t state, next_state;

always_ff @(posedge clk or negedge rst_n) begin : blockName
    if (!rst_n) begin
        state <= IDLE;
    end else begin
        state <= next_state;
    end
end
// Register to hold the desired heading, initialized to NORTH
// Need to use a register to hold the desired heading across clock cycles
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) dsrd_hdng <= NORTH;
    else dsrd_hdng <= dsrd_hdng_next;
end
always_comb begin
    // Default outputs
    strt_hdng = 0;
    dsrd_hdng_next = dsrd_hdng;
    strt_mv = 0;
    stp_lft = 0;
    stp_rght = 0;
    next_state = state;
    stp_lft = cmd0;
    stp_rght = ~cmd0;
    case (state)
        IDLE: begin
            if (!cmd_md) begin
                next_state = START_MOVE;
            end 
        end
        START_MOVE : begin
            strt_mv = 1;
            next_state = MOVE_UNTIL_OPN;
        end
        MOVE_UNTIL_OPN: begin
            // Stop on either opening; cmd0 is only a preference when both sides are open.
            //stp_lft = cmd0;
            //stp_rght = ~cmd0;
            if(sol_cmplt) begin
                next_state = IDLE;
            end 
            else if (mv_cmplt) begin
                next_state = START_HEADING;
                // Choose turn direction from actual openings.
                // If both are open, cmd0 selects preference: 1=left, 0=right.
                if (lft_opn && rght_opn) begin
                    if (cmd0) begin
                        case(dsrd_hdng)
                            NORTH: dsrd_hdng_next = WEST;
                            EAST:  dsrd_hdng_next = NORTH;
                            SOUTH: dsrd_hdng_next = EAST;
                            WEST:  dsrd_hdng_next = SOUTH;
                        endcase
                    end else begin
                        case(dsrd_hdng)
                            NORTH: dsrd_hdng_next = EAST;
                            EAST:  dsrd_hdng_next = SOUTH;
                            SOUTH: dsrd_hdng_next = WEST;
                            WEST:  dsrd_hdng_next = NORTH;
                        endcase
                    end
                end else if (lft_opn) begin
                    case(dsrd_hdng)
                        NORTH: dsrd_hdng_next = WEST;
                        EAST:  dsrd_hdng_next = NORTH;
                        SOUTH: dsrd_hdng_next = EAST;
                        WEST:  dsrd_hdng_next = SOUTH;
                    endcase
                end else if (rght_opn) begin
                    case(dsrd_hdng)
                        NORTH: dsrd_hdng_next = EAST;
                        EAST:  dsrd_hdng_next = SOUTH;
                        SOUTH: dsrd_hdng_next = WEST;
                        WEST:  dsrd_hdng_next = NORTH;
                    endcase
                end else begin
                    // Turn around if both paths are blocked.
                    case(dsrd_hdng)
                        NORTH: dsrd_hdng_next = SOUTH;
                        EAST:  dsrd_hdng_next = WEST;
                        SOUTH: dsrd_hdng_next = NORTH;
                        WEST:  dsrd_hdng_next = EAST;
                    endcase
                end
            end 
        end
        START_HEADING: begin
            strt_hdng = 1;
            next_state = TURN;
        end
        TURN : begin 
            if(mv_cmplt) begin
                next_state = START_MOVE;
            end
        end
    endcase
end
endmodule