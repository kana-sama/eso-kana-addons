dofile('Core.lua')
dofile('UI.lua')
local K=KanaZoneGoals
TOPLEFT=1
local function label()
 return {SetFont=function(self,v)self.font=v end,SetWidth=function(self,v)self.width=v end,
 SetText=function(self,v)self.text=v end,GetTextHeight=function(self)return self.text=='Long source' and 48 or 24 end,
 ClearAnchors=function()end,SetAnchor=function(self,_,_,_,x,y)self.x=x;self.y=y end,
 SetDimensions=function(self,w,h)self.width=w;self.height=h end,SetHidden=function(self,v)self.hidden=v end,
 SetColor=function(self,r,g,b,a)self.color={r,g,b};self.alpha=a or 1 end,SetAlpha=function(self,v)self.alpha=v end}
end
local measure=label()
local entry={name='Relic',rewardName='Item',leadSource='Long source',antiquityQuality=4,rewardQuality=5,complete=false}
entry.layout=K.AntiquityBlockLayout(entry,measure,612)
assert(entry.layout.rewardY>entry.layout.titleHeight)
assert(entry.layout.sourceY>entry.layout.rewardY+entry.layout.rewardHeight)
assert(entry.layout.height>=entry.layout.sourceY+48+18,'source must fit with gap before next block')
local controls={Name=label(),Reward=label(),Source=label(),Checkbox=label()}
GetAntiquityQualityColor=function()return {UnpackRGB=function()return 0.7,0,1 end}end
GetItemQualityColor=function()return {UnpackRGB=function()return 1,0.8,0 end}end
local row={GetNamedChild=function(_,name)return controls[name]end}
K.SetupAntiquityBlock(row,entry,612)
assert(controls.Name.font=='ZoFontGameBold' and controls.Reward.font=='ZoFontGameSmall' and controls.Source.font=='ZoFontGameSmall')
assert(controls.Name.color[3]==1 and controls.Reward.color[1]==1 and controls.Reward.color[2]==0.8,'reward must use its own rarity')
assert(controls.Source.color[1]==0.65 and controls.Source.color[2]==0.65 and controls.Source.alpha==1)
assert(controls.Name.alpha==0.55 and controls.Reward.alpha==0.55,'unfinished entries remain dimmed')
entry={name='Done',complete=true,antiquityQuality=4}
entry.layout=K.AntiquityBlockLayout(entry,measure,612)
K.SetupAntiquityBlock(row,entry,612)
assert(controls.Reward.hidden and controls.Source.hidden and controls.Name.alpha==1 and controls.Checkbox.alpha==1)
assert(entry.layout.height==36,'completed relic should remain compact')
print('PASS antiquity design: separate typography/independent rarity/gray source/measured height/gaps/dimming/recycled compact row')
