module debounce #(
    parameter int N = 19
) (
    input  logic clk,
    input  logic rst_n,
    input  logic btn_in,
    output logic btn_out
);

    logic btn_sync_0, btn_sync_1;
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            btn_sync_0 <= 1'b0;
            btn_sync_1 <= 1'b0;
        end else begin
            btn_sync_0 <= btn_in;
            btn_sync_1 <= btn_sync_0;
        end
    end

    logic [N-1:0] cnt;
    logic idle, max;
    assign idle = (btn_out == btn_sync_1);
    assign max  = (cnt == {N{1'b1}});

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cnt     <= '0;
            btn_out <= 1'b0;
        end else begin
            if (idle) begin
                cnt <= '0;
            end else begin
                cnt <= cnt + 1'b1;
                if (max) btn_out <= ~btn_out;
            end
        end
    end

endmodule
