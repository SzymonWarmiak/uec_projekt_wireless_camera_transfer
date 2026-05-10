`timescale 1ns / 1ps

module uart_rx #(
    parameter int CLK_HZ = 40_000_000,
    parameter int BAUD   = 115_200
) (
    input  logic       clk,
    input  logic       rst,
    input  logic       rx,
    output logic [7:0] data,
    output logic       valid
);

    localparam int CLKS_PER_BIT = CLK_HZ / BAUD;
    localparam int HALF_BIT     = CLKS_PER_BIT / 2;

    typedef enum logic [1:0] {IDLE, START, DATA, STOP} state_t;
    state_t state = IDLE;

    logic [1:0] rx_sync = 2'b11;
    logic [15:0] clk_count = '0;
    logic [2:0] bit_index = '0;
    logic [7:0] shift = '0;

    always_ff @(posedge clk) begin
        if (rst) begin
            rx_sync <= 2'b11;
            state <= IDLE;
            clk_count <= '0;
            bit_index <= '0;
            shift <= '0;
            data <= '0;
            valid <= 1'b0;
        end else begin
            rx_sync <= {rx_sync[0], rx};
            valid <= 1'b0;

            case (state)
                IDLE: begin
                    clk_count <= '0;
                    bit_index <= '0;
                    if (!rx_sync[1]) state <= START;
                end

                START: begin
                    if (clk_count == HALF_BIT - 1) begin
                        clk_count <= '0;
                        if (!rx_sync[1]) state <= DATA;
                        else state <= IDLE;
                    end else begin
                        clk_count <= clk_count + 1'b1;
                    end
                end

                DATA: begin
                    if (clk_count == CLKS_PER_BIT - 1) begin
                        clk_count <= '0;
                        shift[bit_index] <= rx_sync[1];
                        if (bit_index == 3'd7) begin
                            bit_index <= '0;
                            state <= STOP;
                        end else begin
                            bit_index <= bit_index + 1'b1;
                        end
                    end else begin
                        clk_count <= clk_count + 1'b1;
                    end
                end

                STOP: begin
                    if (clk_count == CLKS_PER_BIT - 1) begin
                        clk_count <= '0;
                        data <= shift;
                        valid <= rx_sync[1];
                        state <= IDLE;
                    end else begin
                        clk_count <= clk_count + 1'b1;
                    end
                end
            endcase
        end
    end

endmodule
