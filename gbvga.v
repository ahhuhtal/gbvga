module gbvga(
	input clk,
	output pllclk_out,
	output vsync,
	output hsync,
	output[1:0] r,
	output[1:0] g,
	output[1:0] b,
	input[1:0] di,
	input hsynci,
	input vsynci,
	input clki,
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
	
	reg clki_prev;
	reg vsynci_prev;
	reg hsynci_prev;
	reg[14:0] pixel_i;
	
	framebuffer framebuffer_inst(
		.rdaddress(opixel_k0),
		.wraddress(pixel_i),
		.clock(pllclk),
		.q(data_k1)
	);
	
	always @(posedge pllclk) begin
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
		
		if(vsynci && ~vsynci_prev) begin
			pixel_i <= 0;
		end else begin
			if(clki && ~clki_prev) begin
				pixel_i <= pixel_i+1;
			end
		end
		
		clki_prev <= clki;
		vsynci_prev <= vsynci;
		hsynci_prev <= hsynci;
	end
	
	assign visible_k0 = hcounter_k0 < h_vis && vcounter_k0 < v_vis;
	assign opixel_k0[14:0] = visible_k0*(vcounter_k0[9:2]*160 + hcounter_k0[10:2]);
	
	assign hsync_k0 = (hcounter_k0 >= h_vis + h_fp && hcounter_k0 < h_vis + h_fp + h_sync);
	assign vsync_k0 = (vcounter_k0 >= v_vis + v_fp && vcounter_k0 < v_vis + v_fp + v_sync);

	assign hsync = hsync_k2;
	assign vsync = vsync_k2;
	assign r[1:0] = {data_k2[1] & visible_k2, data_k2[0] & visible_k2 };
	assign g[1:0] = {data_k2[1] & visible_k2, data_k2[0] & visible_k2 };
	assign b[1:0] = {data_k2[1] & visible_k2, data_k2[0] & visible_k2 };
endmodule
