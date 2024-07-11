import ip
import eth

PORT_CLIENT = 68
PORT_SERVER = 67

OP_REQUEST = 1
OP_REPLY = 2
HTYPE_ETH = 1
CHADDR_LEN = 16
FLAGS_BROADCAST = 0x80
SNAME_LEN = 64
FILE_LEN = 128
MAGIC_COOKIE = bytes([99, 130, 83, 99])
OPT_TYPE_CODE = 53
OPT_TYPE_LEN = 1
OPT_TYPE_DISCOVER = 1
OPT_TYPE_REQUEST = 3
OPT_LIST_CODE = 55
OPT_MASK = 1
OPT_ROUTER = 3
OPT_DNS = 6
OPT_DOMAIN_NAME = 15
OPT_DHCP_SERVER_IP = 54
OPT_REQUESTED_IP = 50
OPT_END = 255

HEADER_LEN_BASE = (12 + ip.IPADDR_LEN * 4 + CHADDR_LEN +
	SNAME_LEN + FILE_LEN + len(MAGIC_COOKIE))

def gen_dhcp(xid, secs, opt_type, client_ip, renew=False, dhcp_server_ip=ip.IPADDR_BROADCAST):
	opt_list = bytes([
		OPT_MASK,
		OPT_ROUTER,
		OPT_DNS,
		OPT_DOMAIN_NAME,
		OPT_DHCP_SERVER_IP
	])
	if renew:
		extra_options = bytes([])
	elif client_ip == ip.IPADDR_ZERO:
		extra_options = bytes([
			OPT_LIST_CODE,
			len(opt_list)
		]) + opt_list
	else:
		extra_options = bytes([
			OPT_REQUESTED_IP,
			ip.IPADDR_LEN
		]) + client_ip

	return ip.gen_ip_udp(
		(client_ip if renew else ip.IPADDR_ZERO),
		dhcp_server_ip,
		PORT_CLIENT, PORT_SERVER,
		bytes([
			OP_REQUEST, HTYPE_ETH, eth.MAC_LEN,
			0, # hops = 0 for client
			xid >> 24,
			(xid >> 16) & 0xff,
			(xid >> 8) & 0xff,
			(xid) & 0xff,
			secs >> 8,
			secs & 0xff,
			FLAGS_BROADCAST if client_ip == ip.IPADDR_ZERO else 0, 0
		]) +
		(client_ip if renew else ip.IPADDR_ZERO) +
		ip.IPADDR_ZERO +
		ip.IPADDR_ZERO +
		ip.IPADDR_ZERO +
		eth.MAC_SEND +
		bytes([0] * (CHADDR_LEN - eth.MAC_LEN)) +
		bytes([0] * (SNAME_LEN + FILE_LEN)) +
		MAGIC_COOKIE +
		bytes([
			OPT_TYPE_CODE,
			OPT_TYPE_LEN,
			opt_type,
		]) +
		extra_options +
		bytes([
			OPT_END
		])
	)

def gen_dhcp_discover(xid, secs):
	return gen_dhcp(xid, secs, OPT_TYPE_DISCOVER, ip.IPADDR_ZERO)

def gen_dhcp_request(xid, secs, client_ip, renew=False, dhcp_server_ip=ip.IPADDR_BROADCAST):
	return gen_dhcp(xid, secs, OPT_TYPE_REQUEST, client_ip,
		renew, dhcp_server_ip)

def get_op(packet):
	return packet[0]

def get_xid(packet):
	return ((packet[4] << 24) |
		(packet[5] << 16) |
		(packet[6] << 8) |
		packet[7])

def get_ip(packet):
	return packet[16:20]

def get_opts(packet):
	curr_index = HEADER_LEN_BASE
	opts = {}
	while True:
		if packet[curr_index] == OPT_END:
			return opts
		opt_len = packet[curr_index+1]
		opts[packet[curr_index]] = (
			packet[curr_index+2:curr_index+2+opt_len])
		curr_index += 2 + opt_len
