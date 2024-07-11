`timescale 1ns / 1ps

module test_daisy_chain();

`include "networking.vh"
`include "packet_synth_rom_layout.vh"

reg clk_100mhz = 0;
initial forever #5 clk_100mhz = ~clk_100mhz;

reg clk_50mhz = 0;
initial forever #10 clk_50mhz = ~clk_50mhz;

reg clk_120mhz = 0;
initial forever #4.16667 clk_120mhz = ~clk_120mhz;

reg uart_rst = 1;

wire uart_rom_rst, uart_rom_readclk, uart_rom_outclk;
wire [clog2(PACKET_SYNTH_ROM_SIZE)-1:0] uart_rom_raddr;
wire [BYTE_LEN-1:0] uart_rom_out;
packet_synth_rom_driver uart_psr_inst(
	.clk(clk_50mhz), .rst(uart_rst || uart_rom_rst),
	.readclk(uart_rom_readclk), .raddr(uart_rom_raddr),
	.outclk(uart_rom_outclk), .out(uart_rom_out));
wire uart_tx_inclk, uart_tx_readclk;
wire [BYTE_LEN-1:0] uart_tx_in;
wire uart_tx_start;
assign uart_rom_rst = uart_tx_start;
stream_from_memory uart_sfm_inst(
	.clk(clk_50mhz), .rst(uart_rst), .start(uart_tx_start),
	.read_start(SAMPLE_PAYLOAD_OFF),
	.read_end(SAMPLE_PAYLOAD_OFF + SAMPLE_PAYLOAD_LEN),
	.readclk(uart_tx_readclk),
	.ram_outclk(uart_rom_outclk), .ram_out(uart_rom_out),
	.ram_readclk(uart_rom_readclk), .ram_raddr(uart_rom_raddr),
	.outclk(uart_tx_inclk), .out(uart_tx_in));
wire uart_txd;
uart_tx_fast_stream_driver uart_tx_inst(
	.clk(clk_50mhz), .clk_120mhz(clk_120mhz), .rst(uart_rst),
	.start(uart_tx_start),
	.inclk(uart_tx_inclk), .in(uart_tx_in), .txd(uart_txd),
	.upstream_readclk(uart_tx_readclk));

reg [13:0] sw_prefix = 14'b0100_1110_0000_10;
reg rst = 1;
wire [15:0] sw_tx, sw_rx;
assign sw_tx = {sw_prefix, 1'b1, rst};
assign sw_rx = {sw_prefix, 1'b0, rst};
wire eth_tx_crsdv, eth_rx_crsdv;
wire [1:0] eth_tx_rxd, eth_rx_rxd;

main main_inst_tx(
	.CLK100MHZ(clk_100mhz), .SW(sw_tx),
	.BTNC(1'b0), .BTNU(1'b0), .BTNL(1'b0), .BTNR(1'b0), .BTND(1'b0),
	.ETH_CRSDV(eth_tx_crsdv), .ETH_RXD(eth_tx_rxd),
	.ETH_TXEN(eth_rx_crsdv), .ETH_TXD(eth_rx_rxd),
	.UART_TXD_IN(uart_txd), .UART_RTS(1'b0));
main main_inst_rx(
	.CLK100MHZ(clk_100mhz), .SW(sw_rx),
	.BTNC(1'b0), .BTNU(1'b0), .BTNL(1'b0), .BTNR(1'b0), .BTND(1'b0),
	.ETH_CRSDV(eth_rx_crsdv), .ETH_RXD(eth_rx_rxd),
	.ETH_TXEN(eth_tx_crsdv), .ETH_TXD(eth_tx_rxd),
	.UART_TXD_IN(1'b1), .UART_RTS(1'b0));

reg uart_tx_start_manual = 0;
assign uart_tx_start = uart_tx_start_manual;

initial begin
	#2000
	uart_rst = 0;
	rst = 0;
	#400

	uart_tx_start_manual = 1;
	#20
	uart_tx_start_manual = 0;
	// 12mbaud = 84ns per bit, for a frame of 914 bytes
	// multiply by 2 to account for overhead
	#(2 * 84 * 914 * 8)

	uart_tx_start_manual = 1;
	#20
	uart_tx_start_manual = 0;
	#(2 * 84 * 914 * 8)

	// test resyn
	#2000000

	uart_tx_start_manual = 1;
	#20
	uart_tx_start_manual = 0;
	#(2 * 84 * 914 * 8)

	uart_tx_start_manual = 1;
	#20
	uart_tx_start_manual = 0;
	#(2 * 84 * 914 * 8)

	$stop();
end

endmodule
