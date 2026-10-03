-- Native-shaped keyboard Stats state, attached independently of skill fixtures.
local Attributes={}
function Attributes.Attach(f)
 local api=f.api
 api.ATTRIBUTE_HEALTH=1;api.ATTRIBUTE_MAGICKA=2;api.ATTRIBUTE_STAMINA=3
 api.ATTRIBUTE_POINT_ALLOCATION_MODE_PURCHASE_ONLY=0;api.ATTRIBUTE_POINT_ALLOCATION_MODE_FULL=1;api.RESPEC_PAYMENT_TYPE_GOLD=0;api.RESPEC_RESULT_SUCCESS=0
 f.actualAttributes={10,20,34};f.attributeUnspent=2;f.attributeLog={};f.attributeSends=0
 api.GetAttributeSpentPoints=function(id)return f.actualAttributes[id]end
 api.GetAttributeUnspentPoints=function()return f.attributeUnspent end
 api.GetAttributeRespecCastTimeRemainingMs=function()return f.attributeCast or 0 end
 local stats={initialized=true,attributeControls={},mode=0,payment=9,available=2}
 api.STATS=stats
 function stats:GetAttributePointAllocationMode()return self.mode end
 function stats:SetAttributePointAllocationMode(mode)self.mode=mode;f.attributeLog[#f.attributeLog+1]={'mode',mode}end
 function stats:GetAttributeRespecPaymentType()return self.payment end
 function stats:SetAttributeRespecPaymentType(payment)self.payment=payment end
 function stats:GetAvailablePoints()return self.available end
 function stats:SpendAvailablePoints(delta)self.available=self.available-delta end
 function stats:DoesAttributePointAllocationModeBatchSave()return self.mode~=0 end
 function stats:PurchaseAttributes()error('native PurchaseAttributes forbidden')end
 for id=1,3 do
  local spinner={points=f.actualAttributes[id],addedPoints=0,pointsSpinner={callbacks={},value=f.actualAttributes[id]}}
  function spinner:GetPoints()return self.points end
  function spinner:GetAllocatedPoints()return self.addedPoints end
  function spinner:SetAddedPointsByTotalPoints(total)
   local delta=total-self.points
   if not stats:DoesAttributePointAllocationModeBatchSave()then delta=math.max(delta,0)end
   local diff=delta-self.addedPoints
   if diff>stats.available then diff=stats.available;delta=self.addedPoints+diff end
   self.addedPoints=delta;stats:SpendAvailablePoints(diff);f.attributeLog[#f.attributeLog+1]={'set',id,total}
  end
  function spinner:ResetAddedPoints()self.addedPoints=0;self.points=f.actualAttributes[id];self.pointsSpinner.value=self.points end
  local points=spinner.pointsSpinner
  function points:RegisterCallback(event,fn)self.callbacks[fn]=event end
  function points:UnregisterCallback(event,fn)self.callbacks[fn]=nil end
  function points:Change(total)
   spinner:SetAddedPointsByTotalPoints(total);self.value=spinner.points+spinner.addedPoints
   for fn in pairs(self.callbacks)do fn(total)end
  end
  stats.attributeControls[id]={pointLimitedSpinner=spinner}
 end
 function stats:UpdateSpendablePoints()
  local total=0
  for id=1,3 do
   local spinner=self.attributeControls[id].pointLimitedSpinner
   if self.resetAddedPoints then spinner:ResetAddedPoints()end
   spinner.points=f.actualAttributes[id];spinner.pointsSpinner.value=spinner.points+spinner.addedPoints;total=total+spinner.addedPoints
  end
  self.resetAddedPoints=false;self.available=f.attributeUnspent-total
 end
 function f:ResetAttributesNative()
  for _,control in ipairs(stats.attributeControls)do control.pointLimitedSpinner:ResetAddedPoints()end
  stats.available=f.attributeUnspent;stats.mode=0
 end
 api.SendAttributePointAllocationRequest=function(payment,h,m,s)
  f.attributeSends=f.attributeSends+1;f:Request('attributes',{payment=payment,health=h,magicka=m,stamina=s})
 end
 return f
end
return Attributes
