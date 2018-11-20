module copy(clk, reset_n, go, memory_select, tile_select, colour, offset, write_en, finished);
	input clk, reset_n, go;
	input [1:0] memory_select;
	input [4:0] tile_select;
	output write_en, finished;
	output [14:0] colour;
	output [9:0] offset;
	
	wire [14:0] colour_1, colour_2, colour_3, colour_t;
	reg [18:0] adr;
	wire [14:0] dummy;
	wire clock_25

	divider d0(
		.clk(clk),
		.reset_n(reset_n),
		.clock_div(clock_25)
	);

	reg [3:0] Q, Qn;
	localparam S_RESET     = 3'b000,
	           S_WAIT      = 3'b001,
	           S_SELECT    = 3'b010,
	           S_READ      = 3'b011,
	           S_DRAW      = 3'b100,
	           S_INCREMENT = 3'b101;
	
	altsyncram	VideoMemory (
				.wren_a (1'b0),
				.wren_b (1'b0),
				.clock0 (1'b0), // write clock
				.clock1 (clock_25), // read clock
				.clocken0 (1'b0), // write enable clock
				.clocken1 (1'b1), // read enable clock				
				.address_a (adr),
				.address_b (dummy),
				.data_a (dummy), // data in
				.q_b (colour_1)	// data out
				);
	defparam
		VideoMemory.WIDTH_A = 5*3,
		VideoMemory.WIDTH_B = 5*3,
		VideoMemory.INTENDED_DEVICE_FAMILY = "Cyclone II",
		VideoMemory.OPERATION_MODE = "DUAL_PORT",
		VideoMemory.WIDTHAD_A = 19,
		VideoMemory.NUMWORDS_A = 307200,
		VideoMemory.WIDTHAD_B = 19,
		VideoMemory.NUMWORDS_B = 307200,
		VideoMemory.OUTDATA_REG_B = "CLOCK1",
		VideoMemory.ADDRESS_REG_B = "CLOCK1",
		VideoMemory.CLOCK_ENABLE_INPUT_A = "BYPASS",
		VideoMemory.CLOCK_ENABLE_INPUT_B = "BYPASS",
		VideoMemory.CLOCK_ENABLE_OUTPUT_B = "BYPASS",
		VideoMemory.POWER_UP_UNINITIALIZED = "FALSE",
		VideoMemory.INIT_FILE = "title.mif";
endmodule

module divider(clk, reset_n, clock_div);
	input clk, reset_n;
	output clock_div;
	
	reg q;
	always @(posedge clk)
	begin
		if(reset_n)
			q <= 0;
		else
			q <= q + 1;
	end

	assign clock_div = q;
endmodule
