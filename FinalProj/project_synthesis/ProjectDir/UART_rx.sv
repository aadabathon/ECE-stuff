module UART_rx (
    input  logic clk,
    input  logic rst_n,
    input  logic RX,
    input  logic clr_rdy,
    output logic [7:0] rx_data,
    output logic rdy
);

    // State encoding and internal signals
    typedef enum logic { IDLE, RECEIVE } state_t;
    state_t state, nxt_state;

    logic rx_sync, rx_ff;
    logic start;
    logic receiving;
    logic set_rdy;
    logic shift;
    logic [11:0] baud_cnt;
    logic [3:0]  bit_cnt;
    logic [8:0]  rx_shft_reg;

    // Double flip-flop synchronizer for RX input to avoid metastability
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rx_sync <= 1'b1;
            rx_ff   <= 1'b1;
        end else begin
            rx_sync <= RX;
            rx_ff   <= rx_sync;
        end
    end

    // ---------------------------------------------------------------
    // FSM state register
    // ---------------------------------------------------------------
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) state <= IDLE;
        else        state <= nxt_state;
    end

    always_comb begin
        start     = 1'b0;
        receiving = 1'b0;
        set_rdy   = 1'b0;
        nxt_state = state;

        case (state)
            IDLE: begin
                if (!rx_ff) begin
                    start     = 1'b1;
                    nxt_state = RECEIVE;
                end
            end

            RECEIVE: begin
                receiving = 1'b1;
                // Trigger rdy and return to IDLE after mid-stop bit
                if (shift && bit_cnt == 4'd9) begin
                    set_rdy   = 1'b1;
                    nxt_state = IDLE; 
                end
            end

            default: nxt_state = IDLE;
        endcase
    end

    // ---------------------------------------------------------------
    // Baud counter (counts DOWN to 0)
    //   start : load half-baud (1301) so first sample is mid-start-bit
    //   shift : reload full-baud-1 (2603) for each subsequent bit
    // ---------------------------------------------------------------
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            baud_cnt <= 12'h000;
        else if (start)
            baud_cnt <= 12'd1301;
        else if (shift)
            baud_cnt <= 12'd2603;
        else if (receiving)
            baud_cnt <= baud_cnt - 1;
    end

    assign shift = receiving && (baud_cnt == 12'h000);

    // ---------------------------------------------------------------
    // Bit counter
    // ---------------------------------------------------------------
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            bit_cnt <= 4'h0;
        else if (start)
            bit_cnt <= 4'h0;
        else if (shift)
            bit_cnt <= bit_cnt + 1;
    end

    // ---------------------------------------------------------------
    // Receive shift register
    //
    // New bit enters at [8], existing bits shift right toward [0].
    // After shift 10 (mid-stop): [8]=Stop, [7]=D7, ..., [0]=D0
    // rx_data = rx_shft_reg[7:0] = {D7..D0}
    // ---------------------------------------------------------------
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            rx_shft_reg <= 9'h1FF;
        else if (shift)
            rx_shft_reg <= {rx_ff, rx_shft_reg[8:1]};
    end

    // Mapped strictly to [7:0] as Start bit falls out and Stop bit sits in [8]
    assign rx_data = rx_shft_reg[7:0];

    // ---------------------------------------------------------------
    // rdy SR flip-flop
    // ---------------------------------------------------------------
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            rdy <= 1'b0;
        else if (start || clr_rdy)
            rdy <= 1'b0;
        else if (set_rdy)
            rdy <= 1'b1;
    end

endmodule