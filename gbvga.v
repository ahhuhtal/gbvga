module gbvga(
	input clk,
	output vsync,
	output hsync,
	output[1:0] r,
	output[1:0] g,
	output[1:0] b,
	input[1:0] idata,
	input ihsync,
	input ivsync,
	input iclk);

	wire pllclk;
	
	pll pll_inst(
		.inclk0(clk),
		.c0(pllclk)
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
	
	// params for 640x576 following 800x600 timings
	localparam h_vis = 640;
	localparam h_fp = 120;
	localparam h_sync = 128;
	localparam h_bp = 168;

	localparam v_vis = 576;
	localparam v_fp = 13;
	localparam v_sync = 4;
	localparam v_bp = 35;

	// horiz. counter at time k
	reg[10:0] hcounter_k0;
	// vert. counter at time k
	reg[9:0] vcounter_k0;
	// output pixel address at time k
	wire[14:0] opixel_k0;
	// output pixel visiblity at time k
	wire visible_k0;
	// horiz. sync signal at time k
	wire hsync_k0;
	// vert. sync signal at time k
	wire vert_k0;
	
	// output pixel data at time k-1
	wire[1:0] data_k1;
	// output pixel visiblity at time k-1
	reg visible_k1;
	// horiz. sync signal at time k-1
	reg hsync_k1;
	// vert. sync signal at time k-1
	reg vsync_k1;
	
	// output pixel data at time k-2
	reg[1:0] data_k2;
	// output pixel visiblity at time k-2
	reg visible_k2;
	// horiz. sync signal at time k-2
	reg hsync_k2;
	// vert. sync signal at time k-2
	reg vsync_k2;
	
	// memory for detecting edges
	reg iclk_state;
	reg iclk_prev1;
	reg iclk_prev2;

	reg ivsync_state;
	reg ivsync_prev1;
	reg ivsync_prev2;

	reg[14:0] ipixel;
	
	reg[14:0] ipixel_latched;
	reg[1:0] idata_latched;
	reg iwrite_latched;
	
	framebuffer framebuffer_inst(
		.clock(pllclk),

		.rdaddress(opixel_k0),
		.q(data_k1),

		.wraddress(ipixel_latched),
		.data(idata_latched),
		.wren(iwrite_latched)
	);
	
	always @(posedge pllclk) begin
		// output handler
		if(hcounter_k0 < h_vis + h_fp + h_sync + h_bp - 1) begin
			hcounter_k0 <= hcounter_k0+1;
		end else begin
			hcounter_k0 <= 0;
			
			if(vcounter_k0 < v_vis + v_fp + v_sync + v_bp - 1) begin
				vcounter_k0 <= vcounter_k0+1;
			end else begin
				vcounter_k0 <= 0;
			end
		end

		visible_k1 <= visible_k0;
		vsync_k1 <= vsync_k0;
		hsync_k1 <= hsync_k0;
		
		data_k2 <= data_k1;
		visible_k2 <= visible_k1;
		vsync_k2 <= vsync_k1;
		hsync_k2 <= hsync_k1;
		
		// input handler

		// reset write latch
		iwrite_latched <= 0;
		
		// if clock has been high for a while, change the clock state high
		if(iclk_prev2 && iclk_prev1 && iclk && !iclk_state) begin
			iclk_state <= 1;
		end

		// if the clock has been low for a while, change the clock state low
		if(!iclk_prev2 && !iclk_prev1 && !iclk && iclk_state) begin
			iclk_state <= 0;

			ipixel <= ipixel+1;
			ipixel_latched <= ipixel;
			idata_latched <= idata;
			iwrite_latched <= 1;
		end
		
		// if vsync has been high for a while, change the vsync state high
		if(ivsync_prev2 && ivsync_prev1 && ivsync && !ivsync_state) begin
			ivsync_state <= 1;

			ipixel <= 0;
		end

		// if vsync has been low for a while, change the vsync state low
		if(!ivsync_prev2 && !ivsync_prev1 && !ivsync && ivsync_state) begin
			ivsync_state <= 0;
		end

		iclk_prev2 <= iclk_prev1;
		iclk_prev1 <= iclk;
		ivsync_prev2 <= ivsync_prev1;
		ivsync_prev1 <= ivsync;
	end
	
	assign visible_k0 = hcounter_k0 < h_vis && vcounter_k0 < v_vis;
	assign opixel_k0[14:0] = visible_k0*(vcounter_k0[9:2]*160 + hcounter_k0[10:2]);
	
	assign hsync_k0 = (hcounter_k0 >= h_vis + h_fp && hcounter_k0 < h_vis + h_fp + h_sync);
	assign vsync_k0 = (vcounter_k0 >= v_vis + v_fp && vcounter_k0 < v_vis + v_fp + v_sync);

	assign hsync = hsync_k2;
	assign vsync = vsync_k2;
	assign r[1:0] = {(~data_k2[1]) & visible_k2, (~data_k2[0]) & visible_k2 };
	assign g[1:0] = {(~data_k2[1]) & visible_k2, (~data_k2[0]) & visible_k2 };
	assign b[1:0] = {(~data_k2[1]) & visible_k2, (~data_k2[0]) & visible_k2 };
endmodule
