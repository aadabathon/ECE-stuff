module mult_accum_gated(
    input  logic        clk,
    input  logic        clr,
    input  logic        en,
    input  logic [15:0] A,
    input  logic [15:0] B,
    output logic [63:0] accum
);

logic [31:0] prod_reg;
logic        en_stg2;
logic        en_stg2_latch;
logic        gclk;

always_ff @(posedge clk)
    if (en)
        prod_reg <= A * B;

always_ff @(posedge clk)
    en_stg2 <= en;

always_latch
    if (!clk)
        en_stg2_latch <= en_stg2;

assign gclk = clk & en_stg2_latch;

always_ff @(posedge gclk or posedge clr)
    if (clr)
        accum <= 64'd0;
    else
        accum <= accum + prod_reg;

endmodule