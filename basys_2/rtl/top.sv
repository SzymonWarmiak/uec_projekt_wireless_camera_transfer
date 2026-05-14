`timescale 1ns / 1ps

module top (
    input  logic clk,
    input  logic rst,
    input  logic btnC,
    input  logic btnU,
    input  logic btnL,
    input  logic btnR,
    input  logic btnD,
    output logic [15:0] led,
    input  logic [15:0] sw,
    output logic spi_sck,
    output logic spi_mosi,
    input  logic spi_miso,
    output logic spi_cs_n,
    // Interfejs VGA
    output logic vs,
    output logic hs,
    output logic [3:0] r,
    output logic [3:0] g,
    output logic [3:0] b
);

    logic [7:0] rx_tdata;
    logic       rx_tvalid;
    logic       rx_tuser;
    
    logic [15:0] tx_buttons;
    assign tx_buttons = {11'd0, btnC, btnU, btnD, btnL, btnR};

    spi_stream_rx #(
        .CLK_DIV(4) // np. 40MHz / 4 = 10MHz dla SPI
    ) u_spi_rx (
        .clk(clk),
        .rst(rst),
        .tx_data(tx_buttons),
        .m_axis_tdata(rx_tdata),
        .m_axis_tvalid(rx_tvalid),
        .m_axis_tuser(rx_tuser),
        .spi_sck(spi_sck),
        .spi_mosi(spi_mosi),
        .spi_miso(spi_miso),
        .spi_cs_n(spi_cs_n)
    );

    logic [19:0] byte_index = '0;

    logic [7:0]  rx_tdata_reg;
    logic [16:0] wr_addr_reg;
    logic        wr_en_reg;

    always_ff @(posedge clk) begin
        if (rst) begin
            byte_index <= '0;
            wr_en_reg  <= 1'b0;
        end else begin
            wr_en_reg <= 1'b0;

            if (rx_tvalid) begin
                if (rx_tuser) begin
                    byte_index <= 20'd1;
                    wr_addr_reg <= '0;
                    rx_tdata_reg <= rx_tdata;
                    wr_en_reg <= 1'b1;
                end else begin
                    if (byte_index < 20'd76800) begin
                        wr_addr_reg  <= byte_index[16:0];
                        rx_tdata_reg <= rx_tdata;
                        wr_en_reg    <= 1'b1;
                    end
                    byte_index <= byte_index + 1'b1;
                end
            end
        end
    end

    assign led = sw; // Swiecimy lokalnymi diodami na podstawie lokalnych przelacznikow

    top_vga u_top_vga (
        .clk(clk),
        .rst_n(~rst),
        .frame_wr_clk(clk),
        .frame_wr_en(wr_en_reg),
        .frame_wr_bank(1'b0),
        .frame_wr_addr(wr_addr_reg),
        .frame_wr_data(rx_tdata_reg),
        .frame_rd_bank(1'b0),
        .frame_valid(1'b1),
        .status_word(sw),
        .spi_link(1'b1),
        .peer_link(1'b1),
        .target_x(9'd0), // Celownik wyzerowany, na Odbiorniku nie mamy kamery do liczenia ciemnych punktów
        .target_y(8'd0),
        .vs(vs),
        .hs(hs),
        .r(r),
        .g(g),
        .b(b)
    );

endmodule
