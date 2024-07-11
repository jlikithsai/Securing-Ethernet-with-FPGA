`timescale 1ns / 1ps

module test_ethernet_driver();

`include "params.vh"

reg clk = 0;
// 50MHz clock
initial forever #10 clk = ~clk;

reg rst = 1;
wire crsdv_tr = 1'bz, rxerr_tr = 1'bz;
wire [1:0] rxd_tr = 2'bzz;
reg crsdv, rxerr;
reg [1:0] rxd;
reg rst_done = 0;
assign crsdv_tr = rst_done ? crsdv : 1'bz;
assign rxerr_tr = rst_done ? rxerr : 1'bz;
assign rxd_tr = rst_done ? rxd : 2'bzz;
wire intn, rstn;
wire [1:0] eth_out;
wire eth_outclk, eth_done;
wire [BYTE_LEN-1:0] eth_byte_out;
wire eth_byte_outclk, eth_dtb_done;
rmii_driver rmii_driv_inst(
	.clk(clk), .rst(rst),
	.crsdv_in(crsdv_tr), .rxd_in(rxd_tr),
	.rxerr(rxerr_tr),
	.intn(intn), .rstn(rstn),
	.out(eth_out),
	.outclk(eth_outclk), .done(eth_done));
dibits_to_bytes eth_dtb(
	.clk(clk), .rst(rst),
	.inclk(eth_outclk), .in(eth_out), .in_done(eth_done),
	.out(eth_byte_out), .outclk(eth_byte_outclk), .done(eth_dtb_done));

initial begin
	#100
	rst = 0;
	// reset sequence
	#400
	rst_done = 1;
	rxerr = 0;
	rxd = 0;
	crsdv = 0;
	#100
	crsdv = 1;
	#100

	// 28 cycles = 56 bits
	rxd = 2'b01;
	#540
	rxd = 2'b11;
	#20

	// send 10101010 twice (2 bytes)
	rxd = 2'b10;
	#160

	rxd = 0;
	crsdv = 0;
	#160

	$stop();
end

endmodule

module test_ddr2_ram();

`include "params.vh"

reg clk_100mhz = 0;
// 100MHz clock
initial forever #5 clk_100mhz = ~clk_100mhz;

// clk will be 50MHz
wire clk, clk_200mhz;
clk_wiz_0 clk_wiz_inst(
	.reset(0),
	.clk_in1(clk_100mhz), .clk_out1(clk), .clk_out2(clk_200mhz));

wire [15:0] ddr2_dq;
wire [1:0] ddr2_dqs_n, ddr2_dqs_p;
wire [12:0] ddr2_addr;
wire [2:0] ddr2_ba;
wire ddr2_ras_n, ddr2_cas_n, ddr2_we_n;
wire [0:0] ddr2_ck_p, ddr2_ck_n, ddr2_cke, ddr2_cs_n;
wire [1:0] ddr2_dm;
wire [0:0] ddr2_odt;
reg [26:0] app_addr = 0;
wire [2:0] app_cmd;
wire app_en;
reg [63:0] app_wdf_data = 0;
reg app_wdf_end = 0;
reg [7:0] app_wdf_mask = 0;
reg app_wdf_wren = 0;
wire [63:0] app_rd_data;
wire app_rd_data_end, app_rd_data_valid, app_rdy, app_wdf_rdy;
wire ui_clk, ui_clk_sync_rst, init_calib_complete;
reg sys_rst = 0;
`define x16
`define sg25
ddr2_mcp ddr2_mcp_inst(
	.ck(ddr2_ck_p), .ck_n(ddr2_ck_n), .cke(ddr2_cke),
	.cs_n(ddr2_cs_n),
	.ras_n(ddr2_ras_n), .cas_n(ddr2_cas_n), .we_n(ddr2_we_n),
	.dm_rdqs(ddr2_dm), .ba(ddr2_ba), .addr(ddr2_addr),
	.dq(ddr2_dq), .dqs(ddr2_dqs_p), .dqs_n(ddr2_dqs_n),
	.odt(ddr2_odt));
nexys4_ddr2 #(.SIM_BYPASS_INIT_CAL("FAST")) ddr2_ram_inst(
	.ddr2_dq(ddr2_dq), .ddr2_dqs_n(ddr2_dqs_n), .ddr2_dqs_p(ddr2_dqs_p),
	.ddr2_addr(ddr2_addr), .ddr2_ba(ddr2_ba),
	.ddr2_ras_n(ddr2_ras_n), .ddr2_cas_n(ddr2_cas_n), .ddr2_we_n(ddr2_we_n),
	.ddr2_ck_p(ddr2_ck_p), .ddr2_ck_n(ddr2_ck_n), .ddr2_cke(ddr2_cke),
	.ddr2_cs_n(ddr2_cs_n),
	.ddr2_dm(ddr2_dm), .ddr2_odt(ddr2_odt), .sys_clk_i(clk_200mhz),
	.sys_rst(sys_rst), .app_sr_req(0), .app_ref_req(0), .app_zq_req(0),
	.app_addr(app_addr), .app_cmd(app_cmd), .app_en(app_en),
	.app_wdf_data(app_wdf_data), .app_wdf_end(app_wdf_end),
	.app_wdf_mask(app_wdf_mask), .app_wdf_wren(app_wdf_wren),
	.app_rd_data(app_rd_data), .app_rd_data_end(app_rd_data_end),
	.app_rd_data_valid(app_rd_data_valid),
	.app_rdy(app_rdy), .app_wdf_rdy(app_wdf_rdy),
	.ui_clk(ui_clk), .ui_clk_sync_rst(ui_clk_sync_rst),
	.init_calib_complete(init_calib_complete));

reg ui_en = 0;
wire reading;
assign reading = ui_en && app_addr != 5 && app_rdy;
assign app_cmd = reading ? 3'b001 : 3'b111;
assign app_en = reading;
always @(posedge ui_clk) begin
	if (init_calib_complete && app_rdy)
		ui_en <= 1;
	if (reading) begin
		app_addr <= app_addr + 1;
	end
end

initial begin
	#400
	sys_rst = 1;
	#500
	$stop();
end

endmodule

module test_fast_uart();

`include "params.vh"

