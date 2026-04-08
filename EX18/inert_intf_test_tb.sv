`timescale 1ns/1ps

module inert_intf_test_tb;

    logic clk;
    logic RST_n;
    logic [7:0] LED_stim;
    logic SS_n, SCLK, MOSI, MISO, INT;
	logic [11:0] heading_tb;
	
    localparam [1:0] IDLE = 2'b00;
    localparam [1:0] CAL  = 2'b01;
    localparam [1:0] DISP = 2'b10;

    always #10 clk = ~clk;

    inert_intf_test dut(
        .clk(clk),
        .RST_n(RST_n),
        .LED(LED_stim),
        .SS_n(SS_n),
        .SCLK(SCLK),
        .MOSI(MOSI),
        .MISO(MISO),
        .INT(INT)
    );

    task automatic step;
    begin
        @(posedge clk);
        #1;
    end
    endtask

    task automatic release_forces;
    begin
        release dut.cal_done;
        release dut.heading;
    end
    endtask

    task automatic sync_reset_release;
    begin
        release_forces();

        RST_n = 1'b0;
        #1;
        if (dut.rst_n !== 1'b0)
            $fatal(1, "reset_synch fail: rst_n did not async assert low");

        #7;
        RST_n = 1'b1;
        #1;
        if (dut.rst_n !== 1'b0)
            $fatal(1, "reset_synch fail: rst_n deasserted too early");

        @(negedge clk);
        #1;
        if (dut.rst_n !== 1'b0)
            $fatal(1, "reset_synch fail: rst_n should still be low after first negedge");

        @(negedge clk);
        #1;
        if (dut.rst_n !== 1'b1)
            $fatal(1, "reset_synch fail: rst_n should deassert after second negedge");

        if (dut.state_q !== IDLE)
            $fatal(1, "FSM fail: state_q should be IDLE after reset release");
    end
    endtask

    task automatic goto_cal;
    begin
        force dut.cal_done = 1'b0;

        @(negedge clk);
        dut.tmr = 17'h1FFFE;

        step();
        if (dut.state_q !== IDLE)
            $fatal(1, "goto_cal fail: should still be IDLE one cycle before timer fills");
        if (dut.strt_cal !== 1'b0)
            $fatal(1, "goto_cal fail: strt_cal asserted too early");

        step();
        if (dut.state_q !== CAL)
            $fatal(1, "goto_cal fail: did not enter CAL after timer filled");
        if (dut.strt_cal !== 1'b1)
            $fatal(1, "goto_cal fail: strt_cal should be high in CAL");
    end
    endtask

    task automatic goto_disp(input logic [11:0] hdg);
    begin
        heading_tb = hdg;
		force dut.heading = heading_tb;
        
		force dut.cal_done = 1'b0;

        goto_cal();

        @(negedge clk);
        force dut.cal_done = 1'b1;

        step();
        if (dut.state_q !== DISP)
            $fatal(1, "goto_disp fail: did not enter DISP after cal_done");
        if (LED_stim !== hdg[11:4])
            $fatal(1, "goto_disp fail: LED != heading[11:4] in DISP");
    end
    endtask

    task automatic test_res_synch;
    begin
        $display("TEST1: reset synchronizer");
        sync_reset_release();

        if (dut.strt_cal !== 1'b0)
            $fatal(1, "TEST1 fail: strt_cal should be low after reset release");

        $display("TEST1 passed");
    end
    endtask

    task automatic test_wrapper_FSM;
    begin
        $display("TEST2: wrapper FSM IDLE -> CAL");
        sync_reset_release();
        goto_cal();
        release dut.cal_done;
        $display("TEST2 passed");
    end
    endtask

    task automatic test_cal_display;
    begin
        $display("TEST3: CAL display");
        sync_reset_release();
        goto_cal();

        if (LED_stim !== 8'hA5)
            $fatal(1, "TEST3 fail: LED should be 8'hA5 in CAL");
        if (dut.strt_cal !== 1'b1)
            $fatal(1, "TEST3 fail: strt_cal should be high in CAL");

        repeat (2) begin
            step();
            if (dut.state_q !== CAL)
                $fatal(1, "TEST3 fail: should remain in CAL while cal_done=0");
            if (LED_stim !== 8'hA5)
                $fatal(1, "TEST3 fail: LED should stay 8'hA5 in CAL");
        end

        release dut.cal_done;
        $display("TEST3 passed");
    end
    endtask

    task automatic test_cal_done;
    begin
        $display("TEST4: exit CAL on cal_done");
        sync_reset_release();
        force dut.heading = 12'hABC;
        goto_cal();

        @(negedge clk);
        force dut.cal_done = 1'b1;

        step();
        if (dut.state_q !== DISP)
            $fatal(1, "TEST4 fail: should move to DISP on cal_done");
        if (LED_stim !== 8'hAB)
            $fatal(1, "TEST4 fail: LED should show heading[11:4] = 8'hAB");

        release_forces();
        $display("TEST4 passed");
    end
    endtask

    task automatic test_disp_sticky;
    begin
        $display("TEST5: DISP sticky except reset");
        sync_reset_release();
        goto_disp(12'hABC);

        @(negedge clk);
        force dut.heading  = 12'h5C3;
        force dut.cal_done = 1'b0;

        step();
        if (dut.state_q !== DISP)
            $fatal(1, "TEST5 fail: left DISP unexpectedly");
        if (LED_stim !== 8'h5C)
            $fatal(1, "TEST5 fail: LED should track heading[11:4] while staying in DISP");

        @(negedge clk);
        force dut.cal_done = 1'b1;

        step();
        if (dut.state_q !== DISP)
            $fatal(1, "TEST5 fail: cal_done should not knock FSM out of DISP");

        release_forces();
        $display("TEST5 passed");
    end
    endtask

    task automatic test_resets;
    begin
        $display("TEST6: reset from CAL and DISP");

        sync_reset_release();
        goto_cal();

        RST_n = 1'b0;
        #1;
        if (dut.rst_n !== 1'b0)
            $fatal(1, "TEST6 fail: rst_n did not assert low from CAL");
        if (dut.state_q !== IDLE)
            $fatal(1, "TEST6 fail: FSM did not reset to IDLE from CAL");

        sync_reset_release();
        goto_disp(12'hABC);

        RST_n = 1'b0;
        #1;
        if (dut.rst_n !== 1'b0)
            $fatal(1, "TEST6 fail: rst_n did not assert low from DISP");
        if (dut.state_q !== IDLE)
            $fatal(1, "TEST6 fail: FSM did not reset to IDLE from DISP");

        release_forces();
        $display("TEST6 passed");
    end
    endtask

    initial begin
        clk  = 1'b0;
        RST_n = 1'b1;
        MISO = 1'b0;
        INT  = 1'b0;

        #1;
        test_res_synch();
        test_wrapper_FSM();
        test_cal_display();
        test_cal_done();
        test_disp_sticky();
        test_resets();

        $display("All tests passed");
        $stop;
    end

endmodule