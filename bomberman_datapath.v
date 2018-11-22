module bomberman_datapath(
	output reg [8:0] X_out, Y_out,
	output finished, all_tiles_drawn, game_over,
	output write_en,
	
	input [1:0] memory_select,
	input copy_enable, tc_enable,
	input player_reset, stage_reset,
	input draw_t, draw_p1, draw_p2,
	input p1_bomb, p1_xdir, p1_xmov, p1_ydir, p1_ymov,
	input p2_bomb, p2_xdir, p2_xmov, p2_ydir, p2_ymov,
	input clock, reset
	); 
	
	reg [8:0] X, Y, p1_X, p1_Y, p2_X, p2_Y;
	reg [4:0] p1_speed, p2_speed;
	
	assign p1_speed = 5'd2; // for now set 'speed' of sprite to be 8 pixels moved per second
	assign p2_speed = 5'd2;
	
	// load game_stage map from .mem file into memory.
	reg [3:0] game_stage_initial [0:120];
//	// for use in game.
//	reg [3:0] game_stage_current [0:120];
	initial $readmemh("game_stage_1.mem", game_stage_initial);
	
	wire all_tiles_counted;
	
	coordinate_counter player_1_X(
		.next_coord(p1_X),
		.start_coord(9'd72),
		.min_coord(9'd72),
		.max_coord(9'd232),
		.increment(p1_speed),
		.clock(clock),
		.reset(player_reset),
		.enable(p1_xmov),
		.direction(p1_xdir)
		);
		
	coordinate_counter player_1_Y(
		.next_coord(p1_Y),
		.start_coord(9'd96),
		.min_coord(9'd32),
		.max_coord(9'd192),
		.increment(p1_speed),
		.clock(clock),
		.reset(player_reset),
		.enable(p2_ymov),
		.direction(p1_ydir)
		);
		
	coordinate_counter player_2_X(
		.next_coord(p2_X),
		.start_coord(9'd232),
		.min_coord(9'd72),
		.max_coord(9'd232),
		.increment(speed),
		.clock(clock),
		.reset(player_reset),
		.enable(p2_xmov),
		.direction(p2_xdir)
		);
		
	coordinate_counter player_2_Y(
		.next_coord(p2_Y),
		.start_coord(9'd96),
		.min_coord(9'd32),
		.max_coord(9'd192),
		.increment(speed),
		.clock(clock),
		.reset(player_reset),
		.enable(p2_ymov),
		.direction(p2_ydir)
		);
		
	tile_counter tc(
		.tile_count(tile_count),
		.all_tiles_counted(all_tiles_counted),
		.clock(clock),
		.reset(reset),
		.enable(tc_enable)
		);
	
	copy(
		.clk(clock),
		.reset_n(reset),
		.go(copy_enable),
		.memory_select(memory_select),
		.tile_select((game_stage_initial [tile_count])),
		.colour(colour),
		.offset(offset),
		.write_en(write_en),
		.finished(finished)
		);
	
	// input and direction registers and their respective logic.
	always @ (posedge clock, posedge reset)
		begin
			if (reset)
				begin
					X <= 9'd0;
					Y <= 8'd0;
				end
			else
				begin
					if (draw_t)
						begin
							X <= t_X;
							Y <= t_Y;
						end
					else if (draw_p1)
						begin
							X <= p1_X;
							Y <= p1_Y [7:0];
						end
					else if (draw_p2)
						begin
							X <= p2_X;
							Y <= p2_Y [7:0];
						end
					else
						begin
							X <= 9'd0;
							Y <= 8'd0;
						end
				end
		end
		
	always @ (*)
		begin
			if (reset)
				begin
					X_out <= 9'd0;
					Y_out <= 8'd60;
					colour_out <= 3'd0;
				end
			else if (draw_t | draw_p1 | draw_p2) 
				// add last 2 least significant bits of counter output to X coordinate.
				// add first 2 most significant bits of counter output to Y coordinate.
				begin
					X_out <= X + offset[8:0];
					Y_out <= Y + offset[16:9];
					colour_out <= COLOUR;
				end
		end
endmodule

// counter module for X/Y coordinate given start_coord, min_coord, max_coord, direction and increment.
// 0: decrease coord by increment. 1: increase coord by increment.
// active high reset.
module coordinate_counter(
	output reg [8:0] next_coord,

	input reg [8:0] start_coord,
	input reg [8:0] min_coord, max_coord,
	input [4:0] increment,
	input clock, reset, enable, direction
	);
	
	always @ (posedge clock, posedge reset)
		begin
			// reset to start_coord.
			if (reset)
				begin
					next_coord <= start_coord;
				end
			else if (enable)
				if (direction)
					if (next_coord <= max_coord - increment)
						next_coord <= next_coord + increment;
				else
					if (next_coord >= min_coord + increment)
						next_coord <= next_coord - increment;
		end
		
endmodule


// counter module for cycling through game stage memory file.
// active-high reset.
module tile_counter(tile_count, all_tiles_counted, clock, reset, enable);
	
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
