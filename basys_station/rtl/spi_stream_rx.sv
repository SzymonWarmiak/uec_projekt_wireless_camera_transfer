// Copyright (C) 2026 Szymon Warmiak, Grzegorz Twardosz
// MTM UEC2
// Author: Szymon Warmiak, Grzegorz Twardosz
//
// Description:
// 
`timescale 1ns / 1ps

module spi_stream_rx #(
    parameter int CLK_DIV = 4
)(
    input  logic clk,
    input  logic rst_n,

    input  logic [15:0] tx_data,
    output logic [7:0]  m_axis_tdata,
    output logic       m_axis_tvalid,
    output logic       m_axis_tuser,

    output logic spi_sck,
    output logic spi_mosi,
    input  logic spi_miso,
    output logic spi_cs_n
);

    localparam int FRAME_SIZE = 76800;

    typedef enum logic [2:0] {IDLE, CTRL, CTRL_END, FRAME, FRAME_END} state_t;
    state_t state = IDLE;

    logic [19:0] byte_cnt = '0;
    logic [4:0]  bit_cnt  = '0;
    logic [7:0]  clk_cnt  = '0;
    logic        sck_int  = 1'b0;
    logic [7:0]  rx_shift = '0;
    logic [31:0] tx_shift = '0;
    logic [15:0] idle_cnt = '0;
    logic        tx_active = 1'b0;

    assign spi_sck  = sck_int;
    assign spi_mosi = tx_shift[31];

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state         <= IDLE;
            spi_cs_n      <= 1'b1;
            sck_int       <= 1'b0;
            m_axis_tvalid <= 1'b0;
            m_axis_tuser  <= 1'b0;
            m_axis_tdata  <= '0;
            idle_cnt      <= '0;
            byte_cnt      <= '0;
            bit_cnt       <= '0;
            clk_cnt       <= '0;
            rx_shift      <= '0;
            tx_shift      <= '0;
            tx_active     <= 1'b0;
        end else begin
            m_axis_tvalid <= 1'b0;
            m_axis_tuser  <= 1'b0;

            case (state)
                IDLE: begin
                    spi_cs_n <= 1'b1;
                    sck_int  <= 1'b0;
                    tx_shift <= {tx_data, 16'hCAFE};
                    tx_active <= 1'b1;
                    if (idle_cnt == 16'd1000) begin
                        idle_cnt <= '0;
                        spi_cs_n <= 1'b0;
                        bit_cnt  <= 5'd31;
                        clk_cnt  <= '0;
                        state    <= CTRL;
                    end else begin
                        idle_cnt <= idle_cnt + 1'b1;
                    end
                end

                CTRL: begin
                    if (clk_cnt == CLK_DIV / 2 - 1) begin
                        clk_cnt <= '0;
                        sck_int <= ~sck_int;

                        if (~sck_int) begin
                            rx_shift <= {rx_shift[6:0], spi_miso};
                        end else begin
                            if (tx_active) begin
                                tx_shift <= {tx_shift[30:0], 1'b0};
                            end
                            if (bit_cnt == 0) begin
                                tx_active <= 1'b0;
                                state <= CTRL_END;
                            end else begin
                                bit_cnt <= bit_cnt - 1'b1;
                            end
                        end
                    end else begin
                        clk_cnt <= clk_cnt + 1'b1;
                    end
                end

                CTRL_END: begin
                    spi_cs_n <= 1'b1;
                    sck_int  <= 1'b0;
                    if (idle_cnt == 16'd4000) begin
                        idle_cnt <= '0;
                        clk_cnt  <= '0;
                        byte_cnt <= '0;
                        bit_cnt  <= 5'd7;
                        state    <= FRAME;
                    end else begin
                        idle_cnt <= idle_cnt + 1'b1;
                    end
                end

                FRAME: begin
                    spi_cs_n <= 1'b0;
                    tx_shift <= 32'd0;
                    if (clk_cnt == CLK_DIV / 2 - 1) begin
                        clk_cnt <= '0;
                        sck_int <= ~sck_int;

                        if (~sck_int) begin
                            rx_shift <= {rx_shift[6:0], spi_miso};
                        end else begin
                            if (bit_cnt == 0) begin
                                m_axis_tdata  <= rx_shift;
                                m_axis_tvalid <= 1'b1;
                                if (byte_cnt == 0) begin
                                    m_axis_tuser <= 1'b1;
                                end

                                if (byte_cnt == FRAME_SIZE - 1) begin
                                    state <= FRAME_END;
                                end else begin
                                    byte_cnt <= byte_cnt + 1'b1;
                                    bit_cnt  <= 5'd7;
                                end
                            end else begin
                                bit_cnt <= bit_cnt - 1'b1;
                            end
                        end
                    end else begin
                        clk_cnt <= clk_cnt + 1'b1;
                    end
                end

                FRAME_END: begin
                    spi_cs_n <= 1'b1;
                    sck_int  <= 1'b0;
                    state    <= IDLE;
                end
                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end
endmodule
