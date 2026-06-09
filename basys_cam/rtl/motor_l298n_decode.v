// Pad / SPI MISO[3:0] -> L298N patterns.
// motor_in[0]=IN1, [1]=IN2 (right motor); [2]=IN3, [3]=IN4 (left motor)
// ctrl_nibble: bit0=up, bit1=right, bit2=down, bit3=left
//
// Wiring:
//   right motor: red=OUT1, black=OUT2
//   left motor:  black=OUT3, red=OUT4
// Because the left motor is wired opposite to the right one, straight forward is:
//   right: IN1=1 IN2=0
//   left:  IN3=0 IN4=1
module motor_l298n_decode (
    input  wire [3:0] ctrl_nibble,
    output reg  [3:0] motor_in
);

    localparam [3:0] MOT_STOP  = 4'b0000;
    localparam [3:0] MOT_FWD   = 4'b1001; // IN1=1 IN2=0, IN3=0 IN4=1
    localparam [3:0] MOT_REV   = 4'b0110; // IN1=0 IN2=1, IN3=1 IN4=0
    localparam [3:0] MOT_LEFT  = 4'b1000; // left turn: right motor forward
    localparam [3:0] MOT_RIGHT = 4'b0001; // right turn: left motor forward

    wire up    = ctrl_nibble[0];
    wire down  = ctrl_nibble[1];
    wire left  = ctrl_nibble[2];
    wire right = ctrl_nibble[3];

    always @(*) begin
        if ((up && down) || (left && right))
            motor_in = MOT_STOP;
        else if (up && !down)
            motor_in = MOT_FWD;
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
