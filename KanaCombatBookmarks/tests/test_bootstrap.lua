local T=dofile('KanaCombatBookmarks/tests/support.lua')
T.load('Names');T.load('Model');T.load('Integration');T.load('LogView')
local makeApi=dofile('KanaCombatBookmarks/tests/ui_support.lua')
local names={'DAMAGE_OUT','DAMAGE_IN','DAMAGE_SELF','HEAL_OUT','HEAL_IN','HEAL_SELF','EFFECTS_IN','EFFECTS_OUT','GROUPEFFECTS_IN','GROUPEFFECTS_OUT','PLAYERSTATS','RESOURCES','MESSAGES','DEATH','PLAYERSTATS_ADVANCED','SKILL_TIMINGS','BOSSHP','PERFORMANCE'}
for i,name in ipairs(names) do _G['LIBCOMBAT_EVENT_'..name]=i+3 end
local modules=KanaCombatBookmarks
local function setup()
    local a=makeApi();a._G=a
    a.KanaCombatBookmarks={Names=modules.Names,Model=modules.Model,Integration=modules.Integration,LogView=modules.LogView}
    a.EVENT_ADD_ON_LOADED=1;a.events={};a.pending={};a.strings={}
    a.EVENT_MANAGER={RegisterForEvent=function(_,name,event,fn)assert(not a.events[event]);a.events[event]=fn end,
        UnregisterForEvent=function(_,name,event)a.events[event]=nil end}
    a.ZO_CreateStringId=function(name,text)a.strings[name]=text end
    a.zo_callLater=function(fn)a.pending[#a.pending+1]=fn end
    function a:flush()local q=self.pending;self.pending={};for _,fn in ipairs(q)do fn()end end
    function a:load()
        local f=assert(io.open('KanaCombatBookmarks/KanaCombatBookmarks.lua'));local source=f:read('*a');f:close()
        setmetatable(self,{__index=_G})
        local chunk
        if setfenv then chunk=assert(loadstring(source));setfenv(chunk,self)else chunk=assert(load(source,'bootstrap','t',self))end
        chunk()
    end
    return a
end
T.test('bootstrap implementation',function() local a=setup();a:load() end)
if T.failed>0 then T.finish()end
T.test('load event, repeated hooks and one release binding invoke one mark',function()
    local a=setup();a:load();local loaded=a.events[1]
    loaded(1,'other');assert(not a.KanaCombatBookmarks.adapter)
    loaded(1,'KanaCombatBookmarks');assert(a.KanaCombatBookmarks.adapter);assert(not a.events[1])
    a:load();assert(not a.events[1]);a.KanaCombatBookmarks.Initialize(a)
    a:start(100000);a.now=112345;a.KanaCombatBookmarks.Mark();T.eq(#a.sounds,1)
    assert(a.strings.SI_BINDING_NAME_KANA_COMBAT_BOOKMARK)
    local f=assert(io.open('KanaCombatBookmarks/Bindings.xml'));local xml=f:read('*a');f:close()
    assert(xml:find('<Up>KanaCombatBookmarks.Mark()</Up>',1,true));assert(not xml:find('<Down>',1,true))
end)
T.test('lazy UI install and deferred finalization refresh',function()
    local a=setup();local update=a.controls.report.Update;a.controls.report.Update=nil
    a:load();a.events[1](1,'KanaCombatBookmarks');assert(not a.KanaCombatBookmarks.view.installed)
    a.controls.report.Update=update;a.controls.report:GetHandler('OnShow')()
    assert(a.KanaCombatBookmarks.view.installed)
    a:start();a.KanaCombatBookmarks.Mark();a:stop(101000)
    a.fight=a:finish(100000,101000);a:flush()
    assert(a.KanaCombatBookmarks.view.active);T.eq(#a.fight.kanaCombatBookmarks.entries,1)
    a.now=101500;a.KanaCombatBookmarks.Mark();a:flush();T.eq(#a.KanaCombatBookmarks.view.rows,2)
end)
T.test('missing UI leaves native code intact; unavailable dependencies fail safely',function()
    local a=setup();a.CombatMetrics_Report=nil;a:load();a.events[1](1,'KanaCombatBookmarks')
    assert(a.KanaCombatBookmarks.adapter);a.controls.panel:Update();T.eq(a.nativeUpdates,1)
    local b=setup();b.CombatMetricsFightData=nil;b:load();b.events[1](1,'KanaCombatBookmarks')
    assert(not b.KanaCombatBookmarks.adapter);assert(not b.KanaCombatBookmarks.Mark());T.eq(#b.sounds,0)
end)
T.finish()
