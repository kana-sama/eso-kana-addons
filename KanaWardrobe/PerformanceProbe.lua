local KW=KanaWardrobe
local Probe={};KW.PerformanceProbe=Probe
local Instance={};Instance.__index=Instance
local unpack=unpack or table.unpack
local function pack(...)return {n=select('#',...),...}end
function Probe.New(api,saved,show)
 return setmetatable({api=api,saved=saved,show=show},Instance)
end
-- Only addon-owned methods are observed. Native secure functions and controls
-- are never wrapped. Outside the short page-opening window this is a tail call.
function Instance:Watch(owner,method,name)
 local original=owner and owner[method]
 if type(original)~='function'then return end
 owner[method]=function(...)
  local sample=self.sample
  if not sample then return original(...)end
  local parent=sample.frame;local frame={children=0};sample.frame=frame
  local started=self.api.GetGameTimeMilliseconds()
  local result=pack(pcall(original,...))
  local elapsed=math.max(0,self.api.GetGameTimeMilliseconds()-started)
  sample.frame=parent
  if parent then parent.children=parent.children+elapsed else sample.own=sample.own+elapsed end
  local row=sample.rows[name]or {calls=0,self=0,total=0,max=0};sample.rows[name]=row
  row.calls=row.calls+1;row.self=row.self+math.max(0,elapsed-frame.children)
  row.total=row.total+elapsed;row.max=math.max(row.max,elapsed)
  if not result[1]then error(result[2],0)end
  return unpack(result,2,result.n)
 end
end
function Instance:Begin(page)
 local sample={page=page,started=self.api.GetGameTimeMilliseconds(),own=0,rows={}}
 self.sample=sample
 self.api.zo_callLater(function()
  if self.sample~=sample then return end
  self.sample=nil
  local elapsed=self.api.GetGameTimeMilliseconds()-sample.started
  local rows={};for name,row in pairs(sample.rows)do row.name=name;rows[#rows+1]=row end
  table.sort(rows,function(a,b)if a.self~=b.self then return a.self>b.self end;return a.name<b.name end)
  local lines={'KanaWardrobe page timing','page='..page,'window='..elapsed..'ms (includes 250ms observation delay)','own='..sample.own..'ms'}
  for _,r in ipairs(rows)do
   lines[#lines+1]=string.format('%s: calls=%d self=%dms total=%dms max=%dms',r.name,r.calls,r.self,r.total,r.max)
  end
  local report=table.concat(lines,'\n');self.saved.performanceReport=report
  -- Keep /kw perf available without opening a modal during scene transitions
  -- or a preset application. Timing is not a failure report.
 end,250)
end
function Probe.Attach(runtime)
 local api=runtime.api
 if type(api.GetGameTimeMilliseconds)~='function'or type(api.zo_callLater)~='function'then return end
 local probe=Probe.New(api,runtime.repo.character,function(report)KW.ProbeReport.Show(report)end)
 runtime.performanceProbe=probe
 local methods={
  ui={'Refresh','Model','Render','LayoutPanel','LayoutContent','Summary','RefreshSelectionOverlays'},
  session={'OnNativePageState','Notify','GetView','RecoveryDetails'},
  inventory={'Capture','Refresh','Resolve','Metadata'},
  protection={'RefreshAccessible'},skills={'Catalogue'},attributes={'Capture'},
  filters={'RecountInventory','CountCandidates','Refresh'},
  pages={'Mount','Bounds','SetBackgroundExpanded','RefreshOwnership'},
  repo={'List','Get'},
 }
 for owner,names in pairs(methods)do for _,method in ipairs(names)do probe:Watch(runtime[owner],method,owner..'.'..method)end end
 probe:Watch(runtime.ui.services,'captureActual','captureDisplay')
 probe:Watch(KW.SkillState,'ReadDisplay','skills.ReadDisplay')
end
