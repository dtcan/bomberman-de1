module copy(clk, reset_n, go, refresh, X, Y, memory_select, tile_select, black, X_out, Y_out, colour, write_en, finished);
	input clk, reset_n, go, refresh, black;
	input [8:0] X;
	input [7:0] Y;
	input [1:0] memory_select;
	input [3:0] tile_select;
	output [8:0] X_out;
	output [7:0] Y_out;
	output reg [5:0] colour; // Remove reg keyword if using buffer
	output reg write_en, finished;
	
	localparam WIDTH = 320, HEIGHT = 240; // Still have to go change bit-widths when changing these!
	localparam BITS_PER_COLOUR = 2;       // When changing, also change colour reg and wire widths
	localparam TRANSPARENT = 6'b001100;   // Change this when changing BITS_PER_COLOUR
	
	reg [5:0] temp; //colour_b;
	wire [5:0] colour_1, colour_2, colour_3, colour_t;
	wire [8:0] offset_x;
	wire [7:0] offset_y;
	wire [7:0] offset_t;
	reg [16:0] offset;
	reg enable_count;
	// reg write_buffer;
	reg [16:0] adr;
	// reg refreshing;
	
	assign X_out = X + offset[8:0];
	assign Y_out = Y + offset[16:9];
	
	count8 c0(
		.clk(clk),
		.reset_n(reset_n),
		.enable(enable_count & (memory_select == 2'b11)), // If using buffer, check refreshing signal
		.q(offset_t)
	);
	
	count_xy c1(
		.clk(clk),
		.reset_n(reset_n),
		.enable(enable_count & (memory_select != 2'b11)), // If using buffer, check refreshing
		.max_x(WIDTH),
		.max_y(HEIGHT),
		.q_x(offset_x),
		.q_y(offset_y)
	);
	
	always @(*)
	begin
		case(memory_select) // Assign values to colour_b when using buffer
			2'b00: temp = colour_1;
			2'b01: temp = colour_2;
			2'b10: temp = colour_3;
			2'b11: temp = colour_t;
		endcase
		if((temp != TRANSPARENT) & black)
			colour = 0;
		else
			colour = temp;
		
		if(memory_select == 2'b11) // Check refreshing if using buffer
			offset = {4'd0, offset_t[7:4], 5'd0, offset_t[3:0]};
		else
			offset = {offset_y, offset_x};
	end
	
	/*
	altsyncram	Buffer (
				.wren_a (write_buffer),
				.clock0 (clk), // read clock
				.clocken0 (1'b1), // read enable clock
				.address_a (adr),
				.data_a (colour_b),	// data in
				.q_a (colour)		// data out
				);
	defparam
		Buffer.WIDTH_A = BITS_PER_COLOUR * 3,
		Buffer.INTENDED_DEVICE_FAMILY = "Cyclone II",
		Buffer.OPERATION_MODE = "SINGLE_PORT",
		Buffer.WIDTHAD_A = 17,
		Buffer.NUMWORDS_A = WIDTH * HEIGHT,
		Buffer.CLOCK_ENABLE_INPUT_A = "BYPASS",
		Buffer.POWER_UP_UNINITIALIZED = "FALSE",
		Buffer.INIT_FILE = "title.mif";
	*/
	altsyncram	TitleScreen (
				.wren_a (1'b0),
				.clock0 (clk), // read clock
				.clocken0 (1'b1), // read enable clock
				.address_a (adr),
				.q_a (colour_1)	// data out
				);
	defparam
		TitleScreen.WIDTH_A = BITS_PER_COLOUR * 3,
		TitleScreen.INTENDED_DEVICE_FAMILY = "Cyclone II",
		TitleScreen.OPERATION_MODE = "ROM",
		TitleScreen.WIDTHAD_A = 17,
		TitleScreen.NUMWORDS_A = WIDTH * HEIGHT,
		TitleScreen.CLOCK_ENABLE_INPUT_A = "BYPASS",
		TitleScreen.POWER_UP_UNINITIALIZED = "FALSE",
		TitleScreen.INIT_FILE = "title.mif";
	
	altsyncram	GameScreen (
				.wren_a (1'b0),
				.clock0 (clk), // read clock
				.clocken0 (1'b1), // read enable clock
				.address_a (adr),
				.q_a (colour_2)	// data out
				);
	defparam
		GameScreen.WIDTH_A = BITS_PER_COLOUR * 3,
		GameScreen.INTENDED_DEVICE_FAMILY = "Cyclone II",
		GameScreen.OPERATION_MODE = "ROM",
		GameScreen.WIDTHAD_A = 17,
		GameScreen.NUMWORDS_A = WIDTH * HEIGHT,
		GameScreen.CLOCK_ENABLE_INPUT_A = "BYPASS",
		GameScreen.POWER_UP_UNINITIALIZED = "FALSE",
		GameScreen.INIT_FILE = "game.mif";
	
	altsyncram	EndScreen (
				.wren_a (1'b0),
				.clock0 (clk), // read clock
				.clocken0 (1'b1), // read enable clock
				.address_a (adr),
				.q_a (colour_3)	// data out
				);
	defparam
		EndScreen.WIDTH_A = BITS_PER_COLOUR * 3,
		EndScreen.INTENDED_DEVICE_FAMILY = "Cyclone II",
		EndScreen.OPERATION_MODE = "ROM",
		EndScreen.WIDTHAD_A = 17,
		EndScreen.NUMWORDS_A = WIDTH * HEIGHT,
		EndScreen.CLOCK_ENABLE_INPUT_A = "BYPASS",
		EndScreen.POWER_UP_UNINITIALIZED = "FALSE",
		EndScreen.INIT_FILE = "endscreen.mif";
	
	altsyncram	TileSet (
				.wren_a (1'b0),
				.clock0 (clk), // read clock
				.clocken0 (1'b1), // read enable clock
				.address_a (adr[11:0]),
				.q_a (colour_t)	// data out
				);
	defparam
		TileSet.WIDTH_A = BITS_PER_COLOUR * 3,
		TileSet.INTENDED_DEVICE_FAMILY = "Cyclone II",
		TileSet.OPERATION_MODE = "ROM",
		TileSet.WIDTHAD_A = 12,
		TileSet.NUMWORDS_A = 16 * 16 * 16,
		TileSet.CLOCK_ENABLE_INPUT_A = "BYPASS",
		TileSet.POWER_UP_UNINITIALIZED = "FALSE",
		TileSet.INIT_FILE = "tilesheet.mif";
	
	reg [3:0] Q, Qn;
	localparam S_RESET          = 4'b0000,
	           S_WAIT           = 4'b0001,
	           S_SELECT         = 4'b0010,
	           S_READ           = 4'b0011,
	           S_DRAW_BUFFER    = 4'b0100,
	           S_INCREMENT      = 4'b0101,
	           S_INCREMENT_HOLD = 4'b0110,
	           S_FINISH         = 4'b0111,
	           S_ENABLE_REFRESH = 4'b1000,
              S_DRAW           = 4'b1001;
	
	always @(*)
	begin
		case(Q)
			S_RESET: Qn = S_WAIT;
			S_WAIT: Qn = go ? S_SELECT : S_WAIT;
			/*begin
				if(refresh)
					Qn = S_ENABLE_REFRESH;
				else if(go)
					Qn = S_SELECT;
				else
					Qn = S_WAIT;
			end*/
			S_SELECT: Qn = S_READ;
			S_READ: Qn = S_DRAW; // refreshing ? S_DRAW : S_DRAW_BUFFER;
			//S_DRAW_BUFFER: Qn = S_INCREMENT;
			S_INCREMENT: Qn = S_INCREMENT_HOLD;
			S_INCREMENT_HOLD: Qn = |offset ? S_SELECT : S_FINISH;
			S_FINISH: Qn = S_RESET;
			//S_ENABLE_REFRESH: Qn = S_SELECT;
			S_DRAW: Qn = S_INCREMENT;
		endcase
	end
	
	always @(*)
	begin
		enable_count = 0;
		write_en = 0;
		//write_buffer = 0;
		finished = refresh; // Set to 0 if using buffer
		case(Q)
			S_DRAW: write_en = (colour != TRANSPARENT); // Change this if using buffer or changing colour bits
			S_INCREMENT: enable_count = 1;
			S_FINISH: finished = 1;
			// S_DRAW_BUFFER: write_buffer = (colour_b != TRANSPARENT); // Change this when changing bits per colour
		endcase
	end
	
	always @(posedge clk)
	begin
		case(Q)
			S_RESET:
			begin
				adr <= 0;
				// refreshing <= 0;
			end
			S_SELECT:
			begin
				if(memory_select == 2'b11) // Check refreshing if using buffer
					adr <= ({tile_select[3:2], offset_t[7:4]} * 64) + {tile_select[1:0], offset_t[3:0]};
				else
					adr <= (offset_y * WIDTH) + offset_x;
			end
			// S_ENABLE_REFRESH: refreshing <= 1;
		endcase
	end
	
	always @(posedge clk)
	begin
		if(reset_n)
			Q <= 4'b0000;
		else
			Q <= Qn;
	end
endmodule

module count8(clk, reset_n, enable, q);
	input clk, reset_n, enable;
	
	output reg [7:0] q;
	always @(posedge clk)
	begin
		if(reset_n)
			q <= 0;
		else if(enable)
			q <= q + 1;
	end
endmodule

module count_xy(clk, reset_n, enable, max_x, max_y, q_x, q_y);
	input clk, reset_n, enable;
	input [8:0] max_x;
	input [7:0] max_y;
	
	output reg [8:0] q_x;
	output reg [7:0] q_y;
	always @(posedge clk)
	begin
		if(reset_n)
		begin
			q_x <= 0;
			q_y <= 0;
		end
		else if(enable)
		begin
			if(q_x == max_x - 1)
			begin
				q_x <= 0;
				if(q_y == max_y - 1)
					q_y <= 0;
				else
					q_y <= q_y + 1;
			end
			else
				q_x <= q_x + 1;
		end
	end
endmodule

module count_hold(clk, reset_n, enable, q);
	input clk, reset_n, enable;
	output reg [2:0] q;
	
	localparam HOLD_TIME = 2; // HOLD_TIME = Write hold time / 2
	
	always @(posedge clk)
	begin
		if(reset_n)
			q <= 0;
		else if(enable)
		begin
			if(q == (HOLD_TIME - 1))
				q <= 0;
			else
				q <= q + 1;
		end
	end
endmodule
