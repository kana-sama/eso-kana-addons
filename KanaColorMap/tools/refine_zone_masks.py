"""Trace native zone contours against the ink on the original Tamriel atlas.

The native blob masks remain the topology and placement guide. After smoothing
their square corners, the search for painted ink is limited to twelve atlas
pixels on either side of that path, including outside clipped blob rectangles.
Run before package_zones.py when changing the source atlas or native masks.
"""
import json
import math
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter


ROOT = Path(__file__).resolve().parents[1]
ZONES = {zone['id']: zone for zone in json.loads((ROOT / 'research/zones.json').read_text())}
ATLAS = Image.open(ROOT / 'art/tamriel-original.png').convert('RGB')
PADDING = 16  # Atlas pixels around the native blob rectangle.
TARGETS = tuple(zone_id for zone_id in ZONES if zone_id != 7)


def boundary_loops(mask):
    """Follow each native pixel-cell edge, including separate small islands."""
    coverage = np.asarray(mask) >= 128
    height, width = coverage.shape
    edges = []
    for y in range(height):
        for x in range(width):
            if not coverage[y, x]:
                continue
            if y == 0 or not coverage[y - 1, x]:
                edges.append(((x, y), (x + 1, y)))
            if x == width - 1 or not coverage[y, x + 1]:
                edges.append(((x + 1, y), (x + 1, y + 1)))
            if y == height - 1 or not coverage[y + 1, x]:
                edges.append(((x + 1, y + 1), (x, y + 1)))
            if x == 0 or not coverage[y, x - 1]:
                edges.append(((x, y + 1), (x, y)))

    outgoing = {}
    for start, end in edges:
        outgoing.setdefault(start, []).append(end)
    remaining = set(edges)
    loops = []
    while remaining:
        start, current = min(remaining)
        previous = start
        loop = [start]
        while True:
            remaining.remove((previous, current))
            loop.append(current)
            if current == start:
                break
            choices = [point for point in outgoing[current]
                       if (current, point) in remaining]
            if not choices:
                raise ValueError(f'open native boundary at {current}')
            if len(choices) > 1:
                dx, dy = current[0] - previous[0], current[1] - previous[1]
                choices.sort(key=lambda point:
                             dx * (point[1] - current[1])
                             - dy * (point[0] - current[0]), reverse=True)
            previous, current = current, choices[0]
        loops.append(loop)
    return loops


def sample_bilinear(image, locations):
    height, width = image.shape
    x = np.clip(locations[:, 0], 0, width - 1.001)
    y = np.clip(locations[:, 1], 0, height - 1.001)
    ix, iy = np.floor(x).astype(int), np.floor(y).astype(int)
    fx, fy = x - ix, y - iy
    return (image[iy, ix] * (1 - fx) * (1 - fy)
            + image[iy, ix + 1] * fx * (1 - fy)
            + image[iy + 1, ix] * (1 - fx) * fy
            + image[iy + 1, ix + 1] * fx * fy)


def ink_score(atlas_crop):
    rgb = np.asarray(atlas_crop, dtype=float)
    red, green, blue = rgb[:, :, 0], rgb[:, :, 1], rgb[:, :, 2]
    brown = (np.clip((190 - red) / 90, 0, 1)
             * np.clip((150 - green) / 90, 0, 1)
             * np.clip((100 - blue) / 70, 0, 1)
             * np.clip((red - green - 20) / 30, 0, 1))
    blurred = Image.fromarray(np.uint8(brown * 255)).filter(
        ImageFilter.GaussianBlur(0.8))
    return np.asarray(blurred, dtype=float) / 255


