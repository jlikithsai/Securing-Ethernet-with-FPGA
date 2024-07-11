// generate an ethernet frame on the level of bytes
// CRC needs to be generated on the level of dibits,
// which is handled in eth_tx
// expects payload and rom delay of PACKET_SYNTH_ROM_DELAY
// exposes readclk to out latency of PACKET_SYNTH_ROM_DELAY
module eth_body_tx #(
	// size of rom holding constants, e.g. mac addresses
	parameter RAM_SIZE = PACKET_SYNTH_ROM_SIZE) (
	input clk, rst, start, in_done,
	input inclk, input [BYTE_LEN-1:0] in,
	input readclk,
	input ram_outclk, input [BYTE_LEN-1:0] ram_out,
	output ram_readclk, output reg [clog2(RAM_SIZE)-1:0] ram_raddr,
	output outclk, output [BYTE_LEN-1:0] out,
	output upstream_readclk, done);

`include "packet_synth_rom_layout.vh"
`include "networking.vh"

localparam STATE_IDLE = 0;
localparam STATE_MAC_DST = 1;
localparam STATE_MAC_SRC = 2;
localparam STATE_ETHERTYPE = 3;
localparam STATE_PAYLOAD = 4;

// "pre-delayed" versions of output data generated internally by this
// module, to be combined with ram and upstream read results
wire outclk_pd;
wire [BYTE_LEN-1:0] out_pd;
// out_premux is out, but may be overwritten with ram read result
wire [BYTE_LEN-1:0] out_premux;
// if we requested a payload (upstream) read, then we want to use the
// payload read result instead
// if we requested a read from ram, then we want to use the ram read
// result instead
assign out =
	inclk ? in :
	ram_outclk ? ram_out :
	out_premux;

// outclk for data that is generated internally by this module
wire outclk_internal;
assign outclk = outclk_internal || ram_outclk || inclk;
delay #(.DELAY_LEN(PACKET_SYNTH_ROM_LATENCY)) outclk_delay(
	.clk(clk), .rst(rst || start),
	.in(outclk_pd), .out(outclk_internal));
delay #(.DELAY_LEN(PACKET_SYNTH_ROM_LATENCY),
	.DATA_WIDTH(BYTE_LEN)) out_delay(
	.clk(clk), .rst(rst || start), .in(out_pd), .out(out_premux));
assign done = in_done;

reg [2:0] state = STATE_IDLE;
// number of bytes transmitted for the current stage
reg [2:0] cnt;

// multiplex different sources of data
assign upstream_readclk = state == STATE_PAYLOAD && readclk;
assign ram_readclk = (
	(state == STATE_MAC_DST) ||
	(state == STATE_MAC_SRC) ||
	(state == STATE_ETHERTYPE)) &&
	readclk;
// these signals would be used if we generated any data internally
// we don't in this module, but keep this anyway to maintain a consistent
// implementation across different networking modules
assign outclk_pd = 0;
assign out_pd = 0;

always @(posedge clk) begin
	if (rst)
		state <= STATE_IDLE;
	else if (start) begin
		state <= STATE_MAC_DST;
		ram_raddr <= MAC_RECV_OFF;
		cnt <= 0;
	end else if (outclk) begin
		if (state == STATE_MAC_DST && cnt == ETH_MAC_LEN-1) begin
			cnt <= 0;
			state <= STATE_MAC_SRC;
			ram_raddr <= MAC_SEND_OFF;
		end else if (state == STATE_MAC_SRC && cnt == ETH_MAC_LEN-1) begin
			cnt <= 0;
			state <= STATE_ETHERTYPE;
			ram_raddr <= ETHERTYPE_FFCP_OFF;
		end else if (state == STATE_ETHERTYPE &&
				cnt == ETH_ETHERTYPE_LEN-1) begin
			state <= STATE_PAYLOAD;
		end else if (state == STATE_PAYLOAD && in_done) begin
			cnt <= 0;
			state <= STATE_IDLE;
		end else begin
			cnt <= cnt + 1;
			ram_raddr <= ram_raddr + 1;
		end
	end
end

endmodule

module crc32(
	input clk, rst,
	// allow application to reuse out as a shift register
	// when shift is asserted, shift the data on out by 2 bits
	input shift, inclk, input [1:0] in,
	output [31:0] out);

localparam CRC_INIT = 32'hffffffff;
// polynomial is reflected since we operate in
// least-significant-bit first for simplicity
localparam CRC_POLY = 32'hedb88320;

