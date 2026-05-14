`timescale 1ns / 1ps

module spi_stream_rx #(
    parameter int CLK_DIV = 4 // Dzielnik zegara, np. 40MHz/4 = 10MHz dla bezpiecznego SPI
)(
    input  logic clk,
    input  logic rst,

    input  logic [15:0] tx_data,
    output logic [7:0] m_axis_tdata,
    output logic       m_axis_tvalid,
    output logic       m_axis_tuser,

    output logic spi_sck,
    output logic spi_mosi,
    input  logic spi_miso,
    output logic spi_cs_n
);

    localparam int FRAME_SIZE = 76802; // 2 bajty stanu switchy + 76800 bajtow ramki

    typedef enum logic [1:0] {IDLE, TRANSFER, WAIT_END} state_t;
    state_t state = IDLE;

    logic [19:0] byte_cnt = '0;
    logic [2:0]  bit_cnt  = '0;
    logic [7:0]  clk_cnt  = '0;
    logic        sck_int  = 1'b0;
    logic [7:0]  rx_shift = '0;
    logic [15:0] tx_shift = '0;
    logic [15:0] idle_cnt = '0;

    assign spi_sck = sck_int;
    assign spi_mosi = tx_shift[15];

    always_ff @(posedge clk) begin
        if (rst) begin
            state         <= IDLE;
            spi_cs_n      <= 1'b1;
            sck_int       <= 1'b0;
            m_axis_tvalid <= 1'b0;
            m_axis_tuser  <= 1'b0;
            idle_cnt      <= '0;
        end else begin
            m_axis_tvalid <= 1'b0;
            m_axis_tuser  <= 1'b0;

            case (state)
                IDLE: begin
                    spi_cs_n <= 1'b1;
                    sck_int  <= 1'b0;
                    tx_shift <= tx_data;
                    if (idle_cnt == 16'd1000) begin
                        idle_cnt <= '0;
                        spi_cs_n <= 1'b0;
                        byte_cnt <= '0;
                        bit_cnt  <= 3'd7;
                        clk_cnt  <= '0;
                        state    <= TRANSFER;
                    end else begin
                        idle_cnt <= idle_cnt + 1'b1;
                    end
                end

                TRANSFER: begin
                    if (clk_cnt == CLK_DIV / 2 - 1) begin
                        clk_cnt <= '0;
                        sck_int <= ~sck_int;

                        // W trybie Mode 0 (CPOL=0, CPHA=0) pobieramy dane na zboczu narastajacym
                        if (~sck_int) begin
                            rx_shift <= {rx_shift[6:0], spi_miso};
                        end 
                        // Na zboczu opadajacym sprawdzamy czy mamy pelen bajt
                        else begin
                            tx_shift <= {tx_shift[14:0], 1'b0}; // Przesuwanie rejestru nadawczego
                            if (bit_cnt == 0) begin
                                m_axis_tdata  <= rx_shift;
                                m_axis_tvalid <= 1'b1;
                                if (byte_cnt == 0) m_axis_tuser <= 1'b1; // Znacznik Start of Frame (SOF)

                                if (byte_cnt == FRAME_SIZE - 1) begin
                                    state <= WAIT_END;
                                end else begin
                                    byte_cnt <= byte_cnt + 1'b1;
                                    bit_cnt  <= 3'd7;
                                end
                            end else begin
                                bit_cnt <= bit_cnt - 1'b1;
                            end
                        end
                    end else begin
                        clk_cnt <= clk_cnt + 1'b1;
                    end
                end

                WAIT_END: begin
                    spi_cs_n <= 1'b1;
                    state    <= IDLE;
                end
            endcase
        end
    end
endmodule