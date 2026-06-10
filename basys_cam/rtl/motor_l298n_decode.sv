module motor_l298n_decode (
    input  logic [3:0] ctrl_nibble,
    output logic [3:0] motor_in
);

    localparam logic [3:0] MOT_STOP  = 4'b0000;
    localparam logic [3:0] MOT_FWD   = 4'b1001; // IN1=1 IN2=0, IN3=0 IN4=1
    localparam logic [3:0] MOT_REV   = 4'b0110; // IN1=0 IN2=1, IN3=1 IN4=0
    localparam logic [3:0] MOT_LEFT  = 4'b1000; // left turn: right motor forward
    localparam logic [3:0] MOT_RIGHT = 4'b0001; // right turn: left motor forward

    logic up;
    logic down;
    logic left;
    logic right;

    assign up    = ctrl_nibble[0];
    assign down  = ctrl_nibble[1];
    assign left  = ctrl_nibble[2];
    assign right = ctrl_nibble[3];

    always_comb begin
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
