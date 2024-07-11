import sys
sys.path.append('../lib/')
import os
import eth
import image_bytes

sample_image_data = list(range(512))
# arbitrarily choose an offset of 6 for testing
sample_payload = eth.gen_eth_fgp_payload(6*512, sample_image_data)
sample_frame = eth.gen_eth_f2f(eth.ETHERTYPE_FGP, sample_payload)

class Memory:
	def __init__(self):
		self.curr_bytes = []
		self.curr_index = 0

	def append(self, val):
		off = self.curr_index
		self.curr_bytes += val
		self.curr_index += len(val)
		return off

mem = Memory()
mac_send_off = mem.append(eth.MAC_SEND)
mac_recv_off = mem.append(eth.MAC_RECV)
ethertype_fgp_off = mem.append(eth.ETHERTYPE_FGP)
ethertype_ffcp_off = mem.append(eth.ETHERTYPE_FFCP)
sample_frame_off = mem.append(sample_frame)
sample_payload_off = mem.append(sample_payload)
sample_image_data_off = mem.append(sample_image_data)

NUM_ELEMENTS = 4096;
arr = list(range(NUM_ELEMENTS))

def write_localparam(f, key, val):
	f.write('localparam %s = %d;\n' % (key, val))

rom_layout_filename = os.path.join(
	os.path.dirname(__file__), '../hdl/inc/packet_synth_rom_layout.vh')
with open(rom_layout_filename, 'w') as f:
	f.write('// This is a generated file. DO NOT edit this directly.\n\n')
	f.write('// sender and receiver MAC addresses\n')
	write_localparam(f, 'MAC_SEND_OFF', mac_send_off)
	write_localparam(f, 'MAC_RECV_OFF', mac_recv_off)
	f.write('\n')
	write_localparam(f, 'ETHERTYPE_FGP_OFF', ethertype_fgp_off)
	write_localparam(f, 'ETHERTYPE_FFCP_OFF', ethertype_ffcp_off)
	f.write('\n')
	write_localparam(f, 'SAMPLE_PAYLOAD_OFF', sample_payload_off)
	write_localparam(f, 'SAMPLE_PAYLOAD_LEN', len(sample_payload))
	write_localparam(f, 'SAMPLE_FRAME_OFF', sample_frame_off)
	write_localparam(f, 'SAMPLE_FRAME_LEN', len(sample_frame))
	write_localparam(f, 'SAMPLE_IMG_DATA_OFF', sample_image_data_off)
	write_localparam(f, 'SAMPLE_IMG_DATA_LEN', len(sample_image_data))

for i in range(len(mem.curr_bytes)):
	arr[i] = mem.curr_bytes[i]

with open('packet_synth.coe', 'w') as f:
	f.write('memory_initialization_radix=16;\n')
	f.write('memory_initialization_vector=\n')
	for i in range(NUM_ELEMENTS):
		f.write('%02x%c\n' % (arr[i] % 2**8,
			',' if i != NUM_ELEMENTS - 1 else ';'))
