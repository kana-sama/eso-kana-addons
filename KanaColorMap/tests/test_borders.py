"""Check shipped UI contour coverage for every native world-map zone."""
import json
from pathlib import Path
import xml.etree.ElementTree as ET
import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageOps

ROOT = Path(__file__).resolve().parents[1]
zones = json.loads((ROOT / 'research/zones.json').read_text())
rows = []
for zone in zones:
    zone_id = zone['id']
    border = Image.open(ROOT / f'textures/borders/{zone_id}.dds').convert('RGBA')
    assert border.size == Image.open(ROOT / f'textures/zones/{zone_id}.dds').size
    assert np.array_equal(np.array(border), np.array(Image.open(ROOT / f'art/zone-borders/{zone_id}.png')))
    native = Image.open(ROOT / f'masks/{zone_id}.dds').getchannel('A').resize(border.size, Image.Resampling.BILINEAR)
    binary = native.point(lambda a: 255 if a >= 128 else 0)
    # Flood from outside so only real exterior perimeters, including every
    # separate island, are tested. Enclosed matte holes aren't province borders.
    flooded = ImageOps.expand(binary, 1, fill=0)
    ImageDraw.floodfill(flooded, (0, 0), 128)
    filled = flooded.point(lambda a: 0 if a == 128 else 255).crop((1, 1, binary.width+1, binary.height+1))
    eroded = ImageOps.expand(filled, 1, fill=0).filter(ImageFilter.MinFilter(3)).crop((1, 1, filled.width+1, filled.height+1))
    edge = (np.array(filled)>0) & (np.array(eroded)==0)
    alpha = border.getchannel('A')
    local_alpha = np.array(alpha.filter(ImageFilter.MaxFilter(3)))[edge]
    gaps = int((local_alpha < 128).sum())
    assert gaps == 0, f'{zone_id}: {gaps} unoutlined boundary pixels'
    safe_outside = np.array(filled.filter(ImageFilter.MaxFilter(9))) == 0
    assert np.array(alpha)[safe_outside].max(initial=0) == 0, f'{zone_id}: detached outline'
    rows.append({'id': zone_id, 'name': zone['englishName'], 'boundaryPixels': int(edge.sum()), 'gaps': gaps})

root = ET.parse(ROOT / 'art/tamriel-preview.svg').getroot()
images = [element for element in root if element.tag.endswith('}image')]
assert len(images) == 1 + len(zones)*2
assert all('mask' in im.attrib for im in images[1:len(zones)+1])
assert all('mask' not in im.attrib for im in images[len(zones)+1:]), 'contours must follow all artwork'
assert len(list((ROOT / 'textures/borders').glob('*.dds'))) == len(zones)
(ROOT / 'research/border-coverage.json').write_text(json.dumps(rows, ensure_ascii=False, indent=2)+'\n')
print(f'PASS {len(zones)} zones: {sum(row["boundaryPixels"] for row in rows)} exterior boundary samples, zero gaps; DDS/preview match; global contour pass')
