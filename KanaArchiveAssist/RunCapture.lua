local K=KanaArchiveAssist;local C=K.Config
local R={};K.RunCapture=R
function R.New(onObservation,clock,nextId,onState)
 return setmetatable({onObservation=onObservation,clock=clock or os.time,nextId=nextId,onState=onState,serial=0,status={state='idle'}},{__index=R})
end
function R:SetStatus(state,profile,reason)
 self.status={state=state,profileId=profile,reason=reason}
 if self.onState then self.onState(self.status)end
end
function R:CheckTimeout()
 local p=self.pending
 if p and self.clock()-p.at>30 then self.pending=nil;self:SetStatus('failed',p.profileId,'timeout');return true end
 return false
end
function R:Open(offer)
 if not C.ValidOffer(offer) then self:Invalidate('invalid_offer');return false end
 if not self.offer or self.offer.offerId~=offer.offerId then
  if self.pending then self:SetStatus('failed',self.pending.profileId,'offer_replaced')end
  self.pending=nil;self.excluded=false
 end
 self.offer=C.Copy(offer)
 if not self.pending then self:SetStatus(self.excluded and 'excluded_offer' or 'offered')end
 return true
end
function R:IsExcluded(offerId)
 return self.offer~=nil and self.offer.offerId==offerId and self.excluded==true
end
function R:SetExcluded(offerId,excluded)
 if not self.offer or self.pending or self.offer.offerId~=offerId then return false end
 self.excluded=excluded==true;self:SetStatus(self.excluded and 'excluded_offer' or 'offered');return true
end
function R:Confirm(selected,profile,previous)
 if not self.offer or self.pending then return false end
 local found=false;for _,id in ipairs(self.offer.options)do if id==selected then found=true end end
 if not found then self:SetStatus('failed',profile,'invalid_selection');return false end
 self.serial=self.serial+1
 self.pending={offer=C.Copy(self.offer),selectedId=selected,profileId=profile,excluded=self.excluded==true,previous=previous,at=self.clock(),id=self.nextId and self.nextId() or self.offer.runId..':'..self.serial}
 self:SetStatus('pending',profile)
 return true
end
function R:ApplyResult(buffType,id,count,previous,suppressed)
 local p=self.pending;if not p then return false end
 if self:CheckTimeout()then return false end
 if buffType~=p.offer.buffType then return false end
 self.pending=nil
 if suppressed or id~=p.selectedId or previous~=p.previous or count~=previous+1 then self:SetStatus('failed',p.profileId,suppressed and 'restored_result' or 'mismatched_result');return false end
 if p.excluded then self:SetStatus('excluded',p.profileId);return false,true end
 local o=C.Copy(p.offer);o.schemaVersion=1;o.observationId=p.id;o.profileId=p.profileId;o.selectedId=id;o.offerId=nil
 if self.onObservation(o)==false then self:SetStatus('failed',p.profileId,'history_rejected');return false,true end
 self:SetStatus('recorded',p.profileId);return true,true
end
function R:Invalidate(reason)
 if self.pending then self:SetStatus('failed',self.pending.profileId,reason or 'interrupted')else self:SetStatus('idle')end
 self.offer=nil;self.pending=nil;self.excluded=false
end
function R:Hide() end -- Server acknowledgement may arrive after the scene closes.
