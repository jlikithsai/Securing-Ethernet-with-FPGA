`timescale 1ns / 1ps

module test_crc();

`include "params.vh"

localparam RAM_SIZE = PACKET_SYNTH_ROM_SIZE;

reg clk = 0;
// 50MHz clock
initial forever #10 clk = ~clk;

reg rst = 1;
wire read_req;
reg [clog2(RAM_SIZE)-1:0] read_addr = 0;
wire read_ready;
wire [BYTE_LEN-1:0] read_out;
packet_synth_rom_driver packet_synth_rom_driver_inst(
	.clk(clk), .rst(rst), .readclk(read_req), .raddr(read_addr),
	.outclk(read_ready), .out(read_out));
reg done_in = 0;
wire [1:0] dibit_out;
wire byte_clk, done_out;
wire btd_idle;
bytes_to_dibits btd_inst(
	.clk(clk), .rst(rst), .inclk(read_ready),
	.in(read_out), .in_done(done_in),
	.readclk(1'b1),
	.out(dibit_out), .outclk(byte_clk), .rdy(btd_idle),
	.done(done_out));
wire [31:0] crc;
crc32 crc32_inst(
	.clk(clk), .rst(rst), .shift(0),
	.inclk(byte_clk), .in(dibit_out), .out(crc));

reg reading = 0;
reg [clog2(BYTE_LEN)-2:0] dibit_cnt;
always @(posedge clk) begin
	if (rst)
		dibit_cnt = 0;
	else if (reading) begin
		if (dibit_cnt == BYTE_LEN/2-1)
			read_addr <= read_addr + 1;
		dibit_cnt <= dibit_cnt + 1;
	end
end
assign read_req = reading && dibit_cnt == 0;

initial begin
	#100
	rst = 0;

	// reset sequence
	#400

	reading = 1;
	// read out sample packet
	// 62 bytes * 4 dibits * 20ns
	#4960
	reading = 0;

	#100

	$stop();
end

endmodule

module test_ipv4_checksum();

`include "params.vh"

reg clk = 0;
// 50MHz clock
initial forever #10 clk = ~clk;

localparam IN_LEN = 20 * BYTE_LEN;
reg [IN_LEN-1:0] in = 160'h45000166718a00008011000000000000ffffffff;

reg rst = 1;
reg inclk = 0;
wire [2*BYTE_LEN-1:0] checksum;

ipv4_checksum ipv4_checksum_inst(
	.clk(clk), .rst(rst),
	.inclk(inclk), .in(in[IN_LEN-BYTE_LEN+:BYTE_LEN]),
	.out(checksum));

always @(posedge clk) begin
	if (inclk)
		in <= {in[0+:IN_LEN-BYTE_LEN], 8'h0};
end

initial begin
	#100
	rst = 0;
	inclk = 1;

	#((IN_LEN/BYTE_LEN + 2)*20)

	$stop();
end

endmodule

module test_packet_synth();

`include "params.vh"
`include "packet_synth_rom_layout.vh"

reg clk_100mhz = 0;
// 100MHz clock
initial forever #5 clk_100mhz = ~clk_100mhz;

wire clk;
clk_wiz_0 clk_wiz_inst(
	.reset(1'b0),
	.clk_in1(clk_100mhz),
	.clk_out1(clk));

localparam RAM_SIZE = PACKET_SYNTH_ROM_SIZE;
reg rst = 1, start = 0;
wire eth_tx_inclk, eth_tx_outclk, eth_tx_done;
wire [BYTE_LEN-1:0] eth_tx_in;
wire [1:0] eth_tx_out;
wire rom1_readclk, rom2_readclk, rom1_outclk, rom2_outclk;
wire [clog2(RAM_SIZE)-1:0] rom1_raddr, rom2_raddr;
wire [BYTE_LEN-1:0] rom1_out, rom2_out;
packet_synth_rom_driver psr_driv_1(
	.clk(clk), .rst(rst),
	.readclk(rom1_readclk), .raddr(rom1_raddr),
	.outclk(rom1_outclk), .out(rom1_out));
packet_synth_rom_driver psr_driv_2(
	.clk(clk), .rst(rst),
	.readclk(rom2_readclk), .raddr(rom2_raddr),
	.outclk(rom2_outclk), .out(rom2_out));
wire sfm_readclk, sfm_done, sfm_outclk;
wire [BYTE_LEN-1:0] sfm_out;
stream_from_memory #(.RAM_SIZE(RAM_SIZE),
	.RAM_READ_LATENCY(PACKET_SYNTH_ROM_LATENCY)) sfm_inst(
	.clk(clk), .rst(rst), .start(start),
	.read_start(SAMPLE_IMG_DATA_OFF),
	.read_end(SAMPLE_IMG_DATA_OFF + SAMPLE_IMG_DATA_LEN),
	.readclk(sfm_readclk),
	.ram_outclk(rom1_outclk), .ram_out(rom1_out),
	.ram_readclk(rom1_readclk), .ram_raddr(rom1_raddr),
	.outclk(sfm_outclk), .out(sfm_out), .done(sfm_done));
wire fgp_readclk, fgp_done;
fgp_tx fgp_tx_inst(
	.clk(clk), .rst(rst), .start(start), .in_done(sfm_done),
	.inclk(sfm_outclk), .in(sfm_out),
	// set an arbitrary offset for testing
	.offset(8'hc), .readclk(fgp_readclk),
	.outclk(eth_tx_inclk), .out(eth_tx_in),
	.upstream_readclk(sfm_readclk), .done(fgp_done));
eth_tx eth_tx_inst(
	.clk(clk), .rst(rst), .start(start), .in_done(fgp_done),
	.inclk(eth_tx_inclk), .in(eth_tx_in),
	.ram_outclk(rom2_outclk), .ram_out(rom2_out),
	.ram_readclk(rom2_readclk), .ram_raddr(rom2_raddr),
	.outclk(eth_tx_outclk), .out(eth_tx_out),
	.upstream_readclk(fgp_readclk), .done(eth_tx_done));

initial begin
	#500
	rst = 0;
	start = 1;
	#20
	start = 0;

	// bytes * dibits/byte * ns/dibit
	#(1512 * 4 * 20)

	#400

	$stop();
end

endmodule

module test_packet_parse();

`include "networking.vh"
`include "packet_synth_rom_layout.vh"

reg clk = 0;
// 50MHz clock
initial forever #10 clk = ~clk;

localparam RAM_SIZE = PACKET_SYNTH_ROM_SIZE;

reg rst = 1, start = 0;
wire rom_readclk, rom_outclk;
wire [clog2(RAM_SIZE)-1:0] rom_raddr;
wire [BYTE_LEN-1:0] rom_out;
wire sfm_readclk;
wire btd_inclk, btd_in_done;
wire [BYTE_LEN-1:0] btd_in;
wire eth_parse_inclk, eth_parse_in_done, eth_parse_outclk, eth_parse_err;
wire [1:0] eth_parse_in;
wire [BYTE_LEN-1:0] eth_parse_out;
wire fgp_parse_done;
wire btc_inclk, btc_outclk;
wire [BYTE_LEN-1:0] btc_in;
wire [COLOR_LEN-1:0] btc_out;
wire stm_setoff_req;
wire [clog2(VIDEO_CACHE_RAM_SIZE)-1:0] stm_setoff_val;
wire vram_readclk, vram_outclk, vram_we;
wire [clog2(VIDEO_CACHE_RAM_SIZE)-1:0] vram_raddr, vram_waddr;
wire [COLOR_LEN-1:0] vram_out, vram_win;
packet_synth_rom_driver psr_inst(
	.clk(clk), .rst(rst),
	.readclk(rom_readclk), .raddr(rom_raddr),
	.outclk(rom_outclk), .out(rom_out));
stream_from_memory #(.RAM_SIZE(RAM_SIZE),
	.RAM_READ_LATENCY(PACKET_SYNTH_ROM_LATENCY)) sfm_inst(
	.clk(clk), .rst(rst), .start(start),
	.read_start(SAMPLE_FRAME_OFF),
	.read_end(SAMPLE_FRAME_OFF + SAMPLE_FRAME_LEN),
	.readclk(sfm_readclk),
	.ram_outclk(rom_outclk), .ram_out(rom_out),
	.ram_readclk(rom_readclk), .ram_raddr(rom_raddr),
	.outclk(btd_inclk), .out(btd_in), .done(btd_in_done));
bytes_to_dibits_coord_buf btd_inst(
	.clk(clk), .rst(rst || start),
	.inclk(btd_inclk), .in(btd_in), .in_done(btd_in_done),
	.downstream_rdy(1), .readclk(sfm_readclk),
	.outclk(eth_parse_inclk), .out(eth_parse_in),
	.done(eth_parse_in_done));
wire eth_rx_ethertype_outclk;
wire [ETH_ETHERTYPE_LEN*BYTE_LEN-1:0] eth_rx_ethertype_out;
eth_rx eth_rx_inst(
	.clk(clk), .rst(rst),
	.inclk(eth_parse_inclk), .in(eth_parse_in),
	.in_done(eth_parse_in_done),
	.downstream_done(fgp_parse_done),
	.outclk(eth_parse_outclk), .out(eth_parse_out),
	.ethertype_outclk(eth_rx_ethertype_outclk),
	.ethertype_out(eth_rx_ethertype_out),
	.err(eth_parse_err));
wire eth_parse_downstream_rst;
assign eth_parse_downstream_rst = rst || eth_parse_err;
fgp_rx fgp_rx_inst(
	.clk(clk), .rst(eth_parse_downstream_rst),
	.inclk(eth_parse_outclk), .in(eth_parse_out),
	.done(fgp_parse_done),
	.setoff_req(stm_setoff_req), .setoff_val(stm_setoff_val),
	.outclk(btc_inclk), .out(btc_in));
bytes_to_colors btc_inst(
	.clk(clk), .rst(eth_parse_downstream_rst),
	.inclk(btc_inclk), .in(btc_in),
	.outclk(btc_outclk), .out(btc_out));
stream_to_memory
	#(.RAM_SIZE(VIDEO_CACHE_RAM_SIZE), .WORD_LEN(COLOR_LEN)) stm_inst(
	.clk(clk), .rst(eth_parse_downstream_rst),
	.setoff_req(stm_setoff_req), .setoff_val(stm_setoff_val),
	.inclk(btc_outclk), .in(btc_out),
	.ram_we(vram_we), .ram_waddr(vram_waddr),
	.ram_win(vram_win));
video_cache_ram_driver vram_driv_inst(
	.clk(clk), .rst(rst),
	.readclk(vram_readclk), .raddr(vram_raddr),
	.we(vram_we), .waddr(vram_waddr), .win(vram_win),
	.outclk(vram_outclk), .out(vram_out));

initial begin
	#100
	rst = 0;
	start = 1;
	#20
	start = 0;
	#(SAMPLE_FRAME_LEN * 4 * 20)
	#400
	$stop();
end

endmodule

module test_ffcp_rx_server();

`include "networking.vh"

reg clk = 0;
// 50MHz clock
initial forever #10 clk = ~clk;

reg rst = 1, syn = 0, inclk = 0;
reg [FFCP_INDEX_LEN-1:0] in_index;
wire outclk, downstream_done;
wire [FFCP_INDEX_LEN-1:0] out_index;

delay delay_inst(
	.clk(clk), .rst(rst), .in(outclk), .out(downstream_done));

reg [FFCP_INDEX_LEN+3:0] cnt = 0;
reg use_cnt = 0;
always @(posedge clk) begin
	if (use_cnt)
		cnt <= cnt + 1;
end

wire [FFCP_INDEX_LEN-1:0] actual_in_index;
assign actual_in_index = use_cnt ? cnt[2+:FFCP_INDEX_LEN] : in_index;
wire actual_inclk;
assign actual_inclk = use_cnt ? (cnt[1:0] == 0) : inclk;

ffcp_rx_server ffcp_rx_serv_inst(
	.clk(clk), .rst(rst), .syn(syn),
	.inclk(actual_inclk), .in_index(actual_in_index),
	.downstream_done(downstream_done),
	.outclk(outclk), .out_index(out_index));

initial begin
	#200
	rst = 0;
	syn = 1;
	inclk = 1;
	in_index = 0;
	#20
	syn = 0;
	inclk = 0;
	#1400

	inclk = 1;
	in_index = 1;
	#20
	inclk = 0;
	#40

	inclk = 1;
	in_index = 2;
	#20
	inclk = 0;
	#40

	inclk = 1;
	in_index = 3;
	#20
	inclk = 0;
	#40

	inclk = 1;
	in_index = 3;
	#20
	inclk = 0;
	#40

	inclk = 1;
	in_index = 2;
	#20
	inclk = 0;
	#40

	inclk = 1;
	in_index = 6;
	#20
	inclk = 0;
	#40

	inclk = 1;
	in_index = 5;
	#20
	inclk = 0;
	#40

	inclk = 1;
	in_index = 4;
	#20
	inclk = 0;
	#100

	inclk = 1;
	in_index = 7;
	#20
	inclk = 0;
	#40

	#100
	use_cnt = 1;
	#(16*20*FFCP_BUFFER_LEN)

	$stop();
end

endmodule

module test_ffcp_tx_server();

`include "networking.vh"

reg clk = 0;
// 50MHz clock
initial forever #10 clk = ~clk;

reg rst = 1;
reg advance_tail = 0;
reg inclk = 0;
reg [FFCP_INDEX_LEN-1:0] in_index;

wire almost_full;
wire inclk_pb, downstream_done;
wire [clog2(PB_QUEUE_LEN)-1:0] in_pb_head;
wire [clog2(PB_QUEUE_LEN)-1:0] pb_head, pb_tail;
wire outclk, out_syn;
wire [FFCP_INDEX_LEN-1:0] out_index;
wire [clog2(PB_QUEUE_LEN)-1:0] out_buf_pos;
ffcp_tx_queue ffcp_tx_queue_inst (
	.clk(clk), .rst(rst),
	.advance_tail(advance_tail),
	.inclk(inclk_pb), .in_head(in_pb_head),
	.almost_full(almost_full),
	.head(pb_head), .tail(pb_tail));
ffcp_tx_server ffcp_tx_serv_inst (
	.clk(clk), .rst(rst),
	.pb_head(pb_head), .pb_tail(pb_tail),
	.downstream_done(downstream_done),
	.inclk(inclk), .in_index(in_index),
	.outclk(outclk), .out_syn(out_syn),
	.out_index(out_index), .out_buf_pos(out_buf_pos),
	.outclk_pb(inclk_pb), .out_pb_head(in_pb_head));
delay delay_inst (
	.clk(clk), .rst(rst), .in(outclk), .out(downstream_done));

initial begin
	#400
	rst = 0;
	#100
	advance_tail = 1;
	#20
	advance_tail = 0;
	#400
	advance_tail = 1;
	#100
	advance_tail = 0;
	#400
	inclk = 1;
	in_index = 1;
	advance_tail = 1;
	#20
	in_index = 2;
	#20
	in_index = 1;
	#20
	in_index = 5;
	#20
	inclk = 0;
	#20
	advance_tail = 0;
	#2000
	advance_tail = 1;
	#100
	inclk = 1;
	in_index = 3;
	advance_tail = 0;
	#20
	inclk = 0;
	#1000
	$stop();
end

endmodule
