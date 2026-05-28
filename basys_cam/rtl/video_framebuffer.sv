`timescale 1ns / 1ps

module video_framebuffer #(
    parameter int FRAME_WIDTH = 320,
    parameter int FRAME_HEIGHT = 240
)(
    input  logic wr_clk,
    input  logic wr_en,
    input  logic wr_bank,
    input  logic [$clog2(FRAME_WIDTH * FRAME_HEIGHT)-1:0] wr_addr,
    input  logic [7:0] wr_data,

    input  logic rd_clk,
    input  logic rd_bank,
    input  logic [$clog2(FRAME_WIDTH * FRAME_HEIGHT)-1:0] rd_addr,
    output logic [7:0] rd_data
);

    localparam int PIXELS = FRAME_WIDTH * FRAME_HEIGHT;
    
    // Pamięć sprzętowa BRAM (Block RAM) o rozmiarze pozwalającym na ping-pong buffering
    (* ram_style = "block" *) logic [7:0] ram [0 : 2*PIXELS-1];

    always_ff @(posedge wr_clk) begin
        if (wr_en) ram[{wr_bank, wr_addr}] <= wr_data;
    end

    always_ff @(posedge rd_clk) begin
        rd_data <= ram[{rd_bank, rd_addr}];
    end

endmodule