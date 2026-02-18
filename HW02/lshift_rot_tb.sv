`timescale 1ns/1ps
module lshift_rot_tb();
  localparam int NVECS = 8;
  
  logic rot;
  logic [15:0] src;
  logic [3:0]  amt;
  logic [15:0] res;
  
  lshift_rot iDUT(.rot(rot), .src(src), .amt(amt), .res(res)); // instantiate DUT

  function automatic logic [15:0] golden( // reference model (expected output)
    input logic rotf,  // mode for model: 0 shift, 1 rotate
    input logic [15:0] s, // model src
    input logic [3:0]  a  // model amt
  );
    logic [31:0] dbl; // used for rotate trick: {s,s}
	logic [31:0] shft; //Intermediate shft vector
    begin
      if (!rotf) golden = s << a; // logical left shift: fill with 0s
      else begin
        dbl = {s, s}; // duplicate so wrap bits still exist
		shft = dbl << a; // Shift by a
        golden = shft[31:16]; // select ladder 16 bits
      end
    end
  endfunction

  task automatic check( // drives inputs + checks output
    input logic rotf, // requested mode for this test
    input logic [15:0] s, // requested src for this test
    input logic [3:0]  a // requested amt for this test
  );
    logic [15:0] exp; // expected output for this test
    begin
      rot = rotf; src = s; amt = a; // apply stimulus to DUT
      #1ps; // tiny settle time for comb logic
      exp = golden(rotf, s, a); // compute expected result

      if (res !== exp) // self-check: fail fast on mismatch
        $fatal(1, "FAIL rot=%0b src=%h amt=%0d got=%h exp=%h", rotf, s, a, res, exp);
    end
  endtask

  initial begin
    logic [15:0] vecs [0:7];// small set of representative patterns
    int i, a;  // loop vars (i = vector index, a = amt)

    vecs[0]=16'h0000; // all zeros
    vecs[1]=16'hFFFF; // all ones
    vecs[2]=16'h0001; // LSB set (wrap/shift edge)
    vecs[3]=16'h8000; // MSB set (falls off / wraps)
    vecs[4]=16'hAAAA; // alternating 1010...
    vecs[5]=16'h5555; // alternating 0101...
    vecs[6]=16'h1234; // random-ish
    vecs[7]=16'hBEEF; // random-ish

    for (a = 0; a < 16; a++) begin // try all amounts 0..15
      for (i = 0; i < NVECS; i++) begin // try each test vector
        check(1'b0, vecs[i], a[3:0]); // rot=0 => left shift
        check(1'b1, vecs[i], a[3:0]); // rot=1 => rotate left
      end
    end

    $display("PASS"); // if we get here, everything matched
    $finish; // end sim cleanly
  end

endmodule
