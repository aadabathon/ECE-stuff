module P_term_tb();
    
    logic signed [11:0] err_stim; // 1. Declare signals
    wire  signed [13:0] p_out;

    
    P_term iDUT ( // 2. Instantiate the Unit Under Test (UUT)
        .error(err_stim),
        .P_term(p_out)
    );

    
    initial begin // 3. Stimulus process
        $display("Time\t Error\t | Sat Out\t | P_term (x3)"); // Format the output display for readability
        $display("----------------------------------------------");
        
        err_stim = 12'sd0; // Case 1: Zero
        #10; display_results();

        err_stim = 12'sd100; // Case 2: Positive value (no saturation)
        #10; display_results();

        err_stim = 12'sd511; // Case 3: Positive boundary (511)
        #10; display_results();

        err_stim = 12'sd512; // Case 4: Positive Saturation (512 should become 511)
        #10; display_results();

        err_stim = 12'sd2047; // Case 5: Large Positive Saturation
        #10; display_results();

        err_stim = -12'sd100; // Case 6: Negative value (no saturation)
        #10; display_results();

        err_stim = -12'sd512; // Case 7: Negative boundary (-512)
        #10; display_results();

        err_stim = -12'sd513; // Case 8: Negative Saturation (-513 should become -512)
        #10; display_results();

        err_stim = -12'sd2048; // Case 9: Large Negative Saturation
        #10; display_results();

        $display("----------------------------------------------");
        $display("Test Complete.");
        $stop;
    end
	
    task display_results; //Helper task to self check and print to transcript
        integer exp_sat;
        integer exp_p;
        begin
            exp_sat = err_stim;
            if (exp_sat > 511)  exp_sat = 511;
            if (exp_sat < -512) exp_sat = -512;
            exp_p = exp_sat * 3;

            if ($signed(p_out) !== exp_p)
                $fatal(1, "[%0t] FAIL err=%0d got=%0d exp=%0d", $time, err_stim, $signed(p_out), exp_p);

            $display("%0t\t %d\t | %d\t | %d", $time, err_stim, iDUT.err_sat, p_out);
        end
    endtask
endmodule