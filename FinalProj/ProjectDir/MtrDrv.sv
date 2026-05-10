module MtrDrv(
    input logic clk,
    input logic rst_n,
    input logic signed[11:0] rght_spd,
    input logic signed[11:0] lft_spd,
    input logic [11:0] vbatt,
    output logic lftPWM1,
    output logic lftPWM2,
    output logic rghtPWM1,
    output logic rghtPWM2
);

//internal signals
logic signed [12:0] scale_factor;
logic signed [23:0] lft_prod;
logic signed [23:0] rght_prod;
logic signed [11:0] lft_scaled;
logic signed [11:0] rght_scaled;
logic [11:0] lft_final;
logic [11:0] rght_final;
logic [11:0] lft_final_piped;
logic [11:0] rght_final_piped;

DutyScaleROM scaleROM(.clk(clk),.batt_level(vbatt[9:4]),.scale(scale_factor));
PWM12 lPWM(.clk(clk),.rst_n(rst_n),.duty(lft_final_piped),.PWM1(lftPWM1),.PWM2(lftPWM2));
PWM12 rPWM(.clk(clk),.rst_n(rst_n),.duty(rght_final_piped),.PWM1(rghtPWM1),.PWM2(rghtPWM2));


//scale speed then divide by 2048 and saturate to 12 bits
assign lft_prod = lft_spd * scale_factor;
assign rght_prod = rght_spd * scale_factor;

assign lft_scaled =
    (lft_prod[23:22] == 2'b01) ? 12'h7FF :   // positive overflow
    (lft_prod[23:22] == 2'b10) ? 12'h800 :   // negative overflow
    lft_prod[22:11];

assign rght_scaled =
    (rght_prod[23:22] == 2'b01) ? 12'h7FF :  // positive overflow
    (rght_prod[23:22] == 2'b10) ? 12'h800 :  // negative overflow
    rght_prod[22:11];

//generate PWM signals
assign lft_final = lft_scaled + 12'h800;
assign rght_final = 12'h800 - rght_scaled;

// Pipeline duty inputs to PWM to break long mult->PWM path.
always_ff @(posedge clk or negedge rst_n)
    if (!rst_n) begin
        lft_final_piped  <= 12'h800;
        rght_final_piped <= 12'h800;
    end else begin
        lft_final_piped  <= lft_final;
        rght_final_piped <= rght_final;
    end


endmodule