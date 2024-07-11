import sys
sys.path.append('../lib/')
import ip

sample_header = list(bytes.fromhex('45000166718a00008011c7fd00000000ffffffff'))
sample_header[10] = 0
sample_header[11] = 0
print('computed: 0x%x' % ip.ipv4_checksum(bytes(sample_header)))
print('expected: 0xc7fd')
