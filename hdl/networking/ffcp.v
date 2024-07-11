// FFCP: FGPA Flow Control Protocol
// simple invented-here protocol for flow control
// format: [ type (2 bits) | index (6 bits) | FGP data (769 bytes) ]
// type is 0 (syn), 1 (msg) or 2 (ack)
// The index works like the sequence number in TCP
// FFCP's flow control is a very simplified version of TCP's, where
// the window size is fixed and data flows in only one direction
// FGP data is omitted in ack

// produces outputs with a latency of LATENCY
// essentially the same structure as eth_tx
module ffcp_tx #(
	parameter LATENCY = PACKET_SYNTH_ROM_LATENCY) (
	input clk, rst, start, in_done,
	input inclk, input [BYTE_LEN-1:0] in,
	// ffcp_type/index are valid only when start is asserted
	// these are the values written to the FFCP header
	input [FFCP_TYPE_LEN-1:0] ffcp_type,
	input [FFCP_INDEX_LEN-1:0] ffcp_index,
	input readclk,
	output outclk, output [BYTE_LEN-1:0] out,
	output upstream_readclk, done);

`include "networking.vh"

// the metadata is the type and index combined into a single byte
reg [BYTE_LEN-1:0] metadata_buf;
// the type field in metadata_buf
wire [FFCP_TYPE_LEN-1:0] metadata_buf_type;
assign metadata_buf_type = metadata_buf[FFCP_INDEX_LEN+:FFCP_TYPE_LEN];
wire is_ack;
assign is_ack = metadata_buf_type == FFCP_TYPE_ACK;

wire outclk_pd;
wire [BYTE_LEN-1:0] out_pd, out_premux;
assign out =
	inclk ? in :
	out_premux;
wire outclk_internal;
assign outclk = outclk_internal || inclk;
delay #(.DELAY_LEN(LATENCY)) outclk_delay(
	.clk(clk), .rst(rst || start),
	.in(outclk_pd), .out(outclk_internal));
delay #(.DELAY_LEN(LATENCY),
	.DATA_WIDTH(BYTE_LEN)) out_delay(
	.clk(clk), .rst(rst || start), .in(out_pd), .out(out_premux));

localparam STATE_METADATA = 0;
localparam STATE_DATA = 1;

reg [0:0] state = STATE_METADATA;
reg [9:0] cnt = 0;

wire metadata_done;
assign metadata_done =
	state == STATE_METADATA && cnt == FFCP_METADATA_LEN-1;
// if we're transmitting an ack, then skip the entire payload stage
// by asserting done
wire ack_done;
delay #(.DELAY_LEN(LATENCY)) done_delay(
	.clk(clk), .rst(rst || start),
	.in(readclk && metadata_done && is_ack), .out(ack_done));
assign done = in_done || ack_done;

assign upstream_readclk = (state == STATE_DATA) && readclk;
assign outclk_pd = (state == STATE_METADATA) && readclk;
assign out_pd =
	(state == STATE_METADATA) ? metadata_buf : 0;

always @(posedge clk) begin
	if (rst || start) begin
		state <= STATE_METADATA;
		metadata_buf <= {ffcp_type, ffcp_index};
		cnt <= 0;
	end else if (readclk) begin
		if (metadata_done) begin
			state <= STATE_DATA;
			cnt <= 0;
		end else
			cnt <= cnt + 1;
	end
end

endmodule

module ffcp_rx(
	input clk, rst, inclk,
	input [BYTE_LEN-1:0] in,
	output done,
	// ffcp_type/index valid only when metadata_outclk is asserted
	output metadata_outclk,
	output [FFCP_TYPE_LEN-1:0] ffcp_type,
	output [FFCP_INDEX_LEN-1:0] ffcp_index,
	output outclk, output [BYTE_LEN-1:0] out);

`include "networking.vh"

localparam STATE_METADATA = 0;
localparam STATE_DATA = 1;

reg [0:0] state = STATE_METADATA;
reg [9:0] cnt = 0;

wire metadata_done;
assign metadata_done =
	state == STATE_METADATA && cnt == FFCP_METADATA_LEN-1;
assign done = inclk && (
	(metadata_done && in[FFCP_INDEX_LEN+:FFCP_TYPE_LEN] == FFCP_TYPE_ACK) ||
	(state == STATE_DATA && cnt == FFCP_DATA_LEN-1));
