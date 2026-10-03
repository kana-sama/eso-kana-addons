"""Package the approved thick dual bar and closed sockets as aligned DDS layers."""
from pathlib import Path
from PIL import Image
ROOT=Path(__file__).resolve().parent.parent
src=Image.open(ROOT/'art/werewolf-fury-atlas.png').convert('RGB')
w,h=src.size
sx,sy=w/1280,h/1280

def crop(box,size):
    return src.crop(tuple(round(v*(sx if i%2==0 else sy)) for i,v in enumerate(box))).resize(size,Image.Resampling.LANCZOS)
def matte(im):
    im=im.convert('RGBA');im.putalpha(im.convert('L').point(lambda v:min(255,v*20)));return im
def save(name,im):
    path=ROOT/'textures'/(name+'.dds');im.save(path,pixel_format='DXT5')
    check=Image.open(path);check.load();assert check.size==im.size
bar=crop((0,96,680,462),(512,256))
frame=matte(bar);blue=Image.new('RGBA',bar.size);gold=Image.new('RGBA',bar.size)
for y in range(256):
 for x in range(512):
    r,g,b=bar.getpixel((x,y))
    mb=min(1,max(0,(b-max(r,g*.8)-10)/40))
    mg=min(1,max(0,(min(r,g*1.8)-b-20)/50))
    # Remove baked channel light; the empty channels remain dark and readable.
    m=max(mb,mg)
    old=frame.getpixel((x,y));frame.putpixel((x,y),(round(r*(1-m)+12*m),round(g*(1-m)+14*m),round(b*(1-m)+18*m),old[3]))
    lum=round(.7*g+.3*b)
    blue.putpixel((x,y),(lum,lum,lum,round(mb*255)))
    lum=round(.25*r+.75*g)
    gold.putpixel((x,y),(lum,lum,lum,round(mg*255)))
save('FuryFrame',frame);save('FuryForm',blue);save('FuryFill',gold)
orb=matte(crop((700,42,1196,540),(256,256)))
idle=orb.copy();glow=Image.new('RGBA',orb.size)
for y in range(256):
 for x in range(256):
    r,g,b,a=orb.getpixel((x,y));m=min(1,max(0,(r-max(g,b)-15)/65))
    idle.putpixel((x,y),(round(r*(1-.87*m)),round(g*(1-.8*m)),round(b*(1-.8*m)),a))
    # Only the ruby emits extra light; its complete metal border stays fixed.
    glow.putpixel((x,y),(r,g,b,round(a*m)))
save('BloodSocketActive',orb);save('BloodSocketIdle',idle);save('BloodSocketGlow',glow)
flash=Image.new('RGBA',glow.size,(255,255,255,0))
flash.putalpha(glow.getchannel('A'))
save('BloodSocketFlash',flash)
save('FuryWolf',matte(crop((677,624,1210,1178),(256,256))))
print('PASS: dual bar, separate resource masks, closed sockets and wolf DDS decoded')
