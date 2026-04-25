`timescale 1ns / 1ps

module ov7670_configurator (
    input  logic clk,
    input  logic rst,
    output logic sioc,
    inout  wire  siod,
    output logic done
);

    logic [15:0] init_rom [0:56];
    initial begin
        init_rom[0]  = 16'h1280; init_rom[1]  = 16'h1204;
        init_rom[2]  = 16'h1101; init_rom[3]  = 16'h0C00;
        init_rom[4]  = 16'h3E00; init_rom[5]  = 16'h8C00;
        init_rom[6]  = 16'h0400; init_rom[7]  = 16'h4010;
        init_rom[8]  = 16'h3A04; init_rom[9]  = 16'h1438;
        init_rom[10] = 16'h4fb3; init_rom[11] = 16'h50b3;
        init_rom[12] = 16'h5100; init_rom[13] = 16'h523d;
        init_rom[14] = 16'h53A7; init_rom[15] = 16'h54e4;
        init_rom[16] = 16'h589e; init_rom[17] = 16'h3dc0;
        init_rom[18] = 16'h1101; init_rom[19] = 16'h1711;
        init_rom[20] = 16'h1861; init_rom[21] = 16'h32a4;
        init_rom[22] = 16'h1903; init_rom[23] = 16'h1a7b;
        init_rom[24] = 16'h030a; init_rom[25] = 16'h0e61;
        init_rom[26] = 16'h0f4b; init_rom[27] = 16'h1602;
        init_rom[28] = 16'h1e37; init_rom[29] = 16'h2102;
        init_rom[30] = 16'h2291; init_rom[31] = 16'h2907;
        init_rom[32] = 16'h330b; init_rom[33] = 16'h350b;
        init_rom[34] = 16'h371d; init_rom[35] = 16'h3871;
        init_rom[36] = 16'h392a; init_rom[37] = 16'h3c78;
        init_rom[38] = 16'h4d40; init_rom[39] = 16'h4e20;
        init_rom[40] = 16'h6900; init_rom[41] = 16'h6b4a;
        init_rom[42] = 16'h7410; init_rom[43] = 16'h8d4f;
        init_rom[44] = 16'h8e00; init_rom[45] = 16'h8f00;
        init_rom[46] = 16'h9000; init_rom[47] = 16'h9100;
        init_rom[48] = 16'h9600; init_rom[49] = 16'h9a00;
        init_rom[50] = 16'hb084; init_rom[51] = 16'hb10c;
        init_rom[52] = 16'hb20e; init_rom[53] = 16'hb382;
        init_rom[54] = 16'hb80a; 
        init_rom[55] = 16'hFFFF;
    end

    logic [7:0] clk_div = '0;
    logic tick = 1'b0;
    
    always_ff @(posedge clk) begin
        if (rst) begin
            clk_div <= '0;
            tick <= 1'b0;
        end else if (clk_div == 8'd62) begin
            clk_div <= '0;
            tick <= 1'b1;
        end else begin
            clk_div <= clk_div + 1'b1;
            tick <= 1'b0;
        end
    end

    typedef enum logic [4:0] {
        IDLE, 
        START_A, START_B, START_C, START_D,
        SEND_BIT_A, SEND_BIT_B, SEND_BIT_C, SEND_BIT_D,
        ACK_A, ACK_B, ACK_C, ACK_D,
        STOP_A, STOP_B, STOP_C, STOP_D,
        DELAY, DONE_STATE
    } state_t;

    state_t state = IDLE;
    
    logic [7:0] reg_index = '0;
    logic [23:0] shift_reg = '0;
    logic [4:0] bit_cnt = '0;
    logic [15:0] delay_cnt = '0;
    
    logic sda_out = 1'b1;
    logic sda_oe = 1'b1;
    logic scl_out = 1'b1;

    assign siod = sda_oe ? sda_out : 1'bz;
    assign sioc = scl_out;

    always_ff @(posedge clk) begin
        if (rst) begin
            state <= IDLE;
            done <= 1'b0;
            sda_out <= 1'b1;
            sda_oe <= 1'b1;
            scl_out <= 1'b1;
            reg_index <= '0;
        end else if (tick) begin
            case (state)
                IDLE: begin
                    logic [15:0] cmd = init_rom[reg_index];
                    if (cmd == 16'hFFFF) begin
                        state <= DONE_STATE;
                        done <= 1'b1;
                    end else begin
                        shift_reg <= {8'h42, cmd}; 
                        bit_cnt <= 24;
                        state <= START_A;
                    end
                end

                START_A: begin sda_oe <= 1'b1; sda_out <= 1'b1; scl_out <= 1'b1; state <= START_B; end
                START_B: begin sda_out <= 1'b0; scl_out <= 1'b1; state <= START_C; end
                START_C: begin sda_out <= 1'b0; scl_out <= 1'b0; state <= START_D; end
                START_D: begin state <= SEND_BIT_A; end

                SEND_BIT_A: begin sda_oe <= 1'b1; sda_out <= shift_reg[23]; scl_out <= 1'b0; state <= SEND_BIT_B; end
                SEND_BIT_B: begin scl_out <= 1'b1; state <= SEND_BIT_C; end
                SEND_BIT_C: begin scl_out <= 1'b1; state <= SEND_BIT_D; end
                SEND_BIT_D: begin 
                    scl_out <= 1'b0; 
                    shift_reg <= {shift_reg[22:0], 1'b0};
                    bit_cnt <= bit_cnt - 1'b1;
                    if (bit_cnt == 17 || bit_cnt == 9 || bit_cnt == 1) state <= ACK_A;
                    else state <= SEND_BIT_A;
                end

                ACK_A: begin sda_oe <= 1'b0; scl_out <= 1'b0; state <= ACK_B; end
                ACK_B: begin scl_out <= 1'b1; state <= ACK_C; end 
                ACK_C: begin scl_out <= 1'b1; state <= ACK_D; end
                ACK_D: begin scl_out <= 1'b0; state <= (bit_cnt == 0) ? STOP_A : SEND_BIT_A; end

                STOP_A: begin sda_oe <= 1'b1; sda_out <= 1'b0; scl_out <= 1'b0; state <= STOP_B; end
                STOP_B: begin sda_out <= 1'b0; scl_out <= 1'b1; state <= STOP_C; end
                STOP_C: begin sda_out <= 1'b1; scl_out <= 1'b1; state <= STOP_D; end
                STOP_D: begin delay_cnt <= '0; state <= DELAY; end

                DELAY: begin
                    if (delay_cnt == 16'd1000) begin
                        reg_index <= reg_index + 1'b1;
                        state <= IDLE;
                    end else delay_cnt <= delay_cnt + 1'b1;
                end

                DONE_STATE: done <= 1'b1;
            endcase
        end
    end
endmodule