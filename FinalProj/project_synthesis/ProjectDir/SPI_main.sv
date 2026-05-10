module SPI_main(clk,rst_n,wrt,wt_data,MISO,SS_n,SCLK,MOSI,rd_data,done);

    //inputs and outputs
    input logic clk;
    input logic rst_n;
    input logic wrt;
    input logic[15:0] wt_data;
    input logic MISO;
    output logic SS_n;
    output logic SCLK;
    output logic MOSI;
    output logic[15:0] rd_data;
    output logic done;

    //internal logic
    typedef enum logic[1:0] {IDLE,READ,TRANSFER,FINISH} state_t;
    state_t state,next_state;

    logic[4:0] SCLK_div;
    logic[15:0] shft_reg;
    logic[3:0] bit_cnt;
    logic MISO_smpl;

    logic smpl,shft_imm,done15;
    logic init,ld_SCLK,inc_SCLK,shft,sample,clr_done,set_done,clr_bitcnt,inc_bitcnt;

    assign SCLK=SCLK_div[4];
    assign MOSI=shft_reg[15];
    assign rd_data=shft_reg;
    assign done15=(bit_cnt==4'hF);

    assign smpl=(SCLK_div==5'b01111);
    assign shft_imm=(SCLK_div==5'b11111);

    //state output logic
    always_comb begin
        next_state=state;
        init=0;ld_SCLK=0;inc_SCLK=0;shft=0;sample=0;clr_done=0;set_done=0;clr_bitcnt=0;inc_bitcnt=0;
        SS_n=1;

        case(state)
            IDLE: begin
                SS_n=1;
                clr_done=wrt;
                if(wrt) begin
                    init=1;
                    ld_SCLK=1;
                    clr_bitcnt=1;
                    next_state=READ;
                end
            end

            READ: begin
                SS_n=0;
                inc_SCLK=1;
                if(smpl)
                    sample=1;
                if(shft_imm)
                    next_state=TRANSFER;
            end

            TRANSFER: begin
                SS_n=0;
                inc_SCLK=1;
                if(smpl)
                    sample=1;

                if(shft_imm) begin
                    shft=1;
                    if(done15)
                        next_state=FINISH;
                    else
                        inc_bitcnt=1;
                end
            end

            FINISH: begin
                SS_n=1;
                ld_SCLK=1;
                set_done=1;
                next_state=IDLE;
            end

            default: next_state=IDLE;
        endcase
    end

    //state transition logic and sequential logic
    always_ff @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            state<=IDLE;
            SCLK_div<=5'b10111;
            shft_reg<=16'h0000;
            bit_cnt<=4'h0;
            MISO_smpl<=0;
            done<=0;
        end else begin
            state<=next_state;

            if(clr_done)
                done<=0;
            else if(set_done)
                done<=1;

            if(ld_SCLK)
                SCLK_div<=5'b10111;
            else if(inc_SCLK)
                SCLK_div<=SCLK_div+5'd1;

            if(init)
                shft_reg<=wt_data;
            else if(shft)
                shft_reg<={shft_reg[14:0],MISO_smpl};

            if(sample)
                MISO_smpl<=MISO;

            if(clr_bitcnt)
                bit_cnt<=4'h0;
            else if(inc_bitcnt)
                bit_cnt<=bit_cnt+4'd1;
        end
    end

endmodule
