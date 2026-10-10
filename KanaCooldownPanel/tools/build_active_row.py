"""Build an antialiased white rounded rectangle in a classic BGRA DDS.

234x50 UI pixels (226x42 row + 4px padding), on a 256x64 power-of-two texture.
Run from any directory; uses only the Python standard library.
"""
import math
from pathlib import Path
import struct

WIDTH, HEIGHT = 256, 64
RECT_WIDTH, RECT_HEIGHT, RADIUS = 234, 50, 8


def pixels():
    result = bytearray()
    for y in range(HEIGHT):
        for x in range(WIDTH):
            qx = abs(x + 0.5 - RECT_WIDTH / 2) - (RECT_WIDTH / 2 - RADIUS)
            qy = abs(y + 0.5 - RECT_HEIGHT / 2) - (RECT_HEIGHT / 2 - RADIUS)
            distance = math.hypot(max(qx, 0), max(qy, 0)) + min(max(qx, qy), 0) - RADIUS
            alpha = round(255 * max(0, min(1, 0.5 - distance)))
            result.extend((255, 255, 255, alpha))  # White B, G, R; straight alpha.
    return bytes(result)


def build():
    header = [124, 0x100F, HEIGHT, WIDTH, WIDTH * 4, 0, 0] + [0] * 11
    # Use the same legacy A8R8G8B8 layout as the working KanaInfoBar textures.
    header += [32, 0x41, 0, 32, 0xFF0000, 0xFF00, 0xFF, 0xFF000000]
    header += [0x1000, 0, 0, 0, 0]
    return b'DDS ' + struct.pack('<31I', *header) + pixels()


if __name__ == '__main__':
    target = Path(__file__).resolve().parent.parent / 'textures' / 'ActiveRow.dds'
    target.parent.mkdir(exist_ok=True)
    target.write_bytes(build())
