module UART_tx(
  input  logic clk, rst_n,
  input  logic trmt, // pulse/high to start a transmission
  input  logic [7:0] tx_data, // byte to transmit (LSB first)
  output logic TX, // UART serial output line (idle = '1')
  output logic tx_done // asserted when the frame is finished
);

  // Baud-rate divider (clk cycles per UART bit).
  // With a 50 MHz clk and 19200 baud, BAUD_DIV ≈ 50e6/19200 ≈ 2604.
  localparam int BAUD_DIV = 2604;
  localparam int BAUD_TC = BAUD_DIV - 1;

  // Simple 2-state controller:
  //  - IDLE: TX held high, waiting for trmt
  //  - BUSY: output bits and advance on baud_tick
  typedef enum logic [0:0] {S_IDLE, S_BUSY} state_t;
  state_t state, state_n;

  // Baud counter generates a single-cycle tick at the baud rate while enabled.
  logic [11:0] baud_cnt;
  logic baud_tick;

  // 10-bit shift register holds the UART frame:
  // {stop_bit(1), data[7:0], start_bit(0)}
  // TX always drives shft_reg[0] while BUSY.
  logic [9:0] shft_reg, shft_reg_n;

  // Counts which bit of the 10-bit frame we are on (0..9).
  logic [3:0]  bit_cnt, bit_cnt_n;

  // Next-state versions of registered outputs
  logic TX_n, tx_done_n;

  // Control strobes from FSM to datapath
  logic baud_en, baud_clr; // enable/clear baud counter
  logic do_load, do_shift; // load/shift the frame register
  logic set_done, clr_done; // manage tx_done flag

  // ------------------------------------------------------------
  // Baud counter + tick generation (sequential)
  // ------------------------------------------------------------
  // When baud_en=1, count up to BAUD_TC and generate baud_tick for 1 clk.
  // When baud_clr=1, reset baud_cnt to 0 (used in IDLE and at reset).
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      baud_cnt  <= 12'd0;
      baud_tick <= 1'b0;
    end else begin
      baud_tick <= 1'b0; // default: no tick (1-cycle pulse when terminal count hits)

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

  // ------------------------------------------------------------
  // Shift register next-state logic (combinational)
  // ------------------------------------------------------------
  // Load builds a full UART frame: start=0, 8 data bits, stop=1.
  // Shift moves toward the next output bit; shift-in '1' keeps the line high
  // after the stop bit (idle behavior).
  always_comb begin
    shft_reg_n = shft_reg;
    if (do_load) shft_reg_n = {1'b1, tx_data, 1'b0};
    else if (do_shift) shft_reg_n = {1'b1, shft_reg[9:1]};
  end

  // ------------------------------------------------------------
  // Bit counter next-state logic (combinational)
  // ------------------------------------------------------------
  // Reset bit counter in IDLE. While BUSY, increment only on shifts (baud ticks).
  always_comb begin
    bit_cnt_n = bit_cnt;
    if (state == S_IDLE) bit_cnt_n = 4'd0;
    else if (do_shift) bit_cnt_n = (bit_cnt == 4'd9) ? 4'd9 : (bit_cnt + 4'd1);
  end

  // ------------------------------------------------------------
  // FSM + output decode (combinational)
  // ------------------------------------------------------------
  // Defaults are chosen so nothing latches:
  // - counter cleared unless explicitly running
  // - no load/shift unless commanded
  // - TX/tx_done hold previous unless updated
  always_comb begin
    state_n = state;

    baud_en = 1'b0;
    baud_clr  = 1'b1;

    do_load = 1'b0;
    do_shift  = 1'b0;

    set_done = 1'b0;
    clr_done = 1'b0;

    TX_n = TX;
    tx_done_n = tx_done;

    unique case (state)
      // ----------------------------
      // IDLE: line high, waiting for trmt
      // ----------------------------
      S_IDLE: begin
        TX_n = 1'b1;   // UART idle level
        baud_clr = 1'b1;   // keep baud counter reset in IDLE
        clr_done = 1'b1;   // clear done while waiting

        if (trmt) begin // Start a transmissio -> load the frame, drive start bit immediately, enter BUSY so subsequent bits advance on baud_tick
          do_load  = 1'b1;
          TX_n     = 1'b0;
          state_n  = S_BUSY;
        end
      end

      // ----------------------------
      // BUSY: output frame bits, advance once per baud_tick
      // ----------------------------
      S_BUSY: begin
        baud_en = 1'b1;
        baud_clr = 1'b0;

        // Drive current output bit from shift register
        TX_n = shft_reg[0];

        // On baud tick, shift to the next bit. When the last bit is reached, assert done.
        if (baud_tick) begin
          do_shift = 1'b1;
          if (bit_cnt == 4'd9) begin
            set_done = 1'b1;
            state_n  = S_IDLE;
          end
        end
      end
    endcase

    // tx_done is a registered flag controlled by set/clear strobes
    if (clr_done) tx_done_n = 1'b0;
    if (set_done) tx_done_n = 1'b1;
  end

  // ------------------------------------------------------------
  // State/register updates (sequential)
  // ------------------------------------------------------------
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state    <= S_IDLE;
      shft_reg <= 10'h3FF; // idle fill
      bit_cnt  <= 4'd0;
      TX <= 1'b1;
      tx_done  <= 1'b0;
    end else begin
      state <= state_n;
      shft_reg <= shft_reg_n; 
      bit_cnt  <= bit_cnt_n;
      TX <= TX_n;
      tx_done <= tx_done_n;
    end
  end

endmodule