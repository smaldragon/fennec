from PIL import Image

src = Image.open("font.png").convert("1")

with open("font.bin","wb") as f:
    data = []
    for i in range(1024):
        data.append(0)
    for c in range(256):
        for l in range(4):
            byt = 0
            for bit in range(8):
                px = (c%16)*4+l
                py = (int(c/16))*8+bit
                byt += (src.getpixel((px,py)) == 0) << bit
            data[c + 256*l] = byt
    print(data)
    f.write(bytes(data))