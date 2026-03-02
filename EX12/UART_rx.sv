module UART_rx(
  input  logic       clk, rst_n,
  input  logic       RX,
  input  logic       clr_rdy,
  output logic [7:0] rx_data,
  output logic       rdy
);

  localparam int BAUD_DIV = 2604;
  localparam int BAUD_TC  = BAUD_DIV - 1;
  localparam int HALF_TC  = (BAUD_DIV/2) - 1;

  typedef enum logic [2:0] {IDLE, START_HALF, DATA, STOP} state_t;
  state_t state, state_n;

  logic rx_meta, rx_sync, rx_prev;
  logic start_edge;

  logic [11:0] baud_cnt;
  logic        tick;
  logic [11:0] tc_sel;

  logic [7:0]  shft_reg, shft_reg_n;
  logic [3:0]  bit_cnt, bit_cnt_n;

  logic [7:0]  rx_data_n;
  logic        rdy_n;

  logic baud_en, baud_clr;
  logic shift_en;
  logic bitclr, bitinc;
  logic set_rdy;

  // 2-FF synchronizer + prev for edge detect
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      rx_meta <= 1'b1;
      rx_sync <= 1'b1;
      rx_prev <= 1'b1;
    end else begin
      rx_meta <= RX;
      rx_sync <= rx_meta;
      rx_prev <= rx_sync;
    end
  end

  assign start_edge = (rx_prev == 1'b1) && (rx_sync == 1'b0);

  // select terminal count for START_HALF vs full-bit states
  always_comb begin
    tc_sel = BAUD_TC[11:0];
    if (state == START_HALF) tc_sel = HALF_TC[11:0];
  end

  // BAUD counter + tick 
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      baud_cnt <= 12'd0;
      tick     <= 1'b0;
    end else begin
      tick <= 1'b0;
      if (baud_clr) begin
        baud_cnt <= 12'd0;
      end else if (baud_en) begin
        if (baud_cnt == tc_sel) begin
          baud_cnt <= 12'd0;
          tick     <= 1'b1;
        end else begin
          baud_cnt <= baud_cnt + 12'd1;
        end
      end
    end
  end

  // shift register next
  always_comb begin
    shft_reg_n = shft_reg;
    if (shift_en) shft_reg_n = {shft_reg[6:0], rx_sync};
  end

  // bit counter next
  always_comb begin
    bit_cnt_n = bit_cnt;
    if (bitclr) bit_cnt_n = 4'd0;
    else if (bitinc) bit_cnt_n = bit_cnt + 4'd1;
  end

  // FSM + outputs next
  always_comb begin
    state_n   = state;

    baud_en   = 1'b0;
    baud_clr  = 1'b1;

    shift_en  = 1'b0;
    bitclr    = 1'b0;
    bitinc    = 1'b0;
    set_rdy   = 1'b0;

    rx_data_n = rx_data;
    rdy_n     = rdy;

    if (clr_rdy) rdy_n = 1'b0;
    if (rdy && start_edge) rdy_n = 1'b0;

    case (state)
      IDLE: begin
        bitclr = 1'b1;
        if (start_edge) begin
          rdy_n   = 1'b0;
          state_n = START_HALF;
        end
      end

      START_HALF: begin
        baud_en  = 1'b1;
        baud_clr = 1'b0;
        if (tick) begin
          if (rx_sync == 1'b0) begin
            bitclr   = 1'b1;
            state_n  = DATA;
          end else begin
            state_n  = IDLE;
          end
        end
      end

      DATA: begin
        baud_en  = 1'b1;
        baud_clr = 1'b0;
        if (tick) begin
          shift_en = 1'b1;
          if (bit_cnt == 4'd7) state_n = STOP;
          else bitinc = 1'b1;
        end
      end

      STOP: begin
        baud_en  = 1'b1;
        baud_clr = 1'b0;
        if (tick) begin
          if (rx_sync == 1'b1) begin
            rx_data_n = shft_reg;
            set_rdy   = 1'b1;
          end
          state_n = IDLE;
        end
      end

      default: state_n = IDLE;
    endcase

    if (set_rdy) rdy_n = 1'b1;
  end

  // regs update
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state    <= IDLE;
      shft_reg <= 8'd0;
      bit_cnt  <= 4'd0;
      rx_data  <= 8'd0;
      rdy      <= 1'b0;
    end else begin
      state    <= state_n;
      shft_reg <= shft_reg_n;
      bit_cnt  <= bit_cnt_n;
      rx_data  <= rx_data_n;
      rdy      <= rdy_n;
    end
  end

endmodule