//A 4-bit up/down counter with an Enable, Inputs clk, rst_n, en, and up_dwn_n 
//where output cnt increments on up_dwn_n=1 and decrements on up_dwn_n=0 when en=1.
////////////////////////////////////////////////////////////////////////////////////////

module counter (
    input  logic       clk,
    input  logic       rst_n,
    input  logic       en,
    input  logic       up_dwn_n,
    output logic [3:0] cnt
);

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cnt <= 4'd0;
        end else if (en) begin
            if (up_dwn_n)
                cnt <= cnt + 4'd1;
            else
                cnt <= cnt - 4'd1;
        end
    end

endmodule
