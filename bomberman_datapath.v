module bomberman_datapath(
	output [8:0] reg X, Y,
	
	input player_reset;
	input p1_bomb, p1_xdir, p1_xmov, p1_ydir, p1_ymov,
	input p2_bomb, p2_xdir, p2_xmov, p2_ydir, p2_ymov,
	); 
	
	reg [8:0] p1_X, p1_Y, p2_X, p2_Y;
	reg [4:0] p1_speed, p2_speed;
	
	assign p1_speed = 5'd2; // for now set 'speed' of sprite to be 8 pixels moved per second
	assign p2_speed = 5'd2;
	
	// load game_stage map from .mem file into memory.
	reg [3:0] game_stage_initial [0:120];
	// for use in game.
	reg [3:0] game_stage_current [0:120];
	initial $readmemh("game_stage_1.mem", game_stage_initial);
	
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
	
	copy(clk, reset_n, go, memory_select, tile_select, colour, offset, write_en, finished);
	
	// input and direction registers and their respective logic.
	always @ (posedge clock, posedge reset)
		begin
			if (resetn)
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
							Y <= p1_Y [8:0];
						end
					else if (draw_p2)
						begin
							X <= p2_X;
							Y <= p2_Y [8:0];
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
					x_out <= 8'd0;
					y_out <= 7'd60;
					colour_out <= 3'd0;
				end
			else if (draw_enable | erase_enable) 
				// add last 2 least significant bits of counter output to X coordinate.
				// add first 2 most significant bits of counter output to Y coordinate.
				begin
					x_out <= X + count_out[1:0];
					y_out <= Y + count_out[3:2];
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
