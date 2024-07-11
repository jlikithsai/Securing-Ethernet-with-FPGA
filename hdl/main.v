// SW[0]: reset
// SW[1]: master configure: on for transmit, off for receive
// SW[2]: UART_CTS override (to test flow control)
// SW[3]: enable CBC mode
// SW[15:8]: last bits of key for aes
// BTNC: dump ram over uart (from vram, only in transmit configuration)
module main(
	input CLK100MHZ,
	input [15:0] SW,
	input BTNC, BTNU, BTNL, BTNR, BTND,
	output [7:0] JB,
	output [3:0] VGA_R,
	output [3:0] VGA_B,
	output [3:0] VGA_G,
	output VGA_HS,
	output VGA_VS,
	output LED16_B, LED16_G, LED16_R,
	output LED17_B, LED17_G, LED17_R,
	output [15:0] LED,
	output [7:0] SEG,  // segments A-G (0-6), DP (7)
	output [7:0] AN,	// Display 0-7
	inout ETH_CRSDV, ETH_RXERR,
	inout [1:0] ETH_RXD,
	output ETH_REFCLK, ETH_INTN, ETH_RSTN,
	input UART_TXD_IN, UART_RTS,
	output UART_RXD_OUT, UART_CTS,
	output ETH_TXEN,
	output [1:0] ETH_TXD,
	output ETH_MDC, ETH_MDIO);

////// INCLUDES

