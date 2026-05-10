module IR_math #(
  parameter logic [11:0] NOM_IR = 12'h900
)(
  input  logic        lft_opn,
  input  logic        rght_opn,
  input  logic [11:0] lft_IR,
  input  logic [11:0] rght_IR,
  input  logic signed [8:0]  IR_Dtrm,
  input  logic        en_fusion,
  input  logic signed [11:0] dsrd_hdng,
  output logic [11:0] dsrd_hdng_adj
);

  logic signed [12:0] lft13, rght13, nom13;
  logic signed [12:0] diff_full, ir_diff;
  logic signed [12:0] p_term, d_term, corr;
  logic signed [12:0] sum13;

  assign lft13  = $signed({1'b0, lft_IR});
  assign rght13 = $signed({1'b0, rght_IR});
  assign nom13  = $signed({1'b0, NOM_IR});

  assign diff_full = lft13 - rght13;

  assign ir_diff =
      ( lft_opn &&  rght_opn) ? 13'sd0 :
      ( lft_opn && !rght_opn) ? (nom13 - rght13) :
      (!lft_opn &&  rght_opn) ? (lft13 - nom13) :
                                (diff_full >>> 1);

  assign p_term = (ir_diff >>> 5);
  assign d_term = ($signed({{4{IR_Dtrm[8]}}, IR_Dtrm}) <<< 2);

  assign corr  = en_fusion ? ((p_term + d_term) >>> 1) : 13'sd0;
  assign sum13 = $signed({dsrd_hdng[11], dsrd_hdng}) + corr;

  assign dsrd_hdng_adj =
      (sum13 >  13'sd2047)  ? 12'h7FF :
      (sum13 < -13'sd2048)  ? 12'h800 :
                              sum13[11:0];

endmodule
