`timescale 1ns / 1ps

module spi_master #(
    parameter int DATA_WIDTH = 8,
    parameter int CLK_DIV = 16
)(
    input  logic clk,
    input  logic rst,
    input  logic start,
    input  logic [DATA_WIDTH-1:0] tx_data,
    output logic [DATA_WIDTH-1:0] rx_data = '0,
    output logic busy = 1'b0,
    
    output logic sck = 1'b0,
    output logic mosi = 1'b0,
    input  logic miso,
    output logic cs_n = 1'b1
);

    localparam int DIV_CNT_MAX = CLK_DIV / 2;
    
    typedef enum logic {
        IDLE,
        TRANSFER
    } state_t;
    
    state_t state = IDLE;
    
    logic [$clog2(CLK_DIV)-1:0] clk_cnt = '0;
    logic [$clog2(DATA_WIDTH)-1:0] bit_cnt = '0;
    logic [DATA_WIDTH-1:0] tx_shift = '0;
    logic [DATA_WIDTH-1:0] rx_shift = '0;
    logic sck_int = 1'b0;
    
    always_ff @(posedge clk) begin
        if (rst) begin
            state <= IDLE;
            busy <= 1'b0;
            cs_n <= 1'b1;
            sck <= 1'b0;
            sck_int <= 1'b0;
            mosi <= 1'b0;
            clk_cnt <= '0;
            bit_cnt <= '0;
            rx_data <= '0;
        end else begin
            case (state)
                IDLE: begin
                    cs_n <= 1'b1;
                    sck <= 1'b0;
                    sck_int <= 1'b0;
                    if (start) begin
                        state <= TRANSFER;
                        busy <= 1'b1;
                        cs_n <= 1'b0;
                        tx_shift <= tx_data;
                        bit_cnt <= DATA_WIDTH - 1;
                        clk_cnt <= '0;
                        mosi <= tx_data[DATA_WIDTH - 1];
                    end else begin
                        busy <= 1'b0;
                    end
                end
                
                TRANSFER: begin
                    if (clk_cnt == DIV_CNT_MAX - 1) begin
                        clk_cnt <= '0;
                        sck_int <= ~sck_int;
                        sck <= ~sck_int;
                        
                        if (~sck_int) begin
                            rx_shift[bit_cnt] <= miso;
                        end else begin
                            if (bit_cnt == '0) begin
                                state <= IDLE;
                                rx_data <= rx_shift;
                                cs_n <= 1'b1;
                                busy <= 1'b0;
                            end else begin
                                bit_cnt <= bit_cnt - 1'b1;
                                mosi <= tx_shift[bit_cnt - 1'b1];
                            end
                        end
                    end else begin
                        clk_cnt <= clk_cnt + 1'b1;
                    end
                end
            endcase
        end
    end
endmodule