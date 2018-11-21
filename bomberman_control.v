
// module containing the control for bomberman.v

module bomberman_control(
	output [3:0] tile_select,
	output [1:0] memory_select,
	output copy_enable,
	output reset_stage,
	
	input go, finished, game_over,
	input clock,
	input reset
	);
	
	// load game_stage map from .mem file into memory.
	reg [3:0] game_stage_initial [0:120];
	// for use in game.
	reg [3:0] game_stage_current [0:120];
	initial $readmemh("game_stage_1.mem", game_stage_initial);
	
	delay_counter dc(
		.out(clock_60Hz),
		.clock(clock),
		.resetn(!counter_reset),
		.enable(counter_enable)
		);
	
	// how often to redraw objects (for now moving sprites at 4 pixels/ second)
	frame_counter fc(
		.out(draw),
		.clock(clock_60Hz),
		.resetn(!counter_reset),
		.enable(counter_enable)
		);
	
	// declare states
	localparam	LOAD_TITLE			= 4'd0,	// draw title screen background.
					TITLE					= 4'd1,	// wait for user input to start game.
					LOAD_STAGE 			= 4'd2,	// draw stage screen background.
	
					// states for drawing game stage tiles and sprites.
					DRAW_TILE			= 4'd3,	// draw stage tiles.
					UPDATE_TILE			= 4'd4,	// update tile counter.
					DRAW_P1				= 4'd5,	// draw player 1's sprite.
					DRAW_P2				= 4'd6, 	// draw player 2's sprite.
					GAME_IDLE			= 4'd7,	// wait for delay.
					UPDATE_STAGE		= 4'd8,	// update memory file.
					
					LOAD_WIN_SCREEN	= 4'd10,	// draw win screen background.
					WIN_SCREEN			= 4'd11;	// wait for user input to return to title screen.

	// state table
	always @ (*)
		begin: state_table
			case (current_state)
				LOAD_TITLE: 		next_state = finished 			? TITLE : LOAD_TITLE; 			 // loop in LOAD_TITLE until finished drawing title background.
				TITLE:				next_state = go					? LOAD_STAGE : TITLE;			 // loop in TITLE until user inputs to start game.
				LOAD_STAGE:			next_state = finished			? DRAW_TILE : LOAD_STAGE;		 // loop in LOAD_STAGE until finished drawing stage background.
				DRAW_TILE:			next_state = finished 			? UPDATE_TILE : DRAW_TILE;		 // loop in DRAW_TILE until finished drawing stage tile.
				UPDATE_TILE:		next_state = all_tiles_drawn	? DRAW_SPRITE : DRAW_TILE;		 // loop back to DRAW_TILE until finished drawing all tiles.
				DRAW_P1:				next_state = finished			? DRAW_P2 : DRAW_P1;				 // loop in DRAW_P1 until finished drawing Player 1's sprite.
				DRAW_P2: 			next_state = finished 			? GAME_IDLE : DRAW_P2;			 // loop in DRAW_P2 until finished drawing Player 2's sprite.
				GAME_IDLE:			next_state = next_cycle			? UPDATE_STAGE : GAME_IDLE;	 // loop in GAME_IDLE until delay is complete. 
				UPDATE_STAGE:		next_state = game_over			? LOAD_WIN_SCREEN : DRAW_TILE; // loop back to DRAW_TILE until a Player is killed.
				LOAD_WIN_SCREEN:	next_state = finished			? WIN_SCREEN : LOAD_WIN_SCREEN;// loop in LOAD_WIN_SCREEN until finished drawing win screen background.
				WIN_SCREEN:			next_state = go					? LOAD_TITLE : WIN_SCREEN;		 // loop in WIN_SCREEN until user inputs to return to title.
				default: next_state = LOAD_TITLE;
			endcase
		end
		
	// datapath control signals
	always @ (*)
		begin: enable_signals
			// default signals
			tile_select = 4'd0;
			memory_select = 2'd0;
			copy_enable = 0;
			tc_enable = 0;
			draw_p1 = 0;
			draw_p2 = 0;
			
			case (current_state)
				LOAD_TITLE:
					begin
						memory_select = 2'd0;
						copy_enable = 1;
					end
				TITLE:
					begin
					end
				LOAD_STAGE:
					begin
						memory_select = 2'd1;
						copy_enable = 1;
						game_stage_current = game_stage_initial;
					end
				DRAW_TILE:
					begin
						tile_select = game_stage_current[tile_count];
						memory_select = 2'd3;
					end
				UPDATE_TILE:
					begin
						tc_enable = 1;
					end
				DRAW_P1:
					begin
						draw_p1 = 1;
					end
				DRAW_P2:
					begin
						draw_p2 = 1;
					end
				GAME_IDLE:
					begin
					end
				UPDATE_STAGE:
					begin
						update_stage = 1;
					end
				LOAD_WIN_SCREEN:
					begin
						memory_select = 2'd2;
						copy_enable = 1;
					end
				WIN_SCREEN:
					begin
					end
			endcase
    end
	 
	 // current_state registers
    always@(posedge clock)
    begin: state_FFs
        if(!resetn)
            current_state <= S_IDLE;
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
				count <= 0;
			// count to 833 333 - 1
			else if (enable)
				if (count == 19'd833332) 
					count <= 0;
				else
					count <= count + 1;
		end
		
	// sends high out signal ~60 times per second. 
	assign clock_60Hz = (count == 0)? 1 : 0;

endmodule

// counter module for 15 frames elapsed.
// active-high reset.
module frame_counter(out, clock, reset, enable);
	
	output out;
	
	input clock, reset, enable;
	
	reg [3:0] count;
	
	always @(posedge clock, posedge resetn)
		begin
			if (reset)
				begin
					count <= 0;
				end
			// count to 15 - 1
			else if (enable)
				if (count == 4'd14)
						count <= 0;
				else
						count <= count + 1;
		end
	
	// sends high out signal 1 time every 15 frames.
	assign out = (count == 0)? 1 : 0;

endmodule

// counter module for cycling through game stage memory file.
// active-high reset.
module tile_counter(tile_count, clock, reset, enable);
	
	output reg [6:0] tile_count;
	output all_tiles_counted;
	
	input clock, reset, enable;
	
	reg [6:0] count;
	
	always @(posedge clock, posedge resetn)
		begin
			if (reset)
				begin
					tile_count <= 0;
				end
			// count to 121 - 1
			else if (enable)
				if (tile_count == 7'd120)
						tile_count <= 0;
				else
						tile_count <= count + 1;
		end
	
	assign all_tiles_counted = (tile_count == 0) ? 1 : 0;
		
endmodule
