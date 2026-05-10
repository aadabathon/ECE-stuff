module RemoteComm (
    input  logic       clk,
    input  logic       rst_n,
    input  logic       RX,
    output logic       TX,
    input logic [15:0] cmd,
    input snd_cmd,
    output logic cmd_snt,
    output logic resp_rdy,
    output logic [7:0] resp
);

logic [7:0] cmd_low_byte, cmd_high_byte;
logic sel_high;
logic [7:0] tx_data_uart_input;
logic set_cmd_snt;
logic tx_done;
logic trmt;
UART_rx BLE_RECEIVE(
    .clk(clk),
    .rst_n(rst_n),
    .RX(RX), //RX of UART_rx is connected to TX_RX of wrapper
    .rx_data(resp),
    .rdy(resp_rdy),
    .clr_rdy(1'b0) //No need to clear rdy in this design since we only expect one response per command
);
UART_tx BLE_TRANSMIT(
    .clk(clk),
    .rst_n(rst_n),
    .tx_data(tx_data_uart_input), //Data to transmit is selected between high and low byte of cmd
    .trmt(trmt), //Transmission is triggered by snd_cmd signal
    .tx(TX), //TX of UART_tx is connected to RX_TX of wrapper
    .tx_done(tx_done)
);
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) cmd_low_byte <= 8'h00;
    else begin
        if(snd_cmd)
            cmd_low_byte <= cmd[7:0]; //Flop in low byte of command when snd_cmd is asserted
    end
end

assign tx_data_uart_input = sel_high ? cmd[15:8] : cmd_low_byte;

always_ff @(posedge clk or negedge rst_n) begin
    if(!rst_n) cmd_snt <= 0;
    else if (set_cmd_snt) cmd_snt <= 1; // Set cmd_snt after low byte is done transmitting
    else if(snd_cmd) cmd_snt <= 0; // Clear cmd_snt when a new command is initiated
end

typedef enum logic [1:0] {
    IDLE,
    WAIT_FOR_HIGH_RESPONSE,
    WAIT_FOR_LOW_RESPONSE
} state_t;
state_t state, nxt_state;
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) state <= IDLE;
    else state <= nxt_state;
end
always_comb 
 begin
    trmt = 0;
    sel_high = 0; 
    set_cmd_snt = 0;
    nxt_state = state;
    case(state)
        IDLE : begin
            if(snd_cmd) begin
                sel_high = 1; // Start with high byte
                trmt = 1; // Trigger transmission of high byte
                nxt_state = WAIT_FOR_HIGH_RESPONSE;
            end
        end
        WAIT_FOR_HIGH_RESPONSE : begin
            if(tx_done) begin
                trmt = 1; // Trigger transmission of low byte
                nxt_state = WAIT_FOR_LOW_RESPONSE;
            end else begin
                sel_high = 1; // Keep high byte selected only while still transmitting it
            end
        end
        WAIT_FOR_LOW_RESPONSE : begin
            if(tx_done) begin
                set_cmd_snt = 1; // Indicate command has been sent after low byte is done
                nxt_state = IDLE;
            end
        end
        default : nxt_state = IDLE;
    endcase
end
endmodule