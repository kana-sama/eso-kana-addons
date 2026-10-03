-- Pure selector identity and matching; display names never participate in keys.
local Selectors = {}
KanaEffects.Selectors = Selectors
function Selectors.FromObservation(observation)
    if observation.artificialEffectId then return {kind="artificial",id=observation.artificialEffectId} end
    return {kind="ability",id=observation.abilityId}
end
function Selectors.DeltaField(selector)
    return selector.kind == "ability" and "abilities" or selector.kind == "artificial" and "artificialEffects"
        or selector.kind == "family" and "families" or "categories"
end
function Selectors.Key(selector)
    if selector.kind == "family" then return "family:" .. selector.id .. ":" .. selector.level end
    return selector.kind .. ":" .. tostring(selector.id)
end
function Selectors.Matches(selector, observation)
    if selector.kind == "ability" then return observation.abilityId == selector.id end
    if selector.kind == "artificial" then return observation.artificialEffectId == selector.id end
    local entry = observation.catalog
    if not entry then return false end
    if selector.kind == "category" then return entry.categories ~= nil and entry.categories[selector.id] == true end
    if selector.kind == "family" then
        return entry.familyId == selector.id and (entry.level == "minor" or entry.level == "major")
            and (selector.level == "pair" or selector.level == entry.level)
    end
    return false
end
