// synchronous.sv

module reset_release_sync (
  input  logic clk,
  input  logic arst_n,
  output logic srst_n
);
  logic [1:0] r;

  always_ff @(posedge clk or negedge arst_n) begin
    if (!arst_n) r <= 2'b00;
    else         r <= {r[0], 1'b1};
  end

  assign srst_n = r[1];
endmodule


module async_sync #(
  parameter int STAGES = 2
) (
  input  logic clk,
  input  logic srst_n,
  input  logic async_in,
  output logic sync_out
);
  (* ASYNC_REG = "TRUE" *) logic [STAGES-1:0] s;

  always_ff @(posedge clk or negedge srst_n) begin
    if (!srst_n) s <= '0;
    else         s <= {s[STAGES-2:0], async_in};
  end

  assign sync_out = s[STAGES-1];
endmodule


module top_example (
  input  logic clk,
  input  logic arst_n,
  input  logic ext_async,
  output logic ext_sync,
  output logic ext_rise_pulse
);
  logic srst_n;
  logic ext_sync_d;

  reset_release_sync u_rst (.clk(clk), .arst_n(arst_n), .srst_n(srst_n));

  async_sync #(.STAGES(2)) u_sync (
    .clk(clk),
    .srst_n(srst_n),
    .async_in(ext_async),
    .sync_out(ext_sync)
  );

  always_ff @(posedge clk or negedge srst_n) begin
    if (!srst_n) ext_sync_d <= 1'b0;
    else         ext_sync_d <= ext_sync;
  end

  assign ext_rise_pulse = ext_sync & ~ext_sync_d;
endmodule