assign metadata_outclk = inclk && metadata_done;
assign ffcp_type = in[FFCP_INDEX_LEN+:FFCP_TYPE_LEN];
assign ffcp_index = in[0+:FFCP_INDEX_LEN];
assign outclk = inclk && state == STATE_DATA;
assign out = in;

always @(posedge clk) begin
	if (rst || done) begin
		state <= STATE_METADATA;
		cnt <= 0;
	end else if (inclk) begin
		if (metadata_done) begin
			state <= STATE_DATA;
			cnt <= 0;
		end else
			cnt <= cnt + 1;
	end
end

endmodule

// manages flow control for the receiving end
// the index used in the FFCP header in this case is the same as the
// offset where the data lives in the packet buffer queue
// there are two downstreams here -- the packet transmission pipeline for
// acks, and the FGP DMA pipeline for commits

// specifically, when a packet is received, a bit is set indicating that
// it has been received; if it is at the head of the receive window,
// the packet is committed to the FGP DMA pipeline; when the commit is
// done, the window is advanced, and an ack is sent out if there are
// no more packets to commit

module ffcp_rx_server(
	// syn indicates that a syn is received
	input clk, rst, syn,
	// inclk indicates that a packet has been received with a sequence
	// number (FFCP index field) given by in_index
	input inclk, input [FFCP_INDEX_LEN-1:0] in_index,
	// downstream_done indicates that downstream has finished sending an
	// ack, and we can send another one
	input downstream_done,
	// commit_done indicates that downstream has finished committing a
	// packet, and we can commit another one
	input commit_done,
	// when commit is asserted, downstream processes the packet at the
	// index given by commit_index as part of the data stream
	// packets should be committed in order, except in the case of syn
	output commit, output [FFCP_INDEX_LEN-1:0] commit_index,
	// outclk indicates that we should send an ack for the index given by
	// out_index
	output outclk, output [FFCP_INDEX_LEN-1:0] out_index);

`include "networking.vh"

// bit vector recording whether we have received the packet with each
// sequence number in the window
reg received[FFCP_BUFFER_LEN-1:0];
// used in the reset procedure, which clears the received vector
reg [clog2(FFCP_BUFFER_LEN)-1:0] rst_cnt = 0;
// the start of the receive window
reg [clog2(FFCP_BUFFER_LEN)-1:0] queue_head;
wire curr_received;
assign curr_received = received[queue_head];
wire rst_done;
assign rst_done = rst_cnt == FFCP_BUFFER_LEN-1;

reg downstream_rdy = 1;
always @(posedge clk) begin
	if (rst)
		downstream_rdy <= 1;
	// if we send an ack with outclk, downstream won't be ready until
	// it asserts done
	else if (outclk)
		downstream_rdy <= 0;
	else if (downstream_done)
		downstream_rdy <= 1;
end

reg commit_rdy = 1;
always @(posedge clk) begin
	if (rst)
		commit_rdy <= 1;
	// if we request a commit, downstream won't be ready until
	// it asserts done
	else if (commit)
		commit_rdy <= 0;
	else if (commit_done)
		commit_rdy <= 1;
end

// ignore all messages other than those in receive window
// be careful of wraparound
wire ignore, receiving;
// offset in the receive window of the incoming packet
// use an explicitly declared net to truncate before comparison,
// so that it will always be positive (this is a circular buffer,
// so a negative offset is equivalent to a large positive one)
wire [clog2(FFCP_BUFFER_LEN)-1:0] in_index_head_off;
assign in_index_head_off = in_index - queue_head;
assign ignore = in_index_head_off >= FFCP_WINDOW_LEN;
assign receiving = inclk && !ignore;

// ack_buf indicates that we should send an ack as soon as we get
// the chance to
// try to ack as many indices as possible, so wait until the queue head
// has advanced past all received packets before acking
// also wait until self and downstream are ready
// also wait until any pending commits have finished, because the window
// is only advanced after a commit has completed, but curr_received
// is not asserted in the interim
reg ack_buf = 0;
assign outclk = !curr_received && commit_rdy &&
	downstream_rdy && ack_buf &&
	!rst && !syn && rst_done && !receiving;
// ack index should be the first index that we have not yet received
// when curr_received is not asserted, this is just the head of the window
assign out_index = queue_head;
// only commit when the packet at the head of the window is received
// wait until self and downstream are ready
assign commit = !outclk && curr_received && commit_rdy &&
	!rst && !syn && rst_done && !receiving;
assign commit_index = queue_head;

always @(posedge clk) begin
	if (rst || syn) begin
		queue_head <= 0;
		rst_cnt <= 0;
		ack_buf <= syn;
		// clear this now so we don't need to waste a rst_cnt bit for
		// an extra clear cycle
		received[FFCP_BUFFER_LEN-1] <= 0;
	end else if (!rst_done) begin
		// if ack_buf is set, then the reset was because of a syn, so
		// the first packet has been received
		received[rst_cnt] <= (ack_buf && rst_cnt == 0) ? 1 : 0;
		rst_cnt <= rst_cnt + 1;
	end else begin
		if (commit_done)
			queue_head <= queue_head + 1;
		if (receiving)
			received[in_index] <= 1;
		else if (outclk)
			// outclk indicates that an ack has been transmitted, so
			// clear ack_buf
			ack_buf <= 0;
		else if (commit) begin
			// if we commit a packet, then we should ack it, but only
			// after the commit is done and the window is advanced
			ack_buf <= 1;
			received[queue_head] <= 0;
		end
	end
end

endmodule

// the ffcp_queue manages the packet buffer (PB), intended for use
// with ffcp_tx_server or ffcp_rx_server
// we only need to be able to advance the head/tail by one index each time,
// or overwrite the head
module ffcp_queue(
	input clk, rst,
	input advance_head, advance_tail,
	// inclk indicates that we should overwrite the head
	// in_head is what we should overwrite the head to
	input inclk, input [clog2(PB_QUEUE_LEN)-1:0] in_head,
	output almost_full,
	output reg [clog2(PB_QUEUE_LEN)-1:0] head, tail);

`include "networking.vh"

