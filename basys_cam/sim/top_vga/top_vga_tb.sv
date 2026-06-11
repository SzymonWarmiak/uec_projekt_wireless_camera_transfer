/**
 * Copyright (C) 2025  AGH University of Science and Technology
 * MTM UEC2
 * Author: Piotr Kaczmarczyk
 *
 * Description:
 * Testbench for top_vga. Generates clock, writes test pattern to framebuffer,
 * and uses tiff_writer to export the output frame to results/frameXXX.tif.
 */

module top_vga_tb;

    timeunit 1ns;
    timeprecision 1ps;

    /**
     *  Local parameters
     */

    localparam CLK_VGA_PERIOD = 15;     // ~65 MHz clock for XGA
    localparam CLK_WR_PERIOD  = 40;     // 25 MHz write clock
    localparam RST_START_TIME = 30;
    localparam RST_ACTIVE_TIME = 30;

    /**
     * Local variables and signals
     */

    logic clk;
    logic frame_wr_clk;
    logic rst_n;

    logic frame_wr_en;
    logic frame_wr_bank;
    logic [$clog2(320 * 240)-1:0] frame_wr_addr;
    logic [7:0] frame_wr_data;

    wire vs, hs;
    wire [3:0] r, g, b;

    /**
     * Clock generation
     */

    initial begin
        clk = 1'b0;
        forever #(CLK_VGA_PERIOD/2) clk = ~clk;
    end

    initial begin
        frame_wr_clk = 1'b0;
        forever #(CLK_WR_PERIOD/2) frame_wr_clk = ~frame_wr_clk;
    end

    /**
     * Write Pattern to Framebuffer
     */

    initial begin
        frame_wr_en   = 1'b0;
        frame_wr_addr = '0;
        frame_wr_data = '0;
        frame_wr_bank = 1'b0;

        @(posedge rst_n);
        repeat (10) @(posedge frame_wr_clk);

        $display("Rozpoczynanie zapisu wzorca testowego do framebuffer (BRAM)...");

        for (int y = 0; y < 240; y++) begin
            for (int x = 0; x < 320; x++) begin
                @(posedge frame_wr_clk);
                frame_wr_en   = 1'b1;
                frame_wr_addr = y * 320 + x;
                // Generate a cool XOR pattern with grayscale gradient
                frame_wr_data = (x ^ y) & 8'hff;
            end
        end
        @(posedge frame_wr_clk);
        frame_wr_en   = 1'b0;
        $display("Zapisano 76800 pikseli do BRAM.");
    end

    /**
     * Dut Placement
     */

    top_vga dut (
        .clk(clk),
        .rst_n(rst_n),
        .frame_wr_clk(frame_wr_clk),
        .frame_wr_en(frame_wr_en),
        .frame_wr_bank(frame_wr_bank),
        .frame_wr_addr(frame_wr_addr),
        .frame_wr_data(frame_wr_data),
        .frame_rd_bank(1'b0),
        .frame_valid(1'b1),
        .status_word(16'd0),
        .spi_link(1'b1),
        .peer_link(1'b0),
        .target_x(9'd0),
        .target_y(8'd0),
        .vs(vs),
        .hs(hs),
        .r(r),
        .g(g),
        .b(b)
    );

    /**
     * TIFF Writer
     */

    tiff_writer #(
        .XDIM(16'd1344), // XGA total columns
        .YDIM(16'd806),  // XGA total rows
        .FILE_DIR("../../results")
    ) u_tiff_writer (
        .clk(clk),
        .r({r, r}),      // Duplicate to make 8-bit
        .g({g, g}),      // Duplicate to make 8-bit
        .b({b, b}),      // Duplicate to make 8-bit
        .go(vs)
    );

    /**
     * Main Test control
     */

    initial begin
        rst_n = 1'b1;
        #(RST_START_TIME) rst_n = 1'b0;
        #(RST_ACTIVE_TIME) rst_n = 1'b1;

        $display("Testbench top_vga_tb uruchomiony.");

        // Wait for pattern write completion
        wait (frame_wr_en == 1'b0 && frame_wr_addr == 76799);

        // Run until we capture at least one full vertical scan (vsync goes low, then high, then low)
        wait (vs == 1'b0);
        @(negedge vs) $display("Info: Wykryto negedge VS (Klatka 1) przy %t", $time);
        @(negedge vs) $display("Info: Wykryto negedge VS (Klatka 2) przy %t", $time);

        $display("Koniec symulacji. Klatka wyjściowa zapisana w folderze results.");
        $finish;
    end

endmodule
