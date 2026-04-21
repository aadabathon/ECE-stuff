module MtrDrv(
    input logic clk,
    input logic rst_n,
    input logic [11:0] rght_spd,
    input logic [11:0] lft_spd,
    input logic [11:0] vbatt,
    output logic lftPWM1,
    output logic lftPWM2,
    output logic rghtPWM1,
    output logic rghtPWM2
);

    // 13-bit positive scaling coefficient read from the battery compensation ROM.
    // This approximates the factor used to normalize motor drive as battery voltage changes.
    logic [12:0] scale_factor;

    // Raw multiplication results before dividing by 2048.
    // 12-bit speed * 13-bit scale factor -> up to 25 bits mathematically,
    // but kept here as 24 bits in this implementation.
    logic [23:0] lft_prod;
    logic [23:0] rght_prod;

    // Scaled signed-duty values after dividing by 2048 and saturating to 12 bits.
    logic [11:0] lft_scaled;
    logic [11:0] rght_scaled;

    // Final unsigned PWM duty-cycle values sent into the PWM generators.
    // Left motor is shifted by +0x800 to convert signed duty to unsigned duty.
    // Right motor is inverted about 0x800 because the right motor is mounted opposite the left.
    logic [11:0] lft_final;
    logic [11:0] rght_final;

    // Battery-voltage compensation ROM.
    // Use vbatt[9:4] as the ROM address, as specified by the exercise.
    DutyScaleROM scaleROM(
        .clk(clk),
        .batt_level(vbatt[9:4]),
        .scale(scale_factor)
    );

    // Independent PWM generators for left and right motors.
    PWM12 lPWM(
        .clk(clk),
        .rst_n(rst_n),
        .duty(lft_final),
        .PWM1(lftPWM1),
        .PWM2(lftPWM2)
    );

    PWM12 rPWM(
        .clk(clk),
        .rst_n(rst_n),
        .duty(rght_final),
        .PWM1(rghtPWM1),
        .PWM2(rghtPWM2)
    );

    // Multiply commanded motor speeds by the battery compensation scale factor.
    assign lft_prod = lft_spd * scale_factor;
    assign rght_prod = rght_spd * scale_factor;

    // Divide by 2048 by selecting bits [22:11].
    // Also apply simple saturation to clamp overflow cases into the 12-bit signed range.
    assign lft_scaled =
        (lft_prod[23:22] == 2'b01) ? 12'h7FF :
        (lft_prod[23:22] == 2'b10) ? 12'h800 :
        lft_prod[22:11];

    assign rght_scaled =
        (rght_prod[23:22] == 2'b01) ? 12'h7FF :
        (rght_prod[23:22] == 2'b10) ? 12'h800 :
        rght_prod[22:11];

    // Convert scaled signed motor commands to unsigned PWM duties.
    // Left motor: offset by 0x800.
    // Right motor: offset and invert due to opposite motor orientation.
    assign lft_final = lft_scaled + 12'h800;
    assign rght_final = 12'h800 - rght_scaled;

endmodule