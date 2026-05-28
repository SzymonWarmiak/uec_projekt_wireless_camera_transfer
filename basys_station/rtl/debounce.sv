// =============================================================================
// debounce.sv - filtr przeciw drganiom stykow z synchronizacja CDC
//
// Wejscie 'btn_in' (asynchroniczne, mechaniczne) jest najpierw przepuszczone
// przez dwustopniowy synchronizator (zapobiega metastabilnosci), a nastepnie
// przez licznik 'cnt' o szerokosci N bitow. Stan 'btn_out' zmienia sie dopiero
// po (2^N) cyklach zegara, podczas ktorych wejscie zsynchronizowane bylo stale.
//
// Czas stabilizacji = (2^N) / FCLK.
// Dla FCLK = 40 MHz, N = 19 -> 2^19 / 40 MHz ~= 13.1 ms - dobrze dla
// mechanicznych przyciskow Basys3 (typowy bounce 1-5 ms).
//
// Modul w pelni reset-friendly (synchroniczny reset aktywny w stanie wysokim).
// =============================================================================
module debounce #(
    parameter int N = 19
) (
    input  logic clk,
    input  logic rst,
    input  logic btn_in,
    output logic btn_out
);

    // 1) synchronizacja wejscia (2 FF) - eliminacja metastabilnosci
    logic btn_sync_0, btn_sync_1;
    always_ff @(posedge clk) begin
        if (rst) begin
            btn_sync_0 <= 1'b0;
            btn_sync_1 <= 1'b0;
        end else begin
            btn_sync_0 <= btn_in;
            btn_sync_1 <= btn_sync_0;
        end
    end

    // 2) licznik stabilnosci - resetowany przy kazdej zmianie wejscia
    logic [N-1:0] cnt;
    logic idle, max;
    assign idle = (btn_out == btn_sync_1);
    assign max  = (cnt == {N{1'b1}});

    always_ff @(posedge clk) begin
        if (rst) begin
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