wire [clog2(PB_QUEUE_LEN)-1:0] space_used = tail - head;
assign almost_full = space_used >= PB_QUEUE_ALMOST_FULL_THRES;

always @(posedge clk) begin
	if (rst) begin
		tail <= 0;
		head <= 0;
	end else begin
		if (inclk)
			head <= in_head;
		else if (advance_head)
			head <= head + 1;
		if (advance_tail)
			tail <= tail + 1;
	end
end

endmodule

// keeps track of acknowledgement from receiving FPGA
// ensures that packets only packets up to WINDOW_LEN after the last
// ack are transmitted
// cycles through the transmit window every RESEND_TIMEOUT if no acks
// are received
// starts an entirely new stream if no acks have been received for
// RESYN_TIMEOUT
module ffcp_tx_server(
	input clk, rst,
	// the packet buffer queue head follows the ffcp_tx_server's head,
	// but indexes into the packet buffer queue instead of the
	// transmit sequence numbers window
	// the packet buffer queue tail points to (one after) the last packet
	// that has been received from the laptop
	input [clog2(PB_QUEUE_LEN)-1:0] pb_head, pb_tail,
	input downstream_done,
	// inclk indicates that a packet has been received with sequence number
	// (FFCP index) given by in_index
	input inclk, input [FFCP_INDEX_LEN-1:0] in_index,
	// outclk indicates that we should send a packet with sequence number
	// given by out_index, with payload in the packet buffer queue
	// partition given by out_buf_pos; if out_syn is set, this packet
	// should additionally be a syn instead of a msg
	output outclk, out_syn,
	output [FFCP_INDEX_LEN-1:0] out_index,
	output [clog2(PB_QUEUE_LEN)-1:0] out_buf_pos,
	// the pb outputs are the interface to ffcp_queue
	// outclk_pb requests the ffcp_queue head to be overwritten with
	// out_pb_head
	output outclk_pb,
	output [clog2(PB_QUEUE_LEN)-1:0] out_pb_head);

