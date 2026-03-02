module synch_detect (
  input  wire asynch_sig_in,
  input  wire clk,
  input  wire rst_n,
  output wire rise_edge
);

  wire sync1, sync2, sync2_d;

  // 2-FF synchronizer (reduces metastability probability)
  (* ASYNC_REG = "TRUE" *) dff FF1(.D(asynch_sig_in), .clk(clk), .Q(sync1), .PRN(rst_n));
  (* ASYNC_REG = "TRUE" *) dff FF2(.D(sync1),         .clk(clk), .Q(sync2), .PRN(rst_n));

  // 1-cycle delay for edge detection
  dff FF3(.D(sync2), .clk(clk), .Q(sync2_d), .PRN(rst_n));

  // Rising-edge pulse (high for 1 clk after sync2 goes 0->1)
  assign rise_edge = sync2 & ~sync2_d;

endmodule
