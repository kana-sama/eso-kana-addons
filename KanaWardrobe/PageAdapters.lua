local KW=KanaWardrobe
local P={};KW.PageAdapters=P
local Pages={};Pages.__index=Pages
local definitions={
 inventory={root='ZO_Character',background='ZO_SharedWideLeftPanelBackground',side='right'},
 skills={root='ZO_Skills',background='ZO_SharedRightBackground',side='left',manager='SKILLS_WINDOW',group='keybindStripDescriptor',key='UI_SHORTCUT_SECONDARY',domain='skills'},
 stats={root='ZO_StatsPanel',background='ZO_SharedStatsBackground',side='left',manager='STATS',group='keybindButtons',key='UI_SHORTCUT_PRIMARY',domain='attributes'},
}
local function scale(c)return c.GetScale and c:GetScale()or 1 end
function P.New(api)return setmetatable({api=api or _G,widths={},textureWidths={},backgrounds={},underlays={},backgroundSlices={},removed={}},Pages)end
function Pages:Get(page)
 local d=definitions[page];if not d then return nil end
 local a=self.api;local root,background=a[d.root],a[d.background]
 local scene=a.SCENE_MANAGER and a.SCENE_MANAGER:GetScene(page)
 if not root or not background or not scene then return nil end
 return {scene=scene,root=root,background=background,side=d.side}
end
function Pages:Bounds(page)
 local p=self:Get(page);local a=self.api;if not p or not a.GuiRoot then return nil end
 local factor=scale(p.root);local gui=a.GuiRoot
 local sw,sh=gui:GetWidth()/factor,gui:GetHeight()/factor
 local left,top=(p.root:GetLeft()-gui:GetLeft())/factor,(p.root:GetTop()-gui:GetTop())/factor
 local height=p.root:GetHeight()/factor;local x,width
 if page=='inventory' then
  local stats=a.ZO_CharacterWindowStatsScroll;if not stats then return nil end
  -- LayoutContent supplies the same padding on both sides. An extra gap here
  -- doubled the visible left inset while the background ended at the right one.
  x=(stats:GetRight()-gui:GetLeft())/factor;width=300
  local heading=a.ZO_CharacterHeaderSectionTitle
  top=math.max(12,((heading and heading:GetTop()or p.root:GetTop()+26*factor)-gui:GetTop())/factor-10)
  height=math.min((stats:GetTop()+stats:GetHeight()-gui:GetTop())/factor,sh-64)-top
  x=math.max(12,math.min(x,sw-width-12))
 else
  if page=='stats' then
   local advanced=a.ZO_AdvancedStatsPanel
   if advanced and not advanced:IsHidden()then left=math.min(left,(advanced:GetLeft()-gui:GetLeft())/factor)end
  end
  width=math.min(300,left-28);if width<120 then return nil end
  x=left-width-16;top=math.max(12,top);height=math.min(height,sh-64-top)
 end
 local list={x=x,y=top,width=width,height=math.max(180,height),scale=factor}
 local desc
 if p.side=='left'then desc={x=12,y=top,width=math.max(0,x-24),height=list.height,scale=factor}
 else
  local edge=sw-12;local bag=a.ZO_PlayerInventory
  if bag and not bag:IsHidden()then
   edge=(bag:GetLeft()-gui:GetLeft())/factor
   local bg=a.ZO_SharedRightPanelBackground;local texture=bg and bg:GetNamedChild('Left')
   if texture then edge=math.min(edge,(texture:GetLeft()-gui:GetLeft())/factor)end
  end
  desc={x=x+width+12,y=top,width=math.max(0,edge-x-width-24),height=list.height,scale=factor}
 end
 return {list=list,description=desc}
