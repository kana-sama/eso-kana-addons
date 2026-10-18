"""Package generated circular flame artwork into registered DDS sector sprites.

Pillow is required. The angular clipping gives every rotated sprite the same
circle center and parallel neighboring end faces instead of trusting atlas layout.
"""
from pathlib import Path
import math
from PIL import Image, ImageChops, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
SIZE = 512
source = Image.open(ROOT / 'art/circular-fire.png').convert('RGB')
assert source.size == (1254, 1254)

for name, offset in (('Circle', 0), ('CircleGlow', 627)):
    # Register the artwork's circle center at the exact texture center.
    tile = source.crop((offset, 0, offset + 627, 627))
    tile = tile.transform((SIZE, SIZE), Image.Transform.AFFINE,
                          (1 / .82, 0, 313.5 - 256 / .82,
                           0, 1 / .82, 346 - 256 / .82), Image.Resampling.BICUBIC)
    # Shared 120-degree sectors separated by a constant-width strip. The art
    # remains within the upper sector; copies will be rotated by +/-120 degrees.
    mask = Image.new('L', (SIZE, SIZE))
    pixels = mask.load()
    for y in range(SIZE):
        for x in range(SIZE):
            dx, dy = x + .5 - 256, y + .5 - 256
            radius = math.hypot(dx, dy)
            edge = -dy * math.sin(math.pi / 3) - abs(dx) * .5 - 14
            distance = min(edge, radius - 158, 248 - radius)
            pixels[x, y] = round(255 * max(0, min(1, distance + .5)))
    tile = ImageChops.multiply(tile, mask.convert('RGB')).convert('RGBA')
    path = ROOT / 'textures' / (name + '.dds')
    tile.save(path, pixel_format='DXT5')
    decoded = Image.open(path)
    decoded.load()
    assert decoded.size == (SIZE, SIZE)
    assert decoded.getpixel((256, 256))[:3] == (0, 0, 0)
    for side, angle in (('Left', 120), ('Right', -120), ('Top', 0)):
        tile.rotate(angle, Image.Resampling.BICUBIC).save(
            ROOT / 'textures' / (name + side + '.dds'), pixel_format='DXT5')

# Verify and preview actual DDS sprites, including their rotation around center.
preview = Image.new('RGB', (768, 256), (22, 25, 30))
for stacks in (1, 2, 3):
    texture = Image.open(ROOT / 'textures' / ('CircleGlow.dds' if stacks == 3 else 'Circle.dds')).convert('RGB')
    ring = Image.new('RGB', (SIZE, SIZE))
    for angle in (120, -120, 0)[:stacks]:
        ring = ImageChops.add(ring, texture.rotate(angle, Image.Resampling.BICUBIC))
    ring = ring.resize((192, 192), Image.Resampling.LANCZOS)
    patch = Image.new('RGB', (256, 256))
    patch.paste(ring, (32, 32))
    background = preview.crop(((stacks - 1) * 256, 0, stacks * 256, 256))
    preview.paste(ImageChops.add(background, patch), ((stacks - 1) * 256, 0))
draw = ImageDraw.Draw(preview)
for cx in (128, 384, 640):
    for a,b in (((cx-9,128),(cx-4,128)),((cx+4,128),(cx+9,128)),((cx,119),(cx,124)),((cx,132),(cx,137))):
        draw.line((a,b), fill=(220,220,210), width=1)
preview.save('/tmp/kanaauras-circle-preview.png')
print('PASS: circular DDS sectors decoded, centers clear, 1/2/3 preview rendered')
