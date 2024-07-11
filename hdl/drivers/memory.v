// these are wrappers around the ip bram cores
// provides a readclk-outclk interface so that other modules don't need
// to be aware of the bram latency
`include "packets.v"

module video_cache_ram_driver #(
	parameter RAM_SIZE = VIDEO_CACHE_RAM_SIZE,
	parameter READ_LATENCY = VIDEO_CACHE_RAM_LATENCY) (
	input clk, rst,
	input readclk, input [clog2(RAM_SIZE)-1:0] raddr,
	input we, input [clog2(RAM_SIZE)-1:0] waddr,
	input [COLOR_LEN-1:0] win,
	output outclk, output [COLOR_LEN-1:0] out
	);

`include "params.vh"

delay #(.DELAY_LEN(READ_LATENCY)) delay_inst(
	.clk(clk), .rst(rst), .in(readclk), .out(outclk));
video_cache_ram video_cache_ram_inst(
	.clka(clk), .wea(we),
	.addra(waddr), .dina(win),
	.clkb(clk), .addrb(raddr), .doutb(out));

endmodule

module packet_synth_rom_driver #(
	parameter RAM_SIZE = PACKET_SYNTH_ROM_SIZE,
	parameter READ_LATENCY = PACKET_SYNTH_ROM_LATENCY) (
	input clk, rst,
	input readclk, input [clog2(RAM_SIZE)-1:0] raddr,
	output outclk, output [BYTE_LEN-1:0] out
	);

`include "params.vh"

delay #(.DELAY_LEN(READ_LATENCY)) delay_inst(
	.clk(clk), .rst(rst), .in(readclk), .out(outclk));
packet_synth_rom packet_synth_rom_inst(
	.clka(clk),
	.addra(raddr), .douta(out));

endmodule

module packet_buffer_ram_driver #(
	parameter RAM_SIZE = PACKET_BUFFER_SIZE,
	parameter READ_LATENCY = PACKET_BUFFER_READ_LATENCY) (
	input clk, rst,
	input readclk, input [clog2(RAM_SIZE)-1:0] raddr,
	input we, input [clog2(RAM_SIZE)-1:0] waddr,
	input [BYTE_LEN-1:0] win,
	output outclk, output [BYTE_LEN-1:0] out
	);

`include "params.vh"

delay #(.DELAY_LEN(READ_LATENCY)) delay_inst(
	.clk(clk), .rst(rst), .in(readclk), .out(outclk));
packet_buffer_ram packet_buffer_ram_inst(
	.clka(clk), .wea(we),
	.addra(waddr), .dina(win),
	.clkb(clk), .addrb(raddr), .doutb(out));

endmodule
