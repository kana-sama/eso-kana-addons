# ESO-style Werewolf HUD, 3.9

Reference: user's actual ESO resource-bar screenshot, 2026-09-24 01:32:38,
and approved concept with two bars, diamond wolf crest, four closed sockets.
Flat clipped corners, muted brass edges, dark interiors and simple resource fills.
Existing resource tracking, Devour prediction and full-state animations retained.

`eso-wolf-glyph.png` was generated with the built-in imagegen tool, then resized
and packaged as DDS; other assets are code-defined UI geometry in
`tools/build_eso_wolf.py`. No original ESO art is bundled.

Final generation prompt:

> Create a production game UI sprite: single flat ivory-white frontal wolf head heraldic glyph, angular pointed ears, sharp symmetrical cheek fur, narrow eyes cut out as transparent negative space, dark nose negative space. Elder Scrolls Online minimalist HUD icon language, recognizable strong wolf silhouette at 32 pixels. No circle, no diamond, no frame, no text, no scenery, no other assets, no glow, no 3D, no photorealism, no shadows. Centered with small padding on a genuinely transparent background, square 1024 canvas. This is the standalone flat wolf emblem for a restrained brass-and-dark ESO resource HUD.

`eso-wolf-preview.gif` is a texture-based illustration of three states at 1.5×,
not an ESO screenshot or verification of client rendering/events. The game
uses its existing cooldown indicator, not the illustrative circle in this preview.

## Textured revision 3.9.1

Current source: `eso-wolf-textured-atlas.png`, generated with built-in imagegen
using the approved concept as a reference. Previous flat glyph remains archived.
`build_eso_wolf.py` crops and separates resource and emissive masks; visible wolf
bounds (alpha > 120) are centered before export. Sockets are 38 UI units,
with 11 units of air below the form bar.

Generation brief: production texture atlas, pure black background, no text or scenery.
Top: two isolated straight clipped-end bars, full gold and full blue, weathered brass
rims, fine cloudy magical grain. Bottom left: dark diamond badge, brass bevel,
large centered ivory silver frontal wolf. Bottom right: fully closed worn brass
socket with rich maroon magical light, swirling wisps, tiny embers and branching
red veins; no ball, glossy gem, specular dot or smooth radial gradient.

## Perimeter revision 3.10

Removed horizontal Fury bar; the textured diamond rim now fills clockwise from
the top. Full Fury makes the wolf gold. Rampage turns wolf/rim red and drains
the rim counterclockwise using real buff time. Four UV-clipped quadrants give
continuous progress, with no discrete sprite steps. Crest center moves from
y=34 to y=64, overlapping the remaining form bar. Sockets and drag anchor unchanged.
Existing artwork was exported into neutral and emissive rim layers.

## Compact Blood Hunger segments 3.11

Four circles replaced by code-defined 60x12 chevrons at x=-96,-32,32,96, y=105
in the existing 300x150 HUD. Identical 4-unit spacing and 4-unit bar clearance.
Outer ends mirror the main bar bevel; interior ends interlock visually as arrows.
Existing atlas blood/brass textures are clipped to these masks. Emission and
arrival flashes remain inside the shapes, with no rotation or scaling.
