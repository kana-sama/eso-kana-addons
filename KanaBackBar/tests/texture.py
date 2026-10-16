"""Check the shipped texture rather than relying on a texture-control mock."""
from pathlib import Path
import struct

asset = (Path(__file__).resolve().parent.parent / 'textures' / 'EdgeGlow.dds').read_bytes()
assert asset[:4] == b'DDS '
assert struct.unpack_from('<3I', asset, 12) == (256, 256, 1024)
assert struct.unpack_from('<8I', asset, 76) == (
    32, 0x41, 0, 32, 0xFF0000, 0xFF00, 0xFF, 0xFF000000,
), 'Use the legacy BGRA DDS format that ESO loads'
assert len(asset) == 128 + 256 * 256 * 4


def pixel(x, y):
    offset = 128 + (y * 256 + x) * 4
    return tuple(asset[offset:offset + 4])


assert all(pixel(x, y) == (255, 255, 255, 255) for x, y in (
    (0, 128), (255, 128), (128, 0), (128, 255), (0, 0), (255, 255),
)), 'All four edges and their corners must glow'
assert pixel(128, 128)[3] == pixel(20, 128)[3] == 0, 'Keep the center completely transparent'
assert [pixel(x, 128)[3] for x in (0, 5, 10, 15, 20)] == [255, 143, 64, 16, 0], 'Fade inward smoothly'
assert all(pixel(x, 128) == pixel(255 - x, 128) == pixel(128, x) == pixel(128, 255 - x)
           for x in range(21)), 'Each edge must use the same fade'
print('PASS: 8 edge-glow texture checks')
