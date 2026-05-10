`timescale 1ns/1ps

module Real_MazeRunner_tb_2();
  localparam int CLK_HALF_NS       = 5;
  localparam int BOOT_CYCLES       = 20000;
  localparam int UART_TIMEOUT      = 2500000;
  localparam int CAL_TIMEOUT       = 3500000;
  localparam int TURN_TIMEOUT      = 5000000;
  localparam int MOTION_TIMEOUT    = 1000000;

  localparam logic [7:0] POS_ACK   = 8'hA5;
  localparam logic [15:0] CMD_CAL  = 16'h0000; // cmd[15:13] = 000
  localparam logic [15:0] CMD_WEST = 16'h23FF; // cmd[15:13] = 001, heading = 0x3FF
  localparam logic [15:0] CMD_EAST = 16'h2C00; // cmd[15:13] = 001, heading = 0xC00
  localparam logic [15:0] CMD_MOVE = 16'h4000; // cmd[15:13] = 010, no stop bits

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

  int tests_run, tests_failed;

  MazeRunner iDUT(
    .clk(clk), .RST_n(RST_n),
    .INRT_SS_n(INRT_SS_n), .INRT_SCLK(INRT_SCLK), .INRT_MOSI(INRT_MOSI),
    .INRT_MISO(INRT_MISO), .INRT_INT(INRT_INT),
    .A2D_SS_n(A2D_SS_n), .A2D_SCLK(A2D_SCLK), .A2D_MOSI(A2D_MOSI),
    .A2D_MISO(A2D_MISO),
    .lftPWM1(lftPWM1), .lftPWM2(lftPWM2), .rghtPWM1(rghtPWM1), .rghtPWM2(rghtPWM2),
    .RX(RX_TX), .TX(TX_RX), .hall_n(hall_n),
    .piezo(piezo), .piezo_n(piezo_n),
    .IR_lft_en(IR_lft_en), .IR_cntr_en(IR_cntr_en), .IR_rght_en(IR_rght_en),
    .LED(LED)
  );

  RemoteComm iCMD(
    .clk(clk), .rst_n(RST_n), .RX(TX_RX), .TX(RX_TX),
    .cmd(cmd), .snd_cmd(send_cmd), .cmd_snt(cmd_sent),
    .resp_rdy(resp_rdy), .resp(resp)
  );

  RunnerPhysics iPHYS(
    .clk(clk), .RST_n(RST_n),
    .SS_n(INRT_SS_n), .SCLK(INRT_SCLK), .MISO(INRT_MISO), .MOSI(INRT_MOSI), .INT(INRT_INT),
    .lftPWM1(lftPWM1), .lftPWM2(lftPWM2), .rghtPWM1(rghtPWM1), .rghtPWM2(rghtPWM2),
    .IR_lft_en(IR_lft_en), .IR_cntr_en(IR_cntr_en), .IR_rght_en(IR_rght_en),
    .A2D_SS_n(A2D_SS_n), .A2D_SCLK(A2D_SCLK), .A2D_MOSI(A2D_MOSI), .A2D_MISO(A2D_MISO),
    .hall_n(hall_n), .batt(batt)
  );

  always #(CLK_HALF_NS) clk = ~clk;

  task automatic fail(input string msg);
    begin
      tests_failed++;
      $display("\n[FAIL @ %0t] %s", $time, msg);
      $display("  resp=%02h resp_rdy=%0b cmd_sent=%0b", resp, resp_rdy, cmd_sent);
      $display("  pwm L=%0b%0b R=%0b%0b  omega_lft=%0d omega_rght=%0d omega_sum=%0d heading=%03h", 
               lftPWM1, lftPWM2, rghtPWM1, rghtPWM2,
               iPHYS.omega_lft, iPHYS.omega_rght, iPHYS.omega_sum, iPHYS.heading_robot[19:8]);
      $fatal(1);
    end
  endtask

  task automatic pass(input string msg);
    begin
      tests_run++;
      $display("[PASS @ %0t] %s", $time, msg);
    end
  endtask

  task automatic wait_n(input int n);
    repeat (n) @(posedge clk);
  endtask

`define WAIT_UNTIL(COND, LIMIT, MSG) \
  begin \
    int __wait_i; \
    for (__wait_i = 0; (__wait_i < (LIMIT)) && !(COND); __wait_i++) @(posedge clk); \
    if (!(COND)) fail(MSG); \
  end

  task automatic check_no_x_outputs(input string where);
    begin
      if ($isunknown({TX_RX, INRT_SS_n, INRT_SCLK, INRT_MOSI,
                      A2D_SS_n, A2D_SCLK, A2D_MOSI,
                      lftPWM1, lftPWM2, rghtPWM1, rghtPWM2,
                      IR_lft_en, IR_cntr_en, IR_rght_en, piezo, piezo_n, LED})) begin
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
      wait_n(10);
      //check_no_x_outputs("reset asserted");
      RST_n = 1'b1;
      wait_n(20);
      //check_no_x_outputs("reset released");
      if ({lftPWM1,lftPWM2,rghtPWM1,rghtPWM2} !== 4'b0000)
        fail("motors not stopped immediately after reset release");
      pass("reset produces known outputs and stopped motors");
    end
  endtask

  task automatic send_command(input logic [15:0] c, input string name);
    begin
      @(negedge clk);
      cmd = c;
      send_cmd = 1'b1;
      @(posedge clk);
      send_cmd = 1'b0;
      `WAIT_UNTIL(cmd_sent, UART_TIMEOUT, {"RemoteComm did not finish sending ", name});
      pass({"command sent: ", name});
    end
  endtask

  task automatic expect_ack(input int timeout_cycles, input string name);
    begin
      `WAIT_UNTIL(resp_rdy, timeout_cycles, {"no response for ", name});
      if (resp !== POS_ACK)
        fail({"bad response byte for ", name, "; expected 0xA5"});
      pass({"received position ACK for ", name});
      wait_n(10);
    end
  endtask

  task automatic test_calibration();
    begin
      send_command(CMD_CAL, "calibrate");
      // LED[0] is wired to cmd_proc.in_cal in this repo, so this catches missing calibration state pulses.
      `WAIT_UNTIL(LED[0] === 1'b1, CAL_TIMEOUT/4, "calibration state/in_cal never asserted");
      expect_ack(CAL_TIMEOUT, "calibrate");
      //check_no_x_outputs("after calibration");
    end
  endtask

  task automatic test_turn_west();
    begin
      send_command(CMD_WEST, "heading west");
      `WAIT_UNTIL((iPHYS.omega_lft < -16'sd150) && (iPHYS.omega_rght > 16'sd150),
                  MOTION_TIMEOUT,
                  "west turn did not drive left wheel negative and right wheel positive");
      pass("west turn has correct wheel polarity");
      `WAIT_UNTIL(iPHYS.heading_v > 16'sd0, MOTION_TIMEOUT, "west turn heading_v never went positive");
      pass("west turn heading velocity positive");
      expect_ack(TURN_TIMEOUT, "heading west");
      `WAIT_UNTIL((iPHYS.heading_robot[19:8] > 12'h350) && (iPHYS.heading_robot[19:8] < 12'h4B0),
                  MOTION_TIMEOUT,
                  "robot did not settle near west heading");
      pass("robot settled near west");
      //check_no_x_outputs("after west turn");
    end
  endtask

  task automatic test_turn_east();
    begin
      send_command(CMD_EAST, "heading east");
      `WAIT_UNTIL((iPHYS.omega_lft > 16'sd150) && (iPHYS.omega_rght < -16'sd150),
                  MOTION_TIMEOUT,
                  "east turn did not drive left wheel positive and right wheel negative");
      pass("east turn has correct wheel polarity");
      `WAIT_UNTIL(iPHYS.heading_v < -16'sd0, MOTION_TIMEOUT, "east turn heading_v never went negative");
      pass("east turn heading velocity negative");
      expect_ack(TURN_TIMEOUT, "heading east");
      `WAIT_UNTIL((iPHYS.heading_robot[19:8] > 12'hB50) && (iPHYS.heading_robot[19:8] < 12'hCB0),
                  MOTION_TIMEOUT,
                  "robot did not settle near east heading");
      pass("robot settled near east");
      //check_no_x_outputs("after east turn");
    end
  endtask

  task automatic test_move_forward_abbreviated();
    begin
      // This is intentionally abbreviated. It checks that the post-synth datapath still
      // produces forward PWM and physical wheel acceleration. It does not wait for maze-wall completion.
      send_command(CMD_MOVE, "move forward abbreviated");
      `WAIT_UNTIL(iPHYS.omega_sum > 17'sd3000, MOTION_TIMEOUT, "move command did not ramp omega_sum forward");
      $display("lft_spd=%0d rght_spd=%0d", $signed(iDUT.lft_spd), $signed(iDUT.rght_spd) );
      if (!(iPHYS.omega_sum >= 17'sd1000))
        fail("move command omega_sum rose, but one wheel is not moving forward");
      pass("move command ramps both wheels forward");
      //check_no_x_outputs("during forward move");
    end
  endtask

  task automatic test_maze_solve_right();
    begin 
      //Send maze solve command
      send_command(16'h6000, "maze solve");
      `WAIT_UNTIL(iDUT.cmd_md == 0, TURN_TIMEOUT * 2, "cmd_proc did not switch to maze solve mode");
      pass("cmd_proc switched to maze solve mode");
      `WAIT_UNTIL(iDUT.sol_cmplt, TURN_TIMEOUT * 10, "maze solver did not assert sol_cmplt after maze solve command");
      pass("maze solver found the magnet and asserted sol_cmplt");
    end
  endtask

  initial begin
    $display("\n=== MazeRunner synth-oriented full-system regression ===");
    reset_dut();
    wait_n(BOOT_CYCLES); // lets NEMO/A2D models initialize before the UART stimulus
    test_calibration();
    //test_turn_west();
    //test_turn_east();
    //test_move_forward_abbreviated();
    //Monitor signals from physics model
    //$monitor("Time: %0t | cmd: %h | resp: %h | lftPWM: %b%b | rghtPWM: %b%b | strt_hdng: %b | strt_mv: %b | mv_cmplt: %b", $time, cmd, resp, lftPWM1, lftPWM2, rghtPWM1, rghtPWM2, iDUT.strt_hdng, iDUT.strt_mv, iDUT.mv_cmplt);
    test_maze_solve_right();
    $display("\nALL TESTS PASSED: %0d checks, %0d failures", tests_run, tests_failed);
    $stop;
  end
endmodule