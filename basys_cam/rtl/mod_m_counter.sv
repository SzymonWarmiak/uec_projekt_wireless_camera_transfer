module mod_m_counter #(
    parameter int N = 4, // number of bits in counter
    parameter int M = 10 // mod-M
) (
    input  logic clk,
    input  logic rst_n,
    output logic max_tick,
    output logic [N-1:0] q
);

logic [N-1:0] r_reg;
logic [N-1:0] r_next;

always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        r_reg <= '0;
    end else begin
        r_reg <= r_next;
    end
end

assign r_next = (r_reg == (M - 1)) ? '0 : r_reg + 1'b1;
assign q = r_reg;
assign max_tick = (r_reg == (M - 1)) ? 1'b1 : 1'b0;

endmodule
