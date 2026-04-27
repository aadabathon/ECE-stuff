module UART_wrapper(
    input  logic clk, rst_n,           // 50 MHz clock, active-low asynchronous reset
    input  logic RX,                   // UART receive line from Bluetooth module
    input  logic clr_cmd_rdy,          // Consumer clears cmd_rdy after command is consumed
    input  logic trmt,                 // Pulse high to transmit resp back out over UART
    input  logic [7:0] resp,           // 1-byte response / ack to transmit
    output logic TX,                   // UART transmit line back to Bluetooth module
    output logic cmd_rdy,              // Asserted when a full 16-bit command has been received
    output logic tx_done,              // Pulses when resp transmission completes
    output logic [15:0] cmd            // Reconstructed 16-bit command: high byte first, low byte second
);

    logic [7:0] rx_data_i;             // Byte received from internal UART receiver
    logic load_high, load_low;         // Control signals to load upper/lower byte of cmd
    logic clr_rx_rdy, rx_rdy;          // Handshake with UART receiver
    logic cmd_rdy_d;                   // Next-state value for cmd_rdy

    // FSM states:
    // WAIT_HIGH -> waiting for first byte of command
    // WAIT_LOW  -> waiting for second byte of command
    // CMD_RDY   -> full 16-bit command available, waiting for consumer to clear
    typedef enum logic [1:0] {
        WAIT_HIGH = 2'b00,
        WAIT_LOW  = 2'b01,
        CMD_RDY   = 2'b10
    } UART_STATE_T;

    UART_STATE_T uart_state_q, uart_state_d;

    // Underlying 8-bit UART transceiver.
    // RX side gives us one byte at a time with rx_rdy.
    // TX side simply forwards resp when trmt is pulsed.
    UART uart1(
        .clk(clk),
        .rst_n(rst_n),
        .RX(RX),
        .TX(TX),
        .rx_rdy(rx_rdy),
        .clr_rx_rdy(clr_rx_rdy),
        .rx_data(rx_data_i),
        .trmt(trmt),
        .tx_data(resp),
        .tx_done(tx_done)
    );

    // 16-bit command register.
    // First received byte is stored in cmd[15:8],
    // second received byte is stored in cmd[7:0].
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            cmd <= 16'h0000;
        else begin
            if (load_high) cmd[15:8] <= rx_data_i;
            if (load_low)  cmd[7:0]  <= rx_data_i;
        end
    end

    // Sticky command-ready flag.
    // Set once full command is assembled, and held until clr_cmd_rdy is asserted.
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            cmd_rdy <= 1'b0;
        else
            cmd_rdy <= cmd_rdy_d;
    end

    // State register for receive-side command assembly FSM
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            uart_state_q <= WAIT_HIGH;
        else
            uart_state_q <= uart_state_d;
    end

    // Next-state and control logic
    always_comb begin
        // Safe defaults
        uart_state_d = uart_state_q;
        cmd_rdy_d    = cmd_rdy;    // hold cmd_rdy unless explicitly changed
        clr_rx_rdy   = 1'b0;
        load_high    = 1'b0;
        load_low     = 1'b0;

        case (uart_state_q)

            // Waiting for first byte of 16-bit command.
            // Since spec says high byte arrives first, store into cmd[15:8].
            WAIT_HIGH: begin
                if (rx_rdy) begin
                    load_high    = 1'b1;
                    clr_rx_rdy   = 1'b1;      // acknowledge byte consumed
                    uart_state_d = WAIT_LOW;  // next byte will be low byte
                end
            end

            // Waiting for second byte of 16-bit command.
            // Store into cmd[7:0], then raise cmd_rdy.
            WAIT_LOW: begin
                if (rx_rdy) begin
                    load_low     = 1'b1;
                    clr_rx_rdy   = 1'b1;      // acknowledge byte consumed
                    cmd_rdy_d    = 1'b1;      // full command now available
                    uart_state_d = CMD_RDY;
                end
            end

            // Full command has been received.
            // Hold cmd_rdy high until external logic clears it.
            CMD_RDY: begin
                if (clr_cmd_rdy) begin
                    cmd_rdy_d    = 1'b0;
                    uart_state_d = WAIT_HIGH; // ready for next command
                end
            end

            // Recovery default
            default: begin
                uart_state_d = WAIT_HIGH;
                cmd_rdy_d    = 1'b0;
            end
        endcase
    end

endmodule