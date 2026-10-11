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

print('PASS 40 zones: atlas alignment and no new crop seams')
