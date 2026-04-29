`timescale 1ns / 1ps

module pwm_generator (
    input  logic clk,
    input  logic rst,
    input  logic [7:0] duty,
    output logic pwm_out,
    output logic dir_out
);
    logic [7:0] counter = '0;
    logic [6:0] abs_duty;
    
    assign abs_duty = duty[7] ? (~duty[6:0] + 1'b1) : duty[6:0];
    
    always_ff @(posedge clk) begin
        if (rst) begin
            counter <= '0;
            pwm_out <= 1'b0;
            dir_out <= 1'b0;
        end else begin
            counter <= counter + 1'b1;
            pwm_out <= (counter[6:0] < abs_duty) ? 1'b1 : 1'b0;
            dir_out <= duty[7];
        end
    end
endmodule