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
	
	wire clock_1Hz;
	wire true_reset;
	wire [2:0] bc_max [0:5];
	wire [8:0] bX;
	wire [7:0] oX, oY, bY;
	wire [3:0] tX, tY, rtX, rtY;        // tile coordinates, r = rounded
	wire [2:0] bomb_counters [0:5];     // Count-up timers for bombs/explosions
	reg [12:0] bomb_reg [0:5];          // bomb_reg[i][12:9] = bomb_tY,
	                                    // bomb_reg[i][8:5] = bomb_tX,
	                                    // bomb_reg[i][4:3] = bomb_radius,
	                                    // bomb_reg[i][2:1] = bomb_potency,
	                                    // bomb_reg[i][0] = bomb_enabled
	wire [12:0] bomb_reg_test;
	assign bomb_reg_test = bomb_reg[bomb_id];
	
	assign true_reset = reset | tile_reset;
	assign bc_max[0] = {1'b0, bomb_reg[0][2:1]} + 3'd2;
	assign bc_max[1] = {1'b0, bomb_reg[1][2:1]} + 3'd2;
	assign bc_max[2] = {1'b0, bomb_reg[2][2:1]} + 3'd2;
	assign bc_max[3] = {1'b0, bomb_reg[3][2:1]} + 3'd2;
	assign bc_max[4] = {1'b0, bomb_reg[4][2:1]} + 3'd2;
	assign bc_max[5] = {1'b0, bomb_reg[5][2:1]} + 3'd2;
	assign oX = X - 72;
	assign oY = Y - 32;
	assign tX = oX[7:4];                // Convert X and Y from pixel coordinates to tile coordinates
	assign tY = oY[7:4];
	assign rtX = tX + oX[3];
	assign rtY = tY + oY[3];
	
	assign bX = {1'b0, bomb_reg[bomb_id][8:5], 4'b0000} + 72;
	assign bY = {bomb_reg[bomb_id][12:9], 4'b0000} + 32;
	assign bomb_info = {bY, bX, (bomb_counters[bomb_id] < 2 & bomb_reg[bomb_id][0])};
	
	assign map_tile_id = game_stage[(tY * 11) + tX];
	
	divide_sec d0(
		.clk(clk),
		.reset(true_reset),
		.clock_div(clock_1Hz)
	);
	
	count_max m0(
		.clk(clock_1Hz),
		.reset(true_reset),
		.enable(bomb_reg[0][0]),
		.max(bc_max[0]),
		.q(bomb_counters[0])
	);
	count_max m1(
		.clk(clock_1Hz),
		.reset(true_reset),
		.enable(bomb_reg[1][0]),
		.max(bc_max[1]),
		.q(bomb_counters[1])
	);
	count_max m2(
		.clk(clock_1Hz),
		.reset(true_reset),
		.enable(bomb_reg[2][0]),
		.max(bc_max[2]),
		.q(bomb_counters[2])
	);
	count_max m3(
		.clk(clock_1Hz),
		.reset(true_reset),
		.enable(bomb_reg[3][0]),
		.max(bc_max[3]),
		.q(bomb_counters[3])
	);
	count_max m4(
		.clk(clock_1Hz),
		.reset(true_reset),
		.enable(bomb_reg[4][0]),
		.max(bc_max[4]),
		.q(bomb_counters[4])
	);
	count_max m5(
		.clk(clock_1Hz),
		.reset(true_reset),
		.enable(bomb_reg[5][0]),
		.max(bc_max[5]),
		.q(bomb_counters[5])
	);
	
	integer i = 0;
	integer k = 0;
	always @(posedge clk)
	begin
		reg can_place;
		can place = (((bomb_reg[0][8:5] != rtX) | (bomb_reg[0][12:9] != rtY) | ~bomb_reg[0][0]) &
			         ((bomb_reg[1][8:5] != rtX) | (bomb_reg[1][12:9] != rtY) | ~bomb_reg[1][0]) &
			         ((bomb_reg[2][8:5] != rtX) | (bomb_reg[2][12:9] != rtY) | ~bomb_reg[2][0]) &
			         ((bomb_reg[3][8:5] != rtX) | (bomb_reg[3][12:9] != rtY) | ~bomb_reg[3][0]) &
			         ((bomb_reg[4][8:5] != rtX) | (bomb_reg[4][12:9] != rtY) | ~bomb_reg[4][0]) &
			         ((bomb_reg[5][8:5] != rtX) | (bomb_reg[5][12:9] != rtY) | ~bomb_reg[5][0]));
		
		if(true_reset) // Reset block
		begin
			bomb_reg[0] <= 0;
			bomb_reg[1] <= 0;
			bomb_reg[2] <= 0;
			bomb_reg[3] <= 0;
			bomb_reg[4] <= 0;
			bomb_reg[5] <= 0;
			for(i = 0; i < 121; i = i + 1)
				if(init_stage[i] < 2)
					game_stage[i] <= init_stage[i];
				else
					game_stage[i] <= 2;
		end
		else if(placeP1 & can_place & (~bomb_reg[0][0] | ~bomb_reg[2][0] | ~bomb_reg[4][0])) // Place a bomb for Player 1
		begin
			begin
				if(~bomb_reg[0][0])
				begin
					bomb_reg[0][0] <= 1;
					bomb_reg[0][4:1] <= statsP1;
					bomb_reg[0][8:5] <= rtX;
					bomb_reg[0][12:9] <= rtY;
				end
				else if(~bomb_reg[2][0])
				begin
					bomb_reg[2][0] <= 1;
					bomb_reg[2][4:1] <= statsP1;
					bomb_reg[2][8:5] <= rtX;
					bomb_reg[2][12:9] <= rtY;
				end
				else if(~bomb_reg[4][0])
				begin
					bomb_reg[4][0] <= 1;
					bomb_reg[4][4:1] <= statsP1;
					bomb_reg[4][8:5] <= rtX;
					bomb_reg[4][12:9] <= rtY;
				end
			end
		end
		else if(placeP2 & can_place & (~bomb_reg[1][0] | ~bomb_reg[3][0] | ~bomb_reg[5][0])) // Place a bomb for Player 2
		begin
			begin
				if(~bomb_reg[1][0])
				begin
					bomb_reg[1][0] <= 1;
					bomb_reg[1][4:1] <= statsP2;
					bomb_reg[1][8:5] <= rtX;
					bomb_reg[1][12:9] <= rtY;
				end
				else if(~bomb_reg[3][0])
				begin
					bomb_reg[3][0] <= 1;
					bomb_reg[3][4:1] <= statsP2;
					bomb_reg[3][8:5] <= rtX;
					bomb_reg[3][12:9] <= rtY;
				end
				else if(~bomb_reg[5][0])
				begin
					bomb_reg[5][0] <= 1;
					bomb_reg[5][4:1] <= statsP2;
					bomb_reg[5][8:5] <= rtX;
					bomb_reg[5][12:9] <= rtY;
				end
			end
		end
		else
		begin
			for(k = 0; k < 6; k = k + 1) // Check every counter, if 0 then reset bomb and destroy blocks 
			begin
				if(bomb_counters[k] == bc_max[k])
				begin
					bomb_reg[k] <= 0;
					
					// Radius 1
					if((game_stage[(bomb_reg[k][12:9] * 11) + bomb_reg[k][8:5] + 1] == 2) &
					   (init_stage[(bomb_reg[k][12:9] * 11) + bomb_reg[k][8:5] + 1] != 2))
						game_stage[(bomb_reg[k][12:9] * 11) + bomb_reg[k][8:5] + 1] <= init_stage[(bomb_reg[k][12:9] * 11) + bomb_reg[k][8:5] + 1];
					else
						game_stage[(bomb_reg[k][12:9] * 11) + bomb_reg[k][8:5] + 1] <= 0;
					
					if((game_stage[((bomb_reg[k][12:9] + 1) * 11) + bomb_reg[k][8:5]] == 2) &
					   (init_stage[((bomb_reg[k][12:9] + 1) * 11) + bomb_reg[k][8:5]] != 2))
						game_stage[((bomb_reg[k][12:9] + 1) * 11) + bomb_reg[k][8:5]] <= init_stage[((bomb_reg[k][12:9] + 1) * 11) + bomb_reg[k][8:5]];
					else
						game_stage[((bomb_reg[k][12:9] + 1) * 11) + bomb_reg[k][8:5]] <= 0;
					
					if((game_stage[(bomb_reg[k][12:9] * 11) + bomb_reg[k][8:5] - 1] == 2) &
					   (init_stage[(bomb_reg[k][12:9] * 11) + bomb_reg[k][8:5] - 1] != 2))
						game_stage[(bomb_reg[k][12:9] * 11) + bomb_reg[k][8:5] - 1] <= init_stage[(bomb_reg[k][12:9] * 11) + bomb_reg[k][8:5] - 1];
					else
						game_stage[(bomb_reg[k][12:9] * 11) + bomb_reg[k][8:5] - 1] <= 0;
					
					if((game_stage[((bomb_reg[k][12:9] - 1) * 11) + bomb_reg[k][8:5]] == 2) &
					   (init_stage[((bomb_reg[k][12:9] - 1) * 11) + bomb_reg[k][8:5]] != 2))
						game_stage[((bomb_reg[k][12:9] - 1) * 11) + bomb_reg[k][8:5]] <= init_stage[((bomb_reg[k][12:9] - 1) * 11) + bomb_reg[k][8:5]];
					else
						game_stage[((bomb_reg[k][12:9] - 1) * 11) + bomb_reg[k][8:5]] <= 0;
					
					// Radius 2
					if(bomb_reg[k][4:3] >= 1)
					begin
						if(game_stage[(bomb_reg[k][12:9] * 11) + bomb_reg[k][8:5] + 1] == 0)
						begin
							if((game_stage[(bomb_reg[k][12:9] * 11) + bomb_reg[k][8:5] + 2] == 2) &
							   (init_stage[(bomb_reg[k][12:9] * 11) + bomb_reg[k][8:5] + 2] != 2))
								game_stage[(bomb_reg[k][12:9] * 11) + bomb_reg[k][8:5] + 2] <= init_stage[(bomb_reg[k][12:9] * 11) + bomb_reg[k][8:5] + 2];
							else
								game_stage[(bomb_reg[k][12:9] * 11) + bomb_reg[k][8:5] + 2] <= 0;
						end
						
						if(game_stage[((bomb_reg[k][12:9] + 1) * 11) + bomb_reg[k][8:5]] == 0)
						begin
							if((game_stage[((bomb_reg[k][12:9] + 2) * 11) + bomb_reg[k][8:5]] == 2) &
							   (init_stage[((bomb_reg[k][12:9] + 2) * 11) + bomb_reg[k][8:5]] != 2))
								game_stage[((bomb_reg[k][12:9] + 2) * 11) + bomb_reg[k][8:5]] <= init_stage[((bomb_reg[k][12:9] + 2) * 11) + bomb_reg[k][8:5]];
							else
								game_stage[((bomb_reg[k][12:9] + 2) * 11) + bomb_reg[k][8:5]] <= 0;
						end
						
						if(game_stage[(bomb_reg[k][12:9] * 11) + bomb_reg[k][8:5] - 1] == 0)
						begin
							if((game_stage[(bomb_reg[k][12:9] * 11) + bomb_reg[k][8:5] - 2] == 2) &
							   (init_stage[(bomb_reg[k][12:9] * 11) + bomb_reg[k][8:5] - 2] != 2))
								game_stage[(bomb_reg[k][12:9] * 11) + bomb_reg[k][8:5] - 2] <= init_stage[(bomb_reg[k][12:9] * 11) + bomb_reg[k][8:5] - 2];
							else
								game_stage[(bomb_reg[k][12:9] * 11) + bomb_reg[k][8:5] - 2] <= 0;
						end
						
						if(game_stage[((bomb_reg[k][12:9] - 1) * 11) + bomb_reg[k][8:5]] == 0)
						begin
							if((game_stage[((bomb_reg[k][12:9] - 2) * 11) + bomb_reg[k][8:5]] == 2) &
							   (init_stage[((bomb_reg[k][12:9] - 2) * 11) + bomb_reg[k][8:5]] != 2))
								game_stage[((bomb_reg[k][12:9] - 2) * 11) + bomb_reg[k][8:5]] <= init_stage[((bomb_reg[k][12:9] - 2) * 11) + bomb_reg[k][8:5]];
							else
								game_stage[((bomb_reg[k][12:9] - 2) * 11) + bomb_reg[k][8:5]] <= 0;
						end
					end
					
					// Radius 3
					if(bomb_reg[k][4:3] >= 2)
					begin
						if((game_stage[(bomb_reg[k][12:9] * 11) + bomb_reg[k][8:5] + 1] == 0) & (game_stage[(bomb_reg[k][12:9] * 11) + bomb_reg[k][8:5] + 2] == 0))
						begin
							if((game_stage[(bomb_reg[k][12:9] * 11) + bomb_reg[k][8:5] + 3] == 2) &
							   (init_stage[(bomb_reg[k][12:9] * 11) + bomb_reg[k][8:5] + 3] != 2))
								game_stage[(bomb_reg[k][12:9] * 11) + bomb_reg[k][8:5] + 3] <= init_stage[(bomb_reg[k][12:9] * 11) + bomb_reg[k][8:5] + 3];
							else
								game_stage[(bomb_reg[k][12:9] * 11) + bomb_reg[k][8:5] + 3] <= 0;
						end
						
						if((game_stage[((bomb_reg[k][12:9] + 1) * 11) + bomb_reg[k][8:5]] == 0) & (game_stage[((bomb_reg[k][12:9] + 2) * 11) + bomb_reg[k][8:5]] == 0))
						begin
							if((game_stage[((bomb_reg[k][12:9] + 3) * 11) + bomb_reg[k][8:5]] == 2) &
							   (init_stage[((bomb_reg[k][12:9] + 3) * 11) + bomb_reg[k][8:5]] != 2))
								game_stage[((bomb_reg[k][12:9] + 3) * 11) + bomb_reg[k][8:5]] <= init_stage[((bomb_reg[k][12:9] + 3) * 11) + bomb_reg[k][8:5]];
							else
								game_stage[((bomb_reg[k][12:9] + 3) * 11) + bomb_reg[k][8:5]] <= 0;
						end
						
						if((game_stage[(bomb_reg[k][12:9] * 11) + bomb_reg[k][8:5] - 1] == 0) & (game_stage[(bomb_reg[k][12:9] * 11) + bomb_reg[k][8:5] - 2] == 0))
						begin
							if((game_stage[(bomb_reg[k][12:9] * 11) + bomb_reg[k][8:5] - 3] == 2) &
							   (init_stage[(bomb_reg[k][12:9] * 11) + bomb_reg[k][8:5] - 3] != 2))
								game_stage[(bomb_reg[k][12:9] * 11) + bomb_reg[k][8:5] - 3] <= init_stage[(bomb_reg[k][12:9] * 11) + bomb_reg[k][8:5] - 3];
							else
								game_stage[(bomb_reg[k][12:9] * 11) + bomb_reg[k][8:5] - 3] <= 0;
						end
						
						if((game_stage[((bomb_reg[k][12:9] - 1) * 11) + bomb_reg[k][8:5]] == 0) & (game_stage[((bomb_reg[k][12:9] - 2) * 11) + bomb_reg[k][8:5]] == 0))
						begin
							if((game_stage[((bomb_reg[k][12:9] - 3) * 11) + bomb_reg[k][8:5]] == 2) &
							   (init_stage[((bomb_reg[k][12:9] - 3) * 11) + bomb_reg[k][8:5]] != 2))
								game_stage[((bomb_reg[k][12:9] - 3) * 11) + bomb_reg[k][8:5]] <= init_stage[((bomb_reg[k][12:9] - 3) * 11) + bomb_reg[k][8:5]];
							else
								game_stage[((bomb_reg[k][12:9] - 3) * 11) + bomb_reg[k][8:5]] <= 0;
						end
					end
				end
			end
		end
	end
	
	// Update has_explosion
	integer j = 0;
	always @(*)
	begin
		has_explosion = 0;
		for(j = 0; j < 6; j = j + 1)
		begin
			if(bomb_counters[j] >= 2 & bomb_reg[j][0])
			begin
				if(((bomb_reg[j][8:5] == tX)     & (bomb_reg[j][12:9] == tY)) |
				   ((bomb_reg[j][8:5] == tX + 1) & (bomb_reg[j][12:9] == tY)     & ~game_stage[(tY * 11) + tX][0] & (tX + 1 <= 10)) |
				   ((bomb_reg[j][8:5] == tX)     & (bomb_reg[j][12:9] == tY + 1) & ~game_stage[(tY * 11) + tX][0] & (tY + 1 <= 10)) |
				   ((bomb_reg[j][8:5] == tX - 1) & (bomb_reg[j][12:9] == tY)     & ~game_stage[(tY * 11) + tX][0] & (tX - 1 >= 0)) |
				   ((bomb_reg[j][8:5] == tX)     & (bomb_reg[j][12:9] == tY - 1) & ~game_stage[(tY * 11) + tX][0] & (tY - 1 >= 0)))
					has_explosion = 1;
				if((((bomb_reg[j][8:5] == tX + 2) & (bomb_reg[j][12:9] == tY)     & ~game_stage[(tY * 11) + tX][0] & ~(|game_stage[(tY * 11) + tX + 1])   & (tX + 2 <= 10)) |
					((bomb_reg[j][8:5] == tX)     & (bomb_reg[j][12:9] == tY + 2) & ~game_stage[(tY * 11) + tX][0] & ~(|game_stage[((tY + 1) * 11) + tX]) & (tY + 2 <= 10)) |
					((bomb_reg[j][8:5] == tX - 2) & (bomb_reg[j][12:9] == tY)     & ~game_stage[(tY * 11) + tX][0] & ~(|game_stage[(tY * 11) + tX - 1])   & (tX - 2 >= 0)) |
					((bomb_reg[j][8:5] == tX)     & (bomb_reg[j][12:9] == tY - 2) & ~game_stage[(tY * 11) + tX][0] & ~(|game_stage[((tY - 1) * 11) + tX]) & (tY - 2 >= 0))) &
					(bomb_reg[j][4:3] >= 1))
					has_explosion = 1;
				if((((bomb_reg[j][8:5] == tX + 3) & (bomb_reg[j][12:9] == tY)     & ~game_stage[(tY * 11) + tX][0] & ~(|game_stage[(tY * 11) + tX + 2])   & ~(|game_stage[(tY * 11) + tX + 1])   & (tX + 3 <= 10)) |
					((bomb_reg[j][8:5] == tX)     & (bomb_reg[j][12:9] == tY + 3) & ~game_stage[(tY * 11) + tX][0] & ~(|game_stage[((tY + 2) * 11) + tX]) & ~(|game_stage[((tY + 1) * 11) + tX]) & (tY + 3 <= 10)) |
					((bomb_reg[j][8:5] == tX - 3) & (bomb_reg[j][12:9] == tY)     & ~game_stage[(tY * 11) + tX][0] & ~(|game_stage[(tY * 11) + tX - 2])   & ~(|game_stage[(tY * 11) + tX - 1])   & (tX - 3 >= 0)) |
					((bomb_reg[j][8:5] == tX)     & (bomb_reg[j][12:9] == tY - 3) & ~game_stage[(tY * 11) + tX][0] & ~(|game_stage[((tY - 2) * 11) + tX]) & ~(|game_stage[((tY - 1) * 11) + tX]) & (tY - 3 >= 0))) &
					(bomb_reg[j][4:3] >= 2))
					has_explosion = 1;
			end
		end
	end
	
endmodule

module divide_sec(clk, reset, clock_div);
	input clk, reset;
	output clock_div;
	
	reg [27:0] q;
	always @(posedge clk, posedge reset)
	begin
		if(reset)
			q <= 49999999;
		else
		begin
			if(q == 0)
				q <= 49999999;
			else
				q <= q - 1;
		end
	end
	
	assign clock_div = ~(|q);
	
endmodule

module count_max(clk, reset, enable, max, q);
	input clk, reset, enable;
	input [2:0] max;
	output reg [2:0] q;
	
	always @(posedge clk, posedge reset)
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