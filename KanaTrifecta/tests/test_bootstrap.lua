local F=dofile('KanaTrifecta/tests/fixtures.lua')
return {
 wayrest_first_combat_is_local_with_or_without_known_history=function()
    dofile('KanaTrifecta/profiles/catalog.lua');local p=KanaTrifecta.Profiles:Find(146,2)
    for _,freshness in ipairs({'fresh','unknown'}) do
        local r=KanaTrifecta.Run.New(p,{contextGeneration=1,freshness=freshness,language='en'})
        local o=KanaTrifecta.Observer.New({GetTimeStamp=function() return 1000 end,GetGameTimeMilliseconds=function() return 0 end},function(e) r:Apply(e) end)
        o.context={contextGeneration=1};o.profile=p;o.snapshot=function() return r:Snapshot() end
        o:Handle({kind='combatState',inCombat=true,atMs=0})
        assert(r:View(0).timer.text=='15:00');assert(r.clock.unboundedStart and r.clock.localObservation)
        assert(r:View(0).assessment=='unknown');assert(r:View(900001).timer.colorRole=='error')
        assert(r:View(900001).assessment=='unknown');assert(not r:View(900001).failureReasons.time)
    end
 end,
 solo_veteran_wayrest_renders_without_exported_child_global=function()
    local S=dofile('KanaTrifecta/tests/ui_stubs.lua');local a=S.api();local pending
    dofile('KanaTrifecta/profiles/catalog.lua')
    a.GetGameTimeMilliseconds=function() return 100 end;a.GetTimeStamp=function() return 1000 end
    a.GetUnitZoneIndex=function() return 1 end;a.GetZoneId=function() return 146 end
    a.GetCurrentZoneDungeonDifficulty=function() return 2 end;a.GetGroupSize=function() return 0 end
    a.GetUnitDisplayName=function() return '@one' end;a.GetRawUnitName=function() return 'Char' end
    a.IsUnitDead=function() return false end;a.CallLater=function(fn) pending=fn end
    local b=KanaTrifecta.Bootstrap.New(a);b.hud=KanaTrifecta.Hud.New(a,function() end)
    b.hud.root:SetHidden(false);b:RefreshContext();pending()
    assert(b.run.profileKey=='wayrest_sewers_i');assert(b.run.lifecycle=='observing')
    assert(not S.isHidden(b.hud.content),'panel must remain visible with unknown start')
    assert(b.hud.title.text=='Wayrest Sewers I');assert(b.hud.timer.text=='15:00')
    assert(b.hud.root.anchor[2]==a.questTrackerControl);assert(#b.hud.rows==6)
 end,
 native_control_visibility_during_member_sync=function()
    local S=dofile('KanaTrifecta/tests/ui_stubs.lua');local a=S.api()
    a.GetGameTimeMilliseconds=function() return 100 end;a.GetTimeStamp=function() return 1000 end
    a.GetGroupSize=function() return 0 end
    a.GetUnitDisplayName=function() return '@one' end;a.GetRawUnitName=function() return 'Char' end
    a.IsUnitDead=function() return false end
    local gamepad=false;a.IsInGamepadPreferredMode=function() return gamepad end
    local b=KanaTrifecta.Bootstrap.New(a);b.generation=1;b.run=F.NewRun()
    b.context={contextGeneration=1,freshness='fresh'};b.observer.context=b.context
    b.hud=KanaTrifecta.Hud.New(a,function() end)
    assert(b.hud.root.IsEffectivelyHidden==nil,'test must use the native control API')
    local renders=0;local render=b.hud.Render
    b.hud.Render=function(h,view) renders=renders+1;return render(h,view) end
    b.hud.root:SetHidden(false);b.observer:SyncMembers()
    assert(renders==1);assert(not S.isHidden(b.hud.content))
    b.hud.root:SetHidden(true);b:UpdateView();assert(renders==1)
    b.hud.root:SetHidden(false);gamepad=true;b:UpdateView()
    assert(renders==1);assert(S.isHidden(b.hud.content))
    gamepad=false;b.context=nil;b:UpdateView()
    assert(renders==1);assert(S.isHidden(b.hud.content))
 end,
 two_snapshots_250ms_and_old_callback=function()
    assert(KanaTrifecta.Bootstrap,'Bootstrap not implemented')
    local scheduled={};local zone=1301
    local api={GetGameTimeMilliseconds=function() return 0 end,GetTimeStamp=function() return 1000 end,
        GetUnitZoneIndex=function() return 1 end,GetZoneId=function() return zone end,
        GetCurrentZoneDungeonDifficulty=function() return 2 end,GetGroupSize=function() return 0 end,
        GetUnitDisplayName=function() return '@one' end,GetRawUnitName=function() return 'Char' end,
        IsUnitDead=function() return false end,CallLater=function(fn,ms) assert(ms==250);scheduled[#scheduled+1]=fn end}
    local p=F.NewRun().profile;KanaTrifecta.Profiles:Register(p)
    local b=KanaTrifecta.Bootstrap.New(api);b:RefreshContext();assert(not b.run)
    zone=636;b:RefreshContext();scheduled[1]();assert(not b.run)
    scheduled[2]();assert(not b.run)
    zone=1301;b:RefreshContext();scheduled[3]();assert(b.run);assert(b.run.lifecycle=='observing')
 end,
}