reg clk_100mhz = 0;
// 100MHz clock
initial forever #5 clk_100mhz = ~clk_100mhz;

reg clk_12mbaud = 0;
initial forever #41.6667 clk_12mbaud = ~clk_12mbaud;

wire clk, clk_120mhz;
clk_wiz_0 clk_wiz_inst(
	.reset(1'b0),
	.clk_in1(clk_100mhz),
	.clk_out1(clk),
	.clk_out3(clk_120mhz));

reg rst = 1;

localparam RAM_SIZE = PACKET_BUFFER_SIZE;

wire ram_readclk, ram_we, ram_outclk;
wire [clog2(RAM_SIZE)-1:0] ram_raddr, ram_waddr;
wire [BYTE_LEN-1:0] ram_win, ram_out;
packet_buffer_ram_driver ram_driv_inst(
	.clk(clk), .rst(rst),
	.readclk(ram_readclk), .raddr(ram_raddr),
	.we(ram_we), .waddr(ram_waddr), .win(ram_win),
	.outclk(ram_outclk), .out(ram_out));

wire uart_rxd;
wire [7:0] uart_out;
wire uart_outclk;
uart_rx_fast_driver uart_rx_inst (
	.clk(clk), .clk_120mhz(clk_120mhz), .rst(rst),
	.rxd(uart_rxd), .out(uart_out), .outclk(uart_outclk));
stream_to_memory uart_stm_inst(
	.clk(clk), .rst(rst),
	.setoff_req(1'b0), .setoff_val(0),
	.inclk(uart_outclk), .in(uart_out),
	.ram_we(ram_we), .ram_waddr(ram_waddr),
	.ram_win(ram_win));

reg sfm_start = 0;

wire uart_inclk;
wire [BYTE_LEN-1:0] uart_in;
wire uart_txd, uart_tx_ready;
wire sfm_done;
uart_tx_fast_stream_driver uart_tx_inst(
	.clk(clk), .clk_120mhz(clk_120mhz), .rst(rst), .start(sfm_start),
	.inclk(uart_inclk), .in(uart_in), .txd(uart_txd),
	.ready(uart_tx_ready));
stream_from_memory uart_sfm_inst(
	.clk(clk), .rst(rst), .start(sfm_start),
	.read_start(0), .read_end(3),
	.readclk(uart_tx_ready),
	.ram_outclk(ram_outclk), .ram_out(ram_out),
	.ram_readclk(ram_readclk), .ram_raddr(ram_raddr),
	.outclk(uart_inclk), .out(uart_in), .done(sfm_done));

reg [31:0] test_data = 32'b10_10011011_10_11010000_110_10001111_1;
assign uart_rxd = test_data[31];
reg sending = 0;
always @(posedge clk_12mbaud) begin
	if (sending)
		test_data <= {test_data[30:0], test_data[31]};
end

initial begin
	#2000
	rst = 0;
	#20
	sending = 1;
	#(32 * 2 * 41.6667)
	#40
	sfm_start = 1;
	#20
	sfm_start = 0;
	#(32 * 2 * 41.6667)
	#40
	$stop();
end

endmodule
