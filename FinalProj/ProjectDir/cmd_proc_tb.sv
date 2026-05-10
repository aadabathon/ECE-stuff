module cmd_proc_tb();
    // ----------------------
    // INTERNAL SIGNALS 
    // ----------------------
    logic [15:0] cmd_in;
    logic snd_cmd;
    logic [7:0] resp;
    logic resp_rdy;
    localparam RESP = 8'hA5;
    // --------------------------
    // SIGNALS FROM COMM -> UART
    // --------------------------
    logic clk, rst_n, RX_TX, TX_RX;
    // ------------------------------
    // SIGNALS FROM UART -> CMD_PROC
    // ------------------------------
    logic [15:0] cmd_intern;
    logic cmd_rdy;
    logic clr_cmd_rdy;
    logic tmrt_in;
    logic tx_done;
    // ------------------------------
    // SIGNALS FROM CMD_PROC
    // ------------------------------
    logic strt_cal, in_cal;
    logic strt_hdng, strt_mv;
    logic stp_lft, stp_rght;
    logic [11:0] dsrd_hdng;
    logic cmd_md;
    // TX_RX : COMM -> UART
    // RX_TX : UART -> COMM
    // ------------------------------
    RemoteComm comm (.clk(clk), .rst_n(rst_n), .RX_TX(RX_TX), .TX_RX(TX_RX), .cmd(cmd_in), .snd_cmd(snd_cmd), .cmd_snt(cmd_snt), .resp_rdy(resp_rdy), .resp(resp));
    UART_wrapper uart (.clk(clk), .rst_n(rst_n), .RX(TX_RX), .TX(RX_TX), .resp(RESP),.trmt(tmrt_in), .cmd_rdy(cmd_rdy), .cmd(cmd_intern), .clr_cmd_rdy(clr_cmd_rdy), .tx_done(tx_done));
    // ------------------------------
    // FLOPPED SIGNALS IN PROC
    // ------------------------------
    logic cal_done_flop;
    logic sol_done_flop;
    logic mv_done_flop;

    logic cal_done_ff1;
    logic sol_done_ff1;
    logic mv_done_ff1;
    always_ff @(posedge clk or negedge rst_n) begin : blockName
        if (!rst_n) begin
            cal_done_flop <= 0;
            sol_done_flop <= 0;
            cal_done_ff1 <= 0;
            sol_done_ff1 <= 0;
        end else begin
            cal_done_flop <= cal_done_ff1;
            sol_done_flop <= sol_done_ff1;
            cal_done_ff1 <= proc.strt_cal;
            sol_done_ff1 <= ~proc.cmd_md;
        end
    end
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin 
            mv_done_flop <= 0;
            mv_done_ff1 <= 0;
        end else begin
            mv_done_flop <= mv_done_ff1;
            mv_done_ff1 <= proc.strt_mv || proc.strt_hdng;
        end
    end
    cmd_proc proc (.clk(clk),.rst_n(rst_n),.cmd(cmd_intern),.cmd_rdy(cmd_rdy),.clr_cmd_rdy(clr_cmd_rdy),.send_resp(tmrt_in),
        .strt_cal(strt_cal),.cal_done(cal_done_flop),.in_cal(in_cal),
        .strt_hdng(strt_hdng),.strt_mv(strt_mv),.stp_lft(stp_lft),.stp_rght(stp_rght),.dsrd_hdng(dsrd_hdng),
        .mv_cmplt(mv_done_flop),.cmd_md(cmd_md),.sol_cmplt(sol_done_flop));
    // ------------------------------
    // CLOCK GENERATION
    // ------------------------------
    initial begin
        clk = 0;
        forever #5 clk = ~clk; //100MHz clock
    end
    // ------------------------------
    // TEST SEQUENCE
    // ------------------------------
    initial begin
        cmd_in = 0;
        snd_cmd = 0;
        @( negedge clk);
        rst_n = 0;
        @( negedge clk);
        rst_n = 1;
        @( negedge clk);
        //Send a command to start calibration
        cmd_in = 16'b000_0000000000000; //Start calibration command
        snd_cmd = 1;
        @( negedge clk);
        snd_cmd = 0;
        //Wait for response to be ready
        fork
            begin
                wait (resp_rdy);
                $display("Test passed: resp_rdy and strt_call asserted");
            end
            begin
                #1000000; //Wait for 1000000 time units (enough time for the command to be processed)
                $display("Test failed: timeout waiting for response");
            end
        join_any
        disable fork;
        //---------- Test 3: Heading command ----------
        @( negedge clk);
        cmd_in = 16'h23FF; //Heading command, dsrd_hdng = 0x3FF (West)
        snd_cmd = 1;
        @( negedge clk);
        snd_cmd = 0;
        //Wait for strt_hdng
        fork
            begin
                wait (strt_hdng);
                $display("Test 3 passed: strt_hdng asserted");
            end
            begin
                #1000000;
                $display("Test 3 FAILED: timeout waiting for strt_hdng");
            end
        join_any
        disable fork;
        @(posedge clk);
        @(negedge clk); //Check dsrd_hdng one clock after strt_hdng to ensure NBA has settled
        if(proc.dsrd_hdng == 12'h3FF) $display("Test 3 passed: dsrd_hdng correctly set to 0x3FF");
        else $display("Test 3 FAILED: dsrd_hdng expected 0x3FF, got 0x%0h", proc.dsrd_hdng);
        //Wait for 0xA5 response
        fork
            begin
                @(posedge resp_rdy);
                if (resp == 8'hA5) $display("Test 3 passed: heading resp = 0xA5");
                else $display("Test 3 FAILED: heading resp expected 0xA5, got 0x%0h", resp);
            end
            begin
                #1000000;
                $display("Test 3 FAILED: timeout waiting for heading response");
            end
        join_any
        disable fork;
        //---------- Test 4: Move command (stop at left) ----------
        @( negedge clk);
        cmd_in = 16'h4002; //Move command, cmd[1]=1 -> stp_lft
        snd_cmd = 1;
        @( negedge clk);
        snd_cmd = 0;
        //Wait for strt_mv
        fork
            begin
                wait (strt_mv);
                $display("Test 4 passed: strt_mv asserted");
            end
            begin
                #1000000;
                $display("Test 4 FAILED: timeout waiting for strt_mv");
            end
        join_any
        disable fork;
        //One clock later check stp_lft (negedge ensures NBA settled)
        @(posedge clk);
        @(negedge clk);
        if (stp_lft) $display("Test 4 passed: stp_lft asserted");
        else $display("Test 4 FAILED: stp_lft not asserted");
        //Wait for move response
        fork
            begin
                @(posedge resp_rdy);
                if (resp == 8'hA5) $display("Test 4 passed: move resp = 0xA5");
                else $display("Test 4 FAILED: move resp expected 0xA5, got 0x%0h", resp);
            end
            begin
                #1000000;
                $display("Test 4 FAILED: timeout waiting for move response");
            end
        join_any
        disable fork;
        //---------- Test 5: Solve command ----------
        @( negedge clk);
        cmd_in = 16'h6000; //Solve command
        snd_cmd = 1;
        @( negedge clk);
        snd_cmd = 0;
        //Wait for cmd_md to go low
        fork
            begin
                wait (!cmd_md);
                $display("Test 5 passed: cmd_md deasserted for solve");
            end
            begin
                #1000000;
                $display("Test 5 FAILED: timeout waiting for cmd_md to deassert");
            end
        join_any
        disable fork;
        $display("All tests completed.");
        $stop;
    end
endmodule