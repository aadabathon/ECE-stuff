`timescale 1ns/1ps

module Dterm_tb;

    // ----------------------------
    // TB signals
    // ----------------------------
    logic clk;
    logic rst_n;
    logic hdng_vld;
    logic signed [9:0]  err_sat;
    logic signed [12:0] D_term;

    // ----------------------------
    // Instantiate DUT
    // ----------------------------
    Dterm iDUT (
        .hdng_vld(hdng_vld),
        .clk(clk),
        .rst_n(rst_n),
        .err_sat(err_sat),
        .D_term(D_term)
    );

    // ----------------------------
    // Helper: saturate 11-bit signed value into 8-bit signed range [-128, 127]
    // Mirrors the Dterm datapath clamp behavior.
    // ----------------------------
    function automatic logic signed [7:0] sat8(input logic signed [10:0] x);
        if (x > 11'sd127)       sat8 = 8'sd127;
        else if (x < -11'sd128) sat8 = -8'sd128;
        else                    sat8 = x[7:0];
    endfunction

    // ----------------------------
    // Expected model for D_term:
    //   diff   = err - prev_err
    //   diff8  = sat8(diff)
    //   D_term = diff8 * D_COEFF
    //
    // D_COEFF is 14 per lab spec (0x0E).
    // ----------------------------
    function automatic logic signed [12:0] expected_D(
        input logic signed [9:0] err,
        input logic signed [9:0] prev
    );
        logic signed [10:0] diff;
        logic signed [7:0]  diff8;
        begin
            diff = err - prev;
            diff8 = sat8(diff);
            expected_D = $signed(diff8) * 13'sd14;
        end
    endfunction

    // TB-side "previous error" model.
    // Updated only when we drive a valid sample (hdng_vld pulse),
    // matching the DUT behavior.
    logic signed [9:0] prev_err;

    // ----------------------------
    // Drive one valid heading/error sample into the DUT and check output.
    // Protocol:
    //   - apply err_sat and assert hdng_vld for one cycle
    //   - check D_term shortly after the next posedge
    //   - deassert hdng_vld and update TB's prev_err model
    // ----------------------------
    task automatic send_sample(input logic signed [9:0] err);
        logic signed [12:0] exp;
        begin
            exp = expected_D(err, prev_err);

            // Setup inputs before the capturing clock edge
            @(negedge clk);
            err_sat  = err;
            hdng_vld = 1'b1;

            // DUT captures history on posedge when hdng_vld is high
            @(posedge clk);
            #1; // small delay to avoid race with NBA updates

            if (D_term !== exp) begin
                $display("FAIL t=%0t err=%0d prev=%0d got=%0d exp=%0d",
                         $time, err, prev_err, D_term, exp);
                $fatal;
            end

            // Drop valid and advance TB-side history
            @(negedge clk);
            hdng_vld = 1'b0;
            prev_err = err;
        end
    endtask

    // ----------------------------
    // Clock generation (50 MHz)
    // ----------------------------
    initial begin
        clk = 1'b0;
        forever #10 clk = ~clk;
    end

    // Variables for randomized stimulus generation
    int i;
    int signed s;
    int unsigned u;

    initial begin
        // ----------------------------
        // Reset + init
        // ----------------------------
        rst_n    = 1'b0;
        hdng_vld = 1'b0;
        err_sat  = 10'sd0;
        prev_err = 10'sd0;

        repeat (2) @(negedge clk);
        rst_n = 1'b1;

        // Basic post-reset expectation: D_term should be 0 with no valid samples yet
        #1;
        if (D_term !== 13'sd0) begin
            $display("FAIL after reset got=%0d exp=0", D_term);
            $fatal;
        end

        // ----------------------------
        // Directed tests (edge cases / typical steps)
        // ----------------------------
        send_sample(10'sd0);        // no change
        send_sample(10'sd5);        // small positive step
        send_sample(10'sd100);      // larger positive step
        send_sample(10'sd120);      // small follow-on step
        send_sample(10'sd511);      // near positive limit
        send_sample(-10'sd512);     // negative limit (two's complement)
        send_sample(10'sd0);        // large negative-to-zero jump
        send_sample(10'sd511);      // large positive jump
        send_sample(10'sd0);        // back to zero

        // ----------------------------
        // Randomized regression
        // Keep values within signed 10-bit range [-512, 511]
        // ----------------------------
        for (i = 0; i < 300; i++) begin
            u = $urandom_range(0, 1023);
            s = int'(u) - 512;
            send_sample(s[9:0]);
        end

        $display("PASS"); //No adverse behavior 
        $finish;
    end

endmodule