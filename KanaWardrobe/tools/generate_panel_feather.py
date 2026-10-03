"""Build the DDS alpha mask used by the fixed-edge description surface."""
from pathlib import Path
import struct

size = 64
center_alpha = 210  # 82% opaque: readable text with a faint view of the scene.
# Uncompressed BGRA8 DDS, supported by the same ESO texture loader as icons.
header = [124, 0x100F, size, size, size * 4, 0, 0] + [0] * 11
header += [32, 0x41, 0, 32, 0x00FF0000, 0x0000FF00, 0x000000FF, 0xFF000000]
header += [0x1000, 0, 0, 0, 0]
pixels = bytearray()
for y in range(size):
    for x in range(size):
        opacity = min(1, x / 16, (63 - x) / 16) * min(1, y / 16, (63 - y) / 16)
        pixels.extend((7, 5, 4, round(center_alpha * opacity)))
path = Path(__file__).resolve().parents[1] / 'assets' / 'panel_feather.dds'
path.write_bytes(b'DDS ' + struct.pack('<31I', *header) + pixels)
