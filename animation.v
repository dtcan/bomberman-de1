
// comments here

module animation 
	(
		CLOCK_50,
      KEY,
      SW,
		// The ports below are for the VGA output.
		VGA_CLK,   						//	VGA Clock
		VGA_HS,							//	VGA H_SYNC
		VGA_VS,							//	VGA V_SYNC
		VGA_BLANK_N,					//	VGA BLANK
		VGA_SYNC_N,						//	VGA SYNC
		VGA_R,   						//	VGA Red[9:0]
		VGA_G,	 						//	VGA Green[9:0]
		VGA_B   							//	VGA Blue[9:0]
	);

	input		CLOCK_50;				//	50 MHz
	input   	[9:7]   SW;
	input   	[2:0]   KEY;

	// Do not change the following outputs
	output			VGA_CLK;   				//	VGA Clock
	output			VGA_HS;					//	VGA H_SYNC
	output			VGA_VS;					//	VGA V_SYNC
	output			VGA_BLANK_N;			//	VGA BLANK
	output			VGA_SYNC_N;				//	VGA SYNC
	output	[9:0]	VGA_R;   				//	VGA Red[9:0]
	output	[9:0]	VGA_G;	 				//	VGA Green[9:0]
	output	[9:0]	VGA_B;   				//	VGA Blue[9:0]
	
	wire resetn;
	assign resetn = KEY[0];
	
	// Create the colour, x, y and writeEn wires that are inputs to the controller.
	wire [2:0] colour;
	wire [7:0] x;
	wire [6:0] y;
	wire ld_colour, draw_enable, erase_enable, update, wren, draw_complete;

	// Create an Instance of a VGA controller - there can be only one!
	// Define the number of colours as well as the initial background
	// image file (.MIF) for the controller.
//	vga_adapter VGA(
//			.resetn(resetn),
//			.clock(CLOCK_50),
//			.colour(colour),
//			.x(x),
//			.y(y),
//			.plot(writeEn),
//			/* Signals for the DAC to drive the monitor. */
//			.VGA_R(VGA_R),
//			.VGA_G(VGA_G),
//			.VGA_B(VGA_B),
//			.VGA_HS(VGA_HS),
//			.VGA_VS(VGA_VS),
//			.VGA_BLANK(VGA_BLANK_N),
//			.VGA_SYNC(VGA_SYNC_N),
//			.VGA_CLK(VGA_CLK));
//		defparam VGA.RESOLUTION = "160x120";
//		defparam VGA.MONOCHROME = "FALSE";
//		defparam VGA.BITS_PER_COLOUR_CHANNEL = 1;
//		defparam VGA.BACKGROUND_IMAGE = "black.mif";
			
	// Put your code here. Your code should produce signals x,y,colour and writeEn/plot
	// for the VGA controller, in addition to any other functionality your design may require.

	// Instansiate FSM control
   control c0(
		.ld_colour(ld_colour),
		.draw_enable(draw_enable),
		.erase_enable(erase_enable),
		.update(update),
		.wren(wren),
		.go({~KEY[2], ~KEY[1]}),
		.draw_complete(draw_complete),
		.clock(CLOCK_50),
		.resetn(resetn)
	);
	 
   // Instansiate datapath
	datapath d0(
		.x_out(x), 
		.y_out(y),
		.colour_out(colour),
		.draw_complete(draw_complete),
		.clock(CLOCK_50),
		.resetn(resetn),
		.colour_in(SW[9:7]),
		.ld_colour(ld_colour),
		.draw_enable(draw_enable),
		.erase_enable(erase_enable)		
	);

    
endmodule

