/**
 * VGA display top with an internal dual-clock framebuffer.
 */

module top_vga (
        input  logic clk,
        input  logic rst_n,

        input  logic frame_wr_clk,
        input  logic frame_wr_en,
        input  logic frame_wr_bank,
        input  logic [$clog2(320 * 240)-1:0] frame_wr_addr,
        input  logic [7:0] frame_wr_data,

        input  logic frame_rd_bank,
        input  logic frame_valid,
        input  logic [15:0] status_word,
        input  logic spi_link,
        input  logic peer_link,
        input  logic [8:0] target_x,
        input  logic [7:0] target_y,

        output logic vs,
        output logic hs,
        output logic [3:0] r,
        output logic [3:0] g,
        output logic [3:0] b
    );

    timeunit 1ns;
    timeprecision 1ps;

    logic [10:0] vcount_tim;
    logic [10:0] hcount_tim;
    logic vsync_tim;
    logic vblnk_tim;
    logic hsync_tim;
    logic hblnk_tim;

    logic [10:0] vcount_ren;
    logic [10:0] hcount_ren;
    logic vsync_ren;
    logic vblnk_ren;
    logic hsync_ren;
    logic hblnk_ren;
    logic [11:0] rgb_ren;
    logic [$clog2(320 * 240)-1:0] frame_rd_addr;
    logic [7:0] frame_rd_data;

    assign vs = vsync_ren;
    assign hs = hsync_ren;
    assign {r, g, b} = rgb_ren;

    vga_timing u_vga_timing (
        .clk,
        .rst_n,
        .vcount(vcount_tim),
        .vsync(vsync_tim),
        .vblnk(vblnk_tim),
        .hcount(hcount_tim),
        .hsync(hsync_tim),
        .hblnk(hblnk_tim)
    );

    video_framebuffer #(
        .FRAME_WIDTH(320),
        .FRAME_HEIGHT(240)
    ) u_video_framebuffer (
        .wr_clk(frame_wr_clk),
        .wr_en(frame_wr_en),
        .wr_bank(frame_wr_bank),
        .wr_addr(frame_wr_addr),
        .wr_data(frame_wr_data),
        .rd_clk(clk),
        .rd_bank(frame_rd_bank),
        .rd_addr(frame_rd_addr),
        .rd_data(frame_rd_data)
    );

    vga_frame_renderer #(
        .FRAME_WIDTH(320),
        .FRAME_HEIGHT(240),
        .SCALE(2),
        .X_OFFSET(80),
        .Y_OFFSET(60)
    ) u_vga_frame_renderer (
        .clk,
        .rst_n,
        .frame_valid,
        .status_word,
        .spi_link,
        .peer_link,
        .target_x,
        .target_y,
        .vcount_in(vcount_tim),
        .vsync_in(vsync_tim),
        .vblnk_in(vblnk_tim),
        .hcount_in(hcount_tim),
        .hsync_in(hsync_tim),
        .hblnk_in(hblnk_tim),
        .frame_rd_addr(frame_rd_addr),
        .frame_rd_data(frame_rd_data),
        .vcount_out(vcount_ren),
        .vsync_out(vsync_ren),
        .vblnk_out(vblnk_ren),
        .hcount_out(hcount_ren),
        .hsync_out(hsync_ren),
        .hblnk_out(hblnk_ren),
        .rgb_out(rgb_ren)
    );

endmodule
