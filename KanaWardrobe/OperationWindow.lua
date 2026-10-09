local KW=KanaWardrobe
local unpack=unpack or table.unpack
local W={};KW.OperationWindow=W
local I={};I.__index=I
local function text(key)return KW.Text('OP_'..key)end
local function plain(v)return tostring(v or ''):gsub('|','/')end
local function at(c,parent,x,y,w,h)
 c:ClearAnchors();c:SetAnchor(TOPLEFT,parent,TOPLEFT,x,y);c:SetDimensions(w,h or 0)
end
local function readable(value,depth)
 if type(value)~='table'then return plain(value)end
 depth=depth or 0;if depth>2 then return '…'end
 if value.kind=='item'then return plain(value.link~='' and value.link or value.uid)end
 if value.kind=='empty'then return text('EMPTY')end
 if value.health~=nil then return tostring(value.health)..' / '..tostring(value.magicka)..' / '..tostring(value.stamina)end
 local keys={};for k in pairs(value)do keys[#keys+1]=k end;table.sort(keys,function(a,b)return tostring(a)<tostring(b)end)
 local out={};for _,k in ipairs(keys)do out[#out+1]=plain(k)..'='..readable(value[k],depth+1)end
 return table.concat(out,', ')
end
function W.StepTitle(step)
 local title=text(step.kind)
 if step.kind=='appearance'then title=title..' · '..plain(step.details and step.details.categoryName)end
 if step.kind=='equipBatch'then title=title..' · '..tostring(#(step.details and step.details.items or {}))end
 if step.kind=='bar'then title=title..' · '..text(step.details and step.details.bar or 'front')end
 if (step.kind=='equip' or step.kind=='unequip')and step.details then
  local d=step.details;local name=d.link
  if name and name~='' and GetItemLinkName then name=GetItemLinkName(name)end
  title=title..' · '..(name and name~='' and plain(name)or KW.Dialogs.SlotName(d.slot))
 end
 return title
end
function W.StepBody(step)
 local lines={};local d=step.details or {}
 if step.kind=='equipBatch'then
  for _,item in ipairs(d.items or {})do
   local name=item.link
   if name and name~='' and GetItemLinkName then name=GetItemLinkName(name)end
   local slots=KW.Dialogs.SlotName(item.slot)
   if item.sourceSlot~=nil then slots=KW.Dialogs.SlotName(item.sourceSlot)..' → '..slots end
   lines[#lines+1]=text(item.kind or 'equip')..' · '..slots..' — '..plain(name or '')
  end
 elseif step.kind=='equip' or step.kind=='unequip'then lines[#lines+1]=KW.Dialogs.SlotName(d.slot)
 elseif step.kind=='appearance'then lines[#lines+1]=plain(d.beforeName)..'  →  '..plain(d.targetName)
 elseif step.kind=='attributes'then lines[#lines+1]=readable(d.before)..'  →  '..readable(d.target)
 elseif d.changes then
  for i,change in ipairs(d.changes)do
   if i>8 then lines[#lines+1]=string.format(text('MORE'),#d.changes-8);break end
   local before,target=change.before or {},change.target or {}
   local beforeName=plain(change.beforeName or change.name or text('SKILL'))
   local targetName=plain(change.targetName or change.name or text('SKILL'))
   if step.kind=='bar'then
    lines[#lines+1]=string.format(text(target.kind=='empty' and 'BAR_EMPTY' or 'BAR_SKILL'),change.slot,targetName)
   elseif target.kind=='passive'then
    lines[#lines+1]=string.format(text('SKILL_RANK'),targetName,before.rank or 0,target.rank or 0)
   elseif target.purchased==false then lines[#lines+1]=string.format(text('SKILL_REMOVE'),beforeName)
   elseif before.purchased==false then lines[#lines+1]=string.format(text('SKILL_LEARN'),targetName)
   elseif change.beforeName and change.targetName and change.beforeName~=change.targetName then
    lines[#lines+1]=string.format(text('SKILL_MORPH'),beforeName,targetName)
   else lines[#lines+1]=string.format(text('SKILL_MORPH_UNKNOWN'),beforeName)end
  end
 end
 for _,notice in ipairs(d.notices or {})do
  local bar=notice.bar=='werewolf' and 'WEREWOLF' or notice.bar=='front' and 'FRONT' or 'BACK'
  local beforeName=plain(notice.beforeName or notice.name or text('SKILL'))
  if notice.reason=='skillMoved'then
   lines[#lines+1]=string.format(text('MOVE_'..bar),beforeName,notice.targetSlot)
  elseif notice.reason=='skillSold'then
   lines[#lines+1]=string.format(text('REMOVE_'..bar),beforeName)
  elseif notice.beforeName and notice.targetName and notice.beforeName~=notice.targetName then
   lines[#lines+1]=string.format(text('MORPH_'..bar),beforeName,plain(notice.targetName))
  else lines[#lines+1]=string.format(text('MORPH_UNKNOWN_'..bar),beforeName)end
 end
 if step.status=='running' and step.pending and step.pending.phase=='cooldown' then
  local seconds=math.ceil((step.pending.remainingMs or 0)/1000)
  local key=step.pending.countdownKind=='retry' and 'APPEARANCE_RETRY' or 'APPEARANCE_COOLDOWN'
  lines[#lines+1]=seconds>0 and string.format(text(key),seconds) or text('APPEARANCE_COOLDOWN_UNKNOWN')
 end
 local p=step.problem
 if p then
  lines[#lines+1]='|cE89682'..KW.Dialogs.Problem(p)..'|r'
  if p.code=='operationConsent' and p.details and p.details.extras then
   lines[#lines+1]=KW.Dialogs.ExtrasText({extras=p.details.extras})
  end
 end
 if step.attempt and step.attempt>1 then lines[#lines+1]=string.format(text('ATTEMPT'),step.attempt)end
 return table.concat(lines,'\n')
end
function W.New(executor,api)
 local self=setmetatable({executor=executor,api=api or _G,rows={}},I)
 self:Build();self:Refresh(executor:GetView());return self
end
function I:Label(parent,value,font)
 local c=self.api.WINDOW_MANAGER:CreateControl(nil,parent,CT_LABEL)
 c:SetFont(font or 'ZoFontGame');c:SetText(value or '');c:SetMouseEnabled(false);return c
end
function I:Button(name,value,fn)
 local b=self.api.WINDOW_MANAGER:CreateControlFromVirtual(name,self.root,'ZO_DefaultButton')
 b:SetText(value);b:SetFont('ZoFontGame');b:SetHandler('OnClicked',fn);return b
end
function I:Build()
 local api=self.api;local wm=api.WINDOW_MANAGER
 local root=wm:CreateTopLevelWindow('KanaWardrobeOperation');self.root=root
 root:SetHidden(true);root:SetMouseEnabled(true);root:SetClampedToScreen(true)
 if root.SetMovable then root:SetMovable(true)end
 -- Native keyboard dialogs use MEDIUM / STANDARD_DIALOG. Keep both respec
 -- progress dialogs (and their cancel buttons) above this non-modal window.
 root:SetDrawTier(DT_MEDIUM)
 root:SetDrawLevel(ZO_MEDIUM_TIER_KEYBOARD_STANDARD_DIALOG-1)
 root:SetAnchor(CENTER,api.GuiRoot,CENTER,0,0)
 self.bg=wm:CreateControl(nil,root,CT_BACKDROP);self.bg:SetAnchorFill(root)
 self.bg:SetCenterColor(.025,.032,.034,.96);self.bg:SetEdgeColor(.4,.38,.28,.85)
 self.bg:SetEdgeTexture('EsoUI/Art/Tooltips/UI-Border.dds',128,16)
 self.title=self:Label(root,'','ZoFontHeader3');self.title:SetMaxLineCount(1);self.title:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
 self.subtitle=self:Label(root,'','ZoFontGameSmall');self.subtitle:SetColor(.75,.73,.63,1)
 self.close=wm:CreateControlFromVirtual('KanaWardrobeOperationClose',root,'ZO_CloseButton')
 self.close:SetHandler('OnClicked',function()self.executor:SetVisible(false)end)
 self.line=wm:CreateControl(nil,root,CT_TEXTURE);self.line:SetColor(.48,.45,.31,.6)
 self.scroll=wm:CreateControlFromVirtual('KanaWardrobeOperationScroll',root,'ZO_ScrollContainer')
 self.child=self.scroll:GetNamedChild('Scroll'):GetNamedChild('Child');self.child:SetResizeToFitDescendents(false)
 api.ZO_Scroll_SetOnInteractWithScrollbarCallback(self.scroll,function()self.followActive=false end)
 self.pause=self:Button('KanaWardrobeOperationPause',text('PAUSE'),function()self.executor:Pause()end)
 self.resume=self:Button('KanaWardrobeOperationContinue',text('CONTINUE'),function()self.executor:Continue()end)
 self.restart=self:Button('KanaWardrobeOperationRestart',text('RESTART'),function()self.executor:Restart()end)
 self.report=self:Button('KanaWardrobeOperationReport',text('REPORT'),function()KW.OperationJournal.ShowReport(self.executor.saved)end)
 self.hint=self:Label(root,text('HINT'),'ZoFontGameSmall');self.hint:SetColor(.7,.69,.62,1)
 self.measure=self:Label(root,'','ZoFontGame');self.measure:SetHidden(true)
end
function I:Row(index)
 local row=self.rows[index]
 if not row then
  row=self.api.WINDOW_MANAGER:CreateControl('KanaWardrobeOperationRow'..index,self.child,CT_CONTROL)
  row.highlight=self.api.WINDOW_MANAGER:CreateControl(nil,row,CT_TEXTURE);row.highlight:SetAnchorFill(row);row.highlight:SetColor(.24,.42,.46,.18);row.highlight:SetDrawLayer(DL_BACKGROUND)
  row.mark=self:Label(row,'','ZoFontGameBold');row.title=self:Label(row,'','ZoFontGameBold');row.body=self:Label(row,'','ZoFontGameSmall')
  row.mark:SetHorizontalAlignment(TEXT_ALIGN_CENTER);row.mark:SetVerticalAlignment(TEXT_ALIGN_CENTER)
  row.doneIcon=self.api.WINDOW_MANAGER:CreateControl(nil,row,CT_TEXTURE)
  row.doneIcon:SetTexture('EsoUI/Art/Miscellaneous/check_icon_32.dds');row.doneIcon:SetMouseEnabled(false)
  row.rule=self.api.WINDOW_MANAGER:CreateControl(nil,row,CT_TEXTURE);row.rule:SetColor(.5,.48,.35,.16)
  self.rows[index]=row
 end
 return row
end
function I:Refresh(view)
 for _,row in ipairs(self.rows)do row:SetHidden(true)end
 self.root:SetHidden(not view or not view.visible)
 if not view then self.viewId=nil;self.followGeometry=nil;return end
 if self.viewId~=view.id or self.followActive==nil then
  self.viewId=view.id;self.followActive=true;self.followGeometry=nil
 end
 local activeStep=view.steps[view.index]
 self.resume:SetText(activeStep and activeStep.problem and activeStep.problem.code=='operationConsent' and text('CONFIRM')or text('CONTINUE'))
 local factor=self.root:GetScale();local width=math.min(640,self.api.GuiRoot:GetWidth()/factor-40)
 local maxHeight=math.min(720,self.api.GuiRoot:GetHeight()/factor-56)
 local action=KW.Strings['OP_ACTION_'..tostring(view.kind)]or text('TITLE')
 self.title:SetText(action..' · '..plain(view.name))
 local completed=0;for _,step in ipairs(view.steps)do if step.status=='done'then completed=completed+1 end end
 self.subtitle:SetText(text(view.status)..'   ·   '..tostring(completed)..' / '..tostring(#view.steps))
 at(self.title,self.root,24,16,width-82,32);at(self.close,self.root,width-47,20,24,24)
 at(self.subtitle,self.root,24,52,width-48,22);at(self.line,self.root,24,83,width-48,1)
 local inner=width-70;local y=0
 for index,step in ipairs(view.steps)do
  local row=self:Row(index);row:SetHidden(false)
  local status=step.status or 'pending'
  local color=status=='done' and {.5,.8,.52,1}or (status=='failed' or status=='unconfirmed')and {.92,.54,.44,1}
    or status=='running' and {.5,.8,.88,1}or {.6,.6,.56,1}
  row.highlight:SetHidden(index~=view.index)
  row.mark:SetHidden(status=='done');row.doneIcon:SetHidden(status~='done')
  row.doneIcon:SetColor(unpack(color));at(row.doneIcon,row,4,2,20,20)
  row.mark:SetText(status=='running' and '>'or (status=='failed' or status=='unconfirmed')and '!'or tostring(index))
  row.mark:SetColor(unpack(color));at(row.mark,row,0,0,28,24)
  row.title:SetColor(unpack(color));row.title:SetText(W.StepTitle(step));at(row.title,row,34,0,inner-34,0)
  local titleH=math.max(24,row.title:GetTextHeight()/factor)
  row.body:SetText(W.StepBody(step));row.body:SetColor(.8,.79,.7,1);at(row.body,row,34,titleH+3,inner-34,0)
  local bodyH=row.body:GetText()~='' and row.body:GetTextHeight()/factor+7 or 0
  local height=titleH+bodyH+15
  row.contentTop=y
  at(row,self.child,0,y,inner,height);at(row.rule,row,34,height-4,inner-34,1);y=y+height
 end
 local buttons={self.pause,self.resume,self.restart,self.report};local widths={};local gap=8;local total=3*gap
 for i,button in ipairs(buttons)do
  self.measure:SetText(button:GetLabelControl():GetText())
  widths[i]=math.max(76,math.ceil(self.measure:GetTextWidth()/factor)+24);total=total+widths[i]
 end
 local twoRows=total>width-48;local footer=twoRows and 38 or 0
 local height=math.min(maxHeight,math.max(300,y+205+footer));self.root:SetDimensions(width,height)
 at(self.scroll,self.root,24,94,width-48,height-212-footer);self.child:SetDimensions(inner,math.max(1,y))
 if self.api.ZO_Scroll_UpdateScrollBar then self.api.ZO_Scroll_UpdateScrollBar(self.scroll)end
 local x=24
 for i,button in ipairs(buttons)do
  if twoRows then
   local bw=(width-48-gap)/2
   at(button,self.root,24+(i-1)%2*(bw+gap),height-136+math.floor((i-1)/2)*38,bw,30)
  else
   local bw=widths[i]+(width-48-total)/4
   at(button,self.root,x,height-98,bw,30);x=x+bw+gap
  end
 end
 at(self.hint,self.root,24,height-56,width-48,40)
 local running=view.status=='running' or view.status=='pausing'
 self.pause:SetEnabled(view.status=='running');self.resume:SetEnabled(not running);self.restart:SetEnabled(not running)
 self.hint:SetText(view.status=='failed' and text('FAILED_HINT') or view.status=='paused' and text('PAUSED_HINT')or text('HINT'))
 local row=self.rows[view.index]
 if self.followActive and view.visible and row then
  local geometry=table.concat({view.index,row.contentTop,row:GetHeight(),y,width,height,footer},':')
  if self.followGeometry~=geometry then
   self.followGeometry=geometry
   -- Native helper accounts for the edge fade and clamps against FINAL content
   -- dimensions. Align the heading, including when an error is taller than the viewport.
   self.api.ZO_Scroll_SetScrollToRealOffsetAccountingForGradients(self.scroll,y*factor,row.contentTop*factor,160)
  end
 end
end
