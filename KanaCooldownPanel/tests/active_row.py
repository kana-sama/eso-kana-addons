"""Validate the shipped backdrop, including the legacy DDS format used by ESO assets."""
from pathlib import Path
import runpy
import struct

addon = Path(__file__).resolve().parent.parent
asset = (addon / 'textures' / 'ActiveRow.dds').read_bytes()
assert asset[:4] == b'DDS ', 'Backdrop must be a DDS texture'
height, width, pitch = struct.unpack_from('<3I', asset, 12)
assert (width, height, pitch) == (256, 64, 1024)
# Match the classic A8R8G8B8 (BGRA bytes) format of the working KanaInfoBar assets.
assert struct.unpack_from('<8I', asset, 76) == (
    32, 0x41, 0, 32, 0x00FF0000, 0x0000FF00, 0x000000FF, 0xFF000000
), 'Backdrop must use the established BGRA DDS format, not RGBA'
assert len(asset) == 128 + pitch * height, 'DDS pixel data must be complete'

def pixel(x, y):
    offset = 128 + y * pitch + x * 4
    return tuple(asset[offset:offset + 4])

assert pixel(117, 25) == (255, 255, 255, 255), 'White interior must be opaque before control tint'
assert pixel(0, 0)[3] == pixel(233, 0)[3] == pixel(0, 49)[3] == pixel(233, 49)[3] == 0, 'Corners must be rounded'
assert pixel(234, 25)[3] == pixel(117, 50)[3] == 0, 'Unused texture area must be transparent'
assert any(0 < alpha < 255 for alpha in asset[131::4]), 'Rounded edges must retain antialiasing'
builder = runpy.run_path(str(addon / 'tools' / 'build_active_row.py'))
assert builder['build']() == asset, 'Committed texture must match the builder'
print('PASS: backdrop DDS format, opaque fill, rounded alpha mask and reproducible build')
