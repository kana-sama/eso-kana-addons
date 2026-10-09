local Fake=dofile(ROOT..'/tests/support/fake_eso.lua')
local function setup(saved)
 local KW=Fake.Load({'Core.lua','Slots.lua','Inventory.lua','GearProbe.lua'})
 assert(KW.GearProbe,'equipment batch probe is not installed')
 local a=Fake.New();local f={a=a,saved=saved or {},reports={},clock={now=0,tasks={}}}
 function f.clock:NowMs()return self.now end
 function f.clock:Schedule(ms,fn)local h={at=self.now+ms,fn=fn};self.tasks[h]=true;return h end
 function f.clock:Cancel(h)self.tasks[h]=nil end
 function f:Advance(ms)
  local finish=self.clock.now+ms
  while true do
   local next
   for h in pairs(self.clock.tasks)do if h.at<=finish and (not next or h.at<next.at)then next=h end end
   if not next then break end
   self.clock.tasks[next]=nil;self.clock.now=next.at;next.fn()
  end
  self.clock.now=finish
 end
 a.GetBagSize=function()return 4 end
 a.GetAPIVersion=function()return 101051 end
 a.CallSecureProtected=function(name,fromBag,fromSlot,toBag,toSlot,count)
  assert(name=='RequestMoveItem' and count==1)
  assert(f.saved.run and #f.saved.run.items==2,'snapshot must precede native requests')
  a.requests[#a.requests+1]={'move',fromBag,fromSlot,toBag,toSlot}
  if f.throwDispatch then error('native dispatch failed')end
  return true
 end
 a.bags[0][0]={uid='mythic',link='mythic'};a.descriptions.mythic={quality=99}
 a.bags[0][3]={uid='shoulders',link='shoulders'};a.descriptions.shoulders={equipType=4}
 a.bags[0][2]={uid='chest',link='chest'};a.descriptions.chest={equipType=3}
 a.bags[1][1]={uid='occupied',link='occupied'}
 function f:NewProbe()
  return KW.GearProbe.New(a,self.saved,self.clock,KW.Inventory.New(a),function(text)
   self.reports[#self.reports+1]=text
   if self.throwReport then error('report window failed')end
  end,function()return not self.busy end)
 end
 f.p=f:NewProbe()
 function f:Ack(index)
  local r=assert(a.requests[index]);local item=assert(a.bags[r[2]][r[3]])
  assert(not a.bags[r[4]][r[5]],'probe must never overwrite a occupied slot')
  a.bags[r[2]][r[3]]=nil;a.bags[r[4]][r[5]]=item
 end
 return f
end
local tests={}
function tests.gear_probe_batches_two_removals_but_waits_for_both_before_sequential_restore()
 local f=setup();assert(#f.a.requests==0)
 assert(f.p:Run('gearbatch'));assert(#f.a.requests==2)
 local x,y=f.a.requests[1],f.a.requests[2]
 assert(x[1]=='move' and x[2]==0 and x[3]==3 and x[4]==1 and x[5]==0)
 assert(y[1]=='move' and y[2]==0 and y[3]==2 and y[4]==1 and y[5]==2)
 f:Ack(1);f:Advance(100);assert(#f.a.requests==2 and #f.reports==0)
 f:Ack(2);f:Advance(100);assert(#f.a.requests==3)
 assert(f.a.requests[3][1]=='equip' and f.a.requests[3][3]==0 and f.a.requests[3][5]==3)
 f:Ack(3);f:Advance(100);assert(#f.a.requests==4)
 f:Ack(4);f:Advance(100)
 assert(not f.p.active and f.saved.run.removalVerified and f.saved.run.restored)
 assert(f.saved.run.matchesOriginal and #f.reports==1)
 assert(f.saved.latestReport:find('removalVerified=true',1,true))
 assert(f.saved.latestReport:find('restored=true',1,true))
 assert(f.a.bags[0][0].uid=='mythic' and f.a.bags[1][1].uid=='occupied')
end
function tests.gear_probe_timeout_keeps_partial_evidence_and_restore_resolves_new_bag_location()
 local f=setup();assert(f.p:Run('gearbatch'));f:Ack(1);f:Advance(6000)
 assert(not f.p.active and not f.saved.run.removalVerified and not f.saved.run.restored)
 assert(#f.a.requests==2 and #f.reports==1)
 assert(f.saved.latestReport:find('shoulders',1,true) and f.saved.latestReport:find('chest',1,true))
 f.a.bags[1][3]=f.a.bags[1][0];f.a.bags[1][0]=nil
 assert(f.p:Run('gearrestore'));assert(#f.a.requests==3)
 assert(f.a.requests[3][3]==3,'restore must re-resolve UID, not replay reserved slot')
 f:Ack(3);f:Advance(100)
 assert(f.saved.run.restored and not f.saved.run.removalVerified and #f.a.requests==3)
end
function tests.gear_probe_reload_never_replays_requests_and_report_is_available()
 local f=setup();assert(f.p:Run('gearbatch'));f:Ack(1)
 local reloaded=f:NewProbe();assert(#f.a.requests==2 and not reloaded.active)
 assert(reloaded:Run('gearreport'));assert(#f.a.requests==2)
 assert(f.reports[1]:find('interrupted',1,true))
 local ok=reloaded:Run('gearbatch');assert(not ok and #f.a.requests==2,'unfinished snapshot must survive')
end
function tests.gear_probe_restore_refuses_to_displace_an_unrelated_item()
 local f=setup();assert(f.p:Run('gearbatch'));f:Ack(1);f:Ack(2)
 f.a.bags[0][3]={uid='other',link='other'}
 f:Advance(100)
 assert(not f.p.active and #f.a.requests==2 and not f.saved.run.restored)
 assert(f.saved.latestReport:find('other',1,true))
end
function tests.gear_probe_preflight_checks_armor_space_combat_and_session_before_sending()
 for _,scenario in ipairs({'armor','space','combat','busy'})do
  local f=setup()
  if scenario=='armor'then f.a.bags[0][2]=nil
  elseif scenario=='space'then f.a.GetBagSize=function()return 2 end
  elseif scenario=='combat'then f.a.combat=true
  else f.busy=true end
  local ok=f.p:Run('gearbatch');assert(not ok and #f.a.requests==0,scenario)
  assert(#f.reports==1 and #f.saved.latestReport>0)
 end
end
function tests.gear_probe_dispatch_and_report_failures_keep_a_recoverable_snapshot()
 local f=setup();f.throwDispatch=true;f.throwReport=true
 local ok=f.p:Run('gearbatch')
 assert(not ok and not f.p.active and f.saved.run and #f.saved.run.items==2)
 assert(f.saved.latestReport:find('native dispatch failed',1,true))
 assert(f.saved.reportDisplayError:find('report window failed',1,true))
end
return tests
