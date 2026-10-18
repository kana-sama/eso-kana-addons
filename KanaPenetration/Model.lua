KanaPenetration = KanaPenetration or {}
local M = {}
KanaPenetration.Model = M

function M.Number(value)
    if type(value) == 'number' and value == value and value > -math.huge and value < math.huge then
        return math.max(0, value)
    end
end

local ordinaryDummy = {base=18200}
local trialDummy = {base=18200, trial=true}
local precursor = {base=9100}
-- Furniture IDs resolve to the actual localized unit names. Never match a
-- translated substring such as "Target" or infer armor from current health.
-- Catalog: LUI UnitNamesTable + the client item-name data (see specification).
local dummyItems = {
    118553, 120426, 120427, 121314, 121399, 121400, -- Skeletons
    126035, 126036, 126037, 126038, -- Centurions
    130193, 130194, 130195, 134823, 141778, 146069, 151906,
    153563, 156669, 165569, 166960, 169117, 178694, 183856,
    190951, 193794, 199133, 203270, 211300, 211499, 219876, 223732,
}

function M.BuildDummyLookup(itemName)
    local lookup = {}
    local function Add(id, profile)
        local name = itemName(id)
        if name and name ~= '' then lookup[name] = profile end
    end
    for _, id in ipairs(dummyItems) do Add(id, ordinaryDummy) end
    for _, id in ipairs({147926, 171875, 187664, 204408}) do Add(id, trialDummy) end
    Add(132348, precursor)
    return lookup
end

function M.HousingDummy(maxHealth)
    -- After excluding players/dead/non-attackable units, housing targets are
    -- training furnishings. This also covers new skins absent from the catalog.
    -- The 21M raid preset supplies debuffs; 25M/50M centurions do not.
    return maxHealth == 21000000 and trialDummy or ordinaryDummy
end

function M.Profile(context, settings)
    if settings.profile == 'overland' then return 9100, 'manual' end
    if settings.profile == 'dungeon' then return 18200, 'manual' end
    if settings.profile == 'custom' then
        local value = M.Number(settings.customResistance)
        if value and settings.customResistance >= 0 then return value, 'manual' end
        return nil, 'unknown'
    end
    if context.dummy then return context.dummy.base, 'dummy' end
    if context.archive then return context.archiveBoss and 18200 or 9100, 'archive' end
    if context.unknown or context.house or context.zoneId == 677 or context.zoneId == 1227 then
        return nil, 'unknown'
    end
    if context.dungeon then
        return 18200, 'dungeon'
    end
    return 9100, 'overland'
end

function M.Calculate(base, penetration, reduction)
    base, penetration = M.Number(base), M.Number(penetration)
    local result = {penetration = penetration, fill = 0}
    if not base or not penetration then return result end
    local remaining = math.max(0, base - (M.Number(reduction) or 0))
    result.remaining = remaining
    result.missing = math.max(0, remaining - penetration)
    result.excess = math.max(0, penetration - remaining)
    if remaining == 0 then
        result.stripped, result.fill = true, 1
    else
        result.percent = 100 * penetration / remaining
        result.fill = math.min(1, result.percent / 100)
    end
    return result
end

-- Values describe the debuff, never an increase to the player's own stats.
local definitions = {
    {key='major', ids={61743, 53881, 62775, 62787, 120010}, value=5948},
    {key='minor', ids={61742, 68588, 120019}, value=2974},
    {key='crusher', ids={17906}, setting='crusher'},
    {key='crusher', ids={120007}, value=2108},
    {key='alkosh', ids={75753, 76667}, setting='alkosh'},
    {key='alkosh', ids={120018}, value=6000},
    {key='tremorscale', ids={80866}, setting='tremorscale'},
    {key='crimson', ids={159288}, value=3541},
    {key='crystal', ids={143808}, value=1000},
    {key='runic', ids={187742}, value=2200},
    {key='spellPoison', ids={79087}, value=1320, kind='spell'},
    {key='physicalPoison', ids={79090}, value=1320, kind='physical'},
}
local statuses = {18084, 21929, 95136, 95134, 178118, 178123, 178127, 148801}

function M.BuildLookup(abilityName)
    local lookup = {ids={}, names={}, statuses={}}
    for _, definition in ipairs(definitions) do
        for _, id in ipairs(definition.ids) do
            lookup.ids[id] = definition
            local name = abilityName(id)
            if name and name ~= '' then
                local previous = lookup.names[name]
                if previous == nil then
                    lookup.names[name] = definition
                elseif not previous or previous.key ~= definition.key then
                    lookup.names[name] = false -- Ambiguous localized name: require an ID.
                end
            end
        end
    end
    for _, id in ipairs(statuses) do lookup.statuses[id] = true end
    return lookup
end

function M.Effects(effects, lookup, settings, forceOfNature, trial)
    local families, seenStatuses = {}, {}
    -- These trial-dummy effects may be absent from GetUnitBuffInfo. Seed the
    -- same families used below, so player debuffs cannot double-count them.
    if trial then
        families.major = {value=5948}
        families.minor = {value=2974}
        families.crusher = {value=2108}
        families.alkosh = {value=6000}
    end
    local result = {physical=0, spell=0, bonus=0, bonusMax=forceOfNature and 5280 or 0}
    for _, effect in ipairs(effects) do
        local definition = lookup.ids[effect.id] or lookup.names[effect.name]
        if definition then
            local value = definition.value or M.Number(settings[definition.setting]) or 0
            local previous = families[definition.key]
            if not previous or value > previous.value then
                families[definition.key] = {value=value, kind=definition.kind}
            end
        end
        if forceOfNature and lookup.statuses[effect.id] and not seenStatuses[effect.id] then
            seenStatuses[effect.id] = true
            result.bonus = result.bonus + 660
        end
    end
    for _, family in pairs(families) do
        if family.kind ~= 'spell' then result.physical = result.physical + family.value end
        if family.kind ~= 'physical' then result.spell = result.spell + family.value end
    end
    return result
end
