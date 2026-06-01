// Pad / SPI MISO[3:0] -> L298N patterns.
// motor_in[0]=IN1, [1]=IN2 (motor 1); [2]=IN3, [3]=IN4 (motor 2)
// ctrl_nibble: bit0=up, bit1=right, bit2=down, bit3=left
//
// In this robot one motor is mounted/wired with opposite polarity, so straight
// forward is IN1=0 IN2=1 | IN3=1 IN4=0.
module motor_l298n_decode (
    input  wire [3:0] ctrl_nibble,
    output reg  [3:0] motor_in
);

    localparam [3:0] MOT_STOP  = 4'b0000;
    localparam [3:0] MOT_FWD   = 4'b0110;
    localparam [3:0] MOT_REV   = 4'b1001;
    localparam [3:0] MOT_LEFT  = 4'b0101;
    localparam [3:0] MOT_RIGHT = 4'b1010;

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
