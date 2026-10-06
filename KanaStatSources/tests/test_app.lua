local T=dofile('KanaStatSources/tests/support.lua')
local files={};for line in io.lines('KanaStatSources/KanaStatSources.addon')do if line:match('%.lua$')then files[#files+1]=line:gsub('%.lua$','');T.eq(line:find('tests',1,true),nil)end end
local K=T.load(files)
local function api()
    local capture=dofile('KanaStatSources/tests/fixtures/capture.lua')();local a=dofile('KanaStatSources/tests/fixtures/controls.lua')();for k,v in pairs(capture)do if a[k]==nil then a[k]=v end end
    a.EVENT_ADD_ON_LOADED=1;a.EVENT_STATS_UPDATED=2;a.EVENT_SKILLS_FULL_UPDATE=3;a.EVENT_EFFECT_CHANGED=4;a.EVENT_ACTIVE_WEAPON_PAIR_CHANGED=5;a.EVENT_ATTRIBUTE_UPGRADE_UPDATED=6;a.EVENT_CHAMPION_PURCHASE_RESULT=7
    a.EVENT_MANAGER={handlers={},updates={},RegisterForEvent=function(self,_,event,fn)self.handlers[event]=fn end,UnregisterForEvent=function(self,_,event)self.handlers[event]=nil end,RegisterForUpdate=function(self,name,delay,fn)T.eq(delay,100);self.updates[name]=fn end,UnregisterForUpdate=function(self,name)self.updates[name]=nil end};a.SLASH_COMMANDS={};a.messages={};a.d=function(text)a.messages[#a.messages+1]=text end
    return a
end
return {
 hotbar_change_invalidates_context_without_rebuilding_cached_sources=function()
    local a=api();a.EVENT_ACTION_SLOTS_ACTIVE_HOTBAR_UPDATED=8
    local category=0;a.GetActiveHotbarCategory=function()return category end
    local app=K.App.New(a,K.Dump.Storage(a));app:Start()
    a.EVENT_MANAGER.updates[K.name..':refresh']()
    T.eq(app.lastSnapshot.context.hotbarCategory,0)
    local build,gear,generation=app.collector.cache.build,app.collector.cache.equipment,app.collector.generation
    local changed=a.EVENT_MANAGER.handlers[8];T.eq(type(changed),'function')
    changed(8,false,false,0);T.eq(app.collector.generation,generation)
    category=2;changed(8,true,true,2)
    T.eq(app.collector.generation,generation+1)
    app:GetBreakdown('weaponDamage');T.eq(app.lastSnapshot.context.hotbarCategory,2)
    T.eq(app.collector.cache.build,build);T.eq(app.collector.cache.equipment,gear)
 end,
 prewarm_after_start=function()
    local a=api();local app=K.App.New(a,K.Dump.Storage(a));app:Start()
    local callback=a.EVENT_MANAGER.updates[K.name..':refresh'];T.eq(type(callback),'function')
    callback();T.eq(app.lastSnapshot~=nil,true)
    local captured=app.collector.Capture;app.collector.Capture=function()error('hover performed a full capture')end
    app:GetBreakdown('maxStamina');app.collector.Capture=captured
 end,
 cached_hovers=function()
    local a=api();local app=K.App.New(a,K.Dump.Storage(a));local calls=0
    local capture=app.collector.Capture
    app.collector.Capture=function(self,full)calls=calls+1;return capture(self,full)end
    app:GetBreakdown('maxHealth');app:GetBreakdown('maxStamina');app:GetBreakdown('weaponDamage')
    T.eq(calls,1)
    app:Invalidate('equipment');app:GetBreakdown('maxHealth');T.eq(calls,2)
 end,
 passive_effect_identity=function()
    local a=api();local app=K.App.New(a,K.Dump.Storage(a));local s=dofile('KanaStatSources/tests/fixtures/complete_build.lua')()
    s.skills={{id=123,purchased=true,passive=true,lineActive=true,name='Passive',description='Increases Maximum Health by 1000.'},{id=124,purchased=true,passive=true,lineActive=true,name='Independent',description='Increases Maximum Health by 1000.'}}
    s.effects={{index=1,abilityId=123,name='Active passive effect',endTime=0,description='Increases Maximum Health by 1000.'}}
    local b,c,d=app:Explain(s);local found=0
    for _,v in ipairs(c)do if v.source and (v.source.id==123 or v.source.id==124)then found=found+1 end end
    T.eq(found,2);T.eq(T.sumRows(b.maxHealth),b.maxHealth.total)
    T.eq(c[#c].source.id,123)
 end,
 load_and_dump=function()local a=api();K.App.Load(a);local onLoad=a.EVENT_MANAGER.handlers[1];onLoad(1,'OtherAddon');T.eq(K.instance,nil);onLoad(1,'KanaStatSources');local app=K.instance;T.eq(type(a.SLASH_COMMANDS['/kanastats']),'function');T.eq(a.STATS,nil);a.SLASH_COMMANDS['/kanastats']('dump');T.eq(#a.KanaStatSourcesSaved.dumps,1);T.eq(a.KanaStatSourcesSaved.dumps[1].snapshot.categoryStatus.advancedStats,'available');T.eq(a.EVENT_MANAGER.handlers[1],nil);app:Start();local row=a.Control();row.statEntry={statType=1};a.ZO_StatsEntry_OnMouseEnter(row);T.eq(#a.KanaStatSourcesSaved.dumps,1);T.eq(#a.messages>0,true);K.instance=nil end,
 all_categories=function()local a=api();local app=K.App.New(a,K.Dump.Storage(a));local s=dofile('KanaStatSources/tests/fixtures/complete_build.lua')();local b,c=app:Explain(s);local categories={};for _,r in ipairs(c)do if r.amount~=0 then categories[r.category]=true end;T.eq(r.evidence~=nil,true)end;for _,category in ipairs({'base','attributes','equipment','sets','skills','champion','food','mundus','effects'})do T.eq(categories[category],true)end;for _,d in ipairs(K.Stats.Definitions)do T.eq(T.sumRows(b[d[1]]),s.stats[d[1]].total)end;s.consistent=false;b=app:Explain(s);T.eq(#b.maxHealth.rows,1);T.eq(b.maxHealth.rows[1].category,'unknown')end,
 coalesced_events=function()local a=api();local app=K.App.New(a,K.Dump.Storage(a));app:Start();local row=a.Control();row.statEntry={statType=1};a.ZO_StatsEntry_OnMouseEnter(row);local cached=app.collector.cache.build;for _=1,20 do a.EVENT_MANAGER.handlers[2](2,'player')end;T.eq(app.collector.cache.build,cached);local count=0;for _ in pairs(a.EVENT_MANAGER.updates)do count=count+1 end;T.eq(count,1);a.EVENT_MANAGER.handlers[3](3);T.eq(app.collector.cache.build,nil);for name,fn in pairs(a.EVENT_MANAGER.updates)do fn();T.eq(a.EVENT_MANAGER.updates[name],nil)end;T.eq(app.bridge.active,row);app.bridge:Clear();local generation=app.collector.generation;a.EVENT_MANAGER.handlers[2](2,'group1');T.eq(app.collector.generation,generation);for _,event in ipairs({4,5,6,7})do if event==4 then a.EVENT_MANAGER.handlers[event](event,1,1,'Buff','player')else a.EVENT_MANAGER.handlers[event](event)end end;T.eq(next(a.EVENT_MANAGER.updates),nil)end,
 provider_failure=function()local a=api();local app=K.App.New(a,K.Dump.Storage(a));local original=K.Sources.Skills.Build;K.Sources.Skills.Build=function()error('failure')end;local b,c,d=app:Explain(dofile('KanaStatSources/tests/fixtures/complete_build.lua')());K.Sources.Skills.Build=original;T.eq(T.sumRows(b.maxHealth),b.maxHealth.total);T.eq(#c>0,true);local found=false;for _,v in ipairs(d)do if v.category=='skills' and v.reason:find('failure',1,true)then found=true end end;T.eq(found,true)end,
}
