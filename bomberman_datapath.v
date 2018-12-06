
// module containing the datapath for bomberman.v

module bomberman_datapath(
	// signals to VGA.
	output [8:0] X_out,
	output [7:0] Y_out,
	output [2:0] colour,
	output write_en,
	
	// signals to control.
	output reg [1:0] p1_lives, p2_lives,
	output finished, all_tiles_drawn,
	
	// signals from control.
	input [2:0] bomb_id,
	input [1:0] memory_select, p1_hp_id, p2_hp_id, corner_id,
	input copy_enable, tc_enable,
	input game_reset,
	input draw_stage, draw_tile, draw_explosion, draw_bomb, check_p1, draw_p1, draw_p1_hp, check_p2, draw_p2, draw_p2_hp,
	input black, refresh, print_screen, read_input,
	
	// signals from keyboard.
	input p1_bomb, p1_xdir, p1_xmov, p1_ydir, p1_ymov,
	input p2_bomb, p2_xdir, p2_xmov, p2_ydir, p2_ymov,
	
	input clock, reset
	); 
	
	reg [8:0] copy_X, copy_Y, bomb_X, bomb_Y;
	reg [5:0] statsP1, statsP2; 										// Player powerup stats, format is {num_bombs[1:0], radius[1:0], potency[1:0]}.
	reg [3:0] tile_select; 
	reg [3:0] p1_is_passable, p2_is_passable; 					// keeps track of whether corner tiles of each player are passable.
	reg [3:0] p1_speed, p2_speed; 									// Player speed stats.
	reg p1_x_enable, p1_y_enable, p2_x_enable, p2_y_enable;	// enable signals for player movement.
	reg p1_ic_start, p2_ic_start;										// start signals for invincibility counters.
	reg destroy_tile;
	
	wire [17:0] bomb_info;
	wire [8:0] p1_X, p1_Y, p2_X, p2_Y;
	wire p1_is_invincible, p2_is_invincible, has_explosion;
	
	wire [3:0] map_tile_id, tile_count_x, tile_count_y;
	wire all_tiles_counted_x, all_tiles_counted_y;
	assign all_tiles_drawn = (all_tiles_counted_x & all_tiles_counted_y);
	
	// limits for invincibility length, player speed, maximum number of bombs, explosion radius and potency.
	wire [3:0] speed_limit;
	wire [1:0] inv_length;
	wire [1:0] bomb_limit, radius_limit, potency_limit;
	assign inv_length = 2'd2; 							// set invincibility length of players to 2s.
	assign speed_limit = 4'd8;											// set speed limit to (8 * 4) pixels per second.
	assign bomb_limit = 2'd2; 											// set bomb limit to 3 per player (0 means 1).
	assign radius_limit = 2'd2; 										// set explosion radius limit to 3 tiles per player.
	assign potency_limit = 2'd2; 										// set explosion potency limit to 3 seconds per player.
	
	// P1

	coordinate_counter player_1_X(
		.next_coord(p1_X),
		.start_coord(9'd72),
		.min_coord(9'd72),
		.max_coord(9'd232),
		.increment(p1_speed),
		.clock(refresh),
		.reset(game_reset),
		.enable(p1_x_enable),
		.direction(p1_xdir)
		);
		
	coordinate_counter player_1_Y(
		.next_coord(p1_Y),
		.start_coord(9'd112),
		.min_coord(9'd32),
		.max_coord(9'd192),
		.increment(p1_speed),
		.clock(refresh),
		.reset(game_reset),
		.enable(p1_y_enable),
		.direction(p1_ydir)
		);

	// P2
		
	coordinate_counter player_2_X(
		.next_coord(p2_X),
		.start_coord(9'd232),
		.min_coord(9'd72),
		.max_coord(9'd232),
		.increment(p2_speed),
		.clock(refresh),
		.reset(game_reset),
		.enable(p2_x_enable),
		.direction(p2_xdir)
		);
		
	coordinate_counter player_2_Y(
		.next_coord(p2_Y),
		.start_coord(9'd112),
		.min_coord(9'd32),
		.max_coord(9'd192),
		.increment(p2_speed),
		.clock(refresh),
		.reset(game_reset),
		.enable(p2_y_enable),
		.direction(p2_ydir)
		);
	
	tile_counter tc_x(
		.tile_count(tile_count_x),
		.all_tiles_counted(all_tiles_counted_x),
		.clock(clock),
		.reset(reset),
		.enable(tc_enable)
		);
	
	tile_counter tc_y(
		.tile_count(tile_count_y),
		.all_tiles_counted(all_tiles_counted_y),
		.clock(clock),
		.reset(reset),
		.enable(all_tiles_counted_x)
		);
		
	invincibility_counter ic_p1(
		.is_invincible(p1_is_invincible),
		.length(inv_length),
		.clock(clock),
		.reset(game_reset),
		.start(p1_ic_start)
		);
	
	invincibility_counter ic_p2(
		.is_invincible(p2_is_invincible),
		.length(inv_length),
		.clock(clock),
		.reset(game_reset),
		.start(p2_ic_start)
		);	
	
	bomb b0(
		.clk(clock),
		.reset(reset),
		.tile_reset(game_reset),
		.X(bomb_X),
		.Y(bomb_Y),
		.statsP1(statsP1),
		.statsP2(statsP2),
		.placeP1((p1_bomb & read_input)),
		.placeP2((p2_bomb & read_input)),
		.destroy_tile(destroy_tile),
		.bomb_id(bomb_id),
		.bomb_info(bomb_info),
		.has_explosion(has_explosion),
		.map_tile_id(map_tile_id)
		);
	
	copy c0(
		.clk(clock),
		.reset_n(reset),
		.go(copy_enable),
		.refresh(print_screen),
		.X(copy_X),
		.Y(copy_Y),
		.memory_select(memory_select),
		.tile_select(tile_select),
		.black(black),
		.X_out(X_out),
		.Y_out(Y_out),
		.colour(colour),
		.write_en(write_en),
		.finished(finished)
		);
	
	// player coordinate logic.
	always @ (posedge clock, posedge reset, posedge game_reset)
		begin
			if (reset | game_reset)
				begin
					p1_x_enable <= 0;
					p1_y_enable <= 0;
					p2_x_enable <= 0;
					p2_y_enable <= 0;
				end
			else
				begin // check corners with respect to movement.
					if (p1_xdir)
						p1_x_enable <= (p1_is_passable[1] & p1_is_passable[3] & p1_xmov) ? 1'd1 : 1'd0;
					else if (!p1_xdir)
						p1_x_enable <= (p1_is_passable[0] & p1_is_passable[2] & p1_xmov) ? 1'd1 : 1'd0;
					if (p1_ydir)
						p1_y_enable <= (p1_is_passable[2] & p1_is_passable[3] & p1_ymov) ? 1'd1 : 1'd0;
					else if (!p1_ydir)
						p1_y_enable <= (p1_is_passable[0] & p1_is_passable[1] & p1_ymov) ? 1'd1 : 1'd0;
					if (p2_xdir)
						p2_x_enable <= (p2_is_passable[1] & p2_is_passable[3] & p2_xmov) ? 1'd1 : 1'd0;
					else if (!p2_xdir)
						p2_x_enable <= (p2_is_passable[0] & p2_is_passable[2] & p2_xmov) ? 1'd1 : 1'd0;
					if (p2_ydir)
						p2_y_enable <= (p2_is_passable[2] & p2_is_passable[3] & p2_ymov) ? 1'd1 : 1'd0;
					else if (!p2_ydir)
						p2_y_enable <= (p2_is_passable[0] & p2_is_passable[1] & p2_ymov) ? 1'd1 : 1'd0;
				end
		end
			
	// player health and bomb_XY logic.
	always @ (posedge clock, posedge reset, posedge game_reset)
		begin
			if (reset | game_reset)
				begin
					bomb_X <= 9'd0;
					bomb_Y <= 8'd0;
					statsP1 <= 6'd0;
					statsP2 <= 6'd0;
					p1_lives <= 2'd3;
					p2_lives <= 2'd3;
					p1_speed <= 4'd4;
					p2_speed <= 4'd4;
					p1_is_passable <= 4'd0;
					p2_is_passable <= 4'd0;
					destroy_tile <= 1'd0;
					p1_ic_start <= 1'd0;
					p2_ic_start <= 1'd0;
				end
			else if (draw_tile)
				begin
					bomb_X <= 9'd72 + {1'b0, tile_count_x, 4'b0000};
					bomb_Y <= 8'd32 + {tile_count_y, 4'b0000};
				end
			else if (draw_explosion)
				begin
					bomb_X <= 9'd72 + {1'b0, tile_count_x, 4'b0000}; // multiply tile_count_x by 16
					bomb_Y <= 8'd32 + {tile_count_y, 4'b0000};		 // multiply tile_count_y by 16
				end
			else if (check_p1)
				begin
					bomb_X <= p1_X + (9'd15 * corner_id [0]);
					bomb_Y <= p1_Y + (9'd15 * corner_id [1]);
					if (has_explosion & !p1_is_invincible)
						begin
							p1_lives <= p1_lives - 1'd1;
							p1_ic_start <= 1'd1;
						end
					else if (p1_ic_start)
						p1_ic_start <= 1'd0;
					case (map_tile_id)
						4'd0: // empty tile.
							begin
								p1_is_passable [corner_id] <= 1'd1;
								destroy_tile <= 1'd0;
							end
						4'd3: // extra bomb power up.
							begin
								p1_is_passable [corner_id] <= 1'd1;
								destroy_tile <= 1'd1;					// remove power up tile from game stage.
								if (statsP1 [5:4] < bomb_limit) 		// only increase if less than limit, do nothing otherwise.
									statsP1 [5:4] <= statsP1 [5:4] + 1'd1;
							end
						4'd4: // explosion radius power up.
							begin
								p1_is_passable [corner_id] <= 1'd1;
								destroy_tile <= 1'd1;					// remove power up tile from game stage.
								if (statsP1 [3:2] < radius_limit) 	// only increase if less than limit, do nothing otherwise.
									statsP1 [3:2] <= statsP1 [3:2] + 1'd1;
							end
						4'd5: // explosion potency power up.
							begin
								p1_is_passable [corner_id] <= 1'd1;
								destroy_tile <= 1'd1;					// remove power up tile from game stage.
								if (statsP1 [1:0] < potency_limit) 	// only increase if less than limit, do nothing otherwise.
									statsP1 [1:0] <= statsP1 [1:0] + 1'd1;
							end
						4'd6: // throw bomb power up.
							begin
								p1_is_passable [corner_id] <= 1'd1;
								destroy_tile <= 1'd1;					// remove power up tile from game stage.
								// TODO
							end
						4'd7: // extra life power up.
							begin
								p1_is_passable [corner_id] <= 1'd1;
								destroy_tile <= 1'd1;					// remove power up tile from game stage.
								if (p1_lives < 2'd2)						// only increase if less than limit, do nothing otherwise.
									p1_lives <= p1_lives + 1'd1;	
							end
						4'd8: // player speed power up.
							begin
								p1_is_passable [corner_id] <= 1'd1;
								destroy_tile <= 1'd1;					// remove power up tile from game stage.
								if (p1_speed < speed_limit)			// only increase if less than limit, do nothing otherwise.
									p1_speed <= p1_speed + 1'd1;
							end
						4'd12: // P1 sprite.
							begin
								p1_is_passable [corner_id] <= 1'd1;
								destroy_tile <= 1'd0;
							end
						4'd13: // P2 sprite.
							begin
								p1_is_passable [corner_id] <= 1'd1;
								destroy_tile <= 1'd0;
							end
						4'd14: // P1 sprite (inv).
							begin
								p1_is_passable [corner_id] <= 1'd1;
								destroy_tile <= 1'd0;
							end
						4'd15: // P2 sprite (inv).
							begin
								p1_is_passable [corner_id] <= 1'd1;
								destroy_tile <= 1'd0;
							end
						default:
							begin
								p1_is_passable [corner_id] <= 1'd0;	// all other tiles are impassable.
								destroy_tile <= 1'd0;
							end
					endcase
				end
			else if (check_p2)
				begin
					bomb_X <= p2_X + (9'd15 * corner_id [0]);
					bomb_Y <= p2_Y + (9'd15 * corner_id [1]);
					if (has_explosion & !p2_is_invincible)
						begin
							p2_lives <= p2_lives - 1'd1;
							p2_ic_start <= 1'd1;
						end
					else if (p2_ic_start)
						p2_ic_start <= 1'd0;
					case (map_tile_id)
						4'd0: // empty tile.
							begin
								p2_is_passable [corner_id] <= 1'd1;
								destroy_tile <= 1'd0;
							end
						4'd3: // extra bomb power up.
							begin
								p2_is_passable [corner_id] <= 1'd1;
								destroy_tile <= 1'd1;					// remove power up tile from game stage.
								if (statsP2 [5:4] < bomb_limit) 		// only increase if less than limit, do nothing otherwise.
									statsP2 [5:4] <= statsP2 [5:4] + 1'd1;
							end
						4'd4: // explosion radius power up.
							begin
								p2_is_passable [corner_id] <= 1'd1;
								destroy_tile <= 1'd1;					// remove power up tile from game stage.
								if (statsP2 [3:2] < radius_limit) 	// only increase if less than limit, do nothing otherwise.
									statsP2 [3:2] <= statsP2 [3:2] + 1'd1;
							end
						4'd5: // explosion potency power up.
							begin
								p2_is_passable [corner_id] <= 1'd1;
								destroy_tile <= 1'd1;					// remove power up tile from game stage.
								if (statsP2 [1:0] < potency_limit) 	// only increase if less than limit, do nothing otherwise.
									statsP2 [1:0] <= statsP2 [1:0] + 1'd1;
							end
						4'd6: // throw bomb power up.
							begin
								p2_is_passable [corner_id] <= 1'd1;
								destroy_tile <= 1'd1;					// remove power up tile from game stage.
								// TODO
							end
						4'd7: // extra life power up.
							begin
								p2_is_passable [corner_id] <= 1'd1;
								destroy_tile <= 1'd1;					// remove power up tile from game stage.
								if (p2_lives < 2'd2)						// only increase if less than limit, do nothing otherwise.
									p2_lives <= p2_lives + 1'd1;	
							end
						4'd8: // player speed power up.
							begin
								p2_is_passable [corner_id] <= 1'd1;
								destroy_tile <= 1'd1;					// remove power up tile from game stage.
								if (p2_speed < speed_limit)			// only increase if less than limit, do nothing otherwise.
									p2_speed <= p2_speed + 1'd1;
							end
						4'd12: // P1 sprite.
							begin
								p2_is_passable [corner_id] <= 1'd1;
								destroy_tile <= 1'd0;
							end
						4'd13: // P2 sprite.
							begin
								p2_is_passable [corner_id] <= 1'd1;
								destroy_tile <= 1'd0;
							end
						4'd14: // P1 sprite (inv).
							begin
								p2_is_passable [corner_id] <= 1'd1;
								destroy_tile <= 1'd0;
							end
						4'd15: // P2 sprite (inv).
							begin
								p2_is_passable [corner_id] <= 1'd1;
								destroy_tile <= 1'd0;
							end
						default:
							begin
								p2_is_passable [corner_id] <= 1'd0;	// all other tiles are impassable.
								destroy_tile <= 1'd0;
							end
					endcase
				end
			else if (read_input)
				begin
					if (p1_bomb)
						begin
							bomb_X <= p1_X;
							bomb_Y <= p1_Y [7:0];
						end
					if (p2_bomb)
						begin
							bomb_X <= p2_X;
							bomb_Y <= p2_Y [7:0];
						end
				end
		end
		
	// copy_XY logic.
	always @ (posedge clock, posedge reset)
		begin
			if (reset)
				begin
					copy_X <= 9'd0;
					copy_Y <= 8'd0;
					tile_select <= 4'd0;
				end
			else
				begin
					if (draw_stage)
						begin
							copy_X <= 9'd0;
							copy_Y <= 8'd0;
							tile_select <= 4'd0;
						end
					if (draw_tile)
						begin
							copy_X <= 9'd72 + {1'b0, tile_count_x, 4'b0000}; // multiply tile_count_x by 16
							copy_Y <= 8'd32 + {tile_count_y, 4'b0000};		 // multiply tile_count_y by 16
							tile_select <= map_tile_id;
						end
					if (draw_explosion)
						begin
							copy_X <= 9'd72 + {1'b0, tile_count_x, 4'b0000}; // multiply tile_count_x by 16
							copy_Y <= 8'd32 + {tile_count_y, 4'b0000};		 // multiply tile_count_y by 16
							tile_select <= has_explosion ? 4'd11 : map_tile_id;
						end
					if (draw_bomb)
						begin
							if (bomb_info [0])
								begin
									copy_X <= bomb_info [9:1];
									copy_Y <= bomb_info [17:10];
									tile_select <= 4'd10;
								end
						end
					if (draw_p1)
						begin
							copy_X <= p1_X;
							copy_Y <= p1_Y [7:0];
							tile_select <= p1_is_invincible ? 4'd14 : 4'd12;
						end
					if (draw_p1_hp)
						begin
							copy_X <= 9'd8 + (9'd20 * p1_hp_id);
							copy_Y <= 8'd112;
							tile_select <= 4'd9;
						end
					if (draw_p2)
						begin
							copy_X <= p2_X;
							copy_Y <= p2_Y [7:0];
							tile_select <= p2_is_invincible ? 4'd14 : 4'd12;
						end
					if (draw_p2_hp)
						begin
							copy_X <= 9'd256 + (9'd20 * p2_hp_id);
							copy_Y <= 8'd112;
							tile_select <= 4'd9;
						end
				end
		end
		
endmodule

// counter module for X/Y coordinate given start_coord, min_coord, max_coord, direction and increment.
// 0: decrease coord by increment. 1: increase coord by increment.
// active high reset.
module coordinate_counter(
	output reg [8:0] next_coord,

	input [8:0] start_coord,
	input [8:0] min_coord, max_coord,
	input [3:0] increment,
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
				begin
					if (direction)
						begin
							if (next_coord <= max_coord - increment)
								next_coord <= next_coord + increment;
						end
					else
						begin
							if (next_coord >= min_coord + increment)
								next_coord <= next_coord - increment;
						end
				end
		end
		
endmodule

// counter module for cycling through game stage memory file.
// active-high reset.
module tile_counter(tile_count, all_tiles_counted, clock, reset, enable);
	
	output reg [3:0] tile_count;
	output all_tiles_counted;
	
	input clock, reset, enable;
	
	always @(posedge clock, posedge reset)
		begin
			if (reset)
				begin
					tile_count <= 0;
				end
			// count to 10 - 1
			else if (enable)
				if (tile_count == 4'd10)
						tile_count <= 0;
				else
						tile_count <= tile_count + 4'd1;
		end
	
	assign all_tiles_counted = (tile_count == 0) ? 1'd1 : 1'd0;
		
endmodule

// counter module for specified length (in seconds)[max 3s] of time.
// active-high reset.
module invincibility_counter(is_invincible, length, clock, reset, start);
	
	output is_invincible;
	
	input [1:0] length;
	input clock, reset, start;
	
	reg [51:0] count;

	always @(posedge clock, posedge reset)
		begin
			if (reset)
				count <= 52'd0;
			else if (start)
				count <= 52'd1;
			else if (count != 52'd0)
				count <= count + 52'd1;
			else if (count == (52'd50000000 * length - 1))
				count <= 52'd0;
		end
	
	assign is_invincible = (count == 52'd0) ? 1'd0 : 1'd1;
	
endmodule
