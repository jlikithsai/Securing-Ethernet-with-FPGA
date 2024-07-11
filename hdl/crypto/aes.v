// inclk is asserted when a block is presented on in
// outclk should be asserted when a block is presented on out
// always takes the same number of clock cycles per block
module aes_combined(
	input clk, rst,
	input inclk, input [BLOCK_LEN-1:0] in, key,
	output outclk, output [BLOCK_LEN-1:0] out,
	input decr_select);

`include "params.vh"

  reg [127:0] aes_in;
  wire [127:0] aes_key;
  wire [127:0] aes_out;
  reg [4:0] count = 0;
  reg crypting = 0;
  reg [4:0] key_counter = 0;

  always @(posedge clk) begin
    if(rst) begin
        count <= 0;
        crypting <= 0;
        key_counter <= 0;
    end
	else if (key_counter < 12)
		key_counter <= key_counter + 1;
    else if (inclk) begin
        count <= 0;
        crypting <= 1;
        aes_in <= in;
    end
    else if (crypting && count == 0) begin
            aes_in <= aes_in ^ aes_key;
            count <= count + 1;
    end
    else if (crypting && count < 11) begin
        count <= count + 1;
        aes_in <= aes_out;
    end
    else crypting <= 0;
  end
  aes_block block(.in(aes_in), .key(aes_key), .block_num(count-1), .out(aes_out), .decr_select(decr_select));
  keygen round_key(.clk(clk), .start(key_counter == 0), .key(key), .keyout_sel(decr_select ? 10-count : count), .keyout_selected(aes_key));

  assign out = (count == 10) ? aes_out : 0;
  assign outclk = (count == 10);

endmodule

// implements CBC mode
// when encrypting, XOR the previous output (ciphertext) with the current
// input (plaintext)
// when decrypting, XOR the previous input (ciphertext) with the current
// output (plaintext)
module aes_chain(
	input clk, rst,
	input inclk, input [BLOCK_LEN-1:0] in, key,
	output outclk, output [BLOCK_LEN-1:0] out,
	// only perform CBC if cbc_enable is asserted, to allow us to
	// demonstrate difference with CBC enabled and disabled
	input decr_select, cbc_enable);

`include "params.vh"

// need additional buffering for prev when decrypting -- some time
// passes between inclk and outclk, so we want the plaintext from
// two inclks before
reg [BLOCK_LEN-1:0] prev_prev = 0;
reg [BLOCK_LEN-1:0] prev = 0;
wire [BLOCK_LEN-1:0] aes_out;
aes_combined aes_inst(
	.clk(clk), .rst(rst),
	.inclk(inclk), .in((!decr_select && cbc_enable) ? (in ^ prev) : in),
	.key(key),
	.outclk(outclk), .out(aes_out), .decr_select(decr_select));
assign out = (decr_select && cbc_enable) ? (aes_out ^ prev_prev) : aes_out;

always @(posedge clk) begin
	if (rst) begin
		prev_prev <= 0;
		prev <= 0;
	end else if (decr_select && inclk) begin
		prev_prev <= prev;
		prev <= in;
	end else if (!decr_select && outclk)
		prev <= out;
end

endmodule

// buffered version of bytes interface for aes_combined
// for use with network stack
module aes_combined_bytes_buf(
	input clk, rst,
	input inclk, input [BYTE_LEN-1:0] in, input in_done,
	input [BLOCK_LEN-1:0] key,
	input readclk,
	output outclk, output [BYTE_LEN-1:0] out, output done,
	output upstream_readclk,
	input decr_select, cbc_enable);

