import sys
sys.path.append('../lib/')
import image_bytes
import fpga_serial
import eth

IMAGE_WIDTH = 128
IMAGE_HEIGHT = 128

def send_image(ser):
	fin_name = 'images/nyan.jpg'
	im = image_bytes.image_to_colors(
		fin_name, IMAGE_WIDTH, IMAGE_HEIGHT)
	for i in range(len(im)//512):
		num_written = ser.write(
			eth.gen_eth_fgp_payload(i*512, im[i*512:(i+1)*512]))
		ser.flush()
		print("%d bytes written" % num_written)

fpga_serial.do_serial(send_image)
