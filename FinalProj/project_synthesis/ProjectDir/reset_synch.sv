module reset_synch(
    input  logic RST_n,
    input  logic clk,
    output logic rst_n
);

logic rst_ff1, rst_ff2;

always_ff @(posedge clk or negedge RST_n) begin
    if (!RST_n) begin
        rst_ff1 <= 1'b0;
        rst_ff2 <= 1'b0;
    end else begin
        rst_ff1 <= 1'b1;
        rst_ff2 <= rst_ff1;
    end
end

assign rst_n = rst_ff2;

endmodule