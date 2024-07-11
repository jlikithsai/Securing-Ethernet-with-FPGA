NUM_ELEMENTS = 16384;
arr = list(range(NUM_ELEMENTS))

with open('debug.coe', 'w') as f:
	f.write('memory_initialization_radix=16;\n')
	f.write('memory_initialization_vector=\n')
	for i in range(NUM_ELEMENTS):
		f.write('%02x%c\n' % (arr[i] % 2**8,
			',' if i != NUM_ELEMENTS - 1 else ';'))
