local KW=KanaWardrobe
local O={};KW.OperationSession=O
local M={}
local function domain(component)return component=='abilities' and 'skills' or 'attributes'end
local function add(steps,kind,data)
 data=data or {};data.kind=kind;data.id=kind..':'..(#steps+1);steps[#steps+1]=data
end
local function failure(done,problem)done(nil,problem or KW.Problem('invalidState'))end
function M:Persist()
 self.saved.operationEditor=self.journal and KW.OperationJournal.Plain(self.journal) or nil
 return true
end
function M:Notify()
 self.viewRevision=(self.viewRevision or 0)+1;self:Persist();self.emit('SessionChanged',self:GetView())
end
function M:GetView()
 local j=self.journal;local busy=self.operations and self.operations:IsBusy()
 local editing=j and j.state=='editing' and not (self.operations and self.operations.operation)
 return KW.Copy({state=editing and 'editing' or busy and 'applying' or 'idle',page=j and j.page or self.activePage,
  component=editing and j.component or nil,isEditor=editing==true,name=j and j.name,presetId=j and j.presetId,
  kind=j and j.kind,selection=editing and j.selection or {},selected=editing and j.selection.equipment or {},
  draft=editing and j.experiment,attributesEnabled=editing and j.selection.attributes,
  includedGroups=editing and KW.BuildDraft.IncludedGroups(j.component,j.selection,j.originalPreset,j.clearedGroups),
  missing=editing and j.missing or {},saved=j and j.saveCommitted==true,operation=self.operations and self.operations.operation~=nil})
end
function M:IsEditorActive()return self.journal~=nil and self.journal.state=='editing' and not self.operations.operation end
function M:Editable()
 if not self:IsEditorActive()then return nil,KW.Problem('invalidState')end
 return self.journal
end
function M:IdleRequired()
 if self.operations:IsBusy() or self:IsEditorActive() or self.committing then return nil,KW.Problem('busy')end
 return true
end
function M:StartOperation(intent)
 if self.operations:IsBusy()then self.operations:SetVisible(true);return nil,KW.Problem('operationBusy')end
 intent.capabilities=KW.Copy(self.capabilities)
 -- A new plan inherits unresolved native evidence, including after reload.
 local previous=self.operations.operation
 intent.previous=KW.Copy(intent.previous or {})
 if previous then for _,step in ipairs(previous.steps)do
  local p=step.pending
  if p and p.domain and p.descriptor then intent.previous[p.domain]=KW.Copy(p.descriptor)end
 end end
 return self.operations:Start(intent)
end
function M:Apply(id)
 if self:IsEditorActive()then return nil,KW.Problem('busy')end
 local preset=self.repo:Get(id)
 return self:StartOperation({kind='apply',preset=KW.Copy(preset),presetId=id,name=preset and preset.name})
end
function M:BeginEdit(id,allowMissing,page)
 if self:IsEditorActive()then return nil,KW.Problem('busy')end
 local preset=self.repo:Get(id)
 return self:StartOperation({kind='edit',preset=KW.Copy(preset),presetId=id,name=preset and preset.name,page=page or self.activePage or 'inventory',allowMissing=allowMissing})
end
function M:BeginNew(page)
 if self:IsEditorActive()then return nil,KW.Problem('busy')end
 local name=KW.Text('NEW_PRESET');local i=2
 while self.repo:NameExists(name)do name=KW.Text('NEW_PRESET')..' '..i;i=i+1 end
 return self:StartOperation({kind='new',preset={name=name},name=name,page=page or self.activePage or 'inventory'})
end
function M:EndOperation(kind)
 if not self.journal then return nil,KW.Problem('invalidState')end
 return self:StartOperation({kind=kind,name=self.journal.name,page=self.journal.page})
end
function M:Save()return self:EndOperation('save')end
function M:SaveAndApply()return self:EndOperation('saveApply')end
function M:Cancel()return self:EndOperation('cancel')end
function M:Pause()return self.operations:Pause()end
function M:Resume()return self.operations:Continue()end
function M:CheckLateCompletion()end
function M:OnPlayerActivated()end
function M:OnNativePageState(page,state)
 if state=='showing'then self.activePage=page;self:Notify()end
 -- Native ConfirmHide owns navigation. The operation window remains independent;
 -- leaving a page cannot cancel a sent request or start restoration implicitly.
 if state=='hiding' and self:IsEditorActive() and self.journal.page==page and self.journal.component~='equipment'then
  local j=self.journal;local adapter=self.services[domain(j.component)]
  local api=adapter.api;local native=j.component=='abilities' and api.SKILLS_AND_ACTION_BAR_MANAGER or api.STATS
  local mode=j.component=='abilities' and native:GetSkillPointAllocationMode() or native:GetAttributePointAllocationMode()
  local purchase=j.component=='abilities' and api.SKILL_POINT_ALLOCATION_MODE_PURCHASE_ONLY or api.ATTRIBUTE_POINT_ALLOCATION_MODE_PURCHASE_ONLY
  if mode==purchase then
   local ok,err=adapter:ReleaseAfterNativeExit(j.ownerToken,j.original[j.component])
   if not ok then j.exitProblem=err end
  end
  self:Cancel()
 end
 return true
end
function M:HydrateEditor(j)
 local draft,problem=KW.BuildDraft.New(j.original,j.originalPreset,j.page)
 if not draft then return nil,problem end
 draft.build=KW.Copy(j.experiment);draft.selection=KW.Copy(j.selection);draft.unresolved=j.component=='abilities' and j.missing or nil
 self.journal=j;self.draft=draft;return true
end
function M:SyncDraft()
 local j=self.journal;if not j or not self.draft then return nil,KW.Problem('invalidState')end
 local value,problem
 if j.component=='equipment'then value=self.inventory:Capture('equipment').worn
 else value,problem=self.services[domain(j.component)]:CaptureDraft()end
 if not value then return nil,problem or KW.Problem('nativeDraftUnavailable')end
 local ok;ok,problem=self.draft:Replace(value);if not ok then return nil,problem end
 j.nativeExperiment=KW.Copy(value);j.experiment=self.draft:GetBuild();j.selection=self.draft:GetSelection();return true
end
function M:PrepareEditor(intent,snapshot,catalogue)
 local component=KW.BuildDraft.Component(intent.page)
 local preset=intent.preset
 if not preset then return nil,KW.Problem('presetMissing')end
 local draft,problem=KW.BuildDraft.New(snapshot,preset,intent.page);if not draft then return nil,problem end
 local wanted={[component]=KW.Copy(preset[component] or draft:GetBuild()[component])};local missing={}
 if component=='equipment' and intent.allowMissing then
  for slot,ref in pairs(wanted.equipment)do
   local loc=ref.kind=='item' and snapshot.equipmentState.byUid[ref.uid]
   if ref.kind=='item' and (not loc or loc.bagId~=BAG_WORN and loc.bagId~=BAG_BACKPACK)then missing[slot]=ref;wanted.equipment[slot]={kind='empty'}end
  end
 end
 if component=='abilities' and catalogue then
  local function absent(group,key,ref,skillKey,id)
   local record=catalogue.byKey[skillKey]
   if not record or not record.available then missing[id]={domain=group,key=key,ref=KW.Copy(ref),skillKey=skillKey};return true end
  end
  for key,ref in pairs(wanted.abilities.skills or {})do if absent('skills',key,ref,key,'skill:'..key)then wanted.abilities.skills[key]=nil end end
  for _,bar in ipairs({'front','back','werewolf'})do for slot,ref in pairs(wanted.abilities.bars and wanted.abilities.bars[bar]or {})do
   if ref.kind=='skill' and absent(bar,slot,ref,ref.skillKey,'bar:'..bar..':'..slot)then wanted.abilities.bars[bar][slot]=nil end
  end end
  draft.unresolved=missing
 end
 if component=='abilities'then wanted.abilities=KW.BuildDraft.AbilitiesForEditor(wanted.abilities,catalogue)end
 local raw;raw,problem=self.services.buildPlanner.Build(snapshot,wanted,catalogue,self.capabilities)
 if not raw then return nil,problem end
 local replaced;replaced,problem=draft:Replace(raw.target[component]);if not replaced then return nil,problem end
 local editor={version=2,kind=intent.kind,state='preparingEdit',page=intent.page,component=component,name=preset.name,
  presetId=preset.id,revision=preset.revision,original=KW.Copy(intent.editorBaseline or KW.BuildModel.Normalize(snapshot)),originalPreset=KW.Copy(preset),
  selection=draft:GetSelection(),experiment=draft:GetBuild(),nativeExperiment=KW.Copy(raw.target[component]),missing=missing,saveCommitted=false}
 local result
 if component=='equipment'then result,problem=KW.OperationPlan.Build(snapshot,wanted,self.services,self.capabilities,catalogue)
 else result={steps={},target={},extras={},extraKey=''}end
 if not result then return nil,problem end
 result.context={editor=editor}
 if component~='equipment'then add(result.steps,'mountDraft')end
 add(result.steps,'openEditor');return result
end
function M:CaptureEditorIntent(intent)
 if intent.editor then return KW.Copy(intent.editor)end
 local j=self.journal;if not j then return nil,KW.Problem('invalidState')end
 if intent.kind~='cancel' then
  if not self.draft then
   local ok,problem=self:HydrateEditor(j);if not ok then return nil,problem end
  end
  -- Reload destroys native draft controls, but the editor's last observed values
  -- remain the save goal. Do not replace them with the character's actual build.
  local adapter=j.component~='equipment' and self.services[domain(j.component)]
  local owner=adapter and adapter:GetNativeOwnership()
  if j.component=='equipment' or not self.editorReloaded or owner then
   local ok,problem=self:SyncDraft();if not ok then return nil,problem end
  end
  for slot,entry in pairs(j.missing or {})do
   local selected=j.component=='equipment' and j.selection.equipment[slot]
    or j.component=='abilities' and (entry.domain=='skills' and j.selection.skills[entry.key] or entry.domain~='skills' and j.selection.bars[entry.domain][entry.key])
   if selected then return nil,KW.Problem('unresolvedMissing',{slot=slot})end
  end
  j.selectedBuild=self.draft:GetPresetBuild()
 end
 intent.editor=KW.Copy(j);return KW.Copy(j)
end
function M:PrepareExit(intent,snapshot,catalogue)
 local j=intent.editor;local c=j.component;local steps={};local result={steps=steps,target={},context={editor=KW.Copy(j)}}
 local apply=intent.kind=='saveApply'
 local wanted=c=='equipment' and not apply and {equipment=j.original.equipment}
  or apply and {[c]=j.nativeExperiment or j.experiment[c]} or nil
 if wanted then
  local plan,problem=KW.OperationPlan.Build(snapshot,wanted,self.services,self.capabilities,catalogue)
  if not plan then return nil,problem end
  result.target=plan.target;result.extras=plan.extras;result.extraKey=plan.extraKey;result.following=plan.steps
 end
 if intent.kind~='cancel' then
  local name,problem=KW.Presets.NormalizeName(j.name);if not name then return nil,problem end
  local candidate;candidate,problem=KW.BuildDraft.PresetCandidate(j.originalPreset,c,j.selectedBuild,j.clearedGroups)
  if not candidate or not KW.BuildModel.HasParts(candidate)then return nil,problem or KW.Problem('invalidPreset')end
  candidate.name=name
  local patches={}
  for _,part in ipairs({'equipment','abilities','attributes'})do
   patches[part]=candidate[part] and {op='replace',value=candidate[part]}or {op='remove'}
  end
  if not j.saveCommitted then
   if self.repo:NameExists(name,j.presetId)then return nil,KW.Problem('duplicateName')end
   local current=j.presetId and self.repo:Get(j.presetId)
   if j.presetId and (not current or current.revision~=j.revision)then return nil,KW.Problem('revisionConflict')end
  end
  add(steps,'save',{patches=patches,name=name,candidate=candidate})
 end
 if c~='equipment'then add(steps,'closeDraft')end
 for _,step in ipairs(result.following or {})do steps[#steps+1]=step end;result.following=nil
 add(steps,'finishEditor');return result
end
function M:Calculate(op,report,done)
 local intent=op.intent;local kind=intent.kind;local component
 if kind=='invalid' or kind=='legacy'then return failure(done,KW.Problem('invalidOperation',{legacy=intent.legacy}))end
 local blocked=self.operationSteps:Readiness();if blocked then return failure(done,blocked)end
 if kind=='edit' or kind=='new'then component=KW.BuildDraft.Component(intent.page)
 elseif kind~='apply'then
  local j,problem=self:CaptureEditorIntent(intent);if not j then return failure(done,problem)end
  component=j.component
 end
 local scope=component or intent.preset
 if not scope then return failure(done,KW.Problem('presetMissing'))end
 -- Reconcile only this operation's native evidence. No background recovery scan.
 for _,d in ipairs({'skills','attributes'})do
  local key=d=='skills' and 'abilities' or d
  if scope==key or type(scope)=='table' and scope[key]then
   local ok,problem=self.operationSteps:Reconcile(d,intent.previous and intent.previous[d]);if not ok then return failure(done,problem)end
  end
 end
 local leaving=kind=='save' or kind=='saveApply' or kind=='cancel'
 if not leaving then
  -- A failed editor can be superseded deliberately. Release its owned local
  -- draft before checking foreign changes; never submit it on a new selection.
  if self.journal then
   local ok,problem=self:DiscardOwned();if not ok then return failure(done,problem)end
   self.journal=nil;self.draft=nil;self:Persist()
  end
  local clean,problem=self.services.checkDrafts(scope);if not clean then return failure(done,problem)end
 end
 local snapshot,catalogue,problem=self:CaptureComponent(scope);if not snapshot then return failure(done,problem)end
 local result
 if kind=='apply'then result,problem=KW.OperationPlan.Build(snapshot,intent.preset,self.services,self.capabilities,catalogue)
 elseif kind=='edit' or kind=='new'then result,problem=self:PrepareEditor(intent,snapshot,catalogue)
 else result,problem=self:PrepareExit(intent,snapshot,catalogue)end
 if not result then return failure(done,problem)end
 if result.extras and #result.extras>0 and intent.consent~=result.extraKey then
  return failure(done,KW.Problem('operationConsent',{key=result.extraKey,extras=result.extras}))
 end
 -- Restart recalculates the diff, never the equipment to restore on editor exit.
 if result.context and result.context.editor and (kind=='edit' or kind=='new')then
  intent.editorBaseline=KW.Copy(result.context.editor.original)
 end
 report({phase='calculated',scope=scope,original=KW.BuildModel.Normalize(snapshot),target=result.target})
 done(result)
end
function M:LocalStep(step,op,report,done)
 if step.kind=='diff'then return self:Calculate(op,report,done)end
 local j=self.journal or op.context and op.context.editor
 if not j then return failure(done,KW.Problem('invalidState'))end
 if step.kind=='save'then
  if j.saveCommitted then done({saved=true,id=j.presetId,revision=j.revision,already=true});return end
  local locked,problem=self.protection:EnsureBuild(step.candidate);if not locked then return failure(done,problem)end
  local ok,stored,err=pcall(self.repo.PatchComponents,self.repo,j.presetId,step.patches or {[j.component]=step.patch},step.name,j.revision,function(preset)
   j.presetId=preset.id;j.revision=preset.revision;j.saveCommitted=true;j.commitCandidate=KW.Copy(preset)
   self.journal=j;op.context.editor=KW.Copy(j);op.intent.editor=KW.Copy(j);self:Persist()
   report({saved=true,id=preset.id,revision=preset.revision})
  end)
  if not ok then return failure(done,KW.Problem('commitObserverError',{error=tostring(stored),saveCommitted=j.saveCommitted}))end
  if not stored then return failure(done,err)end
  done({saved=true,id=stored.id,revision=stored.revision})
 elseif step.kind=='mountDraft'then
  local ok,err=self:HydrateEditor(j);if not ok then return failure(done,err)end
  local adapter=self.services[domain(j.component)];local owner=adapter:GetNativeOwnership()
  if owner and owner.phase=='editor' and owner.token==j.ownerToken then done({already=true});return end
  ok,err=adapter:MountDraft(j.nativeExperiment or j.experiment[j.component],function(value,problem)
   if self.journal~=j then return end
   if value then self.draft:Replace(value);j.nativeExperiment=KW.Copy(value);j.experiment=self.draft:GetBuild();j.selection=self.draft:GetSelection()
   else j.problem=problem end
   self:Notify()
  end)
  if not ok then return failure(done,err)end
  j.ownerToken=adapter:GetNativeOwnership().token;self:Persist();op.context.editor=KW.Copy(j)
  done({ownerToken=j.ownerToken})
 elseif step.kind=='openEditor'then
  if j.component~='equipment'then
   local owner=self.services[domain(j.component)]:GetNativeOwnership()
   if not owner or owner.phase~='editor' or owner.token~=j.ownerToken then
    -- A completed mount is local UI state, so reload can invalidate it while
    -- this next step is pending. Restore the draft, never submit its values.
    return self:LocalStep({kind='mountDraft'},op,report,function(result,problem)
     if problem then failure(done,problem)else self:LocalStep(step,op,report,done)end
    end)
   end
  end
  local ok,err=self:HydrateEditor(j);if not ok then return failure(done,err)end
  if j.component=='equipment'then self:SyncDraft()end
  j.state='editing';self.editorReloaded=false;self:Notify();done({editing=true})
 elseif step.kind=='closeDraft'then
  local adapter=self.services[domain(j.component)];local owner=adapter:GetNativeOwnership()
  if owner and owner.phase=='editor' and owner.token~=j.ownerToken then return failure(done,KW.Problem('foreignSkillDraft'))end
  local ok,err=adapter:DiscardDraft();if not ok then return failure(done,err)end
  done({closed=true})
 elseif step.kind=='finishEditor'then
  self.journal=nil;self.draft=nil;self:Persist();done({closed=true})
 else failure(done,KW.Problem('invalidStep',{kind=step.kind}))end
end
function O.Attach(self)
 for name,fn in pairs(M)do self[name]=fn end
 local services=self.services
 local handlers=KW.OperationSteps.New(self.inventory,services.skills,services.attributes,services.events,services.clock,
  {capture=services.capture,localStep=function(...)return self:LocalStep(...)end})
 self.operationSteps=handlers
 self.journal=KW.Copy(self.saved.operationEditor)
 self.editorReloaded=self.journal~=nil
 self.operations=KW.OperationExecutor.New(self.saved,services.clock,handlers,function(view)
  self.emit('OperationChanged',view);self:Notify()
 end,function(op)
  services.clock:Schedule(1,function()
  local ok,err=pcall(self.emit,'SessionFinished',{outcome=op.intent.kind=='apply' and 'applied' or op.intent.kind=='saveApply' and 'applied'
   or op.intent.kind=='save' and 'saved' or op.intent.kind=='cancel' and 'cancelled' or 'editorOpened',saved=op.intent.kind=='save' or op.intent.kind=='saveApply'})
  if not ok then self.saved.operationObserverError=tostring(err)end
  end)
 end,services.describeFailure)
 if self.saved.journal then
  local old=KW.Copy(self.saved.journal);self.saved.legacyOperations=self.saved.legacyOperations or {};self.saved.legacyOperations[#self.saved.legacyOperations+1]=old;self.saved.journal=nil
  if not self.operations.operation then
   local preset=old.kind=='apply' and (old.requested or old.target or old.runTarget)
   if preset and old.version==1 then preset={equipment=preset}end
   self.operations:Start(preset and {kind='apply',preset=preset,name=old.name,previous=old.pending and {[old.pending.domain or (old.phase=='attributes' and 'attributes' or 'skills')]=old.pending}}
    or {kind='legacy',legacy=old,name=old.name})
   self.operations:Pause();self.operations:SetVisible(false)
  end
 end
 if self.journal and not self.operations.operation then
  self:StartOperation({kind='cancel',name=self.journal.name,page=self.journal.page,editor=KW.Copy(self.journal)})
  self.operations:Pause();self.operations:SetVisible(false)
 end
 return self
end
