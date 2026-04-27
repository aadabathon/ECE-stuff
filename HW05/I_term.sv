module I_term(
  input  logic        clk, rst_n,
  input  logic        hdng_vld, moving,
  input  logic [9:0]  err_sat,
  output logic [11:0] I_term
);

  logic signed [15:0] integrator, nxt_integrator, sum;
  logic signed [15:0] err_sext;
  logic              ov;

  assign err_sext = {{6{err_sat[9]}}, err_sat};
  assign sum      = integrator + err_sext;

  assign ov = (~(integrator[15] ^ err_sext[15])) & (integrator[15] ^ sum[15]);

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) integrator <= '0;
    else        integrator <= nxt_integrator;
  end

  always_comb begin
    if (!moving)              nxt_integrator = '0;
    else if (!hdng_vld || ov) nxt_integrator = integrator;
    else                      nxt_integrator = sum;
  end

  assign I_term = integrator[15:4];

endmodule
