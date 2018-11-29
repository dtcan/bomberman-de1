module copy(clk, reset_n, go, refresh, X, Y, memory_select, tile_select, X_out, Y_out, colour, write_en, finished);
	input clk, reset_n, go, refresh;
	input [8:0] X;
	input [7:0] Y;
	input [1:0] memory_select;
	input [3:0] tile_select;
	output [8:0] X_out;
	output [7:0] Y_out;
	output [5:0] colour;
	output reg write_en, finished;
	
	localparam WIDTH = 320, HEIGHT = 240; // Still have to go change bit-widths when changing these!
	localparam BITS_PER_COLOUR = 2;       // When changing, also change colour reg and wire widths
	
	reg [5:0] buffer [0:(WIDTH * HEIGHT) - 1];
	reg [5:0] colour_b;
	wire [5:0] colour_1, colour_2, colour_3, colour_t;
	wire [8:0] offset_x;
	wire [7:0] offset_y;
	wire [7:0] offset_t;
	reg [16:0] offset;
	reg enable_count;
	reg [16:0] adr;
	reg refreshing;
	
	assign X_out = offset_x;
	assign Y_out = offset_y;
	assign colour = buffer[(Y_out * WIDTH) + X_out];
	
	count8 c0(
		.clk(clk),
		.reset_n(reset_n),
		.enable(enable_count & (memory_select == 2'b11)),
		.q(offset_t)
	);
	
	count_xy c1(
		.clk(clk),
		.reset_n(reset_n),
		.enable(enable_count & ((memory_select != 2'b11) | refreshing)),
		.max_x(WIDTH),
		.max_y(HEIGHT),
		.q_x(offset_x),
		.q_y(offset_y)
	);
	
	always @(*)
	begin
		case(memory_select)
			2'b00: colour_b = colour_1;
			2'b01: colour_b = colour_2;
			2'b10: colour_b = colour_3;
			2'b11: colour_b = colour_t;
		endcase
		
		if((memory_select == 2'b11) & ~refreshing)
			offset = {4'd0, offset_t[7:4], 5'd0, offset_t[3:0]};
		else
			offset = {offset_y, offset_x};
	end
	
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
			S_WAIT:
			begin
				if(refresh)
					Qn = S_ENABLE_REFRESH;
				else if(go)
					Qn = S_SELECT;
				else
					Qn = S_WAIT;
			end
			S_SELECT: Qn = S_READ;
			S_READ: Qn = refreshing ? S_DRAW : S_DRAW_BUFFER;
			S_DRAW_BUFFER: Qn = S_INCREMENT;
			S_INCREMENT: Qn = S_INCREMENT_HOLD;
			S_INCREMENT_HOLD: Qn = |offset ? S_SELECT : S_FINISH;
			S_FINISH: Qn = S_RESET;
			S_ENABLE_REFRESH: Qn = S_SELECT;
			S_DRAW: Qn = S_INCREMENT;
		endcase
	end
	
	always @(*)
	begin
		enable_count = 0;
		write_en = 0;
		finished = 0;
		case(Q)
			S_DRAW: write_en = 1;
			S_INCREMENT: enable_count = 1;
			S_FINISH: finished = 1;
		endcase
	end
	
	always @(posedge clk)
	begin
		case(Q)
			S_RESET:
			begin
				adr <= 0;
				refreshing <= 0;
			end
			S_SELECT:
			begin
				if(memory_select == 2'b11)
					adr <= ({tile_select[3:2], offset_t[7:4]} * 64) + {tile_select[1:0], offset_t[3:0]};
				else
					adr <= (offset_y * WIDTH) + offset_x;
			end
			S_DRAW_BUFFER:
			begin
				if(colour != 6'b001100) // !!!!! Change when changing colour width
					buffer[((Y + offset[16:9]) * WIDTH) + X + offset[8:0]] <= colour_b;
			end
			S_ENABLE_REFRESH: refreshing <= 1;
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

