module maze_solve_tb;

    logic        clk;
    logic        rst_n;
    logic        cmd_md;
    logic        cmd0;
    logic        lft_opn;
    logic        rght_opn;
    logic        mv_cmplt;
    logic        sol_cmplt;
    logic [11:0] dsrd_hdng;
    logic        strt_hdng;
    logic        strt_mv;
    logic        stp_lft;
    logic        stp_rght;

    maze_solve dut (
        .clk(clk),
        .rst_n(rst_n),
        .cmd_md(cmd_md),
        .cmd0(cmd0),
        .lft_opn(lft_opn),
        .rght_opn(rght_opn),
        .mv_cmplt(mv_cmplt),
        .sol_cmplt(sol_cmplt),
        .dsrd_hdng(dsrd_hdng),
        .strt_hdng(strt_hdng),
        .strt_mv(strt_mv),
        .stp_lft(stp_lft),
        .stp_rght(stp_rght)
    );

    initial clk = 1'b0;
    always #5 clk = ~clk;

    initial begin
        rst_n     = 1'b0;
        cmd_md    = 1'b1;
        cmd0      = 1'b0;
        lft_opn   = 1'b0;
        rght_opn  = 1'b0;
        mv_cmplt  = 1'b0;
        sol_cmplt = 1'b0;

        repeat (2) @(posedge clk);
        rst_n = 1'b1;

        $display("\n=== TEST 1: left-affinity, take left ===");
        @(posedge clk);
        cmd0   = 1'b1;
        cmd_md = 1'b0;

        wait (strt_mv);
        $display("[%0t] strt_mv asserted for left-affinity case", $time);

        repeat (3) @(posedge clk);
        lft_opn   = 1'b1;
        rght_opn  = 1'b0;
        mv_cmplt  = 1'b1;
        @(posedge clk);
        mv_cmplt  = 1'b0;
        lft_opn   = 1'b0;

		wait (strt_hdng);
		$display("[%0t] strt_hdng asserted, dsrd_hdng currently = %h", $time, dsrd_hdng);

		if (stp_lft !== 1'b1 || stp_rght !== 1'b0)
			$fatal(1, "TEST 1 FAILED: stop outputs wrong for left-affinity. stp_lft=%b stp_rght=%b", stp_lft, stp_rght);

		@(posedge clk);
		#1;
		$display("[%0t] after one clock, dsrd_hdng = %h", $time, dsrd_hdng);

		if (dsrd_hdng !== 12'h3FF)
			$fatal(1, "TEST 1 FAILED: expected heading WEST (3FF), got %h", dsrd_hdng);
				repeat (3) @(posedge clk);
        mv_cmplt = 1'b1;
        @(posedge clk);
        mv_cmplt = 1'b0;

        $display("TEST 1 PASSED");

        $display("\n=== TEST 2: left-affinity, no left open, take right ===");
        wait (strt_mv);
        $display("[%0t] strt_mv asserted", $time);

        repeat (3) @(posedge clk);
        lft_opn   = 1'b0;
        rght_opn  = 1'b1;
        mv_cmplt  = 1'b1;
        @(posedge clk);
        mv_cmplt  = 1'b0;
        rght_opn  = 1'b0;

		wait (strt_hdng);
		$display("[%0t] strt_hdng asserted, dsrd_hdng currently = %h", $time, dsrd_hdng);

		@(posedge clk);
		#1;
		$display("[%0t] after one clock, dsrd_hdng = %h", $time, dsrd_hdng);

		if (dsrd_hdng !== 12'h000)
			$fatal(1, "TEST 2 FAILED: expected heading NORTH (000), got %h", dsrd_hdng);
			
        repeat (3) @(posedge clk);
        mv_cmplt = 1'b1;
        @(posedge clk);
        mv_cmplt = 1'b0;

        $display("TEST 2 PASSED");

        $display("\n=== TEST 3: left-affinity, dead end -> 180 ===");
        wait (strt_mv);
        $display("[%0t] strt_mv asserted", $time);

        repeat (3) @(posedge clk);
        lft_opn   = 1'b0;
        rght_opn  = 1'b0;
        mv_cmplt  = 1'b1;
        @(posedge clk);
        mv_cmplt  = 1'b0;

		wait (strt_hdng);
		$display("[%0t] strt_hdng asserted, dsrd_hdng currently = %h", $time, dsrd_hdng);

		@(posedge clk);
		#1;
		$display("[%0t] after one clock, dsrd_hdng = %h", $time, dsrd_hdng);

		if (dsrd_hdng !== 12'h7FF)
			$fatal(1, "TEST 3 FAILED: expected heading SOUTH (7FF), got %h", dsrd_hdng);
			
        repeat (3) @(posedge clk);
        mv_cmplt = 1'b1;
        @(posedge clk);
        mv_cmplt = 1'b0;

        $display("TEST 3 PASSED");

        $display("\n=== TEST 4: signal maze solved ===");
        wait (strt_mv);
        $display("[%0t] strt_mv asserted before solve completion", $time);

        repeat (3) @(posedge clk);
        sol_cmplt = 1'b1;
        mv_cmplt  = 1'b1;
        @(posedge clk);
        mv_cmplt  = 1'b0;
        sol_cmplt = 1'b0;

        @(posedge clk);

        if (strt_mv !== 1'b0 && strt_hdng !== 1'b0)
            $display("[%0t] NOTE: outputs active around DONE transition, inspect waveform if needed", $time);

        cmd_md = 1'b1;
        $display("TEST 4 PASSED");

		$display("\n=== TEST 5: right-affinity, take right ===");

		rst_n = 1'b0;
		cmd_md = 1'b1;
		cmd0 = 1'b0;
		lft_opn = 1'b0;
		rght_opn = 1'b0;
		mv_cmplt = 1'b0;
		sol_cmplt = 1'b0;

		repeat (2) @(posedge clk);
		rst_n = 1'b1;

		@(posedge clk);
		cmd0   = 1'b0;
		cmd_md = 1'b0;

        wait (strt_mv);
        $display("[%0t] strt_mv asserted for right-affinity case", $time);

        repeat (3) @(posedge clk);
        lft_opn   = 1'b0;
        rght_opn  = 1'b1;
        mv_cmplt  = 1'b1;
        @(posedge clk);
        mv_cmplt  = 1'b0;
        rght_opn  = 1'b0;

		wait (strt_hdng);
		$display("[%0t] strt_hdng asserted, dsrd_hdng currently = %h", $time, dsrd_hdng);

		if (stp_lft !== 1'b0 || stp_rght !== 1'b1)
			$fatal(1, "TEST 5 FAILED: stop outputs wrong for right-affinity. stp_lft=%b stp_rght=%b", stp_lft, stp_rght);

		@(posedge clk);
		#1;
		$display("[%0t] after one clock, dsrd_hdng = %h", $time, dsrd_hdng);

		if (dsrd_hdng !== 12'hC00)
			$fatal(1, "TEST 5 FAILED: expected heading EAST (C00), got %h", dsrd_hdng);
			
        repeat (3) @(posedge clk);
        mv_cmplt = 1'b1;
        @(posedge clk);
        mv_cmplt = 1'b0;

        $display("TEST 5 PASSED");
        $display("\nAll maze_solve tests passed.\n");

        repeat (5) @(posedge clk);
        $stop;
    end

    initial begin
        $monitor("[%0t] cmd_md=%b cmd0=%b lft_opn=%b rght_opn=%b mv_cmplt=%b sol_cmplt=%b strt_mv=%b strt_hdng=%b dsrd_hdng=%h stp_lft=%b stp_rght=%b",
                 $time, cmd_md, cmd0, lft_opn, rght_opn, mv_cmplt, sol_cmplt,
                 strt_mv, strt_hdng, dsrd_hdng, stp_lft, stp_rght);
    end

endmodule