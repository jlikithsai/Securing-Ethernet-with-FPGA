// receives ethernet frames from the rmii interface
// ethernet frames start with a preamble of alternating ones and zeroes,
// ending with two ones
// frames presented on out will not include the preamble
module rmii_driver(
	input clk, rst,
	// rxd and crsdv double as configuration straps when resetting the phy
	// we use rxerer and intn only for reset configuration
	inout crsdv_in,
	inout [1:0] rxd_in,
	output rxerr, intn,
	output reg rstn = 0,
	output reg [1:0] out = 0,
	output reg outclk = 0, output done);

`include "params.vh"

// should have 25ms delay from power supply up before
// nRST assertion, but we assume that power supplies have
// long been set up already
// according to spec: need 100us before nRST deassertion
// and 800ns afterwards
localparam RESET_BEFORE = 5000;
localparam RESET_AFTER = 40;
localparam RESET_SEQUENCE_LEN = RESET_BEFORE + RESET_AFTER;
reg [clog2(RESET_SEQUENCE_LEN)-1:0] rst_cnt = 0;
wire rst_done;
assign rst_done = rst_cnt == RESET_SEQUENCE_LEN;

// RESET CONFIGURATION

// 100Base-TX Full Duplex, auto-negotiation disabled,
// CRS active during receive
localparam DEFAULT_MODE = 3'b011;
// PHY address, leave at zero
localparam DEFAULT_PHYAD = 0;
// REF_CLK in (we control the clocking)
localparam DEFAULT_NINTSEL = 1;

assign crsdv_in = rst_done ? 1'bz : DEFAULT_MODE[2];
assign rxd_in = rst_done ? 2'bzz : DEFAULT_MODE[1:0];
assign rxerr = rst_done ? 1'bz : DEFAULT_PHYAD;
assign intn = rst_done ? 1'bz : DEFAULT_NINTSEL;

wire crsdv;
wire [1:0] rxd;

// assertion of CRS_DV is async wrt the REF_CLK, so synchronization needed
delay #(.DELAY_LEN(SYNC_DELAY_LEN-1)) crsdv_sync(
	.clk(clk), .rst(rst), .in(crsdv_in), .out(crsdv));
// delay rxd to be in time with crsdv
delay #(.DELAY_LEN(SYNC_DELAY_LEN-1), .DATA_WIDTH(2)) rxd_sync(
	.clk(clk), .rst(rst), .in(rxd_in), .out(rxd));

localparam STATE_IDLE = 0;
// crsdv has been asserted, waiting for data to start streaming in
localparam STATE_WAITING = 1;
// reading preamble
localparam STATE_PREAMBLE = 2;
localparam STATE_RECEIVING = 3;
reg [1:0] state = STATE_IDLE;

// store previous crsdv to check for toggling
// a toggling crsdv indicates that dv is asserted but not crs
reg prev_crsdv;
always @(posedge clk) begin
	if (rst_done)
		prev_crsdv <= crsdv;
end

// distinguish crs and dv signals
// only to be used when state == STATE_RECEIVING
// this will give the wrong value for crs on the rising edge of crsdv,
// but this is fine since we aren't using crs
// this will give the wrong value for dv on the falling edge of crsdv,
// but this is fine since systems based on ethernet should be robust to
// zeroes padded to the end of a frame
wire crsdv_toggling, crs, dv;
assign crsdv_toggling = prev_crsdv != crsdv;
assign crs = crsdv_toggling ? 0 : crsdv;
assign dv = crsdv_toggling ? 1 : crsdv;
assign done = (state == STATE_RECEIVING) && !dv;

always @(posedge clk) begin
	if (rst) begin
		rst_cnt <= 0;
		rstn <= 0;
		state <= STATE_IDLE;
		out <= 0;
		outclk <= 0;
	end else if (~rst_done) begin
		if (rst_cnt == RESET_BEFORE - 1)
			rstn <= 1;
		rst_cnt <= rst_cnt + 1;
	end else case(state)
	STATE_IDLE:
		if (crsdv)
			state <= STATE_WAITING;
	STATE_WAITING:
		// drop back to idle if crsdv stops being asserted
		if (!crsdv)
			state <= STATE_IDLE;
		else if (rxd == 2'b01) begin
			state <= STATE_PREAMBLE;
		end
	STATE_PREAMBLE:
		// drop back to idle if crsdv stops being asserted
		if (!crsdv)
			state <= STATE_IDLE;
		else if (rxd == 2'b11) begin
			state <= STATE_RECEIVING;
		end
	STATE_RECEIVING:
		if (!dv) begin
			state <= STATE_IDLE;
			outclk <= 0;
		end else begin
			outclk <= 1;
			out <= rxd;
		end
	endcase
end

endmodule
