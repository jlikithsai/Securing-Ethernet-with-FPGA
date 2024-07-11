import sys
sys.path.append('../lib/')
import image_bytes
import fpga_serial
import eth

fin_name = 'images/nyan.jpg'
IMAGE_WIDTH = 128
IMAGE_HEIGHT = 128

# sample_image_data = image_bytes.image_to_colors(
# 	fin_name, IMAGE_WIDTH, IMAGE_HEIGHT)[:512]
# use same data as in packet synth rom
sample_image_data = list(range(512))
sample_payload = eth.gen_eth_fgp_payload(6*512, sample_image_data)

def send_single(ser):
	num_written = ser.write(sample_payload)
	ser.flush()
	print("%d bytes written" % num_written)

fpga_serial.do_serial(send_single)
