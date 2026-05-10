module UART_tx (
    input logic clk,           // 50MHz system clock [cite: 27]
    input logic rst_n,         // Active low reset [cite: 27]
    input logic trmt,          // Initiate transmission [cite: 27]
    input logic [7:0] tx_data, // Byte to transmit [cite: 27]
    output logic tx,           // Serial data output [cite: 27]
    output logic tx_done       // Asserted when byte is done [cite: 27]
);

    // State encoding
    typedef enum logic { IDLE, TRANSMITTING } state_t;
    state_t state, next_state;

    // Control signals
    logic shift, init, transmitting, set_done;
    logic [3:0] bit_cnt; 
    logic [11:0] baud_cnt; 
    logic [8:0] tx_shft_reg; // Holds {tx_data, start_bit}

    // --- Baud Counter 
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) 
            baud_cnt <= 12'h000;
        else if (init || shift) 
            baud_cnt <= 12'h000; // Reset on init or completion of a bit [cite: 111]
        else if (transmitting)
            baud_cnt <= baud_cnt + 1;
    end
    assign shift = (baud_cnt == 12'd2604); // Baud rate timing 

    // --- Bit Counter 
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            bit_cnt <= 4'h0;
        else if (init)
            bit_cnt <= 4'h0; // Reset for new frame [cite: 104]
        else if (shift)
            bit_cnt <= bit_cnt + 1; // Increment only on shift pulse [cite: 104]
    end

    // --- Shift Register 
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            tx_shft_reg <= 9'h1FF; 
        else if (init)
            tx_shft_reg <= {tx_data, 1'b0}; // Load data and start bit 
        else if (shift)
            tx_shft_reg <= {1'b1, tx_shft_reg[8:1]}; // Shift right, fill with stop bit (1) 
    end
    
    // TX is LSB of shift register. If not transmitting, it should be 1 (Idle).
    assign tx = transmitting ? tx_shft_reg[0] : 1'b1;

    // --- tx_done SR Flip-Flop  ---
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            tx_done <= 1'b0;
        else if (init)
            tx_done <= 1'b0; // Clear on start
        else if (set_done)
            tx_done <= 1'b1; // Set on completion
    end

    // --- FSM Logic 
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) state <= IDLE;
        else        state <= next_state;
    end

    always_comb begin
        init = 0;
        transmitting = 0;
        set_done = 0;
        next_state = state;

        case (state)
            IDLE: begin
                if (trmt) begin
                    init = 1;
                    next_state = TRANSMITTING;
                end
            end
            TRANSMITTING: begin
                transmitting = 1;
                if (bit_cnt == 4'd10) begin // 1 start + 8 data + 1 stop 
                    set_done = 1;
                    next_state = IDLE;
                end
            end
        endcase
    end
endmodule