`include "params.vh"

wire btbl_outclk, btbl_done;
wire [BLOCK_LEN-1:0] btbl_out;
bytes_to_blocks btbl_inst(
	.clk(clk), .rst(rst), .inclk(inclk), .in(in), .in_done(in_done),
	.outclk(btbl_outclk), .out(btbl_out), .done(btbl_done));
wire btbl_swb_empty;
wire btbl_swb_outclk, btbl_swb_done;
wire [BLOCK_LEN-1:0] btbl_swb_out;
single_word_buffer #(.DATA_WIDTH(BLOCK_LEN+1)) btbl_swb_inst(
	.clk(clk), .rst(rst), .clear(btbl_swb_outclk),
	.inclk(btbl_outclk), .in({btbl_out, btbl_done}),
	.empty(btbl_swb_empty), .out({btbl_swb_out, btbl_swb_done}));

wire aes_outclk;
wire [BLOCK_LEN-1:0] aes_out;
aes_chain aes_inst(
	.clk(clk), .rst(rst),
	.inclk(btbl_swb_outclk), .in(btbl_swb_out), .key(key),
	.outclk(aes_outclk), .out(aes_out),
	.decr_select(decr_select), .cbc_enable(cbc_enable));
reg aes_done_buf = 0;
always @(posedge clk) begin
	if (btbl_swb_outclk && btbl_swb_done)
		aes_done_buf <= 1;
	else if (aes_outclk)
		aes_done_buf <= 0;
end

wire bltb_swb_empty;
wire bltb_swb_outclk, bltb_swb_done;
wire [BLOCK_LEN-1:0] bltb_swb_out;
single_word_buffer #(.DATA_WIDTH(BLOCK_LEN+1)) bltb_swb_inst(
	.clk(clk), .rst(rst), .clear(bltb_swb_outclk),
	.inclk(aes_outclk), .in({aes_out, aes_done_buf}),
	.empty(bltb_swb_empty), .out({bltb_swb_out, bltb_swb_done}));
wire bltb_rdy;
blocks_to_bytes bltb_inst(
	.clk(clk), .rst(rst),
	.inclk(bltb_swb_outclk), .in(bltb_swb_out), .in_done(bltb_swb_done),
	.readclk(readclk), .outclk(outclk), .out(out), .done(done),
	.rdy(bltb_rdy));
// read out from the blocks-to-bytes buffer when the blocks-to-bytes
// module is ready
assign bltb_swb_outclk = readclk && bltb_rdy && !bltb_swb_empty;
// the bytes-to-blocks module generates blocks no faster than once
// every 16 clock cycles, so the aes module will always be ready when
// the bytes-to-blocks buffer is written to
// so we just read out from the bytes-to-blocks buffer whenever
// the blocks-to-bytes buffer is ready
assign btbl_swb_outclk = (bltb_swb_outclk || bltb_swb_empty) &&
	!btbl_swb_empty;
// send a read to upstream when the bytes-to-blocks buffer is being
// cleared or is already empty
assign upstream_readclk = btbl_swb_outclk || btbl_swb_empty;

endmodule

module aes_block(input [127:0] in,
                   input [127:0] key,
                   input [3:0] block_num,
                   input decr_select,
                   output [127:0] out);

    wire [127:0] sb_out_e;
    wire [127:0] sr_out_e;
    wire [127:0] mc_out_e;
    wire [127:0] rc_out_e;
    wire [127:0] sb_out_d;
    wire [127:0] sr_out_d;
    wire [127:0] mc_out_d;
    wire [127:0] rc_out_d;

    subbytes a_e(.in(in), .out(sb_out_e), .decrypt(1'b0));
    shiftrows b_e(.in(sb_out_e), .out(sr_out_e), .decrypt(1'b0));
    mixcolumns c_e(.in(sr_out_e), .out(mc_out_e), .decrypt(1'b0));
    addroundkey d_e(
		.in((block_num == 9) ? sr_out_e : mc_out_e),
		.out(rc_out_e), .key(key));

    shiftrows b_d(.in(in), .out(sr_out_d), .decrypt(1'b1));
    subbytes a_d(.in(sr_out_d), .out(sb_out_d), .decrypt(1'b1));
    addroundkey d_d(.in(sb_out_d), .out(rc_out_d), .key(key));
    mixcolumns c_d(.in(rc_out_d), .out(mc_out_d), .decrypt(1'b1));

	assign out = decr_select ? (
		(block_num == 9) ? rc_out_d : mc_out_d) : rc_out_e;

endmodule

module keygen(input clk,
              input start,
              input [127:0] key,
              input [3:0] keyout_sel,
              output [127:0] keyout_selected);
    reg [127:0] rcon;

    reg generating;
    reg [3:0] round_num;
    reg [31:0] w0, w1, w2, w3;

    reg [127:0] keyout [10:0];

    wire [31:0] temp;

    assign keyout_selected = keyout[keyout_sel];
    always @(posedge clk) begin
        if (start) begin
            generating <= 1;
            round_num <= 1;
            keyout[0] <= key;
            w0 <= key[127:96];
            w1 <= key[95:64];
            w2 <= key[63:32];
            w3 <= key[31:0];
        end
        else if (generating && round_num <= 10) begin
            w0 <= w0^temp^rcon;
            w1 <= w0^temp^rcon^w1;
            w2 <= w0^temp^rcon^w1^w2;
            w3 <= w0^temp^rcon^w1^w2^w3;

            keyout[round_num][127:96] <= w0^temp^rcon;
            keyout[round_num][95:64] <= w0^temp^rcon^w1;
            keyout[round_num][63:32] <= w0^temp^rcon^w1^w2;
            keyout[round_num][31:0] <= w0^temp^rcon^w1^w2^w3;
            round_num <= round_num + 1;
        end
    end

    wire [7:0] temp0, temp1, temp2, temp3;

    sbox q0( .in(keyout[round_num-1][63:56]),.out(temp0));
    sbox q1( .in(keyout[round_num-1][71:64]),.out(temp1));
    sbox q2( .in(keyout[round_num-1][79:72]),.out(temp2));
    sbox q3( .in(keyout[round_num-1][87:80]),.out(temp3));
    assign temp = {temp1,temp2,temp3,temp0};

    // rc_i top byte of rcon
    // rc_i = rc_{i-1} *2 if <= rc_{i-1} h'80 else rc_{i-1} *2  ^ h'11b
    always @(*) begin
        case (round_num)
            4'h1: rcon=128'h01_00_00_00_00;
            4'h2: rcon=128'h02_00_00_00_00;
            4'h3: rcon=128'h04_00_00_00_00;
            4'h4: rcon=128'h08_00_00_00_00;
            4'h5: rcon=128'h10_00_00_00_00;
            4'h6: rcon=128'h20_00_00_00_00;
            4'h7: rcon=128'h40_00_00_00_00;
            4'h8: rcon=128'h80_00_00_00_00;
            4'h9: rcon=128'h1b_00_00_00_00;
            4'ha: rcon=128'h36_00_00_00_00;
            default: rcon = 0;
        endcase
    end

endmodule

module addroundkey(input [127:0] in,
                   input [127:0] key,
                   output [127:0] out);
    assign out = in ^ key;
endmodule

module inv_sbox(input [7:0] in,
            output [7:0] out);

            reg [7:0] inv_sbox;
            always @(*) begin
                case (in)
					8'h0 : inv_sbox = 8'h52;
					8'h1 : inv_sbox = 8'h9;
					8'h2 : inv_sbox = 8'h6A;
					8'h3 : inv_sbox = 8'hD5;
					8'h4 : inv_sbox = 8'h30;
					8'h5 : inv_sbox = 8'h36;
					8'h6 : inv_sbox = 8'hA5;
					8'h7 : inv_sbox = 8'h38;
					8'h8 : inv_sbox = 8'hBF;
					8'h9 : inv_sbox = 8'h40;
					8'hA : inv_sbox = 8'hA3;
					8'hB : inv_sbox = 8'h9E;
					8'hC : inv_sbox = 8'h81;
					8'hD : inv_sbox = 8'hF3;
					8'hE : inv_sbox = 8'hD7;
					8'hF : inv_sbox = 8'hFB;
					8'h10 : inv_sbox = 8'h7C;
					8'h11 : inv_sbox = 8'hE3;
					8'h12 : inv_sbox = 8'h39;
					8'h13 : inv_sbox = 8'h82;
					8'h14 : inv_sbox = 8'h9B;
					8'h15 : inv_sbox = 8'h2F;
					8'h16 : inv_sbox = 8'hFF;
					8'h17 : inv_sbox = 8'h87;
					8'h18 : inv_sbox = 8'h34;
					8'h19 : inv_sbox = 8'h8E;
					8'h1A : inv_sbox = 8'h43;
					8'h1B : inv_sbox = 8'h44;
					8'h1C : inv_sbox = 8'hC4;
					8'h1D : inv_sbox = 8'hDE;
					8'h1E : inv_sbox = 8'hE9;
					8'h1F : inv_sbox = 8'hCB;
					8'h20 : inv_sbox = 8'h54;
					8'h21 : inv_sbox = 8'h7B;
					8'h22 : inv_sbox = 8'h94;
					8'h23 : inv_sbox = 8'h32;
					8'h24 : inv_sbox = 8'hA6;
					8'h25 : inv_sbox = 8'hC2;
					8'h26 : inv_sbox = 8'h23;
					8'h27 : inv_sbox = 8'h3D;
					8'h28 : inv_sbox = 8'hEE;
					8'h29 : inv_sbox = 8'h4C;
					8'h2A : inv_sbox = 8'h95;
					8'h2B : inv_sbox = 8'hB;
					8'h2C : inv_sbox = 8'h42;
					8'h2D : inv_sbox = 8'hFA;
					8'h2E : inv_sbox = 8'hC3;
					8'h2F : inv_sbox = 8'h4E;
					8'h30 : inv_sbox = 8'h8;
					8'h31 : inv_sbox = 8'h2E;
					8'h32 : inv_sbox = 8'hA1;
					8'h33 : inv_sbox = 8'h66;
					8'h34 : inv_sbox = 8'h28;
					8'h35 : inv_sbox = 8'hD9;
					8'h36 : inv_sbox = 8'h24;
					8'h37 : inv_sbox = 8'hB2;
					8'h38 : inv_sbox = 8'h76;
					8'h39 : inv_sbox = 8'h5B;
					8'h3A : inv_sbox = 8'hA2;
					8'h3B : inv_sbox = 8'h49;
					8'h3C : inv_sbox = 8'h6D;
					8'h3D : inv_sbox = 8'h8B;
					8'h3E : inv_sbox = 8'hD1;
					8'h3F : inv_sbox = 8'h25;
					8'h40 : inv_sbox = 8'h72;
					8'h41 : inv_sbox = 8'hF8;
					8'h42 : inv_sbox = 8'hF6;
					8'h43 : inv_sbox = 8'h64;
					8'h44 : inv_sbox = 8'h86;
					8'h45 : inv_sbox = 8'h68;
					8'h46 : inv_sbox = 8'h98;
					8'h47 : inv_sbox = 8'h16;
					8'h48 : inv_sbox = 8'hD4;
					8'h49 : inv_sbox = 8'hA4;
					8'h4A : inv_sbox = 8'h5C;
					8'h4B : inv_sbox = 8'hCC;
					8'h4C : inv_sbox = 8'h5D;
					8'h4D : inv_sbox = 8'h65;
					8'h4E : inv_sbox = 8'hB6;
					8'h4F : inv_sbox = 8'h92;
					8'h50 : inv_sbox = 8'h6C;
					8'h51 : inv_sbox = 8'h70;
					8'h52 : inv_sbox = 8'h48;
					8'h53 : inv_sbox = 8'h50;
					8'h54 : inv_sbox = 8'hFD;
					8'h55 : inv_sbox = 8'hED;
					8'h56 : inv_sbox = 8'hB9;
					8'h57 : inv_sbox = 8'hDA;
					8'h58 : inv_sbox = 8'h5E;
					8'h59 : inv_sbox = 8'h15;
					8'h5A : inv_sbox = 8'h46;
					8'h5B : inv_sbox = 8'h57;
					8'h5C : inv_sbox = 8'hA7;
					8'h5D : inv_sbox = 8'h8D;
					8'h5E : inv_sbox = 8'h9D;
					8'h5F : inv_sbox = 8'h84;
					8'h60 : inv_sbox = 8'h90;
					8'h61 : inv_sbox = 8'hD8;
					8'h62 : inv_sbox = 8'hAB;
					8'h63 : inv_sbox = 8'h0;
					8'h64 : inv_sbox = 8'h8C;
					8'h65 : inv_sbox = 8'hBC;
					8'h66 : inv_sbox = 8'hD3;
					8'h67 : inv_sbox = 8'hA;
					8'h68 : inv_sbox = 8'hF7;
					8'h69 : inv_sbox = 8'hE4;
					8'h6A : inv_sbox = 8'h58;
					8'h6B : inv_sbox = 8'h5;
					8'h6C : inv_sbox = 8'hB8;
					8'h6D : inv_sbox = 8'hB3;
					8'h6E : inv_sbox = 8'h45;
					8'h6F : inv_sbox = 8'h6;
					8'h70 : inv_sbox = 8'hD0;
					8'h71 : inv_sbox = 8'h2C;
					8'h72 : inv_sbox = 8'h1E;
					8'h73 : inv_sbox = 8'h8F;
					8'h74 : inv_sbox = 8'hCA;
					8'h75 : inv_sbox = 8'h3F;
					8'h76 : inv_sbox = 8'hF;
					8'h77 : inv_sbox = 8'h2;
					8'h78 : inv_sbox = 8'hC1;
					8'h79 : inv_sbox = 8'hAF;
					8'h7A : inv_sbox = 8'hBD;
					8'h7B : inv_sbox = 8'h3;
					8'h7C : inv_sbox = 8'h1;
					8'h7D : inv_sbox = 8'h13;
					8'h7E : inv_sbox = 8'h8A;
					8'h7F : inv_sbox = 8'h6B;
					8'h80 : inv_sbox = 8'h3A;
					8'h81 : inv_sbox = 8'h91;
					8'h82 : inv_sbox = 8'h11;
					8'h83 : inv_sbox = 8'h41;
					8'h84 : inv_sbox = 8'h4F;
					8'h85 : inv_sbox = 8'h67;
					8'h86 : inv_sbox = 8'hDC;
					8'h87 : inv_sbox = 8'hEA;
					8'h88 : inv_sbox = 8'h97;
					8'h89 : inv_sbox = 8'hF2;
					8'h8A : inv_sbox = 8'hCF;
					8'h8B : inv_sbox = 8'hCE;
					8'h8C : inv_sbox = 8'hF0;
					8'h8D : inv_sbox = 8'hB4;
					8'h8E : inv_sbox = 8'hE6;
					8'h8F : inv_sbox = 8'h73;
					8'h90 : inv_sbox = 8'h96;
					8'h91 : inv_sbox = 8'hAC;
					8'h92 : inv_sbox = 8'h74;
					8'h93 : inv_sbox = 8'h22;
					8'h94 : inv_sbox = 8'hE7;
					8'h95 : inv_sbox = 8'hAD;
					8'h96 : inv_sbox = 8'h35;
					8'h97 : inv_sbox = 8'h85;
					8'h98 : inv_sbox = 8'hE2;
					8'h99 : inv_sbox = 8'hF9;
					8'h9A : inv_sbox = 8'h37;
					8'h9B : inv_sbox = 8'hE8;
					8'h9C : inv_sbox = 8'h1C;
					8'h9D : inv_sbox = 8'h75;
					8'h9E : inv_sbox = 8'hDF;
					8'h9F : inv_sbox = 8'h6E;
					8'hA0 : inv_sbox = 8'h47;
					8'hA1 : inv_sbox = 8'hF1;
					8'hA2 : inv_sbox = 8'h1A;
					8'hA3 : inv_sbox = 8'h71;
					8'hA4 : inv_sbox = 8'h1D;
					8'hA5 : inv_sbox = 8'h29;
					8'hA6 : inv_sbox = 8'hC5;
					8'hA7 : inv_sbox = 8'h89;
					8'hA8 : inv_sbox = 8'h6F;
					8'hA9 : inv_sbox = 8'hB7;
					8'hAA : inv_sbox = 8'h62;
					8'hAB : inv_sbox = 8'hE;
					8'hAC : inv_sbox = 8'hAA;
					8'hAD : inv_sbox = 8'h18;
					8'hAE : inv_sbox = 8'hBE;
					8'hAF : inv_sbox = 8'h1B;
					8'hB0 : inv_sbox = 8'hFC;
					8'hB1 : inv_sbox = 8'h56;
					8'hB2 : inv_sbox = 8'h3E;
					8'hB3 : inv_sbox = 8'h4B;
					8'hB4 : inv_sbox = 8'hC6;
					8'hB5 : inv_sbox = 8'hD2;
					8'hB6 : inv_sbox = 8'h79;
					8'hB7 : inv_sbox = 8'h20;
					8'hB8 : inv_sbox = 8'h9A;
					8'hB9 : inv_sbox = 8'hDB;
					8'hBA : inv_sbox = 8'hC0;
					8'hBB : inv_sbox = 8'hFE;
					8'hBC : inv_sbox = 8'h78;
					8'hBD : inv_sbox = 8'hCD;
					8'hBE : inv_sbox = 8'h5A;
					8'hBF : inv_sbox = 8'hF4;
					8'hC0 : inv_sbox = 8'h1F;
					8'hC1 : inv_sbox = 8'hDD;
					8'hC2 : inv_sbox = 8'hA8;
					8'hC3 : inv_sbox = 8'h33;
					8'hC4 : inv_sbox = 8'h88;
					8'hC5 : inv_sbox = 8'h7;
					8'hC6 : inv_sbox = 8'hC7;
					8'hC7 : inv_sbox = 8'h31;
					8'hC8 : inv_sbox = 8'hB1;
					8'hC9 : inv_sbox = 8'h12;
					8'hCA : inv_sbox = 8'h10;
					8'hCB : inv_sbox = 8'h59;
					8'hCC : inv_sbox = 8'h27;
					8'hCD : inv_sbox = 8'h80;
					8'hCE : inv_sbox = 8'hEC;
					8'hCF : inv_sbox = 8'h5F;
					8'hD0 : inv_sbox = 8'h60;
					8'hD1 : inv_sbox = 8'h51;
					8'hD2 : inv_sbox = 8'h7F;
					8'hD3 : inv_sbox = 8'hA9;
					8'hD4 : inv_sbox = 8'h19;
					8'hD5 : inv_sbox = 8'hB5;
					8'hD6 : inv_sbox = 8'h4A;
					8'hD7 : inv_sbox = 8'hD;
					8'hD8 : inv_sbox = 8'h2D;
					8'hD9 : inv_sbox = 8'hE5;
					8'hDA : inv_sbox = 8'h7A;
					8'hDB : inv_sbox = 8'h9F;
					8'hDC : inv_sbox = 8'h93;
					8'hDD : inv_sbox = 8'hC9;
					8'hDE : inv_sbox = 8'h9C;
					8'hDF : inv_sbox = 8'hEF;
					8'hE0 : inv_sbox = 8'hA0;
					8'hE1 : inv_sbox = 8'hE0;
					8'hE2 : inv_sbox = 8'h3B;
					8'hE3 : inv_sbox = 8'h4D;
					8'hE4 : inv_sbox = 8'hAE;
					8'hE5 : inv_sbox = 8'h2A;
					8'hE6 : inv_sbox = 8'hF5;
					8'hE7 : inv_sbox = 8'hB0;
					8'hE8 : inv_sbox = 8'hC8;
					8'hE9 : inv_sbox = 8'hEB;
					8'hEA : inv_sbox = 8'hBB;
					8'hEB : inv_sbox = 8'h3C;
					8'hEC : inv_sbox = 8'h83;
					8'hED : inv_sbox = 8'h53;
					8'hEE : inv_sbox = 8'h99;
					8'hEF : inv_sbox = 8'h61;
					8'hF0 : inv_sbox = 8'h17;
					8'hF1 : inv_sbox = 8'h2B;
					8'hF2 : inv_sbox = 8'h4;
					8'hF3 : inv_sbox = 8'h7E;
					8'hF4 : inv_sbox = 8'hBA;
					8'hF5 : inv_sbox = 8'h77;
					8'hF6 : inv_sbox = 8'hD6;
					8'hF7 : inv_sbox = 8'h26;
					8'hF8 : inv_sbox = 8'hE1;
					8'hF9 : inv_sbox = 8'h69;
					8'hFA : inv_sbox = 8'h14;
					8'hFB : inv_sbox = 8'h63;
					8'hFC : inv_sbox = 8'h55;
					8'hFD : inv_sbox = 8'h21;
					8'hFE : inv_sbox = 8'hC;
					8'hFF : inv_sbox = 8'h7D;
					default : inv_sbox = 8'h0;
				endcase
            end
            assign out = inv_sbox;
endmodule

module sbox(input [7:0] in,
            output [7:0] out);

            reg [7:0] sbox;
            always @(*) begin
                case (in)
                    8'h0 : sbox = 8'h63;
                    8'h1 : sbox = 8'h7C;
                    8'h2 : sbox = 8'h77;
                    8'h3 : sbox = 8'h7B;
                    8'h4 : sbox = 8'hF2;
                    8'h5 : sbox = 8'h6B;
                    8'h6 : sbox = 8'h6F;
                    8'h7 : sbox = 8'hC5;
                    8'h8 : sbox = 8'h30;
                    8'h9 : sbox = 8'h1;
                    8'hA : sbox = 8'h67;
                    8'hB : sbox = 8'h2B;
                    8'hC : sbox = 8'hFE;
                    8'hD : sbox = 8'hD7;
                    8'hE : sbox = 8'hAB;
                    8'hF : sbox = 8'h76;
                    8'h10 : sbox = 8'hCA;
                    8'h11 : sbox = 8'h82;
                    8'h12 : sbox = 8'hC9;
                    8'h13 : sbox = 8'h7D;
                    8'h14 : sbox = 8'hFA;
                    8'h15 : sbox = 8'h59;
                    8'h16 : sbox = 8'h47;
                    8'h17 : sbox = 8'hF0;
                    8'h18 : sbox = 8'hAD;
                    8'h19 : sbox = 8'hD4;
                    8'h1A : sbox = 8'hA2;
                    8'h1B : sbox = 8'hAF;
                    8'h1C : sbox = 8'h9C;
                    8'h1D : sbox = 8'hA4;
                    8'h1E : sbox = 8'h72;
                    8'h1F : sbox = 8'hC0;
                    8'h20 : sbox = 8'hB7;
                    8'h21 : sbox = 8'hFD;
                    8'h22 : sbox = 8'h93;
                    8'h23 : sbox = 8'h26;
                    8'h24 : sbox = 8'h36;
                    8'h25 : sbox = 8'h3F;
                    8'h26 : sbox = 8'hF7;
                    8'h27 : sbox = 8'hCC;
                    8'h28 : sbox = 8'h34;
                    8'h29 : sbox = 8'hA5;
                    8'h2A : sbox = 8'hE5;
                    8'h2B : sbox = 8'hF1;
                    8'h2C : sbox = 8'h71;
                    8'h2D : sbox = 8'hD8;
                    8'h2E : sbox = 8'h31;
                    8'h2F : sbox = 8'h15;
                    8'h30 : sbox = 8'h4;
                    8'h31 : sbox = 8'hC7;
                    8'h32 : sbox = 8'h23;
                    8'h33 : sbox = 8'hC3;
                    8'h34 : sbox = 8'h18;
                    8'h35 : sbox = 8'h96;
                    8'h36 : sbox = 8'h5;
                    8'h37 : sbox = 8'h9A;
                    8'h38 : sbox = 8'h7;
                    8'h39 : sbox = 8'h12;
                    8'h3A : sbox = 8'h80;
                    8'h3B : sbox = 8'hE2;
                    8'h3C : sbox = 8'hEB;
                    8'h3D : sbox = 8'h27;
                    8'h3E : sbox = 8'hB2;
                    8'h3F : sbox = 8'h75;
                    8'h40 : sbox = 8'h9;
                    8'h41 : sbox = 8'h83;
                    8'h42 : sbox = 8'h2C;
                    8'h43 : sbox = 8'h1A;
                    8'h44 : sbox = 8'h1B;
                    8'h45 : sbox = 8'h6E;
                    8'h46 : sbox = 8'h5A;
                    8'h47 : sbox = 8'hA0;
                    8'h48 : sbox = 8'h52;
                    8'h49 : sbox = 8'h3B;
                    8'h4A : sbox = 8'hD6;
                    8'h4B : sbox = 8'hB3;
                    8'h4C : sbox = 8'h29;
                    8'h4D : sbox = 8'hE3;
                    8'h4E : sbox = 8'h2F;
                    8'h4F : sbox = 8'h84;
                    8'h50 : sbox = 8'h53;
                    8'h51 : sbox = 8'hD1;
                    8'h52 : sbox = 8'h0;
                    8'h53 : sbox = 8'hED;
                    8'h54 : sbox = 8'h20;
                    8'h55 : sbox = 8'hFC;
                    8'h56 : sbox = 8'hB1;
                    8'h57 : sbox = 8'h5B;
                    8'h58 : sbox = 8'h6A;
                    8'h59 : sbox = 8'hCB;
                    8'h5A : sbox = 8'hBE;
                    8'h5B : sbox = 8'h39;
                    8'h5C : sbox = 8'h4A;
                    8'h5D : sbox = 8'h4C;
                    8'h5E : sbox = 8'h58;
                    8'h5F : sbox = 8'hCF;
                    8'h60 : sbox = 8'hD0;
                    8'h61 : sbox = 8'hEF;
                    8'h62 : sbox = 8'hAA;
                    8'h63 : sbox = 8'hFB;
                    8'h64 : sbox = 8'h43;
                    8'h65 : sbox = 8'h4D;
                    8'h66 : sbox = 8'h33;
                    8'h67 : sbox = 8'h85;
                    8'h68 : sbox = 8'h45;
                    8'h69 : sbox = 8'hF9;
                    8'h6A : sbox = 8'h2;
                    8'h6B : sbox = 8'h7F;
                    8'h6C : sbox = 8'h50;
                    8'h6D : sbox = 8'h3C;
                    8'h6E : sbox = 8'h9F;
                    8'h6F : sbox = 8'hA8;
                    8'h70 : sbox = 8'h51;
                    8'h71 : sbox = 8'hA3;
                    8'h72 : sbox = 8'h40;
                    8'h73 : sbox = 8'h8F;
                    8'h74 : sbox = 8'h92;
                    8'h75 : sbox = 8'h9D;
                    8'h76 : sbox = 8'h38;
                    8'h77 : sbox = 8'hF5;
                    8'h78 : sbox = 8'hBC;
                    8'h79 : sbox = 8'hB6;
                    8'h7A : sbox = 8'hDA;
                    8'h7B : sbox = 8'h21;
                    8'h7C : sbox = 8'h10;
                    8'h7D : sbox = 8'hFF;
                    8'h7E : sbox = 8'hF3;
                    8'h7F : sbox = 8'hD2;
                    8'h80 : sbox = 8'hCD;
                    8'h81 : sbox = 8'hC;
                    8'h82 : sbox = 8'h13;
                    8'h83 : sbox = 8'hEC;
                    8'h84 : sbox = 8'h5F;
                    8'h85 : sbox = 8'h97;
                    8'h86 : sbox = 8'h44;
                    8'h87 : sbox = 8'h17;
                    8'h88 : sbox = 8'hC4;
                    8'h89 : sbox = 8'hA7;
                    8'h8A : sbox = 8'h7E;
                    8'h8B : sbox = 8'h3D;
                    8'h8C : sbox = 8'h64;
                    8'h8D : sbox = 8'h5D;
                    8'h8E : sbox = 8'h19;
                    8'h8F : sbox = 8'h73;
                    8'h90 : sbox = 8'h60;
                    8'h91 : sbox = 8'h81;
                    8'h92 : sbox = 8'h4F;
                    8'h93 : sbox = 8'hDC;
                    8'h94 : sbox = 8'h22;
                    8'h95 : sbox = 8'h2A;
                    8'h96 : sbox = 8'h90;
                    8'h97 : sbox = 8'h88;
                    8'h98 : sbox = 8'h46;
                    8'h99 : sbox = 8'hEE;
                    8'h9A : sbox = 8'hB8;
                    8'h9B : sbox = 8'h14;
                    8'h9C : sbox = 8'hDE;
                    8'h9D : sbox = 8'h5E;
                    8'h9E : sbox = 8'hB;
                    8'h9F : sbox = 8'hDB;
                    8'hA0 : sbox = 8'hE0;
                    8'hA1 : sbox = 8'h32;
                    8'hA2 : sbox = 8'h3A;
                    8'hA3 : sbox = 8'hA;
                    8'hA4 : sbox = 8'h49;
                    8'hA5 : sbox = 8'h6;
                    8'hA6 : sbox = 8'h24;
                    8'hA7 : sbox = 8'h5C;
                    8'hA8 : sbox = 8'hC2;
                    8'hA9 : sbox = 8'hD3;
                    8'hAA : sbox = 8'hAC;
                    8'hAB : sbox = 8'h62;
                    8'hAC : sbox = 8'h91;
                    8'hAD : sbox = 8'h95;
                    8'hAE : sbox = 8'hE4;
                    8'hAF : sbox = 8'h79;
                    8'hB0 : sbox = 8'hE7;
                    8'hB1 : sbox = 8'hC8;
                    8'hB2 : sbox = 8'h37;
                    8'hB3 : sbox = 8'h6D;
                    8'hB4 : sbox = 8'h8D;
                    8'hB5 : sbox = 8'hD5;
                    8'hB6 : sbox = 8'h4E;
                    8'hB7 : sbox = 8'hA9;
                    8'hB8 : sbox = 8'h6C;
                    8'hB9 : sbox = 8'h56;
                    8'hBA : sbox = 8'hF4;
                    8'hBB : sbox = 8'hEA;
                    8'hBC : sbox = 8'h65;
                    8'hBD : sbox = 8'h7A;
                    8'hBE : sbox = 8'hAE;
                    8'hBF : sbox = 8'h8;
                    8'hC0 : sbox = 8'hBA;
                    8'hC1 : sbox = 8'h78;
                    8'hC2 : sbox = 8'h25;
                    8'hC3 : sbox = 8'h2E;
                    8'hC4 : sbox = 8'h1C;
                    8'hC5 : sbox = 8'hA6;
                    8'hC6 : sbox = 8'hB4;
                    8'hC7 : sbox = 8'hC6;
                    8'hC8 : sbox = 8'hE8;
                    8'hC9 : sbox = 8'hDD;
                    8'hCA : sbox = 8'h74;
                    8'hCB : sbox = 8'h1F;
                    8'hCC : sbox = 8'h4B;
                    8'hCD : sbox = 8'hBD;
                    8'hCE : sbox = 8'h8B;
                    8'hCF : sbox = 8'h8A;
                    8'hD0 : sbox = 8'h70;
                    8'hD1 : sbox = 8'h3E;
                    8'hD2 : sbox = 8'hB5;
                    8'hD3 : sbox = 8'h66;
                    8'hD4 : sbox = 8'h48;
                    8'hD5 : sbox = 8'h3;
                    8'hD6 : sbox = 8'hF6;
                    8'hD7 : sbox = 8'hE;
                    8'hD8 : sbox = 8'h61;
                    8'hD9 : sbox = 8'h35;
                    8'hDA : sbox = 8'h57;
                    8'hDB : sbox = 8'hB9;
                    8'hDC : sbox = 8'h86;
                    8'hDD : sbox = 8'hC1;
                    8'hDE : sbox = 8'h1D;
                    8'hDF : sbox = 8'h9E;
                    8'hE0 : sbox = 8'hE1;
                    8'hE1 : sbox = 8'hF8;
                    8'hE2 : sbox = 8'h98;
                    8'hE3 : sbox = 8'h11;
                    8'hE4 : sbox = 8'h69;
                    8'hE5 : sbox = 8'hD9;
                    8'hE6 : sbox = 8'h8E;
                    8'hE7 : sbox = 8'h94;
                    8'hE8 : sbox = 8'h9B;
                    8'hE9 : sbox = 8'h1E;
                    8'hEA : sbox = 8'h87;
                    8'hEB : sbox = 8'hE9;
                    8'hEC : sbox = 8'hCE;
                    8'hED : sbox = 8'h55;
                    8'hEE : sbox = 8'h28;
                    8'hEF : sbox = 8'hDF;
                    8'hF0 : sbox = 8'h8C;
                    8'hF1 : sbox = 8'hA1;
                    8'hF2 : sbox = 8'h89;
                    8'hF3 : sbox = 8'hD;
                    8'hF4 : sbox = 8'hBF;
                    8'hF5 : sbox = 8'hE6;
                    8'hF6 : sbox = 8'h42;
                    8'hF7 : sbox = 8'h68;
                    8'hF8 : sbox = 8'h41;
                    8'hF9 : sbox = 8'h99;
                    8'hFA : sbox = 8'h2D;
                    8'hFB : sbox = 8'hF;
                    8'hFC : sbox = 8'hB0;
                    8'hFD : sbox = 8'h54;
                    8'hFE : sbox = 8'hBB;
                    8'hFF : sbox = 8'h16;
                    default : sbox = 8'h0;
                endcase
            end
            assign out = sbox;
endmodule

module subbytes(input [127:0] in,
                input decrypt, // flag, when set to 1 work in decrypt mode
                output [127:0] out);

     wire [127:0] out_e;
     wire [127:0] out_d;

     sbox q0( .in(in[127:120]),.out(out_e[127:120]) );
     sbox q1( .in(in[119:112]),.out(out_e[119:112]) );
     sbox q2( .in(in[111:104]),.out(out_e[111:104]) );
     sbox q3( .in(in[103:96]),.out(out_e[103:96]) );

     sbox q4( .in(in[95:88]),.out(out_e[95:88]) );
     sbox q5( .in(in[87:80]),.out(out_e[87:80]) );
     sbox q6( .in(in[79:72]),.out(out_e[79:72]) );
     sbox q7( .in(in[71:64]),.out(out_e[71:64]) );

     sbox q8( .in(in[63:56]),.out(out_e[63:56]) );
     sbox q9( .in(in[55:48]),.out(out_e[55:48]) );
     sbox q10(.in(in[47:40]),.out(out_e[47:40]) );
     sbox q11(.in(in[39:32]),.out(out_e[39:32]) );

     sbox q12(.in(in[31:24]),.out(out_e[31:24]) );
     sbox q13(.in(in[23:16]),.out(out_e[23:16]) );
     sbox q14(.in(in[15:8]),.out(out_e[15:8]) );
     sbox q15(.in(in[7:0]),.out(out_e[7:0]) );

     inv_sbox iq0( .in(in[127:120]),.out(out_d[127:120]) );
     inv_sbox iq1( .in(in[119:112]),.out(out_d[119:112]) );
     inv_sbox iq2( .in(in[111:104]),.out(out_d[111:104]) );
     inv_sbox iq3( .in(in[103:96]),.out(out_d[103:96]) );

     inv_sbox iq4( .in(in[95:88]),.out(out_d[95:88]) );
     inv_sbox iq5( .in(in[87:80]),.out(out_d[87:80]) );
     inv_sbox iq6( .in(in[79:72]),.out(out_d[79:72]) );
     inv_sbox iq7( .in(in[71:64]),.out(out_d[71:64]) );

     inv_sbox iq8( .in(in[63:56]),.out(out_d[63:56]) );
     inv_sbox iq9( .in(in[55:48]),.out(out_d[55:48]) );
     inv_sbox iq10(.in(in[47:40]),.out(out_d[47:40]) );
     inv_sbox iq11(.in(in[39:32]),.out(out_d[39:32]) );

     inv_sbox iq12(.in(in[31:24]),.out(out_d[31:24]) );
     inv_sbox iq13(.in(in[23:16]),.out(out_d[23:16]) );
     inv_sbox iq14(.in(in[15:8]),.out(out_d[15:8]) );
     inv_sbox iq15(.in(in[7:0]),.out(out_d[7:0]) );

     assign out = decrypt ? out_d : out_e;
endmodule

module shiftrows(input [127:0] in,
                input decrypt, // flag, when set to 1 work in decrypt mode
                output [127:0] out);

    wire [7:0] bytes [15:0];

    genvar i;
    generate
        for (i = 0; i < 16; i=i+1) begin : gen_bytes
            assign bytes[15-i] = in[i*8+7:i*8];
        end
    endgenerate

    assign out = decrypt ?  {bytes[0], bytes[1], bytes[2], bytes[3],
                             bytes[7], bytes[4], bytes[5], bytes[6],
                             bytes[10], bytes[11], bytes[8], bytes[9],
                             bytes[13], bytes[14], bytes[15], bytes[12]}
                : {bytes[0], bytes[1], bytes[2], bytes[3],
                  bytes[5], bytes[6], bytes[7], bytes[4],
                  bytes[10], bytes[11], bytes[8], bytes[9],
                  bytes[15], bytes[12], bytes[13], bytes[14]};
endmodule

module mixcolumns(input [127:0] in,
                input decrypt, // flag, when set to 1 work in decrypt mode
                output [127:0] out);

        wire [7:0] bytes [15:0];
        wire [7:0] dbytes [15:0];       // doubled bytes
        wire [7:0] ddbytes [15:0];       // bytes * 4
        wire [7:0] dddbytes [15:0];       // bytse * 8
        wire [7:0] mixed_bytes_e [15:0];
        wire [7:0] mixed_bytes_d [15:0];


        genvar i;
        generate
            for (i = 0; i < 16; i=i+1) begin : gen_bytes
                assign bytes[i] = in[i*8+7:i*8];
                assign dbytes[i] = {bytes[i][6 : 0], 1'b0} ^
                    (8'h1b & {8{bytes[i][7]}});
                assign ddbytes[i] = {dbytes[i][6 : 0], 1'b0} ^
                    (8'h1b & {8{dbytes[i][7]}});
                assign dddbytes[i] = {ddbytes[i][6 : 0], 1'b0} ^
                    (8'h1b & {8{ddbytes[i][7]}});
            end
        endgenerate


       /*
       For encryption, we left multiply each column by

       2 3 1 1
       1 2 3 1
       1 1 2 3
       3 1 1 2

       in order to generate a new matrix. This means we can go column by column,
       taking every fourth byte.

       multiplication by 2 is equivalent to a left shift of 1,
       multiplication by 3 is a left shift of 1 xored with the initial value.
       using this, we can implement this transformation with no multipliers.

       The inverse matrix (for decryption) is

       0E 0B 0D 09
       09 0E 0B 0D
       0D 09 0E 0B
       0B 0D 09 0E
       */


        genvar j;
        generate
            for (j = 0; j < 4; j=j+1) begin : gen_column_mix
                assign mixed_bytes_d[j] = dbytes[j]^ddbytes[j]^dddbytes[j]^
                                            bytes[j+4]^dbytes[j+4]^dddbytes[j+4]^
                                            bytes[j+8]^ddbytes[j+8]^dddbytes[j+8]^
                                            bytes[j+12]^dddbytes[j+12];
                assign mixed_bytes_d[j+4] = bytes[j]^dddbytes[j]^
                                            dbytes[j+4]^ddbytes[j+4]^dddbytes[j+4]^
                                            bytes[j+8]^dbytes[j+8]^dddbytes[j+8]^
                                            bytes[j+12]^ddbytes[j+12]^dddbytes[j+12];
                assign mixed_bytes_d[j+8] = bytes[j]^ddbytes[j]^dddbytes[j]^
                                            bytes[j+4]^dddbytes[j+4]^
                                            dbytes[j+8]^ddbytes[j+8]^dddbytes[j+8]^
                                            bytes[j+12]^dbytes[j+12]^dddbytes[j+12];
                assign mixed_bytes_d[j+12] = bytes[j]^dbytes[j]^dddbytes[j]^
                                            bytes[j+4]^ddbytes[j+4]^dddbytes[j+4]^
                                            bytes[j+8]^dddbytes[j+8]^
                                            dbytes[j+12]^ddbytes[j+12]^dddbytes[j+12];

                assign mixed_bytes_e[j] = dbytes[j]^dbytes[j+4]^bytes[j+4]^
                            bytes[j+8]^bytes[j+12];
                assign mixed_bytes_e[j+4] = bytes[j]^dbytes[j+4]^dbytes[j+8]^
                            bytes[j+8]^bytes[j+12];
                assign mixed_bytes_e[j+8] = bytes[j]^bytes[j+4]^dbytes[j+8]^
                            dbytes[j+12]^bytes[j+12];
                assign mixed_bytes_e[j+12] = dbytes[j]^bytes[j]^bytes[j+4]^
                            bytes[j+8]^dbytes[j+12];
            end
        endgenerate

        assign out = decrypt ?
            {mixed_bytes_d[15], mixed_bytes_d[14], mixed_bytes_d[13], mixed_bytes_d[12],
            mixed_bytes_d[11], mixed_bytes_d[10], mixed_bytes_d[9], mixed_bytes_d[8],
            mixed_bytes_d[7], mixed_bytes_d[6], mixed_bytes_d[5], mixed_bytes_d[4],
            mixed_bytes_d[3], mixed_bytes_d[2], mixed_bytes_d[1], mixed_bytes_d[0]}
            :
            {mixed_bytes_e[15], mixed_bytes_e[14], mixed_bytes_e[13], mixed_bytes_e[12],
            mixed_bytes_e[11], mixed_bytes_e[10], mixed_bytes_e[9], mixed_bytes_e[8],
            mixed_bytes_e[7], mixed_bytes_e[6], mixed_bytes_e[5], mixed_bytes_e[4],
            mixed_bytes_e[3], mixed_bytes_e[2], mixed_bytes_e[1], mixed_bytes_e[0]};
endmodule
