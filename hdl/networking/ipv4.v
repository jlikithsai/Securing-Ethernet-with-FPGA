module ipv4_checksum(
	input clk, rst,
	input inclk, input [BYTE_LEN-1:0] in,
	output [2*BYTE_LEN-1:0] out);

`include "params.vh"

reg cnt = 0;
reg [2*BYTE_LEN-1:0] curr_dibyte = 0;
reg [2*BYTE_LEN-1:0] prev_sum = 0;

// one extra bit for carry
wire [2*BYTE_LEN:0] curr_sum;
assign curr_sum = prev_sum + curr_dibyte;
// one's complement sum
wire [2*BYTE_LEN-1:0] next_sum;
assign next_sum = curr_sum + curr_sum[2*BYTE_LEN];
assign out = ~next_sum;

always @(posedge clk) begin
	if (rst) begin
		cnt <= 0;
		curr_dibyte <= 0;
		prev_sum <= 0;
	end else if (inclk) begin
		if (cnt == 0) begin
			curr_dibyte <= {in, {BYTE_LEN{1'b0}}};
			prev_sum <= next_sum;
		end else
			curr_dibyte[0+:BYTE_LEN] <= in;
		cnt <= cnt + 1;
	end
end

endmodule