end
-- Native Left textures include a transparent edge. Stretching their whole
-- image stretches that edge by different amounts (1024-wide main art vs the
-- 256-wide tree tint). Keep 64 units of edge and the native remainder at 1:1;
-- insert only a sampled flat column between them.
function Pages:ExpandSkillArt(art,physicalDelta)
 local texture=art.control
 local factor=scale(texture)
 if physicalDelta<=0 then self:RestoreArt(art);return end
 if art.physicalDelta==physicalDelta and art.factor==factor then return end
 art.physicalDelta=physicalDelta;art.factor=factor
 if not art.slices then
  local coords={texture:GetTextureCoords()}
  local _,point,relative,relativePoint,x,y,constrain=texture:GetAnchor(0)
  art.coords=coords;art.anchor={point=point,relative=relative,relativePoint=relativePoint,x=x,y=y,constrain=constrain}
  local slices=self.backgroundSlices[texture]
  if not slices then
   local wm=self.api.WINDOW_MANAGER;local parent=texture:GetParent()
   slices={}
   for _,key in ipairs({'edge','fill'})do
    local c=wm:CreateControl(texture:GetName()..'KanaWardrobeBackground'..key,parent,self.api.CT_TEXTURE)
    c:SetMouseEnabled(false);c:SetDrawLayer(texture:GetDrawLayer());c:SetDrawLevel(texture:GetDrawLevel())
    slices[key]=c
   end
   self.backgroundSlices[texture]=slices
  end
  art.slices=slices
 end
 local a,uv,slices=art.anchor,art.coords,art.slices
 local cut=64;local delta=physicalDelta/scale(texture)
 local u=uv[1]+(uv[2]-uv[1])*cut/art.width
 local parent=texture:GetParent();local relativeScale=scale(texture)/scale(parent)
 local height=texture:GetHeight()/scale(texture)
 for _,c in pairs(slices)do c:SetScale(relativeScale);c:ClearAnchors();c:SetHidden(delta<=0)end
 slices.edge:SetDimensions(cut,height)
 slices.edge:SetTexture(texture:GetTextureFileName());slices.edge:SetTextureCoords(uv[1],u,uv[3],uv[4])
 slices.edge:SetAnchor(a.point,a.relative,a.relativePoint,a.x,a.y,a.constrain)
 slices.fill:SetDimensions(math.max(0,delta),height)
 slices.fill:SetTexture(texture:GetTextureFileName())
 -- Sample the center of one native column so the inserted region has no
 -- horizontal gradient, while keeping the original vertical fade untouched.
 local sample=u+(uv[2]-uv[1])*.5/art.width
 slices.fill:SetTextureCoords(sample,sample,uv[3],uv[4])
 slices.fill:SetAnchor(self.api.TOPLEFT,slices.edge,self.api.TOPRIGHT,0,0)
 texture:ClearAnchors()
 texture:SetAnchor(a.point,a.relative,a.relativePoint,a.x+cut+delta,a.y,a.constrain)
 texture:SetWidth(art.width-cut);texture:SetTextureCoords(u,uv[2],uv[3],uv[4])
end
function Pages:RestoreArt(art)
 art.physicalDelta=nil;art.factor=nil
 art.control:SetWidth(art.width)
 if art.slices then
  local a=art.anchor
  art.control:ClearAnchors();art.control:SetAnchor(a.point,a.relative,a.relativePoint,a.x,a.y,a.constrain)
  local uv=art.coords;art.control:SetTextureCoords(uv[1],uv[2],uv[3],uv[4])
  for _,c in pairs(art.slices)do c:SetHidden(true)end
 end
