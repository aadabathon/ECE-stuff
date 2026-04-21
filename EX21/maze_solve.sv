module maze_solve(
    input  logic        clk,
    input  logic        rst_n,
    input  logic        cmd_md,
    input  logic        cmd0,
    input  logic        lft_opn,
    input  logic        rght_opn,
    input  logic        mv_cmplt,
    input  logic        sol_cmplt,
    output logic [11:0] dsrd_hdng,
    output logic        strt_hdng,
    output logic        strt_mv,
    output logic        stp_lft,
    output logic        stp_rght
);

    // FSM states for maze solving:
    // IDLE       : waiting for a maze solve command
    // START_MOVE : pulse navigate to begin moving forward
    // WAIT_MOVE  : wait for forward movement to complete
    // START_TURN : pulse navigate to begin heading change
    // WAIT_TURN  : wait for heading change to complete
    // DONE       : maze has been solved, wait for command mode to deassert/release
    typedef enum logic [2:0] {
        IDLE,
        START_MOVE,
        WAIT_MOVE,
        START_TURN,
        WAIT_TURN,
        DONE
    } state_t;

    state_t state, nxt_state;

    // Registered desired heading and next heading value.
    // This heading is what gets sent to the navigate block.
    logic [11:0] dsrd_hdng_nxt;

    // Turn decision encoding:
    // TURN_LEFT  -> rotate 90 degrees left
    // TURN_RIGHT -> rotate 90 degrees right
    // TURN_180   -> rotate 180 degrees
    // TURN_NONE  -> no heading change
    logic [1:0]  turn_sel, turn_sel_nxt;

    localparam logic [1:0] TURN_NONE  = 2'd0;
    localparam logic [1:0] TURN_LEFT  = 2'd1;
    localparam logic [1:0] TURN_RIGHT = 2'd2;
    localparam logic [1:0] TURN_180   = 2'd3;

    // Compute the next orthogonal heading for a left turn.
    function automatic logic [11:0] turn_left(input logic [11:0] h);
        case (h)
            12'h000: turn_left = 12'h3FF; // North -> West
            12'h3FF: turn_left = 12'h7FF; // West  -> South
            12'h7FF: turn_left = 12'hC00; // South -> East
            12'hC00: turn_left = 12'h000; // East  -> North
            default: turn_left = 12'h000;
        endcase
    endfunction

    // Compute the next orthogonal heading for a right turn.
    function automatic logic [11:0] turn_right(input logic [11:0] h);
        case (h)
            12'h000: turn_right = 12'hC00; // North -> East
            12'hC00: turn_right = 12'h7FF; // East  -> South
            12'h7FF: turn_right = 12'h3FF; // South -> West
            12'h3FF: turn_right = 12'h000; // West  -> North
            default: turn_right = 12'h000;
        endcase
    endfunction

    // Compute the next orthogonal heading for a 180 degree turn.
    function automatic logic [11:0] turn_180(input logic [11:0] h);
        case (h)
            12'h000: turn_180 = 12'h7FF; // North -> South
            12'h3FF: turn_180 = 12'hC00; // West  -> East
            12'h7FF: turn_180 = 12'h000; // South -> North
            12'hC00: turn_180 = 12'h3FF; // East  -> West
            default: turn_180 = 12'h000;
        endcase
    endfunction

    // Sequential logic for state, desired heading, and remembered turn decision.
    // Desired heading resets to North, matching the assumption that a maze solve
    // command is issued immediately after calibration.
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state      <= IDLE;
            dsrd_hdng  <= 12'h000;
            turn_sel   <= TURN_NONE;
        end
        else begin
            state      <= nxt_state;
            dsrd_hdng  <= dsrd_hdng_nxt;
            turn_sel   <= turn_sel_nxt;
        end
    end

    // Combinational next-state and output logic.
    always_comb begin
        // Hold current values by default.
        nxt_state     = state;
        dsrd_hdng_nxt = dsrd_hdng;
        turn_sel_nxt  = turn_sel;

        // Default control outputs are deasserted unless explicitly pulsed in a state.
        strt_hdng = 1'b0;
        strt_mv   = 1'b0;

        // Stop conditions are determined entirely by the selected affinity:
        // cmd0 = 1 -> left affinity
        // cmd0 = 0 -> right affinity
        stp_lft   = cmd0;
        stp_rght  = ~cmd0;

        case (state)

            // Wait here until command mode goes low, which starts the maze solve FSM.
            IDLE: begin
                turn_sel_nxt = TURN_NONE;
                if (!cmd_md)
                    nxt_state = START_MOVE;
            end

            // Pulse start-move for one cycle, then wait for the move to complete.
            START_MOVE: begin
                strt_mv   = 1'b1;
                nxt_state = WAIT_MOVE;
            end

            // Wait for navigate to report movement completion.
            // When complete:
            // 1. if solution is found, go to DONE
            // 2. otherwise decide which turn to make based on left/right affinity
            WAIT_MOVE: begin
                if (mv_cmplt) begin
                    if (sol_cmplt) begin
                        nxt_state = DONE;
                    end
                    else begin
                        // cmd0 = 1 -> left affinity
                        // Prefer left if open, else right if open, else turn around.
                        if (cmd0) begin
                            if (lft_opn)
                                turn_sel_nxt = TURN_LEFT;
                            else if (rght_opn)
                                turn_sel_nxt = TURN_RIGHT;
                            else
                                turn_sel_nxt = TURN_180;
                        end
                        // cmd0 = 0 -> right affinity
                        // Prefer right if open, else left if open, else turn around.
                        else begin
                            if (rght_opn)
                                turn_sel_nxt = TURN_RIGHT;
                            else if (lft_opn)
                                turn_sel_nxt = TURN_LEFT;
                            else
                                turn_sel_nxt = TURN_180;
                        end

                        nxt_state = START_TURN;
                    end
                end
            end

            // Pulse start-heading for one cycle and update the desired heading.
            // The heading written here depends on the previously selected turn direction.
            START_TURN: begin
                strt_hdng = 1'b1;

                case (turn_sel)
                    TURN_LEFT:  dsrd_hdng_nxt = turn_left(dsrd_hdng);
                    TURN_RIGHT: dsrd_hdng_nxt = turn_right(dsrd_hdng);
                    TURN_180:   dsrd_hdng_nxt = turn_180(dsrd_hdng);
                    default:    dsrd_hdng_nxt = dsrd_hdng;
                endcase

                nxt_state = WAIT_TURN;
            end

            // Wait for navigate to report the heading change is complete.
            // Once the turn is complete, begin the next forward movement.
            WAIT_TURN: begin
                if (mv_cmplt)
                    nxt_state = START_MOVE;
            end

            // Hold here once the maze is solved.
            // Return to IDLE once cmd_md is no longer actively requesting a solve.
            DONE: begin
                turn_sel_nxt = TURN_NONE;
                if (cmd_md)
                    nxt_state = IDLE;
            end

            default: begin
                nxt_state     = IDLE;
                dsrd_hdng_nxt = 12'h000;
                turn_sel_nxt  = TURN_NONE;
            end
        endcase
    end

endmodule