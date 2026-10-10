local F=dofile('KanaTrifecta/tests/fixtures.lua')
local function api()
    return {GetGameTimeMilliseconds=function() return 100 end,GetTimeStamp=function() return 1000 end,
        GetUnitZoneIndex=function() return 1 end,GetZoneId=function() return 1301 end,
        GetCurrentZoneDungeonDifficulty=function() return 2 end,GetGroupSize=function() return 1 end,
        GetGroupUnitTagByIndex=function() return 'group1' end,
        GetUnitDisplayName=function() return '@one' end,GetRawUnitName=function() return 'Char' end,
        IsGroupCompanionUnitTag=function() return false end,IsGroupMemberInSameInstanceAsPlayer=function() return true end,
        IsUnitOnline=function() return true end,IsUnitDead=function() return false end}
end
return {
 membership_changes_and_disconnect=function()
    local a=api();local same,online=true,true
    a.GetUnitDisplayName=function(tag) return tag=='player' and '@one' or '@two' end
    a.GetRawUnitName=function(tag) return tag=='player' and 'Char' or 'Other' end
    a.IsGroupMemberInSameInstanceAsPlayer=function() return same end
    a.IsUnitOnline=function(tag) return tag=='player' or online end
    local r=F.NewRun();local o=KanaTrifecta.Observer.New(a,function(e) r:Apply(e) end)
    o:Activate(r.profile,{contextGeneration=1,freshness='fresh'})
    same=false;o:Death('group1',true);assert(r.deathCount==0);assert(r.deathCoverage=='partial')
    same=true;o:SyncMembers();o:Death('group1',true);assert(r.deathCount==1)
    online=false;o:SyncMembers();assert(not o.members['@two\31Other'].inInstance)
 end,
 member_aliases=function()
    assert(KanaTrifecta.Observer,'Observer not implemented')
    local events={};local o=KanaTrifecta.Observer.New(api(),function(e) events[#events+1]=e end)
    local r=F.NewRun();o:Activate(r.profile,{contextGeneration=1,freshness='fresh'})
    o:SyncMembers();assert(#events==1);assert(events[1].payload.memberKey=='@one\31Char')
    o:Death('player',true);o:Death('group1',true)
    for _,e in ipairs(events) do r:Apply(e) end
    assert(r.deathCount==1)
 end,
 unsupported_veteran_trial=function()
    assert(KanaTrifecta.Observer,'Observer not implemented')
    local a=api();a.GetZoneId=function() return 636 end
    local o=KanaTrifecta.Observer.New(a,function() error('unexpected emit') end)
    assert(KanaTrifecta.Profiles:Find(o:ReadContext().zoneId,2)==nil)
 end,
 inactive_observer_ignores_death=function()
    assert(KanaTrifecta.Observer,'Observer not implemented')
    local o=KanaTrifecta.Observer.New(api(),function() error('inactive event') end);o:Death('player',true)
 end,
}
