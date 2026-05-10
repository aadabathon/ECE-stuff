`timescale 1ns/1ps

module MR_heading_west_tb();

  localparam int CLK_HALF_NS    = 5;
  localparam int BOOT_CYCLES    = 20000;
  localparam int UART_TIMEOUT   = 2500000;
  localparam int CAL_TIMEOUT    = 3500000;
  localparam int TURN_TIMEOUT   = 5000000;
  localparam int MOTION_TIMEOUT = 1000000;

  localparam logic [7:0]  POS_ACK  = 8'hA5;
  localparam logic [15:0] CMD_CAL  = 16'h0000;
  localparam logic [15:0] CMD_WEST = 16'h23FF;
  localparam logic [15:0] CMD_EAST = 16'h2C00;
  localparam logic [15:0] CMD_MOVE = 16'h4000;

  reg clk, RST_n;
  reg send_cmd;
  reg [15:0] cmd;
  reg [11:0] batt;

  logic cmd_sent;
  logic resp_rdy;
  logic [7:0] resp;
  logic hall_n;

  wire TX_RX, RX_TX;
  wire INRT_SS_n, INRT_SCLK, INRT_MOSI, INRT_MISO, INRT_INT;
  wire lftPWM1, lftPWM2, rghtPWM1, rghtPWM2;
  wire A2D_SS_n, A2D_SCLK, A2D_MOSI, A2D_MISO;
  wire IR_lft_en, IR_cntr_en, IR_rght_en;
  wire piezo, piezo_n;
  wire [7:0] LED;

  int tests_run;
  int tests_failed;

  MazeRunner iDUT(
    .clk(clk), .RST_n(RST_n),
    .INRT_SS_n(INRT_SS_n), .INRT_SCLK(INRT_SCLK), .INRT_MOSI(INRT_MOSI),
    .INRT_MISO(INRT_MISO), .INRT_INT(INRT_INT),
    .A2D_SS_n(A2D_SS_n), .A2D_SCLK(A2D_SCLK), .A2D_MOSI(A2D_MOSI),
    .A2D_MISO(A2D_MISO),
    .lftPWM1(lftPWM1), .lftPWM2(lftPWM2),
    .rghtPWM1(rghtPWM1), .rghtPWM2(rghtPWM2),
    .RX(RX_TX), .TX(TX_RX), .hall_n(hall_n),
    .piezo(piezo), .piezo_n(piezo_n),
    .IR_lft_en(IR_lft_en), .IR_cntr_en(IR_cntr_en), .IR_rght_en(IR_rght_en),
    .LED(LED)
  );

  RemoteComm iCMD(
    .clk(clk), .rst_n(RST_n),
    .RX(TX_RX), .TX(RX_TX),
    .cmd(cmd), .snd_cmd(send_cmd), .cmd_snt(cmd_sent),
    .resp_rdy(resp_rdy), .resp(resp)
  );

  RunnerPhysics iPHYS(
    .clk(clk), .RST_n(RST_n),
    .SS_n(INRT_SS_n), .SCLK(INRT_SCLK),
    .MISO(INRT_MISO), .MOSI(INRT_MOSI), .INT(INRT_INT),
    .lftPWM1(lftPWM1), .lftPWM2(lftPWM2),
    .rghtPWM1(rghtPWM1), .rghtPWM2(rghtPWM2),
    .IR_lft_en(IR_lft_en), .IR_cntr_en(IR_cntr_en), .IR_rght_en(IR_rght_en),
    .A2D_SS_n(A2D_SS_n), .A2D_SCLK(A2D_SCLK),
    .A2D_MOSI(A2D_MOSI), .A2D_MISO(A2D_MISO),
    .hall_n(hall_n), .batt(batt)
  );

  always #(CLK_HALF_NS) clk = ~clk;

  task automatic fail(input string msg);
    begin
      tests_failed = tests_failed + 1;
      $display("\n[FAIL @ %0t] %s", $time, msg);
      $display("  resp=%02h resp_rdy=%0b cmd_sent=%0b", resp, resp_rdy, cmd_sent);
      $display("  pwm L=%0b%0b R=%0b%0b omega_lft=%0d omega_rght=%0d omega_sum=%0d heading=%03h",
               lftPWM1, lftPWM2, rghtPWM1, rghtPWM2,
               iPHYS.omega_lft, iPHYS.omega_rght,
               iPHYS.omega_sum, iPHYS.heading_robot[19:8]);
      $fatal(1);
    end
  endtask

  task automatic pass(input string msg);
    begin
      tests_run = tests_run + 1;
      $display("[PASS @ %0t] %s", $time, msg);
    end
  endtask

  task automatic wait_n(input int n);
    begin
      repeat (n) @(posedge clk);
    end
  endtask

  task automatic wait_for_cmd_sent(input string name);
    int i;
    begin
      for (i = 0; (i < UART_TIMEOUT) && !cmd_sent; i = i + 1)
        @(posedge clk);
      if (!cmd_sent)
        fail({"RemoteComm did not finish sending ", name});
    end
  endtask

  task automatic wait_for_resp(input int timeout_cycles, input string name);
    int i;
    begin
      for (i = 0; (i < timeout_cycles) && !resp_rdy; i = i + 1)
        @(posedge clk);
      if (!resp_rdy)
        fail({"no response for ", name});
    end
  endtask

  task automatic check_no_x_outputs(input string where);
    begin
      if ($isunknown({INRT_SS_n, INRT_SCLK, INRT_MOSI,
                      A2D_SS_n, A2D_SCLK, A2D_MOSI,
                      lftPWM1, lftPWM2, rghtPWM1, rghtPWM2,
                      IR_lft_en, IR_cntr_en, IR_rght_en,
                      piezo, piezo_n, LED})) begin
        fail({"unknown X/Z on top-level output during ", where});
      end
    end
  endtask

  task automatic reset_dut();
    begin
      clk = 1'b0;
      RST_n = 1'b0;
      send_cmd = 1'b0;
      cmd = 16'h0000;
      batt = 12'hD80;
      tests_run = 0;
      tests_failed = 0;
      wait_n(20);
      RST_n = 1'b1;
      wait_n(200);
      check_no_x_outputs("after reset synchronization");
      if ($isunknown({lftPWM1,lftPWM2,rghtPWM1,rghtPWM2}))
        fail("motor PWM outputs still X/Z after reset synchronization");
      pass("reset releases to known outputs");
    end
  endtask

  task automatic send_command(input logic [15:0] c, input string name);
    begin
      @(negedge clk);
      cmd = c;
      send_cmd = 1'b1;
      @(posedge clk);
      send_cmd = 1'b0;
      wait_for_cmd_sent(name);
      pass({"command sent: ", name});
      wait_n(10);
    end
  endtask

  task automatic expect_ack(input int timeout_cycles, input string name);
    begin
      wait_for_resp(timeout_cycles, name);
      if (resp !== POS_ACK)
        fail({"bad response byte for ", name, "; expected 0xA5"});
      pass({"received position ACK for ", name});
      wait_n(10);
    end
  endtask

  task automatic test_calibration();
    int i;
    begin
      send_command(CMD_CAL, "calibrate");
      for (i = 0; (i < (CAL_TIMEOUT/4)) && (LED[0] !== 1'b1); i = i + 1)
        @(posedge clk);
      if (LED[0] !== 1'b1)
        fail("calibration state/in_cal never asserted");
      pass("calibration state/in_cal asserted");
      expect_ack(CAL_TIMEOUT, "calibrate");
    end
  endtask

  task automatic test_turn_west();
    int i;
    begin
      send_command(CMD_WEST, "heading west");
      for (i = 0; (i < MOTION_TIMEOUT) &&
                  !((iPHYS.omega_lft < -16'sd150) && (iPHYS.omega_rght > 16'sd150)); i = i + 1)
        @(posedge clk);
      if (!((iPHYS.omega_lft < -16'sd150) && (iPHYS.omega_rght > 16'sd150)))
        fail("west turn did not drive left wheel negative and right wheel positive");
      pass("west turn has correct wheel polarity");

      for (i = 0; (i < MOTION_TIMEOUT) && !(iPHYS.heading_v > 16'sd0); i = i + 1)
        @(posedge clk);
      if (!(iPHYS.heading_v > 16'sd0))
        fail("west turn heading_v never went positive");
      pass("west turn heading velocity positive");
      expect_ack(TURN_TIMEOUT, "heading west");
    end
  endtask

  task automatic test_turn_east();
    int i;
    begin
      send_command(CMD_EAST, "heading east");
      for (i = 0; (i < MOTION_TIMEOUT) &&
                  !((iPHYS.omega_lft > 16'sd150) && (iPHYS.omega_rght < -16'sd150)); i = i + 1)
        @(posedge clk);
      if (!((iPHYS.omega_lft > 16'sd150) && (iPHYS.omega_rght < -16'sd150)))
        fail("east turn did not drive left wheel positive and right wheel negative");
      pass("east turn has correct wheel polarity");

      for (i = 0; (i < MOTION_TIMEOUT) && !(iPHYS.heading_v < 16'sd0); i = i + 1)
        @(posedge clk);
      if (!(iPHYS.heading_v < 16'sd0))
        fail("east turn heading_v never went negative");
      pass("east turn heading velocity negative");
      expect_ack(TURN_TIMEOUT, "heading east");
    end
  endtask

  task automatic test_move_forward_abbreviated();
    int i;
    begin
      send_command(CMD_MOVE, "move forward abbreviated");
      for (i = 0; (i < MOTION_TIMEOUT) && !(iPHYS.omega_sum > 17'sd3000); i = i + 1)
        @(posedge clk);
      if (!(iPHYS.omega_sum > 17'sd3000))
        fail("move command did not ramp omega_sum forward");
      pass("move command ramps omega_sum forward");
    end
  endtask

  initial begin
    $display("\n=== MR_heading_west_tb ===");
    reset_dut();
    wait_n(BOOT_CYCLES);
    test_calibration();
    test_turn_west();
    $display("\nYahoo!!! MR_heading_west_tb passed: %0d checks, %0d failures", tests_run, tests_failed);
    $stop;
  end

endmodule
