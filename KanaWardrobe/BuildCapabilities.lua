local KW = KanaWardrobe
KW.BuildCapabilities = {}

-- Presence is not proof of secure-call permission; that requires the client protocol.
-- Never call respec starters, setters, managers, or allocation requests here.
function KW.BuildCapabilities.Read(api)
    api = api or _G
    local result = {skills=true, attributes=true, problems={}, available={}}
    local function check(component, name, kind)
        local value = api[name]
        local present = kind == "function" and type(value) == "function"
            or kind == "manager" and (type(value) == "table" or type(value) == "userdata")
        result.available[name] = present
        if not present then
            if component then result[component] = false end
            result.problems[#result.problems+1] = KW.Problem("buildCapabilityUnavailable",
                {component=component or "diagnostics", name=name})
        end
    end
    for _,name in ipairs({"StartSkillRespecFromUI", "PrepareSkillPointAllocationRequest", "SendSkillPointAllocationRequest",
        "AddActiveChangeToAllocationRequest", "AddPassiveChangeToAllocationRequest",
        "AddHotbarSlotChangeToAllocationRequest"}) do check("skills", name, "function") end
    for _,name in ipairs({"SKILLS_DATA_MANAGER", "SKILL_POINT_ALLOCATION_MANAGER",
        "ACTION_BAR_ASSIGNMENT_MANAGER", "SKILLS_AND_ACTION_BAR_MANAGER"}) do check("skills", name, "manager") end
    for _,name in ipairs({"StartAttributeRespecFromUI", "SendAttributePointAllocationRequest",
        "GetAttributeSpentPoints", "GetAttributeUnspentPoints"}) do check("attributes", name, "function") end
    check("attributes", "STATS", "manager")
    check(nil, "GetAPIVersion", "function")
    if result.available.GetAPIVersion then result.apiVersion = api.GetAPIVersion() end
    return result
end