`include "networking.vh"

localparam RAM_SIZE = PACKET_BUFFER_SIZE;
localparam VRAM_SIZE = VIDEO_CACHE_RAM_SIZE;
localparam ROM_SIZE = PACKET_SYNTH_ROM_SIZE;

// fixed key to use; last 8 bits will be overwritten by switches
localparam KEY = 128'h4b42_4410_770a_ee13_094d_d0da_1217_7bb0;

////// CLOCKING

wire clk_50mhz;

// the main clock for FPGA logic will be 50MHz
wire clk;
assign clk = clk_50mhz;

wire clk_120mhz;

// 50MHz clock for Ethernet receiving
clk_wiz_0 clk_wiz_inst(
	.reset(0),
	.clk_in1(CLK100MHZ),
	.clk_out1(clk_50mhz),
	.clk_out3(clk_120mhz));

////// CONFIGURATION AND RESET

wire sw0, sw1, sw2, sw3;
wire [7:0] swkey;
delay #(.DELAY_LEN(SYNC_DELAY_LEN)) sw0_sync(
	.clk(clk), .rst(1'b0), .in(SW[0]), .out(sw0));
delay #(.DELAY_LEN(SYNC_DELAY_LEN)) sw1_sync(
	.clk(clk), .rst(1'b0), .in(SW[1]), .out(sw1));
delay #(.DELAY_LEN(SYNC_DELAY_LEN)) sw2_sync(
	.clk(clk), .rst(1'b0), .in(SW[2]), .out(sw2));
delay #(.DELAY_LEN(SYNC_DELAY_LEN)) sw3_sync(
	.clk(clk), .rst(1'b0), .in(SW[3]), .out(sw3));
delay #(.DELAY_LEN(SYNC_DELAY_LEN), .DATA_WIDTH(8)) swkey_sync(
	.clk(clk), .rst(1'b0), .in(SW[8+:8]), .out(swkey));

wire config_transmit;
assign config_transmit = sw1;
wire cbc_enable;
assign cbc_enable = sw3;

reg prev_sw1 = 0;
reg prev_sw3 = 0;
reg [7:0] prev_swkey = 0;
always @(posedge clk) begin
	prev_sw1 <= sw1;
	prev_sw3 <= sw3;
	prev_swkey <= swkey;
end

// reset device when configuration is changed
wire config_change_reset;
assign config_change_reset =
	sw1 != prev_sw1 ||
	sw3 != prev_sw3 ||
	swkey != prev_swkey;

wire rst;
// ensure that reset pulse lasts a sufficient long amount of time
// skip reset when testing
localparam TESTING = 0;
localparam RESET_TIMEOUT = TESTING ? 1 : 5000000;
pulse_extender #(.EXTEND_LEN(RESET_TIMEOUT)) reset_pe(
	.clk(clk), .rst(1'b0), .in(sw0 || config_change_reset), .out(rst));

////// HEX DISPLAY

wire [31:0] hex_display_data;
wire [6:0] segments;

display_8hex display(
	.clk(clk), .data(hex_display_data), .seg(segments), .strobe(AN));

assign SEG[7] = 1'b1;
assign SEG[6:0] = segments;

////// LEDS

assign LED16_R = BTNL; // left button -> red led
assign LED16_G = BTNC; // center button -> green led
assign LED16_B = BTNR; // right button -> blue led
assign LED17_R = BTNL;
assign LED17_G = BTNC;
assign LED17_B = BTNR;

////// BUTTONS

wire btnc_raw, btnl_raw, btnc, btnl;
sync_debounce sd_btnc(
	.rst(rst), .clk(clk), .in(BTNC), .out(btnc_raw));
sync_debounce sd_btnl(
	.rst(rst), .clk(clk), .in(BTNL), .out(btnl_raw));

pulse_generator pg_btnc(
	.clk(clk), .rst(rst), .in(btnc_raw), .out(btnc));
pulse_generator pg_btnl(
	.clk(clk), .rst(rst), .in(btnl_raw), .out(btnl));

////// VGA

wire [clog2(VGA_WIDTH)-1:0] vga_x;
wire [clog2(VGA_HEIGHT)-1:0] vga_y;
// allow for hsync and vsync to be delayed before sending on wire
wire vga_hsync, vga_vsync, vga_hsync_predelay, vga_vsync_predelay, blank;

xvga xvga_inst(
	.clk(clk), .vga_x(vga_x), .vga_y(vga_y),
	.vga_hsync(vga_hsync_predelay), .vga_vsync(vga_vsync_predelay),
	.blank(blank));

// vga_col should be set by some downstream module, indicating the
// color of the current pixel
wire [COLOR_CHANNEL_LEN-1:0] vga_r_out, vga_g_out, vga_b_out;
wire [COLOR_LEN-1:0] vga_col;
assign {vga_r_out, vga_g_out, vga_b_out} = vga_col;

// buffer all outputs to enforce timing constraints
delay #(.DATA_WIDTH(COLOR_CHANNEL_LEN)) vga_r_sync(
	.clk(clk), .rst(rst), .in(vga_r_out), .out(VGA_R));
delay #(.DATA_WIDTH(COLOR_CHANNEL_LEN)) vga_g_sync(
	.clk(clk), .rst(rst), .in(vga_g_out), .out(VGA_G));
delay #(.DATA_WIDTH(COLOR_CHANNEL_LEN)) vga_b_sync(
	.clk(clk), .rst(rst), .in(vga_b_out), .out(VGA_B));
delay vga_hs_sync(
	.clk(clk), .rst(rst), .in(vga_hsync), .out(VGA_HS));
delay vga_vs_sync(
	.clk(clk), .rst(rst), .in(vga_vsync), .out(VGA_VS));

////// BRAM

// the ram_rst signals allow us to clear any pending reads
wire ram_rst;
wire ram_readclk, ram_outclk, ram_we;
wire [clog2(RAM_SIZE)-1:0] ram_raddr, ram_waddr;
wire [BYTE_LEN-1:0] ram_out, ram_win;
packet_buffer_ram_driver ram_driv_inst(
	.clk(clk), .rst(rst || ram_rst),
	.readclk(ram_readclk), .raddr(ram_raddr),
	.we(ram_we), .waddr(ram_waddr), .win(ram_win),
	.outclk(ram_outclk), .out(ram_out));

wire vram_rst;
wire vram_readclk, vram_outclk, vram_we;
wire [clog2(VRAM_SIZE)-1:0] vram_raddr, vram_waddr;
wire [COLOR_LEN-1:0] vram_out, vram_win;
video_cache_ram_driver vram_driv_inst(
	.clk(clk), .rst(rst || vram_rst),
	.readclk(vram_readclk), .raddr(vram_raddr),
	.we(vram_we), .waddr(vram_waddr), .win(vram_win),
	.outclk(vram_outclk), .out(vram_out));

wire rom_rst, rom_readclk, rom_outclk;
wire [clog2(ROM_SIZE)-1:0] rom_raddr;
wire [BYTE_LEN-1:0] rom_out;
packet_synth_rom_driver psr_inst(
	.clk(clk), .rst(rst || rom_rst),
	.readclk(rom_readclk), .raddr(rom_raddr),
	.outclk(rom_outclk), .out(rom_out));

////// AES

// use switches for last 8 bits of key
wire [BLOCK_LEN-1:0] aes_key;
assign aes_key = {KEY[8+:BLOCK_LEN-8], swkey};

wire aes_rst, aes_inclk, aes_outclk, aes_in_done, aes_done;
wire [BYTE_LEN-1:0] aes_in, aes_out;
wire aes_upstream_readclk, aes_readclk;
wire aes_decr_select;
assign aes_decr_select = !config_transmit;
aes_combined_bytes_buf aes_inst(
	.clk(clk), .rst(rst || aes_rst),
	.inclk(aes_inclk), .in(aes_in), .in_done(aes_in_done),
	.key(aes_key),
	.readclk(aes_readclk),
	.outclk(aes_outclk), .out(aes_out), .done(aes_done),
	.upstream_readclk(aes_upstream_readclk),
	.decr_select(aes_decr_select), .cbc_enable(cbc_enable));

// multiplex aes for encrypt and decrypt paths

wire aes_encr_rst, aes_decr_rst;
wire aes_encr_inclk, aes_decr_inclk, aes_encr_outclk, aes_decr_outclk;
wire aes_encr_in_done, aes_decr_in_done, aes_encr_done, aes_decr_done;
wire aes_encr_readclk, aes_decr_readclk;
wire aes_encr_upstream_readclk, aes_decr_upstream_readclk;
wire [BYTE_LEN-1:0] aes_encr_in, aes_decr_in, aes_encr_out, aes_decr_out;
assign aes_rst = aes_decr_select ? aes_decr_rst : aes_encr_rst;
assign aes_inclk = aes_decr_select ? aes_decr_inclk : aes_encr_inclk;
assign aes_in = aes_decr_select ? aes_decr_in : aes_encr_in;
assign aes_in_done = aes_decr_select ? aes_decr_in_done : aes_encr_in_done;
assign aes_readclk = aes_decr_select ? aes_decr_readclk : aes_encr_readclk;
assign aes_encr_outclk = aes_decr_select ? 0 : aes_outclk;
assign aes_decr_outclk = aes_decr_select ? aes_outclk : 0;
assign aes_encr_out = aes_decr_select ? 0 : aes_out;
assign aes_decr_out = aes_decr_select ? aes_out : 0;
assign aes_encr_done = aes_decr_select ? 0 : aes_done;
assign aes_decr_done = aes_decr_select ? aes_done : 0;
assign aes_encr_upstream_readclk =
	aes_decr_select ? 0 : aes_upstream_readclk;
assign aes_decr_upstream_readclk =
	aes_decr_select ? aes_upstream_readclk : 0;

////// RAM MULTIPLEXING

// old uart ram interface for debugging, no longer used
wire uart_ram_rst, uart_ram_readclk, uart_ram_outclk;
wire [clog2(RAM_SIZE)-1:0] uart_ram_raddr;
wire [BYTE_LEN-1:0] uart_ram_out;
assign uart_ram_outclk = 0;

wire rx_ram_rst, uart_ram_we, rx_ram_readclk, rx_ram_outclk;
wire [clog2(RAM_SIZE)-1:0] uart_ram_waddr, rx_ram_raddr;
wire [BYTE_LEN-1:0] uart_ram_win, rx_ram_out;
wire ffcp_ram_rst, rx_ram_we, ffcp_ram_readclk, ffcp_ram_outclk;
wire [clog2(RAM_SIZE)-1:0] rx_ram_waddr, ffcp_ram_raddr;
wire [BYTE_LEN-1:0] rx_ram_win, ffcp_ram_out;
assign ram_rst = config_transmit ? ffcp_ram_rst : rx_ram_rst;
assign ram_we = config_transmit ? uart_ram_we : rx_ram_we;
assign ram_waddr = config_transmit ? uart_ram_waddr : rx_ram_waddr;
assign ram_win = config_transmit ? uart_ram_win : rx_ram_win;
assign ram_readclk = config_transmit ? ffcp_ram_readclk : rx_ram_readclk;
assign ram_raddr = config_transmit ? ffcp_ram_raddr : rx_ram_raddr;
assign rx_ram_outclk = config_transmit ? 0 : ram_outclk;
assign ffcp_ram_outclk = config_transmit ? ram_outclk : 0;
assign rx_ram_out = ram_out;
assign ffcp_ram_out = ram_out;

wire uart_vram_rst;
wire vga_vram_readclk, vga_vram_outclk;
wire [clog2(VRAM_SIZE)-1:0] vga_vram_raddr;
wire [COLOR_LEN-1:0] vga_vram_out;
wire uart_vram_readclk, uart_vram_outclk;
wire [clog2(VRAM_SIZE)-1:0] uart_vram_raddr;
wire [COLOR_LEN-1:0] uart_vram_out;
assign vram_rst = config_transmit ? uart_vram_rst : 0;
assign vram_readclk =
	config_transmit ? uart_vram_readclk : vga_vram_readclk;
assign vram_raddr = config_transmit ? uart_vram_raddr : vga_vram_raddr;
assign vga_vram_outclk = config_transmit ? 0 : vram_outclk;
assign uart_vram_outclk = config_transmit ? vram_outclk : 0;
assign vga_vram_out = vram_out;
assign uart_vram_out = vram_out;

////// RMII

assign ETH_REFCLK = clk;
assign ETH_MDC = 0;
assign ETH_MDIO = 0;
wire rmii_outclk, rmii_done;
wire [1:0] rmii_out;
rmii_driver rmii_driv_inst(
	.clk(clk), .rst(rst),
	.crsdv_in(ETH_CRSDV), .rxd_in(ETH_RXD),
	.rxerr(ETH_RXERR),
	.intn(ETH_INTN), .rstn(ETH_RSTN),
	.out(rmii_out),
	.outclk(rmii_outclk), .done(rmii_done));

wire eth_txen;
wire [1:0] eth_txd;
// buffer the outputs so that eth_txd calculation would be
// under timing constraints
delay eth_txen_delay(
	.clk(clk), .rst(rst), .in(eth_txen), .out(ETH_TXEN));
delay #(.DATA_WIDTH(2)) eth_txd_delay(
	.clk(clk), .rst(rst), .in(eth_txd), .out(ETH_TXD));

////// ETHERNET TX <= RAM

wire ffcp_tx_start;
wire [FFCP_TYPE_LEN-1:0] ffcp_tx_type;
wire [FFCP_INDEX_LEN-1:0] ffcp_tx_index;

wire [clog2(RAM_SIZE)-1:0] ffcp_tx_sfm_read_start;
wire ffcp_tx_sfm_readclk;
wire ffcp_tx_sfm_outclk, ffcp_tx_sfm_done;
wire [BYTE_LEN-1:0] ffcp_tx_sfm_out;
assign ffcp_ram_rst = ffcp_tx_start;
stream_from_memory #(.RAM_SIZE(RAM_SIZE),
	.RAM_READ_LATENCY(PACKET_BUFFER_READ_LATENCY)) ffcp_tx_sfm_inst(
	.clk(clk), .rst(rst), .start(ffcp_tx_start),
	.read_start(ffcp_tx_sfm_read_start),
	.read_end(ffcp_tx_sfm_read_start + FGP_LEN),
	.readclk(ffcp_tx_sfm_readclk),
	.ram_outclk(ffcp_ram_outclk), .ram_out(ffcp_ram_out),
	.ram_readclk(ffcp_ram_readclk), .ram_raddr(ffcp_ram_raddr),
	.outclk(ffcp_tx_sfm_outclk), .out(ffcp_tx_sfm_out),
	.done(ffcp_tx_sfm_done));

wire ffcp_tx_fgp_offset_outclk;
wire [BYTE_LEN-1:0] ffcp_tx_fgp_offset_out;
wire ffcp_tx_fgp_outclk, ffcp_tx_fgp_done;
wire [BYTE_LEN-1:0] ffcp_tx_fgp_out;
// use an fgp_rx to split the data from the offset since we are
// only encrypting the data
fgp_rx fgp_rx(
	.clk(clk), .rst(rst),
	.inclk(ffcp_tx_sfm_outclk), .in(ffcp_tx_sfm_out),
	.offset_outclk(ffcp_tx_fgp_offset_outclk),
	.offset_out(ffcp_tx_fgp_offset_out),
	.outclk(ffcp_tx_fgp_outclk), .out(ffcp_tx_fgp_out),
	.done(ffcp_tx_fgp_done));
reg fgp_tx_reading_metadata = 0;
always @(posedge clk) begin
	if (rst || ffcp_tx_fgp_offset_outclk)
		fgp_tx_reading_metadata <= 0;
	else if (ffcp_tx_start)
		fgp_tx_reading_metadata <= 1;
end
assign ffcp_tx_sfm_readclk =
	fgp_tx_reading_metadata || aes_encr_upstream_readclk;

assign aes_encr_rst = ffcp_tx_start && ffcp_tx_type == FFCP_TYPE_SYN;
assign aes_encr_inclk = ffcp_tx_fgp_outclk && !fgp_tx_reading_metadata;
assign aes_encr_in = ffcp_tx_fgp_out;
assign aes_encr_in_done = ffcp_tx_fgp_done;

wire fgp_tx_start;
assign fgp_tx_start = ffcp_tx_fgp_offset_outclk;
// delay the aes readclk since every transmit component should have
// exactly two clock cycles of delay, but aes has no latency
wire aes_encr_readclk_pd;
delay #(.DELAY_LEN(PACKET_SYNTH_ROM_LATENCY)) aes_encr_readclk_delay(
	.clk(clk), .rst(rst || fgp_tx_start),
	.in(aes_encr_readclk_pd), .out(aes_encr_readclk));

// glue the fgp header back on
wire fgp_tx_readclk, fgp_tx_outclk, fgp_tx_done;
wire [BYTE_LEN-1:0] fgp_tx_out;
fgp_tx fgp_tx_inst(
	.clk(clk), .rst(rst),
	.start(fgp_tx_start), .offset(ffcp_tx_fgp_offset_out),
	.inclk(aes_encr_outclk), .in(aes_encr_out),
	.in_done(aes_encr_done),
	.readclk(fgp_tx_readclk),
	.outclk(fgp_tx_outclk), .out(fgp_tx_out), .done(fgp_tx_done),
	.upstream_readclk(aes_encr_readclk_pd));

wire ffcp_tx_readclk, ffcp_tx_outclk, ffcp_tx_done;
wire [BYTE_LEN-1:0] ffcp_tx_out;
ffcp_tx ffcp_tx_inst(
	.clk(clk), .rst(rst), .start(ffcp_tx_start),
	.inclk(fgp_tx_outclk), .in(fgp_tx_out),
	.in_done(fgp_tx_done),
	.ffcp_type(ffcp_tx_type), .ffcp_index(ffcp_tx_index),
	.readclk(ffcp_tx_readclk),
	.outclk(ffcp_tx_outclk), .out(ffcp_tx_out),
	.upstream_readclk(fgp_tx_readclk), .done(ffcp_tx_done));

wire eth_tx_done;
eth_tx eth_tx_inst(
	.clk(clk), .rst(rst), .start(ffcp_tx_start),
	.in_done(ffcp_tx_done),
	.inclk(ffcp_tx_outclk), .in(ffcp_tx_out),
	.ram_outclk(rom_outclk), .ram_out(rom_out),
	.ram_readclk(rom_readclk), .ram_raddr(rom_raddr),
	.outclk(eth_txen), .out(eth_txd),
	.upstream_readclk(ffcp_tx_readclk), .done(eth_tx_done));

////// ETHERNET RX => VRAM

wire eth_rx_downstream_done, eth_rx_outclk, eth_rx_err, eth_rx_done;
wire [BYTE_LEN-1:0] eth_rx_out;
wire eth_rx_ethertype_outclk;
wire [ETH_ETHERTYPE_LEN*BYTE_LEN-1:0] eth_rx_ethertype_out;
eth_rx eth_rx_inst(
	.clk(clk), .rst(rst),
	.inclk(rmii_outclk), .in(rmii_out),
	.in_done(rmii_done),
	.downstream_done(eth_rx_downstream_done),
	.outclk(eth_rx_outclk), .out(eth_rx_out),
	.ethertype_outclk(eth_rx_ethertype_outclk),
	.ethertype_out(eth_rx_ethertype_out),
	.err(eth_rx_err), .done(eth_rx_done));
// reset all downstream modules when a receive error occurs
wire eth_rx_downstream_rst;
assign eth_rx_downstream_rst = rst || eth_rx_err;

// ffcp_rx_en is asserted (and held until the next packet is received)
// only when the packet is an ffcp packet, acting as a filter
reg ffcp_rx_en = 0;
always @(posedge clk) begin
	if (eth_rx_downstream_rst)
		ffcp_rx_en <= 0;
	else if (eth_rx_ethertype_outclk)
		ffcp_rx_en <= eth_rx_ethertype_out == ETHERTYPE_FFCP;
end
wire ffcp_rx_eth_done;
assign ffcp_rx_eth_done = ffcp_rx_en && eth_rx_done;

wire ffcp_rx_done;
assign eth_rx_downstream_done = ffcp_rx_done;
wire ffcp_rx_metadata_outclk;
wire [FFCP_TYPE_LEN-1:0] ffcp_rx_type;
wire [FFCP_INDEX_LEN-1:0] ffcp_rx_index;
wire ffcp_rx_outclk;
wire [BYTE_LEN-1:0] ffcp_rx_out;
ffcp_rx ffcp_rx_inst(
	.clk(clk), .rst(eth_rx_downstream_rst),
	.inclk(eth_rx_outclk && ffcp_rx_en), .in(eth_rx_out),
	.done(ffcp_rx_done),
	.metadata_outclk(ffcp_rx_metadata_outclk),
	.ffcp_type(ffcp_rx_type), .ffcp_index(ffcp_rx_index),
	.outclk(ffcp_rx_outclk), .out(ffcp_rx_out));

// signals that tell us what kind of ffcp packet we received
wire ffcp_rx_ack_outclk, ffcp_rx_syn_outclk, ffcp_rx_msg_outclk;
assign ffcp_rx_ack_outclk =
	ffcp_rx_metadata_outclk && ffcp_rx_type == FFCP_TYPE_ACK;
assign ffcp_rx_syn_outclk =
	ffcp_rx_metadata_outclk && ffcp_rx_type == FFCP_TYPE_SYN;
assign ffcp_rx_msg_outclk =
	ffcp_rx_metadata_outclk && ffcp_rx_type == FFCP_TYPE_MSG;

// we no longer need to use the ffcp_queue interface in the receive
// configuration
wire pb_advance_tail_rx, pb_advance_head_rx;
assign pb_advance_tail_rx = 1'b0;
assign pb_advance_head_rx = 1'b0;

// stream the ffcp payload into ram

// records the number of bytes of the ffcp payload (which is an fgp
// datagram) we have received
reg [clog2(FGP_LEN)-1:0] fgp_rx_cnt = 0;
assign rx_ram_waddr = {ffcp_rx_index_buf, fgp_rx_cnt};
assign rx_ram_we = ffcp_rx_outclk;
assign rx_ram_win = ffcp_rx_out;
assign pb_rst_rx = 1'b0;
always @(posedge clk) begin
	if (eth_rx_downstream_rst)
		fgp_rx_cnt <= 0;
	else if (ffcp_rx_eth_done)
		fgp_rx_cnt <= 0;
	else if (ffcp_rx_outclk)
		fgp_rx_cnt <= fgp_rx_cnt + 1;
end

// the signal that we send to the ffcp_rx_server to inform it of a syn
// this is different from the syn_outclk because we need to assert this
// at the same time as when we assert the ffcp_rx_server's inclk, which
// only happens when the complete ethernet frame is received
wire ffcp_rx_serv_syn;
// if the ffcp_rx_server receives a syn, then we have started a new stream,
// so all downstream modules should be reset
wire ffcp_rx_serv_downstream_rst;
assign ffcp_rx_serv_downstream_rst = rst || ffcp_rx_serv_syn;

// signals related to the ffcp_rx_server
wire ffcp_rx_commit, ffcp_rx_commit_done;
wire [clog2(FFCP_BUFFER_LEN)-1:0] ffcp_rx_commit_index;

// at some point, the ffcp_rx_server will commit the packet
// and we stream the packet from the packet buffer to VRAM
wire [clog2(RAM_SIZE)-1:0] ffcp_rx_sfm_read_start;
assign ffcp_rx_sfm_read_start =
	{ffcp_rx_commit_index, {clog2(FGP_LEN){1'b0}}};
wire ffcp_rx_sfm_readclk, ffcp_rx_sfm_outclk;
wire [BYTE_LEN-1:0] ffcp_rx_sfm_out;
stream_from_memory #(.RAM_SIZE(RAM_SIZE),
	.RAM_READ_LATENCY(PACKET_BUFFER_READ_LATENCY)) ffcp_rx_sfm_inst(
	.clk(clk), .rst(ffcp_rx_serv_downstream_rst), .start(ffcp_rx_commit),
	.read_start(ffcp_rx_sfm_read_start),
	.read_end(ffcp_rx_sfm_read_start + FGP_LEN),
	.readclk(ffcp_rx_sfm_readclk),
	.ram_outclk(rx_ram_outclk), .ram_out(rx_ram_out),
	.ram_readclk(rx_ram_readclk), .ram_raddr(rx_ram_raddr),
	.outclk(ffcp_rx_sfm_outclk), .out(ffcp_rx_sfm_out),
	.done(ffcp_rx_commit_done));
assign rx_ram_rst = ffcp_rx_serv_downstream_rst;
assign ffcp_rx_sfm_readclk = aes_decr_upstream_readclk;

// the packets are stored in the packet buffer along with the fgp header
// we use the fgp header to determine where to stream the data to in vram

wire fgp_rx_setoff_req;
wire [BYTE_LEN+clog2(FGP_DATA_LEN_COLORS)-1:0] fgp_rx_setoff_val;
wire fgp_rx_outclk;
wire [BYTE_LEN-1:0] fgp_rx_out, fgp_rx_offset_out;
wire fgp_rx_done;
fgp_rx fgp_rx_inst(
	.clk(clk), .rst(ffcp_rx_serv_downstream_rst),
	.inclk(ffcp_rx_sfm_outclk && !config_transmit), .in(ffcp_rx_sfm_out),
	.done(fgp_rx_done),
	.offset_outclk(fgp_rx_setoff_req), .offset_out(fgp_rx_offset_out),
	.outclk(fgp_rx_outclk), .out(fgp_rx_out));
assign fgp_rx_setoff_val = {fgp_rx_offset_out,
	{clog2(FGP_DATA_LEN_COLORS){1'b0}}};

assign aes_decr_rst = ffcp_rx_serv_downstream_rst;
assign aes_decr_inclk = fgp_rx_outclk;
assign aes_decr_in = fgp_rx_out;
assign aes_decr_readclk = 1'b1;

wire fgp_btc_outclk;
wire [COLOR_LEN-1:0] fgp_btc_out;
bytes_to_colors fgp_btc_inst(
	.clk(clk), .rst(ffcp_rx_serv_downstream_rst),
	.inclk(aes_decr_outclk), .in(aes_decr_out),
	.outclk(fgp_btc_outclk), .out(fgp_btc_out));
assign aes_decr_in_done = 1'b0;
stream_to_memory
	#(.RAM_SIZE(VRAM_SIZE), .WORD_LEN(COLOR_LEN)) fgp_stm_inst(
	.clk(clk), .rst(ffcp_rx_serv_downstream_rst),
	.setoff_req(fgp_rx_setoff_req),
	.setoff_val(fgp_rx_setoff_val[clog2(VRAM_SIZE)-1:0]),
	.inclk(fgp_btc_outclk), .in(fgp_btc_out),
	.ram_we(vram_we), .ram_waddr(vram_waddr),
	.ram_win(vram_win));

////// FFCP FLOW CONTROL (RECEIVE CONFIGURATION)

// buffer ffcp header information so that we can provide them to the
// ffcp_rx_server after the complete ethernet frame has been received
reg ffcp_syn_buf;
reg [FFCP_INDEX_LEN-1:0] ffcp_rx_index_buf;
always @(posedge clk) begin
	if (ffcp_rx_syn_outclk || ffcp_rx_msg_outclk) begin
		ffcp_rx_index_buf <= ffcp_rx_index;
		ffcp_syn_buf <= ffcp_rx_syn_outclk;
	end
end

wire ffcp_ack_start;
wire [FFCP_INDEX_LEN-1:0] ffcp_ack_index;
assign ffcp_rx_serv_syn = ffcp_rx_eth_done && ffcp_syn_buf;
ffcp_rx_server ffcp_rx_serv_inst(
	.clk(clk), .rst(rst), .syn(ffcp_rx_serv_syn),
	.inclk(ffcp_rx_eth_done),
	.in_index(ffcp_rx_index_buf),
	.downstream_done(eth_tx_done),
	.commit(ffcp_rx_commit), .commit_index(ffcp_rx_commit_index),
	.commit_done(ffcp_rx_commit_done),
	.outclk(ffcp_ack_start), .out_index(ffcp_ack_index));

////// FFCP FLOW CONTROL (TRANSMIT CONFIGURATION)

wire [clog2(PB_QUEUE_LEN)-1:0] pb_head, pb_tail;
// pb_advance_head_rx, pb_advance_tail_rx and pb_rst_rx
// already declared earlier
wire pb_advance_tail, pb_advance_tail_tx;
wire pb_advance_head, pb_advance_head_tx;
wire pb_rst, pb_rst_tx;
assign pb_advance_tail =
	config_transmit ? pb_advance_tail_tx : pb_advance_tail_rx;
assign pb_advance_head =
	config_transmit ? pb_advance_head_tx : pb_advance_head_rx;
assign pb_rst = config_transmit ? pb_rst_tx : pb_rst_rx;
wire pb_inclk;
wire [clog2(PB_QUEUE_LEN)-1:0] pb_in_head;
wire pb_almost_full;
ffcp_queue ffcp_queue_inst(
	.clk(clk), .rst(rst || pb_rst),
	.advance_head(pb_advance_head), .advance_tail(pb_advance_tail),
	.inclk(pb_inclk && config_transmit), .in_head(pb_in_head),
	.almost_full(pb_almost_full),
	.head(pb_head), .tail(pb_tail));
wire ffcp_msg_start;
wire [FFCP_INDEX_LEN-1:0] ffcp_msg_index;
wire ffcp_tx_syn;
wire [clog2(PB_QUEUE_LEN)-1:0] ffcp_tx_buf_pos;
ffcp_tx_server ffcp_tx_serv_inst(
	.clk(clk), .rst(rst),
	.pb_head(pb_head), .pb_tail(pb_tail),
	.downstream_done(eth_tx_done),
	.inclk(ffcp_rx_ack_outclk), .in_index(ffcp_rx_index),
	.outclk(ffcp_msg_start), .out_syn(ffcp_tx_syn),
	.out_index(ffcp_msg_index),
	.out_buf_pos(ffcp_tx_buf_pos),
	.outclk_pb(pb_inclk), .out_pb_head(pb_in_head));
assign pb_rst_tx = 1'b0;
assign ffcp_tx_sfm_read_start = {ffcp_tx_buf_pos, {clog2(FGP_LEN){1'b0}}};

assign ffcp_tx_start = config_transmit ? ffcp_msg_start : ffcp_ack_start;
assign ffcp_tx_type = config_transmit ?
	(ffcp_tx_syn ? FFCP_TYPE_SYN : FFCP_TYPE_MSG) : FFCP_TYPE_ACK;
assign ffcp_tx_index = config_transmit ? ffcp_msg_index : ffcp_ack_index;

////// UART RX => RAM (TRANSMIT CONFIGURATION)

wire uart_cts;
// request laptop to stop transmitting when the packet buffer is
// almost full, or when we manually override cts
assign uart_cts = sw2 || pb_almost_full;
assign UART_CTS = uart_cts;
wire [7:0] uart_rx_out;
wire uart_rx_outclk;
uart_rx_fast_driver uart_rx_inst(
	.clk(clk), .clk_120mhz(clk_120mhz), .rst(rst),
	.rxd(UART_TXD_IN), .out(uart_rx_out), .outclk(uart_rx_outclk));
wire uart_rx_active;
// reset downstream modules if nothing is received for 1ms, and not
// because we told upstream to pause transmitting
pulse_extender #(.EXTEND_LEN(50000)) uart_rx_active_pe(
	.clk(clk), .rst(rst),
	.in(uart_rx_outclk || uart_cts), .out(uart_rx_active));
wire uart_rx_downstream_rst;
assign uart_rx_downstream_rst = rst || !uart_rx_active;

// streams data from uart to ram
reg [clog2(FGP_LEN)-1:0] uart_rx_cnt = 0;
assign uart_ram_waddr = {pb_tail, uart_rx_cnt};
assign uart_ram_we = uart_rx_outclk;
assign uart_ram_win = uart_rx_out;
// when we have received a complete fgp packet, advance the tail and
// start streaming to the next partition in the packet buffer queue
assign pb_advance_tail_tx = uart_rx_outclk && uart_rx_cnt == FGP_LEN-1;
always @(posedge clk) begin
	if (uart_rx_downstream_rst)
		uart_rx_cnt <= 0;
	else if (uart_rx_outclk)
		uart_rx_cnt <= pb_advance_tail_tx ? 0 : uart_rx_cnt + 1;
end
assign pb_advance_head_tx = 1'b0;

////// UART TX <= RAM/VRAM

wire uart_tx_inclk, uart_tx_readclk;
wire [BYTE_LEN-1:0] uart_tx_in;
wire uart_tx_start;
assign uart_tx_start = btnc;
// if config_transmit is set, stream debug output from vram
// otherwise, stream it from ram
wire uart_sfm_ram_readclk;
wire [clog2(RAM_SIZE)-1:0] uart_sfm_ram_raddr;
stream_from_memory uart_sfm_inst(
	.clk(clk), .rst(rst), .start(uart_tx_start),
	.read_start(0), .read_end(config_transmit ? VRAM_SIZE : RAM_SIZE),
	.readclk(uart_tx_readclk),
	.ram_outclk(config_transmit ? uart_vram_outclk : uart_ram_outclk),
	.ram_out(config_transmit ? uart_vram_out[BYTE_LEN-1:0] : uart_ram_out),
	.ram_readclk(uart_sfm_ram_readclk), .ram_raddr(uart_sfm_ram_raddr),
	.outclk(uart_tx_inclk), .out(uart_tx_in));
assign uart_vram_readclk = uart_sfm_ram_readclk;
assign uart_ram_readclk = uart_sfm_ram_readclk;
assign uart_vram_raddr = uart_sfm_ram_raddr;
assign uart_ram_raddr = uart_sfm_ram_raddr;
assign uart_vram_rst = uart_tx_start;
assign uart_ram_rst = uart_tx_start;
uart_tx_fast_stream_driver uart_tx_inst(
	.clk(clk), .clk_120mhz(clk_120mhz), .rst(rst), .start(uart_tx_start),
	.inclk(uart_tx_inclk), .in(uart_tx_in), .txd(UART_RXD_OUT),
	.upstream_readclk(uart_sfm_readclk));
assign uart_tx_readclk = 1'b1;

////// VRAM => VGA (RECEIVE CONFIGURATION)

graphics_main graphics_main_inst(
	.clk(clk), .rst(rst), .blank(blank),
	.vga_x(vga_x), .vga_y(vga_y),
	.vga_hsync_in(vga_hsync_predelay), .vga_vsync_in(vga_vsync_predelay),
	.ram_outclk(vga_vram_outclk), .ram_out(vga_vram_out),
	.ram_readclk(vga_vram_readclk), .ram_raddr(vga_vram_raddr),
	.vga_col(vga_col),
	.vga_hsync_out(vga_hsync), .vga_vsync_out(vga_vsync));

////// DEBUGGING SIGNALS

wire aes_rst_pe;
pulse_extender aes_rst_pe_inst(
	.clk(clk), .rst(rst), .in(aes_rst), .out(aes_rst_pe));

wire blink;
blinker blinker_inst(
	.clk(clk), .rst(rst),
	.enable(1), .out(blink));

assign LED = {
	SW[15:6],
	blink,
	aes_rst_pe,
	cbc_enable,
	uart_cts,
	config_transmit,
	rst
};

assign hex_display_data = {
	pb_head[3:0],
	ram_raddr[clog2(RAM_SIZE)-12+:12],
	pb_tail[3:0],
	ram_waddr[clog2(RAM_SIZE)-12+:12]
};

assign JB = {
	8'h0
};

endmodule
