`timescale 1ns / 1ps

module top_basys_station (
    input  logic clk,
    input  logic rst,
    output logic [15:0] led,
    input  logic [15:0] sw,
    input  logic btnl,
    input  logic btnr,
    input  logic servo_left_in,
    input  logic servo_right_in,
    input  logic servo_uart_rx,
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
    logic [7:0] servo_cmd;

    spi_stream_rx #(
        .CLK_DIV(4) // 40 MHz / 4 = 10 MHz, jak w dzialajacym wzorze
    ) u_spi_rx (
        .clk(clk),
        .rst(rst),
        .m_axis_tdata(rx_tdata),
        .m_axis_tvalid(rx_tvalid),
        .m_axis_tuser(rx_tuser),
        .s_axis_tdata(servo_cmd),
        .spi_sck(spi_sck),
        .spi_mosi(spi_mosi),
        .spi_miso(spi_miso),
        .spi_cs_n(spi_cs_n)
    );

    logic [19:0] byte_index = '0;
    logic [15:0] remote_sw  = '0;
    logic [7:0]  rx_tdata_reg;
    logic [16:0] wr_addr_reg;
    logic        wr_en_reg;
    localparam logic [7:0] SERVO_POS_MIN    = 8'd0;
    localparam logic [7:0] SERVO_POS_CENTER = 8'd33;
    localparam logic [7:0] SERVO_POS_MAX    = 8'd67;

    logic [1:0]  servo_left_sync = '0;
    logic [1:0]  servo_right_sync = '0;
    logic [7:0]  servo_pos = SERVO_POS_CENTER;
    logic [1:0]  servo_dir;
    logic [19:0] servo_update_counter = '0;
    logic [7:0]  uart_data;
    logic        uart_valid;
    logic        uart_wait_position = 1'b0;
    logic        uart_wait_direction = 1'b0;
    logic [7:0]  uart_position = SERVO_POS_CENTER;

    assign servo_cmd = 8'h00;
    assign servo_dir = servo_left_sync[1]  ? 2'd1 :
                       servo_right_sync[1] ? 2'd2 :
                                             2'd0;

    uart_rx #(
        .CLK_HZ(40_000_000),
        .BAUD(115_200)
    ) u_servo_uart_rx (
        .clk(clk),
        .rst(rst),
        .rx(servo_uart_rx),
        .data(uart_data),
        .valid(uart_valid)
    );

    always_ff @(posedge clk) begin
        if (rst) begin
            byte_index <= '0;
            remote_sw  <= '0;
            wr_en_reg  <= 1'b0;
            servo_left_sync <= '0;
            servo_right_sync <= '0;
            servo_pos <= SERVO_POS_CENTER;
            servo_update_counter <= '0;
            uart_wait_position <= 1'b0;
            uart_wait_direction <= 1'b0;
            uart_position <= SERVO_POS_CENTER;
        end else begin
            wr_en_reg <= 1'b0;
            servo_left_sync <= {servo_left_sync[0], servo_left_in};
            servo_right_sync <= {servo_right_sync[0], servo_right_in};

            if (uart_valid) begin
                if (uart_wait_direction) begin
                    uart_wait_direction <= 1'b0;
                    servo_pos <= uart_position;
                end else if (uart_wait_position) begin
                    uart_wait_position <= 1'b0;
                    uart_wait_direction <= 1'b1;
                    if (uart_data > SERVO_POS_MAX) begin
                        uart_position <= SERVO_POS_MAX;
                    end else begin
                        uart_position <= uart_data;
                    end
                end else if (uart_data == 8'ha5) begin
                    uart_wait_position <= 1'b1;
                end
            end

            if (servo_update_counter == 20'd799999) begin
                servo_update_counter <= '0;
                if ((servo_dir == 2'd1) && (servo_pos > SERVO_POS_MIN)) begin
                    servo_pos <= servo_pos - 1'b1;
                end else if ((servo_dir == 2'd2) && (servo_pos < SERVO_POS_MAX)) begin
                    servo_pos <= servo_pos + 1'b1;
                end
            end else begin
                servo_update_counter <= servo_update_counter + 1'b1;
            end

            if (rx_tvalid) begin
                if (rx_tuser) begin
                    byte_index <= 20'd1;
                    remote_sw[15:8] <= rx_tdata; // Pierwszy bajt naglowka (switche H z Nadajnika)
                end else begin
                    if (byte_index == 20'd1) begin
                        remote_sw[7:0] <= rx_tdata; // Drugi bajt naglowka (switche L z Nadajnika)
                    end else if (byte_index >= 20'd2 && byte_index < 20'd76802) begin
                        wr_addr_reg  <= byte_index - 20'd2; // Mapowanie na BRAM 0-76799
                        rx_tdata_reg <= rx_tdata;
                        wr_en_reg    <= 1'b1;
                    end
                    byte_index <= byte_index + 1'b1;
                end
            end
        end
    end

    assign led = remote_sw; // Zapalamy fizyczne diody Basysa 2 na podstawie switchy z Basysa 1!

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
        .status_word({servo_pos, 6'd0, servo_dir}),
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
