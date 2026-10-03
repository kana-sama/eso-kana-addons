"""Package generated Blood Hunger sprite atlas as ESO-compatible DXT5 DDS."""
from pathlib import Path
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
source = Image.open(ROOT / 'art/blood-hunger.png').convert('RGB')
w, h = source.size
assert w == h and w % 2 == 0
half = w // 2
for name, box in {
    'Orb': (0, 0, half, half),
    'Charged': (half, 0, w, half),
    'Smoke': (0, half, half, h),
    'Spine': (half, half, w, h),
}.items():
    sprite = source.crop(box)
    if name in ('Orb', 'Charged'):
        # Isolate the orb from wisps in the neighbouring smoke tile.
        mask = Image.new('L', sprite.size)
        ImageDraw.Draw(mask).ellipse((half*.065, half*.025, half*.935, half*.885), fill=255)
        clean = Image.new('RGB', sprite.size)
        clean.paste(sprite, (0, 0), mask)
        sprite = clean.crop((half*.04, 0, half*.96, half*.92))
    if name == 'Spine':
        sprite = sprite.crop((half*.35, 0, half*.85, half*.85))
        # Trim black padding so the connector follows the reticle's right arc.
        mask = sprite.convert('L').point(lambda v: 255 if v > 20 else 0)
        sprite = sprite.crop(mask.getbbox())
    sprite = sprite.resize((256, 256), Image.Resampling.LANCZOS).convert('RGBA')
    if name != 'Smoke':
        # The generated atlas uses black as matte. Preserve dark metal interiors.
        sprite.putalpha(Image.eval(sprite.convert('RGB').convert('L'), lambda v: min(255, v * 16)))
    sprite.save(ROOT / 'textures' / ('Blood' + name + '.dds'), pixel_format='DXT5')
    with Image.open(ROOT / 'textures' / ('Blood' + name + '.dds')) as check:
        check.load()
        assert check.size == (256, 256)
print('PASS: four Blood Hunger DDS assets decoded')
