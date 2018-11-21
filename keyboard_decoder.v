
// module that inteprets the keyboard input from the user for use in bomberman.v.

module keyboard_decoder(
	output reg player1_bomb, player2_bomb,				// 0: bomb NOT placed,					1: bomb placed.
	output reg player1_xdir, player2_xdir,				// 0: moving LEFT in x direction, 	1: moving RIGHT in x direction.
	output reg player1_ydir, player2_ydir,				// 0: moving UP in y direction,		1: moving DOWN in y direction.
	output reg player1_x_moving, player2_x_moving,	// 0: NOT moving in x direction, 	1: moving in x direction.
	output reg player1_y_moving, player2_y_moving,	// 0: NOT moving in y direction, 	1: moving in y direction.
	
	inout PS2_CLK, PS2_DAT,
	
	input clock, resetn,
	);
	
	wire w, a, s, d, space;
	wire up, left, down, right, enter;
	
	// store user input into respective registers.
	wire [3:0] player1_wasd, player2_udlr;
	wire space, enter;
	
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
			player1_bomb		<= space;
			player1_x_dir 		<= d ? d : a;
			player1_x_moving 	<= (a | d);
			player1_y_dir		<= s ? s : w; 
			player1_y_moving 	<=	(w | s);
			
			// for player 2.
			player2_bomb		<= enter;
			player2_x_dir 		<= right ? right : left;
			player2_x_moving 	<= (left | right);
			player2_y_dir		<= down ? down : up;
			player2_y_moving 	<= (up | down);
		end

endmodule
