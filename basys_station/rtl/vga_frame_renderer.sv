/**
 * Render a 320x240 grayscale framebuffer on an 800x600 VGA mode.
 *
 * The image is nearest-neighbor scaled by 2x to 640x480 and centered.
 */

module vga_frame_renderer #(
        parameter int FRAME_WIDTH = 320,
        parameter int FRAME_HEIGHT = 240,
        parameter int SCALE = 2,
        parameter int X_OFFSET = 80,
        parameter int Y_OFFSET = 60
    ) (
        input  logic clk,
        input  logic rst_n,
        input  logic frame_valid,
        input  logic [15:0] status_word,
        input  logic spi_link,
        input  logic peer_link,
        input  logic [8:0] target_x,
        input  logic [7:0] target_y,

        input  logic [10:0] vcount_in,
        input  logic        vsync_in,
        input  logic        vblnk_in,
        input  logic [10:0] hcount_in,
        input  logic        hsync_in,
        input  logic        hblnk_in,

        output logic [$clog2(FRAME_WIDTH * FRAME_HEIGHT)-1:0] frame_rd_addr,
        input  logic [7:0] frame_rd_data,

        output logic [10:0] vcount_out,
        output logic        vsync_out,
        output logic        vblnk_out,
        output logic [10:0] hcount_out,
        output logic        hsync_out,
        output logic        hblnk_out,
        output logic [11:0] rgb_out
    );

    timeunit 1ns;
    timeprecision 1ps;

    import vga_pkg::*;

    localparam int ROT_WIDTH = FRAME_HEIGHT;
    localparam int ROT_HEIGHT = FRAME_WIDTH;
    localparam int DISPLAY_HEIGHT = VER_PIXELS;
    localparam int DISPLAY_WIDTH = (ROT_WIDTH * DISPLAY_HEIGHT) / ROT_HEIGHT;
    localparam int DISPLAY_X_OFFSET = (HOR_PIXELS - DISPLAY_WIDTH) / 2;
    localparam int DISPLAY_Y_OFFSET = (VER_PIXELS - DISPLAY_HEIGHT) / 2;
    localparam int BORDER_X0 = (DISPLAY_X_OFFSET >= 2) ? (DISPLAY_X_OFFSET - 2) : 0;
    localparam int BORDER_Y0 = (DISPLAY_Y_OFFSET >= 2) ? (DISPLAY_Y_OFFSET - 2) : 0;
    localparam int BORDER_X1 = DISPLAY_X_OFFSET + DISPLAY_WIDTH + 2;
    localparam int BORDER_Y1 = DISPLAY_Y_OFFSET + DISPLAY_HEIGHT + 2;

    // Porty target_x / target_y zostaly w interfejsie modulu dla zgodnosci wstecznej
    // (uzywaja go top_vga i wszystkie miejsca instancjonujace), ale logika crosshaira
    // zostala wyciagnieta - na wejsciu spodziewamy sie zwykle 0 (patrz basys_cam/rtl/top.sv).

    logic visible_now;
    logic border_now;
    logic banner_now;
    logic spi_indicator_now;
    logic peer_indicator_now;
    logic spi_label_now;
    logic peer_label_now;
    logic [$clog2(FRAME_WIDTH * FRAME_HEIGHT)-1:0] frame_rd_addr_nxt;
    logic [10:0] image_x;
    logic [10:0] image_y;
    logic [10:0] rot_x;
    logic [10:0] rot_y;
    logic [10:0] src_x;
    logic [10:0] src_y;

    logic [1:0] visible_pipe;
    logic [1:0] border_pipe;
    logic [1:0] banner_pipe;
    logic [1:0] spi_indicator_pipe;
    logic [1:0] peer_indicator_pipe;
    logic [1:0] spi_label_pipe;
    logic [1:0] peer_label_pipe;
    logic [1:0] frame_valid_pipe;
    logic [1:0] spi_link_pipe;
    logic [1:0] peer_link_pipe;

    function automatic logic [4:0] font_row(input logic [7:0] ch, input integer row);
        begin
            case (ch)
                "B": case (row)
                    0: font_row = 5'b11110;
                    1: font_row = 5'b10001;
                    2: font_row = 5'b11110;
                    3: font_row = 5'b10001;
                    4: font_row = 5'b10001;
                    5: font_row = 5'b10001;
                    6: font_row = 5'b11110;
                    default: font_row = 5'b00000;
                endcase
                "E": case (row)
                    0: font_row = 5'b11111;
                    1: font_row = 5'b10000;
                    2: font_row = 5'b11110;
                    3: font_row = 5'b10000;
                    4: font_row = 5'b10000;
                    5: font_row = 5'b10000;
                    6: font_row = 5'b11111;
                    default: font_row = 5'b00000;
                endcase
                "2": case (row)
                    0: font_row = 5'b01110;
                    1: font_row = 5'b10001;
                    2: font_row = 5'b00001;
                    3: font_row = 5'b00010;
                    4: font_row = 5'b00100;
                    5: font_row = 5'b01000;
                    6: font_row = 5'b11111;
                    default: font_row = 5'b00000;
                endcase
                default: font_row = 5'b00000;
            endcase
        end
    endfunction

    function automatic logic char_pixel(
        input integer pixel_x,
        input integer pixel_y,
        input integer origin_x,
        input integer origin_y,
        input integer scale,
        input logic [7:0] ch
    );
        integer local_x;
        integer local_y;
        logic [4:0] row_bits;
        begin
            char_pixel = 1'b0;
            if ((pixel_x >= origin_x) && (pixel_x < (origin_x + (5 * scale))) &&
                (pixel_y >= origin_y) && (pixel_y < (origin_y + (7 * scale)))) begin
                local_x = (pixel_x - origin_x) / scale;
                local_y = (pixel_y - origin_y) / scale;
                row_bits = font_row(ch, local_y);
                char_pixel = row_bits[4 - local_x];
            end
        end
    endfunction

    logic [10:0] vcount_pipe [0:1];
    logic [10:0] hcount_pipe [0:1];
    logic [1:0] vsync_pipe;
    logic [1:0] vblnk_pipe;
    logic [1:0] hsync_pipe;
    logic [1:0] hblnk_pipe;

    always_comb begin : address_comb
        visible_now = (!vblnk_in && !hblnk_in) &&
            (hcount_in >= DISPLAY_X_OFFSET) && (hcount_in < (DISPLAY_X_OFFSET + DISPLAY_WIDTH)) &&
            (vcount_in >= DISPLAY_Y_OFFSET) && (vcount_in < (DISPLAY_Y_OFFSET + DISPLAY_HEIGHT));

        border_now = (!vblnk_in && !hblnk_in) &&
            (hcount_in >= BORDER_X0) && (hcount_in < BORDER_X1) &&
            (vcount_in >= BORDER_Y0) && (vcount_in < BORDER_Y1) &&
            !visible_now;

        banner_now = (!vblnk_in && !hblnk_in) &&
            (hcount_in >= 70) && (hcount_in < 350) &&
            (vcount_in >= 12) && (vcount_in < 56);

        spi_indicator_now = (!vblnk_in && !hblnk_in) &&
            (hcount_in >= 84) && (hcount_in < 112) &&
            (vcount_in >= 20) && (vcount_in < 48);

        peer_indicator_now = (!vblnk_in && !hblnk_in) &&
            (hcount_in >= 224) && (hcount_in < 252) &&
            (vcount_in >= 20) && (vcount_in < 48);

        spi_label_now = 1'b0;
        spi_label_now |= char_pixel(hcount_in, vcount_in, 124, 20, 4, "B");
        spi_label_now |= char_pixel(hcount_in, vcount_in, 148, 20, 4, "2");
        spi_label_now |= char_pixel(hcount_in, vcount_in, 172, 20, 4, "E");

        peer_label_now = 1'b0;
        peer_label_now |= char_pixel(hcount_in, vcount_in, 264, 20, 4, "E");
        peer_label_now |= char_pixel(hcount_in, vcount_in, 288, 20, 4, "2");
        peer_label_now |= char_pixel(hcount_in, vcount_in, 312, 20, 4, "E");

        if (visible_now) begin
            image_x = hcount_in - DISPLAY_X_OFFSET;
            image_y = vcount_in - DISPLAY_Y_OFFSET;
            rot_x = (image_x * ROT_WIDTH) / DISPLAY_WIDTH;
            rot_y = (image_y * ROT_HEIGHT) / DISPLAY_HEIGHT;
            src_x = rot_y;
            src_y = FRAME_HEIGHT - 1 - rot_x;
            frame_rd_addr_nxt = (src_y * FRAME_WIDTH) + src_x;
        end else begin
            image_x = '0;
            image_y = '0;
            rot_x = '0;
            rot_y = '0;
            src_x = '0;
            src_y = '0;
            frame_rd_addr_nxt = '0;
        end
    end

    always_ff @(posedge clk or negedge rst_n) begin : renderer_ff
        if (!rst_n) begin
            frame_rd_addr <= '0;
            visible_pipe <= '0;
            border_pipe <= '0;
            banner_pipe <= '0;
            spi_indicator_pipe <= '0;
            peer_indicator_pipe <= '0;
            spi_label_pipe <= '0;
            peer_label_pipe <= '0;
            frame_valid_pipe <= '0;
            spi_link_pipe <= '0;
            peer_link_pipe <= '0;
            vcount_pipe[0] <= '0;
            vcount_pipe[1] <= '0;
            hcount_pipe[0] <= '0;
            hcount_pipe[1] <= '0;
            vsync_pipe <= '0;
            vblnk_pipe <= '0;
            hsync_pipe <= '0;
            hblnk_pipe <= '0;
            vcount_out <= '0;
            hcount_out <= '0;
            vsync_out <= 1'b0;
            vblnk_out <= 1'b0;
            hsync_out <= 1'b0;
            hblnk_out <= 1'b0;
            rgb_out <= 12'h0_0_0;
        end else begin
            frame_rd_addr <= frame_rd_addr_nxt;

            visible_pipe <= {visible_pipe[0], visible_now};
            border_pipe <= {border_pipe[0], border_now};
            banner_pipe <= {banner_pipe[0], banner_now};
            spi_indicator_pipe <= {spi_indicator_pipe[0], spi_indicator_now};
            peer_indicator_pipe <= {peer_indicator_pipe[0], peer_indicator_now};
            spi_label_pipe <= {spi_label_pipe[0], spi_label_now};
            peer_label_pipe <= {peer_label_pipe[0], peer_label_now};
            frame_valid_pipe <= {frame_valid_pipe[0], frame_valid};
            spi_link_pipe <= {spi_link_pipe[0], spi_link};
            peer_link_pipe <= {peer_link_pipe[0], peer_link};

            vcount_pipe[0] <= vcount_in;
            vcount_pipe[1] <= vcount_pipe[0];
            hcount_pipe[0] <= hcount_in;
            hcount_pipe[1] <= hcount_pipe[0];
            vsync_pipe <= {vsync_pipe[0], vsync_in};
            vblnk_pipe <= {vblnk_pipe[0], vblnk_in};
            hsync_pipe <= {hsync_pipe[0], hsync_in};
            hblnk_pipe <= {hblnk_pipe[0], hblnk_in};

            vcount_out <= vcount_pipe[1];
            hcount_out <= hcount_pipe[1];
            vsync_out <= vsync_pipe[1];
            vblnk_out <= vblnk_pipe[1];
            hsync_out <= hsync_pipe[1];
            hblnk_out <= hblnk_pipe[1];

            if (vblnk_pipe[1] || hblnk_pipe[1]) begin
                rgb_out <= 12'h0_0_0;
            end else if (visible_pipe[1] && frame_valid_pipe[1]) begin
                rgb_out <= {frame_rd_data[7:4], frame_rd_data[7:4], frame_rd_data[7:4]};
            end else if (border_pipe[1]) begin
                rgb_out <= frame_valid_pipe[1] ? 12'h0_d_7 : 12'hd_8_0;
            end else begin
                rgb_out <= frame_valid_pipe[1] ? 12'h0_1_1 : 12'h1_0_0;
            end

            if (banner_pipe[1])
                rgb_out <= 12'h0_0_3;

            if (spi_indicator_pipe[1])
                rgb_out <= spi_link_pipe[1] ? 12'h1_f_3 : 12'hf_2_1;

            if (peer_indicator_pipe[1])
                rgb_out <= peer_link_pipe[1] ? 12'h1_f_3 : 12'hf_2_1;

            if (spi_label_pipe[1] || peer_label_pipe[1])
                rgb_out <= 12'hf_f_f;
        end
    end

endmodule
