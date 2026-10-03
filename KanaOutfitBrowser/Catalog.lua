KanaOutfitBrowser = KanaOutfitBrowser or {}
local KOB = KanaOutfitBrowser

KOB.Catalog = KOB.Catalog or {}
local Catalog = KOB.Catalog

local function MakeConstants(overrides)
    if overrides then
        return overrides
    end

    return {
        visualArmorTypeLight = VISUAL_ARMORTYPE_LIGHT,
        visualArmorTypeMedium = VISUAL_ARMORTYPE_MEDIUM,
        visualArmorTypeHeavy = VISUAL_ARMORTYPE_HEAVY,
        armorSlots = {
            OUTFIT_SLOT_HEAD,
            OUTFIT_SLOT_CHEST,
            OUTFIT_SLOT_SHOULDERS,
            OUTFIT_SLOT_HANDS,
            OUTFIT_SLOT_WAIST,
            OUTFIT_SLOT_LEGS,
            OUTFIT_SLOT_FEET,
        },
        chestSlot = OUTFIT_SLOT_CHEST,
    }
end

local function LogicalWeight(visualArmorType, constants)
    if visualArmorType == constants.visualArmorTypeLight then
        return 1
    elseif visualArmorType == constants.visualArmorTypeMedium then
        return 2
    elseif visualArmorType == constants.visualArmorTypeHeavy then
        return 3
    end
    return 4
end

local function ChestKind(icon)
    local normalized = string.lower(icon or "")
    if string.find(normalized, "chest", 1, true) or string.find(normalized, "cuirass", 1, true) then
        return "cuirass", 3
    elseif string.find(normalized, "robe", 1, true) then
        return "robe", 2
    end
    return "unknown", 1
end

local function PreferSlotCandidate(current, candidate, isChest, diagnostics, variantKey, slot)
    if not current then
        return candidate
    end
    if current.collectibleId == candidate.collectibleId then
        return current
    end

    if isChest then
        local currentKind, currentRank = ChestKind(current.icon)
        local candidateKind, candidateRank = ChestKind(candidate.icon)
        if currentKind ~= candidateKind and currentKind ~= "unknown" and candidateKind ~= "unknown" then
            table.insert(diagnostics, string.format(
                "%s chest candidates %d and %d resolved by icon heuristic (%s before %s); ESO exposes no cuirass/robe subtype API.",
                variantKey, current.collectibleId, candidate.collectibleId,
                currentRank > candidateRank and currentKind or candidateKind,
                currentRank > candidateRank and candidateKind or currentKind))
        else
            table.insert(diagnostics, string.format(
                "%s has ambiguous chest candidates %d and %d; icon heuristic is unresolved and the lower collectible ID is used.",
                variantKey, current.collectibleId, candidate.collectibleId))
        end

        if currentRank ~= candidateRank then
            return currentRank > candidateRank and current or candidate
        end
    else
        table.insert(diagnostics, string.format(
            "%s has duplicate outfit slot %s candidates %d and %d; the lower collectible ID is used.",
            variantKey, tostring(slot), current.collectibleId, candidate.collectibleId))
    end

    if candidate.collectibleId < current.collectibleId then
        return candidate
    end
    return current
end

local function IsPositiveId(value)
    return type(value) == "number" and value > 0
end

-- Fallback for the engine's zero item-style IDs. Texture grouping is a
-- heuristic; retain the appearance suffix and never merge unknown filenames.
local function Nonempty(value)
    return type(value) == "string" and value:find("[^ \t\r\n]") and value or nil
end