def trace_loop(loop, native_size, world_size, origin, score):
    points = np.array(loop[:-1], dtype=float)
    points[:, 0] *= world_size[0] / native_size[0]
    points[:, 1] *= world_size[1] / native_size[1]
    points += origin
    segments = np.diff(np.vstack((points, points[0])), axis=0)
    lengths = np.linalg.norm(segments, axis=1)
    cumulative = np.r_[0, np.cumsum(lengths)]
    count = max(10, round(cumulative[-1]))
    positions = np.linspace(0, cumulative[-1], count, endpoint=False)
    indices = np.searchsorted(cumulative[1:], positions)
    fraction = (positions - cumulative[indices]) / np.maximum(lengths[indices], 1e-9)
    original = points[indices] + segments[indices] * fraction[:, None]

    # Remove the low-resolution mask's square corners before looking for ink.
    radius = np.arange(-12, 13)
    weights = np.exp(-0.5 * (radius / 4) ** 2)
    weights /= weights.sum()
    curve = sum(np.roll(original, shift, axis=0) * weight
                for shift, weight in zip(radius, weights))
    tangent = np.roll(curve, -5, axis=0) - np.roll(curve, 5, axis=0)
    magnitude = np.maximum(np.linalg.norm(tangent, axis=1), 1e-9)
    normal = np.stack((-tangent[:, 1] / magnitude,
                       tangent[:, 0] / magnitude), axis=1)
    offsets = np.arange(-12, 13, dtype=float)
    candidates = curve[:, None, :] + normal[:, None, :] * offsets[None, :, None]
    ink = sample_bilinear(score, candidates.reshape(-1, 2)).reshape(count, len(offsets))
    local_cost = -12 * ink + 0.032 * offsets[None, :] ** 2
    transition = 0.7 * (offsets[:, None] - offsets[None, :]) ** 2
    # Solve the closed path, including the join between its last and first points.
    best_cost = math.inf
    best_indices = None
    for start in range(len(offsets)):
        costs = np.full(len(offsets), math.inf)
        costs[start] = local_cost[0, start]
        predecessor = np.zeros((count, len(offsets)), dtype=np.int8)
        for index in range(1, count):
            options = costs[:, None] + transition
            predecessor[index] = np.argmin(options, axis=0)
            costs = local_cost[index] + options[predecessor[index], np.arange(len(offsets))]
        end = int(np.argmin(costs + transition[:, start]))
        cost = costs[end] + transition[end, start]
        if cost < best_cost:
            best_cost = cost
            chosen = np.empty(count, dtype=np.int8)
            at = end
            for index in range(count - 1, -1, -1):
                chosen[index] = at
                at = predecessor[index, at]
            best_indices = chosen
    return curve + normal * offsets[best_indices, None]


def refine(zone_id):
    zone = ZONES[zone_id]
    x, y, width, height = (zone[key] for key in ('x', 'y', 'width', 'height'))
    bounds = tuple(round(value) for value in
                   (x * 2048, y * 2048, (x + width) * 2048, (y + height) * 2048))
    world_size = (bounds[2] - bounds[0], bounds[3] - bounds[1])
    expanded = (max(0, bounds[0] - PADDING), max(0, bounds[1] - PADDING),
                min(2048, bounds[2] + PADDING), min(2048, bounds[3] + PADDING))
    origin = np.array((bounds[0] - expanded[0], bounds[1] - expanded[1]))
    render_size = (expanded[2] - expanded[0], expanded[3] - expanded[1])
    native = Image.open(ROOT / f'art/native-masks/{zone_id}.png').getchannel('A')
    score = ink_score(ATLAS.crop(expanded))
    result = Image.new('L', render_size, 0)
    polygons = []
    for loop in boundary_loops(native):
        area = sum(loop[index][0] * loop[index + 1][1]
                   - loop[index + 1][0] * loop[index][1]
                   for index in range(len(loop) - 1)) / 2
        if abs(area) >= 1:
            polygons.append((abs(area), area,
                             trace_loop(loop, native.size, world_size, origin, score)))
    draw = ImageDraw.Draw(result)
    for _, area, path in sorted(polygons, key=lambda item: item[0], reverse=True):
        draw.polygon([tuple(point) for point in path], fill=255 if area > 0 else 0)
    result = result.filter(ImageFilter.GaussianBlur(0.45))

    texture_size = tuple(max(32, 2 ** math.ceil(math.log2(value)))
                         for value in render_size)
    alpha = result.resize(texture_size, Image.Resampling.BILINEAR)
    mask = Image.merge('RGBA', (alpha, alpha, alpha, alpha))
    destination = ROOT / f'art/refined-masks/{zone_id}.png'
    destination.parent.mkdir(parents=True, exist_ok=True)
    mask.save(destination)
    print(f'{zone_id}: traced {len(polygons)} contours into {texture_size}')
    return expanded


if __name__ == '__main__':
    bounds_path = ROOT / 'art/refined-bounds.json'
    refined_bounds = json.loads(bounds_path.read_text()) if bounds_path.exists() else {}
    for target in TARGETS:
        refined_bounds[str(target)] = refine(target)
    bounds_path.write_text(json.dumps(refined_bounds, indent=2) + '\n')
