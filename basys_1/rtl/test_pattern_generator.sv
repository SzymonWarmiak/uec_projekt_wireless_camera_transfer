`timescale 1ns / 1ps

module test_pattern_generator #(
    parameter int WIDTH = 64,
    parameter int HEIGHT = 64
)(
    input  logic clk,
    input  logic rst,
    input  logic enable,
    output logic [7:0] m_axis_tdata,
    output logic       m_axis_tvalid,
    input  logic       m_axis_tready,
    output logic       m_axis_tlast
);
    logic [7:0] frame_counter = '0;
    logic [9:0] x = '0;
    logic [9:0] y = '0;
    logic active = 1'b0;

    always_ff @(posedge clk) begin
        if (rst) begin
            frame_counter <= '0;
            x <= '0;
            y <= '0;
            active <= 1'b0;
            m_axis_tvalid <= 1'b0;
        end else begin
            if (!active && enable) begin
                active <= 1'b1;
                x <= '0;
                y <= '0;
                m_axis_tvalid <= 1'b1;
                frame_counter <= frame_counter + 1'b1;
            end

            if (active && m_axis_tready && m_axis_tvalid) begin
                if (x == WIDTH - 1) begin
                    x <= '0;
                    if (y == HEIGHT - 1) begin
                        y <= '0;
                        active <= 1'b0;
                        m_axis_tvalid <= 1'b0;
                    end else begin
                        y <= y + 1'b1;
                    end
                end else begin
                    x <= x + 1'b1;
                end
            end
        end
    end

    always_comb begin
        logic [9:0] pos;
        pos = {4'b0, frame_counter[6:1]};
        
        if (x >= pos && x < pos + 10'd16 && y >= (10'd63 - pos) && y < (10'd63 - pos + 10'd16))
            m_axis_tdata = 8'd255;
        else
            m_axis_tdata = 8'd32;
            
        m_axis_tlast = (x == WIDTH - 1) && (y == HEIGHT - 1);
    end
endmodule