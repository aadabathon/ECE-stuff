module PWM12(
    input  logic        clk,
    input  logic        rst_n,
    input  logic [11:0] duty,
    output logic        PWM1,
    output logic        PWM2
);

    localparam logic [11:0] NONOVERLAP = 12'h02C;

    logic [11:0] cnt;
    logic s1, r1, s2, r2;
    logic [12:0] duty_plus_no;

    assign duty_plus_no = {1'b0, duty} + {1'b0, NONOVERLAP}; //No overflow logic so we set this addition to a 13 bit vector

    always_comb begin //Comb block for out SR latch inputes
        s2 = (cnt >= NONOVERLAP);
        r2 = (cnt >= duty);

        s1 = (!duty_plus_no[12]) && (cnt >= duty_plus_no[11:0]);
        r1 = &cnt;
    end

    always_ff @(posedge clk or negedge rst_n) begin //SR flop for PWM2
        if (!rst_n)        PWM2 <= 1'b0;
        else if (r1)       PWM2 <= 1'b0;
        else if (s1)       PWM2 <= 1'b1;
    end

    always_ff @(posedge clk or negedge rst_n) begin //SR Flop for PWM1
        if (!rst_n)        PWM1 <= 1'b0;
        else if (r2)       PWM1 <= 1'b0;
        else if (s2)       PWM1 <= 1'b1;
    end

    always_ff @(posedge clk or negedge rst_n) begin //Flop for cnt incrementor.
        if (!rst_n) cnt <= 12'd0;
        else        cnt <= cnt + 12'd1;
    end

endmodule
