local K=KanaArchiveAssist;local Cfg=K.Config
local C={};K.Controller=C
function C.Install(api,profiles,historyProvider,adapter,view,window)
 local self=setmetatable({api=api,profiles=profiles,view=view or K.View.New(api),histories={},snapshots={},fitFailures={},generation=0,notified={},cache={},cacheOrder={}}, {__index=C})
 self.historyProvider=historyProvider
 self.clock=function()return api.GetGameTimeMilliseconds()end
 self.window=window or K.ProfileWindow.New(api,profiles,function()self:OnProfileChanged()end,function(id)return self:ProfileState(id)end)
 self.settingsPanel=K.ProfileSettings.New(api,self.window)
 self.capture=K.RunCapture.New(function(o)return self:OnObservation(o)end,function()return api.GetFrameTimeSeconds()end,function()
  local ch=profiles.character;ch.attemptSerial=(ch.attemptSerial or 0)+1;return tostring(profiles.characterId)..':'..ch.attemptSerial
 end,function(status)self:OnCaptureState(status)end)
 self.choiceButton=K.ChoiceButton.New(api,self.capture)
 self.adapter=adapter or K.ESOAdapter.Install(api,self.capture,profiles,function(o)self:OnOfferChanged(o)end,function()self:Announce()end)
 api.EVENT_MANAGER:UnregisterForUpdate('KanaArchiveAssistWork')
 api.EVENT_MANAGER:RegisterForUpdate('KanaArchiveAssistWork',0,function()self:Tick()end)
 for _,event in ipairs({api.EVENT_SCREEN_RESIZED,api.EVENT_INTERFACE_SETTING_CHANGED})do
  api.EVENT_MANAGER:UnregisterForEvent('KanaArchiveAssist',event);api.EVENT_MANAGER:RegisterForEvent('KanaArchiveAssist',event,function()self.view:Layout();self.choiceButton:Layout()end)
 end
 return self
end
function C:History(id)
 if self.historyProvider then return self.historyProvider(id)end
 if not self.histories[id]then self.histories[id]=K.History.New(self.profiles.world.profiles[id])end
 return self.histories[id]
end
function C:Announce()self.view:AnnounceProfile(self.profiles:GetActive().name)end
function C:ProfileState(id)
 local profile=self.profiles.world.profiles[id];local run=self.profiles.character.run
 local summary=self:History(id):GetSummary(run and not run.ended and run.id or nil)
 local flow=self.capture and self.capture.status or {state='idle'}
 local owner=flow.profileId or self.profiles:GetActive().id
 if owner~=id or flow.state=='idle'then flow=profile.activity or {state='idle'}end
 return {summary=summary,flow=Cfg.Copy(flow),activity=Cfg.Copy(profile.activity),active=id==self.profiles:GetActive().id}
end
function C:OnCaptureState(status)
 local profile=self.profiles.world.profiles[status.profileId or self.profiles:GetActive().id]
 if status.state=='recorded'or status.state=='excluded'or status.state=='failed'then
  profile.activity=Cfg.Copy(status);profile.activity.at=self.api.GetTimeStamp()
 end
 self.window:RefreshState()
end
function C:OnProfileChanged()
 self:Announce();self:OnOfferChanged(self.offer,true)
end
function C:Unavailable(reason)
 if not self.offer then return end
 local key=self.offer.offerId..':'..self.profiles:GetActive().id
 if not self.notified[key]then self.notified[key]=true;self.view:ReportUnavailable(self.offer.offerId,self.profiles:GetActive().id,reason)end
end
function C:StartFit(profile,buffType)
 local history=self:History(profile.id);local revision=history:GetRevision(buffType);local key=profile.id..':'..buffType
 local snapshot=self.snapshots[key]
 if revision==0 or (snapshot and snapshot.historyRevision==revision)then return end
 local failure=self.fitFailures[key];if failure and failure.revision==revision then return failure.reason end
 if self.fitJob and self.fitKey==key and self.fitRevision==revision then return end
 self.fitJob=K.ChoiceModel.NewFitJob(function(check)return history:BuildDataset(buffType,check)end,snapshot,profile.seed,self.clock)
 self.fitKey=key;self.fitRevision=revision
