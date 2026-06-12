/**
 * San Jose State University
 * EE178 Lab #4
 * Author: prof. Eric Crabilla
// Modified by: Szymon Warmiak, Grzegorz Twardosz
 *
 * Modified by:
 * 2025  AGH University of Science and Technology
 * MTM UEC2
 * Piotr Kaczmarczyk
 *
 * Description:
 * Top level synthesizable module including the project top and all the FPGA-referred modules.
 */

module top_basys3 (
        input  logic clk,
        input  logic btnC,
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
        output logic [3:0] vgaRed,
        output logic [3:0] vgaGreen,
        output logic [3:0] vgaBlue,
        output logic Hsync,
        output logic Vsync
    );

    timeunit 1ns;
    timeprecision 1ps;

    /**
     * Local variables and signals
     */

    logic clk_in;
    logic clk_fb;
    logic clk_vga_ss;
    logic clk_vga_out;
    logic clk_sys_out;
    logic locked;
    logic pclk_vga;
    logic pclk_sys;
    logic rst_n;
    (* KEEP = "TRUE" *)
    (* ASYNC_REG = "TRUE" *)
    logic [7:0] safe_start = 0;
    // For details on synthesis attributes used above, see AMD Xilinx UG 901:
    // https://docs.xilinx.com/r/en-US/ug901-vivado-synthesis/Synthesis-Attributes


    /**
     * FPGA submodules placement
     */

    IBUF clk_ibuf (
        .I(clk),
        .O(clk_in)
    );

    MMCME2_BASE #(
        .CLKIN1_PERIOD(10.000),
        .DIVCLK_DIVIDE(1),
        .CLKFBOUT_MULT_F(10.000),
        .CLKOUT0_DIVIDE_F(15.375),
        .CLKOUT1_DIVIDE(25)
    ) clk_in_mmcme2 (
        .CLKIN1(clk_in),
        .CLKOUT0(clk_vga_out),
        .CLKOUT0B(),
        .CLKOUT1(clk_sys_out),
        .CLKOUT1B(),
        .CLKOUT2(),
        .CLKOUT2B(),
        .CLKOUT3(),
        .CLKOUT3B(),
        .CLKOUT4(),
        .CLKOUT5(),
        .CLKOUT6(),
        .CLKFBOUT(clk_fb),
        .CLKFBOUTB(),
        .CLKFBIN(clk_fb),
        .LOCKED(locked),
        .PWRDWN(1'b0),
        .RST(1'b0)
    );

    BUFH clk_vga_bufh (
        .I(clk_vga_out),
        .O(clk_vga_ss)
    );

    assign rst_n = ~btnC;

    always_ff @(posedge clk_vga_ss or negedge rst_n) begin
        if (!rst_n) begin
            safe_start <= '0;
        end else begin
            safe_start <= {safe_start[6:0], locked};
        end
    end

    BUFGCE #(
        .SIM_DEVICE("7SERIES")
    ) clk_vga_bufgce (
        .I(clk_vga_out),
        .CE(safe_start[7]),
        .O(pclk_vga)
    );

    BUFGCE #(
        .SIM_DEVICE("7SERIES")
    ) clk_sys_bufgce (
        .I(clk_sys_out),
        .CE(safe_start[7]),
        .O(pclk_sys)
    );

    /**
     *  Project functional top module
     */

    top u_top (
        .clk(pclk_sys),
        .clk_vga(pclk_vga),
        .rst_n(rst_n),
        .led(led),
        .sw(sw),
        .spi_sck(spi_sck),
        .spi_mosi(spi_mosi),
        .spi_miso(spi_miso),
        .motor_in(motor_in),
        .spi_cs_n(spi_cs_n),
        .ov7670_sioc(ov7670_sioc),
        .ov7670_siod(ov7670_siod),
        .ov7670_vsync(ov7670_vsync),
        .ov7670_href(ov7670_href),
        .ov7670_pclk(ov7670_pclk),
        .ov7670_xclk(ov7670_xclk),
        .ov7670_data(ov7670_data),
        .vs(Vsync),
        .hs(Hsync),
        .r(vgaRed),
        .g(vgaGreen),
        .b(vgaBlue)
    );

endmodule
