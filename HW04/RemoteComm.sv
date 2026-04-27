module RemoteComm(
    input  logic        clk,        // system clock
    input  logic        rst_n,      // active-low asynchronous reset
    input  logic        RX,         // serial line coming back from UART_wrapper TX
    input  logic [15:0] cmd,        // 16-bit command to send
    input  logic        snd_cmd,    // pulse high to start sending cmd
    output logic        TX,         // serial line driving UART_wrapper RX
    output logic        cmd_snt,    // goes high after both command bytes are fully sent
    output logic [7:0]  resp,       // 1-byte response received back from UART_wrapper
    output logic        resp_rdy    // response-ready flag from UART receiver
);

    logic [15:0] cmd_reg;           // holds command stable during 2-byte transmission
    logic        en_cmd_reg;        // load-enable for cmd_reg

    logic        sel_high;          // 1 -> send high byte, 0 -> send low byte
    logic        trmt;              // pulse to start one UART byte transmission
    logic        tx_done;           // asserted by UART TX when current byte is finished

    logic [7:0]  tx_data;           // byte currently fed to UART transmitter
    logic [7:0]  rx_data;           // byte received by UART receiver
    logic        rx_rdy;            // asserted when rx_data is valid

    logic        set_cmd_snt;       // internal control to set cmd_snt after both bytes sent

    // FSM states:
    // IDLE           : waiting for snd_cmd
    // SEND_HIGH      : pulse trmt for cmd[15:8]
    // WAIT_HIGH_DONE : wait for first byte to finish transmitting
    // SEND_LOW       : pulse trmt for cmd[7:0]
    // WAIT_LOW_DONE  : wait for second byte to finish transmitting
    typedef enum logic [2:0] {
        IDLE           = 3'b000,
        SEND_HIGH      = 3'b001,
        WAIT_HIGH_DONE = 3'b010,
        SEND_LOW       = 3'b011,
        WAIT_LOW_DONE  = 3'b100
    } RC_STATE_T;

    RC_STATE_T rc_state_q, rc_state_d;

    // UART transceiver:
    // - TX sends tx_data when trmt is pulsed
    // - RX captures 1-byte response from UART_wrapper
    UART uart2(
        .clk(clk),
        .rst_n(rst_n),
        .RX(RX),
        .TX(TX),
        .rx_rdy(rx_rdy),
        .clr_rx_rdy(1'b0),   // response path is simply exposed directly per spec
        .rx_data(rx_data),
        .trmt(trmt),
        .tx_data(tx_data),
        .tx_done(tx_done)
    );

    // Directly expose UART receiver outputs as RemoteComm response outputs
    assign resp     = rx_data;
    assign resp_rdy = rx_rdy;

    // Command holding register:
    // latch input cmd when snd_cmd starts a new transmission
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            cmd_reg <= 16'h0000;
        else if (en_cmd_reg)
            cmd_reg <= cmd;
    end

    // FSM state register
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            rc_state_q <= IDLE;
        else
            rc_state_q <= rc_state_d;
    end

    // cmd_snt behaves like the SR-latch in the diagram:
    // - reset on snd_cmd (new command starting)
    // - set when second byte finishes transmitting
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            cmd_snt <= 1'b0;
        else if (snd_cmd)
            cmd_snt <= 1'b0;
        else if (set_cmd_snt)
            cmd_snt <= 1'b1;
    end

    // Byte-select mux:
    // Bluetooth/UART spec says send high byte first, then low byte
    assign tx_data = (sel_high) ? cmd_reg[15:8] : cmd_reg[7:0];

    // FSM next-state and control logic
    always_comb begin
        // default outputs
        rc_state_d  = rc_state_q;
        en_cmd_reg  = 1'b0;
        sel_high    = 1'b0;
        trmt        = 1'b0;
        set_cmd_snt = 1'b0;

        case (rc_state_q)

            // Wait for request to send a new 16-bit command
            IDLE: begin
                if (snd_cmd) begin
                    en_cmd_reg = 1'b1;     // capture full cmd into local register
                    rc_state_d = SEND_HIGH;
                end
            end

            // Start transmission of high byte
            SEND_HIGH: begin
                sel_high   = 1'b1;
                trmt       = 1'b1;         // one-cycle transmit pulse
                rc_state_d = WAIT_HIGH_DONE;
            end

            // Keep high byte selected until UART reports first byte is done
            WAIT_HIGH_DONE: begin
                sel_high = 1'b1;
                if (tx_done)
                    rc_state_d = SEND_LOW;
            end

            // Start transmission of low byte
            SEND_LOW: begin
                trmt       = 1'b1;
                rc_state_d = WAIT_LOW_DONE;
            end

            // Wait for second byte to finish, then declare command sent
            WAIT_LOW_DONE: begin
                if (tx_done) begin
                    set_cmd_snt = 1'b1;
                    rc_state_d  = IDLE;
                end
            end

            // Recovery default
            default: begin
                rc_state_d = IDLE;
            end
        endcase
    end

endmodule