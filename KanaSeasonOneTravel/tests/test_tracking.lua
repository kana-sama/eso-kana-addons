-- Run from tests/: lua test_tracking.lua
local now, reset = 100000, 110000
local zone, x, y, z = 381, 10000, 10000, 10000
local target, targetType = "Reward Chest", 1
local participating, step = 98, 35
local journal = {}
local mailLists = {}
local handlers, updates = {}, {}
EVENT_MANAGER = {
    RegisterForEvent = function(_, _, event, fn) handlers[event] = fn end,
    RegisterForUpdate = function(_, name, _, fn) updates[name] = fn end,
    UnregisterForUpdate = function(_, name) updates[name] = nil end,
}
local events = { "PLAYER_ACTIVATED", "PLAYER_DEACTIVATED", "QUEST_ADDED", "QUEST_REMOVED",
    "WORLD_EVENT_PARTICIPATION_BEGIN", "WORLD_EVENT_STEP_CHANGED", "WORLD_EVENT_DEACTIVATED",
    "WORLD_EVENT_ACTIVATED", "WORLD_EVENT_STEP_PROGRESS_CHANGED", "LOOT_UPDATED", "LOOT_RECEIVED", "LOOT_CLOSED",
    "MAIL_LISTS_INITIALIZED", "MAIL_LISTS_UPDATED" }
for _, event in ipairs(events) do _G["EVENT_" .. event] = event end
QUEST_TYPE_FAVOR, MAX_JOURNAL_QUESTS = 20, 25
TIMED_ACTIVITY_TYPE_DAILY = 1
INTERACT_TARGET_TYPE_OBJECT, INTERACT_TARGET_TYPE_FIXTURE = 1, 2
function GetTimeStamp() return now end
function GetTimedActivityTypeResetTimeS() return reset end
function GetWorldName() return "EU Megaserver" end
function GetUnitWorldPosition() return zone, x, y, z end
function GetZoneId(index) return index end
function ZO_ExplorationUtils_GetParentZoneIdByZoneIndex(index) return index end
function GetParticipatingWorldEventStep() return participating, step end
function GetLootTargetInfo() return target, targetType, "Search", false end
function zo_strlower(s) return s:lower() end
SLASH_COMMANDS = {}
function d() end
function IsValidQuestIndex(i) return journal[i] ~= nil end
function GetJournalQuestId(i) return journal[i].id end
function GetJournalQuestType(i) return journal[i].kind end
function GetJournalQuestStartingZone(i) return journal[i].origin end
function GetQuestType(id)
    for _, q in pairs(journal) do if q.id == id then return q.kind end end
end
function GetNumMailLists() return #mailLists end
function GetMailListName(index) return mailLists[index].name end
function GetNumUnlockedMailsInMailList(index) return mailLists[index].count, mailLists[index].maximum end
local saved = { completed = {}, favors = {} }
ZO_SavedVars = { NewCharacterIdSettings = function() return saved end }
dofile("../Core.lua")
assert(type(KanaSeasonOneTravel.InitializeTracking) == "function" or loadfile("../Tracking.lua"),
    "Daily completion tracking must be implemented")
dofile("../Tracking.lua")
local addon = KanaSeasonOneTravel
addon.InitializeTracking()
local function fire(event, ...) handlers[event](event, ...) end
local function loot(self)
    fire("LOOT_UPDATED")
    fire("LOOT_RECEIVED", "player", "item", 1, 0, 0, self, false, "", 123, false)
    fire("LOOT_CLOSED")
end

-- Intermediate stage, other player's loot and opening a chest do not count.
fire("WORLD_EVENT_PARTICIPATION_BEGIN", 98, 32)
loot(true)
assert(not addon.IsDone("farm"), "Intermediate rewards must not count")
fire("WORLD_EVENT_PARTICIPATION_BEGIN", 98, 35)
fire("WORLD_EVENT_DEACTIVATED", 98)
assert(not addon.IsDone("farm"), "Completion alone must not count")
fire("LOOT_UPDATED")
fire("LOOT_CLOSED")
assert(not addon.IsDone("farm"), "Opening without taking loot must not count")
loot(false)
assert(not addon.IsDone("farm"), "Other players' loot must not count")
targetType = 9
loot(true)
assert(not addon.IsDone("farm"), "Corpse loot must not count")
targetType, target = 1, "Chest"
loot(true)
assert(not addon.IsDone("farm"), "Unidentified ordinary chest must not count")
target = "Reward Chest"
x = x + 20000
loot(true)
assert(not addon.IsDone("farm"), "A distant reward chest must not count")
x = x - 20000
loot(true)
assert(addon.IsDone("farm"), "Taking the nearby final reward must mark today")
addon.InitializeTracking()
assert(addon.IsDone("farm"), "Completion must survive reload")
now = reset
assert(not addon.IsDone("farm"), "Completion expires at the game reset")
reset = now + 86400

