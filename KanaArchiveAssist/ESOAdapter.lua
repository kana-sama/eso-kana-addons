local K=KanaArchiveAssist;local C=K.Config
local A={};K.ESOAdapter=A
function A:Trace(event,...)
 if not C.debugCapture then return end
 K.captureTrace=K.captureTrace or {};local log=K.captureTrace
 log[#log+1]={time=self.api.GetFrameTimeSeconds(),event=event,args={...}}
 if #log>128 then table.remove(log,1)end
end
function A:RunId()
 local ch=self.profiles.character
 if not ch.run or ch.run.ended then
  ch.runSerial=(ch.runSerial or 0)+1
  ch.run={id=tostring(self.profiles.characterId or 'character')..':'..ch.runSerial,ended=false}
 end
 return ch.run.id
end
function A:Initialized()self:Trace('initialized');if self.api.IsEndlessDungeonStarted()then self:RunId()end;self:Presence()end
function A:Started(explicit)
 self:Trace('started',explicit)
 if explicit and self.profiles.character.run and not self.profiles.character.run.ended then self.profiles.character.run.ended=true end
 self:RunId();self.capture:Invalidate();self.offer=nil;self.onOfferChanged(nil);self:Presence()
end
function A:Completed()
 self:Trace('completed')
 if self.profiles.character.run then self.profiles.character.run.ended=true end
 self.capture:Invalidate();self.offer=nil;self.onOfferChanged(nil)
end
function A:Presence()
 local inside=self.api.IsInstanceEndlessDungeon()
 if inside and not self.inside then
  self:RunId();if self.onEnter then self.onEnter()end
 end
 self.inside=inside
 if not inside then self.capture:Invalidate();self.onOfferChanged(nil)end
end
function A:Reject(reason)
 self:Trace('reject',reason);self.capture:Invalidate(reason);self.offer=nil
 self.capture:SetStatus('failed',self.profiles:GetActive().id,reason);self.onOfferChanged(nil)
end
function A:Refresh()
 local a=self.api;local selector=a.ENDLESS_DUNGEON_BUFF_SELECTOR_KEYBOARD
 -- Scene SHOWING runs before its fragment unhides the selector control.
 if a.IsInGamepadPreferredMode()or not selector:IsShowing()or selector.isRerolling or not a.IsInstanceEndlessDungeon()then self.onOfferChanged(nil);return end
 local options,buffType={},nil
 for bucket=a.ENDLESS_DUNGEON_BUFF_BUCKET_TYPE_ITERATION_BEGIN,a.ENDLESS_DUNGEON_BUFF_BUCKET_TYPE_ITERATION_END do
  local id=a.GetEndlessDungeonBuffSelectorBucketTypeChoice(bucket)
  if id and id>0 then
   local t=a.GetAbilityEndlessDungeonBuffType(id);if buffType and t~=buffType then self:Reject('invalid_offer');return end
   buffType=t;options[#options+1]=id
  end
 end
 local visions={};for id,count in pairs(a.ENDLESS_DUNGEON_MANAGER:GetAbilityStackCountTable(a.ENDLESS_DUNGEON_BUFF_TYPE_VISION)or {})do if count>0 then visions[#visions+1]={id,count}end end
 table.sort(visions,function(x,y)return x[1]<y[1]end)
 local stage,cycle,arc=a.ENDLESS_DUNGEON_MANAGER:GetProgression()
 local o={runId=self:RunId(),buffType=buffType,options=options,context={visions=visions,stage=stage,cycle=cycle,arc=arc},timestamp=a.GetTimeStamp()}
 if not C.ValidOffer(o)then self:Reject('invalid_offer');return end
 local key=C.OfferKey(o)
 if not self.offer or C.OfferKey(self.offer)~=key then self.serial=self.serial+1;o.offerId=o.runId..':'..self.serial;self.offer=o else o=self.offer end
 self:Trace('offer',o.offerId,o.buffType);self.capture:Open(o);self.onOfferChanged(C.Copy(o))
end
function A.Install(api,capture,profiles,onOfferChanged,onEnter)
 local self=setmetatable({api=api,capture=capture,profiles=profiles,onOfferChanged=onOfferChanged,onEnter=onEnter,serial=0},{__index=A})
 local selector=api.ENDLESS_DUNGEON_BUFF_SELECTOR_KEYBOARD
 api.SecurePostHook(selector,'OnShowing',function()self:Refresh()end)
 api.SecurePostHook(selector,'RefreshBuffs',function()self:Refresh()end)
 api.SecurePostHook(selector,'SetIsRerolling',function(_,rerolling)if rerolling then self:Trace('reroll');capture:Invalidate();self.offer=nil;onOfferChanged(nil)end end)
 api.SecurePostHook(selector,'OnHiding',function()self:Trace('hide');capture:Hide();onOfferChanged(nil)end)
 api.ZO_PreHook(selector,'CommitChoice',function(object)
  if api.IsInGamepadPreferredMode()then return end
  local buff=object.selectedBuffControl;if not buff then return end
  if not self.offer or not capture.offer then capture:SetStatus('failed',profiles:GetActive().id,'offer_missing');return end
  local stacks=api.ENDLESS_DUNGEON_MANAGER:GetAbilityStackCountTable(self.offer.buffType)or {}
  self:Trace('confirm',buff.abilityId,profiles:GetActive().id,capture:IsExcluded(self.offer.offerId))
  capture:Confirm(buff.abilityId,profiles:GetActive().id,stacks[buff.abilityId]or 0)
  onOfferChanged(nil)
 end)
 api.ENDLESS_DUNGEON_MANAGER:RegisterCallback('BuffStackCountChanged',function(t,id,count,old,suppress)
  self:Trace('result',t,id,count,old,suppress)
  local _,matched=capture:ApplyResult(t,id,count,old,suppress)
  if matched then self.offer=nil;onOfferChanged(nil)
  elseif selector:IsShowing()then self:Refresh()end
 end)
 local function event(id,fn)api.EVENT_MANAGER:UnregisterForEvent('KanaArchiveAssist',id);api.EVENT_MANAGER:RegisterForEvent('KanaArchiveAssist',id,fn)end
 event(api.EVENT_ENDLESS_DUNGEON_INITIALIZED,function()self:Initialized()end)
 event(api.EVENT_ENDLESS_DUNGEON_STARTED,function()self:Started(true)end)
 event(api.EVENT_ENDLESS_DUNGEON_COMPLETED,function()self:Completed()end)
 event(api.EVENT_PLAYER_ACTIVATED,function()self:Presence()end)
 event(api.EVENT_GAMEPAD_PREFERRED_MODE_CHANGED,function()if api.IsInGamepadPreferredMode()then capture:Invalidate();onOfferChanged(nil)else self:Refresh()end end)
 self:Presence();return self
end