end
function Pages:SetBackgroundExpanded(page,expanded)
 if not expanded then
  local bg=self.backgrounds[page]
  if bg and self.widths[bg]then bg:SetWidth(self.widths[bg]);self.widths[bg]=nil end
  local art=bg and self.textureWidths[bg]
  if art then self:RestoreArt(art);self.textureWidths[bg]=nil end
  local underlay=self.underlays[page]
  if underlay then
   underlay.owner:SetWidth(underlay.width);self:RestoreArt(underlay.art)
   self.underlays[page]=nil
  end
  self.backgrounds[page]=nil;return
 end
 local p=self:Get(page);if not p then return end
 local bg=p.background;local factor=scale(bg)
 if self.backgrounds[page]and self.backgrounds[page]~=bg then self:SetBackgroundExpanded(page,false)end
 local b=self:Bounds(page);if not b then return end
 self.backgrounds[page]=bg;self.widths[bg]=self.widths[bg]or bg:GetWidth()/factor
 local gui=self.api.GuiRoot;local list=b.list
 local edge=(p.side=='right' and list.x+list.width or list.x)*list.scale+gui:GetLeft()
 local width=p.side=='right' and (edge-bg:GetLeft())/factor or (bg:GetRight()-edge)/factor
 local target=math.max(self.widths[bg],width)
 -- Right/Stats backgrounds have fixed-width art anchored to their left edge.
 -- Widening only the RIGHT-anchored owner moves that art away from the native
 -- page. Skills preserves the native edge/remainder with slices; Stats keeps
 -- its existing width extension. Inventory uses other art.
 if p.side=='left'and not self.textureWidths[bg]then
  local ok,texture=pcall(bg.GetNamedChild,bg,page=='skills'and 'Left'or 'BG')
  if ok and texture then self.textureWidths[bg]={control=texture,width=texture:GetWidth()/scale(texture)}end
 end
 local art=self.textureWidths[bg]
 if math.abs(bg:GetWidth()/factor-target)>.01 then bg:SetWidth(target)end
 if art then
  if page=='skills'then self:ExpandSkillArt(art,(target-self.widths[bg])*factor)
  else
   local textureScale=scale(art.control)
   local artWidth=art.width+(target-self.widths[bg])*factor/textureScale
   if math.abs(art.control:GetWidth()/textureScale-artWidth)>.01 then art.control:SetWidth(artWidth)end
  end
 end
 -- Skills has a second native layer (TREE_UNDERLAY_FRAGMENT). Its Left art
 -- begins at the same edge as the main background. Extend both by the same
 -- physical delta, preserving each texture's fade rather than stretching it.
 if page=='skills'then
  local owner=self.api.ZO_SharedTreeUnderlay
  if owner and not self.underlays[page]then
   local ok,texture=pcall(owner.GetNamedChild,owner,'Left')
   if ok and texture then
    self.underlays[page]={owner=owner,width=owner:GetWidth()/scale(owner),
     art={control=texture,width=texture:GetWidth()/scale(texture)}}
   end
  end
  local underlay=self.underlays[page]
  if underlay then
   local delta=(target-self.widths[bg])*factor
   local ownerWidth=underlay.width+delta/scale(underlay.owner)
   if math.abs(underlay.owner:GetWidth()/scale(underlay.owner)-ownerWidth)>.01 then underlay.owner:SetWidth(ownerWidth)end
   self:ExpandSkillArt(underlay.art,delta)
  end
 end
end
function Pages:Mount(page,session)
 if not self:Get(page)then return nil,KW.Problem('buildCapabilityUnavailable')end
 if self.active and self.active~=page then self:Unmount(self.active)end
 self.active=page;self.session=session or self.session;self:RefreshOwnership();return true
end
function Pages:Unmount(page)
 if self.active~=page then return end
 self:SetBackgroundExpanded(page,false);self.active=nil;self:RefreshOwnership()
end
local function current(strip,key)
 local button=strip:GetButtonOrEtherealDescriptorForKeybind(key)
 if type(button)=='userdata'then return button.keybindButtonDescriptor end
 return button
end
function Pages:IsActive(page,p)
 local scene=p and p.scene
 if scene and type(scene.IsShowing)=='function'then return scene:IsShowing()end
 return self.active==page
end
local function topState(strip)
 return strip.GetTopKeybindStateIndex and strip:GetTopKeybindStateIndex()or nil
