local Fake=dofile(ROOT.."/tests/support/fake_eso.lua")
local function setup()
    local k=Fake.Load({"Core.lua","BuildCapabilities.lua"})
    local api={requests={},skillRequests={},attributeRequests={}}
    local function forbidden()error("diagnostics attempted an allocation")end
    for _,name in ipairs({"StartSkillRespecFromUI","PrepareSkillPointAllocationRequest","SendSkillPointAllocationRequest","AddActiveChangeToAllocationRequest","AddPassiveChangeToAllocationRequest","AddHotbarSlotChangeToAllocationRequest","SendAttributePointAllocationRequest","StartAttributeRespecFromUI"})do api[name]=forbidden end
    api.GetAttributeSpentPoints=function()return 0 end
    api.GetAttributeUnspentPoints=function()return 64 end
    api.GetAPIVersion=function()return 101050 end
    for _,name in ipairs({"SKILLS_DATA_MANAGER","SKILL_POINT_ALLOCATION_MANAGER","ACTION_BAR_ASSIGNMENT_MANAGER","SKILLS_AND_ACTION_BAR_MANAGER","STATS"})do api[name]={}end
    return k,api
end
local tests={}
function tests.capabilities_missing_respec_api_preserves_equipment()
    local k,a=setup();a.StartAttributeRespecFromUI=nil
    local c=k.BuildCapabilities.Read(a)
    assert(not c.attributes and c.skills)
    assert(#a.requests==0 and #a.skillRequests==0 and #a.attributeRequests==0)
    assert(c.problems[1].details.name=="StartAttributeRespecFromUI")
end
function tests.capabilities_read_never_sends_requests()
    local k,a=setup();local c=k.BuildCapabilities.Read(a)
    assert(c.skills and c.attributes and c.apiVersion==101050 and #c.problems==0)
    assert(#a.requests==0 and #a.skillRequests==0 and #a.attributeRequests==0)
end
function tests.capabilities_missing_managers_and_getters_are_component_local()
    local k,a=setup();a.SKILLS_DATA_MANAGER=nil;a.GetAttributeSpentPoints=nil
    local c=k.BuildCapabilities.Read(a)
    assert(not c.skills and not c.attributes and #c.problems==2)
    assert(c.available.SendAttributePointAllocationRequest and not c.available.GetAttributeSpentPoints)
end
function tests.capabilities_missing_api_version_is_reported_without_throwing()
    local k,a=setup();a.GetAPIVersion=nil
    local c=k.BuildCapabilities.Read(a)
    assert(c.apiVersion==nil and #c.problems==1 and c.skills and c.attributes)
end
function tests.capabilities_status_reports_live_missing_names_without_requests()
    local k,a=setup();a.StartAttributeRespecFromUI=nil
    local text=k.Core.BuildCapabilitiesStatus({api=a})
    assert(text:find("API 101050",1,true) and text:find("skills=true",1,true))
    assert(text:find("attributes=false",1,true) and text:find("StartAttributeRespecFromUI",1,true))
    assert(#a.requests==0 and #a.skillRequests==0 and #a.attributeRequests==0)
end
function tests.missing_skill_entry_degrades_skills_without_calling_starter()
 local k,a=setup();a.StartSkillRespecFromUI=nil;local c=k.BuildCapabilities.Read(a)
 assert(not c.skills and c.attributes and c.problems[1].details.name=="StartSkillRespecFromUI")
end
return tests
