module UART_rx(
  input  logic clk, rst_n,
  input  logic RX, // asynchronous serial input (idle high)
  input  logic clr_rdy, // clears rdy flag after user consumes rx_data
  output logic [7:0] rx_data, // received byte
  output logic rdy // goes high when a valid byte is captured
);

  // 50 MHz / 19200 baud ≈ 2604 clocks per UART bit
  localparam int BAUD_DIV = 2604;
  localparam int BAUD_TC  = BAUD_DIV - 1;
  localparam int HALF_TC  = (BAUD_DIV/2) - 1;

  // States:
  // IDLE : wait for start-bit falling edge
  // START_HALF : wait half bit-time, re-check start is still low (debounce/align)
  // DATA : sample 8 data bits, one per bit-time, in the middle of the bit cell
  // STOP : sample stop bit, latch rx_data, assert rdy
  typedef enum logic [2:0] {IDLE, START_HALF, DATA, STOP} state_t;
  state_t state, state_n;

  // RX synchronizer (2-FF) + previous sample for edge detect
  logic rx_meta, rx_sync, rx_prev;
  logic start_edge;

  // Baud counter generates a 1-cycle tick at selected terminal count
  logic [11:0] baud_cnt;
  logic        tick;
  logic [11:0] tc_sel;

  // Shift register collects received bits (UART is LSB-first)
  logic [7:0] shft_reg, shft_reg_n;
  logic [3:0] bit_cnt, bit_cnt_n;

  logic [7:0] rx_data_n;
  logic rdy_n;

  // Control strobes from FSM
  logic baud_en, baud_clr;
  logic shift_en;
  logic bitclr, bitinc;
  logic set_rdy;

  // ------------------------------------------------------------
  // 2-FF synchronizer for RX + edge detect
  // ------------------------------------------------------------
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

  // Detect falling edge (idle high -> start bit low)
  assign start_edge = (rx_prev == 1'b1) && (rx_sync == 1'b0);

  // ------------------------------------------------------------
  // Select terminal count:
  // - START_HALF uses HALF_TC (align to middle of start bit)
  // - DATA/STOP use full BAUD_TC (one full bit time)
  // ------------------------------------------------------------
  always_comb begin
    tc_sel = BAUD_TC[11:0];
    if (state == START_HALF) tc_sel = HALF_TC[11:0];
  end

  // ------------------------------------------------------------
  // Baud counter + tick generation
  // ------------------------------------------------------------
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      baud_cnt <= 12'd0;
      tick <= 1'b0;
    end else begin
      tick <= 1'b0;

      if (baud_clr) begin
        baud_cnt <= 12'd0;
      end else if (baud_en) begin
        if (baud_cnt == tc_sel) begin
          baud_cnt <= 12'd0;
          tick <= 1'b1;
        end else begin
          baud_cnt <= baud_cnt + 12'd1;
        end
      end
    end
  end

  // ------------------------------------------------------------
  // Shift register next-state
  // FIX: UART is LSB-first, so shift RIGHT and insert new bit into MSB.
  // After 8 ticks: shft_reg[0]=b0 ... shft_reg[7]=b7.
  // ------------------------------------------------------------
  always_comb begin
    shft_reg_n = shft_reg;
    if (shift_en) shft_reg_n = {rx_sync, shft_reg[7:1]};
  end

  // Bit counter next-state
  always_comb begin
    bit_cnt_n = bit_cnt;
    if (bitclr) bit_cnt_n = 4'd0;
    else if (bitinc) bit_cnt_n = bit_cnt + 4'd1;
  end

  // ------------------------------------------------------------
  // FSM + output decode
  // ------------------------------------------------------------
  always_comb begin
    state_n = state;

    baud_en = 1'b0;
    baud_clr  = 1'b1;

    shift_en  = 1'b0;
    bitclr = 1'b0;
    bitinc = 1'b0;
    set_rdy = 1'b0;

    rx_data_n = rx_data;
    rdy_n = rdy;

    // Clear rdy when user requests, or when a new frame starts
    if (clr_rdy) rdy_n = 1'b0;
    if (rdy && start_edge) rdy_n = 1'b0;

    unique case (state)
      IDLE: begin
        bitclr = 1'b1;
        if (start_edge) begin
          rdy_n = 1'b0;
          state_n = START_HALF;
        end
      end

      START_HALF: begin
        baud_en  = 1'b1;
        baud_clr = 1'b0;

        // After half-bit, confirm RX is still low (valid start)
        if (tick) begin
          if (rx_sync == 1'b0) begin
            bitclr = 1'b1;
            state_n = DATA;
          end else begin
            state_n = IDLE; // false start / glitch
          end
        end
      end

      DATA: begin
        baud_en  = 1'b1;
        baud_clr = 1'b0;

        // Sample one data bit per bit-time tick
        if (tick) begin
          shift_en = 1'b1;
          if (bit_cnt == 4'd7) state_n = STOP;
          else bitinc  = 1'b1;
        end
      end

      STOP: begin
        baud_en  = 1'b1;
        baud_clr = 1'b0;

        // Sample stop bit; if valid, publish byte + assert rdy
        if (tick) begin
          if (rx_sync == 1'b1) begin
            rx_data_n = shft_reg;
            set_rdy = 1'b1;
          end
          state_n = IDLE;
        end
      end

      default: state_n = IDLE;
    endcase

    if (set_rdy) rdy_n = 1'b1;
  end

  // ------------------------------------------------------------
  // Registers update
  // ------------------------------------------------------------
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      shft_reg <= 8'd0;
      bit_cnt <= 4'd0;
      rx_data <= 8'd0;
      rdy <= 1'b0;
    end else begin
      state <= state_n;
      shft_reg <= shft_reg_n;
      bit_cnt <= bit_cnt_n;
      rx_data <= rx_data_n;
      rdy <= rdy_n;
    end
  end

endmodule