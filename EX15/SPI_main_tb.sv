`timescale 1ns/1ps

module SPI_main_tb;

    logic clk;
    logic rst_n;
    logic wrt;
    logic [15:0] wt_data;
    logic MISO;
    logic SS_n;
    logic SCLK;
    logic MOSI;
    logic done;
    logic [15:0] rd_data;
    logic INT;

    SPI_main iDUT(
        .clk(clk),
        .rst_n(rst_n),
        .wrt(wrt),
        .wt_data(wt_data),
        .MISO(MISO),
        .SS_n(SS_n),
        .SCLK(SCLK),
        .MOSI(MOSI),
        .done(done),
        .rd_data(rd_data)
    );

    SPI_NEMO iNEMO(
        .clk(clk),
        .rst_n(rst_n),
        .SS_n(SS_n),
        .SCLK(SCLK),
        .MOSI(MOSI),
        .MISO(MISO),
        .INT(INT)
    );

    initial clk = 0;
    always #10 clk = ~clk;

    task automatic pulse_wrt(input [15:0] cmd);
        begin
            @(negedge clk);
            wt_data = cmd;
            wrt = 1'b1;
            @(negedge clk);
            wrt = 1'b0;
        end
    endtask

    task automatic wait_done;
        begin
            wait(done === 1'b1);
            @(negedge clk);
        end
    endtask

    task automatic check_eq16(input [15:0] got, input [15:0] exp, input string msg);
        begin
            if (got !== exp) begin
                $display("FAIL: %s got=%h exp=%h time=%0t", msg, got, exp, $time);
                $fatal;
            end
            else begin
                $display("PASS: %s got=%h time=%0t", msg, got, $time);
            end
        end
    endtask

    task automatic do_spi(input [15:0] cmd);
        begin
            pulse_wrt(cmd);
            wait_done();
        end
    endtask

    initial begin
        rst_n   = 0;
        wrt     = 0;
        wt_data = 16'h0000;

        repeat (5) @(negedge clk);
        rst_n = 1;

        do_spi(16'h8F00);
        check_eq16(rd_data, 16'hxx6A, "WHO_AM_I read should return 0x6A in low byte");

        do_spi(16'h0D02);

        wait(INT === 1'b1);
        $display("PASS: INT asserted after config");

        do_spi(16'hA600);
        $display("INFO: yawL read rd_data=%h", rd_data);

        do_spi(16'hA700);
        $display("INFO: yawH read rd_data=%h", rd_data);

        $display("BASIC SPI_main TB PASSED");
        $finish;
    end

endmodule