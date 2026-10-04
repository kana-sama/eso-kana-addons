TestSupport.PerformanceHarness={}
function TestSupport.PerformanceHarness.Load()
    for _,path in ipairs({'integration/EsoApi.lua','localization/en.lua','localization/ru.lua','catalog/data/Families.lua','catalog/data/Categories.lua','catalog/Selectors.lua','catalog/Catalog.lua','model/Schema.lua','effects/History.lua','effects/Store.lua','effects/Sources.lua','rules/Rules.lua','widgets/Projector.lua','widgets/Layout.lua','integration/Anchors.lua','ui/Timers.lua','ui/Controls.lua','ui/FontMetrics.lua','ui/Renderer.lua','Runtime.lua','dev/Diagnostics.lua','dev/Replay.lua'}) do
        local f=io.open(TEST_ROOT..'/'..path); if f then f:close(); dofile(TEST_ROOT..'/'..path) end
    end
end
function TestSupport.PerformanceHarness.New(profile)
    local clock=TestSupport.FakeClock.New(10); local api=TestSupport.FakeApi.New(clock); local native=TestSupport.NativeRecording.New({directVisibility=true})
    api.controls=native.controls; api.fonts=native.fonts; api.CreateFont=native.CreateFont; api.GetStringWidthScaled=native.GetStringWidthScaled; api.GetUIGlobalScale=native.GetUIGlobalScale
    for k,v in pairs(native.constants) do api.constants[k]=v end
    for k,v in pairs({EVENT_EFFECT_CHANGED=1,REGISTER_FILTER_UNIT_TAG=2,EVENT_RETICLE_TARGET_CHANGED=3,EVENT_BOSSES_CHANGED=4,EFFECT_RESULT_GAINED=5,EFFECT_RESULT_UPDATED=6,BUFF_EFFECT_TYPE_BUFF=7,EVENT_EFFECTS_FULL_UPDATE=8}) do api.constants[k]=v end
    api.GetAPIVersion=function() return 101051 end; api.DoesAbilityExist=function() return true end
    api.GetAbilityName=function(id,caster) return 'Native '..id..':'..tostring(caster) end; api.GetAbilityIcon=function(id) return id..'.dds' end
    api.units.player={name='Player'}
    local d=assert(KanaEffects.Diagnostics,'missing diagnostics instrumentation').New(api)
    local catalog=KanaEffects.Catalog.New(api,nil,d); local store=KanaEffects.Store.New(); local history=KanaEffects.History.New()
    local sources=KanaEffects.Sources.New(api,catalog,store,history,d)
    local controls=KanaEffects.Controls.New(api); local metrics=KanaEffects.FontMetrics.New(controls); local timers=KanaEffects.Timers.New(clock)
    local renderer=KanaEffects.Renderer.New(api.controls.GuiRoot,controls,timers,d)
    local queue={}; local function defer(fn) local t={fn=fn}; queue[#queue+1]=t; return function() t.cancelled=true end end
    local runtime=KanaEffects.Runtime.New({schema=KanaEffects.Schema,catalog=catalog,store=store,sources=sources,rules=KanaEffects.Rules,projector=KanaEffects.Projector,layout=KanaEffects.Layout,renderer=renderer,anchors=KanaEffects.Anchors.New(api),fontMetrics=metrics,clock=clock,historyUnitTags={player=true,reticleover=true,boss1=true},defer=defer,diagnostics=d})
    local function flush() local q=queue; queue={}; for _,v in ipairs(q) do if not v.cancelled then v.fn() end end end
    local c={api=api,native=native,clock=clock,diagnostics=d,catalog=catalog,store=store,history=history,sources=sources,controls=controls,renderer=renderer,timers=timers,runtime=runtime,flush=flush}
    c.profile=profile or TestSupport.Fixtures.Profile(); runtime:Start(c.profile); flush()
    function c:Event(id,slot,ending) api:Emit(1,6,slot or 1,'Effect '..id,'player',10,ending or 70,1,id..'.dds','',7,0,0,'Player',7,id,99) end
    function c:Tick(time) clock:Set(time); local jobs={}; for _,job in pairs(api.updates) do jobs[#jobs+1]=job.callback end; for _,fn in ipairs(jobs) do fn() end; flush() end
    return c
end
function TestSupport.PerformanceHarness.Profiler(frames)
    local api={constants={SCRIPT_PROFILER_RECORD_DATA_TYPE_CLOSURE=1},time=0,updates={},frames=frames,reads=0,closureReads=0}
    api.Now=function() return api.time end
    api.IsScriptProfilerEnabled=function() return api.enabled==true end
    api.StartScriptProfiler=function() api.starts=(api.starts or 0)+1; api.enabled=true end
    api.StopScriptProfiler=function() api.stops=(api.stops or 0)+1; api.enabled=false end
    api.GetScriptProfilerNumFrames=function() return #api.frames end
    api.GetScriptProfilerFrameNumRecords=function(f) return #api.frames[f] end
    api.GetScriptProfilerRecordInfo=function(f,r) api.reads=api.reads+1; return unpack(api.frames[f][r],1,5) end
    api.GetScriptProfilerClosureInfo=function(id) api.closureReads=api.closureReads+1; return 'closure',id==1 and 'user:/AddOns/eso-kana-addons/KanaEffects/Runtime.lua' or 'user:/AddOns/Other/Runtime.lua',1 end
    api.eventManager={RegisterForUpdate=function(_,name,_,fn) api.updates[name]=fn end,UnregisterForUpdate=function(_,name) api.updates[name]=nil end}
    function api:Tick(time) self.time=time; local jobs={}; for _,fn in pairs(self.updates) do jobs[#jobs+1]=fn end; for _,fn in ipairs(jobs) do fn() end end
    return api
end
