module MazeRunner_tb();
  
  reg clk,RST_n;
  reg send_cmd;					// assert to send command to MazeRunner_tb
  reg [15:0] cmd;				// 16-bit command to send
  reg [11:0] batt;				// battery voltage 0xD80 is nominal
  
  logic cmd_sent;				
  logic resp_rdy;				// MazeRunner has sent a pos acknowledge
  logic [7:0] resp;				// resp byte from MazeRunner (hopefully 0xA5)
  logic hall_n;					// magnet found?
  
  /////////////////////////////////////////////////////////////////////////
  // Signals interconnecting MazeRunner to RunnerPhysics and RemoteComm //
  ///////////////////////////////////////////////////////////////////////
  wire TX_RX,RX_TX;
  wire INRT_SS_n,INRT_SCLK,INRT_MOSI,INRT_MISO,INRT_INT;
  wire lftPWM1,lftPWM2,rghtPWM1,rghtPWM2;
  wire A2D_SS_n,A2D_SCLK,A2D_MOSI,A2D_MISO;
  wire IR_lft_en,IR_cntr_en,IR_rght_en;  
  wire piezo;

  ///// Internal registers for testing purposes??? /////////

  
  //////////////////////
  // Instantiate DUT //
  ////////////////////
  MazeRunner iDUT(.clk(clk),.RST_n(RST_n),.INRT_SS_n(INRT_SS_n),.INRT_SCLK(INRT_SCLK),
                  .INRT_MOSI(INRT_MOSI),.INRT_MISO(INRT_MISO),.INRT_INT(INRT_INT),
				  .A2D_SS_n(A2D_SS_n),.A2D_SCLK(A2D_SCLK),.A2D_MOSI(A2D_MOSI),
				  .A2D_MISO(A2D_MISO),.lftPWM1(lftPWM1),.lftPWM2(lftPWM2),
				  .rghtPWM1(rghtPWM1),.rghtPWM2(rghtPWM2),.RX(RX_TX),.TX(TX_RX),
				  .hall_n(hall_n),.piezo(piezo),.piezo_n(),.IR_lft_en(IR_lft_en),
				  .IR_rght_en(IR_rght_en),.IR_cntr_en(IR_cntr_en),.LED());
	
  ///////////////////////////////////////////////////////////////////////////////////////
  // Instantiate RemoteComm which models bluetooth module receiving & forwarding cmds //
  /////////////////////////////////////////////////////////////////////////////////////
  RemoteComm iCMD(.clk(clk), .rst_n(RST_n), .RX(TX_RX), .TX(RX_TX), .cmd(cmd), .snd_cmd(send_cmd),
               .cmd_snt(cmd_sent), .resp_rdy(resp_rdy), .resp(resp));
			   
  ///////////////////////////////////////////////////
  // Instantiate physical model of robot and maze //
  /////////////////////////////////////////////////
  RunnerPhysics iPHYS(.clk(clk),.RST_n(RST_n),.SS_n(INRT_SS_n),.SCLK(INRT_SCLK),.MISO(INRT_MISO),
                      .MOSI(INRT_MOSI),.INT(INRT_INT),.lftPWM1(lftPWM1),.lftPWM2(lftPWM2),
					  .rghtPWM1(rghtPWM1),.rghtPWM2(rghtPWM2),
                     .IR_lft_en(IR_lft_en),.IR_cntr_en(IR_cntr_en),.IR_rght_en(IR_rght_en),
					 .A2D_SS_n(A2D_SS_n),.A2D_SCLK(A2D_SCLK),.A2D_MOSI(A2D_MOSI),
					 .A2D_MISO(A2D_MISO),.hall_n(hall_n),.batt(batt));


					 
  initial begin
    clk = 0;
  /// Your magic goes here ///
    @(negedge clk);
    RST_n = 0;
    send_cmd = 0;
    @(negedge clk);
    RST_n = 1;
    if(iDUT.lftPWM1 !== 0 || iDUT.lftPWM2 !== 0 || iDUT.rghtPWM1 !== 0 || iDUT.rghtPWM2 !== 0) begin
        $display("Test failed: Motors should be stopped after reset");
        $display("lftPWM1: %d, lftPWM2: %d, rghtPWM1: %d, rghtPWM2: %d", iDUT.lftPWM1, iDUT.lftPWM2, iDUT.rghtPWM1, iDUT.rghtPWM2);
        $stop();
    end
    repeat (10000) @(posedge clk); // Wait a few cycles after reset
    cmd = 16'h0000; // Example command to start moving forward (you should replace with actual command);
    send_cmd = 1;
    @(posedge clk);
    send_cmd = 0;
    wait(resp_rdy); // Wait for response ready
    #10000;
    cmd = 16'h27FF; // Example command to start turning (you should replace with actual command);
    @(negedge clk);
    send_cmd = 1;
    @(posedge clk);
    send_cmd = 0;
    wait(resp_rdy); // Wait for response ready
    wait(iDUT.strt_hdng); // Wait for response ready
    wait(iDUT.mv_cmplt); // Wait for response ready
    #1000;
    cmd = 16'h4000; // Example command to stop (you should replace with actual command);
    @(negedge clk);
    force iDUT.frwrd_opn = 1; // Ensure forward path is open
    @(negedge clk);
    send_cmd = 1;
    @(posedge clk);
    send_cmd = 0;
    wait(resp_rdy); // Wait for response ready
    wait(iDUT.frwrd_spd >= 11'h2A0); // Wait for forward speed to reach cruising speed
    #500000;
    @(posedge clk);
    force iDUT.frwrd_opn = 0; // Simulate obstacle detected
    wait(iDUT.mv_cmplt); // Wait for movement to complete
    force iDUT.frwrd_opn = 1; // Clear obstacle;
    #1000;
    
    $stop();
  end
  
  always
    #5 clk = ~clk;
	
endmodule
