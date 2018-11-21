module bomberman_datapath();

	
	
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