// control module
module control(
	ld_colour,
	draw_enable,
	erase_enable,
	update,
	wren,
	go,
	draw_complete,
	clock,
	resetn
	);
	
	output ld_colour, draw_enable, erase_enable, update, wren;
	
	input [1:0] go;
	input draw_complete, clock, resetn;
	
	reg [2:0] current_state, next_state;
	reg ld_colour, draw_enable, erase_enable, update, wren, counter_reset, counter_enable;
	
	wire draw, clock_60Hz;
	
	delay_counter dc(
		.out(clock_60Hz),
		.clock(clock),
		.resetn(!counter_reset),
		.enable(counter_enable)
		);
	
	frame_counter fc(
		.out(draw),
		.clock(clock_60Hz),
		.resetn(!counter_reset),
		.enable(counter_enable)
		);
	
	// declare states
	localparam	S_IDLE 			= 3'd0,
					S_LOAD_COLOUR 	= 3'd1,
					S_WAIT_DRAW 	= 3'd2,
					S_DRAW	 		= 3'd3,
					S_WAIT_ERASE	= 3'd4,
					S_ERASE	 		= 3'd5,
					S_UPDATE			= 3'd6;

	// state table
	always @ (*)
		begin: state_table
			case (current_state)
				S_IDLE: 			next_state	= (go == 2'b01)	? S_LOAD_COLOUR : S_IDLE; 			// Loop in current state until KEY[1] is pressed.
				S_LOAD_COLOUR:	next_state	= (go == 2'b10) 	? S_WAIT_DRAW 	 : S_LOAD_COLOUR; // Loop in current state until KEY[2] is pressed.
				S_WAIT_DRAW: 	next_state 	= draw 				? S_DRAW 	    : S_WAIT_DRAW; 	// Loop in current state until draw signal is 1.
				S_DRAW: 			next_state	= draw_complete	? S_WAIT_ERASE  : S_DRAW; 			// Loop in current state until draw_complete signal is 1.
				S_WAIT_ERASE: 	next_state 	= draw 				? S_ERASE 		 : S_WAIT_ERASE;	// Loop in current state until draw signal is 1.
				S_ERASE: 		next_state	= draw_complete	? S_UPDATE		 : S_ERASE; 		// Loop in current state until draw_complete signal is 1.
				S_UPDATE: 		next_state 	= S_DRAW;
				default: next_state = S_IDLE;
			endcase
		end
		
	// datapath control signals
	always @ (*)
    begin: enable_signals
        // By default make all our signals 0.
        ld_colour = 1'b0;
        draw_enable = 1'b0;
		  erase_enable = 1'b0;
		  update = 1'b0;
		  wren = 1'b0;
		  counter_reset = 1'b0;
		  counter_enable = 1'b0;

        case (current_state)
            S_LOAD_COLOUR: 
					ld_colour = 1'b1;
            S_WAIT_DRAW:
					begin
						counter_reset = 1'b1;
						counter_enable = 1'b1;
					end					
				S_DRAW:
					begin
						draw_enable = 1'b1;
						wren = 1'b1;
					end
            S_WAIT_ERASE:
					begin
						counter_reset = 1'b1;
						counter_enable = 1'b1;
					end
				S_ERASE:
					begin
						erase_enable = 1'b1;
						wren = 1'b1;
					end
				S_UPDATE:
					update = 1'b1;
        endcase
    end
	 
	 // current_state registers
    always@(posedge clock)
    begin: state_FFs
        if(!resetn)
            current_state <= S_IDLE;
        else
            current_state <= next_state;
    end
	 

endmodule

// delay_counter module to convert 50MHz clock to 60Hz.
module delay_counter(out, clock, resetn, enable);
	
	output out;
	
	input clock, resetn, enable;
	
	reg [19:0] count;
	
	always @(posedge clock, negedge resetn)
		begin
			if (!resetn)
				count <= 0;
			// count to 833 333 - 1
			else if (enable)
				if (count == 19'd833332) 
					count <= 0;
				else
					count <= count + 1;
		end
		
	// sends high out signal ~60 times per second. 
	assign out = (count == 0)? 1 : 0;

endmodule

// counter module for 15 frames elapsed.
module frame_counter(out, clock, resetn, enable);
	
	output out;
	
	input clock, resetn, enable;
	
	reg [3:0] count;
	
	always @(posedge clock, negedge resetn)
		begin
			if (!resetn)
				begin
					count <= 0;
				end
			// count to 15 - 1
			else if (enable)
				if (count == 4'd14)
						count <= 0;
				else
						count <= count + 1;
		end
	
	// sends high out signal 1 time every 15 frames.
	assign out = (count == 0)? 1 : 0;

endmodule

// datapath module with counter to cycle and send all 16 pixel coordinates to vga_adapter.
module datapath(
	x_out, y_out,
	colour_out,
	draw_complete,
	clock,
	resetn,
	colour_in,
	ld_colour,
	draw_enable,
	erase_enable
	);
	
	output [7:0] x_out;
	output [6:0] y_out;
	output [2:0] colour_out;
	output draw_complete;
	
	input [2:0] colour_in;
	input clock, resetn, ld_colour, draw_enable, erase_enable;

	// input registers
	reg [7:0] X;
	reg [6:0] Y;
	reg [2:0] COLOUR;
	
	// direction registers
	reg dir_X, dir_Y; // for Y: 0 - Up, 1 - Down. for X: 0 - Left, 1 - Right.
	
	// output registers
	reg [7:0] x_out;
	reg [6:0] y_out;
	reg [2:0] colour_out;
	
	// counter output wire
	wire [7:0] wire_x;
	wire [6:0] wire_y;
	wire [3:0] count_out;
	
	counter_X cX(
		.x_out(wire_x),
		.clock(clock),
		.resetn(resetn),
		.enable(update),
		.dir(dir_X)
		);
		
	counter_Y cY(
		.y_out(wire_y),
		.clock(clock),
		.resetn(resetn),
		.enable(update),
		.dir(dir_Y)
		);
		
	// instantiate counter
	counter c(
		.out(count_out),
		.finished(draw_complete),
		.clock(clock),
		.resetn(resetn),
		.enable((draw_enable | erase_enable))
		);
	
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

// counter module for X coordinate.
module counter_X(x_out, clock, resetn, enable, dir);
	
	output [7:0] x_out;
	
	input clock, resetn, enable; 
	input dir; // horizontal direction, 0 for left and 1 for right.
	
	reg [7:0] x_out;
	
	always @ (posedge clock, negedge resetn)
		begin
			// reset to position 0.
			if (!resetn)
				begin
					x_out <= 0;
				end
			else if (enable)
				if (dir)
					x_out <= x_out + 1;
				else
					x_out <= x_out - 1;
		end
		
endmodule

// counter module for y coordinate.
module counter_Y(y_out, clock, resetn, enable, dir);
	
	output [6:0] y_out;
	
	input clock, resetn, enable; 
	input dir; // vertical direction, 0 for up and 1 for down.
	
	reg [6:0] y_out;
	
	always @ (posedge clock, negedge resetn)
		begin
			// reset to position 60.
			if (!resetn)
				begin
					y_out <= 7'd60;
				end
			else if (enable)
				if (!dir)
					y_out <= y_out + 1;
				else
					y_out <= y_out - 1;
		end
		
endmodule		

// counter module for datapath.
module counter(out, finished, clock, resetn, enable);
	
	output [3:0] out;
	output finished;
	
	input clock, resetn, enable;
	
	reg [3:0] out;
	
	always @ (posedge clock, negedge resetn)
		begin
			if (!resetn)
				begin
					out <= 0;
				end
			// count to 16 if enable.
			else if (enable)
				if (out == 4'd15)
					begin
						out <= 0;
					end
				else
					out <= out + 1;
		end
		
		assign finished = (out == 4'd15) ? 1 : 0;
	
endmodule

