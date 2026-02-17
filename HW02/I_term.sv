module I_term( //I term module implemented according to the Ex08 specifications
  input  logic        clk, rst_n, 
  input  logic        hdng_vld, moving, //Mux sel inputs 
  input  logic [9:0]  err_sat, //err_sat from P_term module
  output logic [11:0] I_term //12 bit vector output
);

  logic signed [15:0] integrator, nxt_integrator, sum; 
  logic signed [15:0] err_sext; // = sext(err_sat) 
  logic ov; //Overflow bit

  assign err_sext = {{6{err_sat[9]}}, err_sat}; //sext with vector concatenation
  assign sum = integrator + err_sext; //Feeds into 1 sel of the (!ov & hdng_vld) mux

  assign ov = (~(integrator[15] ^ err_sext[15])) & (integrator[15] ^ sum[15]); //Overflow logic, ie (signA == signB) && (signA(B) != signS)

  always_ff @(posedge clk or negedge rst_n) begin //D flop with asynch reset, with d as nxt_integrator and q as integrator
    if (!rst_n) integrator <= '0;
    else integrator <= nxt_integrator;
  end

  always_comb begin
    if (!moving) nxt_integrator = '0; //If were not moving, fill nxt_integrator with 0s
    else if (!hdng_vld || ov) nxt_integrator = integrator; //If mux sel logic selects 0, nxt_integrator = integrator
    else nxt_integrator = sum; //If the line above's condition doesn't hit, we necessarily pass the 1 select of the mux with is our sum signal
  end

  assign I_term = integrator[15:4]; //Assign I_term with the 12 MSB of our integrator signal

endmodule
