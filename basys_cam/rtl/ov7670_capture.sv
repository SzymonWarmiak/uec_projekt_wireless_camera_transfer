`timescale 1ns / 1ps

module ov7670_capture #(
    parameter int H_RES = 640,
    parameter int V_RES = 480,
    parameter int OUT_W = 64,
    parameter int OUT_H = 64
)(
    input  logic pclk,
    input  logic rst_n,
    input  logic vsync,
    input  logic href,
    input  logic [7:0] d,

    output logic [7:0] m_axis_tdata,
    output logic       m_axis_tvalid,
    output logic       m_axis_tlast,
    output logic       m_axis_tuser
);

    localparam int DOWNSAMPLE = 2;
    localparam int CROP_W = OUT_W * DOWNSAMPLE;
    localparam int CROP_H = OUT_H * DOWNSAMPLE;
    localparam int START_X = (H_RES - CROP_W) / 2;
    localparam int START_Y = (V_RES - CROP_H) / 2;

    logic [9:0] x_cnt = '0;
    logic [9:0] y_cnt = '0;
    logic byte_sel = 1'b0;
    logic [7:0] latched_d = '0;

    logic prev_vsync = 1'b0;
    logic prev_href  = 1'b0;
    logic sof_flag   = 1'b0;

    always_ff @(posedge pclk or negedge rst_n) begin
        if (!rst_n) begin
            x_cnt <= '0;
            y_cnt <= '0;
            byte_sel <= 1'b0;
            latched_d <= '0;
            prev_vsync <= 1'b0;
            prev_href <= 1'b0;
            sof_flag <= 1'b0;
            m_axis_tdata <= '0;
            m_axis_tvalid <= 1'b0;
            m_axis_tlast <= 1'b0;
            m_axis_tuser <= 1'b0;
        end else begin
            prev_vsync <= vsync;
            prev_href  <= href;

            m_axis_tvalid <= 1'b0;
            m_axis_tlast  <= 1'b0;
            m_axis_tuser  <= 1'b0;

            if (vsync) begin
                x_cnt <= '0;
                y_cnt <= '0;
                byte_sel <= 1'b0;
                sof_flag <= 1'b1;
            end else begin
                if (href && !prev_href) begin
                    byte_sel <= 1'b0;
                    x_cnt <= '0;
                end

                if (href) begin
                    byte_sel <= ~byte_sel;
                    if (byte_sel == 1'b0) begin
                        latched_d <= d;
                    end else begin
                        logic [7:0] gray;
                        gray = {latched_d[2:0], d[7:5], 2'b00};

                        if ((x_cnt >= START_X) &&
                            (x_cnt < START_X + CROP_W) &&
                            (y_cnt >= START_Y) &&
                            (y_cnt < START_Y + CROP_H)) begin
                            // Przepuszczamy co drugi piksel w obu osiach (Downsample x2).
                            if ((x_cnt[0] == 1'b0) && (y_cnt[0] == 1'b0)) begin
                                m_axis_tdata  <= gray;
                                m_axis_tvalid <= 1'b1;
                                if (sof_flag) begin
                                    m_axis_tuser <= 1'b1;
                                    sof_flag <= 1'b0;
                                end
                                if ((x_cnt == START_X + CROP_W - DOWNSAMPLE) &&
                                    (y_cnt == START_Y + CROP_H - DOWNSAMPLE)) begin
                                    m_axis_tlast <= 1'b1;
                                end
                            end
                        end
                        x_cnt <= x_cnt + 1'b1;
                    end
                end

                if (!href && prev_href) begin
                    y_cnt <= y_cnt + 1'b1;
                end
            end
        end
    end
endmodule
