`timescale 1ns / 1ps

module test_aes_full_encrypt();

reg clk_100mhz = 0;
// 100MHz clock
initial forever #5 clk_100mhz = ~clk_100mhz;

wire clk;
clk_wiz_0 clk_wiz_inst(
	.reset(0),
	.clk_in1(clk_100mhz),
	.clk_out1(clk));

reg [127:0] in;
reg [127:0] key;
wire [127:0] out_enc, dec;
reg rst; 
reg in_clk;
wire out_clk, out_clk_2; 

aes_combined enc_block(.clk(clk), .rst(rst), .key(key), .inclk(in_clk), .in(in), .outclk(out_clk), .out(out_enc), .decr_select(0));
aes_combined dec_block(.clk(clk), .rst(rst), .key(key), .inclk(out_clk), .in(out_enc), .outclk(out_clk_2), .out(dec), .decr_select(1));


initial begin
    rst = 1;
    in_clk = 0;
	#250
	rst = 0;
	in = 213412334;
    key = 12341234;
    #10
    in_clk = 1;
    #10
    in_clk = 0;
	#1500
	
    rst = 1;
	$stop();
	
end

endmodule

module test_aes_keygen();

reg clk_100mhz = 0;
// 100MHz clock
initial forever #5 clk_100mhz = ~clk_100mhz;

wire clk;
clk_wiz_0 clk_wiz_inst(
	.reset(0),
	.clk_in1(clk_100mhz),
	.clk_out1(clk));

reg [127:0] key;
wire [127:0] keyout;
reg [3:0] keyout_sel;

reg rst; 
reg in_clk;
reg start;
wire out_clk, out_clk_2; 

keygen a(.clk(clk), .key(key), .start(start), .keyout_selected(keyout), .keyout_sel(keyout_sel));

initial begin
	#250
	rst = 0;
    key = 1234343;
    keyout_sel = 0;
    start = 0;
    #10
    start = 1;
    #10
    start = 0;
    
	#200
	keyout_sel = 1;
	#10
	keyout_sel = 2;

	$stop();
end

endmodule

module test_aes_inversion();

reg clk_100mhz = 0;
// 100MHz clock
initial forever #5 clk_100mhz = ~clk_100mhz;

wire clk;
clk_wiz_0 clk_wiz_inst(
	.reset(0),
	.clk_in1(clk_100mhz),
	.clk_out1(clk));

reg [127:0] in;
reg [127:0] key;
wire [127:0] out_enc_s, dec_s;
wire [127:0] out_enc_sr, dec_sr;
wire [127:0] out_enc_m, dec_m;
wire [127:0] out_enc_a, dec_a;

reg rst; 
reg in_clk;
wire out_clk, out_clk_2; 

subbytes a(.in(in), .out(out_enc_s), .decrypt(0));
subbytes b(.in(out_enc_s),.out(dec_s), .decrypt(1));
shiftrows c(.in(in), .out(out_enc_sr), .decrypt(0));
shiftrows d(.in(out_enc_sr), .out(dec_sr), .decrypt(1));
mixcolumns e(.in(in), .out(out_enc_m), .decrypt(0));
mixcolumns f(.in(out_enc_m), .out(dec_m), .decrypt(1));
addroundkey g(.in(in), .out(out_enc_a), .key(key));
addroundkey h(.in(out_enc_a), .out(dec_a), .key(key));


initial begin
	#250
	rst = 0;
	in = 2009789435;
    key = 1234343;
    #10
    in_clk = 1;
    #10
    in_clk = 0;
	#800

	$stop();
end

endmodule

module test_aes_one_block_encrypt();

reg clk_100mhz = 0;
// 100MHz clock
initial forever #5 clk_100mhz = ~clk_100mhz;

wire clk;
clk_wiz_0 clk_wiz_inst(
	.reset(0),
	.clk_in1(clk_100mhz),
	.clk_out1(clk));

reg [127:0] in;
reg [127:0] key;
wire [127:0] out;

aes_block aes(
	.in(in), .key(key), .out(out), .decr_select(0));

initial begin
	#100
	in = 200;
    key = 0;
	#40

	$stop();
end

endmodule
