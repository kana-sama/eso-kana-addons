GetOutfitSlotDataHiddenOutfitStyleCollectibleId = function() return 0 end
local function fail(message)
    error(message, 2)
end

local function assertEqual(actual, expected, message)
    if actual ~= expected then
        fail(string.format("%s: expected %s, got %s", message or "values differ", tostring(expected), tostring(actual)))
    end
end

local function assertTruthy(value, message)
    if not value then
        fail(message or "expected truthy value")
    end
end

local function findByKey(variants, key)
    for _, variant in ipairs(variants) do
        if variant.key == key then
            return variant
        end
    end
end

local function containsDiagnostic(diagnostics, fragment)
    for _, diagnostic in ipairs(diagnostics) do
        if string.find(diagnostic, fragment, 1, true) then
            return true
        end
    end
    return false
end

local CONSTANTS = {
    visualArmorTypeLight = 11,
    visualArmorTypeMedium = 22,
    visualArmorTypeHeavy = 33,
    armorSlots = { 101, 102, 103, 104, 105, 106, 107 },
    chestSlot = 102,
}

KanaOutfitBrowser = nil
dofile("KanaOutfitBrowser/Catalog.lua")
local Catalog = assert(KanaOutfitBrowser and KanaOutfitBrowser.Catalog, "Catalog module must exist")

local tests = {}

