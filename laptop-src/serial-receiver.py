import sys
sys.path.append('../lib/')
import fpga_serial

def listen(ser):
	with open('dump.log', 'wb') as f:
		while True:
			data = ser.read(128)
			if len(data) > 0:
				print('received %d bits' % len(data))
				f.write(data)
				f.flush()

fpga_serial.do_serial(listen)
