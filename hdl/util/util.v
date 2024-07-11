// delays signals on in for a DELAY_LEN cycles
// accepts input at any time, no need to wait for an input to
// appear on out
module delay #(
	// number of delay cycles
	parameter DELAY_LEN = 1,
	parameter DATA_WIDTH = 1) (
	input clk, rst, [DATA_WIDTH-1:0] in,
	output [DATA_WIDTH-1:0] out);

// shift register holds input from previous cycles
reg [DELAY_LEN*DATA_WIDTH-1:0] queue;
assign out = queue[0+:DATA_WIDTH];

always @ (posedge clk) begin
	if (rst)
		queue <= 0;
	// if DELAY_LEN is 1,
	// queue[DATA_WIDTH+:(DELAY_LEN-1)*DATA_WIDTH] would have zero length
	// resulting in wrong behavior, so treat this as a special case
	else if (DELAY_LEN == 1)
		queue <= in;
	else
		queue <= {in, queue[DATA_WIDTH+:(DELAY_LEN-1)*DATA_WIDTH]};
end

endmodule

// modified from code provided in previous labs
module debounce (
	input rst, clk, noisy,
	output reg clean);

reg [19:0] count;
reg prev;

always @(posedge clk) begin
	if (rst) begin
		prev <= noisy;
		clean <= noisy;
		count <= 0;
	end else if (noisy != prev) begin
		prev <= noisy; count <= 0;
	end else if (count == 650000)
		clean <= prev;
	else
		count <= count+1;
end

endmodule

module sync_debounce (
	input rst, clk, in,
	output out);

`include "params.vh"

wire synced;
delay #(.DELAY_LEN(SYNC_DELAY_LEN)) delay_inst(
	.clk(clk), .rst(rst), .in(in), .out(synced));
debounce debounce_inst(
	.rst(rst), .clk(clk), .noisy(synced), .clean(out));

endmodule

// toggles a signal every 2*BLINK_PERIOD clock cycles
// used to create a blinking LED to check that the system is running
module blinker #(
	parameter BLINK_PERIOD = 50000000) (
	input clk, rst, enable,
	output reg out = 0);

`include "util.vh"

// timer count, increases each clock cycle
reg [clog2(BLINK_PERIOD)-1:0] cnt = 0;

always @(posedge clk) begin
	if (rst || !enable) begin
		cnt <= 0;
		out <= 0;
	end else if (cnt == BLINK_PERIOD-1) begin
		cnt <= 0;
		out <= ~out;
	end else
		cnt <= cnt + 1;
end

endmodule

// out is asserted if in is asserted, or if in was asserted at some
// point in the last EXTEND_LEN clock cycles
module pulse_extender #(
	// time to extend pulse by, default 0.1s
	parameter EXTEND_LEN = 5000000) (
	input clk, rst, in, output out);

`include "util.vh"

// timer count, decreases each clock cycle
reg [clog2(EXTEND_LEN+1)-1:0] cnt = 0;
wire done;
assign done = cnt == 0;
// assert out if timer has not expired
// include in so that out is asserted on the same clock cycle
// that in is asserted
assign out = in || !done;

always @(posedge clk) begin
	if (rst)
		cnt <= 0;
	else if (in)
		cnt <= EXTEND_LEN;
	else if (!done)
		cnt <= cnt - 1;
end

endmodule

// asserts out for a single clock cycle when in is asserted
// out should be asserted on the same clock cycle as the rising edge of in
module pulse_generator (
	input clk, rst, in, output out);

// pulsed indicates that out has been asserted, and should be deasserted
// thereafter until in is deasserted (and asserted again)
reg pulsed = 0;
assign out = in && !pulsed;

always @(posedge clk) begin
	if (rst)
		pulsed <= 0;
	else if (in)
		pulsed <= 1;
	else
		pulsed <= 0;
end

endmodule

// pulses out for a single clock cycle every PULSE_PERIOD
// out is not, and should not be used as a clock
module clock_divider #(
	parameter PULSE_PERIOD = 4) (
	// only pulses if en is asserted
	input clk, rst, en, output out);

`include "util.vh"

reg [clog2(PULSE_PERIOD)-1:0] cnt = 0;
assign out = !rst && en && cnt == 0;

always @(posedge clk) begin
	if (rst)
		cnt <= 0;
	else if (cnt == PULSE_PERIOD-1)
		cnt <= 0;
	else
		cnt <= cnt + 1;
end

endmodule

// inclk is not a real clock, and only indicates that the data on
// in is valid
// when inclk is asserted, the buffer is overwritten with in, whether
// or not it is empty
module single_word_buffer #(
	parameter DATA_WIDTH = 1) (
	input clk, rst, clear, inclk, input [DATA_WIDTH-1:0] in,
	// empty indicates if the buffer is empty
	output reg empty = 1, output reg [DATA_WIDTH-1:0] out);

always @(posedge clk) begin
	if (rst)
		empty <= 1;
	else if (inclk) begin
		empty <= 0;
		out <= in;
	// clear simply marks the buffer as empty
	end else if (clear)
		empty <= 1;
end

endmodule
