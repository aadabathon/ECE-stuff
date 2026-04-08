module piezo_drv_test (
    input  logic clk,
    input  logic RST_n,
    input  logic batt_low,
    input  logic fanfare,
    output logic piezo,
    output logic piezo_n
);

    logic rst_n;

    reset_synch u_reset_synch (
        .clk   (clk),
        .RST_n (RST_n),
        .rst_n (rst_n)
    );

    piezo_drv #(.FAST_SIM(0)) u_piezo_drv (
        .clk     (clk),
        .rst_n   (rst_n),
        .batt_low(batt_low),
        .fanfare (fanfare),
        .piezo   (piezo),
        .piezo_n (piezo_n)
    );

endmodule