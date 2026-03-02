module ss_A2D_SM(clk,rst_n,strt_cnv,smp_eq_8,gt,clr_dac,inc_dac,
                 clr_smp,inc_smp,accum,cnv_cmplt);

  input clk,rst_n;			// clock and asynch reset
  input strt_cnv;			// asserted to kick off a conversion
  input smp_eq_8;			// from datapath, tells when we have 8 samples
  input gt;					// gt signal, has to be double flopped
  
  output logic clr_dac;			// clear the input counter to the DAC
  output inc_dac;			// increment the counter to the DAC
  output clr_smp;			// clear the sample counter
  output inc_smp;			// increment the sample counter
  output accum;				// asserted to make accumulator accumulate sample
  output cnv_cmplt;			// indicates when the conversion is complete

  /////////////////////////////////////////////////////////////////
  // You fill in the SM implementation. I want to see the use   //
  // of enumerated type for state, and proper SM coding style. //
  //////////////////////////////////////////////////////////////
  
  
endmodule
  
					   