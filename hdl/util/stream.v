// convert a stream of words of size S_LEN to a stream of words
// of size L_LEN, where S_LEN and L_LEN are powers of 2
// packing is in little-endian order, as determined by ethernet
// no latency between in and out
module stream_pack #(
	parameter S_LEN = 1,
	parameter L_LEN = 2) (
	input clk, rst, inclk, input [S_LEN-1:0] in, input in_done,
	output outclk, output [L_LEN-1:0] out, output done);

`include "util.vh"

localparam PACK_RATIO = L_LEN/S_LEN;

// shift buffer used to pack small words into large ones
// don't need to store last small word
reg [L_LEN-S_LEN-1:0] shifted;
// number of small words received
reg [clog2(PACK_RATIO)-1:0] cnt = 0;

assign out = {in, shifted};
// data is valid on out when PACK_RATIO small words have been received
assign outclk = inclk && cnt == PACK_RATIO-1;
// last large word is presented when last small word is received
assign done = in_done;

always @(posedge clk) begin
	// usually we have cnt == 0 when in_done is asserted, but
	// reset just in case the data stream was incomplete
	if (rst || in_done)
		cnt <= 0;
	else if (inclk) begin
		// shift from left since we're assuming little-endian
		shifted <= {in, shifted[S_LEN+:L_LEN-2*S_LEN]};
		cnt <= cnt + 1;
	end
end

endmodule

// convert a stream of words of size L_LEN to a stream of words
// of size S_LEN, where S_LEN and L_LEN should be powers of 2
// no latency between in and out
// unpacking is in little-endian order, as determined by ethernet
// assumes that words are inserted no faster than once every
// PACK_RATIO clock cycles
module stream_unpack #(
	parameter S_LEN = 1,
	parameter L_LEN = 2) (
	input clk, rst, inclk, input [L_LEN-1:0] in, input in_done,
	// readclk requests for data to be presented on out, and is
	// not an actual clock
	input readclk,
	output outclk, output [S_LEN-1:0] out,
	// done is pulsed after in_done when buffer has been cleared
	output rdy, done);

`include "util.vh"

localparam PACK_RATIO = L_LEN/S_LEN;

// shift buffer used to unpack large words into small ones
// need to store entire large word, since readclk may not be asserted
// at the same time as inclk
reg [L_LEN-1:0] shifted;
// as a special case, if readclk and inclk are asserted at the same time,
// present the small word from in directly since there hasn't been time
// to store the large word in the shift buffer
assign out = inclk ? in[0+:S_LEN] : shifted[0+:S_LEN];
reg idle = 1;
assign rdy = idle;
assign outclk = (!idle || inclk) && readclk;

// current offset in large word
// we'd have finished processing the large word when cnt == PACK_RATIO-1
reg [clog2(PACK_RATIO)-1:0] cnt = 0;

// in_done_found indicates that in_done has been asserted,
// and we should assert done when the buffer clears
reg in_done_found = 0;
assign done = outclk && in_done_found && cnt == PACK_RATIO-1;

