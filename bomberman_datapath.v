module bomberman_datapath();
	
	// input and direction registers and their respective logic.
	always @ (posedge clock, negedge resetn)
		begin
			if (!resetn)
				begin
					X <= 8'd0;
					Y <= 7'd60;
					COLOUR <= 3'd0;
					dir_X <= 0;
					dir_Y <= 1;
				end
			else
				begin
					if (ld_colour)
						COLOUR <= colour_in;
					if (draw_enable)
						begin
							X <= wire_x;
							Y <= wire_y;
							COLOUR <= colour_in;
						end
					if (erase_enable)
						begin
							X <= wire_x;
							Y <= wire_y;
							COLOUR <= 3'd0;
						end
					if (update)
						begin
							dir_X = (X == 8'd155) ? 0 : 1;
							dir_Y = (Y == 7'd116) ? 0 : 1;
						end
				end
		end
		
	always @ (*)
		begin
			if (!resetn)
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
	input [5:0] increment,
	input clock, reset, enable, direction
	);
	
	always @ (posedge clock, posedge reset)
		begin
			// reset to start_coord.
			if (reset)
				begin
					next_coord <= start_coord;
				end
			else if (enable & (next_coord >= min_coord) & (next_coord <= max_coord))
				next_coord <= direction ? (next_coord + increment) : (next_coord - increment);
//				if (direction)
//					next_coord <= next_coord + increment;
//				else
//					next_coord <= next_coord - increment;
		end
		
endmodule

coordinate_counter player_1_X(
	.next_coord(p1_X),
	.start_coord(9'd72),
	.max_coord(9'd232),
	.increment(p1_speed),
	.clock(clock),
	.reset(reset),
	.enable(),
	.direction(p1_X_dir)
	);
	
coordinate_counter player_1_Y(
	.next_coord(p1_Y),
	.start_coord(9'd96),
	.max_coord(9'd232),
	.increment(p1_speed),
	.clock(clock),
	.reset(reset),
	.enable(),
	.direction(p1_Y_dir)
	);
	
coordinate_counter player_2_X(
	.next_coord(p2_X),
	.start_coord(9'd232),
	.increment(speed),
	.clock(clock),
	.reset(reset),
	.enable(),
	.direction(p2_X_dir)
	);
	
coordinate_counter player_2_Y(
	.next_coord(p2_Y),
	.start_coord(9'd96),
	.increment(speed),
	.clock(clock),
	.reset(reset),
	.enable(),
	.direction(p2_Y_dir)
	);
	
coordinate_counter tile_X(
	.next_coord(t_X),
	.start_coord(9'd72),
	.increment(5'd16),
	.clock(clock),
	.reset(reset),
	.enable(),
	.direction(1)
	);
	
coordinate_counter tile_Y(
	.next_coord(t_Y),
	.start_coord(9'd96),
	.increment(5'd16),
	.clock(clock),
	.reset(reset),
	.enable(),
	.direction(1)
	);
