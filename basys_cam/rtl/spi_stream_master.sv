// Copyright (C) 2026 Szymon Warmiak, Grzegorz Twardosz
// MTM UEC2
// Author: Szymon Warmiak, Grzegorz Twardosz
//
// Description:
// 
`timescale 1ns / 1ps

module spi_stream_master #(
    parameter int CLK_DIV = 2
)(
    input  logic clk,
    input  logic rst_n,

    input  logic [7:0] s_axis_tdata,
    input  logic       s_axis_tvalid,
    output logic       s_axis_tready,
    input  logic       s_axis_tlast,

    output logic [7:0] m_axis_rx_tdata,
    output logic       m_axis_rx_tvalid,

    output logic spi_sck,
    output logic spi_mosi,
    input  logic spi_miso,
    output logic spi_cs_n
);

    typedef enum logic [1:0] {IDLE, SHIFT, DONE, WAIT_NEXT} state_t;
    state_t state = IDLE;

    logic [7:0] tx_shift, rx_shift;
    logic [2:0] bit_cnt;
    logic [15:0] clk_cnt;
    logic sck_int, last_byte;

    assign spi_sck = sck_int;
    assign spi_mosi = tx_shift[7];

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            s_axis_tready <= 1'b0;
            m_axis_rx_tvalid <= 1'b0;
            m_axis_rx_tdata <= '0;
            spi_cs_n <= 1'b1;
            sck_int <= 1'b0;
            tx_shift <= '0;
            rx_shift <= '0;
            bit_cnt <= '0;
            clk_cnt <= '0;
            last_byte <= 1'b0;
        end else begin
            m_axis_rx_tvalid <= 1'b0;

            case (state)
                IDLE: begin
                    sck_int <= 1'b0;
                    s_axis_tready <= 1'b1;
                    if (s_axis_tvalid && s_axis_tready) begin
                        s_axis_tready <= 1'b0;
                        tx_shift <= s_axis_tdata;
                        last_byte <= s_axis_tlast;
                        spi_cs_n <= 1'b0;
                        bit_cnt <= 3'd7;
                        clk_cnt <= '0;
                        state <= SHIFT;
                    end
                end
                SHIFT: begin
                    if (clk_cnt == CLK_DIV - 1) begin
                        clk_cnt <= '0;
                        sck_int <= ~sck_int;
                        if (~sck_int) begin
                            rx_shift <= {rx_shift[6:0], spi_miso};
                        end else begin
                            tx_shift <= {tx_shift[6:0], 1'b0};
                            if (bit_cnt == 0) begin
                                state <= DONE;
                            end else begin
                                bit_cnt <= bit_cnt - 1'b1;
                            end
                        end
                    end else begin
                        clk_cnt <= clk_cnt + 1'b1;
                    end
                end
                DONE: begin
                    if (clk_cnt == CLK_DIV - 1) begin
                        clk_cnt <= '0;
                        m_axis_rx_tdata <= rx_shift;
                        m_axis_rx_tvalid <= 1'b1;
                        if (last_byte) begin
                            spi_cs_n <= 1'b1;
                            state <= IDLE;
                        end else begin
                            state <= WAIT_NEXT;
                        end
                    end else begin
                        clk_cnt <= clk_cnt + 1'b1;
                    end
                end
                WAIT_NEXT: begin
                    s_axis_tready <= 1'b1;
                    if (s_axis_tvalid && s_axis_tready) begin
                        s_axis_tready <= 1'b0;
                        tx_shift <= s_axis_tdata;
                        last_byte <= s_axis_tlast;
                        bit_cnt <= 3'd7;
                        clk_cnt <= '0;
                        state <= SHIFT;
                    end
                end
                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end
endmodule
