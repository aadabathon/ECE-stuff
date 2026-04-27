`timescale 1ns/1ps

module PID_tb;

  logic clk;
  logic rst_n, moving, hdng_vld;
  logic signed [11:0] dsrd_hdng, actl_hdng;
  logic [10:0] frwrd_spd;

  wire at_hdng;
  wire [11:0] lft_spd, rght_spd;

  logic [37:0] stim_mem [0:1999];
  logic [24:0] resp_mem [0:1999];

  logic [24:0] dut_resp;

  integer i;
  integer errors;

  PID dut (
    .clk(clk),
    .rst_n(rst_n),
    .hdng_vld(hdng_vld),
    .moving(moving),
    .dsrd_hdng(dsrd_hdng),
    .actl_hdng(actl_hdng),
    .frwrd_spd(frwrd_spd),
    .at_hdng(at_hdng),
    .lft_spd(lft_spd),
    .rght_spd(rght_spd)
  );

  assign dut_resp = {at_hdng, lft_spd, rght_spd};

  initial begin
    clk = 1'b0;
    forever #5 clk = ~clk;
  end

  initial begin
    $readmemh("PID_stim.hex", stim_mem);
    $readmemh("PID_resp.hex", resp_mem);

    errors = 0;

    rst_n      = 0;
    moving     = 0;
    hdng_vld   = 0;
    dsrd_hdng  = '0;
    actl_hdng  = '0;
    frwrd_spd  = '0;

    @(negedge clk);

    for (i = 0; i < 2000; i = i + 1) begin
      {rst_n, moving, hdng_vld, dsrd_hdng, actl_hdng, frwrd_spd} = stim_mem[i];

      @(posedge clk);
      #1;

      if (dut_resp !== resp_mem[i]) begin
        errors = errors + 1;
        $display("Mismatch at vector %0d", i);
        $display("  stim     = %h", stim_mem[i]);
        $display("  expected = %h", resp_mem[i]);
        $display("  got      = %h", dut_resp);
      end

      @(negedge clk);
    end

    if (errors == 0)
      $display("Adam: all 2000 PID vectors matched. W");
    else
      $display("Adam: %0d mismatches found.", errors);

    $stop;
  end

endmodule