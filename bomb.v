module bomb(clk, reset, tile_reset, X, Y, statsP1, statsP2, placeP1, placeP2, bomb_id, bomb_info, has_explosion, map_tile_id);
	
	input clk;                          // 50Mhz clock
	input reset;                        // Active-high reset
	input tile_reset;                   // Reset the stage to initial state
	input [8:0] X;                      // Position (in pixel coordinates) used for operations below
	input [7:0] Y;
	
	// Signals for bomb placing
	input [3:0] statsP1, statsP2;       // Player powerup stats, format is {radius{1:0], potency[1:0]}
	input placeP1, placeP2;             // Bomb is placed at (X, Y) on posedge of this signal
	
	// Signals for bomb drawing
	input [2:0] bomb_id;                // Bomb identifier, in range [0,5]
	output [17:0] bomb_info;            // Register with bomb enabled and position, format is {bomb_Y[7:0], bomb_X[8:0], bomb_enabled}
	
	// Signals for explosion drawing
	output reg has_explosion;           // Signal is high if an explosion exists at (X, Y)
	
	// Signals for tile drawing
	output [3:0] map_tile_id;
	
	// Game stage grids
	reg [3:0] init_stage [0:120];
	reg [3:0] game_stage [0:120];
	initial $readmemh("game_stage_1.mem", init_stage);
	
	wire true_reset;
	wire [8:0] bX;
	wire [7:0] bY, oX, oY;
	wire [3:0] tX, tY, rtX, rtY;        // tile coordinates, r = rounded
	wire [6:0] tile_index;
	
	wire [12:0] bomb_reg [0:5];         // bomb_reg[i][12:9] = bomb_tY,
	                                    // bomb_reg[i][8:5]  = bomb_tX,
	                                    // bomb_reg[i][4:3]  = bomb_radius,
	                                    // bomb_reg[i][2:1]  = bomb_potency,
	                                    // bomb_reg[i][0]    = bomb_enabled
	wire [5:0] bomb_exists;
	wire bomb_is_explosion [0:5];
	wire bomb_died [0:5];
	wire [6:0] bomb_index [0:5];
	
	assign true_reset = reset | tile_reset;
	assign oX = X - 72;
	assign oY = Y - 32;
	assign tX = oX[7:4];                // Convert X and Y from pixel coordinates to tile coordinates
	assign tY = oY[7:4];
	assign rtX = tX + oX[3];
	assign rtY = tY + oY[3];
	assign tile_index = ((tY * 11) + tX);
	
	assign bX = {1'b0, bomb_reg[bomb_id][8:5], 4'b0000} + 72;
	assign bY = {bomb_reg[bomb_id][12:9], 4'b0000} + 32;
	assign bomb_info = {bY, bX, (~bomb_is_explosion[bomb_id] & bomb_reg[bomb_id][0])};
	
	assign map_tile_id = game_stage[tile_index];
	
	// Player 1 bombs
	solo_bomb b0(
		.clk(clk),
		.reset(true_reset),
		.place(placeP1 & ~(|bomb_exists)),
		.tX(rtX),
		.tY(rtY),
		.stats(statsP1),
		.bomb_reg(bomb_reg[0]),
		.tile_index(bomb_index[0]),
		.exists(bomb_exists[0]),
		.is_explosion(bomb_is_explosion[0]),
		.died(bomb_died[0])
	);
	solo_bomb b1(
		.clk(clk),
		.reset(true_reset),
		.place(placeP1 & ~(|bomb_exists) & bomb_reg[0]),
		.tX(rtX),
		.tY(rtY),
		.stats(statsP1),
		.bomb_reg(bomb_reg[1]),
		.tile_index(bomb_index[1]),
		.exists(bomb_exists[1]),
		.is_explosion(bomb_is_explosion[1]),
		.died(bomb_died[1])
	);	
	solo_bomb b2(
		.clk(clk),
		.reset(true_reset),
		.place(placeP1 & ~(|bomb_exists) & bomb_reg[0] & bomb_reg[1]),
		.tX(rtX),
		.tY(rtY),
		.stats(statsP1),
		.bomb_reg(bomb_reg[2]),
		.tile_index(bomb_index[2]),
		.exists(bomb_exists[2]),
		.is_explosion(bomb_is_explosion[2]),
		.died(bomb_died[2])
	);
	
	// Player 2 bombs
	solo_bomb b3(
		.clk(clk),
		.reset(true_reset),
		.place(placeP2 & ~(|bomb_exists)),
		.tX(rtX),
		.tY(rtY),
		.stats(statsP2),
		.bomb_reg(bomb_reg[3]),
		.tile_index(bomb_index[3]),
		.exists(bomb_exists[3]),
		.is_explosion(bomb_is_explosion[3]),
		.died(bomb_died[3])
	);
	solo_bomb b4(
		.clk(clk),
		.reset(true_reset),
		.place(placeP2 & ~(|bomb_exists) & bomb_reg[3]),
		.tX(rtX),
		.tY(rtY),
		.stats(statsP2),
		.bomb_reg(bomb_reg[4]),
		.tile_index(bomb_index[4]),
		.exists(bomb_exists[4]),
		.is_explosion(bomb_is_explosion[4]),
		.died(bomb_died[4])
	);	
	solo_bomb b5(
		.clk(clk),
		.reset(true_reset),
		.place(placeP2 & ~(|bomb_exists) & bomb_reg[3] & bomb_reg[4]),
		.tX(rtX),
		.tY(rtY),
		.stats(statsP2),
		.bomb_reg(bomb_reg[5]),
		.tile_index(bomb_index[5]),
		.exists(bomb_exists[5]),
		.is_explosion(bomb_is_explosion[5]),
		.died(bomb_died[5])
	);
	
	// Update game stage
	integer i = 0;
	integer k = 0;
	always @(posedge clk)
	begin
		if(true_reset) // Reset block
		begin
			for(i = 0; i < 121; i = i + 1)
				if(init_stage[i] < 2)
					game_stage[i] <= init_stage[i];
				else
					game_stage[i] <= 2;
		end /*
		else
		begin
			for(k = 0; k < 6; k = k + 1) // Check every counter, if 0 then reset bomb and destroy blocks 
			begin
				if(bomb_died[k])
				begin
					// Radius 1
					if((bomb_index[k] + 1) <= 10)
					begin
						if((game_stage[bomb_index[k] + 1] == 2) &
							(init_stage[bomb_index[k] + 1] != 2))
							game_stage[bomb_index[k] + 1] <= init_stage[bomb_index[k] + 1];
						else
							game_stage[bomb_index[k] + 1] <= 0;
					end
					
					if((bomb_index[k] - 1) <= 10)
					begin
						if((game_stage[bomb_index[k] - 1] == 2) &
							(init_stage[bomb_index[k] - 1] != 2))
							game_stage[bomb_index[k] - 1] <= init_stage[bomb_index[k] - 1];
						else
							game_stage[bomb_index[k] - 1] <= 0;
					end
					
					if((bomb_index[k] + 11) <= 10)
					begin
						if((game_stage[bomb_index[k] + 11] == 2) &
							(init_stage[bomb_index[k] + 11] != 2))
							game_stage[bomb_index[k] + 11] <= init_stage[bomb_index[k] + 11];
						else
							game_stage[bomb_index[k] + 11] <= 0;
					end
					
					if((bomb_index[k] - 11) <= 10)
					begin
						if((game_stage[bomb_index[k] - 11] == 2) &
							(init_stage[bomb_index[k] - 11] != 2))
							game_stage[bomb_index[k] - 11] <= init_stage[bomb_index[k] - 11];
						else
							game_stage[bomb_index[k] - 11] <= 0;
					end
					
					// Radius 2
					if(bomb_reg[k][4:3] >= 1)
					begin
						if((game_stage[bomb_index[k] + 1] == 0) & ((bomb_index[k] + 2) <= 10))
						begin
							if((game_stage[bomb_index[k] + 2] == 2) &
							   (init_stage[bomb_index[k] + 2] != 2))
								game_stage[bomb_index[k] + 2] <= init_stage[bomb_index[k] + 2];
							else
								game_stage[bomb_index[k] + 2] <= 0;
						end
						
						if((game_stage[bomb_index[k] - 1] == 0) & ((bomb_index[k] - 2) <= 10))
						begin
							if((game_stage[bomb_index[k] - 2] == 2) &
							   (init_stage[bomb_index[k] - 2] != 2))
								game_stage[bomb_index[k] - 2] <= init_stage[bomb_index[k] - 2];
							else
								game_stage[bomb_index[k] - 2] <= 0;
						end
						
						if((game_stage[bomb_index[k] + 11] == 0) & ((bomb_index[k] + 22) <= 10))
						begin
							if((game_stage[bomb_index[k] + 22] == 2) &
							   (init_stage[bomb_index[k] + 22] != 2))
								game_stage[bomb_index[k] + 22] <= init_stage[bomb_index[k] + 22];
							else
								game_stage[bomb_index[k] + 22] <= 0;
						end
						
						if((game_stage[bomb_index[k] - 11] == 0) & ((bomb_index[k] - 22) <= 10))
						begin
							if((game_stage[bomb_index[k] - 22] == 2) &
							   (init_stage[bomb_index[k] - 22] != 2))
								game_stage[bomb_index[k] - 22] <= init_stage[bomb_index[k] - 22];
							else
								game_stage[bomb_index[k] - 22] <= 0;
						end
					end
					
					// Radius 3
					if(bomb_reg[k][4:3] >= 2)
					begin
						if((game_stage[bomb_index[k] + 1] == 0) & (game_stage[bomb_index[k] + 2] == 0) & ((bomb_index[k] + 3) <= 10))
						begin
							if((game_stage[bomb_index[k] + 3] == 2) &
							   (init_stage[bomb_index[k] + 3] != 2))
								game_stage[bomb_index[k] + 3] <= init_stage[bomb_index[k] + 3];
							else
								game_stage[bomb_index[k] + 3] <= 0;
						end
						
						if((game_stage[bomb_index[k] - 1] == 0) & (game_stage[bomb_index[k] - 2] == 0) & ((bomb_index[k] - 3) <= 10))
						begin
							if((game_stage[bomb_index[k] - 3] == 2) &
							   (init_stage[bomb_index[k] - 3] != 2))
								game_stage[bomb_index[k] - 3] <= init_stage[bomb_index[k] - 3];
							else
								game_stage[bomb_index[k] - 3] <= 0;
						end
						
						if((game_stage[bomb_index[k] + 11] == 0) & (game_stage[bomb_index[k] + 22] == 0) & ((bomb_index[k] + 33) <= 10))
						begin
							if((game_stage[bomb_index[k] + 33] == 2) &
							   (init_stage[bomb_index[k] + 33] != 2))
								game_stage[bomb_index[k] + 33] <= init_stage[bomb_index[k] + 33];
							else
								game_stage[bomb_index[k] + 33] <= 0;
						end
						
						if((game_stage[bomb_index[k] - 11] == 0) & (game_stage[bomb_index[k] - 22] == 0) & ((bomb_index[k] - 33) <= 10))
						begin
							if((game_stage[bomb_index[k] - 33] == 2) &
							   (init_stage[bomb_index[k] - 33] != 2))
								game_stage[bomb_index[k] - 33] <= init_stage[bomb_index[k] - 33];
							else
								game_stage[bomb_index[k] - 33] <= 0;
						end
					end
				end
			end
		end*/
	end
	
	// Update has_explosion
	integer j = 0;
	always @(*)
	begin
		has_explosion = 0;
		for(j = 0; j < 6; j = j + 1)
		begin
			if(bomb_is_explosion[j])
			begin
				if(((bomb_reg[j][8:5] == tX)     & (bomb_reg[j][12:9] == tY)) |
				   ((bomb_reg[j][8:5] == tX + 1) & (bomb_reg[j][12:9] == tY)     & ~game_stage[tile_index][0] & (tX + 1 <= 10)) |
				   ((bomb_reg[j][8:5] == tX - 1) & (bomb_reg[j][12:9] == tY)     & ~game_stage[tile_index][0] & (tX - 1 <= 10)) |
				   ((bomb_reg[j][8:5] == tX)     & (bomb_reg[j][12:9] == tY + 1) & ~game_stage[tile_index][0] & (tY + 1 <= 10)) |
				   ((bomb_reg[j][8:5] == tX)     & (bomb_reg[j][12:9] == tY - 1) & ~game_stage[tile_index][0] & (tY - 1 <= 10)))
					has_explosion = 1;
				else if((((bomb_reg[j][8:5] == tX + 2) & (bomb_reg[j][12:9] == tY)     & ~game_stage[tile_index][0] & ~(|game_stage[tile_index + 1])  & (tX + 2 <= 10)) |
					      ((bomb_reg[j][8:5] == tX - 2) & (bomb_reg[j][12:9] == tY)     & ~game_stage[tile_index][0] & ~(|game_stage[tile_index - 1])  & (tX - 2 <= 10)) |
					      ((bomb_reg[j][8:5] == tX)     & (bomb_reg[j][12:9] == tY + 2) & ~game_stage[tile_index][0] & ~(|game_stage[tile_index + 11]) & (tY + 2 <= 10)) |
					      ((bomb_reg[j][8:5] == tX)     & (bomb_reg[j][12:9] == tY - 2) & ~game_stage[tile_index][0] & ~(|game_stage[tile_index - 11]) & (tY - 2 <= 10))) &
					       (bomb_reg[j][4:3] >= 1))
					has_explosion = 1;
				else if((((bomb_reg[j][8:5] == tX + 3) & (bomb_reg[j][12:9] == tY)     & ~game_stage[tile_index][0] & ~(|game_stage[tile_index + 1])  & ~(|game_stage[tile_index + 2])  & (tX + 3 <= 10)) |
					      ((bomb_reg[j][8:5] == tX - 3) & (bomb_reg[j][12:9] == tY)     & ~game_stage[tile_index][0] & ~(|game_stage[tile_index - 1])  & ~(|game_stage[tile_index - 2])  & (tX - 3 <= 10)) |
					      ((bomb_reg[j][8:5] == tX)     & (bomb_reg[j][12:9] == tY + 3) & ~game_stage[tile_index][0] & ~(|game_stage[tile_index + 11]) & ~(|game_stage[tile_index + 22]) & (tY + 3 <= 10)) |
					      ((bomb_reg[j][8:5] == tX)     & (bomb_reg[j][12:9] == tY - 3) & ~game_stage[tile_index][0] & ~(|game_stage[tile_index - 11]) & ~(|game_stage[tile_index - 22]) & (tY - 3 <= 10))) &
					       (bomb_reg[j][4:3] >= 2))
					has_explosion = 1;
			end
		end
	end
	
endmodule

module solo_bomb(clk, reset, place, tX, tY, stats, bomb_reg, tile_index, exists, is_explosion, died);
	input clk, reset, place;
	input [3:0] tX, tY, stats;
	output reg [12:0] bomb_reg;
	output [6:0] tile_index;
	output exists, is_explosion;
	output reg died;
	
	wire [2:0] counter, c_max;
	wire clock_1Hz;
	
	assign tile_index = ((bomb_reg[12:9] * 11) + bomb_reg[8:5]);
	assign exists = ((bomb_reg[8:5] == tX) & (bomb_reg[12:9] == tY) & bomb_reg[0]);
	assign is_explosion = (bomb_reg[0] & (counter >= 2));
	assign c_max = {1'b0, bomb_reg[2:1]} + 3'd2;
	
	divide_sec d0(
		.clk(clk),
		.reset(reset | ~bomb_reg[0]),
		.enable(bomb_reg[0]),
		.clock_div(clock_1Hz)
	);
	
	count_max m0(
		.clk(clk),
		.reset(reset),
		.enable(clock_1Hz),
		.max(c_max),
		.q(counter)
	);
	
	always @(posedge clk)
	begin
		if(reset)
		begin
			bomb_reg <= 0;
			died <= 0;
		end
		else if(clock_1Hz & (counter == c_max))
		begin
			bomb_reg[0] <= 0;
			died <= 1;
		end
		else if(died)
		begin
			bomb_reg <= 0;
			died <= 0;
		end
		else if(place & ~bomb_reg[0])
		begin
			bomb_reg[0] <= 1;
			bomb_reg[4:1] <= stats;
			bomb_reg[8:5] <= tX;
			bomb_reg[12:9] <= tY;
		end
	end
	
endmodule

module divide_sec(clk, reset, enable, clock_div);
	input clk, reset, enable;
	output clock_div;
	
	reg [27:0] q;
	always @(posedge clk)
	begin
		if(reset | (q == 0))
			q <= 9; // Change to 49999999 when not testing
		else if(enable)
			q <= q - 1;
	end
	
	assign clock_div = ~(|q);
	
endmodule

module count_max(clk, reset, enable, max, q);
	input clk, reset, enable;
	input [2:0] max;
	output reg [2:0] q;
	
	always @(posedge clk)
	begin
		if(reset)
			q <= 0;
		else if(enable)
		begin
			if(q == max)
				q <= 0;
			else
				q <= q + 1;
		end
	end
	
endmodule
