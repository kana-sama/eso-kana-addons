local KW=KanaWardrobe
local O={};KW.SelectionOverlay=O
local Overlay={};Overlay.__index=Overlay
local serial=0
-- ESO retains created controls. Retired own controls are reused per native
-- parent, so scroll/editor cycles allocate only a bounded number of children.
local free={}
function O.New(parent,resolveKey,onToggle)
 local bucket=free[parent];local c=bucket and table.remove(bucket)
 if not c then
  serial=serial+1
  local name='KanaWardrobeSelection'..serial
  c=WINDOW_MANAGER:CreateControlFromVirtual(name,parent,'ZO_CheckButton')
  c:SetDimensions(18,18);c:SetDrawLayer(DL_OVERLAY)
  local background=WINDOW_MANAGER:CreateControl(name..'Background',c,CT_BACKDROP)
  background:SetAnchor(TOPLEFT,c,TOPLEFT,0,0);background:SetAnchor(BOTTOMRIGHT,c,BOTTOMRIGHT,0,0)
  background:SetDrawLayer(DL_CONTROLS);background:SetMouseEnabled(false)
  background:SetCenterColor(.015,.015,.02,1);background:SetEdgeTexture(nil,1,1,0,0);background:SetEdgeColor(0,0,0,0)
  c.background=background
 end
 c:SetHidden(true);c:SetMouseEnabled(true)
 local self=setmetatable({control=c,parent=parent,resolveKey=resolveKey,onToggle=onToggle,enabled=false},Overlay)
 -- Only our checkbox receives this handler. The native slot's handlers remain
 -- untouched, and each click resolves current pooled data and selection again.
 c:SetHandler('OnClicked',function(_,button)
  if self.destroyed or button~=(MOUSE_BUTTON_INDEX_LEFT or 1)then return end
  local data=self:Refresh()
  if not data or not self.enabled then return end
  local selected=not(data.selected==true)
  self.onToggle(data.domain,data.key,selected,c)
 end)
 return self
end
function Overlay:Bind(icon,resolveKey)
 if self.destroyed then return end
 self.icon=icon;if resolveKey then self.resolveKey=resolveKey end
 self.control:ClearAnchors();self.control:SetAnchor(TOPRIGHT,icon,TOPRIGHT,-1,1)
end
function Overlay:SetSelected(value)
 ZO_CheckButton_SetCheckState(self.control,value==true)
end
function Overlay:SetEnabled(value)
 self.enabled=value==true
 ZO_CheckButton_SetEnableState(self.control,self.enabled)
end
function Overlay:SetSkillStyle(value)
 if self.skillStyle==value then return end
 self.skillStyle=value
 local c=self.control;local size=value and 24 or 18
 c:SetDimensions(size,size)
 local texture=value and 'EsoUI/Art/Buttons/checkbox_white_'or 'EsoUI/Art/Buttons/checkbox_'
 c:SetNormalTexture(texture..'unchecked.dds');c:SetPressedTexture(texture..'checked.dds')
 -- Keep the opaque backing above native skill art, but below the checkmark.
 c:SetDrawLevel(value and 2 or 0)
 c.background:SetDrawLayer(value and DL_OVERLAY or DL_CONTROLS)
 c.background:SetDrawLevel(value and 1 or 0)
end
function Overlay:Refresh()
 if self.destroyed then return nil end
 local data=self.resolveKey and self.resolveKey()
 local visible=data and data.visible~=false and self.icon~=nil
 self:SetSkillStyle(data~=nil and (data.domain=='skills'or data.domain=='bars'))
 self.control:SetHidden(not visible)
 self:SetSelected(visible and data.eligible~=false and data.selected==true)
 self:SetEnabled(visible and data.eligible~=false and data.enabled~=false)
 return visible and data or nil
end
function Overlay:Destroy()
 if self.destroyed then return end
 self.destroyed=true;self.control:SetHidden(true);self:SetSelected(false);self:SetEnabled(false);self.control:SetMouseEnabled(false)
 for _,name in ipairs({'OnClicked','OnMouseEnter','OnMouseExit'})do self.control:SetHandler(name,nil)end
 self.control:ClearAnchors()
 local bucket=free[self.parent]or {};free[self.parent]=bucket;bucket[#bucket+1]=self.control
 self.resolveKey=nil;self.onToggle=nil;self.icon=nil;self.parent=nil
end
