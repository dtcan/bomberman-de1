
// module that inteprets the keyboard input from the user for use in bomberman.v.

module keyboard_decoder(
	output reg p1_bomb, p2_bomb,			// 0: bomb NOT placed,					1: bomb placed.
	output reg p1_xdir, p2_xdir,			// 0: moving LEFT in x direction, 	1: moving RIGHT in x direction.
	output reg p1_ydir, p2_ydir,			// 0: moving UP in y direction,		1: moving DOWN in y direction.
	output reg p1_x_moving, p2_x_moving,// 0: NOT moving in x direction, 	1: moving in x direction.
	output reg p1_y_moving, p2_y_moving,// 0: NOT moving in y direction, 	1: moving in y direction.
	
	inout PS2_CLK, PS2_DAT,
	
	input clock, resetn,
	);
	
	wire w, a, s, d, space;
	wire up, left, down, right, enter;
	
	// module for tracking keyboard input.
	keyboard_tracker #(.PULSE_OR_HOLD(0)) kb(
	     .clock(clock),
		  .reset(resetn),
		  .PS2_CLK(PS2_CLK),
		  .PS2_DAT(PS2_DAT),
		  .w(w),
		  .a(a),
		  .s(s),
		  .d(d),
		  .left(left),
		  .right(right),
		  .up(up),
		  .down(down),
		  .space(space),
		  .enter(enter)
		  );
	
	// input logic.
	always @(*)
		begin
			// for player 1.
			p1_bomb		<= space;
			p1_x_dir 	<= d ? d : a;
			p1_x_moving <= (a | d);
			p1_y_dir		<= s ? s : w; 
			p1_y_moving <=	(w | s);
			
			// for player 2.
			p2_bomb		<= enter;
			p2_x_dir 	<= right ? right : left;
			p2_x_moving <= (left | right);
			p2_y_dir		<= down ? down : up;
			p2_y_moving <= (up | down);
		end

endmodule
