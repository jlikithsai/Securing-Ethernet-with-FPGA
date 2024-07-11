module graphics_main #(
	parameter RAM_SIZE = PACKET_BUFFER_SIZE) (
	input clk, rst, blank,
	input [clog2(VGA_WIDTH)-1:0] vga_x,
	input [clog2(VGA_HEIGHT)-1:0] vga_y,
	// vga_hsync/vsync should be delayed by the latency of this module
	// so that the output pixel colors would be synchronized
	input vga_hsync_in, vga_vsync_in,
	input ram_outclk, input [COLOR_LEN-1:0] ram_out,
	output ram_readclk, output [clog2(RAM_SIZE)-1:0] ram_raddr,
	output [COLOR_LEN-1:0] vga_col,
	output vga_hsync_out, vga_vsync_out);

`include "params.vh"

wire blank_delayed;
delay #(.DELAY_LEN(VIDEO_CACHE_RAM_LATENCY)) hsync_delay(
	.clk(clk), .rst(rst), .in(vga_hsync_in), .out(vga_hsync_out));
delay #(.DELAY_LEN(VIDEO_CACHE_RAM_LATENCY)) vsync_delay(
	.clk(clk), .rst(rst), .in(vga_vsync_in), .out(vga_vsync_out));
delay #(.DELAY_LEN(VIDEO_CACHE_RAM_LATENCY)) blank_delay(
	.clk(clk), .rst(rst), .in(blank), .out(blank_delayed));

// number of pixels per image pixel in each direction
localparam RESOLUTION = 4;
// height and width of the image
localparam IMAGE_SIZE = 128;

// position in image to display, in terms of image pixels
wire [clog2(IMAGE_SIZE)-1:0] image_x, image_y;
// position in image to display, in terms of screen pixels
wire [clog2(VGA_WIDTH)-1:0] image_x_pix;
wire [clog2(VGA_HEIGHT)-1:0] image_y_pix;
// center image in screen
assign image_x_pix = vga_x - (VGA_WIDTH/2 - IMAGE_SIZE*RESOLUTION/2);
assign image_y_pix = vga_y - (VGA_HEIGHT/2 - IMAGE_SIZE*RESOLUTION/2);
// divide by RESOLUTION
assign image_x = image_x_pix[clog2(RESOLUTION)+:clog2(IMAGE_SIZE)];
assign image_y = image_y_pix[clog2(RESOLUTION)+:clog2(IMAGE_SIZE)];
// display the image in the center and white everywhere else
assign ram_readclk = !blank &&
	vga_x >= VGA_WIDTH/2 - IMAGE_SIZE*RESOLUTION/2 &&
	vga_x < VGA_WIDTH/2 + IMAGE_SIZE*RESOLUTION/2 &&
	vga_y >= VGA_HEIGHT/2 - IMAGE_SIZE*RESOLUTION/2 &&
	vga_y < VGA_HEIGHT/2 + IMAGE_SIZE*RESOLUTION/2;
assign ram_raddr = {image_y, image_x};
assign vga_col = blank_delayed ? 12'h0 :
	ram_outclk ? ram_out : 12'hfff;

endmodule
