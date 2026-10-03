"""Code-defined feeding overlay sprites: filament, diamond checkpoint and spark."""
from pathlib import Path
from math import exp
from PIL import Image
ROOT=Path(__file__).resolve().parent.parent
for name,w,h in [('DevourThread',128,16),('DevourMark',32,64),('DevourSpark',128,128),('DevourHalo',128,128)]:
    im=Image.new('RGBA',(w,h))
    for y in range(h):
        for x in range(w):
            dx=(x+.5-w/2)/(w/2);dy=(y+.5-h/2)/(h/2)
            if name=='DevourThread':
                a=min(1,exp(-dy*dy*38)+.25*exp(-dy*dy*4))
            elif name=='DevourHalo':
                r2=dx*dx+dy*dy
                a=exp(-r2*3)*max(0,1-r2)**2
            elif name=='DevourMark':
                a=max(0,min(1,(.92-abs(dx)-abs(dy))*20))
            else:
                r2=dx*dx+dy*dy
                halo=.3*exp(-r2*12)
                rays=.7*exp(-abs(dx)*70-abs(dy)*5)+.7*exp(-abs(dy)*70-abs(dx)*5)
                a=min(1,halo+rays+exp(-r2*180))
            im.putpixel((x,y),(255,255,255,round(255*a)))
    im.save(ROOT/'textures'/(name+'.dds'),pixel_format='DXT5')
    with Image.open(ROOT/'textures'/(name+'.dds')) as check:
        check.load();assert check.size==(w,h)
print('PASS: feeding thread, checkpoint and spark DDS decoded')
