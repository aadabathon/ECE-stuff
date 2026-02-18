module lshift_rot( //module with both left shift and rotation capability
	input logic rot,
	input logic [15:0] src,
	input logic [3:0] amt,
	output logic [15:0] res
);
	// Personal notes: Automatic is like a C function, each call gets its own copy on the stack. The static keyword is analagous to C as well, local vars persist across calls. logic [15:0] is the return type. In SV, type int is a 32-bit signed number. Functions in verilog are cool and I hope to learn about all the SV has to offer
  function automatic logic [15:0] stage_do( // A function makes the always_comb block easier on the eyes
    input logic [15:0] in, //pass a 16 bit vector
    input int          sh, //Integer signal that tells the call how many bits to shift/rot
    input logic        en, //An enable bit that correpsonds to amt[n_i] in our n bit amt shift signal
    input logic        rotf // If this bit is high, we rotation left, if low we shift left
  );
    logic [15:0] out; //must return a 16 bit type logic
    int i; // loop var
    int idx; // index var
    begin
      out = in;
      if (en) begin //begin the loop only if en is high
        for (i = 0; i < 16; i++) begin // 16 iterations of this loop as we have a 4-bit amt signal, could generalize to an n-bit amt signal with 2^n iterations
          if (rotf) begin //if rot is asserted begin
            idx = (i - sh) & 4'hF; // A nice way to implement rotations is leveraging the twos complement int and masking it with 32'b00...01111, ie (i - sh) mod 16. Eg: i = 15, sh = 2 -> idx = 13 and our out[15] = in[13]. Eg that wraps: i = 3, sh = 5 -> idx = 1110 and our out[3] = in[14]
            out[i] = in[idx]; //Set the Ith bit to the corresponding bit in[idx], we resolve each out[i] every iteration of the loop
          end else begin // else we just shift
            out[i] = (i >= sh) ? in[i - sh] : 1'b0; // If i is less than sh, the bit would be out of bounds and we fill 0, else we fill out[i] with in[i-sh]. Eg i = 1, sh = 2, i - sh = -1, this bit doesn't exist, so we fill out[1] with 0. Eg i = 5, sh = 2, i - sh = 3, we fill out[5] with in[3]
          end
        end
      end
      return out; // return out after loop terminates.
    end
  endfunction

  logic [15:0] s0, s1, s2, s3, s4; //Intermediate 16 bit logic signals.

  always_comb begin
    s0  = src; // rotations/shifts are additive, so if we pass a signal to stage_do with sh = 1 and then sh = 2 it is as if we passed it with sh = 3, so we can call stage_do for each bit of our amt bits with the corresponding shift value, and enable it only if the amt[i] is high
    s1  = stage_do(s0,  1, amt[0], rot); //en = amt[0], sh = 1
    s2  = stage_do(s1,  2, amt[1], rot); //feed back s1, en = amt[1], sh = 2
    s3  = stage_do(s2,  4, amt[2], rot); // feedback s2, en = amt[2], sh = 4
    s4  = stage_do(s3,  8, amt[3], rot); // feedback s3, en = amt[3], sh = 8
    res = s4; // return s4
  end

endmodule