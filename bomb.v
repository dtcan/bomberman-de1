module bomb(clk, X, Y, statsP1, statsP2, placeP1, placeP2, id, bomb_info, tile_x, tile_y, has_explosion);
	
	input clk;                    // 50Mhz clock
	input [8:0] X;                // Position (in pixel coordinates) used for operations below
	input [7:0] Y;
	
	// Signals for bomb placing
	input [3:0] statsP1, statsP2; // Player powerup stats, format is {radius{1:0], potency[1:0]}
	input placeP1, placeP2;       // Bomb is placed at (X, Y) on posedge of this signal
	
	// Signals for bomb drawing
	input [2:0] id;               // Bomb identifier, in range [0,5]
	output [17:0] bomb_info;      // Register with bomb enabled and position, format is {bomb_Y[7:0], bomb_X[8:0], bomb_enabled}
	
	// Signals for explosion drawing
	output has_explosion;         // Signal is high if an explosion exists at (X, Y)
	
	// TODO: Implementation goes here
	
endmodule