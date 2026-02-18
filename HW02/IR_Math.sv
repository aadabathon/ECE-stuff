module IR_math #( // IR math module implemented according to the Ex06 Specifications
  parameter logic [11:0] NOM_IR = 12'h900 // nominal IR reading (used when a sensor is "open"/invalid)
)(
  input  logic lft_opn, // left IR open flag (1 = sensor invalid/open)
  input  logic rght_opn, // right IR open flag (1 = sensor invalid/open)
  input  logic [11:0] lft_IR, // raw left IR ADC/sample (unsigned magnitude)
  input  logic [11:0] rght_IR, // raw right IR ADC/sample (unsigned magnitude)
  input  logic signed [8:0]  IR_Dtrm, // D-term (derivative term) from IR error history (signed 9-bit)
  input  logic en_fusion, // enable “fusion” correction (apply P+D -> heading adjust)
  input  logic signed [11:0] dsrd_hdng, // desired heading (signed 12-bit, two's complement)
  output logic [11:0] dsrd_hdng_adj // adjusted desired heading (12-bit two's complement in [11:0])
);

  logic signed [12:0] lft13, rght13, nom13; // 13-bit signed versions (extra bit avoids overflow on subtract)
  logic signed [12:0] diff_full, ir_diff; // full difference + selected “IR difference” used for control
  logic signed [12:0] p_term, d_term, corr; // P-term (proportional), D-term (derivative), final correction
  logic signed [12:0] sum13; // 13-bit sum before saturating back to 12-bit range

  assign lft13  = $signed({1'b0, lft_IR}); // zero-extend 12->13, then treat as signed (still non-negative)
  assign rght13 = $signed({1'b0, rght_IR}); // same for right IR
  assign nom13  = $signed({1'b0, NOM_IR}); // same for nominal IR reference

  assign diff_full = lft13 - rght13; // raw left-right difference (signed)

  assign ir_diff =
      ( lft_opn &&  rght_opn) ? 13'sd0 : // both invalid -> 0 correction input
      ( lft_opn && !rght_opn) ? (nom13 - rght13) : // left invalid -> estimate using nominal - right
      (!lft_opn &&  rght_opn) ? (lft13 - nom13) : // right invalid -> estimate using left - nominal
                                (diff_full >>> 1);// both valid -> scaled diff (>>> is arithmetic shift)

  assign p_term = (ir_diff >>> 5); // P-term: proportional gain via divide-by-32 (arithmetic shift)
                                                               
  assign d_term = ($signed({{4{IR_Dtrm[8]}}, IR_Dtrm}) <<< 2); // D-term: derivative gain via multiply-by-4

  assign corr  = en_fusion ? ((p_term + d_term) >>> 1) : 13'sd0; // final signed correction applied to heading

  assign sum13 = $signed({dsrd_hdng[11], dsrd_hdng}) + corr;     // adjusted heading before saturation

  assign dsrd_hdng_adj =
      (sum13 >  13'sd2047)  ? 12'h7FF : // clamp to +2047  (0x7FF)
      (sum13 < -13'sd2048)  ? 12'h800 : // clamp to -2048  (0x800)
                              sum13[11:0]; // in range -> truncate (safe because we just checked range)

endmodule
