local addon = KanaSeasonOneTravel
local saved, lootKey
local scanName = "KanaSeasonOneTravelParticipation"
local favorZones = { [381] = "urcelmo", [41] = "holgunn", [3] = "arabelle" }
local favorMailNames = {
    urcelmo = { "urcelmo", "урсельмо", "Урсельмо" },
    holgunn = { "holgunn", "холгун", "Холгун" },
    arabelle = { "arabelle", "арабелл", "Арабелл" },
}
-- English client name and the current Russian localization of the daily quest.
local highSeasDailyNames = { ["Bounty of the Abecean Sea"] = true,
    ["Дары Абесинского моря"] = true }
local vaultAchievementId

-- The final secret achievement grants a Quasigriff and has four criteria and
-- 50 points. Identify that combination across localized achievement names;
-- Legend of the Nowhere Vault is the different room-completion achievement.
local function FindVaultAchievement()
    if vaultAchievementId then return end
    for category = 1, GetNumAchievementCategories() do
        local _, subcategoryCount, achievementCount = GetAchievementCategoryInfo(category)
        for subcategory = 0, subcategoryCount do
            local count = subcategory == 0 and achievementCount
                or select(2, GetAchievementSubCategoryInfo(category, subcategory))
            for index = 1, count do
                local id = GetAchievementId(category, subcategory, index)
                if id then
                    local hasReward, collectibleId = GetAchievementRewardCollectible(id)
                    if hasReward and collectibleId and collectibleId > 0 then
                        local name = zo_strlower(GetCollectibleName(collectibleId) or "")
                        local _, _, points = GetAchievementInfo(id)
                        if points == 50 and GetAchievementNumCriteria(id) == 4
                            and (name:find("quasigriff", 1, true)
                                or name:find("квазигриф", 1, true)) then
                            vaultAchievementId = id
                            return
                        end
                    end
                end
            end
        end
    end
end

-- Observed U50 parent instances and final participation steps; see SOURCES.md.
-- Deactivation alone is not completion: the player must subsequently take loot.
local encounters = {
    farm = { zone = 381, parent = 98, finalStep = 35, children = { [131] = true } },
    bilsa = { zone = 41, parent = 95, finalStep = 30,
        children = { [106] = true, [107] = true, [108] = true, [109] = true, [110] = true, [112] = true } },
    vampire = { zone = 3, parent = 96, finalStep = 17, rewardItemId = 225219,
        children = { [99] = true, [100] = true, [101] = true, [102] = true, [103] = true, [104] = true, [105] = true } },
}

local function Refresh()
    if addon.Refresh then addon.Refresh() end
end

local function Trace(event, details)
    local zone = GetUnitWorldPosition("player")
    if not favorZones[zone] then return end
    local context = saved.encounter
    local instance, step = GetParticipatingWorldEventStep()
    local message = string.format("%s %s zone=%s participation=%s/%s context=%s ended=%s %s",
        tostring(GetTimeStamp()), event, tostring(zone), tostring(instance), tostring(step),
        context and context.key or "none", tostring(context and context.ended), details or "")
    saved.diagnostics = saved.diagnostics or {}
    table.insert(saved.diagnostics, message)
    if #saved.diagnostics > 100 then table.remove(saved.diagnostics, 1) end
end

local function NextReset()
    local now = GetTimeStamp()
    local reset = GetTimedActivityTypeResetTimeS(TIMED_ACTIVITY_TYPE_DAILY)
    if reset and reset > now and reset <= now + 86400 then return reset end
    -- Daily quests reset at 03:00 UTC on EU, 10:00 UTC on NA. U50 may
    -- have no daily timed activities, in which case their API returns 0.
    local hour = GetWorldName():find("EU", 1, true) and 3 or 10
    local offset = hour * 3600
    return math.floor((now - offset) / 86400) * 86400 + offset + 86400
end

local function RefreshPermanentFavors()
    local changed = false
    for index = 1, GetNumMailLists() do
        local name = zo_strlower(GetMailListName(index) or "")
        local count = GetNumUnlockedMailsInMailList(index)
        if count and count >= 20 then
            for key, aliases in pairs(favorMailNames) do
                for _, alias in ipairs(aliases) do
                    if name:find(alias, 1, true) and not saved.permanent[key] then
                        saved.permanent[key] = true
                        changed = true
                    end
                end
            end
        end
    end
    if changed then Refresh() end
end

function addon.IsPermanentDone(key)
    return saved.permanent[key] == true
end

function addon.IsDone(key)
    if key == "nowhere" then
        return vaultAchievementId ~= nil and IsAchievementComplete(vaultAchievementId)
    end
    if addon.IsPermanentDone(key) then return true end
    local expiry = saved.completed[key]
    return type(expiry) == "number" and expiry > GetTimeStamp()
end

function addon.SetDone(key, complete)
    if key == "nowhere" or not addon.destinations[key] then return end
    saved.completed[key] = complete and NextReset() or nil
    Refresh()
