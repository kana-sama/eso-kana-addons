"""Texture-based animation preview, not a capture from the ESO client."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageChops
import math
root=Path(__file__).resolve().parent.parent
textures={p.stem:Image.open(p).convert('RGBA') for p in (root/'textures').glob('Eso*.dds')}
textures['BloodSmoke']=Image.open(root/'textures/BloodSmoke.dds').convert('RGBA')
def place(dst,name,box,color=(1,1,1,1),uv=None,add=False,rotation=0):
 x,y,w,h=map(round,box);im=textures[name]
 if uv:im=im.crop((round(uv[0]*im.width),round((uv[2] if len(uv)>2 else 0)*im.height),round(uv[1]*im.width),round((uv[3] if len(uv)>2 else 1)*im.height)))
 if im.width==0 or w<1:return
 im=im.resize((w,h),Image.Resampling.LANCZOS)
 if rotation:im=im.rotate(rotation,resample=Image.Resampling.BICUBIC)
 im=Image.merge('RGBA',tuple(ch.point(lambda v,c=c:round(v*c)) for ch,c in zip(im.split(),color)))
 if add:
  rgb=Image.merge('RGB',tuple(ImageChops.multiply(ch,im.getchannel('A')) for ch in im.split()[:3]))
  layer=Image.new('RGB',dst.size);layer.paste(rgb,(x,y));dst.paste(ImageChops.add(dst.convert('RGB'),layer).convert('RGBA'))
 else:dst.alpha_composite(im,(x,y))
def beat(t):return math.sin(math.pi*(t%1)/.5)**2 if t%1<.5 else 0
frames=[]
for n in range(40):
 t=n/20
 im=Image.new('RGBA',(1440,510),(24,28,30,255));draw=ImageDraw.Draw(im)
 for panel,(fury,count) in enumerate(((.45,2),(1,4),(.6,4))):
  x,y=15+panel*480,52;w,h=450,225
  draw.text((x+140,18),('ACCUMULATING','FURY READY','RAMPAGE')[panel],fill='#c5bea8')
  place(im,'EsoWolfFrame',(x,y,w,h))
  for name,frac in [('EsoWolfForm',.65)]:
   for i in range(1):
    l=.07+i*.86;r=min(l+.86,.07+.86*frac)
    if r<=l:continue
    wave=.5+.5*math.sin(t*2.8-(i+1)*.38)
    color=(.12+.06*wave,.65+.05*wave,1,1) if name=='EsoWolfForm' else ((1,.65+.25*beat(t),.12,.5+.5*beat(t)) if panel==1 else ((1,.15,.035,.95) if panel==2 else (1,.78,.12,.9)))
    place(im,name,(x+l*w,y,(r-l)*w,h),color,uv=(l,r))
  l=.07+.86*.65;r=.07+.86*.80
  place(im,'EsoWolfForm',(x+l*w,y,(r-l)*w,h),(.65,.85,1,.20),uv=(l,r))
  cx,cy=x+w/2,y+64*1.5
  place(im,'EsoWolfCrestNeutral',(cx-51,cy-51,102,102))
  value=(.65+.25*t/2) if panel==0 else (1 if panel==1 else 1-t/2)
  rimcolor=(1,.65+.25*beat(t),.12,.5+.5*beat(t)) if panel==1 else ((1,.15,.035,.95) if panel==2 else (1,.78,.12,.9))
  rim=Image.new('RGBA',(256,256))
  for i in range(4):
   q=max(0,min(1,value*4-i))
   if q<=0:continue
   edge=round(q*256)
   if i==0:box=(0,0,edge,256)
   elif i==1:box=(0,0,256,edge)
   elif i==2:box=(256-edge,0,256,256)
   else:box=(0,256-edge,256,256)
   side=textures['EsoWolfSide'+str(i+1)].crop(box)
   rim.alpha_composite(side,box[:2])
  textures['RimPreview']=rim.rotate(-45,Image.Resampling.BICUBIC,expand=True)
  place(im,'RimPreview',(cx-51,cy-51,102,102),rimcolor)
  color=(1,1,1,1) if panel==0 else ((1,.72+.18*beat(t-.25),.25,1) if panel==1 else (1,.12,.08,1))
  place(im,'EsoWolfGlyph',(cx-51,cy-51,102,102),color)
  if panel:
   b=beat(t-.25) if panel==1 else .5+.5*math.sin(t*8)
   size=(68+8*b if panel==1 else 72)*1.5
   tint=(1,.55+.35*b,.12,.2+.8*b) if panel==1 else (1,.025,.015,.45+.55*b)
   place(im,'EsoWolfGlyph',(cx-size/2,cy-size/2,size,size),tint,add=True)
  if panel==2:
   place(im,'BloodSmoke',(cx-70.5,cy-70.5,141,141),(1,.08,.04,.35+.3*b),add=True,rotation=math.degrees(t*.4))
   for ex in [-7.2,7.2]:place(im,'EsoBloodFlash',(cx+ex*1.5-9,cy+3-6,18,12),(1,.12+.2*b,.06,.7+.3*b),add=True)
  for i,ox in enumerate([-96,-32,32,96],1):
   cx,cy=x+w/2+ox*1.5,y+(75+30)*1.5
   box=(cx-45,cy-9,90,18)
   prefix='EsoBloodSegment'+str(i)
   place(im,prefix+'Idle',box,(.75,.75,.75,1))
   if i<=count:place(im,prefix+'Active',box)
   if count==4:
    p=.5+.5*math.sin(t*5)
    place(im,prefix+'Glow',box,(1,.7+.3*p,.7+.3*p,.15+.85*p),add=True)
    wave=.5+.5*math.sin(t*2.3+i*1.7)
    place(im,prefix+'Glow',box,(1,.55,.55,.2+.18*wave),add=True)
  cx,cy=x+w/2,382
  draw.ellipse((cx-65,cy-65,cx+65,cy+65),outline='#0b0e0f',width=9)
  draw.arc((cx-65,cy-65,cx+65,cy+65),270,320,fill='#a19132',width=9)
  draw.line((cx-6,cy,cx+6,cy),fill='white');draw.line((cx,cy-6,cx,cy+6),fill='white')
 frames.append(im.convert('RGB'))
frames[0].save(root/'art/eso-wolf-preview.png')
frames[0].save(root/'art/eso-wolf-preview.gif',save_all=True,append_images=frames[1:],duration=50,loop=0)
