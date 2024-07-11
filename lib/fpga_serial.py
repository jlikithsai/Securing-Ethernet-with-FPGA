'''Automatically find USB Serial Port
jodalyst 9/2017
'''

import serial.tools.list_ports

def get_usb_port():
	usb_port = list(serial.tools.list_ports.grep('USB-Serial Controller'))
	if len(usb_port) == 1:
		print('Automatically found USB-Serial Controller: {}'.format(usb_port[0].description))
		return usb_port[0].device
	else:
		ports = list(serial.tools.list_ports.comports())
		port_dict = {i:[ports[i],ports[i].vid] for i in range(len(ports))}
		usb_id = None
		for p in port_dict:
			print('{}:   {} (Vendor ID: {})'.format(p,port_dict[p][0],port_dict[p][1]))
			if port_dict[p][1]==1027:
				usb_id = p
		if usb_id == None:
			return None
		else:
			print('USB-Serial Controller: Device {}'.format(p))
			return port_dict[usb_id][0].device

def do_serial(callback):
	serial_port = get_usb_port()
	if serial_port is None:
		raise Exception('USB-Serial Controller Not Found')

	with serial.Serial(port = serial_port, 
		# 12mbaud
		baudrate=12000000,
		parity=serial.PARITY_NONE, 
		stopbits=serial.STOPBITS_ONE, 
		bytesize=serial.EIGHTBITS,
		# enable rts/cts processing
		rtscts=True,
		timeout=0) as ser:

		print(ser)
		print('Serial Connected!')

		if ser.isOpen():
			print(ser.name + ' is open...')

		callback(ser)
