from socket import *
import image_bytes
import crc32

MAC_LEN = 6
MAC_ZERO = bytes.fromhex('000000000000')
MAC_SEND = bytes.fromhex('DEADBEEFCAFE')
MAC_RECV = bytes.fromhex('C0FFEEDAD101')
MAC_BROADCAST = bytes.fromhex('FFFFFFFFFFFF')

ETHERTYPE_LEN = 2
ETHERTYPE_FGP = bytes.fromhex('ca11')
ETHERTYPE_FFCP = bytes.fromhex('ca12')
ETHERTYPE_IP = bytes.fromhex('0800')
ETHERTYPE_ARP = bytes.fromhex('0806')

HEADER_LEN = 2 * MAC_LEN + ETHERTYPE_LEN

def gen_eth_body(dst, src, eth_type, payload):
	assert(len(src) == MAC_LEN and len(dst) == MAC_LEN)
	assert(len(eth_type) == ETHERTYPE_LEN)
	return dst + src + eth_type + payload

def gen_eth(dst, src, eth_type, payload):
	body = gen_eth_body(dst, src, eth_type, payload)
	crc = crc32.crc(body)
	return body + bytes([
		crc >> 24,
		(crc >> 16) & 0xff,
		(crc >> 8) & 0xff,
		crc & 0xff
	])

# fpga to fpga
def gen_eth_f2f(eth_type, payload):
	return gen_eth(MAC_RECV, MAC_SEND, eth_type, payload)

def gen_eth_fgp_payload(offset, colors):
	assert(len(colors) == 512)
	return (bytes([offset//512]) +
		image_bytes.colors_to_bytes(colors))

def gen_eth_fgp(offset, colors):
	return gen_eth_f2f(ETHERTYPE_FGP,
		gen_eth_fgp_payload(offset, colors))

def sendeth(frame, interface = "enp2s0"):
	s = socket(AF_PACKET, SOCK_RAW)
	s.bind((interface, 0))
	# remove crc
	return s.send(frame[:-4])

def get_ethertype(frame):
	return frame[2*MAC_LEN:2*MAC_LEN+2]

def get_src_mac(frame):
	return frame[MAC_LEN:2*MAC_LEN]
