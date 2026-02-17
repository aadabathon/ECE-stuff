module mux2to1_tb();
//////////////////////////////////////
// Testbench for 2-to-1 multiplexer //
//////////////////////////////////////

// stiumulus to the DUT
logic stim_in0, stim_in1;
logic stim_sel;
logic stim_out;
  
// Instantiate DUT = Device Under Test
mux2to1 iDUT(.in0(stim_in0),.in1(stim_in1),.sel(stim_sel),.out(stim_out));

initial begin
    // Test case 1: sel=0, expect out=in0
    stim_in0 = 0;
    stim_in1 = 1;
    stim_sel = 0;
    #10;

    // Test case 2: sel=1, expect out=in1
    stim_in0 = 0;
    stim_in1 = 1;
    stim_sel = 1;
    #10;

    // Test case 3: sel=0, expect out=in0
    stim_in0 = 1;
    stim_in1 = 0;
    stim_sel = 0;
    #10;

    // Test case 4: sel=1, expect out=in1
    stim_in0 = 1;
    stim_in1 = 0;
    stim_sel = 1;
    #10;
    $stop();
end
 
endmodule