module gbvga(
	input clk,
	output vsync,
	output hsync,
	output reg[1:0] r,
	output reg[1:0] g,
	output reg[1:0] b,
	input[1:0] idata,
	input ihsync,
	input ivsync,
	input iclk);

	// clock output from the PLL
	wire pllclk;
	
	// instantiate the PLL to generate
	// a 40 MHz output clock: pllclk
	// from a
	// 50 MHz input clock: clk

	pll pll_inst(
		.inclk0(clk),
		.c0(pllclk)
	);
	
	// VGA output variables
	
	// params for 640x576 following 800x600 timings @ 40 MHz
	localparam h_vis = 640; // visible area horizontal pixels
	localparam h_fp = 120; // horizontal front porch pixels
	localparam h_sync = 128; // horizontal sync active pixels
	localparam h_bp = 168; // horizontal back porch pixels

	localparam v_vis = 576; // visible area vertical pixels
	localparam v_fp = 13; // vertical front porch pixels
	localparam v_sync = 4; // vertical sync active pixels
	localparam v_bp = 35; // vertical back porch pixels


	// VGA output after next pixel
	
	// horiz. counter
	reg[10:0] hcounter_next2;
	// vert. counter
	reg[9:0] vcounter_next2;
	// output pixel address computed from hcounter and vcounter
	wire[14:0] opixel_next2;
	// output pixel visiblity
	wire visible_next2;
	// horiz. sync signal
	wire hsync_next2;
	// vert. sync signal
	wire vsync_next2;
	

	// VGA output for next pixel

	// output pixel data
	wire[3:0] data_next1;
	// output pixel visiblity
	reg visible_next1;
	// horiz. sync signal
	reg hsync_next1;
	// vert. sync signal
	reg vsync_next1;
	

	// VGA output for right now
	
	// output pixel data
	reg[3:0] data_now;
	// output pixel visiblity
	reg visible_now;
	// horiz. sync signal
	reg hsync_now;
	// vert. sync signal
	reg vsync_now;
	
	// how many VGA frames (vsync) without GB data to blank display
	localparam framesmissing_to_blank = 2;

	// flag to blank screen due to GB data missing
	reg blank;

	// how many VGA frames have been output without GB input
	reg[1:0] framesmissing;

	// GB data decoding variables

	// memory for filtered edge detection
	reg iclk_state; // current internal input clock signal state
	reg iclk_prev1; // input clock signal 1 master clock cycle ago
	reg iclk_prev2; // input clock signal 2 master clock cycles ago
	reg iclk_prev3; // input clock signal 3 master clock cycles ago
	// iclk_state is changed, when current iclk and prev1-3 all agree.
	
	reg ivsync_state; // current internal input vsync signal state
	reg ivsync_prev1; // input vsync signal 1 master clock cycle ago
	reg ivsync_prev2; // input vsync signal 2 master clock cycles ago
	reg ivsync_prev3; // input vsync signal 3 master clock cycles ago
	// ivsync_state is changed, when current ivsync and prev1-3 all agree
	
	reg ihsync_state; // current internal input hsync signal state
	reg ihsync_prev1; // input hsync signal 1 master clock cycle ago
	reg ihsync_prev2; // input hsync signal 2 master clock cycles ago
	reg ihsync_prev3; // input hsync signal 3 master clock cycles ago
	// ihsync_state is changed, when current ihsync and prev1-3 all agree
	
	// memory for synchronizing data to a moment before edge detect
	reg[1:0] idata_prev1; // input data 1 master clock cycle ago
	reg[1:0] idata_prev2; // input data 2 master clock cycles ago
	reg[1:0] idata_prev3; // input data 3 master clock cycles ago
	reg[1:0] idata_prev4; // input data 4 master clock cycles ago
	reg[1:0] idata_prev5; // input data 5 master clock cycles ago
	// when the ihsync state goes from high to low,
	// the input data is sampled from 5 master clock cycles in the past
	// this is because there is a very short period of time between
	// hsync negative edge and the setup of new data on the data lines
	
	// pixel counter for the next pixel in line to be decoded
	reg[14:0] ipixel;
	
	// when pixel data is to be written to memory
	// these variables contain the address and value for duration of the write cycle
	reg[14:0] ipixel_latched;
	reg[1:0] idata_latched;
	wire[3:0] idata_oldstate;
	reg[3:0] idata_newstate;
	
	reg iwrite_enabled;
	
	reg[1:0] iwrite_state;
	

	// 2-port RAM instantiation for framebuffer

	framebuffer framebuffer_inst (
		.clock(pllclk), // a single clock is used for both ports
		.address_a(opixel_next2), // port A used by VGA output
        .data_a(4'b1111), // write white data if display is blanked
		.wren_a(blank), // VGA output does not write
		.q_a(data_next1), // VGA output data

		.address_b(ipixel_latched),
		.data_b(idata_newstate),
		.wren_b(iwrite_enabled),
		.q_b(idata_oldstate)
	);
		
	always @(posedge pllclk) begin
		// VGA signal generation
		
		if(hcounter_next2 < h_vis + h_fp + h_sync + h_bp - 1) begin
			// the increment doesn't overflow horizontal pixel count
			
			hcounter_next2 <= hcounter_next2+1'd1; // increment the horizontal pixel position
		end else begin
			// the increment would overflow pixel count
			hcounter_next2 <= 0; // reset horizontal pixel position
			
			if(vcounter_next2 < v_vis + v_fp + v_sync + v_bp - 1) begin
				// the increment doesn't overflow vertical pixel count

				vcounter_next2 <= vcounter_next2+1'd1; // increment the vertical pixel position
			end else begin
				// the increment would overflow pixel count
				vcounter_next2 <= 0; // reset vertical pixel position

				// there have been framesmissing_to_blank frames without GB data
				// and blank has not been set
				if(blank == 0 && framesmissing >= framesmissing_to_blank) begin
					blank <= 1;
				end

				framesmissing <= framesmissing + 2'd1;
			end
		end

		// shift data marked for 2 clock cycles in the future
		// to one clock cycle in the future
		visible_next1 <= visible_next2;
		vsync_next1 <= vsync_next2;
		hsync_next1 <= hsync_next2;
		
		// shift data marked for 1 clock cycle in the future
		// to right now
		data_now <= data_next1;
		visible_now <= visible_next1;
		vsync_now <= vsync_next1;
		hsync_now <= hsync_next1;



		// GB input decoder

		case(iwrite_state)
			0: begin // no update cycle was ongoing
				iwrite_state <= 0;
				iwrite_enabled <= 0;
			end

			1: begin // old pixel data read, write data on next clock pulse
				iwrite_state <= 2;
				iwrite_enabled <= 1;
			end
			
			2: begin // data was written
				iwrite_state <= 0;
				iwrite_enabled <= 0;
			end
						
			default: begin
				iwrite_state <= 0;
				iwrite_enabled <= 0;
			end
		endcase
		
		// input clock filtering and handling

		// if clock has been high for a while, change the clock state high
		if(iclk_prev3 && iclk_prev2 && iclk_prev1 && iclk && !iclk_state) begin
			iclk_state <= 1;
		end

		// if the clock has been low for a while, change the clock state low
		if(!iclk_prev3 && !iclk_prev2 && !iclk_prev1 && !iclk && iclk_state) begin
			iclk_state <= 0;

			// also, if the hsync is low, sample the data lines and store to memory
			if(ihsync_state == 0) begin
				ipixel <= ipixel+1'd1; // increment pixel count
				
				// store the current pixel address as write address
				// take data from a few clock cycles ago
				// initiate write
				ipixel_latched <= ipixel;
				idata_latched <= ~idata_prev5;
				iwrite_state <= 1;
			end
		end


		// input hsync filtering and handling

		// if hsync has been high for a while, change the hsync state high
		if(ihsync_prev3 && ihsync_prev2 && ihsync_prev1 && ihsync && !ihsync_state) begin
			ihsync_state <= 1;
		end

		// if hsync has been low for a while, change the hsync state low
		if(!ihsync_prev3 && !ihsync_prev2 && !ihsync_prev1 && !ihsync && ihsync_state) begin
			ihsync_state <= 0;

			ipixel <= ipixel+1'd1; // increment pixel count

			// store the current pixel address
			// take data from a few clock cycles ago
			// initiate write
			ipixel_latched <= ipixel;
			idata_latched <= ~idata_prev5;
			iwrite_state <= 1;
		end


		// input vsync filtering and handling

		// if vsync has been high for a while, change the vsync state high
		if(ivsync_prev3 && ivsync_prev2 && ivsync_prev1 && ivsync && !ivsync_state) begin
			ivsync_state <= 1;

			// rising edge of vsync signals a start of a new frame
			ipixel <= 0;

			// clear blank flag and data missing counter
			blank <= 0;
			framesmissing <= 0;
		end

		// if vsync has been low for a while, change the vsync state low
		if(!ivsync_prev3 && !ivsync_prev2 && !ivsync_prev1 && !ivsync && ivsync_state) begin
			ivsync_state <= 0;
		end

		// shift current data to data from previous clock cycle
		iclk_prev1 <= iclk;
		ivsync_prev1 <= ivsync;
		ihsync_prev1 <= ihsync;
		idata_prev1 <= idata;

		// shift previous clock cycle data to data from 2 clock cycles ago
		iclk_prev2 <= iclk_prev1;
		ivsync_prev2 <= ivsync_prev1;
		ihsync_prev2 <= ihsync_prev1;
		idata_prev2 <= idata_prev1;

		// shift data from 2 clock cycles ago to data from 3 clock cycles ago
		iclk_prev3 <= iclk_prev2;
		ivsync_prev3 <= ivsync_prev2;
		ihsync_prev3 <= ihsync_prev2;
		idata_prev3 <= idata_prev2;

		// shift data from 3 clock cycles ago to data from 4 clock cycles ago
		idata_prev4 <= idata_prev3;

		// shift data from 4 clock cycles ago to data from 5 clock cycles ago
		idata_prev5 <= idata_prev4;
	end
	
   // compute motion blur
	always @* begin
		case({idata_oldstate, idata_latched})
			6'b000000: idata_newstate <= 4'b0000;
			6'b000001: idata_newstate <= 4'b0010;
			6'b000010: idata_newstate <= 4'b0011;
			6'b000011: idata_newstate <= 4'b0101;
			6'b000100: idata_newstate <= 4'b0000;
			6'b000101: idata_newstate <= 4'b0010;
			6'b000110: idata_newstate <= 4'b0100;
			6'b000111: idata_newstate <= 4'b0110;
			6'b001000: idata_newstate <= 4'b0001;
			6'b001001: idata_newstate <= 4'b0011;
			6'b001010: idata_newstate <= 4'b0101;
			6'b001011: idata_newstate <= 4'b0110;
			6'b001100: idata_newstate <= 4'b0010;
			6'b001101: idata_newstate <= 4'b0100;
			6'b001110: idata_newstate <= 4'b0101;
			6'b001111: idata_newstate <= 4'b0111;
			6'b010000: idata_newstate <= 4'b0011;
			6'b010001: idata_newstate <= 4'b0101;
			6'b010010: idata_newstate <= 4'b0110;
			6'b010011: idata_newstate <= 4'b1000;
			6'b010100: idata_newstate <= 4'b0011;
			6'b010101: idata_newstate <= 4'b0101;
			6'b010110: idata_newstate <= 4'b0111;
			6'b010111: idata_newstate <= 4'b1000;
			6'b011000: idata_newstate <= 4'b0100;
			6'b011001: idata_newstate <= 4'b0101;
			6'b011010: idata_newstate <= 4'b0111;
			6'b011011: idata_newstate <= 4'b1001;
			6'b011100: idata_newstate <= 4'b0101;
			6'b011101: idata_newstate <= 4'b0110;
			6'b011110: idata_newstate <= 4'b1000;
			6'b011111: idata_newstate <= 4'b1010;
			6'b100000: idata_newstate <= 4'b0101;
			6'b100001: idata_newstate <= 4'b0111;
			6'b100010: idata_newstate <= 4'b1001;
			6'b100011: idata_newstate <= 4'b1010;
			6'b100100: idata_newstate <= 4'b0110;
			6'b100101: idata_newstate <= 4'b1000;
			6'b100110: idata_newstate <= 4'b1010;
			6'b100111: idata_newstate <= 4'b1011;
			6'b101000: idata_newstate <= 4'b0111;
			6'b101001: idata_newstate <= 4'b1000;
			6'b101010: idata_newstate <= 4'b1010;
			6'b101011: idata_newstate <= 4'b1100;
			6'b101100: idata_newstate <= 4'b0111;
			6'b101101: idata_newstate <= 4'b1001;
			6'b101110: idata_newstate <= 4'b1010;
			6'b101111: idata_newstate <= 4'b1100;
			6'b110000: idata_newstate <= 4'b1000;
			6'b110001: idata_newstate <= 4'b1010;
			6'b110010: idata_newstate <= 4'b1011;
			6'b110011: idata_newstate <= 4'b1101;
			6'b110100: idata_newstate <= 4'b1001;
			6'b110101: idata_newstate <= 4'b1010;
			6'b110110: idata_newstate <= 4'b1100;
			6'b110111: idata_newstate <= 4'b1110;
			6'b111000: idata_newstate <= 4'b1001;
			6'b111001: idata_newstate <= 4'b1011;
			6'b111010: idata_newstate <= 4'b1101;
			6'b111011: idata_newstate <= 4'b1111;
			6'b111100: idata_newstate <= 4'b1010;
			6'b111101: idata_newstate <= 4'b1100;
			6'b111110: idata_newstate <= 4'b1101;
			6'b111111: idata_newstate <= 4'b1111;
		endcase
	end
			
	// assign output
	
	// compute the visibility signal for the pixel after 2 clock cycles
	assign visible_next2 = hcounter_next2 < h_vis && vcounter_next2 < v_vis;

	// compute the address in framebuffer for the pixel after 2 clock cycles
	// if pixel is not visible, default to address 0
	// otherwise address = vcount/4 * 160 + hcount/4
	assign opixel_next2[14:0] = visible_next2*(vcounter_next2[9:2]*8'd160 + hcounter_next2[10:2]);
	
	// compute hsync and vsync signals for the pixel after 2 clock cycles
	// polarity is positive for the svga 800x600
	assign hsync_next2 = (hcounter_next2 >= h_vis + h_fp && hcounter_next2 < h_vis + h_fp + h_sync);
	assign vsync_next2 = (vcounter_next2 >= v_vis + v_fp && vcounter_next2 < v_vis + v_fp + v_sync);

	// connect the hsync and vsync outputs to the corresponding register
	assign hsync = hsync_now;
	assign vsync = vsync_now;
	
	// assign actual output pixel data

	always @* begin
		if(visible_now) begin
			// VGA output is not in blanking. Output data.

			// There is valid GB data. Display framebuffer contents
			case(data_now)
				0: begin
					r <= 2'b00;
					g <= 2'b00;
					b <= 2'b00;
				end
				1: begin
					r <= 2'b00;
					g <= 2'b00;
					b <= 2'b00;
				end

				2: begin
					r <= 2'b00;
					g <= 2'b00;
					b <= 2'b01;
				end
				3: begin
					r <= 2'b00;
					g <= 2'b00;
					b <= 2'b01;
				end

				4: begin
					r <= 2'b00;
					g <= 2'b00;
					b <= 2'b10;
				end
				5: begin
					r <= 2'b00;
					g <= 2'b00;
					b <= 2'b10;
				end
				
				6: begin
					r <= 2'b00;
					g <= 2'b00;
					b <= 2'b11;
				end
				7: begin
					r <= 2'b00;
					g <= 2'b00;
					b <= 2'b11;
				end
				
				8: begin
					r <= 2'b00;
					g <= 2'b01;
					b <= 2'b11;
				end
				9: begin
					r <= 2'b00;
					g <= 2'b01;
					b <= 2'b11;
				end

				10: begin
					r <= 2'b00;
					g <= 2'b10;
					b <= 2'b11;
				end
				11: begin
					r <= 2'b00;
					g <= 2'b10;
					b <= 2'b11;
				end

				12: begin
					r <= 2'b00;
					g <= 2'b11;
					b <= 2'b11;
				end
				13: begin
					r <= 2'b00;
					g <= 2'b11;
					b <= 2'b11;
				end
				
				14: begin
					r <= 2'b01;
					g <= 2'b11;
					b <= 2'b11;
				end
				15: begin
					r <= 2'b01;
					g <= 2'b11;
					b <= 2'b11;
				end
			endcase
		end else begin
			// VGA output is in blanking. Display black.
			r <= 2'b00;
			g <= 2'b00;
			b <= 2'b00;
		end
	end
endmodule