reg [31:0] curr;
// leave at least significant bit first, since crc will be
// shifted out from the end
assign out = ~curr;

// optimized dibit CRC step
// step1: XOR in both inputs at once
// step2: first division by poly
// step3: second division by poly
wire [31:0] step1, step2, step3;
assign step1 = {curr[2+:30], curr[0+:2] ^ in};
assign step2 = step1[1+:31] ^ (step1[0] ? CRC_POLY : 0);
assign step3 = step2[1+:31] ^ (step2[0] ? CRC_POLY : 0);

always @(posedge clk) begin
	if (rst)
		curr <= CRC_INIT;
	else if (shift)
		curr <= {2'b11, curr[2+:30]};
	else if (inclk)
		curr <= step3;
end

endmodule

// creates continuous dibit stream for an ethernet frame
module eth_tx #(
	// size of rom holding constants, e.g. mac addresses
	parameter RAM_SIZE = PACKET_SYNTH_ROM_SIZE) (
	input clk, rst, start, in_done,
	input inclk, input [BYTE_LEN-1:0] in,
	input ram_outclk, input [BYTE_LEN-1:0] ram_out,
	output ram_readclk,
	output [clog2(RAM_SIZE)-1:0] ram_raddr,
	output outclk, output [1:0] out,
	output upstream_readclk, done);

`include "networking.vh"

// main_rdy indicates that main processing is ready for the frame body
wire main_rdy;
wire eth_tx_readclk, eth_tx_outclk, eth_tx_done;
wire [BYTE_LEN-1:0] eth_tx_out;
wire btd_outclk, btd_done;
wire [1:0] btd_out;
wire crc_rst, crc_shift;
wire [31:0] crc_out;
eth_body_tx eth_tx_inst(
	.clk(clk), .rst(rst), .start(start), .in_done(in_done),
	.inclk(inclk), .in(in), .readclk(eth_tx_readclk),
	.ram_outclk(ram_outclk), .ram_out(ram_out),
	.ram_readclk(ram_readclk), .ram_raddr(ram_raddr),
	.outclk(eth_tx_outclk), .out(eth_tx_out),
	.upstream_readclk(upstream_readclk), .done(eth_tx_done));
bytes_to_dibits_coord_buf btd_inst(
	.clk(clk), .rst(rst || start),
	.inclk(eth_tx_outclk), .in(eth_tx_out), .in_done(eth_tx_done),
	.downstream_rdy(main_rdy), .upstream_readclk(eth_tx_readclk),
	.outclk(btd_outclk), .out(btd_out), .done(btd_done));
crc32 crc32_inst(
	.clk(clk), .rst(crc_rst), .shift(crc_shift),
	.inclk(btd_outclk), .in(btd_out), .out(crc_out));

localparam STATE_IDLE = 0;
// we need to transmit the preamble
localparam STATE_PREAMBLE = 1;
localparam STATE_BODY = 2;
localparam STATE_CRC = 3;
// "transmit" an inter-packet gap to ensure that packets are always
// sufficiently spaced apart
localparam STATE_GAP = 4;

reg [2:0] state = STATE_IDLE;
// number of dibits transmitted for the current stage
reg [5:0] cnt;

// sfd indicates that we have reached the end of the preamble
wire sfd, crc_done, gap_done;
// multiply by 4 since we're measuring in dibits
assign sfd = (state == STATE_PREAMBLE) && (cnt == ETH_PREAMBLE_LEN*4-1);
assign crc_done = (state == STATE_CRC) && (cnt == ETH_CRC_LEN*4-1);
assign crc_shift = state == STATE_CRC;
assign gap_done = (state == STATE_GAP) && (cnt == ETH_GAP_LEN*4-1);
assign out =
	(state == STATE_BODY) ? btd_out :
	sfd ? 2'b11 :
	(state == STATE_PREAMBLE) ? 2'b01 :
	crc_out[0+:2];
// reset the crc module when we enter the crc-protected region, which
// starts when the preamble ends
assign crc_rst = rst || sfd;
assign main_rdy = state == STATE_BODY;
assign done = gap_done;
assign outclk = btd_outclk ||
	(state == STATE_PREAMBLE) ||
	(state == STATE_CRC);

always @(posedge clk) begin
	if (rst)
		state <= STATE_IDLE;
	else if (start) begin
		cnt <= 0;
		state <= STATE_PREAMBLE;
	end else if (sfd)
		state <= STATE_BODY;
	else if (state == STATE_BODY && btd_done) begin
		state <= STATE_CRC;
		cnt <= 0;
	end else if (crc_done) begin
		state <= STATE_GAP;
		cnt <= 0;
	end else if (gap_done)
		state <= STATE_IDLE;
	else
		cnt <= cnt + 1;
end

endmodule

module eth_rx(
	input clk, rst, inclk,
	input [1:0] in, input in_done,
	// downstream_done must be asserted on the same cycle as outclk
	// on the last byte of payload processing for correct error detection
	input downstream_done,
	output outclk, output [BYTE_LEN-1:0] out,
	output ethertype_outclk,
	output [ETH_ETHERTYPE_LEN*BYTE_LEN-1:0] ethertype_out,
	// done is pulsed at the same time as the last dibit of a full packet,
	// not on the last byte presented on out, giving a chance for the
	// module to throw an error if the crc check fails
	// done is only pulsed when a complete frame has been received
	// without errors
	output err, done);

`include "networking.vh"

