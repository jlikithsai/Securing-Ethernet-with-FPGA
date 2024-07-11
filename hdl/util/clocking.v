// synchronizes a reset signal over a clock boundary using an IP FIFO
module reset_stream_fifo(
	input clka, clkb,
	input rsta, output rstb);

wire fifo_empty, fifo_out;
wire fifo_rden, fifo_prev_rden;
bit_stream_fifo reset_fifo(
	.rst(1'b0),
	.wr_clk(clka), .rd_clk(clkb),
	.din(rsta), .wr_en(rsta),
	.rd_en(fifo_rden), .dout(fifo_out),
	.empty(fifo_empty));
assign fifo_rden = !fifo_empty;
delay reset_fifo_read_delay(
	.clk(clkb), .rst(rstb), .in(fifo_rden), .out(fifo_prev_rden));
// fifo_out is only valid when rden was asserted the previous clock cycle
assign rstb = fifo_prev_rden && fifo_out;

endmodule
