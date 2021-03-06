module bomberman
	(
		CLOCK_50,
		KEY,
		PS2_CLK,
		PS2_DAT,
		// For debugging:
		LEDR,
		// The ports below are for the VGA output.
		VGA_CLK,   						//	VGA Clock
		VGA_HS,							//	VGA H_SYNC
		VGA_VS,							//	VGA V_SYNC
		VGA_BLANK_N,					//	VGA BLANK
		VGA_SYNC_N,						//	VGA SYNC
		VGA_R,   						//	VGA Red[9:0]
		VGA_G,	 						//	VGA Green[9:0]
		VGA_B   							//	VGA Blue[9:0]
	);

	input	CLOCK_50;				//	50 MHz
	input [1:0] KEY;
	
	inout PS2_CLK;
	inout PS2_DAT;
	
	// For debugging: (p1 inputs LEDR[0-4]. p2 inputs LEDR[5-9])
	output [9:0] LEDR;
	assign LEDR = {p1_bomb, p1_xdir, p1_xmov, p1_ydir, p1_ymov, p2_bomb, p2_xdir, p2_xmov, p2_ydir, p2_ymov};
	// Temporary for debugging:
//	assign game_over = ~KEY[1];
	
	// Do not change the following outputs
	output			VGA_CLK;   				//	VGA Clock
	output			VGA_HS;					//	VGA H_SYNC
	output			VGA_VS;					//	VGA V_SYNC
	output			VGA_BLANK_N;			//	VGA BLANK
	output			VGA_SYNC_N;				//	VGA SYNC
	output	[9:0]	VGA_R;   				//	VGA Red[9:0]
	output	[9:0]	VGA_G;	 				//	VGA Green[9:0]
	output	[9:0]	VGA_B;   				//	VGA Blue[9:0]
	
	// wires for user input from keyboard.
	wire p1_bomb, p2_bomb, p1_xdir, p2_xdir, p1_ydir, p2_ydir, p1_xmov, p2_xmov, p1_ymov, p2_ymov;
	wire start_game;
	
	// wires for control/datapath inputs/ outputs.
	wire [2:0] bomb_id, corner_id;
	wire [2:0] p1_hp_id, p2_hp_id;
	wire [1:0] memory_select;
	wire [1:0] p1_lives, p2_lives;
	wire copy_enable, tc_enable, game_reset;
	wire draw_stage, draw_tile, draw_explosion, draw_bomb, draw_p1, draw_p1_hp, draw_p2, draw_p2_hp;
	wire set_p1, check_p1, set_p2, check_p2;
	wire black, refresh, print_screen, read_p1_input, send_p1_input, read_p2_input, send_p2_input;
	wire finished, all_tiles_drawn;
	
	// wires for datapath/VGA inputs/ outputs.
	wire [2:0] colour;
	wire [8:0] x;
	wire [7:0] y;
	wire write_en;
	
	wire reset;
	assign reset = ~KEY[0];
	
	// Create an Instance of a VGA controller - there can be only one!
	// Define the number of colours as well as the initial background
	// image file (.MIF) for the controller.
	vga_adapter VGA(
			.resetn(~reset), // since our code runs on reset active high wile VGA is active low.
			.clock(CLOCK_50),
			.colour(colour),
			.x(x),
			.y(y),
			.plot(write_en),
			/* Signals for the DAC to drive the monitor. */
			.VGA_R(VGA_R),
			.VGA_G(VGA_G),
			.VGA_B(VGA_B),
			.VGA_HS(VGA_HS),
			.VGA_VS(VGA_VS),
			.VGA_BLANK(VGA_BLANK_N),
			.VGA_SYNC(VGA_SYNC_N),
			.VGA_CLK(VGA_CLK));
		defparam VGA.RESOLUTION = "320x240";
		defparam VGA.MONOCHROME = "FALSE";
		defparam VGA.BITS_PER_COLOUR_CHANNEL = 2;
		defparam VGA.BACKGROUND_IMAGE = "black.mif";
					
	// Put your code here. Your code should produce signals x,y,colour and writeEn/plot
	// for the VGA controller, in addition to any other functionality your design may require.
	
	keyboard_decoder kd(
		.p1_bomb(p1_bomb),
		.p2_bomb(p2_bomb),
		.p1_xdir(p1_xdir),
		.p2_xdir(p2_xdir),
		.p1_ydir(p1_ydir),
		.p2_ydir(p2_ydir),
		.p1_xmov(p1_xmov),
		.p2_xmov(p2_xmov),
		.p1_ymov(p1_ymov),
		.p2_ymov(p2_ymov),
		.start_game(start_game),
		.PS2_CLK(PS2_CLK),
		.PS2_DAT(PS2_DAT),
		.clock(CLOCK_50),
		.reset(reset)
	);

	// Instansiate FSM control
	
	bomberman_control bc(
		.memory_select(memory_select),
		.copy_enable(copy_enable),
		.tc_enable(tc_enable),
		.game_reset(game_reset),
		.draw_stage(draw_stage),
		.draw_tile(draw_tile),
		.draw_explosion(draw_explosion),
		.draw_bomb(draw_bomb),
		.set_p1(set_p1),
		.check_p1(check_p1),
		.draw_p1(draw_p1),
		.draw_p1_hp(draw_p1_hp),
		.set_p2(set_p2),
		.check_p2(check_p2),
		.draw_p2(draw_p2),
		.draw_p2_hp(draw_p2_hp),
		.bomb_id(bomb_id),
		.corner_id(corner_id),
		.p1_hp_id(p1_hp_id),
		.p2_hp_id(p2_hp_id),
		.black(black),
		.refresh(refresh),
		.print_screen(print_screen),
		.read_p1_input(read_p1_input),
		.send_p1_input(send_p1_input),
		.read_p2_input(read_p2_input),
		.send_p2_input(send_p2_input),
		.p1_lives(p1_lives),
		.p2_lives(p2_lives),
		.go(start_game),
		.finished(finished),
		.all_tiles_drawn(all_tiles_drawn),
		.clock(CLOCK_50),
		.reset(reset)
	);

   // Instansiate datapath
	
	bomberman_datapath dp(
		.X_out(x),
		.Y_out(y),
		.colour(colour),
		.write_en(write_en),
		.p1_lives(p1_lives),
		.p2_lives(p2_lives),
		.finished(finished),
		.all_tiles_drawn(all_tiles_drawn),
		.bomb_id(bomb_id),
		.corner_id(corner_id),
		.memory_select(memory_select),
		.p1_hp_id(p1_hp_id),
		.p2_hp_id(p2_hp_id),
		.copy_enable(copy_enable),
		.tc_enable(tc_enable),
		.game_reset(game_reset),
		.draw_stage(draw_stage),
		.draw_tile(draw_tile),
		.draw_explosion(draw_explosion),
		.draw_bomb(draw_bomb),
		.set_p1(set_p1),
		.check_p1(check_p1),
		.draw_p1(draw_p1),
		.draw_p1_hp(draw_p1_hp),
		.set_p2(set_p2),
		.check_p2(check_p2),
		.draw_p2(draw_p2),
		.draw_p2_hp(draw_p2_hp),
		.black(black),
		.refresh(refresh),
		.print_screen(print_screen),
		.read_p1_input(read_p1_input),
		.send_p1_input(send_p1_input),
		.read_p2_input(read_p2_input),
		.send_p2_input(send_p2_input),
		.p1_bomb(p1_bomb),
		.p1_xdir(p1_xdir),
		.p1_xmov(p1_xmov),
		.p1_ydir(p1_ydir),
		.p1_ymov(p1_ymov),
		.p2_bomb(p2_bomb),
		.p2_xdir(p2_xdir),
		.p2_xmov(p2_xmov),
		.p2_ydir(p2_ydir),
		.p2_ymov(p2_ymov),
		.clock(CLOCK_50),
		.reset(reset)
	);

endmodule
