module P_term_tb();
    // 1. Declare signals
    logic signed [11:0] err_stim;
    wire  signed [13:0] p_out;

    // 2. Instantiate the Unit Under Test (UUT)
    P_term iDUT (
        .error(err_stim),
        .P_term(p_out)
    );

    // 3. Stimulus process
    initial begin
        // Format the output display for readability
        $display("Time\t Error\t | Sat Out\t | P_term (x3)");
        $display("----------------------------------------------");

        // Case 1: Zero
        err_stim = 12'sd0; 
        #10; display_results();

        // Case 2: Positive value (no saturation)
        err_stim = 12'sd100; 
        #10; display_results();

        // Case 3: Positive boundary (511)
        err_stim = 12'sd511; 
        #10; display_results();

        // Case 4: Positive Saturation (512 should become 511)
        err_stim = 12'sd512; 
        #10; display_results();

        // Case 5: Large Positive Saturation
        err_stim = 12'sd2047; 
        #10; display_results();

        // Case 6: Negative value (no saturation)
        err_stim = -12'sd100; 
        #10; display_results();

        // Case 7: Negative boundary (-512)
        err_stim = -12'sd512; 
        #10; display_results();

        // Case 8: Negative Saturation (-513 should become -512)
        err_stim = -12'sd513; 
        #10; display_results();

        // Case 9: Large Negative Saturation
        err_stim = -12'sd2048; 
        #10; display_results();

        $display("----------------------------------------------");
        $display("Test Complete.");
        $stop;
    end

    // Helper task to print values
    task display_results;
        begin
            $display("%0t\t %d\t | %d\t | %d", $time, err_stim, iDUT.err_sat, p_out);
        end
    endtask

endmodule