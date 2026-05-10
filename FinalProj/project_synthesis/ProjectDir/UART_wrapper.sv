module UART_wrapper (
    input logic clk,
    input logic rst_n,
    input logic RX,
    input logic clr_cmd_rdy,
    output logic cmd_rdy,
    output logic [15:0] cmd,
    output logic tx_done,
    input logic trmt,
    input logic [7:0] resp,
    output logic TX
);
//Internal logic
logic clr_cmd_rdy_sm_output; //Output of the state machine to clear cmd_rdy
logic [7:0] rx_data; //Data received from UART_rx
logic rx_rdy_sm_input; //Input to the state machine indicating new data is ready

logic rx_dy_sm_output;
logic flop_in_high_byte; //Indicates that were receiving high byte of the command.
// ---------------------------------------------------------------
// State machine enum and logic
// ---------------------------------------------------------------
typedef enum logic [1:0] {
    IDLE,
    PROCESS_CMD_LOW,
    WAIT_FOR_CLR_CMD
} state_t;
state_t state, nxt_state;
logic clr_rdy;
// ---------------------------------------------------------------
// Instance of UART_rx
// This is used to receive a command from the BLE module after sending a command. 
//The received data is stored in rx_data and cmd_rdy is asserted when a new command is ready
// ---------------------------------------------------------------
UART_rx BLE_RECEIVE(
    .clk(clk),
    .rst_n(rst_n),
    .RX(RX),
    .clr_rdy(clr_rdy),
    .rx_data(rx_data),
    .rdy(rx_rdy_sm_input)
);
// ---------------------------------------------------------------
// Instance of UART_tx
// ---------------------------------------------------------------
UART_tx BLE_TRANSMIT(
    .clk(clk),
    .rst_n(rst_n),
    .tx_data(resp),
    .trmt(trmt),
    .tx(TX),
    .tx_done(tx_done)
);

always_ff @(posedge clk or negedge rst_n) begin
    if   (!rst_n) state <= IDLE;
    else  state <= nxt_state;
end

always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) cmd[15:8] <= 8'h00;
    else if(flop_in_high_byte) cmd[15:8] <= rx_data; //Flop in high byte of command
end
assign cmd[7:0] = rx_data; //Low byte of command is always the most recently received data
always_comb begin
    cmd_rdy = 0;
    clr_rdy = 0;
    flop_in_high_byte = 0;

    nxt_state = state;
    case(state)
        IDLE : 
            if(rx_rdy_sm_input) begin
                nxt_state = PROCESS_CMD_LOW;
                flop_in_high_byte = 1; //Indicate that we're receiving the high byte of the command
                clr_rdy = 1; //Assert clr_rdy to clear the rdy signal in UART_rx
            end
        PROCESS_CMD_LOW : begin
            if(rx_rdy_sm_input) begin
                cmd_rdy = 1; //Assert cmd_rdy to indicate a new command is ready
                clr_rdy = 1; //Assert clr_rdy to clear the rdy signal in UART_rx
                nxt_state = IDLE;
            end
        end
        WAIT_FOR_CLR_CMD : begin
            if(clr_cmd_rdy) begin
               nxt_state = IDLE;
            end
        end
        default : nxt_state = IDLE;
    endcase
end
endmodule