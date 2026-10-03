-- Minimal ESO boundary simulation. This tests our state transitions, not rendering.
local H={events={},updates={},mouseX=0,mouseY=0,time=0,scene='hudui'}
local C={}; C.__index=C
local factors={TOPLEFT={0,0},TOP={.5,0},TOPRIGHT={1,0},LEFT={0,.5},CENTER={.5,.5},RIGHT={1,.5},BOTTOMLEFT={0,1},BOTTOM={.5,1},BOTTOMRIGHT={1,1}}
for name in pairs(factors) do _G[name]=name end
for _,name in ipairs({'CT_CONTROL','CT_LABEL','CT_TEXTURE','CT_BACKDROP','DT_MEDIUM','DT_HIGH','DL_BACKGROUND','DL_CONTROLS','DL_OVERLAY',
    'SCENE_SHOWN','SCENE_HIDING','SCENE_HIDDEN','SCENE_FRAGMENT_HIDING','SCENE_FRAGMENT_HIDDEN','KEYBIND_STRIP_ALIGN_RIGHT',
    'EVENT_ADD_ON_LOADED','EVENT_PLAYER_ACTIVATED','EVENT_SCREEN_RESIZED','EVENT_INVENTORY_SINGLE_SLOT_UPDATE',
    'EVENT_INVENTORY_FULL_UPDATE','EVENT_INVENTORY_BAG_CAPACITY_CHANGED','EVENT_PLAYER_COMBAT_STATE','REGISTER_FILTER_BAG_ID'}) do _G[name]=name end
MOUSE_BUTTON_INDEX_LEFT=1;MOUSE_BUTTON_INDEX_RIGHT=2;BAG_BACKPACK=1;BAG_WORN=2;ITEMTYPE_TREASURE=7
function H.control(parent) return setmetatable({parent=parent,width=0,height=0,scale=1,handlers={}},C) end
function C:SetDimensions(w,h) self.width,self.height=w,h end
function C:SetAnchor(p,r,rp,x,y) self.anchor={p,r,rp,x or 0,y or 0} end
function C:ClearAnchors() self.anchor=nil end
function C:SetAnchorFill(parent) self.fill=parent end
function C:GetWidth() return self.fill and self.fill:GetWidth() or self.width end
function C:GetHeight() return self.fill and self.fill:GetHeight() or self.height end
function C:EffectiveScale() return self.scale*(self.parent and self.parent:EffectiveScale() or 1) end
function C:GetLeft()
    if not self.anchor then return self.parent and self.parent:GetLeft() or 0 end
    local p,r,rp,x=table.unpack(self.anchor)
    local parentScale=self.parent and self.parent:EffectiveScale() or 1
    return r:GetLeft()+r:GetWidth()*r:EffectiveScale()*factors[rp][1]+x*parentScale-self:GetWidth()*self:EffectiveScale()*factors[p][1]
end
function C:GetTop()
    if not self.anchor then return self.parent and self.parent:GetTop() or 0 end
    local p,r,rp,_,y=table.unpack(self.anchor)
    local parentScale=self.parent and self.parent:EffectiveScale() or 1
    return r:GetTop()+r:GetHeight()*r:EffectiveScale()*factors[rp][2]+y*parentScale-self:GetHeight()*self:EffectiveScale()*factors[p][2]
end
function C:SetScale(s) self.scale=s end
function C:SetText(t) self.text=t end
function C:GetText() return self.text end
function C:SetFont(f) self.font=f end
function C:GetTextWidth() return (utf8.len(self.text or '') or 0)*9 end
function C:SetHidden(v) self.hidden=v end
function C:IsHidden() return self.hidden==true end
function C:SetHandler(k,v) self.handlers[k]=v end
function C:SetColor(...) self.color={...} end
for _,method in ipairs({'SetMouseEnabled','SetCenterColor','SetEdgeColor','SetEdgeTexture','SetDrawLayer','SetDrawLevel',
    'SetTexture','SetDesaturation','SetAlpha','SetClampedToScreen','SetDrawTier','AddLine'}) do C[method]=function() end end
GuiRoot=H.control();GuiRoot:SetDimensions(1920,1080)
WINDOW_MANAGER={CreateControl=function(_,_,parent) return H.control(parent) end,
    CreateTopLevelWindow=function() return H.control(GuiRoot) end,
    CreateControlFromVirtual=function(_,_,parent) return H.control(parent) end}
EVENT_MANAGER={RegisterForEvent=function(_,namespace,event,fn) H.events[namespace..event]=fn end,
    UnregisterForEvent=function() end,RegisterForUpdate=function(_,id,_,fn) H.updates[id]=fn end,
    UnregisterForUpdate=function(_,id) H.updates[id]=nil end,AddFilterForEvent=function() end}
local scenes={}
SCENE_MANAGER={IsShowing=function(_,name) return H.scene==name end,SetInUIMode=function() end,
    GetScene=function(_,name)
        scenes[name]=scenes[name] or {RegisterCallback=function(self,_,cb) self.callback=cb end}
        return scenes[name]
    end,
    CallWhen=function(_,name,_,fn) H.pendingScene,H.pendingCallback=name,fn end,
    Show=function(_,name)
        H.scene=name
        if H.pendingScene==name then local fn=H.pendingCallback;H.pendingCallback=nil;fn() end
    end}
HUD_SCENE={AddFragment=function() end};HUD_UI_SCENE=HUD_SCENE
ZO_SimpleSceneFragment={New=function() return {RegisterCallback=function(self,_,fn) self.callback=fn end} end}
-- Native ZO_SavedVars returns an interface; settings live behind __index.
-- pairs(interface) does not enumerate settings in ESO's Lua runtime.
ZO_SavedVars={NewAccountWide=function(_,_,_,_,defaults)
    return setmetatable({}, {__index=defaults,__newindex=function(_,key,value) defaults[key]=value end})
end}
KEYBIND_STRIP={AddKeybindButtonGroup=function() end,RemoveKeybindButtonGroup=function() end}
LibAddonMenu2={RegisterAddonPanel=function() return H.control() end,RegisterOptionControls=function() end,OpenToPanel=function() end}
SLASH_COMMANDS={};InformationTooltip=H.control()
function InitializeTooltip() end
function ClearTooltip() end
function ClearMenu() end
function AddMenuItem() end
function ShowMenu() end
function GetFrameTimeSeconds() return H.time end
function GetUIMousePosition() return H.mouseX,H.mouseY end
function GetLatency() return 110 end
function GetFramerate() return 64 end
function GetBagSize() return 0 end
function GetBagUseableSize() return 100 end
function GetNumBagUsedSlots() return 50 end
function GetFenceSellTransactionInfo() return 100,0,3600 end
function DoesItemHaveDurability() return false end
function GetItemCondition() return 100 end
function GetItemRepairCost() return 0 end
function IsUnitInCombat() return false end
function IsUnitGrouped() return false end
function ZO_PreHook(name,fn) H.prehook=fn end
function ZO_PostHook() end
function H.load()
    for _,file in ipairs({'Logic','Core','Providers','Inventory','Panel','Editor','Settings'}) do dofile('KanaInfoBar/'..file..'.lua') end
    KanaInfoBar:Initialize()
    return KanaInfoBar
end
return H
