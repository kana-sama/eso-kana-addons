"""Export aligned DDS layers from the approved textured imagegen atlas.

Separates colored channels/emissive regions for resource clipping and animation.
All art comes from art/eso-wolf-textured-atlas.png, not procedural gradients.
"""
from pathlib import Path
from PIL import Image
ROOT=Path(__file__).resolve().parent.parent
src=Image.open(ROOT/'art/eso-wolf-textured-atlas.png').convert('RGB')
sx,sy=src.width/1536,src.height/1024

def crop(box):
    return src.crop(tuple(round(v*(sx if i%2==0 else sy)) for i,v in enumerate(box)))

def matte(im):
    im=im.convert('RGBA')
    im.putalpha(im.convert('L').point(lambda v: min(255,max(0,(v-3)*28))))
    return im

def save(name,im):
    im.save(ROOT/'textures'/(name+'.dds'),pixel_format='DXT5')
    with Image.open(ROOT/'textures'/(name+'.dds')) as check:
        check.load();assert check.size==im.size

def channel_layer(box,kind):
    raw=crop(box)
    frame=matte(raw)
    light=Image.new('RGBA',raw.size)
    for y in range(raw.height):
        for x in range(raw.width):
            r,g,b=raw.getpixel((x,y))
            # Only saturated channel colors; restrict vertically to avoid brass rims.
            if .18<y/raw.height<.81:
                m=max(0,min(1,((b-max(r,g*.8)-10)/40 if kind=='blue' else (min(r,g*1.8)-b-28)/65)))
            else:m=0
            if m:
                lum=round(.25*r+.75*g) if kind=='gold' else round(.45*g+.55*b)
                a=frame.getpixel((x,y))[3]
                light.putpixel((x,y),(lum,lum,lum,round(m*255)))
                frame.putpixel((x,y),(round(r*(1-m)+10*m),round(g*(1-m)+13*m),round(b*(1-m)+16*m),a))
    return frame,light

size=(1024,512)
frame=Image.new('RGBA',size)
for box,kind,y,h,name in [((58,273,1478,397),'blue',70,25,'EsoWolfForm')]:
    border,light=channel_layer(box,kind)
    wh=(round(274/300*1024),round(h/150*512))
    xy=(round(13/300*1024),round(y/150*512))
    frame.alpha_composite(border.resize(wh,Image.Resampling.LANCZOS),xy)
    layer=Image.new('RGBA',size)
    layer.alpha_composite(light.resize(wh,Image.Resampling.LANCZOS),xy)
    save(name,layer)
save('EsoWolfFrame',frame)

raw=crop((196,439,681,924)).resize((256,256),Image.Resampling.LANCZOS)
crest=matte(raw)
glyph=Image.new('RGBA',raw.size)
for y in range(256):
    for x in range(256):
        r,g,b=raw.getpixel((x,y))
        # Wolf is neutral ivory; border is yellow brass. Limit extraction to emblem.
        if 60<x<195 and 45<y<218:
            a=round(255*max(0,min(1,(min(r,g,b)-45)/70)))
            if a:
                glyph.putpixel((x,y),(r,g,b,a))
                if a>30:crest.putpixel((x,y),(21,22,21,255))
