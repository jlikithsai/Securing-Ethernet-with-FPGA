`include "util.vh"

localparam SYNC_DELAY_LEN = 3;

localparam BYTE_LEN = 8;
localparam COLOR_CHANNEL_LEN = 4;
localparam COLOR_LEN = COLOR_CHANNEL_LEN * 3;
localparam BLOCK_LEN = 128;

localparam PACKET_BUFFER_SIZE = 16384;
// taken from ip summary
localparam PACKET_BUFFER_READ_LATENCY = 2;

localparam PACKET_SYNTH_ROM_SIZE = 4096;
localparam PACKET_SYNTH_ROM_LATENCY = 2;

localparam VIDEO_CACHE_RAM_SIZE = 16384;
localparam VIDEO_CACHE_RAM_LATENCY = 2;

localparam VGA_WIDTH = 800;
localparam VGA_HEIGHT = 600;