end

local function FavorKey(zoneIndex)
    if not zoneIndex or zoneIndex == 0 then return end
    return favorZones[GetZoneId(zoneIndex)]
        or favorZones[ZO_ExplorationUtils_GetParentZoneIdByZoneIndex(zoneIndex)]
end

local function RememberFavor(index)
    if IsValidQuestIndex(index) and GetJournalQuestType(index) == QUEST_TYPE_FAVOR then
        local key = FavorKey(GetJournalQuestStartingZone(index))
        if key then saved.favors[GetJournalQuestId(index)] = key end
    end
end

local function ScanJournal()
    local previous = saved.favors
    saved.favors = {}
    for index = 1, MAX_JOURNAL_QUESTS do
        if IsValidQuestIndex(index) then
            local id = GetJournalQuestId(index)
            saved.favors[id] = previous[id]
            RememberFavor(index)
        end
    end
end

local function QuestRemoved(_, completed, index, name, zoneIndex, poiIndex, questId)
    local key = saved.favors[questId]
    saved.favors[questId] = nil
    -- Covers instantly completed board requests which never entered the journal.
    if not key and GetQuestType(questId) == QUEST_TYPE_FAVOR then
        key = FavorKey(zoneIndex)
    end
    if not key and highSeasDailyNames[name] then key = "highseas" end
    if completed and key then addon.SetDone(key, true) end
end

local function Participation(_, instanceId, stepId)
    local zone, x, y, z = GetUnitWorldPosition("player")
    for key, encounter in pairs(encounters) do
        if zone == encounter.zone and stepId == encounter.finalStep
            and (instanceId == encounter.parent or encounter.children[instanceId]) then
            local context = saved.encounter
            -- A delayed native query can still return the last phase after
            -- deactivation. Never turn an awaiting-chest state back into a fight.
            if context and context.key == key and context.ended then return end
            if context and context.key == key then
                context.x, context.y, context.z = x, y, z
                context.expires = GetTimeStamp() + 600
                return
            end
            saved.encounter = {
                key = key, zone = zone, x = x, y = y, z = z,
                expires = GetTimeStamp() + 600, ended = false,
            }
            Trace("final-participation", "instance=" .. tostring(instanceId))
            return
        end
    end
end

local function SampleParticipation()
    local instance, step = GetParticipatingWorldEventStep()
    Participation(nil, instance, step)
end

local function NearEncounter(context)
    local zone, x, y, z = GetUnitWorldPosition("player")
    -- ESO world coordinates are centimetres. Keep the loot near the end position.
    return zone == context.zone
        and (x - context.x)^2 + (y - context.y)^2 + (z - context.z)^2 <= 6000^2
end

local function EventEnded(_, instanceId)
    Trace("deactivated", "instance=" .. tostring(instanceId))
    SampleParticipation()
    local context = saved.encounter
    if not context or context.ended or context.expires <= GetTimeStamp() then return end
    if instanceId ~= encounters[context.key].parent or not NearEncounter(context) then return end
    context.zone, context.x, context.y, context.z = GetUnitWorldPosition("player")
    context.ended = true
    context.expires = GetTimeStamp() + 180
    Trace("awaiting-chest")
    -- Intentionally no checkmark here: the reward may never be collected.
end

local function IsRewardChest(key)
    local name, targetType = GetLootTargetInfo()
    if targetType ~= INTERACT_TARGET_TYPE_OBJECT and targetType ~= INTERACT_TARGET_TYPE_FIXTURE then return false end
    name = zo_strlower(name or "")
    -- Deliberately exclude generic treasure chests and corpses. Unknown names
    -- remain unmarked; the checkbox allows correction without inventing a reward.
    return name:find("reward chest", 1, true) ~= nil
        or name:find("сундук с наград", 1, true) ~= nil
        or (saved.rewardChestNames[key] and saved.rewardChestNames[key][name] == targetType) == true
end

local function ObserveLoot()
    lootKey = nil
    local context = saved.encounter
    if context and context.ended and context.expires > GetTimeStamp()
        and NearEncounter(context) and IsRewardChest(context.key) then
        lootKey = context.key
    end
    local name, targetType = GetLootTargetInfo()
    Trace("loot-source", string.format("name=%s type=%s matched=%s near=%s expired=%s",
        tostring(name), tostring(targetType), tostring(lootKey),
        tostring(context and NearEncounter(context)), tostring(context and context.expires <= GetTimeStamp())))
end

