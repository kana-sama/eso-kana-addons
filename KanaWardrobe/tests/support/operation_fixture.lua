local Fake=dofile(ROOT..'/tests/support/fake_eso.lua')
local BF=dofile(ROOT..'/tests/support/build_fixture.lua')
local AF=dofile(ROOT..'/tests/support/attribute_fixture.lua')
return function(specs)
 local k=Fake.Load({'Core.lua','Slots.lua','lang/en.lua','BuildModel.lua','Presets.lua','Inventory.lua','EquipmentPlan.lua','EquipmentRunner.lua','Protection.lua','SkillState.lua','SkillAdapter.lua','AttributeAdapter.lua','BuildPlanner.lua','BuildDraft.lua','BuildJournal.lua','Session.lua','OperationJournal.lua','OperationExecutor.lua','OperationPlan.lua','OperationSteps.lua','OperationSession.lua'})
 local f=AF.Attach(BF.InstallSkills(BF.New(),specs or {{lineId=10,kind='active',id=51,purchased=true,morph=1}}));BF.InstallSkillDrafts(f)
 f.k=k;f.events=k.Core.NewEvents();f.skills=k.SkillAdapter.New(f.api,f.events,f.clock);f.attributes=k.AttributeAdapter.New(f.api,f.events)
 f.inventory=k.Inventory.New(f.api);f.repo=k.Presets.New({},'EU','a','c','Kana');f.protection=k.Protection.New(f.repo,f.inventory)
 f.api.IsUnitDeadOrReincarnating=function()return false end
 f.api.CanItemBePlayerLocked=function()return true end
 f.api.IsItemPlayerLocked=function(bag,slot)return f.api.bags[bag][slot].locked==true end
 f.api.SetItemIsPlayerLocked=function(bag,slot,value)f.api.bags[bag][slot].locked=value end
 f.services={skills=f.skills,attributes=f.attributes,clock=f.clock,events=f.events}
 f.services.buildPlanner=k.BuildPlanner.New(f.services)
 f.captures={}
 function f.services.capture(scope)
  f.captures[#f.captures+1]=scope or 'all'
  local function has(domain)return scope==nil or scope==domain or type(scope)=='table' and scope[domain]~=nil end
  local s={budgets={}};local c
  if has('equipment')or has('abilities')then local eq=f.inventory:Capture('equipment');s.equipment=k.Copy(eq.worn);s.equipmentState=eq end
  if has('abilities')then c=f.skills:Catalogue();s.abilities=k.Copy(c.abilities);s.budgets.skills=c.budgets.skills;s.budgets.mastery=k.Copy(c.budgets.mastery)end
  if has('attributes')then s.attributes,s.budgets.attributes=f.attributes:Capture()end
  return s,c
 end
 function f:Plan(wanted)local s,c=self.services.capture(wanted);return self.k.OperationPlan.Build(s,wanted,self.services,{},c)end
 function f:AddItem(id,slot,worn,equipType)
  self.api.bags[worn and BAG_WORN or BAG_BACKPACK][slot]={uid=id,link=id}
  self.api.descriptions[id]={equipType=equipType or EQUIP_TYPE_RING}
  return {kind='item',uid=id,link=id}
 end
 function f:AckGear(index)
  local r=self.api.requests[index or #self.api.requests];local bag,slot=r[2],r[3]
  local item=self.api.bags[bag][slot];self.api.bags[bag][slot]=nil
  if r[1]=='equip'then local old=self.api.bags[BAG_WORN][r[5]];self.api.bags[BAG_WORN][r[5]]=item;self.api.bags[bag][slot]=old
  else self.api.bags[BAG_BACKPACK][90+#self.api.requests]=item end
  self.events:Emit('InventoryChanged',{});self:Advance(1)
 end
 return f
end
