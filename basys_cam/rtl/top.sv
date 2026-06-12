// Copyright (C) 2026 Szymon Warmiak, Grzegorz Twardosz
// MTM UEC2
// Author: Szymon Warmiak, Grzegorz Twardosz
//
// Description:
// 
`timescale 1ns / 1ps

module top (
    input  logic clk,
    input  logic clk_vga,
    input  logic rst_n,
    output logic [15:0] led,
    input  logic [15:0] sw,
    output logic spi_sck,
    output logic spi_mosi,
    input  logic spi_miso,
    output logic [3:0] motor_in,
    output logic spi_cs_n,

    output logic ov7670_sioc,
    inout  wire ov7670_siod,
    input  logic ov7670_vsync,
    input  logic ov7670_href,
    input  logic ov7670_pclk,
    output logic ov7670_xclk,
    input  logic [7:0] ov7670_data,

    output logic vs,
    output logic hs,
    output logic [3:0] r,
    output logic [3:0] g,
    output logic [3:0] b
);

    localparam int IMG_W = 320;
    localparam int IMG_H = 240;

    typedef enum logic [1:0] {WAIT_FRAME, SEND_PIXELS, SEND_CTRL} state_t;
    state_t state = WAIT_FRAME;
    localparam int CTRL_POLL_CYCLES = 40000;

    logic [7:0] spi_tdata;
    logic spi_tvalid;
    logic spi_tready;
    logic spi_tlast;
    
    logic [3:0] ctrl_nibble = 4'b0000;

    motor_l298n_decode u_motor_decode (
        .ctrl_nibble(ctrl_nibble),
        .motor_in(motor_in)
    );

    assign led = {8'b0, motor_in, ctrl_nibble};

    logic [7:0] cap_tdata;
    logic       cap_tvalid;
    logic       cap_tlast;
    logic       cap_tuser;

    logic [7:0] fifo_tdata;
    logic       fifo_tvalid;
    logic       fifo_tready;
    logic       fifo_tlast;
    logic       fifo_tuser;
    logic       cap_tready;
    logic [0:0]  fifo_s_axis_tkeep;
    logic [0:0]  fifo_s_axis_tstrb;
    logic [0:0]  fifo_m_axis_tkeep;
    logic [0:0]  fifo_s_axis_tid;
    logic [0:0]  fifo_s_axis_tdest;
    logic [0:0]  fifo_m_axis_tid;
    logic [0:0]  fifo_m_axis_tdest;
    logic        fifo_prog_full;
    logic        fifo_almost_full;
    logic        fifo_prog_empty;
    logic        fifo_almost_empty;
    logic [13:0] fifo_wr_data_count;
    logic [13:0] fifo_rd_data_count;

    logic [7:0] spi_rx_tdata;
    logic       spi_rx_tvalid;
    logic       spi_ctrl_sampled = 1'b0;
    logic [$clog2(CTRL_POLL_CYCLES) - 1:0] ctrl_poll_cnt = '0;

    assign fifo_s_axis_tkeep  = 1'b1;
    assign fifo_s_axis_tstrb  = 1'b1;
    assign fifo_s_axis_tid    = 1'b0;
    assign fifo_s_axis_tdest  = 1'b0;

    ov7670_capture #(
        .H_RES(640),
        .V_RES(480),
        .OUT_W(IMG_W),
        .OUT_H(IMG_H)
    ) u_capture (
        .pclk(ov7670_pclk),
        .rst_n(rst_n),
        .vsync(ov7670_vsync),
        .href(ov7670_href),
        .d(ov7670_data),
        .m_axis_tdata(cap_tdata),
        .m_axis_tvalid(cap_tvalid),
        .m_axis_tlast(cap_tlast),
        .m_axis_tuser(cap_tuser)
    );

    xpm_fifo_axis #(
        .CLOCKING_MODE("independent_clock"),
        .FIFO_DEPTH(8192),
        .TDATA_WIDTH(8),
        .TUSER_WIDTH(1),
        .USE_ADV_FEATURES("0000")
    ) u_fifo (
        .s_aresetn(rst_n),
        .s_aclk(ov7670_pclk),
        .s_axis_tvalid(cap_tvalid),
        .s_axis_tdata(cap_tdata),
        .s_axis_tlast(cap_tlast),
        .s_axis_tuser(cap_tuser),
        .s_axis_tkeep(fifo_s_axis_tkeep),
        .s_axis_tstrb(fifo_s_axis_tstrb),
        .s_axis_tid(fifo_s_axis_tid),
        .s_axis_tdest(fifo_s_axis_tdest),
        .s_axis_tready(cap_tready),

        .m_aclk(clk),
        .m_axis_tvalid(fifo_tvalid),
        .m_axis_tdata(fifo_tdata),
        .m_axis_tlast(fifo_tlast),
        .m_axis_tuser(fifo_tuser),
        .m_axis_tkeep(fifo_m_axis_tkeep),
        .m_axis_tid(fifo_m_axis_tid),
        .m_axis_tdest(fifo_m_axis_tdest),
        .m_axis_tready(fifo_tready),

        .prog_full_axis(fifo_prog_full),
        .wr_data_count_axis(fifo_wr_data_count),
        .almost_full_axis(fifo_almost_full),
        .prog_empty_axis(fifo_prog_empty),
        .rd_data_count_axis(fifo_rd_data_count),
        .almost_empty_axis(fifo_almost_empty)
    );

    spi_stream_master #(
        .CLK_DIV(1)
    ) u_spi_master (
        .clk(clk),
        .rst_n(rst_n),
        .s_axis_tdata(spi_tdata),
        .s_axis_tvalid(spi_tvalid),
        .s_axis_tready(spi_tready),
        .s_axis_tlast(spi_tlast),
        .m_axis_rx_tdata(spi_rx_tdata),
        .m_axis_rx_tvalid(spi_rx_tvalid),
        .spi_sck(spi_sck),
        .spi_mosi(spi_mosi),
        .spi_miso(spi_miso),
        .spi_cs_n(spi_cs_n)
    );

    always_comb begin
        spi_tdata = 8'd0;
        spi_tvalid = 1'b0;
        spi_tlast = 1'b0;
        fifo_tready = 1'b0;

        if (state == WAIT_FRAME) begin
            if (fifo_tvalid && !fifo_tuser) begin
                fifo_tready = 1'b1;
            end
        end else if (state == SEND_PIXELS) begin
            spi_tdata = fifo_tdata;
            spi_tvalid = fifo_tvalid;
            spi_tlast = fifo_tlast;
            fifo_tready = spi_tready;
        end else if (state == SEND_CTRL) begin
            spi_tdata = 8'd0;
            spi_tvalid = 1'b1;
            spi_tlast = 1'b1;
        end
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= WAIT_FRAME;
            ctrl_nibble <= 4'b0000;
            spi_ctrl_sampled <= 1'b0;
            ctrl_poll_cnt <= '0;
        end else begin
            if (state == SEND_PIXELS && spi_rx_tvalid && !spi_ctrl_sampled) begin
                ctrl_nibble <= spi_rx_tdata[3:0];
                spi_ctrl_sampled <= 1'b1;
            end else if (state == SEND_CTRL && spi_rx_tvalid) begin
                ctrl_nibble <= spi_rx_tdata[3:0];
            end

            case (state)
                WAIT_FRAME: begin
                    if (fifo_tvalid && fifo_tuser) begin
                        state <= SEND_PIXELS;
                        spi_ctrl_sampled <= 1'b0;
                        ctrl_poll_cnt <= '0;
                    end else if (ctrl_poll_cnt == CTRL_POLL_CYCLES - 1) begin
                        state <= SEND_CTRL;
                        ctrl_poll_cnt <= '0;
                    end else begin
                        ctrl_poll_cnt <= ctrl_poll_cnt + 1'b1;
                    end
                end
                SEND_PIXELS: begin
                    if (spi_tvalid && spi_tready && spi_tlast) begin
                        state <= WAIT_FRAME;
                    end
                end
                SEND_CTRL: begin
                    if (spi_rx_tvalid) begin
                        state <= WAIT_FRAME;
                    end
                end
                default: begin
                    state <= WAIT_FRAME;
                end
            endcase
        end
    end

    logic [1:0] clk_div = '0;
    logic clk_25mhz;
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            clk_div <= '0;
        end else begin
            clk_div <= clk_div + 1'b1;
        end
    end
    assign clk_25mhz = clk_div[1];
    assign ov7670_xclk = clk_25mhz;

    logic camera_config_done;
    ov7670_configurator u_configurator (
        .clk(clk_25mhz),
        .rst_n(rst_n),
        .sioc(ov7670_sioc),
        .siod(ov7670_siod),
        .done(camera_config_done)
    );

    logic [$clog2(IMG_W * IMG_H) - 1 : 0] cam_wr_addr = '0;
    always_ff @(posedge ov7670_pclk or negedge rst_n) begin
        if (!rst_n) begin
            cam_wr_addr <= '0;
        end else if (cap_tvalid) begin
            if (cap_tuser) begin
                cam_wr_addr <= '0;
            end else begin
                cam_wr_addr <= cam_wr_addr + 1'b1;
            end
        end
    end

    top_vga u_top_vga (
        .clk(clk_vga),
        .rst_n(rst_n),
        .frame_wr_clk(ov7670_pclk),
        .frame_wr_en(cap_tvalid),
        .frame_wr_bank(1'b0),
        .frame_wr_addr(cam_wr_addr),
        .frame_wr_data(cap_tdata),
        .frame_rd_bank(1'b0),
        .frame_valid(1'b1),
        .status_word(sw),
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

endmodule
