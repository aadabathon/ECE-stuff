module PWM12(
    input  logic clk,
    input  logic rst_n,
    input  logic [11:0] duty,
    output logic PWM1,
    output logic PWM2
);
    // 12-bit PWM with complementary/non-overlapping outputs.
    // - cnt is a free-running 12-bit phase accumulator (period = 4096 clk cycles).
    // - PWM1 turns ON after a fixed dead-time (NONOVERLAP) and turns OFF at 'duty'.
    // - PWM2 turns ON at (duty + NONOVERLAP) and turns OFF at the end of the period.
    // - Nonoverlap prevents both outputs from being high at the same time.
	
    localparam logic [11:0] NONOVERLAP = 12'h02C; // dead-time in clock cycles

    logic [11:0] cnt;
    logic s1, r1, s2, r2;
    logic [12:0] duty_plus_no;

    assign duty_plus_no = {1'b0, duty} + {1'b0, NONOVERLAP}; // Widened add so we can detect overflow; if overflow occurs, suppress PWM2 set.

    always_comb begin //Comb block for out SR latch inputs
        s2 = (cnt >= NONOVERLAP);
        r2 = (cnt >= duty);

        s1 = (!duty_plus_no[12]) && (cnt >= duty_plus_no[11:0]);
        r1 = &cnt;
    end
	
    // PWM2 SR-style flop: priority reset, then set.
    // (No explicit "hold" needed since flops naturally retain value otherwise.)
    always_ff @(posedge clk or negedge rst_n) begin //SR flop for PWM2
        if (!rst_n) PWM2 <= 1'b0;
        else if (r1) PWM2 <= 1'b0;
        else if (s1) PWM2 <= 1'b1;
    end
	
	// PWM1 SR-style flop: priority reset, then set.
	// Note: if duty < NONOVERLAP, r2 asserts before s2 so PWM1 remains low (deadtime dominates).
    always_ff @(posedge clk or negedge rst_n) begin //SR Flop for PWM1
        if (!rst_n) PWM1 <= 1'b0;
        else if (r2) PWM1 <= 1'b0;
        else if (s2) PWM1 <= 1'b1;
    end

	// Free-running 12-bit counter (sets PWM period).
    always_ff @(posedge clk or negedge rst_n) begin //Flop for cnt incrementor.
        if (!rst_n) cnt <= 12'd0;
        else cnt <= cnt + 12'd1;
    end
endmodule