wire frame_rst;
// reset everything not just on rst but also when the flow of data breaks
assign frame_rst = rst || !inclk;

wire dtb_outclk, dtb_done;
wire [BYTE_LEN-1:0] dtb_out;
dibits_to_bytes dtb_inst(
	.clk(clk), .rst(frame_rst),
	.inclk(inclk), .in(in), .in_done(in_done),
	.outclk(dtb_outclk), .out(dtb_out), .done(dtb_done));
wire crc_shift;
wire [31:0] crc_out;
crc32 crc32_inst(
	.clk(clk), .rst(frame_rst), .shift(crc_shift),
	.inclk(inclk), .in(in), .out(crc_out));

localparam STATE_MAC_DST = 0;
localparam STATE_MAC_SRC = 1;
localparam STATE_ETHERTYPE = 2;
localparam STATE_PAYLOAD = 3;
localparam STATE_CRC = 4;
localparam STATE_DONE = 5;

reg [2:0] state = STATE_MAC_DST;
// records number of bytes received for the current stage
reg [2:0] cnt = 0;
// idle indicates that we're not currently processing a frame
reg idle = 1;
// throw an error if the flow of data breaks while we're processing a frame
assign err = (!idle && !inclk) ||
	// we should not be receiving additional data after the crc
	(state == STATE_DONE && inclk && in != 2'b00) ||
	// crc check
	(state == STATE_CRC && inclk && in != crc_out[1:0]);

assign out = dtb_out;
assign outclk = state == STATE_PAYLOAD && dtb_outclk;
wire ethertype_done;
assign ethertype_done =
	state == STATE_ETHERTYPE && cnt == ETH_ETHERTYPE_LEN-1;
wire crc_done;
assign crc_done =
	state == STATE_CRC && cnt == ETH_CRC_LEN-1;
// a crc error may be thrown on the last dibit, so check for that
// before asserting done
assign done = dtb_outclk && crc_done && !err;

// holds the shifted ethertype, so that the ethertype can be transmitted
// one byte at a time
reg [(ETH_ETHERTYPE_LEN-1)*BYTE_LEN-1:0] ethertype_shifted;
assign ethertype_outclk = dtb_outclk && ethertype_done;
assign ethertype_out = {ethertype_shifted, dtb_out};

assign crc_shift = inclk && state == STATE_CRC;

always @(posedge clk) begin
	if (frame_rst) begin
		state <= STATE_MAC_DST;
		cnt <= 0;
		idle <= 1;
	// stop processing packets immediately when an error is thrown
	end else if (err)
		state <= STATE_DONE;
	else if (dtb_outclk) begin
		if (state == STATE_MAC_DST && cnt == ETH_MAC_LEN-1) begin
			state <= STATE_MAC_SRC;
			cnt <= 0;
		end else if (state == STATE_MAC_SRC && cnt == ETH_MAC_LEN-1) begin
			state <= STATE_ETHERTYPE;
			cnt <= 0;
		end else if (ethertype_done)
			state <= STATE_PAYLOAD;
		// the length of the payload is determined by the downstream
		// module, as is standard in networking over ethernet
		else if (state == STATE_PAYLOAD && downstream_done) begin
			state <= STATE_CRC;
			cnt <= 0;
		end else if (crc_done) begin
			state <= STATE_DONE;
			idle <= 1;
		end else if (state != STATE_DONE) begin
			idle <= 0;
			cnt <= cnt + 1;
			ethertype_shifted <=
				ethertype_out[0+:(ETH_ETHERTYPE_LEN-1)*BYTE_LEN];
		end
	end
end

endmodule