always @(posedge clk) begin
	if (rst) begin
		cnt <= 0;
		in_done_found <= 0;
		idle <= 1;
	end else begin
		if (inclk && in_done)
			in_done_found <= 1;
		else if (done)
			in_done_found <= 0;
		if (outclk) begin
			cnt <= cnt + 1;
			// if inclk is asserted at the same time as readclk
			// (and thus outclk), we present the first small word
			// immediately, so only store PACK_RATIO-1 small words
			// from the large word
			if (inclk) begin
				idle <= 0;
				shifted <= {{S_LEN{1'b0}}, in[S_LEN+:L_LEN-S_LEN]};
			end else begin
				shifted <= {{S_LEN{1'b0}}, shifted[S_LEN+:L_LEN-S_LEN]};
				if (cnt == PACK_RATIO-1)
					idle <= 1;
			end
		end else if (inclk) begin
			idle <= 0;
			shifted <= in;
		end
	end
end

endmodule

// convert a dibit stream to a bytestream
module dibits_to_bytes(
	input clk, rst, inclk, input [1:0] in, input in_done,
	output outclk, output [BYTE_LEN-1:0] out, output done);

`include "params.vh"

stream_pack #(.S_LEN(2), .L_LEN(BYTE_LEN)) pack_inst(
	.clk(clk), .rst(rst), .inclk(inclk), .in(in), .in_done(in_done),
	.outclk(outclk), .out(out), .done(done));

endmodule

// convert a bytestream to a dibit stream
module bytes_to_dibits(
	input clk, rst, inclk, input [BYTE_LEN-1:0] in, input in_done,
	input readclk,
	output outclk, output [1:0] out, output rdy, done);

`include "params.vh"

stream_unpack #(.S_LEN(2), .L_LEN(BYTE_LEN)) unpack_inst(
	.clk(clk), .rst(rst), .inclk(inclk), .in(in), .in_done(in_done),
	.readclk(readclk),
	.outclk(outclk), .out(out), .rdy(rdy), .done(done));

endmodule

// convert a bytestream to a stream of AES blocks
module bytes_to_blocks(
	input clk, rst, inclk, input [BYTE_LEN-1:0] in, input in_done,
	output outclk, output [BLOCK_LEN-1:0] out, output done);

`include "params.vh"

stream_pack #(.S_LEN(BYTE_LEN), .L_LEN(BLOCK_LEN)) pack_inst(
	.clk(clk), .rst(rst), .inclk(inclk), .in(in), .in_done(in_done),
	.outclk(outclk), .out(out), .done(done));

endmodule

// convert a stream of AES blocks to a bytestream
module blocks_to_bytes(
	input clk, rst, inclk, input [BLOCK_LEN-1:0] in, input in_done,
	input readclk,
	output outclk, output [BYTE_LEN-1:0] out, output rdy, done);

`include "params.vh"

stream_unpack #(.S_LEN(BYTE_LEN), .L_LEN(BLOCK_LEN)) unpack_inst(
	.clk(clk), .rst(rst), .inclk(inclk), .in(in), .in_done(in_done),
	.readclk(readclk),
	.outclk(outclk), .out(out), .rdy(rdy), .done(done));

endmodule

// convert a bytestream to a stream of 12-bit colors
// one clock cycle of latency between in and out
module bytes_to_colors(
	input clk, rst,
	input inclk, input [BYTE_LEN-1:0] in,
	output reg outclk, output reg [COLOR_LEN-1:0] out);

`include "params.vh"

// three states to convert three bytes into two colors
// state indicates number of bytes received for each three-byte block
reg [1:0] state = 0;
// stores the input from the previous inclk
reg [BYTE_LEN-1:0] prev_in;

always @(posedge clk) begin
	if (rst)
		state <= 0;
	else if (inclk) begin
		prev_in <= in;
		case (state)
		// if state == 1, combine previous input with first half of
		// current input
		1: begin
			outclk <= 1;
			out <= {prev_in, in[BYTE_LEN/2+:BYTE_LEN/2]};
		end
		// if state == 2, combine second half of previous input with
		// current input
		2: begin
			outclk <= 1;
			out <= {prev_in[0+:BYTE_LEN/2], in};
		end
		// if state == 0, do nothing since we don't have enough data yet
		default:
			outclk <= 0;
		endcase

		// cycle through three states
		if (state == 2)
			state <= 0;
		else
			state <= state + 1;
	end else
		outclk <= 0;
end

endmodule

// stream data out of memory
// starts only after start is asserted and then deasserted
module stream_from_memory #(
	parameter RAM_SIZE = PACKET_BUFFER_SIZE,
	parameter RAM_READ_LATENCY = PACKET_BUFFER_READ_LATENCY) (
	input clk, rst, start,
	// read_start and read_end only need to be valid when start is asserted
	// read_end points to one byte after the last byte
	input [clog2(RAM_SIZE)-1:0] read_start, read_end,
	input readclk,
	input ram_outclk, input [BYTE_LEN-1:0] ram_out,
	output ram_readclk,
	output [clog2(RAM_SIZE)-1:0] ram_raddr,
	output outclk, output [BYTE_LEN-1:0] out, output done);

`include "params.vh"

assign outclk = ram_outclk;
assign out = ram_out;

// save read_end since it might change after start is deasserted
reg [clog2(RAM_SIZE)-1:0] read_end_buf;
reg [clog2(RAM_SIZE)-1:0] curr_addr;

// disambiguate reading first and last word in case read_start == read_end
reg first_word = 0;

assign ram_raddr = curr_addr;
// idle indicates that the stream has finished
wire idle;
assign idle = !first_word && ram_raddr == read_end_buf;
// if the stream has finished, don't issue ram reads even if readclk
// is asserted
assign ram_readclk = !idle && readclk;

// delay done so it appears when the last word comes out of ram
wire done_pd;
assign done_pd = readclk && (ram_raddr + 1 == read_end_buf);
delay #(.DELAY_LEN(RAM_READ_LATENCY)) done_delay(
	.clk(clk), .rst(rst), .in(done_pd), .out(done));

always @(posedge clk) begin
	if (rst) begin
		// stop stream even if readclk is asserted
		// (i.e. make idle = 1)
		curr_addr <= 0;
		read_end_buf <= 0;
		first_word <= 0;
	end else if (start) begin
		curr_addr <= read_start;
		read_end_buf <= read_end;
		first_word <= 1;
	// only increment curr_addr when we issue a read to ram,
	// which only happens when readclk is asserted
	end else if (ram_readclk) begin
		curr_addr <= curr_addr + 1;
		first_word <= 0;
	end
end

endmodule

// create a memory write stream
module stream_to_memory #(
	parameter RAM_SIZE = PACKET_BUFFER_SIZE,
	parameter WORD_LEN = BYTE_LEN) (
	input clk, rst,
	// used to set the offset for a new write stream
	// setoff_val is only valid when setoff_req is asserted
	// the setoff interface can be used at the same clock cycle as
	// inclk, so you can begin a new write stream immediately
	// after a write stream completes
	input setoff_req,
	input [clog2(RAM_SIZE)-1:0] setoff_val,
	input inclk, input [WORD_LEN-1:0] in,
	output reg ram_we = 0,
	output reg [clog2(RAM_SIZE)-1:0] ram_waddr,
	output reg [WORD_LEN-1:0] ram_win);

`include "params.vh"

reg [clog2(RAM_SIZE)-1:0] curr_addr = 0;
always @(posedge clk) begin
	if (rst) begin
		ram_we <= 0;
		curr_addr <= 0;
	end else begin
		if (setoff_req)
			curr_addr <= setoff_val;
		else if (inclk)
			curr_addr <= curr_addr + 1;

		if (inclk) begin
			// issue ram write
			ram_we <= 1;
			ram_waddr <= curr_addr;
			ram_win <= in;
		end else
			ram_we <= 0;
	end
end

endmodule

// coordinate two stream modules so that upstream data is requested
// only after downstream has received the previous word
module stream_coord(
	input clk, rst,
	input downstream_rdy, downstream_inclk,
	output upstream_readclk);

// waiting indicates that we have issued a read to upstream and we are
// waiting for downstream to receive a word
reg waiting = 0;
assign upstream_readclk = !rst && (waiting ? 0 : downstream_rdy);

always @(posedge clk) begin
	if (rst)
		waiting <= 0;
	// downstream_inclk indicates that a word has been received, and
	// downstream_rdy will be deasserted until downstream is ready
	// for the next word
	else if (downstream_inclk)
		waiting <= 0;
	else if (upstream_readclk)
		waiting <= 1;
end

endmodule

// buffered version of stream_coord, ensures that a word is passed
// out immediately when downstream is ready
module stream_coord_buf #(
	parameter DATA_WIDTH = 1) (
	input clk, rst,
	input inclk, input [DATA_WIDTH-1:0] in,
	input in_done,
	input downstream_rdy,
	output outclk, output [DATA_WIDTH-1:0] out,
	output done,
	output upstream_readclk);

wire swb_empty;
stream_coord sc_inst(
	.clk(clk), .rst(rst),
	// if downstream (of stream_coord_buf) is ready, the buffer will be
	// cleared, so the buffer (which is downstream of stream_coord) is
	// ready
	.downstream_rdy(swb_empty || downstream_rdy),
	.downstream_inclk(inclk),
	.upstream_readclk(upstream_readclk));
// add a single bit for the done signal
single_word_buffer #(.DATA_WIDTH(DATA_WIDTH+1)) swb_inst(
	// clear the buffer when downstream is ready, since then outclk would
	// be asserted (unless rst or swb_empty is asserted, but in those
	// cases it would be safe to clear the buffer anyway)
	.clk(clk), .rst(rst), .clear(downstream_rdy),
	.inclk(inclk), .in({in, in_done}),
	.empty(swb_empty), .out({out, done}));
// only present data on out when downstream is ready
assign outclk = !rst && !swb_empty && downstream_rdy;

endmodule

// coordinated, buffered version of stream_unpack
module stream_unpack_coord_buf #(
	parameter S_LEN = 1,
	parameter L_LEN = 2) (
	input clk, rst, inclk,
	input [L_LEN-1:0] in,
	input in_done, downstream_rdy,
	output upstream_readclk, outclk,
	output [S_LEN-1:0] out,
	output done);

wire su_rdy, su_inclk, su_in_done;
wire [L_LEN-1:0] su_in;
stream_coord_buf #(.DATA_WIDTH(L_LEN)) su_scb_inst(
	.clk(clk), .rst(rst),
	.inclk(inclk), .in(in),
	.in_done(in_done), .downstream_rdy(su_rdy && downstream_rdy),
	.outclk(su_inclk), .out(su_in), .done(su_in_done),
	.upstream_readclk(upstream_readclk));
stream_unpack #(.S_LEN(S_LEN), .L_LEN(L_LEN)) su_inst (
	.clk(clk), .rst(rst),
	.inclk(su_inclk), .in(su_in), .in_done(su_in_done),
	.readclk(1'b1),
	.outclk(outclk), .out(out),
	.rdy(su_rdy), .done(done));

endmodule

// coordinated, buffered version of bytes_to_dibits
module bytes_to_dibits_coord_buf(
	input clk, rst, inclk,
	input [BYTE_LEN-1:0] in,
	input in_done, downstream_rdy,
	output upstream_readclk, outclk,
	output [1:0] out,
	output done);

`include "params.vh"

stream_unpack_coord_buf #(.S_LEN(2), .L_LEN(BYTE_LEN)) sucb_inst (
	.clk(clk), .rst(rst),
	.inclk(inclk), .in(in), .in_done(in_done),
	.downstream_rdy(downstream_rdy), .upstream_readclk(upstream_readclk),
	.outclk(outclk), .out(out), .done(done));

endmodule
