`timescale 1ns / 1ps

module test_bytes_to_colors();

`include "params.vh"

reg clk = 0;
// 50MHz clock
initial forever #10 clk = ~clk;

reg rst = 1;
reg btc_inclk = 0;
wire [BYTE_LEN-1:0] btc_in;
wire btc_outclk;
wire [COLOR_LEN-1:0] btc_out;

bytes_to_colors btc_inst(
	.clk(clk), .rst(rst), .inclk(btc_inclk), .in(btc_in),
	.outclk(btc_outclk), .out(btc_out));
reg [4*COLOR_LEN-1:0] in_data_shifted = 48'hDEADBEEFCAFE;
assign btc_in = in_data_shifted[0+:BYTE_LEN];

wire vram_readclk, vram_outclk, vram_we;
wire [clog2(VIDEO_CACHE_RAM_SIZE)-1:0] vram_raddr, vram_waddr;
wire [COLOR_LEN-1:0] vram_out, vram_win;
video_cache_ram_driver vram_driv_inst(
	.clk(clk), .rst(rst),
	.readclk(vram_readclk), .raddr(vram_raddr),
	.we(vram_we), .waddr(vram_waddr), .win(vram_win),
	.outclk(vram_outclk), .out(vram_out));
stream_to_memory
	#(.RAM_SIZE(VIDEO_CACHE_RAM_SIZE), .WORD_LEN(COLOR_LEN)) stm_inst(
	.clk(clk), .rst(rst), .setoff_req(0), .setoff_val(0),
	.inclk(btc_outclk), .in(btc_out),
	.ram_we(vram_we), .ram_waddr(vram_waddr),
	.ram_win(vram_win));
assign vram_readclk = 0;
assign vram_raddr = 0;

always @(posedge clk) begin
	if (btc_inclk)
		in_data_shifted <= {in_data_shifted[0+:BYTE_LEN],
			in_data_shifted[BYTE_LEN+:BYTE_LEN]};
end

initial begin
	#100
	rst = 0;
	#100
	btc_inclk = 1;
	#(6 * 20)
	#100
	$stop();
end

endmodule
