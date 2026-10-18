"""Build the full-screen white alpha mask in ESO's legacy BGRA DDS format.

The outer 8% of each edge fades smoothly to a completely transparent center.
Uses only the Python standard library; run from any directory.
"""
from pathlib import Path
import struct

SIZE, FADE = 256, 20


def build():
    header = [124, 0x100F, SIZE, SIZE, SIZE * 4, 0, 0] + [0] * 11
    header += [32, 0x41, 0, 32, 0xFF0000, 0xFF00, 0xFF, 0xFF000000]
    header += [0x1000, 0, 0, 0, 0]
    pixels = bytearray()
    for y in range(SIZE):
        for x in range(SIZE):
            distance = min(x, y, SIZE - 1 - x, SIZE - 1 - y)
            alpha = round(255 * max(0, 1 - distance / FADE) ** 2)
            pixels.extend((255, 255, 255, alpha))
    return b'DDS ' + struct.pack('<31I', *header) + pixels


if __name__ == '__main__':
    target = Path(__file__).resolve().parent.parent / 'textures' / 'EdgeGlow.dds'
    target.parent.mkdir(exist_ok=True)
    target.write_bytes(build())
