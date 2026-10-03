-- Tests renderer output at the ESO control boundary (no game runtime required).
CombatMetronome = {}
KanaCooldownMetronome = CombatMetronome
CENTER, TOPLEFT, TOP, BOTTOM = 1, 2, 3, 4
CT_CONTROL, CT_POLYGON, CT_BACKDROP = 5, 6, 9
DL_OVERLAY, POLYGON_POINT_LAYOUT_CLOCKWISE = 7, 8
local Control = {}
Control.__index = Control
function Control:SetHidden(v) self.hidden = v end
function Control:IsHidden() return self.hidden end
function Control:SetDimensions(w,h) self.w,self.h = w,h end
function Control:SetAnchor(...) self.anchor = {...} end
function Control:ClearAnchors() self.anchor = nil end
function Control:SetMouseEnabled(v) end
function Control:GetName() return self.name end
function Control:SetClampedToScreen(v) self.clamped=v end
function Control:SetDrawLayer(v) end
function Control:SetDrawLevel(v) end
function Control:SetPointLayout(v) end
function Control:SetSmoothingEnabled(v) end
function Control:SetBorderThickness(a,b,c) end
function Control:SetBorderColor(...) end
function Control:SetEdgeColor(...) end
function Control:SetEdgeTexture(...) end
function Control:SetCenterColor(...) self.color = {...} end
function Control:AddPoint(x,y) self.points[#self.points+1] = {x,y} end
function Control:SetPoint(i,x,y) assert(self.points[i]); self.points[i] = {x,y} end
function Control:GetWidth() return self.w end
function Control:GetHeight() return self.h end
WINDOW_MANAGER = {controls={}}
function WINDOW_MANAGER:CreateControl(name,parent,kind)
    local c = setmetatable({name=name,points={},parent=parent,kind=kind}, Control)
    self.controls[#self.controls+1]=c
    return c
end
local function control() return WINDOW_MANAGER:CreateControl(nil,nil,CT_CONTROL) end
GuiRoot = control(); GuiRoot:SetDimensions(1920,1080)
local loaded = loadfile((arg and arg[1] or '.')..'/Radial.lua')
if loaded then loaded() end
assert(CombatMetronome.AttachRadialBar, 'radial renderer is missing')
local cm = CombatMetronome
cm.name='TestCM'
cm.DEFAULT_SAVED_VARS={Progressbar={radialCooldown=false,radialCenterX=960,radialCenterY=540,radialOuterRadius=60,radialInnerRadius=45}}
cm.SV={Progressbar={radialCooldown=true,radialCenterX=960,radialCenterY=540,radialOuterRadius=60,radialInnerRadius=45,backgroundColor={0,0,0,0.5}}}
local bar={background=control(),backgroundTexture=control(),borderL=control(),borderR=control(),segments={{progress=.1,color={1,0,0,1}},{progress=.5,color={1,1,0,1}}}}
function bar:Update() self.linearUpdated=true end
function bar:SetHidden(v) self.background:SetHidden(v) end
cm.Progressbar={bar=bar,frame=control()}
cm:AttachRadialBar()
bar:SetHidden(false); bar:Update()
assert(bar.background.hidden, 'linear background must be hidden in radial mode')
local function area(r,g,b)
    local total = 0
    for _, c in ipairs(cm.Progressbar.radial.rectangles) do
        if not c.hidden and c.color[1]==r and c.color[2]==g and c.color[3]==b then
            total=total+c.w*c.h
        end
    end
    return total
end
local totalArea=math.pi*(60*60-45*45)
assert(math.abs(area(1,0,0)/totalArea-.1)<.002, 'wrong ping area')
assert(math.abs(area(1,1,0)/totalArea-.4)<.002, 'wrong main area')
assert(math.abs(area(0,0,0)/totalArea-.5)<.002, 'wrong background area')
-- A ring must stay complete throughout the countdown, including all quadrants.
for step=0,40 do
    bar.segments[2].progress=step/40
    bar:Update()
    for degree=0,359 do
        local angle=(degree+.123)*math.pi/180
        local x,y=52.5*math.sin(angle),-52.5*math.cos(angle)
        local hits=0
        for _,c in ipairs(cm.Progressbar.radial.rectangles) do
            if not c.hidden and math.abs(x-c.anchor[4])<c.w/2 and math.abs(y-c.anchor[5])<c.h/2 then hits=hits+1 end
        end
        assert(hits==1, 'ring missing or overlapping at '..degree..' degrees, progress '..step/40)
    end
end
bar.segments[2].progress=.02; bar:Update()
assert(math.abs(area(1,0,0)/totalArea-.02)<.002,'ping must clip to remaining progress')
assert(area(1,1,0)==0,'main fill must disappear inside ping zone')
bar.segments[2].progress=-.1; bar:Update()
assert(area(1,0,0)==0 and area(1,1,0)==0,'expired cooldown must have no fill')
bar.segments[2].progress=2; bar.segments[1].progress=0; bar:Update()
assert(math.abs(area(1,1,0)/totalArea-1)<.002,'full cooldown must fill 360 degrees')
cm.SV.Progressbar.backgroundColor={.2,.4,.6,.5}
bar.segments[1].color={1,0,0,.5}; bar.segments[1].progress=1
bar:Update()
local color=cm.Progressbar.radial.rectangles[1].color
assert(math.abs(color[1]-.7333333333333333)<1e-7)
assert(math.abs(color[2]-.1333333333333333)<1e-7)
assert(math.abs(color[3]-.2)<1e-7 and math.abs(color[4]-.75)<1e-7)
cm.SV.Progressbar.backgroundColor={0,0,0,0}; bar.segments[1].color={1,0,0,0}; bar:Update()
for _,v in ipairs(cm.Progressbar.radial.rectangles[1].color) do assert(v==0) end
cm.SV.Progressbar.backgroundColor={0,0,0,.5}; bar.segments[1].color={1,0,0,1}; bar.segments[1].progress=.1
for cycle=1,2 do
    local count=#WINDOW_MANAGER.controls
    for i=0,100 do bar.segments[2].progress=i/100; bar:Update() end
    if cycle==2 then assert(#WINDOW_MANAGER.controls==count,'controls must be reused') end
end
assert(#cm.Progressbar.radial.rectangles<=240*5,'unbounded control count')
bar:SetHidden(true); assert(cm.Progressbar.radial.root.hidden)
cm.SV.Progressbar.radialCooldown=false; bar:SetHidden(false); bar:Update()
assert(not bar.background.hidden and bar.linearUpdated)
assert(cm.Progressbar.radial.root.hidden)
print('PASS backdrop ring: 360-degree coverage at 41 progress values, ping, colors, expiry, reuse, linear fallback')
cm.Progressbar.timeLabel=control()
cm.Progressbar.spellLabel=control()
cm.Progressbar.spellIcon=control()
function Control:SetDimensionConstraints(...) self.constraints={...} end
cm.Progressbar.UI={
    Size=function() cm:RadialLayout() end,
    Position=function(value) cm.positionMode=value end,
}
function cm:HideFancy(value) self.fancyHidden=value or self.SV.Progressbar.radialCooldown end
local options=cm:RadialOptions().controls
options[1].setFunc(true)
assert(cm.Progressbar.frame.w==120 and cm.Progressbar.frame.h==120,'ring needs a square frame')
assert(cm.Progressbar.timeLabel.anchor[1]==CENTER,'timer should be inside the ring')
options[2].setFunc(123); options[4].setFunc(456)
assert(cm.SV.Progressbar.radialCenterX==123 and cm.SV.Progressbar.radialCenterY==456)
options[3].func()
assert(cm.SV.Progressbar.radialCenterX==960 and cm.SV.Progressbar.radialCenterY==456,'horizontal centering must only change X')
options[5].func()
assert(cm.SV.Progressbar.radialCenterY==540,'vertical centering must use screen height')
options[6].setFunc(20)
assert(cm.SV.Progressbar.radialInnerRadius==19,'shrinking outer radius must constrain inner radius')
options[7].setFunc(100)
assert(cm.SV.Progressbar.radialInnerRadius==19,'inner radius must stay below outer')
options[7].setFunc(0)
assert(cm.SV.Progressbar.radialInnerRadius==0,'zero inner radius should allow a filled disc')
cm.Progressbar.showSample=true
options[2].setFunc(100)
assert(cm.positionMode=='Sample','settings changes must keep preview active')
options[1].setFunc(false)
assert(options[2].disabled(),'radial geometry settings should disable in linear mode')
assert(cm.Progressbar.frame.constraints[4]==100,'linear height constraint must be restored')
print('PASS settings: live layout, center buttons, radius bounds, preview, mode switch')