end
-- Inventory has no stock hide confirmation. Install only our callback in an
-- empty public scene slot; release only the exact callback we still own.
function Pages:RefreshEquipmentExit()
 local manager=self.api.SCENE_MANAGER
 local scene=manager and manager.GetScene and manager:GetScene('inventory')
 local view=self.session and self.session:GetView()
 local own=view and view.isEditor and view.page=='inventory' and view.component=='equipment' and view.state~='idle'
 local hook=self.equipmentExit
 if hook and (not own or hook.scene~=scene)then
  if hook.scene.hideSceneConfirmationCallback==hook.callback then hook.scene:SetHideSceneConfirmationCallback(nil)end
  self.equipmentExit=nil
 end
 if own and self.requestEquipmentExit and not self.equipmentExit and scene and scene.SetHideSceneConfirmationCallback and scene.HasHideSceneConfirmation and scene.AcceptHideScene and scene.RejectHideScene and not scene:HasHideSceneConfirmation()then
  hook={scene=scene}
  hook.callback=function(source)
   if self.equipmentExit~=hook or source~=scene or scene.hideSceneConfirmationCallback~=hook.callback then return end
   self.requestEquipmentExit(scene)
  end
  self.equipmentExit=hook;scene:SetHideSceneConfirmationCallback(hook.callback)
 end
end
function Pages:RefreshOwnership()
 self:RefreshEquipmentExit()
 local strip=self.api.KEYBIND_STRIP
 if not strip or not strip.GetButtonOrEtherealDescriptorForKeybind or not strip.HasKeybindButtonGroup then return end
 local function ownership()return self.session and self.session.GetNativeOwnership and self.session:GetNativeOwnership()or {}end
 for _,page in ipairs({'skills','stats'})do
  local d=definitions[page];local manager=self.api[d.manager];local group=manager and manager[d.group]
  local descriptor
  for _,entry in ipairs(group or {})do if entry.keybind==d.key then descriptor=entry;break end end
  local stateIndex=topState(strip)
  local function groupActive()return topState(strip)==stateIndex and strip:HasKeybindButtonGroup(group,stateIndex)end
  local p=self:Get(page);local active=p and self:IsActive(page,p)and group and groupActive()
  local own=ownership()[d.domain]
  if active and descriptor and own then
   if current(strip,d.key)==descriptor then
    local backlink=descriptor.keybindButtonGroupDescriptor
    strip:RemoveKeybindButton(descriptor,stateIndex)
    self.removed[page]={descriptor=descriptor,group=group,backlink=backlink}
   end
  end
  if active and descriptor and not ownership()[d.domain] then
   local removed=self.removed[page]
   if removed and removed.descriptor==descriptor and removed.group==group and removed.backlink==group and not current(strip,d.key)and groupActive()and not ownership()[d.domain]then
    -- Public individual Add clears the native group backlink. Restore only that
    -- exact saved association in this guarded synchronous stack, then Update.
    strip:AddKeybindButton(descriptor,stateIndex)
    if current(strip,d.key)==descriptor and groupActive()and not ownership()[d.domain]then
     descriptor.keybindButtonGroupDescriptor=removed.backlink
     strip:UpdateKeybindButton(descriptor,stateIndex)
     if topState(strip)==stateIndex and current(strip,d.key)==descriptor then
      if ownership()[d.domain]or not groupActive()then strip:RemoveKeybindButton(descriptor,stateIndex)else self.removed[page]=nil end
     end
    elseif topState(strip)==stateIndex and current(strip,d.key)==descriptor then strip:RemoveKeybindButton(descriptor,stateIndex)end
   elseif current(strip,d.key)==descriptor then self.removed[page]=nil end
  end
 end
end

local function visible(control)
 if not control then return false end
 if control.IsControlHidden then return not control:IsControlHidden()end
 return not control:IsHidden()
