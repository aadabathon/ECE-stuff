`timescale 1ns/1ps

module Dterm_tb;

    logic clk;
    logic rst_n;
    logic hdng_vld;
    logic signed [9:0]  err_sat;
    logic signed [12:0] D_term;

    Dterm iDUT (
        .hdng_vld(hdng_vld),
        .clk(clk),
        .rst_n(rst_n),
        .err_sat(err_sat),
        .D_term(D_term)
    );

    function automatic logic signed [7:0] sat8(input logic signed [10:0] x);
        if (x > 11'sd127)       sat8 = 8'sd127;
        else if (x < -11'sd128) sat8 = -8'sd128;
        else                    sat8 = x[7:0];
    endfunction

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

    logic signed [9:0] prev_err;

    task automatic send_sample(input logic signed [9:0] err);
        logic signed [12:0] exp;
        begin
            exp = expected_D(err, prev_err);

            @(negedge clk);
            err_sat  = err;
            hdng_vld = 1'b1;

            @(posedge clk);
            #1;
            if (D_term !== exp) begin
                $display("FAIL t=%0t err=%0d prev=%0d got=%0d exp=%0d",
                         $time, err, prev_err, D_term, exp);
                $fatal;
            end

            @(negedge clk);
            hdng_vld = 1'b0;
            prev_err = err;
        end
    endtask

    initial begin
        clk = 1'b0;
        forever #10 clk = ~clk;
    end

    int i;
    int signed s;
    int unsigned u;

    initial begin
        rst_n    = 1'b0;
        hdng_vld = 1'b0;
        err_sat  = 10'sd0;
        prev_err = 10'sd0;

        repeat (2) @(negedge clk);
        rst_n = 1'b1;

        #1;
        if (D_term !== 13'sd0) begin
            $display("FAIL after reset got=%0d exp=0", D_term);
            $fatal;
        end

        send_sample(10'sd0);
        send_sample(10'sd5);
        send_sample(10'sd100);
        send_sample(10'sd120);
        send_sample(10'sd511);
        send_sample(-10'sd512);
        send_sample(10'sd0);
        send_sample(10'sd511);
        send_sample(10'sd0);

        for (i = 0; i < 300; i++) begin
            u = $urandom_range(0, 1023);
            s = int'(u) - 512;
            send_sample(s[9:0]);
        end

        $display("PASS");
        $finish;
    end

endmodule
