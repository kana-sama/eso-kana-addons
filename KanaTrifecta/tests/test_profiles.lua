local F=dofile('KanaTrifecta/tests/fixtures.lua')
return {
 profile_validation=function()
    local p=F.NewRun().profile; local registry=KanaTrifecta.Profiles
    assert(#registry:Validate(p)==0);assert(registry:Register(p));assert(registry:Find(1301,2)==p)
    assert(registry:Find(1301,1)==nil);p.bosses[2].key='a';assert(#registry:Validate(p)>0)
 end,
 empty_validated_profile_rejected=function()
    local p=F.NewRun({bosses={}}).profile;assert(#KanaTrifecta.Profiles:Validate(p)>0)
 end,
 unknown_metadata_has_no_fabricated_numbers=function()
    local r=F.NewRun({bosses={},limitMs=false,supportStatus='unsupported'})
    local v=r:View(0);assert(v.timer.text=='--:--');assert(v.deaths.text=='0');assert(#v.bossRows==0)
 end,
}
