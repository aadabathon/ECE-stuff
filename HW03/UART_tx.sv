module UART_tx(
  input  logic       clk, rst_n,
  input  logic       trmt,
  input  logic [7:0] tx_data,
  output logic       TX, tx_done
);

  localparam int BAUD_DIV = 2604;
  localparam int BAUD_TC  = BAUD_DIV - 1;

  typedef enum logic [0:0] {S_IDLE, S_BUSY} state_t;
  state_t state, state_n;

  logic [11:0] baud_cnt;
  logic        baud_tick;

  logic [9:0]  shft_reg, shft_reg_n;
  logic [3:0]  bit_cnt,  bit_cnt_n;

  logic        TX_n, tx_done_n;

  logic baud_en, baud_clr;
  logic do_load, do_shift;
  logic set_done, clr_done;

  // baud counter + tick (SEQUENTIAL)
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      baud_cnt  <= 12'd0;
      baud_tick <= 1'b0;
    end else begin
      baud_tick <= 1'b0;

      if (baud_clr) begin
        baud_cnt <= 12'd0;
      end else if (baud_en) begin
        if (baud_cnt == BAUD_TC[11:0]) begin
          baud_cnt  <= 12'd0;
          baud_tick <= 1'b1;
        end else begin
          baud_cnt <= baud_cnt + 12'd1;
        end
      end
    end
  end

  // shift reg next (COMB)
  always_comb begin
    shft_reg_n = shft_reg;
    if (do_load)       shft_reg_n = {1'b1, tx_data, 1'b0};
    else if (do_shift) shft_reg_n = {1'b1, shft_reg[9:1]};
  end

  // bit cnt next (COMB)
  always_comb begin
    bit_cnt_n = bit_cnt;
    if (state == S_IDLE) bit_cnt_n = 4'd0;
    else if (do_shift)   bit_cnt_n = (bit_cnt == 4'd9) ? 4'd9 : (bit_cnt + 4'd1);
  end

  // FSM + outputs next (COMB)
  always_comb begin
    state_n   = state;

    baud_en   = 1'b0;
    baud_clr  = 1'b1;

    do_load   = 1'b0;
    do_shift  = 1'b0;

    set_done  = 1'b0;
    clr_done  = 1'b0;

    TX_n      = TX;
    tx_done_n = tx_done;

    case (state)
      S_IDLE: begin
        TX_n     = 1'b1;
        baud_clr = 1'b1;
        clr_done = 1'b1;

        if (trmt) begin
          do_load  = 1'b1;
          TX_n     = 1'b0;     // start bit immediately
          state_n  = S_BUSY;
        end
      end

      S_BUSY: begin
        baud_en  = 1'b1;
        baud_clr = 1'b0;

        TX_n = shft_reg[0];

        if (baud_tick) begin
          do_shift = 1'b1;
          if (bit_cnt == 4'd9) begin
            set_done = 1'b1;
            state_n  = S_IDLE;
          end
        end
      end
    endcase

    if (clr_done) tx_done_n = 1'b0;
    if (set_done) tx_done_n = 1'b1;
  end

  // regs update (SEQUENTIAL)
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state    <= S_IDLE;
      shft_reg <= 10'h3FF;
      bit_cnt  <= 4'd0;
      TX       <= 1'b1;
      tx_done  <= 1'b0;
    end else begin
      state    <= state_n;
      shft_reg <= shft_reg_n;
      bit_cnt  <= bit_cnt_n;
      TX       <= TX_n;
      tx_done  <= tx_done_n;
    end
  end

endmodule