module mux2to1(in0,in1,sel,out);
///////////////////////////////////////////////////////
// Structural Verilog implementation of a 2-to-1 mux //
// selecting between two inputs in0, in1             //
// out is in0 when sel=0, in1 when sel=1             //
///////////////////////////////////////////////////////
input in0, in1;;
input sel;
output out;

// Intermediate signals
wire notsel;
wire and0out, and1out;

// Selects in0 when sel=0, in1 when sel=1
// - note: port connection order is output first, then input(s)
not iINV(notsel, sel);
and iAND0(and0out, in0, notsel);
and iAND1(and1out, in1, sel);
or iOR(out, and0out, and1out);

endmodule