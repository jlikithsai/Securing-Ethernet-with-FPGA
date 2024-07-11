IP_VERSION_4 = 4
IP_HEADER_LEN_DEFAULT = 5
IP_FLAGS_DF = 0x40
IP_TTL_DEFAULT = 128

IP_PROT_UDP = 17

IPADDR_LEN = 4
IPADDR_ZERO = bytes([0, 0, 0, 0])
IPADDR_BROADCAST = bytes([255, 255, 255, 255])

UDP_HEADER_LEN = 8

def ipv4_checksum(header):
	curr_sum = 0;
	for i in range((len(header)+1)//2):
		if i*2 == len(header)-1:
			second_byte = 0
		else:
			second_byte = header[i*2+1]
		curr_sum += (header[i*2] << 8) | second_byte
	checksum = (curr_sum >> 16) + (curr_sum & 0xffff)
	return (~checksum) & 0xffff

def gen_ip(protocol, ip_src, ip_dst, payload):
	header_len = 20
	total_len = header_len + len(payload)
	header = [
		(IP_VERSION_4 << 4) | (header_len // 4),
		0, # empty DSCP for now
		total_len >> 8,
		total_len & 0xff,
		0,
		0, # fragmentation identifier
		IP_FLAGS_DF, # don't fragment
		0, # fragmentation options
		IP_TTL_DEFAULT,
		protocol,
		0,
		0 # set checksum to 0 for calculation
		] + list(ip_src + ip_dst)
	checksum = ipv4_checksum(bytes(header))
	header[10] = checksum >> 8
	header[11] = checksum & 0xff
	return bytes(header) + payload

def gen_ip_udp(ip_src, ip_dst, port_src, port_dst, payload):
	total_len = UDP_HEADER_LEN + len(payload)
	header = [
		port_src >> 8,
		port_src & 0xff,
		port_dst >> 8,
		port_dst & 0xff,
		total_len >> 8,
		total_len & 0xff,
		0,
		0 # set checksum to 0 for calculation
	]
	checksum = ipv4_checksum(ip_src + ip_dst + bytes([
		0, IP_PROT_UDP, total_len >> 8, total_len & 0xff
	]) + bytes(header) + payload)
	header[6] = checksum >> 8
	header[7] = checksum & 0xff
	ip_payload = bytes(header) + payload
	return gen_ip(IP_PROT_UDP, ip_src, ip_dst, ip_payload)

def ip_get_version(packet):
	return packet[0] >> 4

def ip_get_prot(packet):
	return packet[9]

def ip_get_dst_addr(packet):
	return packet[16:20]

def udp_get_dst_port(packet):
	return (packet[2] << 8) | packet[3]