function tests.groups_by_item_style_and_visual_weight_while_preserving_collectible_ids()
    local records = {
        { collectibleId = 5001, outfitStyleId = 9001, itemStyleId = 77, name = "Breton", visualArmorType = 11, eligibleSlots = { 101 }, icon = "head.dds", unlocked = true },
        { collectibleId = 5002, outfitStyleId = 9002, itemStyleId = 77, name = "Breton", visualArmorType = 11, eligibleSlots = { 102 }, icon = "gear_breton_light_robe_a.dds", unlocked = true },
        { collectibleId = 5003, outfitStyleId = 9003, itemStyleId = 77, name = "Breton", visualArmorType = 11, eligibleSlots = { 102 }, icon = "gear_breton_light_chest_a.dds", unlocked = false },
        { collectibleId = 5004, outfitStyleId = 9004, itemStyleId = 77, name = "Breton", visualArmorType = 11, eligibleSlots = { 103 }, icon = "shoulder.dds", unlocked = true },
        { collectibleId = 5101, outfitStyleId = 9101, itemStyleId = 77, name = "Breton", visualArmorType = 22, eligibleSlots = { 101 }, icon = "head.dds" },
        { collectibleId = 5201, outfitStyleId = 9201, itemStyleId = 77, name = "Breton", visualArmorType = 33, eligibleSlots = { 101 }, icon = "head.dds" },
    }

    local variants, diagnostics = Catalog.Normalize(records, CONSTANTS)
    assertEqual(#variants, 4, "three weights and a robe alternative remain in one family")

    local light = assert(findByKey(variants, "itemstyle:77:1"), "light variant missing")
    assertEqual(light.styleKey, "itemstyle:77", "standard weights share the item-style family")
    assertEqual(light.weight, 1, "light logical weight")
    assertEqual(light.slots[101].collectibleId, 5001, "preview payload uses collectible id")
    assertEqual(light.slots[102].collectibleId, 5003, "canonical chest icon wins over robe icon")
    assertEqual(light.knownCount, 2, "known count follows learned chosen parts, not geometry")
    assertEqual(light.partCount, 3, "part count follows parts actually supplied by this style")
    assertEqual(#light.missingSlots, 4, "sparse variant reports missing slots")
    assertTruthy(containsDiagnostic(diagnostics, "icon heuristic"), "chest heuristic must be diagnosed")

    assertTruthy(findByKey(variants, "itemstyle:77:2"), "medium variant missing")
    assertTruthy(findByKey(variants, "itemstyle:77:3"), "heavy variant missing")
end

function tests.omits_zero_or_missing_style_ids_instead_of_cross_mixing_them()
    local records = {
        { collectibleId = 6001, outfitStyleId = 0, itemStyleId = 0, name = "Unknown A", visualArmorType = 11, eligibleSlots = { 101 } },
        { collectibleId = 6002, outfitStyleId = nil, itemStyleId = nil, name = "Unknown B", visualArmorType = 11, eligibleSlots = { 102 } },
    }

    local variants, diagnostics = Catalog.Normalize(records, CONSTANTS)
    assertEqual(#variants, 0, "unresolvable styles are not grouped into style zero")
    assertTruthy(containsDiagnostic(diagnostics, "6001"), "first omitted collectible is diagnosed")
    assertTruthy(containsDiagnostic(diagnostics, "6002"), "second omitted collectible is diagnosed")
end

function tests.records_bounded_raw_id_evidence_without_guessing_catalog_families()
    local records = {}
    for index = 1, 35 do
        records[index] = {
            collectibleId = 1597 + index,
            outfitStyleId = 500 + index,
            itemStyleId = 0,
            name = "Unknown native family",
            visualArmorType = 11,
            eligibleSlots = { 101 },
        }
    end
    records[2].outfitStyleId = "502"
    records[3].outfitStyleId = nil
    local variants, diagnostics, snapshot = Catalog.Normalize(records, CONSTANTS)
    assertEqual(#variants, 0, "diagnostic capture does not invent families")
    assertEqual(snapshot.recordCount, 35, "records considered are counted")
    assertEqual(snapshot.omittedRecordCount, 35, "every omission is counted even beyond sample limit")
    assertEqual(snapshot.variantCount, 0, "produced variants are counted")
    assertEqual(#snapshot.omittedSamples, 10, "saved raw evidence is bounded")
    assertEqual(snapshot.omittedSamples[1].collectibleId, "1598", "native collectible ID retained")
    assertEqual(snapshot.omittedSamples[1].referenceId, "501", "reference ID retained")
    assertEqual(snapshot.omittedSamples[1].itemStyleId, "0", "failing item-style value retained")
    assertEqual(snapshot.omittedSamples[2].referenceIdType, "string", "string IDs remain distinguishable")
    assertEqual(snapshot.omittedSamples[3].referenceIdType, "nil", "missing IDs remain distinguishable")
    assertTruthy(containsDiagnostic(diagnostics, "referenceId=501 (number), itemStyleId=0 (number)"), "text diagnostic identifies the failing field")
end

function tests.keeps_nontraditional_visual_types_in_distinct_unified_families()
    local records = {
        { collectibleId = 7001, outfitStyleId = 9701, itemStyleId = 88, name = "Signature", visualArmorType = 44, eligibleSlots = { 101 } },
        { collectibleId = 7002, outfitStyleId = 9702, itemStyleId = 88, name = "Signature", visualArmorType = 55, eligibleSlots = { 102 } },
    }

    local variants = Catalog.Normalize(records, CONSTANTS)
    assertEqual(#variants, 2, "raw nontraditional armor types cannot collide")
    local first = assert(findByKey(variants, "itemstyle:88:visual:44:4"), "first unified type missing")
    local second = assert(findByKey(variants, "itemstyle:88:visual:55:4"), "second unified type missing")
    assertEqual(first.styleKey, "itemstyle:88:visual:44", "raw type is part of first family")
    assertEqual(second.styleKey, "itemstyle:88:visual:55", "raw type is part of second family")
    assertEqual(first.weight, 4, "nontraditional variants use unified logical weight")
end

function tests.does_not_merge_distinct_ids_that_share_a_localized_name()
    local variants = Catalog.Normalize({
        { collectibleId = 8001, outfitStyleId = 9801, itemStyleId = 91, name = "Same Name", visualArmorType = 11, eligibleSlots = { 101 } },
        { collectibleId = 8002, outfitStyleId = 9802, itemStyleId = 92, name = "Same Name", visualArmorType = 11, eligibleSlots = { 102 } },
    }, CONSTANTS)

    assertEqual(#variants, 2, "localized names are labels, not grouping keys")
    assertTruthy(findByKey(variants, "itemstyle:91:1"), "first stable family missing")
    assertTruthy(findByKey(variants, "itemstyle:92:1"), "second stable family missing")
end

function tests.build_uses_native_ids_methods_filters_and_vararg_slots()
    VISUAL_ARMOR_TYPE_LIGHT = nil
    VISUAL_ARMOR_TYPE_MEDIUM = nil
    VISUAL_ARMOR_TYPE_HEAVY = nil
    VISUAL_ARMORTYPE_LIGHT = 11
    VISUAL_ARMORTYPE_MEDIUM = 22
    VISUAL_ARMORTYPE_HEAVY = 33
    OUTFIT_SLOT_HEAD = 101
    OUTFIT_SLOT_CHEST = 102
    OUTFIT_SLOT_SHOULDERS = 103
    OUTFIT_SLOT_HANDS = 104
    OUTFIT_SLOT_WAIST = 105
    OUTFIT_SLOT_LEGS = 106
    OUTFIT_SLOT_FEET = 107
    ZO_OUTFIT_STYLE_DEFAULT_ITEM_MATERIAL_INDEX = 1

    local data = {
        IsOutfitStyle = function() return true end,
        IsArmorStyle = function() return true end,
        GetId = function() return 8101 end,
        GetName = function() return "Native Head" end,
        GetReferenceId = function() return 18101 end,
        GetOutfitStyleItemStyleId = function() return 123 end,
        GetOutfitStyleItemStyleName = function() return "Native Family" end,
        GetVisualArmorType = function() return 22 end,
        GetIcon = function() return "native_head.dds" end,
        IsUnlocked = function() return false end,
    }
    local observedSorted
    local observedFilters
    ZO_COLLECTIBLE_DATA_MANAGER = {
        GetAllCollectibleDataObjects = function(_, categoryFilters, collectibleFilters, sorted)
            assertEqual(categoryFilters, nil, "all categories are eligible for the collectible filters")
            observedSorted = sorted
            observedFilters = collectibleFilters
            return { data }
        end,
    }
    GetEligibleOutfitSlotsForCollectible = function(collectibleId)
        assertEqual(collectibleId, 8101, "eligible slots query takes collectible id")
        return 101, 999
    end

    local variants = Catalog.Build()
    assertEqual(observedSorted, true, "native collection requests stable native sorting")
    assertEqual(#observedFilters, 1, "one armor-style filter is supplied")
    assertTruthy(observedFilters[1](data), "native armor style passes filter")
    assertEqual(#variants, 1, "one data object produces one sparse variant")
    local variant = assert(findByKey(variants, "itemstyle:123:2"), "native medium variant missing")
    assertEqual(variant.slots[101].collectibleId, 8101, "collectible ID is kept for preview")
    assertEqual(variant.slots[101].materialIndex, 1, "default material index is explicit")
    assertEqual(variant.knownCount, 0, "locked parts are not counted as learned")
    assertEqual(variant.partCount, 1, "non-armor eligible slots are ignored")
    assertEqual(Catalog.lastDiagnostics.enumeratedCount, 1, "native enumeration count is retained")
    assertEqual(Catalog.lastDiagnostics.recordCount, 1, "normalized input count is retained")
    assertEqual(Catalog.lastDiagnostics.variantCount, 1, "native build result count is retained")
    assertEqual(Catalog.lastDiagnostics.omittedRecordCount, 0, "valid native data records no omission")
end

function tests.zero_style_diagnostics_distinguish_learned_parts_and_live_api()
    tests.build_uses_native_ids_methods_filters_and_vararg_slots()
    local data = ZO_COLLECTIBLE_DATA_MANAGER:GetAllCollectibleDataObjects(nil, {}, true)[1]
    data.GetOutfitStyleItemStyleId = function() return 0 end
    data.GetOutfitStyleItemStyleName = function() return "" end
    data.GetName = function() return "Redguard Gloves 1" end
    data.IsUnlocked = function() return true end
    GetCollectibleReferenceId = function(id) assertEqual(id,8101); return 18101 end
    GetOutfitStyleItemStyleId = function(id) assertEqual(id,18101); return 0 end
    local variants = Catalog.Build()
    local evidence = Catalog.lastDiagnostics.groupingEvidence
    assertEqual(#variants,1,"unrecognized texture remains a standalone entry")
    assertEqual(variants[1].styleKey,"collectible:8101","unknown families never merge")
    assertEqual(evidence.zeroStyleUnlockedCount,1,"learned omission counted separately")
    assertEqual(evidence.zeroStyleUnlockedSamples[1].collectibleName,"Redguard Gloves 1")
    assertEqual(evidence.zeroStyleUnlockedSamples[1].liveItemStyleId,0,"direct API result retained")
    assertEqual(evidence.zeroStyleUnlockedSamples[1].icon,"native_head.dds")
    GetCollectibleReferenceId, GetOutfitStyleItemStyleId = nil, nil
end

function tests.texture_fallback_keeps_weights_slots_and_appearance_ranks()
    local records = {}
    for weight, word in ipairs({"light", "medium", "heavy"}) do
        for rank, suffix in ipairs({"b", "c", "d"}) do
            for slot, part in ipairs({"head", "chest", "shoulders", "hands", "waist", "legs", "feet"}) do
                records[#records+1] = {collectibleId=#records+1, outfitStyleId=#records+100,
                    itemStyleId=0, name="", collectibleName="Бретонский тяжелый шлем "..rank,
                    visualArmorType=weight*11, eligibleSlots={100+slot}, unlocked=true,
                    icon="/esoui/art/icons/gear_breton_"..word.."_"..part.."_"..suffix..".dds"}
            end
        end
    end
    local variants, _, snapshot = Catalog.Normalize(records, CONSTANTS)
    assertEqual(#variants,9,"three weights times three appearances")
    assertEqual(snapshot.omittedRecordCount,0,"zero engine IDs no longer lose these records")
    for _, v in ipairs(variants) do
        assertEqual(v.styleKey,"texture:breton")
        assertEqual(v.name,"Бретонский")
        assertEqual(v.partCount,7)
        assertEqual(v.knownCount,7,"learned pieces survive grouping")
    end
end

function tests.unknown_textures_do_not_merge_by_localized_name()
    local records={}
    for i=1,2 do records[i]={collectibleId=i,outfitStyleId=i+100,itemStyleId=0,
        collectibleName="Same name",icon="/odd_"..i..".dds",eligibleSlots={101},visualArmorType=11} end
    local variants=Catalog.Normalize(records,CONSTANTS)
    assertEqual(#variants,2)
    assertTruthy(variants[1].styleKey~=variants[2].styleKey)
end

function tests.empty_names_fall_back_without_changing_native_family_identity()
    local variants = Catalog.Normalize({
        {collectibleId=9001,outfitStyleId=101,itemStyleId=55,name="",collectibleName="Шлем Ра Гада",
            icon="/esoui/art/icons/gear_ragada_heavy_head_a.dds",visualArmorType=33,eligibleSlots={101}},
        {collectibleId=9002,outfitStyleId=102,itemStyleId=56,name="",collectibleName="",
            icon="/unknown.dds",visualArmorType=33,eligibleSlots={101}},
        {collectibleId=9003,outfitStyleId=103,itemStyleId=0,name="",collectibleName="",
            icon="/esoui/art/icons/gear_ragada_heavy_head_a.dds",visualArmorType=33,eligibleSlots={101}},
    },CONSTANTS)
    assertEqual(findByKey(variants,"itemstyle:55:3").name,"Ра Гада")
    assertEqual(findByKey(variants,"itemstyle:56:3").name,"Стиль #56")
    assertEqual(findByKey(variants,"texture:ragada:3:a").name,"ragada")
end

function tests.localized_piece_prefixes_group_unknown_icons_by_family_and_weight()
    local records = {}
    local names = {"Шлем", "Камзол", "Эполеты", "Наручи", "Пояс", "Брюки", "Сапоги"}
    for weight=1,3 do
        for slot,noun in ipairs(names) do
            records[#records+1]={collectibleId=#records+1,outfitStyleId=#records+100,itemStyleId=0,
                collectibleName=noun.." жрецов Новой Луны", icon="/nonstandard"..#records..".dds",
                eligibleSlots={100+slot}, visualArmorType=weight*11,unlocked=true}
        end
    end
    local variants = Catalog.Normalize(records,CONSTANTS)
    assertEqual(#variants,3)
    for _,variant in ipairs(variants) do
        assertEqual(variant.name,"жрецов Новой Луны")
        assertEqual(variant.partCount,7)
        assertEqual(variant.knownCount,7)
    end
    records[1].eligibleSlots={102} -- a head-like word on a chest item is not stripped
    local mismatch=Catalog.Normalize({records[1]},CONSTANTS)
    assertEqual(mismatch[1].styleKey,"collectible:1")
end

function tests.new_moon_remaining_piece_names_join_existing_family_without_losing_robe()
    local records={}
    local names={"Камзол", "Куртка", "Мантия", "Латные перчатки", "Кираса"}
    local weights={11,22,11,33,33}
    for i,name in ipairs(names) do
        records[i]={collectibleId=100+i,outfitStyleId=200+i,itemStyleId=0,
            collectibleName=name.." жрецов Новой Луны",icon="/nonstandard"..i..".dds",
            eligibleSlots={i==4 and 104 or 102},visualArmorType=weights[i],unlocked=true}
    end
    local variants=Catalog.Normalize(records,CONSTANTS)
    assertEqual(#variants,4,"three weights plus an alternate light chest")
    local found={}
    for _,v in ipairs(variants) do
        assertEqual(v.styleKey,"name:жрецов Новой Луны")
        for _,part in pairs(v.slots) do found[part.collectibleId]=true end
    end
    for i=1,5 do assertTruthy(found[100+i],"every original part remains accessible") end
end

function tests.build_excludes_native_hide_slot_actions_by_id_not_localized_name()
    tests.build_uses_native_ids_methods_filters_and_vararg_slots()
    GetOutfitSlotDataHiddenOutfitStyleCollectibleId=function(slot) return slot==101 and 8101 or 0 end
    local variants=Catalog.Build()
    assertEqual(#variants,0,"native hide action must not form a set")
    assertEqual(Catalog.lastDiagnostics.recordCount,0,"excluded before grouping and progress counts")
    GetOutfitSlotDataHiddenOutfitStyleCollectibleId=function() return 0 end
end

local passed = 0
for name, test in pairs(tests) do
    local ok, err = pcall(test)
    if not ok then
        io.stderr:write("FAIL ", name, ": ", tostring(err), "\n")
        os.exit(1)
    end
    passed = passed + 1
end

print(string.format("test_catalog.lua: %d tests passed", passed))
