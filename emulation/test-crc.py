import sys
sys.path.append('../lib/')
import eth
import crc32

# sample taken from StackOverflow:
# https://stackoverflow.com/questions/40017293/check-fcs-ethernet-frame-crc-32-online-tools

sample_payload_str = '45000030B3FE0000801172BA0A0000030A00000204000400001C894D000102030405060708090A0B0C0D0E0F10111213'
sample_payload = bytes.fromhex(sample_payload_str)

sample_frame = eth.gen_eth_f2f(eth.ETHERTYPE_IP, sample_payload)
print(sample_frame)

crc = crc32.crc(sample_frame)
expected = 0x1cdf4421

print('poly: %08x' % crc32.POLY)
print('out: %08x' % crc)
print('expected: %08x' % expected)
