def reflect(x):
	res = 0
	for i in range(32):
		res = (res << 1) | ((x >> i) & 1)
	return res

def reflect_bytes(x):
	res = 0
	for i in range(4):
		res = (res << 8) | ((x >> (i*8)) & 0xff)
	return res

POLY = reflect(0x04c11db7)
INIT = reflect(0xffffffff)
MASK = 0xffffffff

def crc(frame):
	curr = INIT
	for i in range(len(frame) * 8):
		curr_bit = (frame[i//8] >> (i%8)) & 1
		curr ^= curr_bit
		multiple = POLY if (curr & 1) == 1 else 0
		curr = ((curr >> 1) ^ multiple) & MASK
	return reflect_bytes((~curr) & MASK)
