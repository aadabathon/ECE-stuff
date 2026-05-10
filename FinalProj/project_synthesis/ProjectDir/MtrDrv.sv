module MtrDrv(
    input clk,
    input rst_n,
    input [11:0] rght_spd,
    input [11:0] lft_spd,
    input [11:0] vbatt,
    output lftPWM1,
    output lftPWM2,
    output rghtPWM1,
    output rghtPWM2
);

logic [12:0] scale_factor;
logic [23:0] lft_prod;
logic [23:0] rght_prod;
logic [23:0] lft_prod_pipe;
logic [23:0] rght_prod_pipe;
logic [11:0] lft_scaled;
logic [11:0] rght_scaled;
logic [11:0] lft_final;
logic [11:0] rght_final;
logic [11:0] lft_final_pipe;
logic [11:0] rght_final_pipe;

DutyScaleROM scaleROM(.clk(clk),.batt_level(vbatt[9:4]),.scale(scale_factor));

assign lft_prod = lft_spd * scale_factor;
assign rght_prod = rght_spd * scale_factor;

always_ff @(posedge clk, negedge rst_n) begin
  if (!rst_n) begin
    lft_prod_pipe <= 24'h000000;
    rght_prod_pipe <= 24'h000000;
  end else begin
    lft_prod_pipe <= lft_prod;
    rght_prod_pipe <= rght_prod;
  end
end


assign lft_scaled =
    (lft_prod_pipe[23:22] == 2'b01) ? 12'h7FF :
    (lft_prod_pipe[23:22] == 2'b10) ? 12'h800 :
    lft_prod_pipe[22:11];

assign rght_scaled =
    (rght_prod_pipe[23:22] == 2'b01) ? 12'h7FF :
    (rght_prod_pipe[23:22] == 2'b10) ? 12'h800 :
    rght_prod_pipe[22:11];

assign lft_final = lft_scaled + 12'h800;
assign rght_final = 12'h800 - rght_scaled;

always_ff @(posedge clk, negedge rst_n) begin
    if (!rst_n) begin
        lft_final_pipe <= 12'h800;
        rght_final_pipe <= 12'h800;
    end else begin
        lft_final_pipe <= lft_final;
        rght_final_pipe <= rght_final;
    end
end

PWM12 lPWM(.clk(clk),.rst_n(rst_n),.duty(lft_final_pipe),.PWM1(lftPWM1),.PWM2(lftPWM2));
PWM12 rPWM(.clk(clk),.rst_n(rst_n),.duty(rght_final_pipe),.PWM1(rghtPWM1),.PWM2(rghtPWM2));

endmodule