end
function C:OnOfferChanged(offer,force)
 self.choiceButton:Refresh(offer)
 local profile=self.profiles:GetActive();local key=offer and profile.id..':'..offer.offerId..':'..Cfg.OfferKey(offer)
 if not force and key==self.offerKey then return end
 self.generation=self.generation+1;self.offerKey=key;self.offer=offer;self.supportJob=nil;self.currentPrediction=nil;self.view:Hide()
 if not offer then return end
 local history=self:History(profile.id);local cacheKey=profile.id..':'..offer.buffType
 local snapshot=self.snapshots[cacheKey]
 if not snapshot or snapshot.historyRevision~=history:GetRevision(offer.buffType)then
  if history:GetRevision(offer.buffType)==0 then self:Unavailable('insufficient_history');return end
  local reason=self:StartFit(profile,offer.buffType)
  if not snapshot then self:Unavailable(reason or 'calculating');return end
 end
 self:Request(snapshot)
end
function C:OnObservation(observation)
 observation.recordedAt=self.api.GetTimeStamp();observation.recordedTime=self.api.GetTimeString();observation.recordedDate=self.api.GetDateStringFromTimestamp(observation.recordedAt)
 local history=self:History(observation.profileId)
 if not history:Append(observation)then return false end
 self.window:RefreshState()
 if observation.profileId==self.profiles:GetActive().id and self.offer then self:OnOfferChanged(self.offer,true)end
 return true
end
function C:Request(snapshot)
 if not self.offer then return end
 local key=self.offerKey..':'..snapshot.version
 local cached=self.cache[key]
 if cached then self:Publish(snapshot,cached);return end
 self.supportSnapshot=snapshot;self.supportGeneration=self.generation;self.supportCacheKey=key
 self.supportJob=K.ContextSupport.NewJob(snapshot.dataset,snapshot,self.offer,self.clock)
end
function C:Publish(snapshot,support)
 if not self.offer then return end
 local utilities=K.ChoiceModel.Predict(snapshot,self.offer)
 local result=K.Grades.Rate(self.offer.options,utilities[1],support);result.modelVersion=snapshot.version;self.currentPrediction=result
 local stats=support.stats
 self.view:Show(self.api.ENDLESS_DUNGEON_BUFF_SELECTOR_KEYBOARD,self.offer,result,self.profiles:GetActive().name,stats)
 if not support.supported then self:Unavailable(result.reason)end
end
function C:Tick()
 self.capture:CheckTimeout()
 if not self.fitJob then
  local profile=self.profiles:GetActive()
  for _,buffType in ipairs({self.api.ENDLESS_DUNGEON_BUFF_TYPE_VERSE,self.api.ENDLESS_DUNGEON_BUFF_TYPE_VISION})do
   self:StartFit(profile,buffType);if self.fitJob then break end
  end
 end
 local deadline=self.clock()+Cfg.frameMs
 if self.supportJob then
  local done,result,reason=self.supportJob:Step(deadline)
  if done then
   self.supportJob=nil
   if self.supportGeneration==self.generation and self.offer then
    result=result or {supported=false,byId={},reason=reason or 'numerical_failure'}
    self.cache[self.supportCacheKey]=result;self.cacheOrder[#self.cacheOrder+1]=self.supportCacheKey
    if #self.cacheOrder>32 then self.cache[table.remove(self.cacheOrder,1)]=nil end
    self:Publish(self.supportSnapshot,result)
   end
  end
 end
 if self.clock()>=deadline then return end
 if self.fitJob then
  local done,snapshot,reason=self.fitJob:Step(deadline)
  if done then
   self.fitJob=nil
   if snapshot then
    self.snapshots[self.fitKey]=snapshot
    self.fitFailures[self.fitKey]=nil
   else self.fitFailures[self.fitKey]={revision=self.fitRevision,reason=reason or 'numerical_failure'}end
   if self.offer and self.fitKey==self.profiles:GetActive().id..':'..self.offer.buffType then
    if snapshot then self:Request(snapshot)else self:Unavailable(reason)end
   end
  end
 end
end
