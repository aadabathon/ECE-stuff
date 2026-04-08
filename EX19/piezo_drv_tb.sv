`timescale 1ns/1ps

module piezo_drv_tb;

logic clk;
logic rst_n;
logic batt_low;
logic fanfare;
logic piezo;
logic piezo_n;

localparam int FANFARE_CYCLES_FAST =
    (1 << 19) +   // G6
    (1 << 19) +   // C7
    (1 << 19) +   // E7
    (3 << 18) +   // G7
    (1 << 18) +   // E7
    (1 << 20);    // G7

piezo_drv #(.FAST_SIM(0)) dut (
    .clk(clk),
    .rst_n(rst_n),
    .batt_low(batt_low),
    .fanfare(fanfare),
    .piezo(piezo),
    .piezo_n(piezo_n)
);

initial clk = 1'b0;
always #10 clk = ~clk;

task automatic check_no_toggle(input int cycles, input string tag);
    logic prev_piezo, prev_piezo_n;
    int i;
    begin
        prev_piezo   = piezo;
        prev_piezo_n = piezo_n;
        for (i = 0; i < cycles; i++) begin
            @(posedge clk);
            if ((piezo !== prev_piezo) || (piezo_n !== prev_piezo_n)) begin
                $display("FAIL: %s: unexpected toggle at time %0t", tag, $time);
                $stop;
            end
            prev_piezo   = piezo;
            prev_piezo_n = piezo_n;
        end
    end
endtask

task automatic check_has_toggle(input int cycles, input string tag);
    logic prev_piezo, prev_piezo_n;
    int i;
    bit saw_toggle;
    begin
        prev_piezo   = piezo;
        prev_piezo_n = piezo_n;
        saw_toggle   = 1'b0;
        for (i = 0; i < cycles; i++) begin
            @(posedge clk);
            if ((piezo !== prev_piezo) || (piezo_n !== prev_piezo_n))
                saw_toggle = 1'b1;
            prev_piezo   = piezo;
            prev_piezo_n = piezo_n;
        end
        if (!saw_toggle) begin
            $display("FAIL: %s: no toggling observed by time %0t", tag, $time);
            $stop;
        end
    end
endtask

initial begin
    rst_n    = 1'b0;
    batt_low = 1'b0;
    fanfare  = 1'b0;

    repeat (5) @(posedge clk);
    rst_n = 1'b1;

    check_no_toggle(2000, "before fanfare");

    @(posedge clk);
    fanfare = 1'b1;
    @(posedge clk);
    fanfare = 1'b0;

    check_has_toggle(100000, "during fanfare");
    repeat (FANFARE_CYCLES_FAST + 1000) @(posedge clk);
    check_no_toggle(2000, "after fanfare completes");

    @(posedge clk);
    batt_low = 1'b1;

    check_has_toggle(100000, "during batt_low");

    repeat (700000) @(posedge clk);

    batt_low = 1'b0;
    check_no_toggle(5000, "after batt_low deasserted");

    $display("PASS: piezo_drv_tb completed successfully");
    $finish;
end

always @(posedge clk) begin
    if (piezo_n !== ~piezo) begin
        $display("FAIL: piezo_n is not the inverse of piezo at time %0t", $time);
        $stop;
    end
end

endmodule