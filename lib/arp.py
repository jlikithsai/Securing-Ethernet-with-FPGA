import eth
import ip

HTYPE_ETH = 1
PTYPE_IPV4 = 0x0800

OP_REQUEST = 1
OP_REPLY = 2

def gen_arp(client_ip, target_ip):
	return bytes([
		HTYPE_ETH >> 8,
		HTYPE_ETH & 0xff,
		PTYPE_IPV4 >> 8,
		PTYPE_IPV4 & 0xff,
		eth.MAC_LEN,
		ip.IPADDR_LEN,
		OP_REQUEST >> 8,
		OP_REQUEST & 0xff
	]) + eth.MAC_SEND + client_ip + eth.MAC_ZERO + target_ip

def get_op(packet):
	return (packet[6] << 8) | packet[7]

def get_target_addr(packet):
	return packet[24:28]

def get_sender_mac(packet):
	return packet[8:14]
