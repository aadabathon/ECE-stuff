module up_dwn_tb();

reg clk, rst_n;
reg en, up_dwn_n;
wire [3:0] cnt;

// Instantiate DUT //
counter iDUT(.clk(clk), .rst_n(rst_n), .en(en), .up_dwn_n(up_dwn_n), .cnt(cnt));

reg [3:0] exp;

initial begin
  clk = 0;
  rst_n = 0;
  en = 0;
  up_dwn_n = 1;
  exp = 4'd0;

  @(posedge clk);
  @(negedge clk) rst_n = 1;

  @(posedge clk) en = 1;
  repeat (5) @(posedge clk);

  en = 0;
  @(posedge clk) en = 1;
  repeat (2) @(posedge clk);

  up_dwn_n = 0;
  repeat (3) @(posedge clk);

  $display("PASS (no mismatches)");
  $finish;
end

always #5 clk = ~clk;

// golden model + check
always @(posedge clk or negedge rst_n) begin
  if (!rst_n) begin
    exp <= 4'd0;
  end else if (en) begin
    exp <= up_dwn_n ? (exp + 4'd1) : (exp - 4'd1);
  end
end

always @(posedge clk) begin
  if (rst_n) begin
    assert (cnt === exp)
      else begin
        $error("Mismatch @%0t: cnt=%0d exp=%0d (en=%0b up_dwn_n=%0b)", $time, cnt, exp, en, up_dwn_n);
        $fatal;
      end
  end
end

endmodule
