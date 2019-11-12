module gbvga(
	input clk,
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
	
	pll pll_inst(
		.inclk0(clk),
		.c0(pllclk),
		.locked(locked)
	);
endmodule
