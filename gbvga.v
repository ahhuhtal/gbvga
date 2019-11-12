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
	
	reg[10:0] h_counter;
	reg[9:0] v_counter;
	
	always @(posedge pllclk)
	begin
		if(h_counter < 1055)
		begin
			h_counter <= h_counter+1;
		end
		else
		begin
			h_counter <= 0;
			
			if(v_counter < 627)
			begin
				v_counter <= v_counter+1;
			end
			else
			begin
				v_counter <= 0;
			end
		end
	end
	
	assign hsync = (h_counter >= 840 && h_counter < 968);
	assign vsync = (v_counter >= 601 && v_counter < 605);
endmodule