# Center by visible (not almost transparent) artwork bounds. One centered asset
# is shared by the base and emissive wolf, with matching crest/control dimensions.
bounds=glyph.getchannel('A').point(lambda v:255 if v>120 else 0).getbbox()
assert bounds
piece=glyph.crop(bounds)
centered=Image.new('RGBA',(256,256))
centered.alpha_composite(piece,((256-piece.width)//2,(256-piece.height)//2))
save('EsoWolfCrest',crest);save('EsoWolfGlyph',centered)
# Broaden the code-defined perimeter to ~5 UI units perpendicular to each side.
# Sample the existing brass bevel across this band, preserving its surface detail.
neutral=crest.copy();progress=Image.new('RGBA',crest.size)
for y in range(256):
    for x in range(256):
        dx,dy=x-127.5,y-127.5
        distance=abs(dx)+abs(dy)
        if 99<distance<128:
            t=max(0,min(1,(distance-100)/26))
            sample_distance=113+11*t
            px=round(127.5+dx*sample_distance/distance)
            py=round(127.5+dy*sample_distance/distance)
            r,g,b,_=crest.getpixel((px,py))
            lum=round(.25*r+.65*g+.1*b)
            alpha=round(255*max(0,min(1,distance-100,127-distance)))
            # A bright floor keeps the active band legible even on dark metal pits.
            light=round(175+80*lum/255)
            progress.putpixel((x,y),(light,light,light,alpha))
            neutral.putpixel((x,y),(round(lum*.35),round(lum*.36),round(lum*.37),alpha))
save('EsoWolfCrestNeutral',neutral);save('EsoWolfCrestProgress',progress)
# Unrotate the four textured sides into a square. Cropping in these coordinates
# produces perpendicular end caps; quarter masks retain exact mitered corners.
from math import sqrt
for i, box in enumerate(((128,0,256,128),(128,128,256,256),(0,128,128,256),(0,0,128,128)),1):
    side=Image.new('RGBA',(256,256))
    side.paste(progress.crop(box),box[:2])
    # Affine output square spans +/- 128/sqrt(2) in the unrotated coordinate system.
    side=side.transform((256,256),Image.Transform.AFFINE,
        (.5,-.5,128,.5,.5,0),resample=Image.Resampling.BICUBIC)
    save('EsoWolfSide'+str(i),side)
visible=centered.getchannel('A').point(lambda v:255 if v>120 else 0).getbbox()
assert abs((visible[0]+visible[2])/2-128)<=1 and abs((visible[1]+visible[3])/2-128)<=1

raw=crop((885,479,1283,877)).resize((256,256),Image.Resampling.LANCZOS)
active=matte(raw);idle=active.copy();glow=Image.new('RGBA',raw.size)
for y in range(256):
    for x in range(256):
        r,g,b,a=active.getpixel((x,y))
        m=max(0,min(1,(r-max(g,b)-12)/40)) if (x-128)**2+(y-128)**2<107**2 else 0
        if m:
            # Preserve etched brass and dark interior detail; isolate blood emission.
            idle.putpixel((x,y),(round(r*(1-.92*m)),round(g*(1-.7*m)),round(b*(1-.6*m)),a))
            glow.putpixel((x,y),(r,g,b,round(a*m*.7)))
flash=Image.new('RGBA',raw.size,(255,245,215,0))
flash.putalpha(glow.getchannel('A'))
save('EsoBloodActive',active);save('EsoBloodIdle',idle)
save('EsoBloodGlow',glow);save('EsoBloodFlash',flash)
print('PASS: textured bar layers, centered visible wolf, closed blood sockets, DDS decode')

# Compact stacks with vertical internal dividers. Continue the actual lower
# bevel of the main bar across the gap instead of choosing an unrelated angle.
from PIL import ImageDraw, ImageFilter, ImageChops
blood=crop((956,595,1210,749)).resize((256,64),Image.Resampling.LANCZOS).convert('RGBA')
metal=crop((121,106,1415,118)).resize((256,64),Image.Resampling.LANCZOS).convert('RGBA')
# Fit the existing exported bar silhouette in UI units; the segment row starts
# at x=24, y=99, with height 12. Both outer ends use this same extended line.
samples=[]
for y in (84,86,88,90,92,94):
    row=round(y/150*frame.height)
    x=next(x for x in range(frame.width//2) if frame.getpixel((x,row))[3]>180)
    samples.append((y,x*300/frame.width))
my=sum(y for y,x in samples)/len(samples)
mx=sum(x for y,x in samples)/len(samples)
slope=sum((y-my)*(x-mx) for y,x in samples)/sum((y-my)**2 for y,x in samples)
intercept=mx-slope*my
outer_top=slope*99+intercept-24
outer_bottom=slope*111+intercept-24
assert 0<outer_top<outer_bottom<60
for i in range(1,5):
    if i==1:points=[(outer_top,0),(60,0),(60,12),(outer_bottom,12)]
    elif i==4:points=[(0,0),(60-outer_top,0),(60-outer_bottom,12),(0,12)]
    else:points=[(0,0),(60,0),(60,12),(0,12)]
    mask=Image.new('L',(256,64))
    ImageDraw.Draw(mask).polygon([(round(x/60*255),round(y/12*63)) for x,y in points],fill=255)
    # Pad before erosion so straight top/bottom borders remain present too.
    padded=Image.new('L',(264,72));padded.paste(mask,(4,4))
    inner=padded.filter(ImageFilter.MinFilter(7)).crop((4,4,260,68))
    rim=metal.copy();rim.putalpha(ImageChops.subtract(mask,inner))
    active=blood.copy();active.putalpha(inner);active=Image.alpha_composite(active,rim)
    idle=blood.copy()
    idle=Image.merge('RGBA',tuple(c.point(lambda v:round(v*.08)) for c in idle.split()[:3])+(inner,))
    idle=Image.alpha_composite(idle,rim)
    glow=blood.copy();glow.putalpha(inner.point(lambda v:round(v*.65)))
    flash=Image.new('RGBA',(256,64),(255,245,215,0));flash.putalpha(inner)
    for name,im in [('Idle',idle),('Active',active),('Glow',glow),('Flash',flash)]:
        save('EsoBloodSegment'+str(i)+name,im)
print('PASS: four blood segments with vertical dividers and collinear outer bevels, closed frames, clipped emission and flash')
