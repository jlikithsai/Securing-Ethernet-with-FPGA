import sys
import os
import os.path
import time
sys.path.append('../lib/')
import eth
import image_bytes
import fpga_serial

STOP_EARLY = False
image_dir = 'images/nyan/'
# image_dir = 'images/rickroll/'
IMAGE_WIDTH = 128
IMAGE_HEIGHT = 128
FRAME_PERIOD = 1/12

def send_cycle(ser):
	# Only cycle a few times if testing (i.e. STOP_EARLY == True)
	cnt = 0
	images = sorted(os.listdir(image_dir))
	prev_time = time.time()
	while True:
		if STOP_EARLY and cnt == 5:
			break
		for fin_name in images:
			im = image_bytes.image_to_colors(
				os.path.join(image_dir, fin_name),
				IMAGE_WIDTH, IMAGE_HEIGHT)
			# im = [a % 256 for a in list(range(128*128))]
			for i in range(len(im)//512):
				num_written = ser.write(
					eth.gen_eth_fgp_payload(i*512, im[i*512:(i+1)*512]))
				# uncomment this to transmit one packet per second
				# ser.flush()
				# time.sleep(1)
			# only flush once per complete frame for better throughput
			ser.flush()
			# print("%d bytes written" % num_written)
			curr_time = time.time()
			time_diff = curr_time - prev_time
			if time_diff < FRAME_PERIOD:
				time.sleep(FRAME_PERIOD - time_diff)
			prev_time = curr_time
		cnt = cnt + 1

fpga_serial.do_serial(send_cycle)