-- Localized fallback for filenames that do not encode the armor family.
-- Strip only a complete leading piece name that agrees with the actual slot.
local function NameFamily(record, constants)
    if not constants or not Nonempty(record.collectibleName) then return end
    local nouns = {
        {"Опаловая маска", "Головной убор", "Тяжелый шлем", "Тяжёлый шлем", "Шлем", "Капюшон", "Шляпа", "Маска"},
        {"Камзол", "Кираса", "Нагрудник", "Одеяние", "Роба", "Жилет", "Куртка", "Мантия"},
        {"Опаловый наплечник", "Эполеты", "Оплечье", "Наплечники", "Наплечник", "Наплечи"},
        {"Латные перчатки", "Наручи", "Перчатки", "Рукавицы"},
        {"Пояс", "Ремень"},
        {"Брюки", "Поножи", "Штаны"},
        {"Ботинки", "Сапоги", "Башмаки", "Сандалии"},
    }
    for index, slot in ipairs(constants.armorSlots) do
        for _, eligible in ipairs(record.eligibleSlots or {}) do
            if eligible == slot then
                for _, noun in ipairs(nouns[index] or {}) do
                    local prefix = noun .. " "
                    if record.collectibleName:sub(1, #prefix) == prefix then
                        local label = record.collectibleName:sub(#prefix + 1):match("^[ \t]*(.-)[ \t]*$")
                        local name, rank = label:match("^(.-) +(%d+)$")
                        name = name or label
                        if Nonempty(name) then
                            local key = zo_strlower and zo_strlower(name) or name:gsub("[A-Z]", string.lower)
                            if noun:find("Опалов", 1, true) then key = "opal:" .. key; name = "Опаловый: " .. name end
                            return "name:" .. key, name, rank, 1
                        end
                    end
                end
            end
        end
    end
end

local function LegacyResolveFamily(record, constants)
    if IsPositiveId(record.itemStyleId) and Nonempty(record.name) then
        return "itemstyle:" .. tostring(record.itemStyleId), record.name, nil, 3
    end
    local icon = string.lower(record.icon or "")
    local family, weight, part, appearance = icon:match("/gear_(.+)_([^_]+)_([^_]+)_([^_]+)%.dds$")
    local parts = { head=true, chest=true, shirt=true, robe=true, shoulders=true, shoulder=true,
        hands=true, hand=true, waist=true, belt=true, legs=true, feet=true, foot=true }
    if family and (weight == "light" or weight == "medium" or weight == "heavy") and parts[part] then
        local name = Nonempty(record.collectibleName) or Nonempty(record.name) or family
        local isHead = part == "head"
        if isHead then
            -- Only label cleanup; family identity never depends on translated text.
            for _, term in ipairs({"Головной убор", "головной убор", "Тяжелый", "тяжелый",
                "Тяжёлый", "тяжёлый", "Шлем", "шлем", "Light", "Medium", "Heavy", "Helmet", "Helm", "Hat", "Hood"}) do
                name = name:gsub(term, "")
            end
            name = name:gsub("[ \t\r\n]+%d+$", ""):gsub("[ \t\r\n]+", " "):match("^[ \t\r\n]*(.-)[ \t\r\n]*$")
        end
        if name == "" then name = Nonempty(record.collectibleName) or family end
        if IsPositiveId(record.itemStyleId) then appearance = nil end
        return IsPositiveId(record.itemStyleId) and ("itemstyle:" .. record.itemStyleId) or ("texture:" .. family),
            name, appearance, isHead and 2 or 1
    end
    if IsPositiveId(record.itemStyleId) then
        return "itemstyle:" .. record.itemStyleId,
            Nonempty(record.collectibleName) or ("Стиль #" .. record.itemStyleId), nil, 0
    end
    local nameKey, nameLabel, nameRank, priority = NameFamily(record, constants)
    if nameKey then return nameKey, nameLabel, nameRank, priority end
    if Nonempty(record.collectibleName) then
        return "collectible:" .. tostring(record.collectibleId), record.collectibleName, nil, 0
    end
end

local PART_INDEX = {
    head=1, helmet=1, helm=1,
    chest=2, cheste=2, chestv2=2, costume=2, shirt=2, robe=2, robes=2, lightrobe=2,
    shoulder=3, shoulders=3, should=3,
    hands=4, hand=4, gloves=4, arms=4,
    waist=5, belt=5, legs=6, legsa=6, feet=7, foot=7,
}
local WEIGHTS = { light=true, medium=true, heavy=true, lgt=true, med=true, hvy=true, mediuam=true, meium=true, mediumt=true, lighty=true }
local function TextureFamily(record, constants)
    local stem = (record.icon or ""):lower():match("/([^/]+)%.dds$")
    if not stem then return end
    if stem:sub(1,5) == "gear_" then stem = stem:sub(6)
    elseif not stem:match("^und") then return end
    local tokens = {}
    for token in stem:gmatch("[^_]+") do tokens[#tokens+1]=token end
    local partAt, part
    for i=#tokens,2,-1 do
        local slotIndex=PART_INDEX[tokens[i]]
        if slotIndex then
            for _,slot in ipairs(record.eligibleSlots or {}) do
                if constants and slot == constants.armorSlots[slotIndex] then partAt,part=i,tokens[i]; break end
            end
        end
        if partAt then break end
    end
    if not partAt then
        -- Several shipped icons name the wrong body part. Family still comes
        -- from the filename; placement always comes from eligibleSlots, not art.
        for i=#tokens,2,-1 do
            if PART_INDEX[tokens[i]] then partAt,part=i,tokens[i]; break end
        end
    end
    if not partAt and stem == "faunslarkcladding_a" then
        return "faunslarkcladding", "chest", "a"
    end
    if not partAt then return end
    local family, appearance = {}, {}
    for i,token in ipairs(tokens) do
        if token == "lightbg" or token == "mediumbg" or token == "heavybg" then token = "bg" end
        if i ~= partAt and not WEIGHTS[token] then
            if i < partAt then family[#family+1]=token else appearance[#appearance+1]=token end
        end
    end
    local name = table.concat(family,"_")
    -- Older art names glue the abbreviated armor weight to the motif token,
    -- sometimes immediately before v2. Preserve the version itself.
    name = name:gsub("lgt(v%d+)$", "%1"):gsub("med(v%d+)$", "%1"):gsub("hvy(v%d+)$", "%1")
    name = name:gsub("lgt$", ""):gsub("med$", ""):gsub("hvy$", "")
    name = name:gsub("heavy$", ""):gsub("medium$", ""):gsub("light$", "")
    local aliases = {
        ["-knightsotsrose"]="knightsotsrose", knightsots="knightsotsrose", knightsotsr="knightsotsrose",
        armamentofthekindred="armamentkindred", fellowshipofstirk="fellowshipstirk",
        ashlander_v2="ashlanderv", prophetplayer="prophet", golddragoon="goldroaddragoon",
    }
    name = aliases[name] or name
    if record.visualArmorType == 5 and (name == "rags" or name == "soulshriven" or name == "npcbandit") then name = "prisoner" end
    if name == "" then return end
    local suffix = #appearance > 0 and table.concat(appearance,"_") or "a"
    -- Verified art revisions/typos in the full client snapshot, not extra outfits.
    if suffix == "a-" or suffix == "a." or suffix == "a_2" then suffix = "a" end
    if name == "scribesofmora" and suffix == "a2" then suffix = "a" end
    -- This recolored shoulder is sold as a different named style.
    if name == "feraldruid" and suffix == "b" then name = "feraldruid_b" end
    return name, part, suffix
end

local function ResolveFamily(record, constants)
    if record.itemStyleId == 67 then
        local key, label, rank, priority = NameFamily(record, constants)
        if key then return key, label, rank, priority end
    end
    if IsPositiveId(record.itemStyleId) and record.itemStyleId ~= 67 and Nonempty(record.name) then
        return "itemstyle:" .. tostring(record.itemStyleId), record.name, nil, 3
    end
    local family, part, appearance = TextureFamily(record, constants)
    if family then
        local name = Nonempty(record.collectibleName) or Nonempty(record.name) or family
        local isHead = PART_INDEX[part] == 1
        if isHead then
            -- Only label cleanup; family identity never depends on translated text.
            for _, term in ipairs({"Головной убор", "головной убор", "Тяжелый", "тяжелый",
                "Тяжёлый", "тяжёлый", "Шлем", "шлем", "Light", "Medium", "Heavy", "Helmet", "Helm", "Hat", "Hood"}) do
                name = (" " .. name .. " "):gsub(" " .. term .. " ", " ")
            end
            name = name:match("^[ \t\r\n]*(.-)[ \t\r\n]*$"):gsub("[ \t\r\n]+%d+$", ""):gsub("[ \t\r\n]+", " "):match("^[ \t\r\n]*(.-)[ \t\r\n]*$")
        end
        if name == "" then name = Nonempty(record.collectibleName) or family end
        if IsPositiveId(record.itemStyleId) and record.itemStyleId ~= 67 then appearance = nil end
        return (IsPositiveId(record.itemStyleId) and record.itemStyleId ~= 67) and ("itemstyle:" .. record.itemStyleId) or ("texture:" .. family),
            name, appearance, isHead and 2 or 1
    end
    if IsPositiveId(record.itemStyleId) then
        return "itemstyle:" .. record.itemStyleId,
            Nonempty(record.collectibleName) or ("Стиль #" .. record.itemStyleId), nil, 0
    end
    local nameKey, nameLabel, nameRank, priority = NameFamily(record, constants)
    if nameKey then return nameKey, nameLabel, nameRank, priority end
    if Nonempty(record.collectibleName) then
        return "collectible:" .. tostring(record.collectibleId), record.collectibleName, nil, 0
    end
end

function Catalog.Normalize(records, constantOverrides)
    local constants = MakeConstants(constantOverrides)
    local diagnostics = {}
    local snapshot = {
        recordCount = #(records or {}),
        variantCount = 0,
        omittedRecordCount = 0,
        omittedSamples = {},
        familyAliases = {},
    }
    local armorSlotSet = {}
    for _, slot in ipairs(constants.armorSlots) do
        armorSlotSet[slot] = true
    end

    local byKey = {}
    for _, record in ipairs(records or {}) do
        local familyKey, familyName, appearance, nameRank = ResolveFamily(record, constants)
        if not IsPositiveId(record.collectibleId)
            or not IsPositiveId(record.outfitStyleId)
            or not familyKey then
            snapshot.omittedRecordCount = snapshot.omittedRecordCount + 1
            if #snapshot.omittedSamples < 10 then
                table.insert(snapshot.omittedSamples, {
                    collectibleId = tostring(record.collectibleId),
                    collectibleIdType = type(record.collectibleId),
                    referenceId = tostring(record.outfitStyleId),
                    referenceIdType = type(record.outfitStyleId),
                    itemStyleId = tostring(record.itemStyleId),
                    itemStyleIdType = type(record.itemStyleId),
                    name = record.name or "",
                })
            end
            table.insert(diagnostics, string.format(
                "Collectible %s (%s) was omitted: referenceId=%s (%s), itemStyleId=%s (%s), name=%s. IDs must be positive numbers; family was not guessed from its name.",
                tostring(record.collectibleId), type(record.collectibleId),
                tostring(record.outfitStyleId), type(record.outfitStyleId),
                tostring(record.itemStyleId), type(record.itemStyleId), record.name or ""))
        else
            local weight = LogicalWeight(record.visualArmorType, constants)
            local styleKey = familyKey
            if weight == 4 then
                styleKey = styleKey .. ":visual:" .. tostring(record.visualArmorType)
            end
            local oldKey = LegacyResolveFamily(record, constants)
            if oldKey then
                if weight == 4 then oldKey = oldKey .. ":visual:" .. tostring(record.visualArmorType) end
                snapshot.familyAliases[oldKey] = snapshot.familyAliases[oldKey] or {}
                snapshot.familyAliases[oldKey][styleKey] = true
            end
            local key = styleKey .. ":" .. tostring(weight) .. (appearance and (":" .. appearance) or "")
            local variant = byKey[key]
            if not variant then
                variant = {
                    key = key,
                    styleKey = styleKey,
                    name = familyName or "",
                    _nameRank = nameRank or 0,
                    _nameId = record.collectibleId,
                    weight = weight,
                    visualArmorType = record.visualArmorType,
                    slots = {},
                    missingSlots = {},
                    knownCount = 0,
                    partCount = 0,
                    _slotSources = {},
                    _slotCandidates = {},
                }
                byKey[key] = variant
            end

            if (nameRank or 0) > variant._nameRank
                or ((nameRank or 0) == variant._nameRank and record.collectibleId < variant._nameId) then
                variant.name, variant._nameRank, variant._nameId = familyName, nameRank or 0, record.collectibleId
            end
            for _, slot in ipairs(record.eligibleSlots or {}) do
                if armorSlotSet[slot] then
                    local candidate = {
                        collectibleId = record.collectibleId,
                        materialIndex = record.materialIndex or 1,
                        icon = record.icon,
                        unlocked = record.unlocked,
                    }
                    variant._slotCandidates[slot] = variant._slotCandidates[slot] or {}
                    variant._slotCandidates[slot][candidate.collectibleId] = candidate
                    local chosen = PreferSlotCandidate(
                        variant._slotSources[slot], candidate, slot == constants.chestSlot,
                        diagnostics, key, slot)
                    variant._slotSources[slot] = chosen
                    variant.slots[slot] = {
                        collectibleId = chosen.collectibleId,
                        materialIndex = chosen.materialIndex,
                        unlocked = chosen.unlocked,
                    }
                end
            end
        end
    end

    local variants = {}
    for _, variant in pairs(byKey) do
        for _, slot in ipairs(constants.armorSlots) do
            if variant.slots[slot] then
                variant.partCount = variant.partCount + 1
                if variant.slots[slot].unlocked then
                    variant.knownCount = variant.knownCount + 1
                end
            else
                table.insert(variant.missingSlots, slot)
            end
        end
        local candidatesBySlot = variant._slotCandidates
        variant._slotSources, variant._slotCandidates = nil, nil
        table.insert(variants, variant)
        -- Preserve every collectible, including robes and alternate gloves.
        -- Do not silently discard a collision or generate a Cartesian product.
        for slot, candidates in pairs(candidatesBySlot) do
            local chosen = variant.slots[slot]
            for id, candidate in pairs(candidates) do
                if id ~= chosen.collectibleId then
                    local alternate = {}
                    for k, v in pairs(variant) do alternate[k] = v end
                    alternate.key = variant.key .. (slot == constants.chestSlot and ":chest:" or (":slot:" .. slot .. ":")) .. id
                    alternate.slots = {}
                    for otherSlot, part in pairs(variant.slots) do alternate.slots[otherSlot] = part end
                    alternate.slots[slot] = {
                        collectibleId = id, materialIndex = candidate.materialIndex, unlocked = candidate.unlocked,
                    }
                    alternate.knownCount = variant.knownCount - (chosen.unlocked and 1 or 0) + (candidate.unlocked and 1 or 0)
                    table.insert(variants, alternate)
                end
            end
        end
    end

    local labels = {}
    for _, variant in ipairs(variants) do
        local label = labels[variant.styleKey]
        if not label or variant._nameRank > label.rank
            or (variant._nameRank == label.rank and variant._nameId < label.id) then
            labels[variant.styleKey] = {name=variant.name, rank=variant._nameRank, id=variant._nameId}
        end
    end
    for _, variant in ipairs(variants) do
        variant.name = labels[variant.styleKey].name
        variant._nameRank, variant._nameId = nil, nil
    end

    local diagnosticLimit = 25
    if #diagnostics > diagnosticLimit then
        local suppressed = #diagnostics - diagnosticLimit
        while #diagnostics > diagnosticLimit do
            table.remove(diagnostics)
        end
        table.insert(diagnostics, string.format(
            "%d additional catalog diagnostics were suppressed; inspect representative entries above.",
            suppressed))
    end

    table.sort(variants, function(left, right)
        local leftName = string.lower(left.name or "")
        local rightName = string.lower(right.name or "")
        if leftName == rightName then
            return left.key < right.key
        end
        return leftName < rightName
    end)

    snapshot.variantCount = #variants
    return variants, diagnostics, snapshot
end

function Catalog.MigratePreferences(prefs, snapshot)
    if prefs.catalogGroupingVersion == 2 or not snapshot or not snapshot.familyAliases then return end
    local aliases, incoming = snapshot.familyAliases, {}
    for old, targets in pairs(aliases) do
        for target in pairs(targets) do
            incoming[target] = incoming[target] or {}
            incoming[target][old] = true
        end
    end
    for _, field in ipairs({"favorites", "hidden", "collapsed"}) do
        local source, result = prefs[field] or {}, {}
        for key, value in pairs(source) do result[key] = value end
        for target, originals in pairs(incoming) do
            local any, all = false, true
            for old in pairs(originals) do
                any = any or source[old] == true
                all = all and source[old] == true
            end
            -- One favorited piece can favorite its family. Hiding just one piece
            -- must not silently hide the other pieces newly merged with it.
            result[target] = (field == "favorites" and any or field ~= "favorites" and all) or nil
        end
        prefs[field] = result
    end
    local order, seen = {}, {}
    for _, old in ipairs(prefs.styleOrder or {}) do
        local targets = {}
        for target in pairs(aliases[old] or {[old]=true}) do targets[#targets+1]=target end
        table.sort(targets)
        for _, target in ipairs(targets) do
            if not seen[target] then order[#order+1]=target; seen[target]=true end
        end
    end
    prefs.styleOrder = order
    prefs.catalogGroupingVersion = 2
end

function Catalog.Build()
    if not ZO_COLLECTIBLE_DATA_MANAGER
        or not ZO_COLLECTIBLE_DATA_MANAGER.GetAllCollectibleDataObjects
        or not GetEligibleOutfitSlotsForCollectible then
        Catalog.lastDiagnostics = { error = "ESO collectible catalog APIs are unavailable." }
        return {}, { "ESO collectible catalog APIs are unavailable." }
    end

    local hideSlotCollectibles = {}
    for _, slot in ipairs(MakeConstants().armorSlots) do
        local id = GetOutfitSlotDataHiddenOutfitStyleCollectibleId(slot)
        if IsPositiveId(id) then hideSlotCollectibles[id] = true end
    end
    local function IsArmorOutfitStyle(collectibleData)
        return collectibleData:IsOutfitStyle() and collectibleData:IsArmorStyle()
            and not hideSlotCollectibles[collectibleData:GetId()]
    end

    local collectibleDataObjects = ZO_COLLECTIBLE_DATA_MANAGER:GetAllCollectibleDataObjects(
        nil, { IsArmorOutfitStyle }, true)
    local records = {}
    local evidence = { version = 2, zeroStyleCount = 0, zeroStyleUnlockedCount = 0,
        positiveStyleCount = 0, positiveStyleUnlockedCount = 0,
        zeroStyleUnlockedSamples = {}, zeroStyleLockedSamples = {} }
    for _, collectibleData in ipairs(collectibleDataObjects) do
        if IsArmorOutfitStyle(collectibleData) then
            local collectibleId = collectibleData:GetId()
            local outfitStyleId = collectibleData:GetReferenceId()
            local eligibleSlots = { GetEligibleOutfitSlotsForCollectible(collectibleId) }
            local itemStyleId = collectibleData:GetOutfitStyleItemStyleId()
            local unlocked = collectibleData:IsUnlocked()
            if not IsPositiveId(itemStyleId) then
                evidence.zeroStyleCount = evidence.zeroStyleCount + 1
                if unlocked then evidence.zeroStyleUnlockedCount = evidence.zeroStyleUnlockedCount + 1 end
                local samples = unlocked and evidence.zeroStyleUnlockedSamples or evidence.zeroStyleLockedSamples
                if #samples < 25 then
                    local liveReferenceId = GetCollectibleReferenceId and GetCollectibleReferenceId(collectibleId)
                    local liveStyleId = GetOutfitStyleItemStyleId and GetOutfitStyleItemStyleId(liveReferenceId or outfitStyleId)
                    samples[#samples + 1] = {
                        collectibleId = collectibleId, referenceId = outfitStyleId,
                        cachedItemStyleId = itemStyleId, liveReferenceId = liveReferenceId,
                        liveItemStyleId = liveStyleId,
                        collectibleName = collectibleData:GetName(), icon = collectibleData:GetIcon(),
                        visualArmorType = collectibleData:GetVisualArmorType(), eligibleSlots = eligibleSlots,
                    }
                end
            else
                evidence.positiveStyleCount = evidence.positiveStyleCount + 1
                if unlocked then evidence.positiveStyleUnlockedCount = evidence.positiveStyleUnlockedCount + 1 end
            end
            table.insert(records, {
                collectibleId = collectibleId,
                outfitStyleId = outfitStyleId,
                itemStyleId = itemStyleId,
                name = collectibleData:GetOutfitStyleItemStyleName(),
                collectibleName = collectibleData:GetName(),
                visualArmorType = collectibleData:GetVisualArmorType(),
                eligibleSlots = eligibleSlots,
                icon = collectibleData:GetIcon(),
                unlocked = unlocked,
                materialIndex = ZO_OUTFIT_STYLE_DEFAULT_ITEM_MATERIAL_INDEX or 1,
            })
        end
    end

    local variants, diagnostics, snapshot = Catalog.Normalize(records)
    snapshot.nameSamples = {}
    for _, record in ipairs(records) do
        local text = string.lower((record.collectibleName or "") .. " " .. (record.icon or ""))
        if #snapshot.nameSamples < 30 and (not Nonempty(record.collectibleName)
            or text:find("gada", 1, true) or text:find("Гада", 1, true)) then
            local key, label = ResolveFamily(record, MakeConstants())
            snapshot.nameSamples[#snapshot.nameSamples + 1] = {
                collectibleId = record.collectibleId, collectibleName = record.collectibleName,
                apiName = record.name, icon = record.icon, familyKey = key, resolvedName = label,
            }
        end
    end
    snapshot.enumeratedCount = #collectibleDataObjects
    snapshot.groupingEvidence = evidence
    -- Full, replayable client evidence. Small samples missed entire filename and
    -- localization patterns, so they cannot validate whole-catalog grouping.
    snapshot.audit = {
        version = 1,
        records = records,
        constants = MakeConstants(),
        hideSlotCollectibles = hideSlotCollectibles,
    }
    Catalog.lastDiagnostics = snapshot
    return variants, diagnostics
end
