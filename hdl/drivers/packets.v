// packet_buffer_ram module
module packet_buffer_ram (
    input wire clk,
    input wire wea,
    input wire [clog2(RAM_SIZE)-1:0] addra,
    input wire [BYTE_LEN-1:0] dina,
    input wire clkb,
    input wire [clog2(RAM_SIZE)-1:0] addrb,
    output reg [BYTE_LEN-1:0] doutb
);

parameter RAM_SIZE = PACKET_BUFFER_SIZE;
parameter BYTE_LEN = 8; // Adjust the width as needed

reg [BYTE_LEN-1:0] mem [0:RAM_SIZE-1];

always @(posedge clk) begin
    if (wea) mem[addra] <= dina;
end

assign doutb = mem[addrb];

endmodule

// video_cache_ram module
module video_cache_ram (
    input wire clka,
    input wire wea,
    input wire [clog2(RAM_SIZE)-1:0] addra,
    input wire [COLOR_LEN-1:0] dina,
    input wire clkb,
    input wire [clog2(RAM_SIZE)-1:0] addrb,
    output reg [COLOR_LEN-1:0] doutb
);

parameter RAM_SIZE = VIDEO_CACHE_RAM_SIZE;
parameter COLOR_LEN = 8; // Adjust the width as needed

reg [COLOR_LEN-1:0] mem [0:RAM_SIZE-1];

always @(posedge clka) begin
    if (wea) mem[addra] <= dina;
end

assign doutb = mem[addrb];

endmodule

// packet_synth_rom module
module packet_synth_rom (
    input wire clka,
    input wire [clog2(RAM_SIZE)-1:0] addra,
    output reg [BYTE_LEN-1:0] douta
);

parameter RAM_SIZE = PACKET_SYNTH_ROM_SIZE;
parameter BYTE_LEN = 8; // Adjust the width as needed
wire count =8'b00000000;
reg [BYTE_LEN-1:0] mem [0:RAM_SIZE-1];

// Initialize ROM contents here
  initial 
    begin
      for (integer i=0;i<256;i=i+1)
        mem[i] <= count +i; 
    end
assign douta = mem[addra];

endmodule
