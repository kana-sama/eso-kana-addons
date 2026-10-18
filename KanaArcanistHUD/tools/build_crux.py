"""Package the approved jade ring and independent smoke into game DDS assets."""
from pathlib import Path
import math
from PIL import Image, ImageChops, ImageDraw, ImageEnhance

ROOT=Path(__file__).resolve().parent.parent
SIZE=512
source=Image.open(ROOT/'art/crux-jade.png').convert('RGB')
assert source.size==(1254,1254)
ring=source.crop((0,0,627,627)).resize((SIZE,SIZE),Image.Resampling.LANCZOS).convert('RGBA')
smoke=source.crop((627,0,1254,627)).resize((SIZE,SIZE),Image.Resampling.LANCZOS).convert('RGBA')
sectors={n:Image.new('RGBA',(SIZE,SIZE)) for n in ('Left','Right','Top')}
for y in range(SIZE):
    for x in range(SIZE):
        rgb=ring.getpixel((x,y))[:3]
        # Black-background sprite matting preserves dark stone and clears empty space.
        alpha=min(255,round(max(rgb)/16*255))
        pixel=(*rgb,alpha)
        ring.putpixel((x,y),pixel)
        angle=math.degrees(math.atan2(y+.5-256,x+.5-256))%360
        side='Right' if angle<90 or angle>=330 else ('Left' if angle<210 else 'Top')
        sectors[side].putpixel((x,y),pixel)
assets={**{'Jade'+n:im for n,im in sectors.items()},'JadeFull':ring,'JadeSmoke':smoke}
for name,im in assets.items():
    path=ROOT/'textures'/('Crux'+name+'.dds')
    im.save(path,pixel_format='DXT5')
    decoded=Image.open(path);decoded.load()
    assert decoded.size==(SIZE,SIZE)
    if name!='JadeSmoke': assert decoded.getpixel((256,256))[3]==0
alphas=[sectors[n].getchannel('A').tobytes() for n in ('Left','Right','Top')]
assert all(a+b+c==f for a,b,c,f in zip(*alphas,ring.getchannel('A').tobytes()))
print('PASS: jade DDS decoded; sections exactly partition full ring; center transparent')