end
local function icon(control)return control and (control.icon or control:GetNamedChild('Icon'))end
local function skillSelection(api,row)
 if not visible(row) or not row.dataEntry or row.dataEntry.typeId~=1 then return nil end
 local data=api.ZO_ScrollList_GetData and api.ZO_ScrollList_GetData(row)
 local skill=data and data.skillData
 if not skill or not KW.SkillState then return nil end
 local key=KW.SkillState.Key(skill);local line=skill:GetSkillLineData()
 local eligible=not skill:IsCraftedAbility() and line:IsAvailable()
 if eligible and skill:IsAutoGrant()then
  eligible=skill:IsPassive() and skill:GetNumRanks()>1
   or not skill:IsPassive() and skill:CanPointAllocationsBeAltered(api.SKILL_POINT_ALLOCATION_MODE_FULL)
 end
 return {domain='skills',key=key,eligible=eligible==true,visible=true}
end
local function barSelection(api,object)
 -- Empty native slots hide their icon texture; the button remains selectable.
 if not visible(object.button) or not object.icon then return nil end
 local manager=api.ACTION_BAR_ASSIGNMENT_MANAGER
 if not manager or not manager.GetCurrentHotbarCategory or not manager.GetHotbar then return nil end
 local category=manager:GetCurrentHotbarCategory();local bar
 if category~=nil and category==api.HOTBAR_CATEGORY_PRIMARY then bar='front'
 elseif category~=nil and category==api.HOTBAR_CATEGORY_BACKUP then bar='back'
 elseif category~=nil and category==api.HOTBAR_CATEGORY_WEREWOLF then bar='werewolf'end
 if not bar then return nil end
 local first=api.ACTION_BAR_FIRST_NORMAL_SLOT_INDEX
 local slot=first and type(object.slotId)=='number' and object.slotId-first
 if not slot or slot%1~=0 or slot<1 or slot>6 then return nil end
 local hotbar=manager:GetHotbar(category)
 if not hotbar or not hotbar.IsSlotLocked or not hotbar.IsSlotMutable or not hotbar.GetOverrideSkillDataForSlot then return nil end
 local eligible=not hotbar:IsSlotLocked(object.slotId) and hotbar:IsSlotMutable(object.slotId)
  and not hotbar:GetOverrideSkillDataForSlot(object.slotId)
 return {domain='bars',key={bar=bar,slot=slot},eligible=eligible==true,visible=true}
end
-- Enumerate only ready native controls currently on screen. No catalogue or
-- inventory scan, native setup callback replacement, or forced page init.
function Pages:GetSelectionIcons(page)
 local a=self.api;local result={}
 if page=='inventory'then
  local names={'Head','Shoulder','Chest','Glove','Belt','Leg','Foot','Neck','Ring1','Ring2','MainHand','OffHand','BackupMain','BackupOff'}
  for index,slot in ipairs(KW.Slots.Order)do
   local native=a['ZO_CharacterEquipmentSlots'..names[index]];local texture=icon(native)
   if native and texture then
    result[#result+1]={parent=native,icon=texture,resolveKey=function()
     if not visible(native)then return nil end
     return {domain='equipment',key=slot,eligible=true,visible=true}
    end}
   end
  end
 elseif page=='skills'then
  local manager=a.SKILLS_WINDOW;local list=manager and manager.skillList
  for _,row in ipairs(list and list.activeControls or {})do
   if row.dataEntry and row.dataEntry.typeId==1 then
    local slot=row:GetNamedChild('Slot');local texture=icon(slot)
    if slot and texture then result[#result+1]={parent=slot,icon=texture,resolveKey=function()return skillSelection(a,row)end}end
   end
  end
  for _,object in ipairs(manager and manager.assignableActionBar and manager.assignableActionBar.buttons or {})do
   if object.button and object.icon then
    result[#result+1]={parent=object.button,icon=object.icon,resolveKey=function()return barSelection(a,object)end}
   end
  end
 end
 return result
end
