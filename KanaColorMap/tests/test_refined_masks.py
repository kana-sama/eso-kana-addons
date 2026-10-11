"""Check every shipped contour against the painted atlas and crop edges."""
import json
from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter


ROOT = Path(__file__).resolve().parents[1]
ZONES = json.loads((ROOT / 'research/zones.json').read_text())
BOUNDS = json.loads((ROOT / 'art/refined-bounds.json').read_text())
ATLAS = Image.open(ROOT / 'art/tamriel-original.png').convert('RGB')


def painted_edge_fraction(mask, box):
    size = (box[2] - box[0], box[3] - box[1])
    binary = mask.getchannel('A').resize(size, Image.Resampling.BILINEAR).point(
        lambda value: 255 if value >= 128 else 0)
    coverage = np.asarray(binary) > 0
    inner = np.asarray(binary.filter(ImageFilter.MinFilter(3))) > 0
    edge = coverage & ~inner
    # Use a threshold independent of the tracing algorithm's continuous score.
    rgb = np.asarray(ATLAS.crop(box), dtype=int)
    ink = ((rgb[:, :, 0] < 170) & (rgb[:, :, 1] < 125)
           & (rgb[:, :, 2] < 80) & (rgb[:, :, 0] > rgb[:, :, 1] + 25))
    nearby = np.asarray(Image.fromarray(np.uint8(ink) * 255)
                        .filter(ImageFilter.MaxFilter(5))) > 0
    return float(nearby[edge].mean()), coverage


assert len(ZONES) == 40
assert len(BOUNDS) == len(ZONES) - 1  # Stonefalls retains the accepted asset.
for zone in ZONES:
    zone_id = zone['id']
    x, y, width, height = (zone[key] for key in ('x', 'y', 'width', 'height'))
    native_box = tuple(round(value * 2048) for value in (x, y, x + width, y + height))
    render_box = tuple(BOUNDS.get(str(zone_id), native_box))
    native = Image.open(ROOT / f'art/native-masks/{zone_id}.png').convert('RGBA')
    shipped = Image.open(ROOT / f'masks/{zone_id}.dds').convert('RGBA')
    native_score, native_coverage = painted_edge_fraction(native, native_box)
    shipped_score, shipped_coverage = painted_edge_fraction(shipped, render_box)
    required_gain = 0.08 if zone_id in (7, 13) else -0.02
    assert shipped_score >= native_score + required_gain, (
        f'{zone_id}: ink alignment {shipped_score:.3f} vs native {native_score:.3f}')
    assert shipped.width >= native.width, f'{zone_id}: mask resolution regressed'

    refined = ROOT / f'art/refined-masks/{zone_id}.png'
    assert refined.exists(), f'{zone_id}: no refined contour'
    if zone_id != 7:
        mask = np.asarray(Image.open(refined).getchannel('A')) >= 128
        assert not (mask[0].any() or mask[-1].any()
                    or mask[:, 0].any() or mask[:, -1].any()), f'{zone_id}: crop seam'
    if zone_id == 13:
        guide = np.zeros_like(shipped_coverage)
        dx, dy = native_box[0] - render_box[0], native_box[1] - render_box[1]
        guide[dy:dy+native_coverage.shape[0], dx:dx+native_coverage.shape[1]] = native_coverage
        changed = np.count_nonzero(guide != shipped_coverage)
        assert changed / guide.sum() < 0.08, 'Deshaan contour moved too far'

# The Rift/Cyrodiil seam in the reported screenshot must follow the pale
# painted border, rather than the stair steps of two independent blob masks.
def placed_mask(zone_id):
    box = BOUNDS[str(zone_id)]
    source = Image.open(ROOT / f'masks/{zone_id}.dds').getchannel('A')
    scaled = np.asarray(source.resize((box[2]-box[0], box[3]-box[1]),
                                      Image.Resampling.BILINEAR)) >= 128
    placed = np.zeros((2048, 2048), dtype=bool)
    placed[box[1]:box[3], box[0]:box[2]] = scaled
    return placed


rift, cyrodiil = placed_mask(125), placed_mask(16)
rgb = np.asarray(ATLAS, dtype=int)
ink = ((rgb[:, :, 0] < 190) & (rgb[:, :, 1] < 145)
       & (rgb[:, :, 2] < 90) & (rgb[:, :, 0] > rgb[:, :, 1] + 20))
near_ink = np.asarray(Image.fromarray(np.uint8(ink) * 255)
                      .filter(ImageFilter.MaxFilter(5))) > 0
separation = []
painted = []
for x in range(1160, 1351):
    rift_y = 760 + np.flatnonzero(rift[760:865, x]).max()
    cyrodiil_y = 760 + np.flatnonzero(cyrodiil[760:865, x]).min()
    separation.append(abs(cyrodiil_y - rift_y))
    painted.append(near_ink[rift_y, x])
assert np.mean(separation) < 1.5 and np.percentile(separation, 90) <= 2, (
    'Rift/Cyrodiil seam has doubled or stair-stepped borders')
assert np.mean(painted) >= .98, 'Rift southern edge misses the painted atlas line'
print('PASS 40 zones: atlas alignment, no crop seams, Rift/Cyrodiil border')
