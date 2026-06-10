/**
 * Copyright (C) 2025  AGH University of Science and Technology
 * MTM UEC2
 * Author: Piotr Kaczmarczyk
 *
 * Description:
 * Package with vga related constants.
 */

package vga_pkg;

    // Parameters for XGA Display 1024 x 768 @ 60fps using a 65 MHz clock.
    localparam HOR_PIXELS = 1024;
    localparam VER_PIXELS = 768;

    localparam HOR_TOTAL_TIME  = 1344;
    localparam HOR_BLANK_START = 1024;
    localparam HOR_BLANK_TIME  = 320;
    localparam HOR_SYNC_START  = 1048;
    localparam HOR_SYNC_TIME   = 136;

    localparam VER_TOTAL_TIME  = 806;
    localparam VER_BLANK_START = 768;
    localparam VER_BLANK_TIME  = 38;
    localparam VER_SYNC_START  = 771;
    localparam VER_SYNC_TIME   = 6;
    
endpackage