`include "networking.vh"

reg downstream_rdy = 1;
always @(posedge clk) begin
	if (rst)
		downstream_rdy <= 1;
	// if we send an ack with outclk, downstream won't be ready until
	// it asserts done
	else if (outclk)
		downstream_rdy <= 0;
	else if (downstream_done)
		downstream_rdy <= 1;
end

// the head of the transmit window
// this is different from the head of the packet buffer queue,
// which is a separate queue that buffers packets from the laptop
// except in the case of a syn, we want the queue_head and packet buffer
// queue head to advance at the same time -- the queue_head advances
// when we receive an ack for a packet, indicating that we no longer
// need the packet in the packet buffer queue
reg [clog2(FFCP_BUFFER_LEN)-1:0] queue_head = 0;
// index in the transmit window of the packet that we are transmitting
// (or just transmitted)
reg [clog2(FFCP_BUFFER_LEN)-1:0] curr_index = 0;

// (one more than) the end of the transmit window
// used to ensure that the addition wraps around (i.e. is truncated)
// properly for correct comparison
wire [clog2(FFCP_BUFFER_LEN)-1:0] window_end;
wire at_end;
assign window_end = queue_head + FFCP_WINDOW_LEN;
// offset from the packet buffer queue head where the payload of the
// packet that we are transmitting is stored
wire [clog2(PB_QUEUE_LEN)-1:0] curr_index_pb;
// this is, apart from an offset of pb_head - queue_head, the same as
// curr_index
assign curr_index_pb = curr_index - queue_head + pb_head;
// we have transmitted all packets in the current cycle if we are
// at the end of the transmit window, or there are no more packets
// to transmit
assign at_end = curr_index == window_end || curr_index_pb == pb_tail;

// ignore all acks other than those in transmit window
// be careful of wraparound
wire ignore, receiving;
wire [clog2(FFCP_BUFFER_LEN)-1:0] in_index_head_off;
// offset in the transmit window of the incoming ack
// use an explicitly declared net to truncate before comparison,
// so that it will always be positive (this is a circular buffer,
// so a negative offset is equivalent to a large positive one)
assign in_index_head_off = in_index - queue_head;
assign ignore = in_index_head_off >= FFCP_WINDOW_LEN;
assign receiving = inclk && !ignore;

// overwrite the packet buffer queue head when an ack is received
assign outclk_pb = receiving;
assign out_pb_head = in_index - queue_head + pb_head;

// syn_buf indicates that the next packet sent should be a syn
// first packet should be a syn once reset is done
reg syn_buf = 1;
assign out_syn = syn_buf && out_index == 0;
assign out_index = curr_index;
assign out_buf_pos = curr_index - queue_head + pb_head;
assign outclk = !rst && downstream_rdy && !at_end;

localparam TESTING = 0;
// unit test values are 4 and 20
localparam RESEND_TIMEOUT = TESTING ? 100 : 500000;
localparam RESYN_TIMEOUT = TESTING ? 60000 : 50000000;

// use pulse extenders as timers
// resyn indicates that the data stream should be reset
wire resend_disable, resyn_disable, resyn;
// wait for 10ms before trying again
pulse_extender #(.EXTEND_LEN(RESEND_TIMEOUT)) resend_timer (
	.clk(clk), .rst(rst), .in(!at_end), .out(resend_disable));
// wait for 1s before trying to re-establish the connection
pulse_extender #(.EXTEND_LEN(RESYN_TIMEOUT)) resyn_timer (
	.clk(clk), .rst(rst), .in(inclk), .out(resyn_disable));
// only assert resyn for one clock cycle, don't resyn again until
// we hear an ack from the receiving FPGA
pulse_generator resyn_pg (
	.clk(clk), .rst(rst), .in(!resyn_disable), .out(resyn));

// difference between in_index and curr_index, but truncated to
// take care of wraparound
wire [clog2(FFCP_BUFFER_LEN)-1:0] in_index_curr_index_off;
assign in_index_curr_index_off = in_index - curr_index;

always @(posedge clk) begin
	// reset is similar to resyn since in both cases we are
	// starting a new data stream
	if (rst || resyn) begin
		queue_head <= 0;
		curr_index <= 0;
		syn_buf <= 1;
	end else begin
		if (receiving) begin
			// once we get an ack, we no longer want to syn
			syn_buf <= 0;
			// move the transmit window up to the ack index
			queue_head <= in_index;
		end
		// if the transmit window has shifted beyond the packet
		// we're currently transmitting, just skip ahead
		if (receiving && in_index_curr_index_off < FFCP_WINDOW_LEN)
			curr_index <= in_index;
		// when we transmit a packet, go to the next packet
		else if (outclk)
			curr_index <= curr_index + 1;
		// when the resend timeout expires, go back to the head of the
		// transmit window
		else if (!resend_disable)
			curr_index <= queue_head;
	end
end

endmodule
