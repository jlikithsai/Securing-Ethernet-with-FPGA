`timescale 1ns / 1ps

module test_main();

reg clk_100mhz = 0;
// 100MHz clock
initial forever #5 clk_100mhz = ~clk_100mhz;

wire clk, clk_120mhz;
clk_wiz_0 clk_wiz_inst(
	.reset(0),
	.clk_in1(clk_100mhz),
	.clk_out1(clk),
	.clk_out3(clk_120mhz));

initial begin
	#10000
	$stop();
end

endmodule
