
// module containing the control for bomberman.v

module bomberman_control(
	output [1:0] memory_select,
	output reset_stage,
	
	input go, finished, draw_complete, draw, game_over,
	input clock,
	input reset
	);
	
	delay_counter dc(
		.out(clock_60Hz),
		.clock(clock),
		.resetn(!counter_reset),
		.enable(counter_enable)
		);
	
	// how often to redraw objects (for now moving sprites at 4 pixels/ second)
	frame_counter fc(
		.out(draw),
		.clock(clock_60Hz),
		.resetn(!counter_reset),
		.enable(counter_enable)
		);
	
	// declare states
	localparam	IDLE 					= 3'd0,
					// states for drawing game stage
					LOAD_STAGE 			= 3'd1,
					STAGE_DRAW			= 3'd2,
					STAGE_IDLE			= 3'd3,
					STAGE_ERASE			= 3'd4,
					STAGE_UPDATE		= 3'd5,
					//
					LOAD_WIN_SCREEN	= 3'd6,
					WIN_SCREEN			= 3'd7;

	// state table
	always @ (*)
		begin: state_table
			case (current_state)
				IDLE: 				next_state = go 				? LOAD_STAGE 		: IDLE;				// loop in IDLE until go is 1.
				LOAD_STAGE: 		next_state = finished 		? GAME				: LOAD_STAGE;		// loop in LOAD_STAGE until finished is 1.
				STAGE_DRAW:			next_state = draw_complete	? STAGE_IDLE		: STAGE_DRAW;		// loop in STAGE_DRAW until draw_complete is 1.
				STAGE_IDLE:			next_state = draw				? STAGE_ERASE		: STAGE_IDLE;		// loop in STAGE_IDLE until draw is 1.
				STAGE_ERASE:		next_state = draw_complete	? STAGE_UPDATE		: STAGE_ERASE;		// loop in STAGE_ERASE until draw_complete is 1.
				STAGE_UPDATE:		next_state = game_over		? LOAD_WIN_SCREEN	: STAGE_DRAW;		// loop back to STAGE_DRAW until game_over is 1.
				LOAD_WIN_SCREEN:  next_state = finished		? WIN_SCREEN		: LOAD_WIN_SCREEN;// loop in LOAD_WIN_SCREEN until finished is 1.
				WIN_SCREEN:			next_state = go				? IDLE				: WIN_SCREEN;		// loop in WIN_SCREEN until go is 1.
				default: next_state = IDLE;
			endcase
		end
		
	// datapath control signals
	always @ (*)
    begin: enable_signals
        // default signals
		memory_select = 2'd3;
		reset_stage = 0;

		case (current_state)
			IDLE: 				// draw title screen and wait for user input to start playing.
				begin
					memory_select = 2d'0;
				end
			LOAD_STAGE: 		// draw game stage background.
				begin
					memory_select = 2d'1;
					reset_stage = 1;
				end
			STAGE_DRAW:			// draw game stage.
				begin
				end
			STAGE_IDLE:			// wait for delay.
				begin
				end
			STAGE_ERASE:		// erase game stage.
				begin
				end
			STAGE_UPDATE:		// update game stage.
				begin
				end
			LOAD_WIN_SCREEN:	// draw game over screen.
				begin
					memory_select = 2d'2;
				end
			WIN_SCREEN:			// 
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
module delay_counter(clock_60Hz, clock, resetn, enable);
	
	output clock_60Hz;
	
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
	assign clock_60Hz = (count == 0)? 1 : 0;

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
