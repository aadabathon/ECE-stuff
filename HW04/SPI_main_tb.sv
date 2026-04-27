`timescale 1ns/1ps

module SPI_main_tb;

    // Testbench-side signals that connect to the DUT and the sensor model
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

    // DUT = your SPI master
    SPI_main dut (
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

    // NEMO = provided slave / sensor model
    // This is what your SPI master is talking to
    SPI_iNEMO nemo (
        .SS_n(SS_n),
        .SCLK(SCLK),
        .MISO(MISO),
        .MOSI(MOSI),
        .INT(INT)
    );

    // 50 MHz clock: period = 20 ns
    initial clk = 1'b0;
    always #10 clk = ~clk;

    // start_cmd:
    // Apply a new 16-bit command and pulse wrt for one clock cycle.
    // This tells SPI_main to begin a transaction.
    task automatic start_cmd(input [15:0] cmd);
        begin
            @(negedge clk);
            wt_data = cmd;
            wrt     = 1'b1;

            @(negedge clk);
            wrt     = 1'b0;
        end
    endtask

    // wait_done:
    // Wait for the DUT to raise done, meaning the SPI transfer finished.
    // Then step to the next negedge so outputs have settled cleanly.
    task automatic wait_done;
        begin
            wait(done === 1'b1);
            @(negedge clk);
        end
    endtask

    // spi_xfer:
    // Convenience wrapper: launch a command, then wait for it to complete.
    task automatic spi_xfer(input [15:0] cmd);
        begin
            start_cmd(cmd);
            wait_done();
        end
    endtask

    // check_equal_16:
    // Generic self-check for a full 16-bit expected value.
    // Useful if you ever want to verify an entire returned word.
    task automatic check_equal_16(
        input [15:0] got,
        input [15:0] exp,
        input [255:0] msg
    );
        begin
            if (got !== exp) begin
                $display("FAIL: %s  got=%h exp=%h  time=%0t", msg, got, exp, $time);
                $fatal;
            end
            else begin
                $display("PASS: %s  got=%h  time=%0t", msg, got, $time);
            end
        end
    endtask

    // check_low_byte:
    // Most SPI reads here only care about the returned data byte in rd_data[7:0].
    // The upper byte is often just leftover/garbage/command-path data.
    task automatic check_low_byte(
        input [15:0] got,
        input [7:0] exp,
        input [255:0] msg
    );
        begin
            if (got[7:0] !== exp) begin
                $display("FAIL: %s  got=%h exp_low=%h  time=%0t", msg, got, exp, $time);
                $fatal;
            end
            else begin
                $display("PASS: %s  got=%h  time=%0t", msg, got, $time);
            end
        end
    endtask

    initial begin
        // Initial conditions before reset release
        rst_n   = 1'b0;
        wrt     = 1'b0;
        wt_data = 16'h0000;

        // Hold reset low for a few cycles so everything initializes
        repeat (5) @(negedge clk);
        rst_n = 1'b1;

        $display("Starting SPI_main testbench...");

        // ------------------------------------------------------------
        // TEST 1: Read WHO_AM_I register
        //
        // 16'h8F00 means:
        //   8'h8F = read register 0x0F
        //   8'h00 = dummy byte so the slave can shift data back to us
        //
        // Expected low byte from NEMO is 0x6A.
        // ------------------------------------------------------------
        spi_xfer(16'h8F00);
        check_low_byte(rd_data, 8'h6A, "WHO_AM_I read");

        // ------------------------------------------------------------
        // TEST 2: Write 0x02 to register 0x0D
        //
        // This enables NEMO setup / interrupt generation in the model.
        // Then immediately read the register back to prove the write stuck.
        // ------------------------------------------------------------
        spi_xfer(16'h0D02);   // write 0x02 to reg 0x0D
        spi_xfer(16'h8D00);   // read back reg 0x0D

        $display("INFO: INT cfg reg readback = %h", rd_data[7:0]);

        if (rd_data[7:0] !== 8'h02) begin
            $display("FAIL: write to 0x0D did not stick");
            $fatal;
        end

        $display("INFO: write rd_data = %h", rd_data);

        // ------------------------------------------------------------
        // TEST 3: Wait for INT to assert
        //
        // After NEMO is configured, its internal update counter should
        // eventually assert INT.
        //
        // We use a timeout so the simulation does not hang forever if
        // something is broken.
        // ------------------------------------------------------------
        fork
            begin
                wait (INT === 1'b1);
                $display("PASS: INT asserted at time %0t", $time);
            end
            begin
                #1000000;
                $display("FAIL: timeout waiting for INT");
                $fatal;
            end
        join_any
        disable fork;

        $display("PASS: INT asserted at time %0t", $time);

        // ------------------------------------------------------------
        // TEST 4: Read yaw low byte
        //
        // Register 0x26 is yawL in the model.
        // Reading it should also clear INT.
        // ------------------------------------------------------------
        spi_xfer(16'hA600);
        $display("INFO: yawL read rd_data = %h", rd_data);

        // After reading yawL, INT should clear
        @(negedge clk);
        if (INT !== 1'b0) begin
            $display("FAIL: INT did not clear after yawL read, INT=%b time=%0t", INT, $time);
            $fatal;
        end
        else begin
            $display("PASS: INT cleared after yawL read");
        end

        // ------------------------------------------------------------
        // TEST 5: Read yaw high byte
        //
        // Register 0x27 is yawH in the model.
        // This is mostly a smoke test here to show another valid read.
        // ------------------------------------------------------------
        spi_xfer(16'hA700);
        $display("INFO: yawH read rd_data = %h", rd_data);

        $display("YAHOOOO!!!! ALL BASIC TESTS PASSED");
        $finish;
    end

endmodule