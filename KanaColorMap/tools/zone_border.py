"""Build a UI contour from native coverage; never modifies terrain artwork."""
import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageOps


def outer_coverage(coverage):
    """Ignore enclosed alpha speckles, keeping every separate island perimeter."""
    flooded = ImageOps.expand(coverage, 1, fill=0)
    ImageDraw.floodfill(flooded, (0, 0), 128)
    return flooded.point(lambda a: 0 if a == 128 else 255).crop(
        (1, 1, coverage.width + 1, coverage.height + 1))


def build_border(mask, width, height, output_size):
    scale = 4
    size = (round(width * 2048 * scale), round(height * 2048 * scale))
    # Trace the native 50% contour, not the gradient of its blurred alpha.
    # Subtracting blurred masks made the ink fade along broad antialias ramps.
    sampled = mask.getchannel('A').resize(size, Image.Resampling.BILINEAR)
    coverage = outer_coverage(sampled.point(lambda a: 255 if a >= 128 else 0))
    # Narrow the frame on tiny islands so the terrain remains readable.
    factor = min(1, min(width, height) * 2048 / 64)
    outer = max(3, round(6 * factor))
    inner = max(outer + 3, round(14 * factor))
    padded = ImageOps.expand(coverage, inner, fill=0)

    def erode(radius):
        return np.asarray(padded.filter(ImageFilter.MinFilter(radius * 2 + 1))
                          .crop((inner, inner, inner + size[0], inner + size[1])), dtype=float)

    alpha = np.asarray(coverage, dtype=float)
    dark = alpha - erode(outer)
    light = erode(outer) - erode(inner)
    total = dark + light
    rgba = np.zeros((*total.shape, 4), dtype=np.uint8)
    for c, (ink, parchment) in enumerate(zip((68, 52, 29), (237, 212, 153))):
        rgba[:, :, c] = np.round((dark * ink + light * parchment) / np.maximum(total, 1))
    rgba[:, :, 3] = np.round(total)
    # Bilinear conversion keeps coverage nonnegative and avoids ringing outside it.
    result = Image.fromarray(rgba).resize(output_size, Image.Resampling.BILINEAR)
    # A subpixel island may survive in the final mask while vanishing in the
    # intermediate contour raster. Cover those final mask pixels explicitly.
    final_mask = mask.getchannel('A').resize(output_size, Image.Resampling.BILINEAR)
    final_coverage = outer_coverage(final_mask.point(lambda a: 255 if a >= 128 else 0))
    padded = ImageOps.expand(final_coverage, 1, fill=0)
    inner = padded.filter(ImageFilter.MinFilter(3)).crop(
        (1, 1, output_size[0] + 1, output_size[1] + 1))
    edge = (np.asarray(final_coverage) > 0) & (np.asarray(inner) == 0)
    nearby = np.asarray(result.getchannel('A').filter(ImageFilter.MaxFilter(3))) >= 128
    missed = edge & ~nearby
    if missed.any():
        pixels = np.asarray(result).copy()
        pixels[missed] = (68, 52, 29, 255)
        result = Image.fromarray(pixels)
    return result
