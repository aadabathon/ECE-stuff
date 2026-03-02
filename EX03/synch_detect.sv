module synch_detect ( 
  input  logic asynch_sig_in,
  input  logic clk,
  input  logic rst_n,
  output logic rise_edge
);

  logic n_async;
  logic q1, q2;
  logic sync;
  logic sync_d;
  logic n_sync;
  logic q3;

  not (n_async, asynch_sig_in);

  (* ASYNC_REG = "TRUE" *) dff FF1(.D(n_async), .clk(clk), .Q(q1), .PRN(rst_n));
  (* ASYNC_REG = "TRUE" *) dff FF2(.D(q1),      .clk(clk), .Q(q2), .PRN(rst_n));

  not (sync, q2);
  
  not (n_sync, sync);
  dff FF3(.D(n_sync), .clk(clk), .Q(q3), .PRN(rst_n));
  not (sync_d, q3);

  assign rise_edge = sync & ~sync_d;

endmodule
