`timescale 1ns / 1ps

module top_basys_cam (
    input  logic clk,
    input  logic rst,
    output logic [15:0] led,
    input  logic [15:0] sw,
    output logic spi_sck,
    output logic spi_mosi,
    input  logic spi_miso,
    output logic spi_cs_n,
    // Interfejs kamery OV7670
    output logic ov7670_sioc,
    inout  wire  ov7670_siod,
    input  logic ov7670_vsync,
    input  logic ov7670_href,
    input  logic ov7670_pclk,
    output logic ov7670_xclk,
    input  logic [7:0] ov7670_data,
    // Interfejs VGA
    output logic vs,
    output logic hs,
    output logic [3:0] r,
    output logic [3:0] g,
    output logic [3:0] b
);

    localparam int IMG_W = 320;
    localparam int IMG_H = 240;

    typedef enum logic [1:0] {WAIT_FRAME, SEND_SW_H, SEND_SW_L, SEND_PIXELS} state_t;
    state_t state = WAIT_FRAME;

    logic [7:0] spi_tdata;
    logic spi_tvalid;
    logic spi_tready;
    logic spi_tlast;
    
    logic [7:0] rx_tdata;
    logic rx_tvalid;
    logic [15:0] led_reg = '0;
    int rx_byte_cnt = 0;

    logic [7:0] cap_tdata;
    logic       cap_tvalid;
    logic       cap_tlast;
    logic       cap_tuser;

    logic [7:0] fifo_tdata;
    logic       fifo_tvalid;
    logic       fifo_tready;
    logic       fifo_tlast;
    logic       fifo_tuser;

    ov7670_capture #(
        .H_RES(640),
        .V_RES(480),
        .OUT_W(IMG_W),
        .OUT_H(IMG_H)
    ) u_capture (
        .pclk(ov7670_pclk),
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
        .TUSER_WIDTH(1)
    ) u_fifo (
        .s_aresetn(~rst),
        .s_aclk(ov7670_pclk),
        .s_axis_tvalid(cap_tvalid),
        .s_axis_tdata(cap_tdata),
        .s_axis_tlast(cap_tlast),
        .s_axis_tuser(cap_tuser),
        .s_axis_tready(),

        .m_aclk(clk),
        .m_axis_tvalid(fifo_tvalid),
        .m_axis_tdata(fifo_tdata),
        .m_axis_tlast(fifo_tlast),
        .m_axis_tuser(fifo_tuser),
        .m_axis_tready(fifo_tready)
    );

    spi_stream_master #(
        .CLK_DIV(1)
    ) u_spi_master (
        .clk(clk),
        .rst(rst),
        .s_axis_tdata(spi_tdata),
        .s_axis_tvalid(spi_tvalid),
        .s_axis_tready(spi_tready),
        .s_axis_tlast(spi_tlast),
        .m_axis_rx_tdata(rx_tdata),
        .m_axis_rx_tvalid(rx_tvalid),
        .spi_sck(spi_sck),
        .spi_mosi(spi_mosi),
        .spi_miso(spi_miso),
        .spi_cs_n(spi_cs_n)
    );

    assign led = led_reg;

    always_comb begin
        spi_tdata = 8'd0;
        spi_tvalid = 1'b0;
        spi_tlast = 1'b0;
        fifo_tready = 1'b0;

        if (state == WAIT_FRAME) begin
            if (fifo_tvalid && !fifo_tuser) fifo_tready = 1'b1;
        end else if (state == SEND_SW_H) begin
            spi_tdata = sw[15:8];
            spi_tvalid = 1'b1;
            spi_tlast = 1'b0;
        end else if (state == SEND_SW_L) begin
            spi_tdata = sw[7:0];
            spi_tvalid = 1'b1;
            spi_tlast = 1'b0;
        end else if (state == SEND_PIXELS) begin
            spi_tdata = fifo_tdata;
            spi_tvalid = fifo_tvalid;
            spi_tlast = fifo_tlast;
            fifo_tready = spi_tready;
        end
    end

    always_ff @(posedge clk) begin
        if (rst) begin
            state <= WAIT_FRAME;
            rx_byte_cnt <= 0;
            led_reg <= '0;
        end else begin
            if (spi_cs_n) begin
                rx_byte_cnt <= 0;
            end else if (rx_tvalid) begin
                if (rx_byte_cnt == 0) led_reg[15:8] <= rx_tdata;
                if (rx_byte_cnt == 1) led_reg[7:0]  <= rx_tdata;
                rx_byte_cnt <= rx_byte_cnt + 1;
            end

            case (state)
                WAIT_FRAME: begin
                    if (fifo_tvalid && fifo_tuser) state <= SEND_SW_H;
                end
                SEND_SW_H: begin
                    if (spi_tvalid && spi_tready) state <= SEND_SW_L;
                end
                SEND_SW_L: begin
                    if (spi_tvalid && spi_tready) state <= SEND_PIXELS;
                end
                SEND_PIXELS: begin
                    if (spi_tvalid && spi_tready && spi_tlast) state <= WAIT_FRAME;
                end
            endcase
        end
    end

    logic [1:0] clk_div = '0;
    logic clk_25mhz;
    always_ff @(posedge clk) begin
        if (rst) clk_div <= '0;
        else clk_div <= clk_div + 1'b1;
    end
    assign clk_25mhz = clk_div[1];
    assign ov7670_xclk = clk_25mhz;

    logic camera_config_done;
    ov7670_configurator u_configurator (
        .clk(clk_25mhz),
        .rst(rst),
        .sioc(ov7670_sioc),
        .siod(ov7670_siod),
        .done(camera_config_done)
    );

    // =========================================================
    // --- OBSŁUGA WYŚWIETLACZA VGA (Bezpośrednio z kamery) ---
    // =========================================================
    
    // 1. Sprzętowe generowanie zegara 40 MHz z systemowych 100 MHz (dla 800x600 @ 60Hz)
    logic clk_40mhz;
    assign clk_40mhz = clk;

    // 2. Licznik adresów pikseli (zsynchronizowany z zegarem pclk kamery)
    logic [$clog2(IMG_W * IMG_H) - 1 : 0] cam_wr_addr = '0;
    always_ff @(posedge ov7670_pclk) begin
        if (cap_tvalid) begin
            if (cap_tuser) cam_wr_addr <= '0; // cap_tuser to początek nowej klatki (X:0, Y:0)
            else cam_wr_addr <= cam_wr_addr + 1;
        end
    end

    // =========================================================
    // --- SPRZĘTOWE WYZNACZANIE CELU (Najciemniejszy punkt) ---
    // =========================================================
    logic [8:0] cam_x = '0;
    logic [7:0] cam_y = '0;
    logic [7:0] min_val = 8'hFF;
    logic [8:0] current_target_x = 160;
    logic [7:0] current_target_y = 120;
    logic [8:0] final_target_x = 160;
    logic [7:0] final_target_y = 120;

    always_ff @(posedge ov7670_pclk) begin
        if (cap_tvalid) begin
            if (cap_tuser) begin 
                min_val <= cap_tdata;
                current_target_x <= '0;
                current_target_y <= '0;
                final_target_x <= current_target_x; // Zapisz wynik przeanalizowanej klatki
                final_target_y <= current_target_y;
            end else begin
                // Omijamy marginesy 10px, zeby zignorowac szum na brzegach matrycy kamery
                if (cap_tdata < min_val && cam_x > 10 && cam_x < (IMG_W - 10) && cam_y > 10 && cam_y < (IMG_H - 10)) begin
                    min_val <= cap_tdata;
                    current_target_x <= cam_x;
                    current_target_y <= cam_y;
                end
            end

            if (cap_tuser) begin
                cam_x <= 9'd1;
                cam_y <= '0;
            end else begin
                if (cam_x == IMG_W - 1) begin
                    cam_x <= '0;
                    if (cam_y < IMG_H - 1) cam_y <= cam_y + 1;
                end else begin
                    cam_x <= cam_x + 1;
                end
            end
        end
    end

    // Synchronizacja współrzędnych celu do domeny zegara VGA (40 MHz)
    logic [8:0] target_x_sync1, target_x_sync2;
    logic [7:0] target_y_sync1, target_y_sync2;
    always_ff @(posedge clk_40mhz) begin
        target_x_sync1 <= final_target_x;
        target_x_sync2 <= target_x_sync1;
        target_y_sync1 <= final_target_y;
        target_y_sync2 <= target_y_sync1;
    end

    // 3. Główny moduł renderujący VGA z buforem ramki
    top_vga u_top_vga (
        .clk(clk_40mhz),               // Zegar odczytu dla monitora
        .rst_n(~rst),
        .frame_wr_clk(ov7670_pclk),    // Zegar zapisu z kamery
        .frame_wr_en(cap_tvalid),      // Pisz do bufora tylko gdy kamera daje poprawne dane
        .frame_wr_bank(1'b0),
        .frame_wr_addr(cam_wr_addr),   // Skalkulowany adres (0 do 76799)
        .frame_wr_data(cap_tdata),     // Surowy piksel grayscale z kamery
        .frame_rd_bank(1'b0),
        .frame_valid(1'b1),            // Cały czas wyświetlaj
        .status_word(sw),              // Do GUI na monitorze można przekazać stan Switchy
        .spi_link(1'b1),               // Wymuś by diodka "SPI" na monitorze siweciła na niebiesko
        .peer_link(1'b0),
        .target_x(target_x_sync2),     // Przekazanie X celownika
        .target_y(target_y_sync2),     // Przekazanie Y celownika
        .vs(vs),
        .hs(hs),
        .r(r),
        .g(g),
        .b(b)
    );

endmodule
