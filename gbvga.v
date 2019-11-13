module gbvga(
	input clk,
	output pllclk_out,
	output vsync,
	output hsync,
	output[1:0] r,
	output[1:0] g,
	output[1:0] b,
	output[7:0] segment,
	output[3:0] digit);

	wire pllclk;
	wire locked;
	
	assign digit = 4'b0111;
	assign segment = {~locked, 7'b1111111};
	
	assign pllclk_out = pllclk;
	
	pll pll_inst(
		.inclk0(clk),
		.c0(pllclk),
		.locked(locked)
	);
	
	// regular 800x600 timings
	// localparam h_vis = 800;
	// localparam h_fp = 40;
	// localparam h_sync = 128;
	// localparam h_bp = 88;
	// localparam v_vis = 600;
	// localparam v_fp = 1;
	// localparam v_sync = 4;
	// localparam v_bp = 23;
	
	localparam h_vis = 640;
	localparam h_fp = 120;
	localparam h_sync = 128;
	localparam h_bp = 168;

	localparam v_vis = 576;
	localparam v_fp = 13;
	localparam v_sync = 4;
	localparam v_bp = 35;

	reg[10:0] h_counter;
	reg[9:0] v_counter;	
	
	always @(posedge pllclk)
	begin
		if(h_counter < h_vis + h_fp + h_sync + h_bp - 1)
		begin
			h_counter <= h_counter+1;
		end
		else
		begin
			h_counter <= 0;
			
			if(v_counter < v_vis + v_fp + v_sync + v_bp - 1)
			begin
				v_counter <= v_counter+1;
			end
			else
			begin
				v_counter <= 0;
			end
		end
	end
	
	assign hsync = (h_counter >= h_vis + h_fp && h_counter < h_vis + h_fp + h_sync);
	assign vsync = (v_counter >= v_vis + v_fp && v_counter < v_vis + v_fp + v_sync);
endmodule
