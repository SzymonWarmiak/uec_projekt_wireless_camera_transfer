/**
 * Copyright (C) 2025  AGH University of Science and Technology
 * MTM UEC2
 * Author: Piotr Kaczmarczyk
 *
 * Description:
 * Vga timing controller.
 */

module vga_timing (
        input  logic clk,
        input  logic rst_n,
        output logic [10:0] vcount,
        output logic vsync,
        output logic vblnk,
        output logic [10:0] hcount,
        output logic hsync,
        output logic hblnk
    );

    timeunit 1ns;
    timeprecision 1ps;

    import vga_pkg::*;


    /**
     * Local variables and signals
     */

    // Add your signals and variables here.
    logic [10:0] vcount_nxt, hcount_nxt;
    logic vsync_nxt, vblnk_nxt, hsync_nxt, hblnk_nxt;

    /**
     * Internal logic
     */

    // Add your code here.
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            hcount <= '0;
            vcount <= '0;
            hsync  <= 1'b0;
            hblnk  <= 1'b0;
            vsync  <= 1'b0;
            vblnk  <= 1'b0;
        end else begin
            hcount <= hcount_nxt;
            vcount <= vcount_nxt;
            hsync  <= hsync_nxt;
            hblnk  <= hblnk_nxt;
            vsync  <= vsync_nxt;
            vblnk  <= vblnk_nxt;
        end
    end

    always_comb begin
        hcount_nxt = hcount;
        vcount_nxt = vcount;

        if (hcount == (HOR_TOTAL_TIME - 1)) begin
            hcount_nxt = '0;
            if (vcount == (VER_TOTAL_TIME - 1)) begin
                vcount_nxt = '0;
            end else begin
                vcount_nxt = vcount + 1'b1;
            end
        end else begin
            hcount_nxt = hcount + 1'b1;
        end

        hblnk_nxt = (hcount_nxt >= HOR_BLANK_START) && (hcount_nxt < (HOR_BLANK_START + HOR_BLANK_TIME));
        hsync_nxt = (hcount_nxt >= HOR_SYNC_START) && (hcount_nxt < (HOR_SYNC_START + HOR_SYNC_TIME));
        vblnk_nxt = (vcount_nxt >= VER_BLANK_START) && (vcount_nxt < (VER_BLANK_START + VER_BLANK_TIME));
        vsync_nxt = (vcount_nxt >= VER_SYNC_START) && (vcount_nxt < (VER_SYNC_START + VER_SYNC_TIME));
    end


endmodule
