// Copyright (C) 2026 Szymon Warmiak, Grzegorz Twardosz
// MTM UEC2
// Author: Szymon Warmiak, Grzegorz Twardosz
//
// Description:
// 

module vga_frame_renderer #(
        parameter int FRAME_WIDTH = 320,
        parameter int FRAME_HEIGHT = 240,
        parameter int SCALE = 2,
        parameter int X_OFFSET = 0,
        parameter int Y_OFFSET = 0
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

    localparam int DISPLAY_WIDTH = 512;
    localparam int DISPLAY_HEIGHT = 682;
    localparam int DISPLAY_X_OFFSET = (HOR_PIXELS - DISPLAY_WIDTH) / 2;
    localparam int DISPLAY_Y_OFFSET = (VER_PIXELS - DISPLAY_HEIGHT) / 2;

    logic visible_now;
    logic [$clog2(FRAME_WIDTH * FRAME_HEIGHT)-1:0] frame_rd_addr_nxt;
    logic [10:0] image_x;
    logic [10:0] image_y;
    logic [10:0] src_x;
    logic [10:0] src_y;
    logic [14:0] src_x_scaled;
    logic [14:0] src_y_scaled;
    logic [18:0] frame_row_base;

    logic [1:0] visible_pipe;
    logic [1:0] frame_valid_pipe;
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

        if (visible_now) begin
            image_x = hcount_in - DISPLAY_X_OFFSET;
            image_y = vcount_in - DISPLAY_Y_OFFSET;
            src_x_scaled = {image_y, 4'b0000} - {4'b0000, image_y};
            src_y_scaled = {image_x, 4'b0000} - {4'b0000, image_x};
            src_x = src_x_scaled[14:5];
            src_y = FRAME_HEIGHT - 1 - src_y_scaled[14:5];
            frame_row_base = {src_y, 8'b0000_0000} + {2'b00, src_y, 6'b00_0000};
            frame_rd_addr_nxt = frame_row_base[16:0] + src_x;
        end else begin
            image_x = '0;
            image_y = '0;
            src_x = '0;
            src_y = '0;
            src_x_scaled = '0;
            src_y_scaled = '0;
            frame_row_base = '0;
            frame_rd_addr_nxt = '0;
        end
    end

    always_ff @(posedge clk or negedge rst_n) begin : renderer_ff
        if (!rst_n) begin
            frame_rd_addr <= '0;
            visible_pipe <= '0;
            frame_valid_pipe <= '0;
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
            frame_valid_pipe <= {frame_valid_pipe[0], frame_valid};

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
            end else begin
                rgb_out <= 12'h0_0_0;
            end
        end
    end

endmodule
