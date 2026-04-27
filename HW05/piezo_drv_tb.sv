`timescale 1ns/1ps

module piezo_drv_tb;

logic clk;
logic rst_n;
logic batt_low;
logic fanfare;
logic piezo;
logic piezo_n;

localparam bit FAST_SIM = 1'b1;

localparam int DUR_2P22 = 4194304;
localparam int DUR_2P23 = 8388608;
localparam int DUR_3P22 = 12582912;
localparam int DUR_2P24 = 16777216;

localparam int DUR_INC = FAST_SIM ? 16 : 1;

localparam int NOTE_2P22 = DUR_2P22 / DUR_INC;
localparam int NOTE_2P23 = DUR_2P23 / DUR_INC;
localparam int NOTE_3P22 = DUR_3P22 / DUR_INC;
localparam int NOTE_2P24 = DUR_2P24 / DUR_INC;

localparam int FANFARE_TOTAL =
    NOTE_2P23 +
    NOTE_2P23 +
    NOTE_2P23 +
    NOTE_3P22 +
    NOTE_2P22 +
    NOTE_2P24;

piezo_drv #(.FAST_SIM(FAST_SIM)) dut (
    .clk(clk),
    .rst_n(rst_n),
    .batt_low(batt_low),
    .fanfare(fanfare),
    .piezo(piezo),
    .piezo_n(piezo_n)
);

initial clk = 1'b0;
always #10 clk = ~clk;

task automatic fail(input string msg);
begin
    $display("FAIL: %s at time %0t", msg, $time);
    $fatal;
end
endtask

task automatic step;
begin
    @(posedge clk);
    #1;
end
endtask

task automatic step_n(input int n);
int i;
begin
    for (i = 0; i < n; i++)
        step();
end
endtask

task automatic pulse_fanfare;
begin
    @(negedge clk);
    fanfare = 1'b1;
    repeat (8) @(negedge clk);
    fanfare = 1'b0;
end
endtask

task automatic set_batt_low(input logic val);
begin
    @(negedge clk);
    batt_low = val;
end
endtask

task automatic expect_idle(input int cycles, input string tag);
int i;
begin
    for (i = 0; i < cycles; i++) begin
        step();
        if (piezo !== 1'b0)
            fail({tag, ": piezo should be 0"});
        if (piezo_n !== 1'b1)
            fail({tag, ": piezo_n should be 1"});
    end
end
endtask

task automatic expect_activity(input int cycles, input string tag);
int i;
bit saw0;
bit saw1;
begin
    saw0 = 1'b0;
    saw1 = 1'b0;

    for (i = 0; i < cycles; i++) begin
        step();

        if (piezo === 1'b0)
            saw0 = 1'b1;
        if (piezo === 1'b1)
            saw1 = 1'b1;
    end

    if (!saw0 || !saw1)
        fail(tag);
end
endtask

always @(posedge clk) begin
    #1;
    if (piezo_n !== ~piezo)
        fail("piezo_n is not inverse of piezo");
end

initial begin
    rst_n    = 1'b0;
    batt_low = 1'b0;
    fanfare  = 1'b0;

    repeat (5) @(posedge clk);
    @(negedge clk);
    rst_n = 1'b1;

    expect_idle(2000, "after reset");

    pulse_fanfare();
    expect_activity(60000, "fanfare did not oscillate");

    step_n(FANFARE_TOTAL + 5000);
    step_n(3);
    expect_idle(3000, "after fanfare");

    set_batt_low(1'b1);
    expect_activity(60000, "batt_low did not start oscillating");

    step_n(NOTE_2P23 + 10000);
    expect_activity(60000, "batt_low did not stay active");

    set_batt_low(1'b0);
    step_n(3);
    expect_idle(5000, "after batt_low cleared");

    $display("PASS: piezo_drv_tb completed successfully");
    $finish;
end

endmodule