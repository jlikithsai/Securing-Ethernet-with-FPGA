from PIL import Image

def colors_to_bytes(arr):
	res = []
	for i in range(len(arr)//2):
		col1, col2 = arr[i*2], arr[i*2+1]
		res += [
			col1 >> 4,
			((col1 & 0xf) << 4) | (col2 >> 8),
			col2 & 0xff
		]
	return bytes(res)

def image_to_colors(fin_name, width, height):
	im = Image.open(fin_name).convert('RGB')
	im = im.resize((width, height))
	colors = []
	for i in range(height):
		for j in range(width):
			r, g, b = im.getpixel((j, i))
			r >>= 4
			g >>= 4
			b >>= 4
			colors += [(r << 8) | (g << 4) | b]
	im.close()
	return colors

def image_to_bytestream(fin_name, width, height):
	return colors_to_bytes(image_to_colors(fin_name, width, height))
