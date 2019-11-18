module gbvga(
	input clk,
	output pllclk_out,
	output reg vsync,
	output reg hsync,
	output reg[1:0] r,
	output reg[1:0] g,
	output reg[1:0] b,
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

	reg[10:0] h_counter;
	reg[9:0] v_counter;	
	
	wire[1:0] r_p2;
	wire[1:0] g_p2;
	wire[1:0] b_p2;
	reg[1:0] r_p1;
	reg[1:0] g_p1;
	reg[1:0] b_p1;

	wire hsync_p1;
	wire vsync_p1;

	wire[14:0] pixel_o;

	wire[1:0] data_p2;
	
	wire visible;
	
	reg clki_prev;
	reg vsynci_prev;
	reg hsynci_prev;
	reg[14:0] pixel_i;
	
	framebuffer framebuffer_inst(
		.rdaddress(pixel_o),
		.wraddress(pixel_i),
		.clock(pllclk),
		.q(data_p2)
	);
	
	always @(posedge pllclk) begin
		if(h_counter < h_vis + h_fp + h_sync + h_bp - 1) begin
			h_counter <= h_counter+1;
		end else begin
			h_counter <= 0;
			
			if(v_counter < v_vis + v_fp + v_sync + v_bp - 1) begin
				v_counter <= v_counter+1;
			end else begin
				v_counter <= 0;
			end
		end
		
		r_p1 <= r_p2;
		g_p1 <= g_p2;
		b_p1 <= b_p2;

		vsync <= vsync_p1;
		hsync <= hsync_p1;
		r <= r_p1;
		g <= g_p1;
		b <= b_p1;
		
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
	
	assign visible = h_counter < h_vis && v_counter < v_vis;

	assign pixel_o[14:0] = visible*(v_counter[9:2]*160 + h_counter[10:2]);
	
	assign hsync_p2 = (h_counter >= h_vis + h_fp && h_counter < h_vis + h_fp + h_sync);
	assign vsync_p2 = (v_counter >= v_vis + v_fp && v_counter < v_vis + v_fp + v_sync);
	assign r_p2[1:0] = {data_p2[1] & visible, data_p2[0] & visible };
	assign g_p2[1:0] = {data_p2[1] & visible, data_p2[0] & visible };
	assign b_p2[1:0] = {data_p2[1] & visible, data_p2[0] & visible };
endmodule
