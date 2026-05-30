// Odbior UART z lab (list_ch08_04_uart) @ 9600, 40 MHz -> 4 bity sterowania (L298N IN1..IN4)
// DVSR = 40_000_000 / (16 * 9600) = 260
module uart_ctrl_bridge (
    input  wire       clk,
    input  wire       reset,
    input  wire       rx,
    output reg [3:0] ctrl_nibble
);

    wire       rx_empty;
    wire [7:0] r_data;
    reg        rd_uart;

    uart #(
        .DBIT(8),
        .SB_TICK(16),
        .DVSR(260),
        .DVSR_BIT(9),
        .FIFO_W(2)
    ) u_uart (
        .clk(clk),
        .reset(reset),
        .rd_uart(rd_uart),
        .wr_uart(1'b0),
        .rx(rx),
        .w_data(8'h00),
        .tx_full(),
        .rx_empty(rx_empty),
        .tx(),
        .r_data(r_data)
    );

    always @(posedge clk, posedge reset) begin
        rd_uart <= 1'b0;
        if (reset)
            ctrl_nibble <= 4'b0000;
        else if (~rx_empty) begin
            rd_uart <= 1'b1;
            ctrl_nibble <= r_data[3:0];
        end
    end

endmodule