-- Favor origin must survive journal removal and travel to a different zone.
journal[2] = { id = 1002, kind = QUEST_TYPE_FAVOR, origin = 41 }
fire("QUEST_ADDED", 2)
journal[2] = nil
zone = 3
fire("QUEST_REMOVED", true, 2, "A favor", 3, 0, 1002)
assert(addon.IsDone("holgunn") and not addon.IsDone("arabelle"), "Use the quest origin, not the turn-in zone")
journal[4] = { id = 1004, kind = QUEST_TYPE_FAVOR, origin = 3 }
fire("QUEST_ADDED", 4)
fire("QUEST_REMOVED", false, 4, "Abandoned favor", 3, 0, 1004)
assert(not addon.IsDone("arabelle"), "Abandoning a favor must not count")
journal[5] = { id = 1005, kind = 1, origin = 381 }
fire("QUEST_ADDED", 5)
fire("QUEST_REMOVED", true, 5, "Ordinary quest", 381, 0, 1005)
assert(not addon.IsDone("urcelmo"), "Unrelated quests must not count")

-- Only the repeatable High Seas quest counts, in either supported locale.
fire("QUEST_REMOVED", true, 6, "Raising the Riotous Redress", 823, 0, 2001)
assert(not addon.IsDone("highseas"), "The introduction must not count as today's voyage")
fire("QUEST_REMOVED", false, 6, "Bounty of the Abecean Sea", 823, 0, 2002)
assert(not addon.IsDone("highseas"), "Abandoning the daily must not count")
fire("QUEST_REMOVED", true, 6, "Bounty of the Abecean Sea", 823, 0, 2002)
assert(addon.IsDone("highseas"), "Turning in the English daily must mark today")
addon.SetDone("highseas", false)
fire("QUEST_REMOVED", true, 6, "Дары Абесинского моря", 823, 0, 2002)
assert(addon.IsDone("highseas"), "Turning in the Russian daily must mark today")
addon.SetDone("highseas", false)
fire("QUEST_REMOVED", true, 6, "An unrelated Gold Coast quest", 823, 0, 2003)
assert(not addon.IsDone("highseas"), "An unrelated quest must not mark the voyage")
fire("QUEST_REMOVED", true, 6, "Дары Абесинского моря", 823, 0, 2002)
now = reset
assert(not addon.IsDone("highseas"), "The High Seas check expires at the next daily reset")
reset = now + 86400

-- Manual correction for completions before installation or unknown loot names.
addon.SetDone("arabelle", true)
assert(addon.IsDone("arabelle"))
addon.SetDone("arabelle", false)
assert(not addon.IsDone("arabelle"))

-- An old encounter / merely entering the final phase must not mark a new day.
zone, participating, step = 41, 95, 30
fire("WORLD_EVENT_PARTICIPATION_BEGIN", 95, 30)
loot(true)
assert(not addon.IsDone("bilsa"))
fire("WORLD_EVENT_DEACTIVATED", 95)
now = now + 601
loot(true)
assert(not addon.IsDone("bilsa"), "Expired final-chest context must not count")

-- The API can return 0 when daily timed activities are unavailable (U50).
zone, participating, step = 3, 96, 17
fire("WORLD_EVENT_PARTICIPATION_BEGIN", 96, 17)
fire("WORLD_EVENT_DEACTIVATED", 96)
fire("LOOT_UPDATED")
target = ""
fire("LOOT_RECEIVED", "player", "item", 1, 0, 0, true, false, "", 123, false)
assert(addon.IsDone("vampire"), "A captured loot source must survive target clearing on the last item")
fire("LOOT_CLOSED")
addon.SetDone("vampire", false)
fire("LOOT_RECEIVED", "player", "item", 1, 0, 0, true, false, "", 123, false)
assert(not addon.IsDone("vampire"), "Closed loot session must not capture unrelated items")
reset = 0
addon.SetDone("vampire", true)
assert(addon.IsDone("vampire"), "Use the server daily reset if the activities timer is unavailable")

