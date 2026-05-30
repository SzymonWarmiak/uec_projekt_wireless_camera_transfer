// Pada / UART[3:0] -> wzorce L298N (jak Arduino: 2 piny na silnik)
// motor_in[0]=IN1, [1]=IN2 (silnik 1); [2]=IN3, [3]=IN4 (silnik 2)
// ctrl_nibble: bit0=góra, bit1=prawo, bit2=dół, bit3=lewo
module motor_l298n_decode (
    input  wire [3:0] ctrl_nibble,
    output reg  [3:0] motor_in
);

    localparam [3:0] MOT_STOP  = 4'b0000;
    // IN1,H IN2,L | IN3,H IN4,L  — oba do przodu
    localparam [3:0] MOT_FWD   = 4'b0101;
    // IN1,L IN2,H | IN3,L IN4,H  — oba do tyłu
    localparam [3:0] MOT_REV   = 4'b1010;
    // skręt w lewo: silnik1 w tył, silnik2 do przodu
    localparam [3:0] MOT_LEFT  = 4'b0110;
    // skręt w prawo: silnik1 do przodu, silnik2 w tył
    localparam [3:0] MOT_RIGHT = 4'b1001;

    wire up    = ctrl_nibble[0];
    wire right = ctrl_nibble[1];
    wire down  = ctrl_nibble[2];
    wire left  = ctrl_nibble[3];

    always @(*) begin
        if ((up && down) || (left && right))
            motor_in = MOT_STOP;
        else if (up && !down) begin
            if (left && !right)
                motor_in = MOT_LEFT;
            else if (right && !left)
                motor_in = MOT_RIGHT;
            else
                motor_in = MOT_FWD;
        end
        else if (down && !up)
            motor_in = MOT_REV;
        else if (left && !right)
            motor_in = MOT_LEFT;
        else if (right && !left)
            motor_in = MOT_RIGHT;
        else
            motor_in = MOT_STOP;
    end

endmodule
