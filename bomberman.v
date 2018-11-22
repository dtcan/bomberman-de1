module bomberman
	(
		CLOCK_50,
		KEY,
		PS2_CLK,
		PS2_DAT,
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
	input [0:0] KEY;
	
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
	
	// wires for control/datapath inputs/ outputs.
	wire [1:0] memory_select;
	wire copy_enable, tc_enable, player_reset, stage_reset, draw_t, draw_p1, draw_p2;
	wire finished, all_tiles_drawn, game_over;
	
	// wires for datapath/VGA inputs/ outputs.
	wire [4:0] colour;
	wire [7:0] x;
	wire [6:0] y;
	
	wire reset;
	assign reset = ~KEY[0];
	
	// Create an Instance of a VGA controller - there can be only one!
	// Define the number of colours as well as the initial background
	// image file (.MIF) for the controller.
	vga_adapter VGA(
			.resetn(resetn),
			.clock(CLOCK_50),
			.colour(colour),
			.x(x),
			.y(y),
			.plot(writeEn),
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
		defparam VGA.BITS_PER_COLOUR_CHANNEL = 5;
		defparam VGA.BACKGROUND_IMAGE = "black.mif";
					
	// Put your code here. Your code should produce signals x,y,colour and writeEn/plot
	// for the VGA controller, in addition to any other functionality your design may require.
	
	keyboard_decoder kd(
		.p1_bomb(pl_bomb),
		.p2_bomb(p2_bomb),
		.p1_xdir(p1_xdir),
		.p2_xdir(p2_xdir),
		.p1_ydir(p1_ydir),
		.p2_ydir(p2_ydir),
		.p1_xmov(p1_xmov),
		.p2_xmov(p2_xmov),
		.p1_ymov(p1_ymov),
		.p2_ymov(p2_ymov),
		.PS2_CLK(PS2_CLK),
		.PS2_DAT(PS2_DAT),
		.clock(CLOCK50),
		.reset(reset)
	);

	// Instansiate FSM control
	
	bomberman_control bc(
		.memory_select(memory_select),
		.copy_enable(copy_enable),
		.tc_enable(tc_enable),
		.player_reset(player_reset),
		.stage_reset(stage_reset),
		.draw_t(draw_t),
		.draw_p1(draw_p1),
		.draw_p2(draw_p2),
		.go(p1_bomb),
		.finished(finished),
		.add_tiles_drawn(all_tiles_drawn),
		.game_over(game_over),
		.clock(CLOCK[50]),
		.reset(reset)
	);

   // Instansiate datapath
	
	bomberman_datapath dp(
	);
    
endmodule
