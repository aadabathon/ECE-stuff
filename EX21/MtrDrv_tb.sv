module MtrDrv_tb;

    logic        clk;
    logic        rst_n;
    logic [11:0] rght_spd;
    logic [11:0] lft_spd;
    logic [11:0] vbatt;
    logic        lftPWM1;
    logic        lftPWM2;
    logic        rghtPWM1;
    logic        rghtPWM2;

    integer lft_count;
    integer rght_count;
    integer i;

    MtrDrv dut (
        .clk(clk),
        .rst_n(rst_n),
        .rght_spd(rght_spd),
        .lft_spd(lft_spd),
        .vbatt(vbatt),
        .lftPWM1(lftPWM1),
        .lftPWM2(lftPWM2),
        .rghtPWM1(rghtPWM1),
        .rghtPWM2(rghtPWM2)
    );

    initial clk = 1'b0;
    always #5 clk = ~clk;

    task automatic measure_pwm;
        output integer lcnt;
        output integer rcnt;
        input integer cycles;
        begin
            lcnt = 0;
            rcnt = 0;
            for (i = 0; i < cycles; i = i + 1) begin
                @(posedge clk);
                if (lftPWM1)  lcnt = lcnt + 1;
                if (rghtPWM1) rcnt = rcnt + 1;
            end
        end
    endtask

    task automatic show_internal_state;
        begin
            $display("    scale_factor=%h lft_prod=%h rght_prod=%h lft_scaled=%h rght_scaled=%h lft_final=%h rght_final=%h",
                     dut.scale_factor, dut.lft_prod, dut.rght_prod,
                     dut.lft_scaled, dut.rght_scaled, dut.lft_final, dut.rght_final);
        end
    endtask

    initial begin
        rst_n    = 1'b0;
        lft_spd  = 12'h000;
        rght_spd = 12'h000;
        vbatt    = 12'hDB0;

        repeat (2) @(posedge clk);
        rst_n = 1'b1;

        // -----------------------------------------
        // TEST 1:
        // Zero input should give about 50% duty regardless of battery
        // -----------------------------------------
        $display("\n=== TEST 1: zero input, ~50%% duty ===");

        lft_spd  = 12'h000;
        rght_spd = 12'h000;
        vbatt    = 12'hDB0;
        @(posedge clk);
        show_internal_state();
        measure_pwm(lft_count, rght_count, 4096);
        $display("[%0t] vbatt=%h lftPWM1 high count=%0d rghtPWM1 high count=%0d",
                 $time, vbatt, lft_count, rght_count);

        if (lft_count < 2000 || lft_count > 2096 || rght_count < 2000 || rght_count > 2096)
            $fatal(1, "TEST 1 FAILED at vbatt=%h: expected about 2048 high counts out of 4096", vbatt);

        vbatt = 12'hD00;
        @(posedge clk);
        show_internal_state();
        measure_pwm(lft_count, rght_count, 4096);
        $display("[%0t] vbatt=%h lftPWM1 high count=%0d rghtPWM1 high count=%0d",
                 $time, vbatt, lft_count, rght_count);

        if (lft_count < 2000 || lft_count > 2096 || rght_count < 2000 || rght_count > 2096)
            $fatal(1, "TEST 1 FAILED at vbatt=%h: expected about 2048 high counts out of 4096", vbatt);

        vbatt = 12'hFF0;
        @(posedge clk);
        show_internal_state();
        measure_pwm(lft_count, rght_count, 4096);
        $display("[%0t] vbatt=%h lftPWM1 high count=%0d rghtPWM1 high count=%0d",
                 $time, vbatt, lft_count, rght_count);

        if (lft_count < 2000 || lft_count > 2096 || rght_count < 2000 || rght_count > 2096)
            $fatal(1, "TEST 1 FAILED at vbatt=%h: expected about 2048 high counts out of 4096", vbatt);

        $display("TEST 1 PASSED");

        // -----------------------------------------
        // TEST 2:
        // lft_spd = 0x3FF at unity scaling battery (0xDB)
        // -----------------------------------------
        $display("\n=== TEST 2: left motor positive command at unity battery ===");
        lft_spd  = 12'h3FF;
        rght_spd = 12'h000;
        vbatt    = 12'hDB0;
        @(posedge clk);
        show_internal_state();
        measure_pwm(lft_count, rght_count, 4096);
        $display("[%0t] lftPWM1 high count=%0d rghtPWM1 high count=%0d",
                 $time, lft_count, rght_count);

        if (lft_count <= 2048)
            $fatal(1, "TEST 2 FAILED: expected lftPWM1 > 2048 highs out of 4096, got %0d", lft_count);

        $display("TEST 2 PASSED");

        // -----------------------------------------
        // TEST 3:
        // lft_spd = 0x3FF at lower battery (0xD0)
        // -----------------------------------------
        $display("\n=== TEST 3: left motor positive command at lower battery ===");
        lft_spd  = 12'h3FF;
        rght_spd = 12'h000;
        vbatt    = 12'hD00;
        @(posedge clk);
        show_internal_state();
        measure_pwm(lft_count, rght_count, 4096);
        $display("[%0t] lftPWM1 high count=%0d rghtPWM1 high count=%0d",
                 $time, lft_count, rght_count);

        if (lft_count <= 2048)
            $fatal(1, "TEST 3 FAILED: expected lftPWM1 > 2048 highs out of 4096, got %0d", lft_count);

        $display("TEST 3 PASSED");

		// -----------------------------------------
		// TEST 4:
		// rght_spd = 0xC00 at fresh battery (0xFF)
		// Check right motor inversion behavior
		// -----------------------------------------
		$display("\n=== TEST 4: right motor inverted behavior ===");
		lft_spd  = 12'h000;
		rght_spd = 12'hC00;
		vbatt    = 12'hFF0;
		@(posedge clk);
		show_internal_state();
		measure_pwm(lft_count, rght_count, 4096);
		$display("[%0t] lftPWM1 high count=%0d rghtPWM1 high count=%0d",
				 $time, lft_count, rght_count);

		if (rght_count >= 200)
			$fatal(1, "TEST 4 FAILED: expected rghtPWM1 to stay low most of the time due to right motor inversion, got %0d highs", rght_count);

		$display("TEST 4 PASSED");

		// -----------------------------------------
		// TEST 5:
		// Drive both motors together
		// -----------------------------------------
		$display("\n=== TEST 5: both motors driven together ===");
		lft_spd  = 12'h200;
		rght_spd = 12'hE00;
		vbatt    = 12'hE00;
		@(posedge clk);
		show_internal_state();
		measure_pwm(lft_count, rght_count, 4096);
		$display("[%0t] lftPWM1 high count=%0d rghtPWM1 high count=%0d",
				 $time, lft_count, rght_count);

		if (lft_count <= 2048)
			$fatal(1, "TEST 5 FAILED: expected lftPWM1 to be above 50%% duty, got %0d highs", lft_count);

		if (rght_count >= 200)
			$fatal(1, "TEST 5 FAILED: expected rghtPWM1 to stay low most of the time, got %0d highs", rght_count);

		$display("TEST 5 PASSED");
        $display("\nAll MtrDrv tests passed.\n");

        $stop;
    end

endmodule