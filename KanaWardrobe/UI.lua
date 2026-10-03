local KW=KanaWardrobe
local UI={};KW.UI=UI
local Instance={};Instance.__index=Instance
local D=KW.Dialogs
local unpack=unpack or table.unpack
local PANEL_WIDTH, PAD, GUTTER = 300, 12, ZO_SCROLL_BAR_WIDTH or 16
local ROW_HEIGHT=36
local function scale(control)return control.GetScale and control:GetScale() or 1 end
local function place(control,parent,x,y,width,height)
 control:ClearAnchors();control:SetAnchor(TOPLEFT,parent,TOPLEFT,x,y)
 if width then control:SetWidth(width)end
 if height then control:SetHeight(height)end
end
local function textHeight(control)
 return math.max(18,(control.GetTextHeight and control:GetTextHeight() or control:GetHeight())/scale(control))
end
local function snapshotLayout(control)
 local w,h=control:GetDimensions();local factor=scale(control)
 local data={width=w/factor,height=h/factor,anchors={}}
 for index=0,control:GetNumAnchors()-1 do
  local valid,point,relativeTo,relativePoint,x,y,constraints=control:GetAnchor(index)
  if valid then data.anchors[#data.anchors+1]={point,relativeTo,relativePoint,x,y,constraints}end
 end
 return data
end
local function restoreLayout(control,data)
 control:ClearAnchors();control:SetDimensions(data.width,data.height)
 for _,anchor in ipairs(data.anchors)do control:SetAnchor(unpack(anchor,1,6))end
end
local function text(key)return KW.Strings[key] or "" end
local function count(t)local n=0;for _,v in pairs(t or {})do if v then n=n+1 end end;return n end
local function tooltip(control,value)
 if not InitializeTooltip then return end
 -- Keep checkbox help on screen; panel help opens away from the set cards.
 if control:GetLeft()/scale(control)>=320 then
  InitializeTooltip(InformationTooltip,control,RIGHT,-8,0,LEFT)
 else InitializeTooltip(InformationTooltip,control,LEFT,8,0,RIGHT)end
 SetTooltipText(InformationTooltip,value)
end
local function clearTooltip()if ClearTooltip then ClearTooltip(InformationTooltip)end end
local function label(parent,name,value,x,y,width,font)
 local c=WINDOW_MANAGER:CreateControl(name,parent,CT_LABEL);c:SetAnchor(TOPLEFT,parent,TOPLEFT,x,y)
 c:SetWidth(width);c:SetFont(font or "ZoFontGame");c:SetText(value);return c
end
local function button(parent,name,value,x,y,width,callback)
 local c=WINDOW_MANAGER:CreateControlFromVirtual(name,parent,"ZO_DefaultButton")
 c:SetAnchor(TOPLEFT,parent,TOPLEFT,x,y);c:SetDimensions(width,28);c:SetText(value)
 c:SetHandler("OnClicked",callback);return c
end
-- Native right-panel art begins left of the bag controls themselves.
function UI.InventoryLeftEdge()
 local bag=ZO_PlayerInventory
 if not bag or bag:IsHidden()then return nil end
 local left=bag:GetLeft()
 local background=ZO_SharedRightPanelBackground
 local texture=background and background:GetNamedChild("Left")
 if texture then left=math.min(left,texture:GetLeft())end
 return left
end
function UI.New(repo,session,preview,inventory,services)
 local self=setmetatable({repo=repo,session=session,preview=preview,inventory=inventory or (KW.runtime and KW.runtime.inventory),rows={},layouts={},checks={},toggles={},hoverSerial=0,visible=false,services=services or {},page="inventory"},Instance)
 self.pages=self.services.pages
 self.overlayPages=self.pages or (KW.PageAdapters and KW.PageAdapters.New(self.inventory and self.inventory.api or _G))
 self.selectionOverlays={}
 if self.pages then self.pages.session=session;self.pages.requestEquipmentExit=function(scene)self:CloseEditor(scene)end end
 if self.services.events and self.pages then
  for _,name in ipairs({"SessionChanged","SkillSubmissionChanged"})do
   self.services.events:Subscribe(name,function()self.pages:RefreshOwnership()end)
  end
 end
 if WINDOW_MANAGER and KanaWardrobePanel then self:Build() end
 if preview and preview.SetLayoutChangedCallback then
  preview:SetLayoutChangedCallback(function()
   if self.root then self:SetBackgroundExpanded(self.visible)end
  end)
 end
 if preview and preview.SetCloseCallback then
  preview:SetCloseCallback(function()self.hoverSerial=self.hoverSerial+1;self.hoverControl=nil;clearTooltip()end)
 end
 return self
end
-- d() writes a local system message; it never sends a player chat message.
function Instance:Message(message)
 if not message or message=="" then return end
 local api=self.inventory and self.inventory.api or _G
 local output=api.d or d
 if output then output("|cC5B58AKanaWardrobe|r: "..message)end
end
function Instance:Problem(problem)
 self.lastProblem=problem
 if problem and (problem.code=='foreignSkillDraft' or problem.code=='skillBarOverride') and not (problem.details and problem.details.nativeReportSaved) and self.services.describeProblem then
  self.services.describeProblem(problem,self.currentCommand,self.currentCommandArgs)
 end
 local message=D.Problem(problem)
 if message~="" and self.reportedProblem~=message then self:Message(message);self.reportedProblem=message end
 return nil,problem
end
function Instance:Command(method,...)
 self.lastProblem=nil;self.lastOutcome=nil;self.reportedProblem=nil
 self.currentCommand=method
 self.currentCommandArgs={...}
 local result,problem=self.session[method](self.session,...)
 if not result and problem then self:Problem(problem)end
 self:Refresh();self.currentCommand=nil;self.currentCommandArgs=nil;return result,problem
end
function Instance:Readiness()
 local api=self.inventory and self.inventory.api or _G
 if api.IsUnitInCombat and api.IsUnitInCombat("player")then return KW.Problem("inCombat")end
 if api.IsUnitDead and api.IsUnitDead("player")then return KW.Problem("dead")end
 if api.IsBlockActive and api.IsBlockActive()then return KW.Problem("blocking")end
end
local function selectionCount(view)
 if view.component=="attributes"then return view.attributesEnabled and 1 or 0 end
 if view.component=="abilities"then
  local v=view.selection or {};return count(v.skills)+count(v.bars and v.bars.front)+count(v.bars and v.bars.back)+count(v.bars and v.bars.werewolf)
 end
 return count(view.selected)
end
function Instance:Model(snapshot,actual,catalogue,captureProblem)
 local view=self.session:GetView();local readiness=self:Readiness()
 local idle=view.state=="idle";local editing=view.state=="editing" and not view.paused
 local selected=selectionCount(view)
 local unresolved=count(view.missing)
 if view.component=='abilities'then
  unresolved=0
  for _,entry in pairs(view.missing or {})do
   local selection=view.selection or {};local included=entry.domain=='skills' and (selection.skills or {})[entry.key] or entry.domain~='skills' and ((selection.bars or {})[entry.domain]or {})[entry.key]
   if included then unresolved=unresolved+1 end
  end
 end
 local projected=selected>0
 if view.component and not projected then
  local preset=view.presetId and self.repo:Get(view.presetId)
  if preset then
   for _,part in ipairs({"equipment","abilities","attributes"})do
    if part~=view.component and preset[part]~=nil then projected=true end
   end
  end
 end
 local model={view=view,rows={},quickId=KW.Presets.QUICK_ID,selectedCount=selected,canNew=idle and not readiness,
  canSave=editing and projected and unresolved==0 and not readiness,
  canSaveAndApply=editing and projected and unresolved==0 and not readiness,
  canCancel=editing and not readiness,reason=D.Problem(readiness or view.problem),isEditor=view.isEditor==true}
 model.canQuickSave=idle and not readiness
 model.canQuickLoad=model.canQuickSave and self.repo:Get(KW.Presets.QUICK_ID)~=nil
 if not idle and model.reason=="" then model.reason=text("BUSY")end
 if editing and unresolved>0 then model.saveReason=D.Problem({code="missingUnresolved"})
 elseif editing and not projected then model.saveReason=text("EMPTY_SELECTION")else model.saveReason=model.reason end
 for _,preset in ipairs(self.repo:List())do
  local row={id=preset.id,name=D.Plain(preset.name),preset=preset,matches=true,missing={},missingBySlot={},canApply=idle and not readiness}
  if actual and KW.BuildModel then
   row.matches=KW.BuildModel.Matches(actual,preset)
   if row.matches and preset.abilities and KW.SkillState then
    row.matches=KW.BuildModel.Matches(actual,{abilities=KW.SkillState.ExpandMasterySelection(preset.abilities,catalogue)})
   end
   for _,part in ipairs({"equipment","abilities","attributes"})do
    if preset[part]~=nil and actual[part]==nil then
     row.problem=captureProblem or KW.Problem(part=="abilities" and "skillsUnavailable"or part=="attributes"and"attributesUnavailable"or"invalidBuildSnapshot")
     row.canApply=false;break
    end
   end
  elseif self.services.captureActual then row.problem=captureProblem or KW.Problem("invalidBuildSnapshot");row.matches=false;row.canApply=false end
  for _,slot in ipairs(KW.Slots.Order)do
   local ref=(preset.slots or preset.equipment or {})[slot]
   if ref then
    local worn=snapshot.worn[slot]
    if not actual and (not worn or worn.kind~=ref.kind or (ref.kind=="item" and worn.uid~=ref.uid))then row.matches=false end
    if ref.kind=="item" then
     local location=snapshot.byUid[ref.uid]
     if not location or not (location.bagId==BAG_WORN or location.bagId==BAG_BACKPACK) then
      row.missing[#row.missing+1]={slot=slot,link=ref.link};row.missingBySlot[slot]=ref;row.canApply=false
     end
    end
   end
  end
  row.reason=row.problem and D.Problem(row.problem)or #row.missing>0 and text("MISSING_HELP").."\n"..D.MissingText(row.missingBySlot) or model.reason
  if self.session.operations then row.canApply=idle end
  model.rows[#model.rows+1]=row
 end
 if self.session.operations then
  model.canNew=idle;model.canQuickLoad=idle and self.repo:Get(KW.Presets.QUICK_ID)~=nil
  model.canSave=editing and projected and unresolved==0
  model.canSaveAndApply=model.canSave;model.canCancel=editing
 end
 return model
end
function Instance:Refresh()
 if not self.inventory then return nil end
 local actual,catalogue,problem
 if self.services.captureActual then actual,catalogue,problem=self.services.captureActual()end
 local snapshot=actual and actual.equipmentState or self.inventory:Capture(false)
 self.descriptionCatalogue=catalogue;self.descriptionInventory=snapshot
 self.model=self:Model(snapshot,actual,catalogue,problem)
 if self.closeDecision and self.model.view.state=='recovery'then
  local decision=self.closeDecision;self.closeDecision=nil;D.Retire(decision.dialog)
  if decision.scene then decision.scene:RejectHideScene()end
 end
 if self.pages then self.pages:RefreshOwnership()end
 if self.model.view.problem then self:Problem(self.model.view.problem)else self.reportedProblem=nil end
 if self.content then self:Render(self.model)end
 return self.model
end
function Instance:OnSessionFinished(result)
 local decision=self.closeDecision
 if decision and self.session.journal==decision.owner and self.session:GetView().state~='idle'then return end
 if decision then
  self.closeDecision=nil;D.Retire(decision.dialog)
  if decision.scene then
   if self.session:GetView().state=='idle' and not result.problem and decision.action and result.outcome==(decision.action=='Save' and 'saved' or 'cancelled')then decision.scene:AcceptHideScene()
   else decision.scene:RejectHideScene()end
  end
 end
 if not self.session.operations and not result.problem and (result.outcome=='applied' or result.outcome=='restored' or result.outcome=='saved' or result.outcome=='cancelled')then self:CompleteProgress()
 else self.progressCompleting=nil end
 self.lastProblem=result.problem
 self.lastOutcome=result.outcome
 if result.problem then self:Problem(result.problem)else self:Message(text("OUTCOME_"..(result.outcome or "")))end
 self:ScheduleRefresh()
end
function Instance:ScheduleRefresh()
 if self.refreshPending then return end
 self.refreshPending=true
 local function refresh()self.refreshPending=false;self:Refresh()end
 if zo_callLater then zo_callLater(refresh,0)else refresh()end
end
function Instance:FindRow(id)
 for _,row in ipairs((self.model or self:Refresh()).rows)do if row.id==id then return row end end
end
function Instance:RowClick(id,mouseButton)
 local row=self:FindRow(id);if not row then return end
 if mouseButton==2 then return self:ContextMenu(row)end
 if mouseButton==1 then
  if row.canApply then self:Command("Apply",id)else self:Message(row.reason)end
 end
end
function Instance:ContextMenu(row,anchor)
 self.hoverSerial=self.hoverSerial+1;self.hoverControl=nil;clearTooltip()
 if self.preview then self.preview:Hide()end
 local actions={
  {label=text("EDIT"),run=function()
   if self.session.operations then self:Command("BeginEdit",row.id,true,self.page)
   elseif #row.missing>0 then D.ConfirmEditMissing(row.missingBySlot,function()self:Command("BeginEdit",row.id,true,self.page)end)
   else self:Command("BeginEdit",row.id,false,self.page)end
  end},
  {label=text("DUPLICATE"),run=function()
   if self.session:GetView().state~="idle"then return self:Problem({code="busy"})end
   local copy,problem=self.repo:Duplicate(row.id,row.preset.revision)
   if not copy then self:Problem(problem)end
   self:Refresh()
  end},
  {label=text("DELETE"),run=function()D.ConfirmDelete(row.preset,function()
   if self.session:GetView().state~="idle"then return self:Problem({code="busy"})end
   local ok,problem=self.repo:Delete(row.id,row.preset.revision);if not ok then self:Problem(problem)end;self:Refresh()
  end)end},
 }
 if ClearMenu then
  ClearMenu()
  if self.session:GetView().state~="idle" then AddMenuItem(text("BUSY"),function()end)
  else for _,action in ipairs(actions)do AddMenuItem(action.label,action.run)end end
  ShowMenu(anchor or self.content)
 end
 return actions
end
function Instance:Summary(preset)
 local description=KW.BuildDescription and KW.BuildDescription.Build(preset,self.descriptionCatalogue)
 local equipment=description and description.equipmentSummary or preset.equipment or preset.slots
 if description and not equipment then return {name=preset.name,description=description}end
 local state=self.descriptionInventory or self.inventory:Capture(false)
 local current={name=preset.name,equipment=description and description.equipmentSummary or KW.Copy(equipment or {})}
 for _,ref in pairs(current.equipment)do
  local location=ref.kind=="item" and state.byUid[ref.uid]
  if location then ref.link=location.link end
 end
 local summary=KW.SetModel.Build(current,function(ref)
  local location=state.byUid[ref.uid]
  return location and (location.metadata or self.inventory:Metadata(location.link,location)) or self.inventory:Metadata(ref.link,nil)
 end)
 summary.description=description;return summary
end
function Instance:Hover(row,control)
 if self.session:GetView().isEditor then return end
 self.hoverSerial=self.hoverSerial+1;local serial=self.hoverSerial;self.hoverControl=control
 local function show()
  if self.hoverSerial~=serial or self.session:GetView().isEditor or not self.visible then return end
  if MouseIsOver and not MouseIsOver(control) then return end
  if #row.missing>0 then tooltip(control,row.reason)end
  self.preview:Show(control,self:Summary(row.preset),self.root)
 end
 if zo_callLater then zo_callLater(show,60)end
end
function Instance:Leave()
 clearTooltip()
end
function Instance:HideDescription()
 self.hoverSerial=self.hoverSerial+1;self.hoverControl=nil
 if self.preview then self.preview:Hide()end
end
function Instance:RememberLayout(control)
 if not self.layouts[control]then self.layouts[control]=snapshotLayout(control)end
end
function Instance:RestoreLayout()
 for control,data in pairs(self.layouts)do restoreLayout(control,data)end
 self.layouts={}
end
function Instance:SetEditorLayout(active)
 -- Retire any old remembered layout once; editing never changes native slots.
 if next(self.layouts)then self:RestoreLayout()end
 self.layoutActive=active
 if not active then self:ClearSelectionOverlays()end
end
function Instance:OnSceneHidden(page)
 if self.pages and page and page~=self.page then return end
 if self.pages then self.pages:Unmount(self.page)end
 self.visible=false;self.geometryHiddenPage=nil
 if self.content then self.content:SetHidden(true)end
 self:HideDescription()
 self:SetEditorLayout(false)
 self:SetBackgroundExpanded(false)
 if not self.pages and self.session:GetView().state~="idle"then self:Command("Pause","sceneHidden")end
end
function Instance:CloseEditor(scene)
 if self.closeDecision then
  -- A native exit can arrive while the ordinary close dialog is already open.
  if scene then self.closeDecision.scene=scene end
  return self.closeDecision.dialog
 end
 local view=self.session:GetView()
 if view.state=="editing" and not view.paused then
  local decision={scene=scene,owner=self.session.journal};self.closeDecision=decision
  local function continue()
   if self.closeDecision~=decision or decision.action then return end
   self.closeDecision=nil;D.Retire(decision.dialog)
   if decision.scene then decision.scene:RejectHideScene()end
  end
  local function finish(action)
   if self.closeDecision~=decision or decision.action then return end
   decision.action=action
   local ok=self:Command(action)
   if not ok and self.closeDecision==decision then
    self.closeDecision=nil;D.Retire(decision.dialog)
    if decision.scene then decision.scene:RejectHideScene()end
   end
  end
  decision.dialog=D.CloseEditor(function()finish('Save')end,function()finish('Cancel')end,continue)
  return decision.dialog
 elseif scene then scene:RejectHideScene()
 elseif view.recovery then self:RecoveryMenu()
 elseif view.isEditor then D.Recovery(view,function(action)self:Command("Recover",action,view.recoveryKey)end)end
end
function Instance:RecoveryActions()
 local view=self.session:GetView();local choices={}
 if view.state=='recovery' and view.recovery and self.session.GetRecoveryView then
  local problem;view,problem=self.session:GetRecoveryView()
  if not view then self:Problem(problem);return choices end
 end
 if view.state~="recovery"or not view.recovery or not view.recovery.actions then return choices end
 local key=view.recoveryKey
 for _,action in ipairs(view.recovery.actions)do
  local selected=action
  choices[#choices+1]={label=text("RECOVER_"..selected),run=function()
   local function execute()
    local current=self.session:GetView()
    if current.state~="recovery"or current.recoveryKey~=key then return self:Problem(KW.Problem("recoveryChanged"))end
    return self:Command("Recover",selected,key)
   end
   if selected=="acceptCurrent"then
    local current=self.session:GetView()
    if current.state~="recovery"or current.recoveryKey~=key then return self:Problem(KW.Problem("recoveryChanged"))end
    return D.ConfirmRecoveryEndpoint(selected,execute)
   end
   return execute()
  end}
 end
 return choices
end
function Instance:RecoveryMenu()
 local choices=self:RecoveryActions()
 if ClearMenu then
  ClearMenu();for _,choice in ipairs(choices)do AddMenuItem(choice.label,choice.run)end
  ShowMenu(self.recoverButton or self.content)
 end
 return choices
end
function Instance:RepairChoices(id)
 local view=self.session:GetView();local entry=view.component=='abilities' and view.missing[id]
 if not entry then return {}end
 local choices={{label=text('REPAIR_REMOVE'),run=function()self:Command('ResolveMissingAbility',id,'omit')end}}
 if entry.domain=='skills'then
  local keys={};for key in pairs(view.draft.abilities.skills or {})do if not view.missing['skill:'..key]then keys[#keys+1]=key end end;table.sort(keys)
  for _,key in ipairs(keys)do
   local replacement=key;local record=self.descriptionCatalogue and self.descriptionCatalogue.byKey[key]
   local name=record and record.name
   -- Resolve names only for this explicit repair menu, not every list refresh.
   if not name and record and record.native and record.native.GetCurrentProgressionData then
    local progression=record.native:GetCurrentProgressionData()
    name=progression and progression:GetName()
   end
   choices[#choices+1]={label=text('REPAIR_REPLACE')..': '..D.Plain(name or key),run=function()self:Command('ResolveMissingAbility',id,'replace',replacement)end}
  end
 else choices[#choices+1]={label=text('REPAIR_REPLACE'),run=function()self:Command('ResolveMissingAbility',id,'replace')end}end
 return choices
end
function Instance:RenderRepairs(view)
 self.repairRows=self.repairRows or {}
 local ids={};if view.component=='abilities'then for id in pairs(view.missing or {})do ids[#ids+1]=id end end;table.sort(ids)
 for index,id in ipairs(ids)do
  local entry=view.missing[id];local row=self.repairRows[index]
  if not row then
   row=WINDOW_MANAGER:CreateControl('KanaWardrobeRepair'..index,self.editor,CT_CONTROL);row:SetMouseEnabled(true)
   row.title=label(row,'KanaWardrobeRepair'..index..'Title','',0,0,220,'ZoFontGameSmall')
   row.title:SetMaxLineCount(1);row.title:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
   row.reason=label(row,'KanaWardrobeRepair'..index..'Reason','',0,20,220,'ZoFontGameSmall')
   row.reason:SetMaxLineCount(2);row.reason:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
   row.action=button(row,'KanaWardrobeRepair'..index..'Action',text('EDIT'),0,54,220,function()
    if not ClearMenu then return end
    ClearMenu();for _,choice in ipairs(self:RepairChoices(row.id))do AddMenuItem(choice.label,choice.run)end;ShowMenu(row.action)
   end)
   self.repairRows[index]=row
  end
  row.id=id;row:SetHidden(false)
  local source=entry.domain=='skills' and entry.skillKey or text(entry.domain=='front' and 'SUMMARY_FRONT' or 'SUMMARY_BACK')..' '..entry.key..' · '..entry.skillKey
  row.title:SetText(D.Plain(source));row.reason:SetText(D.Problem(entry.problem));row.action:SetEnabled(view.state=='editing' and not view.paused)
  row:SetHandler('OnMouseEnter',function()tooltip(row,D.Plain(source)..'\n'..D.Problem(entry.problem))end);row:SetHandler('OnMouseExit',clearTooltip)
 end
 for index=#ids+1,#self.repairRows do self.repairRows[index]:SetHidden(true)end
end
function Instance:ResolveMenu(slot,anchor)
 if not ClearMenu then return end
 ClearMenu()
 for _,entry in ipairs({{"USE_WORN","replace"},{"SAVE_EMPTY","empty"},{"OMIT_SLOT","omit"}})do
  local choice=entry[2];AddMenuItem(text(entry[1]),function()self:Command("ResolveMissing",slot,choice)end)
 end
 ShowMenu(anchor)
end
-- A fixed footer track: progress never changes list/editor geometry.
function Instance:CompleteProgress()
 if not self.progressOperation then return end
 self.progressStart=self.progressValue;self.progressTarget=1;self.progressElapsed=0
 self.progressCompleting=(self.progressTime or 0)+.6
end
function Instance:UpdateProgress(view)
 if not self.progressTrack then return end
 local p=view.progress
 local running=view.state=='applying' or view.state=='preparingEdit' or view.state=='restoring'
 local visible=running and p and p.total and p.total>0
 if not visible and self.progressCompleting then return end
 if not visible and view.state=='editing' and p and p.total>0 and p.completed==p.total and self.progressOperation then
  self:CompleteProgress();return
 end
 self.progressTrack:SetHidden(not visible);self.progressLabel:SetHidden(not visible);self.progressStage:SetHidden(not visible)
 if not visible then self.progressFill:SetHidden(true);self.progressOperation=nil;return end
 if self.progressOperation~=p.operationId then
  self.progressCompleting=nil
  self.progressOperation=p.operationId;self.progressValue=0;self.progressStart=0;self.progressTarget=0;self.progressElapsed=0;self.progressTime=nil
  self.progressTrack:SetAlpha(1);self.progressLabel:SetAlpha(1);self.progressStage:SetAlpha(1)
 end
 -- Only SessionFinished can award the final 100%, after whole-build checks.
 local target=math.min(.99,math.max(0,p.ratio or (p.completed or 0)/p.total))
 if target~=self.progressTarget then
  self.progressStart=self.progressValue;self.progressTarget=target;self.progressElapsed=0
 end
 local phases={skills='PROGRESS_SKILLS',attributes='PROGRESS_ATTRIBUTES',equipment='PROGRESS_EQUIPMENT'}
 local phaseLabel=text(phases[p.phase]or 'PROGRESS_EQUIPMENT')
 if p.stage=='cooldown'then phaseLabel=phaseLabel..' · '..text('PROGRESS_COOLDOWN')end
 self.progressStage:SetText(phaseLabel)
 self.progressLabel:SetText(tostring(math.floor(target*100+.5))..'%')
end
function Instance:AnimateProgress(now)
 if not self.progressOperation then return end
 local dt=self.progressTime and math.max(0,now-self.progressTime)or 0;self.progressTime=now
 if self.progressCompleting and now>=self.progressCompleting then
  self.progressCompleting=nil;self.progressOperation=nil
  self.progressTrack:SetHidden(true);self.progressFill:SetHidden(true);self.progressLabel:SetHidden(true);self.progressStage:SetHidden(true);return
 end
 self.progressElapsed=(self.progressElapsed or 0)+dt
 local t=math.min(1,self.progressElapsed/.2);t=t*t*(3-2*t)
 self.progressValue=(self.progressStart or 0)+(self.progressTarget-(self.progressStart or 0))*t
 local alpha=self.progressCompleting and math.min(1,math.max(0,(self.progressCompleting-now)/.2))or 1
 self.progressTrack:SetAlpha(alpha);self.progressLabel:SetAlpha(alpha);self.progressStage:SetAlpha(alpha)
 if self.progressCompleting then self.progressLabel:SetText(tostring(math.floor(self.progressValue*100+.5))..'%')end
 self.progressFill:SetHidden(self.progressValue<=0)
 self.progressFill:SetWidth(math.max(.01,self.progressTrack:GetWidth()/scale(self.progressTrack)*self.progressValue))
end
function Instance:Build()
 self.root=KanaWardrobePanel;self.content=self.root:GetNamedChild("Content")
 self.root:SetWidth(PANEL_WIDTH)
 self.root:SetClampedToScreen(true)
 self.root:SetHandler("OnUpdate",function(_,now)
  self:AnimateProgress(now)
  if self.visible and (not self.layoutTime or now-self.layoutTime>=0.25)then
   self.layoutTime=now;self:LayoutPanel()
  end
 end)
 local c=self.content
 self.progressTrack=WINDOW_MANAGER:CreateControl('KanaWardrobeProgressTrack',c,CT_TEXTURE)
 self.progressTrack:SetColor(.16,.23,.24,.65)
 self.progressTrack:SetDrawLayer(DL_CONTROLS);self.progressTrack:SetMouseEnabled(false)
 self.progressFill=WINDOW_MANAGER:CreateControl('KanaWardrobeProgressFill',self.progressTrack,CT_TEXTURE)
 self.progressFill:SetAnchor(TOPLEFT,self.progressTrack,TOPLEFT,0,0);self.progressFill:SetHeight(4)
 self.progressFill:SetDrawLayer(DL_OVERLAY);self.progressFill:SetMouseEnabled(false)
 self.progressFill:SetColor(.46,.76,.8,.95)
 self.progressLabel=label(c,'KanaWardrobeProgressLabel','',0,0,48,'ZoFontGameSmall')
 self.progressLabel:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
 self.progressStage=label(c,'KanaWardrobeProgressStage','',0,0,180,'ZoFontGameSmall')
 self.progressStage:SetColor(.78,.76,.65,1)
 self.progressStage:SetMaxLineCount(1);self.progressStage:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
 self.title=label(c,"KanaWardrobeTitle",(zo_strupper or string.upper)(text("PRESETS")),12,10,240,"ZoFontHeader4")
 if self.session.operations then
  self.operationButton=button(c,'KanaWardrobeOperationOpen','≡',0,0,28,function()self.session.operations:SetVisible(true)end)
  self.operationButton:SetHandler('OnMouseEnter',function()tooltip(self.operationButton,text('OP_REOPEN'))end)
  self.operationButton:SetHandler('OnMouseExit',clearTooltip)
 end
 self.newButton=button(c,"KanaWardrobeNew",text("NEW_PRESET"),12,44,224,function()self:Command("BeginNew",self.page)end)
 self.list=WINDOW_MANAGER:CreateControlFromVirtual("KanaWardrobeList",c,"ZO_ScrollContainer")
 self.list:SetAnchor(TOPLEFT,c,TOPLEFT,8,148);self.list:SetAnchor(BOTTOMRIGHT,c,BOTTOMRIGHT,-8,-48)
 self.listChild=self.list:GetNamedChild("Scroll"):GetNamedChild("Child");self.listChild:SetResizeToFitDescendents(false)
 self.editorScroll=WINDOW_MANAGER:CreateControlFromVirtual("KanaWardrobeEditorScroll",c,"ZO_ScrollContainer")
 self.editorScroll:SetAnchor(TOPLEFT,c,TOPLEFT,12,146);self.editorScroll:SetAnchor(BOTTOMRIGHT,c,BOTTOMRIGHT,-8,-12)
 self.editor=self.editorScroll:GetNamedChild("Scroll"):GetNamedChild("Child")
 self.editor:SetResizeToFitDescendents(false);self.editor:SetDimensions(260,432)
 self.footer=WINDOW_MANAGER:CreateControl("KanaWardrobeFooter",c,CT_CONTROL)
 self.nameButton=button(self.editor,"KanaWardrobeName","",0,0,224,function()
  D.EditName({name=self.session:GetView().name},function(name)self:Command("SetName",name)end)
 end)
 self.nameLabel=label(self.nameButton,"KanaWardrobeNameLabel","",10,2,204,"ZoFontGame")
 self.nameLabel:SetMaxLineCount(1);self.nameLabel:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
 self.nameButton:SetHandler("OnMouseEnter",function()tooltip(self.nameButton,D.Plain(self.session:GetView().name).."\n"..text("EDIT_HELP"))end)
 self.nameButton:SetHandler("OnMouseExit",clearTooltip)
 self.allButton=button(self.editor,"KanaWardrobeAll",text("ALL"),0,124,108,function()self:SelectAll(true)end)
 self.noneButton=button(self.editor,"KanaWardrobeNone",text("NONE"),114,124,110,function()self:SelectAll(false)end)
 self.ghostButton=button(self.editor,"KanaWardrobeGhosts",text("RESOLVE"),0,158,224,function()
  ClearMenu();for _,slot in ipairs(KW.Slots.Order)do
   if self.session:GetView().missing[slot]then local id=slot;AddMenuItem(D.SlotName(slot),function()zo_callLater(function()self:ResolveMenu(id,self.ghostButton)end,0)end)end
  end;ShowMenu(self.ghostButton)
 end)
 self.saveButton=button(self.footer,"KanaWardrobeSave",text("SAVE"),0,196,108,function()self:Command("Save")end)
 self.saveAndApplyButton=button(self.footer,"KanaWardrobeSaveAndApply",text("SAVE_AND_APPLY"),0,0,224,function()self:Command("SaveAndApply")end)
 self.cancelButton=button(self.footer,"KanaWardrobeCancel",text("CANCEL"),114,196,110,function()self:Command("Cancel")end)
 self.resumeButton=button(self.editor,"KanaWardrobeResume",text("RESUME"),0,292,224,function()self:Command("Resume")end)
 self.recoverButton=button(self.editor,"KanaWardrobeRecover",text("RESTORE"),0,326,224,function()
  local view=self.session:GetView()
  if view.recovery then self:RecoveryMenu()else self:Command("Recover","restore",view.recoveryKey)end
 end)
 self.partialButton=button(self.editor,"KanaWardrobePartial",text("RESTORE_AVAILABLE"),0,360,224,function()
  local view=self.session:GetView();D.ConfirmRestoreAvailable(view.recoveryMissing or view.missing,function()self:Command("Recover","restoreAvailable",view.recoveryKey)end)
 end)
 self.keepButton=button(self.editor,"KanaWardrobeKeep",text("KEEP_CURRENT"),0,394,224,function()D.ConfirmKeepCurrent(function()self:Command("Recover","keepCurrent")end)end)
 self.closeButton=WINDOW_MANAGER:CreateControlFromVirtual("KanaWardrobeClose",c,"ZO_CloseButton")
 self.closeButton:SetHandler("OnClicked",function()self:CloseEditor()end)
 self.closeButton:SetHandler("OnMouseEnter",function()tooltip(self.closeButton,text("CLOSE"))end)
 self.closeButton:SetHandler("OnMouseExit",clearTooltip)
 self.quickBar=WINDOW_MANAGER:CreateControl("KanaWardrobeQuickBar",c,CT_CONTROL)
 self.quickSave=button(self.quickBar,"KanaWardrobeQuickSave",text("QUICK_SAVE"),0,0,120,function()self:Command("QuickSave")end)
 self.quickLoad=button(self.quickBar,"KanaWardrobeQuickLoad",text("QUICK_LOAD"),128,0,120,function()self:Command("QuickLoad")end)
 for _,b in ipairs({self.quickSave,self.quickLoad})do
  b:SetFont("ZoFontGameSmall")
  b:SetHandler("OnMouseExit",clearTooltip)
 end
 self.attributesCheck=WINDOW_MANAGER:CreateControlFromVirtual("KanaWardrobeAttributesInclude",self.editor,"ZO_CheckButton")
 self.attributesCheck:SetDimensions(20,20);ZO_CheckButton_SetLabelText(self.attributesCheck,text("ATTRIBUTES_INCLUDE"))
 ZO_CheckButton_SetToggleFunction(self.attributesCheck,function(_,checked)self:Command("SetAttributesEnabled",checked)end)
 self:BuildChecks()
 self.fragment=ZO_SimpleSceneFragment:New(self.root)
 for _,page in ipairs(self.pages and {"inventory","skills","stats"}or {"inventory"})do
  local scene=SCENE_MANAGER:GetScene(page)
  if scene then
   scene:AddFragment(self.fragment)
   scene:RegisterCallback("StateChange",function(_,state)
    if state==SCENE_HIDING or state==SCENE_HIDDEN then self:OnSceneHidden(page)
    elseif state==SCENE_SHOWING or state==SCENE_SHOWN then
     if self.page~=page then self:HideDescription()end
     self.page=page
     if self.pages then self.pages:Mount(page,self.session)end
     self.visible=page~="inventory"or not INVENTORY_FRAGMENT or INVENTORY_FRAGMENT:IsShowing();self:ScheduleRefresh()
    end
   end)
  end
 end
 -- Native items-tab fragment owns tab visibility independently of the scene.
 if INVENTORY_FRAGMENT then
  INVENTORY_FRAGMENT:RegisterCallback("StateChange",function(_,state)
   if state==SCENE_FRAGMENT_HIDING or state==SCENE_FRAGMENT_HIDDEN then self:OnSceneHidden("inventory")
   elseif state==SCENE_FRAGMENT_SHOWING or state==SCENE_FRAGMENT_SHOWN then
    if SCENE_MANAGER:IsShowing("inventory")then self.visible=true;self:ScheduleRefresh()end
   end
  end)
 end
 self:Refresh()
end
-- Keep the original preset-only extension; description layout is independent.
function Instance:SetBackgroundExpanded(active)
 if self.pages then return self.pages:SetBackgroundExpanded(self.page,active)end
 local background=ZO_SharedWideLeftPanelBackground
 if not background then return end
 if active then
  if not self.backgroundWidth then self.backgroundWidth=background:GetWidth()/scale(background)end
  local width=math.max(self.backgroundWidth,(self.root:GetRight()-background:GetLeft())/scale(background))
  background:SetWidth(width)
 elseif self.backgroundWidth then
  background:SetWidth(self.backgroundWidth);self.backgroundWidth=nil
 end
end
function Instance:UpdateDescriptionBounds(bounds)
 local b=bounds and bounds.description
 local key=self.page..":"..(b and table.concat({b.x,b.y,b.width,b.height,b.scale},":")or "unavailable")
 if self.descriptionGeometry==key then return end
 self.descriptionGeometry=key
 self.descriptionSafeArea=b and {x=b.x,y=b.y,width=b.width,height=b.height,scale=b.scale}or nil
 if self.preview and self.preview.SetSafeArea then self.preview:SetSafeArea(self.descriptionSafeArea)end
end
function Instance:LayoutPanel()
 if not self.root or not self.visible then return end
 if IsInGamepadPreferredMode and IsInGamepadPreferredMode()then return end
 local geometryRetry=self.pages and self.geometryHiddenPage==self.page and self.pages.active==self.page
 if self.content:IsHidden()and not geometryRetry then return end
 if self.pages then
  local bounds=self.pages:Bounds(self.page)
  if not bounds then self.pageBounds=nil;self:UpdateDescriptionBounds(nil);self.geometryHiddenPage=self.page;self.content:SetHidden(true);self:SetBackgroundExpanded(false);return end
  if geometryRetry then self.content:SetHidden(false)end
  self.geometryHiddenPage=nil
  self.pageBounds=bounds;self:UpdateDescriptionBounds(bounds);local b=bounds.list
  local key=table.concat({self.page,b.x,b.y,b.width,b.height,b.scale},":")
  if self.panelGeometry~=key then
   self.panelGeometry=key;place(self.root,GuiRoot,b.x,b.y,b.width,b.height)
   if self.model then self:LayoutContent(self.model)end
   if self.preview and not self.preview.SetSafeArea and self.preview.visible and self.preview.summary then self.preview:Refresh(self.preview.summary)end
  end
  self:SetBackgroundExpanded(true);return
 end
 local factor=scale(self.root)
 local screenWidth,screenHeight=GuiRoot:GetWidth()/factor,GuiRoot:GetHeight()/factor
 local stats=ZO_CharacterWindowStatsScroll
 local x=(stats:GetRight()-GuiRoot:GetLeft())/factor
 local heading=ZO_CharacterHeaderSectionTitle
 local titleTop=heading and heading:GetTop() or ZO_Character:GetTop()+26*factor
 local top=math.max(12,(titleTop-GuiRoot:GetTop())/factor-10)
 local bottom=math.min((stats:GetTop()+stats:GetHeight()-GuiRoot:GetTop())/factor,screenHeight-64)
 local height=math.max(180,bottom-top)
 x=math.max(12,math.min(x,screenWidth-PANEL_WIDTH-12))
 local descX=x+PANEL_WIDTH+36
 local edge=(UI.InventoryLeftEdge()or GuiRoot:GetRight())-GuiRoot:GetLeft()
 self:UpdateDescriptionBounds({description={x=descX,y=top,width=math.max(0,edge/factor-descX-24),height=height,scale=factor}})
 local key=table.concat({x,top,height,factor,screenWidth,screenHeight,UI.InventoryLeftEdge() or screenWidth*factor},":")
 if key~=self.panelGeometry then
  self.panelGeometry=key
  place(self.root,GuiRoot,x,top,PANEL_WIDTH,height)
  if self.model then self:LayoutContent(self.model)end
  if self.preview and not self.preview.SetSafeArea and self.preview.visible and self.preview.summary then
   self.preview:Refresh(self.preview.summary)
  end
 end
 self:SetBackgroundExpanded(true)
end
function Instance:LayoutContent(model)
 local panelWidth=self.root:GetWidth()/scale(self.root)
 local width=panelWidth-2*PAD
 local bodyWidth=width-GUTTER
 place(self.title,self.content,PAD,10,width-36)
 place(self.closeButton,self.content,panelWidth-PAD-20,16,20,20)
 if self.operationButton then
  local operation=self.session.operations.operation
  self.operationButton:SetHidden(not operation)
  self.operationButton:SetText(operation and operation.status=='failed' and '!'or operation and operation.status=='paused' and 'Ⅱ'or '≡')
  place(self.operationButton,self.content,panelWidth-PAD-30,9,28,28)
  self.title:SetWidth(panelWidth-PAD*2-38)
 end
 local bodyTop=60
 local height=self.content:GetHeight()/scale(self.content)
 local quickTop=height-PAD-24
 place(self.progressStage,self.content,PAD,quickTop-44,width-56,18)
 place(self.progressLabel,self.content,panelWidth-PAD-48,quickTop-44,48,18)
 place(self.progressTrack,self.content,PAD,quickTop-20,width,4)
 place(self.quickBar,self.content,PAD,quickTop,width,24)
 local half=(width-12)/2
 place(self.quickSave,self.quickBar,0,0,half,24)
 place(self.quickLoad,self.quickBar,half+12,0,half,24)
 local maxNewTop=quickTop-80
 local newTop=model.isEditor and maxNewTop or math.min(bodyTop+#model.rows*ROW_HEIGHT+8,maxNewTop)
 place(self.newButton,self.content,PAD,newTop,width,28)
 local bodyBottom=newTop-8
 if model.isEditor then
  place(self.footer,self.content,PAD,newTop-76,width,64)
  place(self.saveButton,self.footer,0,0,half,28);place(self.cancelButton,self.footer,half+12,0,half,28)
  place(self.saveAndApplyButton,self.footer,0,36,width,28)
  bodyBottom=newTop-88
 end
 for _,scroll in ipairs({self.list,self.editorScroll})do
  scroll:ClearAnchors();scroll:SetAnchor(TOPLEFT,self.content,TOPLEFT,PAD,bodyTop)
  scroll:SetAnchor(BOTTOMRIGHT,self.content,TOPLEFT,panelWidth-PAD,math.max(bodyTop+1,bodyBottom))
 end
 local y=0
 local function full(control,gap,height)
  if control:IsHidden()then return end
  place(control,self.editor,0,y,bodyWidth,height)
  y=y+(height or textHeight(control))+(gap or 12)
 end
 full(self.nameButton,8,28);self.nameLabel:SetWidth(bodyWidth-20)
 if not self.allButton:IsHidden()then
  local half=(bodyWidth-8)/2
  place(self.allButton,self.editor,0,y,half,28);place(self.noneButton,self.editor,half+8,y,half,28);y=y+40
 end
 if not self.attributesCheck:IsHidden()then
  place(self.attributesCheck,self.editor,0,y,20,20)
  if self.attributesCheck.label then self.attributesCheck.label:SetWidth(bodyWidth-25)end
  y=y+32
 end
 full(self.ghostButton,12,28)
 for _,row in ipairs(self.repairRows or {})do
  full(row,10,82);row.title:SetWidth(bodyWidth);row.reason:SetWidth(bodyWidth);row.action:SetWidth(bodyWidth)
 end
 full(self.resumeButton,12,28)
 full(self.recoverButton,8,28);full(self.partialButton,8,28);full(self.keepButton,8,28)
 self.editor:SetDimensions(bodyWidth,math.max(1,y))
 for _,row in ipairs(self.rows)do
  row:SetWidth(bodyWidth)
  local badgeWidth=row.row and #row.row.missing>0 and 70 or 0
  place(row.title,row,28,5,bodyWidth-32-badgeWidth)
  place(row.badge,row,bodyWidth-70,8,70)
  place(row.tick,row,4,8,20,20)
  place(row.highlight,row,0,0,bodyWidth,ROW_HEIGHT)
  row.badge:SetMaxLineCount(1);row.badge:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
 end
 self.listChild:SetDimensions(bodyWidth,math.max(1,#model.rows*ROW_HEIGHT))

end
function Instance:BuildChecks()
 if not KW.SelectionOverlay or not self.overlayPages then return end
 self.overlayUpdate=WINDOW_MANAGER:CreateControl("KanaWardrobeSelectionUpdate",self.content,CT_CONTROL)
 self.overlayUpdate:SetHandler("OnEffectivelyHidden",function()self:ClearSelectionOverlays()end)
 self.overlayUpdate:SetHandler("OnEffectivelyShown",function()
  if self.model then
   local shown=self.visible and not self.content:IsHidden() and (not IsInGamepadPreferredMode or not IsInGamepadPreferredMode())
   self:RenderSelectionOverlays(shown,self.model)
  end
 end)
end
function Instance:ClearSelectionOverlays()
 if self.overlayUpdate then self.overlayUpdate:SetHandler("OnUpdate",nil)end
 for _,overlay in pairs(self.selectionOverlays)do overlay:Destroy()end
 self.selectionOverlays={};self.checks={};self.overlayState=nil
end
function Instance:RefreshSelectionOverlays()
 local state=self.overlayState
 if not state or not self.visible or not self.session:IsEditorActive()then self:ClearSelectionOverlays();return end
 local seen={};self.checks={}
 for _,entry in ipairs(self.overlayPages:GetSelectionIcons(state.page))do
  local parent=entry.parent;seen[parent]=true
  local function resolve()
   local current=self.overlayState
   if not current or current.page~=state.page or self.page~=state.page or not self.visible or not self.session:IsEditorActive()then return nil end
   local data=entry.resolveKey();if not data then return nil end
   local domain=data.domain
   if not (current.component=="equipment" and domain=="equipment" or current.component=="abilities" and (domain=="skills"or domain=="bars"))then return nil end
   data.enabled=current.enabled;data.selected=self.session:GetSelected(domain,data.key)
   return data
  end
  local overlay=self.selectionOverlays[parent]
  if not overlay then
   overlay=KW.SelectionOverlay.New(parent,resolve,function(domain,key,selected)
    if domain=="equipment"then self:Command("SetSelected",key,selected)else self:Command("SetSelected",domain,key,selected)end
   end)
   self.selectionOverlays[parent]=overlay
   if state.component=="equipment"then
    overlay.control:SetHandler("OnMouseEnter",function()
     local data=resolve();if data then tooltip(overlay.control,D.SlotName(data.key).."\n"..text("SELECTED_SLOT").."\n"..text("EDIT_HELP"))end
    end)
    overlay.control:SetHandler("OnMouseExit",clearTooltip)
   end
  end
  overlay:Bind(entry.icon,resolve)
  local data=overlay:Refresh()
  if data and data.domain=="equipment"then self.checks[data.key]=overlay.control end
 end
 for parent,overlay in pairs(self.selectionOverlays)do if not seen[parent]then overlay:Destroy();self.selectionOverlays[parent]=nil end end
end
function Instance:RenderSelectionOverlays(shown,model)
 local view=model.view;local component=view.component or "equipment"
 local valid=shown and model.isEditor and not view.paused
  and (component=="equipment" and self.page=="inventory" or component=="abilities" and self.page=="skills")
 if not valid or not self.overlayUpdate or not self.session.GetSelected or not self.session.IsEditorActive then self:ClearSelectionOverlays();return end
 if self.overlayState and (self.overlayState.page~=self.page or self.overlayState.component~=component)then self:ClearSelectionOverlays()end
 self.overlayState={page=self.page,component=component,enabled=view.state=="editing"}
 self:RefreshSelectionOverlays()
 if self.overlayState then
  self.overlayTime=nil
  self.overlayUpdate:SetHandler("OnUpdate",function(_,now)
   if not self.visible or not self.session:IsEditorActive()then self:ClearSelectionOverlays();return end
   if not self.overlayTime or now-self.overlayTime>=.1 then self.overlayTime=now;self:RefreshSelectionOverlays()end
  end)
 end
end
function Instance:SelectAll(selected)
 local view=self.session:GetView()
 if view.component=="attributes"then return self:Command("SetAttributesEnabled",selected)end
 if view.component=="abilities"then
  local a=view.draft and view.draft.abilities or {}
  for key in pairs(a.skills or {})do self.session:SetSelected("skills",key,selected)end
  for _,bar in ipairs({"front","back","werewolf"})do
   for slot in pairs(a.bars and a.bars[bar]or {})do self.session:SetSelected("bars",{bar=bar,slot=slot},selected)end
  end
  return self:Refresh()
 end
 for _,slot in ipairs(KW.Slots.Order)do if not self.session:GetView().missing[slot]then self.session:SetSelected(slot,selected)end end
 self:Refresh()
end
function Instance:Render(model)
 local view=model.view;local shown=self.visible and (not IsInGamepadPreferredMode or not IsInGamepadPreferredMode())
 self.content:SetHidden(not shown)
 if not shown then self.geometryHiddenPage=nil;self:SetBackgroundExpanded(false)end
 self:SetEditorLayout(shown and model.isEditor)
 if model.isEditor or not shown then self:HideDescription()end
 self.list:SetHidden(model.isEditor or view.paused or view.state=="recovery")
 self.editorScroll:SetHidden(not model.isEditor and not view.paused and view.state~="recovery")
 self.closeButton:SetHidden(not model.isEditor)
 self.newButton:SetHidden(false)
 self.newButton:SetEnabled(model.canNew)
 self.quickSave:SetEnabled(model.canQuickSave)
 self.quickLoad:SetEnabled(model.canQuickLoad)
 self.quickSave:SetHandler("OnMouseEnter",function()tooltip(self.quickSave,model.canQuickSave and text("QUICK_SAVE_HELP") or model.reason)end)
 self.quickLoad:SetHandler("OnMouseEnter",function()
  tooltip(self.quickLoad,not model.canQuickSave and model.reason or (model.canQuickLoad and text("QUICK_LOAD_HELP") or text("QUICK_EMPTY")))
 end)
 self.newButton:SetHandler("OnMouseEnter",function()if not model.canNew then tooltip(self.newButton,model.reason)end end)
 self.newButton:SetHandler("OnMouseExit",clearTooltip)
 self.nameLabel:SetText(D.Plain(view.name));self.nameButton:SetEnabled(view.state=="editing" and not view.paused)
 self.saveAndApplyButton:SetEnabled(model.canSaveAndApply);self.saveAndApplyButton:SetHidden(false)
 self.saveButton:SetEnabled(model.canSave);self.cancelButton:SetEnabled(model.canCancel)
 self.allButton:SetEnabled(view.state=="editing" and not view.paused);self.noneButton:SetEnabled(view.state=="editing" and not view.paused)
 self.saveButton:SetHandler("OnMouseEnter",function()tooltip(self.saveButton,model.canSave and text(view.component and "COMPONENT_SAVE_HELP"or"RETURN_NOTE") or model.saveReason)end)
 self.saveButton:SetHandler("OnMouseExit",clearTooltip)
 self.cancelButton:SetHandler("OnMouseEnter",function()tooltip(self.cancelButton,model.canCancel and text(view.component and "COMPONENT_CANCEL_HELP"or"RETURN_NOTE") or model.reason)end)
 self.cancelButton:SetHandler("OnMouseExit",clearTooltip)
 self.saveAndApplyButton:SetHandler("OnMouseEnter",function()tooltip(self.saveAndApplyButton,model.canSaveAndApply and text("SAVE_AND_APPLY_HELP")or model.saveReason)end)
 self.saveAndApplyButton:SetHandler("OnMouseExit",clearTooltip)
 self.attributesCheck:SetHidden(not model.isEditor or view.component~="attributes" or self.page~="stats")
 ZO_CheckButton_SetCheckState(self.attributesCheck,view.attributesEnabled==true)
 ZO_CheckButton_SetEnableState(self.attributesCheck,view.state=="editing" and not view.paused)
 self.ghostButton:SetHidden(view.component=="abilities" or count(view.missing)==0)
 self:RenderRepairs(view)
 self.resumeButton:SetHidden(not view.paused or view.state=="recovery")
 self.recoverButton:SetHidden(view.state~="recovery")
 self.recoverButton:SetText(view.recovery and text("RECOVERY_ACTIONS")or text("RESTORE"))
 self.partialButton:SetHidden(view.recovery~=nil or view.state~="recovery" or count(view.recoveryMissing)==0)
 self.keepButton:SetHidden(view.recovery~=nil or view.state~="recovery")
 self:RenderSelectionOverlays(shown,model)
 self.nameButton:SetHidden(not model.isEditor)
 self.allButton:SetHidden(not model.isEditor or view.component=="attributes")
 self.noneButton:SetHidden(not model.isEditor or view.component=="attributes")
 self.footer:SetHidden(not model.isEditor)
 self:UpdateProgress(view)
 for index,row in ipairs(model.rows)do
  local c=self.rows[index]
  if not c then
   c=WINDOW_MANAGER:CreateControl("KanaWardrobeRow"..index,self.listChild,CT_CONTROL)
   c:SetDimensions(220,ROW_HEIGHT);c:SetMouseEnabled(true)
   c.highlight=WINDOW_MANAGER:CreateControl("KanaWardrobeRow"..index.."Highlight",c,CT_TEXTURE)
   c.highlight:SetTexture("EsoUI/Art/Miscellaneous/listItem_highlight.dds")
   c.highlight:SetTextureCoords(0,1,0,0.625)
   c.highlight:SetDrawLayer(DL_BACKGROUND);c.highlight:SetMouseEnabled(false);c.highlight:SetHidden(true)
   c.tick=WINDOW_MANAGER:CreateControl("KanaWardrobeRow"..index.."Tick",c,CT_TEXTURE)
   c.tick:SetTexture("EsoUI/Art/Miscellaneous/check_icon_32.dds");c.tick:SetMouseEnabled(false)
   c.title=label(c,"KanaWardrobeRow"..index.."Name","",28,5,180,"ZoFontGameBold")
   c.title:SetMouseEnabled(false)
   c.title:SetMaxLineCount(1);c.title:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
   c.badge=label(c,"KanaWardrobeRow"..index.."Badge","",148,5,72,"ZoFontGameSmall")
   self.rows[index]=c
  end
  c.row=row;c:SetHidden(false)
  if c.rowIndex~=index then
   c.rowIndex=index;c:ClearAnchors();c:SetAnchor(TOPLEFT,self.listChild,TOPLEFT,0,(index-1)*ROW_HEIGHT)
  end
  c.title:SetText(row.name);c.badge:SetText(#row.missing>0 and string.format(text("MISSING"),#row.missing)or"")
  c.badge:SetMouseEnabled(false);c.tick:SetHidden(not row.matches)
  c.highlight:SetHidden(not MouseIsOver or not MouseIsOver(c))
  c:SetHandler("OnMouseUp",function(_,mouseButton,inside)if inside then self:RowClick(row.id,mouseButton)end end)
  c:SetHandler("OnMouseEnter",function()c.highlight:SetHidden(false);self:Hover(row,c)end)
  c:SetHandler("OnMouseExit",function()c.highlight:SetHidden(true);self:Leave()end)
 end
 for index=#model.rows+1,#self.rows do self.rows[index]:SetHidden(true)end
 self:LayoutPanel()
 self:LayoutContent(model)
 self:RefreshConfirmation(shown,view)
 self:RefreshToggles()
end
function Instance:RetireConfirmation()
 local token=self.confirmationToken
 self.confirmationToken=nil;self.confirmationKey=nil
 if token then D.Retire(token.dialog)end
end
function Instance:RefreshConfirmation(shown,view)
 local eligible=shown and view.state=="confirming" and not view.paused and view.confirmation
 local key=eligible and view.confirmation.plan.extraKey
 if self.confirmationToken and (not eligible or self.confirmationToken.key~=key)then self:RetireConfirmation()end
 if not eligible or self.confirmationToken then return end
 local token={key=key};self.confirmationToken=token;self.confirmationKey=key
 local function choose(method)
  if self.confirmationToken~=token then return end
  -- ESO invokes the button callback before releasing its modal. Defer session
  -- changes until after release so a refreshed plan cannot queue a stale copy.
  local function dispatch()
   if self.confirmationToken~=token then return end
   local current=self.session:GetView()
   if not self.visible or current.state~="confirming" or current.paused or not current.confirmation
    or current.confirmation.plan.extraKey~=key then self:RetireConfirmation();self:Refresh();return end
   self.confirmationToken=nil;self.confirmationKey=nil
   self:Command(method,key)
  end
  if zo_callLater then zo_callLater(dispatch,0)else dispatch()end
 end
 token.dialog=D.ConfirmExtras(view.confirmation.plan,view.confirmation.presetName,
  function()choose("Confirm")end,function()choose("RejectConfirmation")end)
end
function Instance:RegisterHideToggle(parent,context,filters)
 if not WINDOW_MANAGER or not parent then return end
 local existing=self.toggles[parent]
 if not existing then
  local c=WINDOW_MANAGER:CreateControlFromVirtual("KanaWardrobeHide"..tostring(count(self.toggles)+1),parent,"ZO_CheckButton")
  c:SetDimensions(20,20);ZO_CheckButton_SetLabelText(c,"")
  existing={control=c,contexts={},filters=filters};self.toggles[parent]=existing
  ZO_CheckButton_SetToggleFunction(c,function(_,checked)filters:SetEnabled(checked);self:RefreshToggles()end)
  c:SetHandler("OnMouseEnter",function()
   local value=existing.label or text("HIDE_ITEMS")
   if filters:IsBypassed()then value=value.."\n"..text("HIDE_BYPASS")end
   tooltip(c,value)
  end)
  c:SetHandler("OnMouseExit",clearTooltip)
  c:SetHandler("OnEffectivelyShown",function()self:RefreshToggles()end)
  c:SetHandler("OnEffectivelyHidden",function()self:LayoutToggle(existing,false)end)
 end
 existing.contexts[context]=true
 for _,definition in ipairs(filters:GetContexts())do
  if definition.context==context then existing.list=definition.list or existing.list end
 end
 self:RefreshToggles();return existing.control
end
function Instance:LayoutToggle(entry,active)
 local list=entry.list
 if not list or not list.GetNumAnchors then return end
 -- Native InfoBar occupies 64 units below the list (capacity and currencies).
 -- Put our toggle beneath it; never resize/reanchor the item viewport.
 if active then
  entry.control:ClearAnchors();entry.control:SetAnchor(TOPLEFT,list,BOTTOMLEFT,8,72)
 end
 if active and entry.control.label then
  local label=entry.control.label
  label:SetWidth(math.max(1,list:GetWidth()/scale(list)-48))
  label:SetMaxLineCount(1);label:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
 end
end
function Instance:RefreshToggles()
 for _,entry in pairs(self.toggles)do
  local active
  for _,context in ipairs(entry.filters:GetContexts())do if context.active and entry.contexts[context.context]then active=context.context;break end end
  entry.control:SetHidden(not active)
  self:LayoutToggle(entry,active~=nil)
  if active then
   entry.label=string.format(text("HIDE_ITEMS"),entry.filters:HiddenCount(active))
   ZO_CheckButton_SetLabelText(entry.control,entry.label)
   ZO_CheckButton_SetCheckState(entry.control,entry.filters:IsEnabled())
   ZO_CheckButton_SetEnableState(entry.control,not entry.filters:IsBypassed())
  end
 end
end
