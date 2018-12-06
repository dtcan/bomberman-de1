
// module containing the control for bomberman.v

module bomberman_control(
	output reg [1:0] memory_select,
	output reg copy_enable, tc_enable,
	output reg game_reset,
	output reg draw_stage, draw_tile, draw_explosion, draw_bomb, check_p1, draw_p1, draw_p1_hp, check_p2, draw_p2, draw_p2_hp,
	output reg black, print_screen, read_input,
	output [2:0] bomb_id, corner_id,
	output [1:0] p1_hp_id, p2_hp_id,
	output refresh, // maybe let datapath have it's own internal clock
	
	input [1:0] p1_lives, p2_lives,
	input go, finished, all_tiles_drawn,
	input clock,
	input reset
	);
	
	// internal registers and wires.
	reg [4:0] current_state, next_state;
	reg dc_reset, dc_enable; 						// for delay counter
	reg bc_reset, bc_enable; 						// for bomb counter
	reg lc_reset, lc_p1_enable, lc_p2_enable; // for lives counter
	reg cc_reset, cc_enable;						// for corner counter
	
	wire clock_60Hz;			 						// internal clock @ 60Hz
	
	wire all_bombs_drawn, all_checked, all_P1HP_drawn, all_P2HP_drawn;
	wire game_over;
	
	// game_over condition.
	assign game_over = ((p1_lives == 2'd0) | (p2_lives == 2'd0)) ? 1'd1 : 1'd0; 
	
	delay_counter dc(
		.clock_60Hz(clock_60Hz),
		.clock(clock),
		.reset((reset | dc_reset)),
		.enable(dc_enable)
		);
	
	// how often to redraw objects (for now moving sprites 4 times/ second).
	frame_counter fc(
		.out(refresh),
		.clock(clock),
		.reset((reset | dc_reset)),
		.enable(clock_60Hz)
		);
	
	// bomb counter.
	counter_3bit bc(
		.count(bomb_id),
		.counted(all_bombs_drawn),
		.count_to(3'd5),
		.clock(clock),
		.reset((reset | bc_reset)),
		.enable(bc_enable)
		);
	
	// corner counter.
	counted_3bit cc(
		.count(corner_id),
		.counted(all_checked),
		.count_to(3'd7),
		.clock(clock),
		.reset((reset | cc_reset)),
		.enable(cc_enable)
		);
	
	// p1 hearts counter.
	counter_3bit lc_p1(
		.count(p1_hp_id),
		.counted(all_P1HP_drawn),
		.count_to(3'd2), // (p1_lives - 2'd1)
		.clock(clock),
		.reset((reset | lc_reset)),
		.enable(lc_p1_enable)
		);
	
	// p2 hearts counter.
	counter_3bit lc_p2(
		.count(p2_hp_id),
		.counted(all_P2HP_drawn),
		.count_to(3'd2), // (p2_lives - 2'd1)
		.clock(clock),
		.reset((reset | lc_reset)),
		.enable(lc_p2_enable)
		);
		
	// declare states``
	localparam	LOAD_TITLE			= 5'd0,	// draw title screen background to buffer.
					DISPLAY_TITLE		= 5'd1,	// draw title screen background to VGA.
					TITLE					= 5'd2,	// wait for user input to start game.
					LOAD_STAGE 			= 5'd3,	// draw stage screen background to buffer.
					DISPLAY_STAGE		= 5'd4,	// draw stage screen background to VGA.
	
					// states for drawing game stage tiles and sprites.
					DRAW_TILE			 = 5'd5,	// draw stage tile.
					DRAW_EXPLOSION		 = 5'd6, // draw explosion (if it exists) on stage tile.
					UPDATE_TILE			 = 5'd7,	// update tile counter.
					DRAW_BOMB			 = 5'd8,	// draw bomb tiles.
					UPDATE_BOMB			 = 5'd9, // update bomb counter.
					CHECK_P1_CORNER	 = 5'd10,// check tile of corner pixel.
					UPDATE_P1_CORNER	 = 5'd11,// update corner pixel.
					DRAW_P1				 = 5'd12,// draw player 1's sprite.
					DRAW_P1_HP		 	 = 5'd13,// draw player 1's health.
					UPDATE_P1_HP		 = 5'd14,// update player 1's health.
					CHECK_P2_CORNER	 = 5'd15,// check tile of corner pixel.
					UPDATE_P2_CORNER	 = 5'd16,// update corner pixel.
					DRAW_P2				 = 5'd17,// draw player 2's sprite.
					DRAW_P2_HP			 = 5'd18,// draw player 2's health.
					UPDATE_P2_HP		 = 5'd19,// update player 2's health.
					GAME_IDLE			 = 5'd20,// wait for delay.
					UPDATE_STAGE		 = 5'd21,// draw stage to VGA.
					
					LOAD_WIN_SCREEN	 = 5'd22,// draw win screen background to buffer.
					DISPLAY_WIN_SCREEN = 5'd23,// draw win screen background to VGA.
					WIN_SCREEN			 = 5'd24;// wait for user input to return to title screen.

	// state table
	always @ (*)
		begin: state_table
			case (current_state)
				LOAD_TITLE: 			next_state = finished 			? DISPLAY_TITLE : LOAD_TITLE;  			// loop in LOAD_TITLE until finished drawing title background to buffer.
				DISPLAY_TITLE:			next_state = finished			? TITLE : DISPLAY_TITLE;		 			// loop in DISPLAY_TITLE until finished drawing title background to VGA.
				TITLE:					next_state = go					? LOAD_STAGE : TITLE;			 			// loop in TITLE until user inputs to start game.
				LOAD_STAGE:				next_state = finished			? DISPLAY_STAGE : LOAD_STAGE;	 			// loop in LOAD_STAGE until finished drawing stage background to buffer.
				DISPLAY_STAGE: 		next_state = finished			? DRAW_TILE : DISPLAY_STAGE;	 			// loop in DISPLAY_STAGE until finished drawing title background to VGA.
				DRAW_TILE:				next_state = finished 			? DRAW_EXPLOSION : DRAW_TILE;	 			// loop in DRAW_TILE until finished drawing stage tile.
				DRAW_EXPLOSION:		next_state = finished			? UPDATE_TILE : DRAW_EXPLOSION;			// loop in DRAW_EXPLOSION until finished drawing explosion on stage tile.
				UPDATE_TILE:			next_state = all_tiles_drawn	? DRAW_BOMB : DRAW_TILE;		 			// loop back to DRAW_TILE until finished drawing all tiles.
				DRAW_BOMB:				next_state = finished 			? UPDATE_BOMB : DRAW_BOMB;		 			// loop in DRAW_BOMB until finished drawing current bomb.
				UPDATE_BOMB:			next_state = all_bombs_drawn	? CHECK_P1_CORNER : DRAW_BOMB; 			// loop back to DRAW_BOMB until finished drawing all bombs.
				CHECK_P1_CORNER:		next_state = UPDATE_P1_CORNER;										 	
				UPDATE_P1_CORNER:		next_state = all_checked		? DRAW_P1 : CHECK_P1_CORNER;	 			// loop back to CHECK_P1_CORNER until all 4 corners are checked.
				DRAW_P1:					next_state = finished			? DRAW_P1_HP : DRAW_P1;	 		 			// loop in DRAW_P1 until finished drawing Player 1's sprite.
				DRAW_P1_HP:				next_state = finished			? UPDATE_P1_HP : DRAW_P1_HP;	 			// loop in DRAW_P1_HP until finished drawing current P1's HP.
				UPDATE_P1_HP:			next_state = all_P1HP_drawn	? CHECK_P2_CORNER : DRAW_P1_HP;			// loop back to DRAW_P1_HP until finished drawing all P1's HPs.
				CHECK_P2_CORNER:		next_state = UPDATE_P2_CORNER;
				UPDATE_P2_CORNER: 	next_state = all_checked		? DRAW_P2 : CHECK_P2_CORNER;	 			// loop back to CHECK_P2_CORNER until all 4 corners are checked.
				DRAW_P2: 				next_state = finished 			? DRAW_P2_HP : DRAW_P2;			 			// loop in DRAW_P2 until finished drawing Player 2's sprite.
				DRAW_P2_HP:				next_state = finished			? UPDATE_P2_HP : DRAW_P2_HP;	 			// loop in DRAW_P2_HP until finished drawing current P2's HP.
				UPDATE_P2_HP:			next_state = all_P2HP_drawn	? GAME_IDLE : DRAW_P2_HP;	 	 			// loop back to DRAW_P2_HP until finished drawing all P2's HPs.
				GAME_IDLE:				next_state = clock_60Hz			? UPDATE_STAGE : GAME_IDLE;	 			// loop in GAME_IDLE until delay is complete. 
				UPDATE_STAGE:																						 	 			// loop back to DRAW_TILE until a Player is killed after updating stage.
					begin
						if (game_over)
							next_state = LOAD_WIN_SCREEN;
						else if (!game_over & finished)
							next_state = DRAW_TILE;
						else
							next_state = UPDATE_STAGE;
					end
				LOAD_WIN_SCREEN:		next_state = finished			? DISPLAY_WIN_SCREEN : LOAD_WIN_SCREEN;// loop in LOAD_WIN_SCREEN until finished drawing win screen background to buffer.
				DISPLAY_WIN_SCREEN: 	next_state = finished			? WIN_SCREEN : DISPLAY_WIN_SCREEN; 		//loop in DISPLAY_WIN_SCREEN until finished drawing title background to VGA.
				WIN_SCREEN:				next_state = go					? LOAD_TITLE : WIN_SCREEN;		 			// loop in WIN_SCREEN until user inputs to return to title.
				default: 				next_state = LOAD_TITLE;
			endcase
		end
		
	// datapath control signals
	always @ (*)
		begin: enable_signals
			// default signals
			memory_select = 2'd0;
			copy_enable = 0;
			tc_enable = 0;
			game_reset = 0;
			
			draw_stage = 0;
			draw_tile = 0;
			draw_explosion = 0;
			draw_bomb = 0;
			check_p1 = 0;
			draw_p1 = 0;
			draw_p1_hp = 0;
			check_p2 = 0;
			draw_p2 = 0;
			draw_p2_hp = 0;
			black = 0;
			
			dc_reset = 0;
			dc_enable = 0;
			bc_reset = 0;
			bc_enable = 0;
			lc_reset = 0;
			lc_p1_enable = 0;
			lc_p2_enable = 0;
			cc_reset = 0;
			cc_enable = 0;
			
			print_screen = 0;
			read_input = 0;
			
			case (current_state)
				LOAD_TITLE:
					begin
						memory_select = 2'd0;
						copy_enable = 1;
						draw_stage = 1;
					end
					
				DISPLAY_TITLE:
					begin
						print_screen = 1;
					end
					
				TITLE:
					begin
					end
					
				LOAD_STAGE:
					begin
						memory_select = 2'd1;
						copy_enable = 1;
						draw_stage = 1;
					end
				
				DISPLAY_STAGE:
					begin
						game_reset = 1;					
						dc_reset = 1;
						bc_reset = 1;
						lc_reset = 1;
						print_screen = 1;
					end
					
				DRAW_TILE:
					begin
						memory_select = 2'd3;
						copy_enable = 1;
						draw_tile = 1;
						dc_enable = 1;
					end
					
				DRAW_EXPLOSION:
					begin
						memory_select = 2'd3;
						copy_enable = 1;
						draw_explosion = 1;
						dc_enable = 1;
					end
				UPDATE_TILE:
					begin
						tc_enable = 1;
						dc_enable = 1;
					end
					
				DRAW_BOMB:
					begin
						memory_select = 2'd3;
						copy_enable = 1;
						draw_bomb = 1;
						dc_enable = 1;
					end
					
				UPDATE_BOMB:
					begin
						bc_enable = 1;
						dc_enable = 1;
						cc_reset = 1;
					end
				
				CHECK_P1_CORNER:
					begin
						dc_enable = 1;
						check_p1 = 1;
					end
				
				UPDATE_P1_CORNER:
					begin
						dc_enable = 1;
						cc_enable = 1;
					end
					
				DRAW_P1:
					begin
						memory_select = 2'd3;
						copy_enable = 1;
						draw_p1 = 1;
						dc_enable = 1;
					end
					
				DRAW_P1_HP:
					begin
						memory_select = 2'd3;
						copy_enable = 1;
						draw_p1_hp = 1;
						if (p1_hp_id >= p1_lives)
							black = 1;
						else
							black = 0;
						dc_enable = 1;
					end
					
				UPDATE_P1_HP:
					begin
						lc_p1_enable = 1;
						dc_enable = 1;
						cc_reset = 1;
					end
				
				CHECK_P2_CORNER:
					begin
						dc_enable = 1;
						check_p2 = 1;
					end
					
				UPDATE_P2_CORNER:
					begin
						dc_enable = 1;
						cc_enable = 1;
					end
					
				DRAW_P2:
					begin
						memory_select = 2'd3;
						copy_enable = 1;
						draw_p2 = 1;
						dc_enable = 1;
					end
					
				DRAW_P2_HP:
					begin
						memory_select = 2'd3;
						copy_enable = 1;
						draw_p2_hp = 1;
						if (p2_hp_id >= p2_lives)
							black = 1;
						else
							black = 0;
						dc_enable = 1;
					end
					
				UPDATE_P2_HP:
					begin
						lc_p2_enable = 1;
						dc_enable = 1;
					end
					
				GAME_IDLE:
					begin
						dc_enable = 1;
					end
					
				UPDATE_STAGE:
					begin
						dc_enable = 1;
						print_screen = 1;
						read_input = 1;
					end
					
				LOAD_WIN_SCREEN:
					begin
						memory_select = 2'd2;
						copy_enable = 1;
						draw_stage = 1;
					end
					
				DISPLAY_WIN_SCREEN:
					begin
						print_screen = 1;
					end
					
				WIN_SCREEN:
					begin
					end
			endcase
    end
	 
	 // current_state registers
    always@(posedge clock)
    begin: state_FFs
        if(reset)
            current_state <= LOAD_TITLE;
        else
            current_state <= next_state;
    end
	
endmodule

// delay_counter module to convert 50MHz clock to 60Hz.
// active high reset.
module delay_counter(clock_60Hz, clock, reset, enable);
	
	output clock_60Hz;
	
	input clock, reset, enable;
	
	reg [19:0] count;
	
	always @(posedge clock, posedge reset)
		begin
			if (reset)
				count <= 20'd0;
			// count to 833 333 - 1
			else if (enable)
				begin
					if (count == 20'd833332) // change this to 833332 after testing
						count <= 20'd0;
					else
						count <= count + 20'd1;
				end
		end
		
	// sends high out signal ~60 times per second. 
	assign clock_60Hz = (count == 20'd833332)? 1'd1 : 1'd0;

endmodule

// counter module for 15 frames elapsed.
// active-high reset.
module frame_counter(out, clock, reset, enable);
	
	output out;
	
	input clock, reset, enable;
	
	reg [3:0] count;
	
	always @(posedge clock, posedge reset)
		begin
			if (reset)
				count <= 4'd0;
			// count to 15 - 1
			else if (enable)
				begin
					if (count == 4'd14)
						count <= 4'd0;
					else
						count <= count + 4'd1;
				end
		end
	
	// sends high out signal 1 time every 15 frames.
	assign out = (count == 4'd14)? 1'd1 : 1'd0;

endmodule

// TODO combine the following two modules.
// counter module for 6 bombs.
// active high reset.
//module bomb_counter(count, out, clock, reset, enable);
//	
//	output reg [2:0] count;
//	
//	output out;
//		
//	input clock, reset, enable;
//	
//	always @ (posedge clock, posedge reset)
//		begin
//			if (reset)
//				count <= 3'd0;
//			else if (enable)
//				begin
//					if (count == 3'd5)
//						count <= 3'd0;
//					else
//						count <= count + 3'd1;
//				end
//		end
//		
//	assign out = (count == 3'd5) ? 1'd1 : 1'd0;
//	
//endmodule

// counter module that counts up to 7 (from 0) and outputs counted high when it does.
// active high reset.
module counter_3bit(

	output reg [2:0] count,
	output counted,

	input [2:0] count_to,
	input clock, reset, enable
	
	);
	
	always @ (posedge clock, posedge reset)
		begin
			if (reset)
				count <= 3'd0;
			else if (enable)
				begin
					if (count == count_to)
						count <= 3'd0;
					else
						count <= count + 3'd1;
				end
		end
		
	assign counted = (count == count_to) ? 1'd1 : 1'd0;
	
endmodule

//// counter module that counts to count_to and sends finished signal when count is at count_to.
//// active high reset.
//module counter(count, out, count_to, clock, reset, enable);
//	
//	output reg [1:0] count;
//	
//	output out;
//	
//	input [1:0] count_to;
//	input clock, reset, enable;
//	
//	always @ (posedge clock, posedge reset)
//		begin
//			if (reset)
//				count <= 2'd0;
//			else if (enable)
//				begin
//					if (count == count_to)
//						count <= 2'd0;
//					else
//						count <= count + 2'd1;
//				end
//		end
//	
//	assign out = (count == count_to) ? 1'd1 : 1'd0;
//	
//endmodule
