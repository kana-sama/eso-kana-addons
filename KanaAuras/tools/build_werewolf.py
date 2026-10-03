"""Separate the generated blue channel from its frame, export aligned DDS layers."""
from pathlib import Path
from PIL import Image
ROOT = Path(__file__).resolve().parent.parent
im = Image.open(ROOT/'art/werewolf-form.png').convert('RGB')
mask = im.convert('L').point(lambda v: 255 if v>20 else 0)
im = im.crop(mask.getbbox()).resize((512,128),Image.Resampling.LANCZOS)
frame = Image.new('RGBA',im.size)
fill = Image.new('RGBA',im.size)
for y in range(128):
    for x in range(512):
        r,g,b = im.getpixel((x,y))
        blue = min(1,max(0,(b-max(r,g*.75)-12)/45))
        alpha = min(255,max(r,g,b)*16)
        # Dark channel remains behind the clipped fill. All layers share geometry.
        frame.putpixel((x,y),(int(r*(1-blue)+12*blue),int(g*(1-blue)+15*blue),int(b*(1-blue)+20*blue),alpha))
        fill.putpixel((x,y),(b,b,b,round(blue*255)))
for name,sprite in [('Frame',frame),('Fill',fill)]:
    path=ROOT/'textures'/('Werewolf'+name+'.dds')
    sprite.save(path,pixel_format='DXT5')
    decoded=Image.open(path);decoded.load();assert decoded.size==(512,128)
print('PASS: aligned werewolf DDS layers; fill bounds',fill.getchannel('A').getbbox())
