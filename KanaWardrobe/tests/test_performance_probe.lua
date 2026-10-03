local Fake=dofile(ROOT..'/tests/support/fake_eso.lua')
local function setup()
 local k=Fake.Load({'Core.lua','PerformanceProbe.lua'})
 assert(k.PerformanceProbe,'missing page performance probe')
 local f={now=0,queue={},saved={},shown={}}
 f.api={GetGameTimeMilliseconds=function()return f.now end,zo_callLater=function(cb)f.queue[#f.queue+1]=cb end}
 f.probe=k.PerformanceProbe.New(f.api,f.saved,function(report)f.shown[#f.shown+1]=report end)
 return f
end
return {
 measures_nested_work_once_and_preserves_results_and_errors=function()
  local f=setup();local obj={}
  function obj:Child(value)f.now=f.now+200;return nil,value,false end
  function obj:Parent(value)f.now=f.now+10;local a,b,c=self:Child(value);f.now=f.now+10;return a,b,c end
  function obj:Fail()f.now=f.now+20;error('native failure',0)end
  f.probe:Watch(obj,'Child','child');f.probe:Watch(obj,'Parent','parent');f.probe:Watch(obj,'Fail','fail')
  f.probe:Begin('skills');local a,b,c=obj:Parent(7)
  assert(a==nil and b==7 and c==false)
  local ok,err=pcall(obj.Fail,obj);assert(not ok and err=='native failure')
  f.now=500;f.queue[1]()
  assert(#f.shown==0,'timing must not steal focus from a preset application')
  assert(f.saved.performanceReport:find('own=240ms',1,true),'nested calls counted twice')
  assert(f.saved.performanceReport:find('parent: calls=1 self=20ms total=220ms max=220ms',1,true))
 end,
 fast_pages_stay_quiet_and_scene_switch_cancels_old_report=function()
  local f=setup();local obj={Read=function()f.now=f.now+2 end}
  f.probe:Watch(obj,'Read','read')
  f.probe:Begin('inventory');obj.Read();f.probe:Begin('stats');obj.Read()
  f.now=260;f.queue[1]();assert(not f.saved.performanceReport)
  f.queue[2]();assert(#f.shown==0 and f.saved.performanceReport:find('page=stats',1,true))
  assert(f.saved.performanceReport:find('read: calls=1',1,true))
  local report=f.saved.performanceReport;obj.Read();assert(f.saved.performanceReport==report)
 end,
 report_is_deferred_and_outside_work_is_not_called_addon_time=function()
  local f=setup();f.probe:Begin('inventory');f.now=2300
  assert(#f.shown==0);f.queue[1]()
  assert(#f.shown==0 and f.saved.performanceReport:find('own=0ms',1,true))
 end,
}