-- The step notification can precede the participation query catching up.
-- Participation BEGIN need not fire again when an already participating player
-- advances to the final phase. Sampling the native query must recover this.
addon.SetDone("vampire", false)
saved.encounter = nil
target, targetType, zone = "Reward Chest", 1, 3
participating, step = 0, 0
fire("PLAYER_ACTIVATED")
fire("WORLD_EVENT_STEP_CHANGED", 105, 17)
participating, step = 105, 17
assert(next(updates), "Final participation needs an update after the initial step notification")
for _, update in pairs(updates) do update() end
-- The fight/escort can move the player farther than 60m from the phase start.
x = x + 10000
for _, update in pairs(updates) do update() end
fire("WORLD_EVENT_DEACTIVATED", 96)
for _, update in pairs(updates) do update() end
assert(saved.encounter.ended, "A lagging participation query must not reopen an ended encounter")
loot(true)
assert(addon.IsDone("vampire"), "Late final participation and movement must still allow the final chest")

-- An unmatched real loot name must be captured for diagnosis, not guessed.
addon.SetDone("vampire", false)
fire("WORLD_EVENT_ACTIVATED", 96)
fire("WORLD_EVENT_PARTICIPATION_BEGIN", 105, 17)
fire("WORLD_EVENT_DEACTIVATED", 96)
target = "Unrecognized reward container"
loot(true)
assert(not addon.IsDone("vampire"))
assert(saved.diagnostics and #saved.diagnostics > 0, "Keep evidence for a missed chest")
local foundName = false
for _, entry in ipairs(saved.diagnostics) do
    if entry:find(target, 1, true) then foundName = true end
end
assert(foundName, "Record the actual loot target name")
-- The encounter-specific reward is locale-independent evidence when the
-- chest label is unknown. Ordinary item receipts must not teach an alias.
fire("LOOT_RECEIVED", "player", "Shard of Parched Stone", 1, 0, 0, true, false, "", 225219, false)
assert(addon.IsDone("vampire"), "Recognize the vampire's exclusive reward by its native item ID")
addon.SetDone("vampire", false)
fire("WORLD_EVENT_ACTIVATED", 96)
fire("WORLD_EVENT_PARTICIPATION_BEGIN", 105, 17)
fire("WORLD_EVENT_DEACTIVATED", 96)
loot(true)
assert(addon.IsDone("vampire"), "Remember the actual chest name for runs without another shard")
addon.SetDone("vampire", false)
fire("LOOT_RECEIVED", "player", "Shard", 1, 0, 0, true, false, "", 225219, false)
assert(not addon.IsDone("vampire"), "The reward item without final encounter context must not mark completion")
fire("PLAYER_DEACTIVATED")
assert(not next(updates), "Stop participation sampling on loading screens")

-- Mail-list counts are per character and include favors completed before this
-- addon was installed. A completed 20-favor chain must outlive daily resets.
mailLists = {
    { name = "Battlereeve Urcelmo", count = 20, maximum = 20 },
    { name = "Holgunn One-Eye", count = 19, maximum = 20 },
    { name = "Lady Arabelle Davaux", count = 0, maximum = 20 },
}
saved = { completed = {}, favors = {} }
addon.InitializeTracking()
assert(addon.IsDone("urcelmo") and addon.IsPermanentDone("urcelmo"),
    "Existing 20/20 favors must immediately show a permanent check")
assert(not addon.IsDone("holgunn") and not addon.IsPermanentDone("holgunn"),
    "19/20 favors must not be permanent")
addon.SetDone("holgunn", true)
now = now + 86400
assert(not addon.IsDone("holgunn"), "A 19/20 daily check still expires")
addon.SetDone("urcelmo", false)
assert(addon.IsDone("urcelmo"), "Clearing today's mark and daily reset cannot erase 20/20")
mailLists[2].count = 20
fire("MAIL_LISTS_UPDATED")
assert(addon.IsPermanentDone("holgunn"), "The twentieth letter promotes the mark")
addon.InitializeTracking()
assert(addon.IsDone("holgunn"), "The permanent mark survives reload")
mailLists = {}
addon.InitializeTracking()
assert(addon.IsPermanentDone("holgunn"), "Saved 20/20 survives delayed mail-list initialization")
mailLists = { { name = "Леди Арабелла Дево", count = 20, maximum = 20 } }
fire("MAIL_LISTS_INITIALIZED")
assert(addon.IsPermanentDone("arabelle"), "Match a localized character mail list")
saved = { completed = {}, favors = {} }
mailLists = { { name = "Холгун Одноглазый", count = 3, maximum = 20 } }
addon.InitializeTracking()
assert(not addon.IsPermanentDone("urcelmo") and not addon.IsPermanentDone("holgunn")
    and not addon.IsPermanentDone("arabelle"), "Another character starts with its own progress")
print("KanaSeasonOneTravel: daily completion checks passed")