local function LootReceived(_, recipient, item, quantity, sound, lootType, self, pickpocket, questIcon, itemId)
    if not self or pickpocket or quantity <= 0 then return end
    -- Query at receipt as well: automatic looting may not display a loot window.
    -- The target may already be empty when the last item arrives; retain the
    -- source captured by LOOT_UPDATED until LOOT_CLOSED, never across sessions.
    local name = GetLootTargetInfo()
    if name and name ~= "" then ObserveLoot() end
    local context = saved.encounter
    local eligible = context and context.ended and context.expires > GetTimeStamp() and NearEncounter(context)
    if not eligible then lootKey = nil end
    -- Shard of Parched Stone: encounter-specific loot, identified by the client
    -- item ID, not a translated name. Still require the observed final phase,
    -- encounter end and nearby personal loot; inventory updates are not used.
    if eligible and itemId and encounters[context.key].rewardItemId == itemId then
        lootKey = context.key
        local name, targetType = GetLootTargetInfo()
        if name and name ~= "" and (targetType == INTERACT_TARGET_TYPE_OBJECT
            or targetType == INTERACT_TARGET_TYPE_FIXTURE) then
            saved.rewardChestNames[context.key] = saved.rewardChestNames[context.key] or {}
            saved.rewardChestNames[context.key][zo_strlower(name)] = targetType
            Trace("reward-chest-learned", "name=" .. name .. " item=" .. tostring(itemId))
        end
    end
    if lootKey then
        Trace("marked-from-loot", lootKey)
        addon.SetDone(lootKey, true)
        saved.encounter = nil
        lootKey = nil
    end
end

function addon.InitializeTracking()
    saved = ZO_SavedVars:NewCharacterIdSettings("KanaSeasonOneTravelSaved", 1, nil,
        { completed = {}, permanent = {}, favors = {}, diagnostics = {}, rewardChestNames = {} }, GetWorldName())
    saved.permanent = saved.permanent or {}
    saved.rewardChestNames = saved.rewardChestNames or {}
    saved.diagnostics = saved.diagnostics or {}
    lootKey = nil
    FindVaultAchievement()
    local function Register(event, callback)
        EVENT_MANAGER:RegisterForEvent("KanaSeasonOneTravelTracking", event, callback)
    end
    Register(EVENT_QUEST_ADDED, function(_, index) RememberFavor(index) end)
    Register(EVENT_QUEST_REMOVED, QuestRemoved)
    Register(EVENT_MAIL_LISTS_INITIALIZED, RefreshPermanentFavors)
    Register(EVENT_MAIL_LISTS_UPDATED, RefreshPermanentFavors)
    Register(EVENT_ACHIEVEMENTS_UPDATED, function()
        FindVaultAchievement()
        Refresh()
    end)
    Register(EVENT_ACHIEVEMENT_AWARDED, function(_, _, _, id)
        if not vaultAchievementId then FindVaultAchievement() end
        if id == vaultAchievementId then Refresh() end
    end)
    Register(EVENT_WORLD_EVENT_PARTICIPATION_BEGIN, function(event, instance, step)
        Trace("participation-begin", string.format("instance=%s step=%s", tostring(instance), tostring(step)))
        Participation(event, instance, step)
    end)
    Register(EVENT_WORLD_EVENT_STEP_CHANGED, function(_, instance, newStep)
        Trace("step-changed", string.format("instance=%s step=%s", tostring(instance), tostring(newStep)))
        local participating = GetParticipatingWorldEventStep()
        if participating == instance then Participation(nil, instance, newStep) end
    end)
    Register(EVENT_WORLD_EVENT_STEP_PROGRESS_CHANGED, SampleParticipation)
    Register(EVENT_WORLD_EVENT_DEACTIVATED, EventEnded)
    Register(EVENT_WORLD_EVENT_ACTIVATED, function(_, instance)
        local context = saved.encounter
        if context and instance == encounters[context.key].parent then saved.encounter = nil end
    end)
    Register(EVENT_PLAYER_DEACTIVATED, function()
        lootKey = nil
        EVENT_MANAGER:UnregisterForUpdate(scanName)
    end)
    Register(EVENT_PLAYER_ACTIVATED, function()
        ScanJournal()
        RefreshPermanentFavors()
        local context = saved.encounter
        if context and (context.expires <= GetTimeStamp() or not NearEncounter(context)) then
            saved.encounter = nil
        end
        local instance, step = GetParticipatingWorldEventStep()
        if not saved.encounter or not saved.encounter.ended then Participation(nil, instance, step) end
        EVENT_MANAGER:UnregisterForUpdate(scanName)
        local zone = GetUnitWorldPosition("player")
        if favorZones[zone] then
            -- STEP_CHANGED can arrive before the participation query updates.
            -- Polling also keeps the position current during moving encounters.
            EVENT_MANAGER:RegisterForUpdate(scanName, 500, SampleParticipation)
        end
        Refresh()
    end)
    Register(EVENT_LOOT_UPDATED, ObserveLoot)
    Register(EVENT_LOOT_RECEIVED, LootReceived)
    Register(EVENT_LOOT_CLOSED, function() lootKey = nil end)
    SLASH_COMMANDS["/kstdebug"] = function()
        for index = math.max(1, #saved.diagnostics - 9), #saved.diagnostics do
            d(saved.diagnostics[index])
        end
    end
    ScanJournal()
    RefreshPermanentFavors()
end
