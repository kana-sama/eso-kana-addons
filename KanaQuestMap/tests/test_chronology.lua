local addonRoot = arg[1] or "."

KanaQuestMap = {}
GetZoneNameById = function(zoneId)
  local names = {
    [3] = "Glenumbra^F",
    [584] = "Imperial City",
    [684] = "Wrothgar",
    [816] = "Hew's Bane",
    [823] = "Gold Coast",
  }
  if names[zoneId] then return names[zoneId] end
  return ""
end
GetQuestZoneId = function(questId)
  if questId == 7001 then return 816 end
  return 0
end
GetZoneIndex = function(zoneId) return zoneId end
GetCollectibleIdForZone = function(zoneIndex) return zoneIndex end
GetCollectibleName = function(collectibleId)
  local names = {
    [816] = "Thieves Guild",
    [823] = "Dark Brotherhood",
  }
  return names[collectibleId] or ""
end

dofile(addonRoot .. "/Chronology.lua")

local tqg = {
  ZoneLevelDLC = { [1] = {
    [1] = { name = 4, id = 584 },
    [2] = { name = 4.1, id = 684 },
    [3] = { name = 4.2, id = 816 },
    [4] = { name = 4.3, id = 823 },
  } },
  ZoneLevelClassic = { [1] = {
    [1] = { name = 1.1, id = 3 },
  }, [5] = {
    [1] = { name = "(1.00) Invitation", id = "Fighters Guild description" },
  }, [6] = {
    [1] = { name = "(1.00) Invitation", id = "Mages Guild description" },
  } },
  TopLevelClassic = {
    [1] = "1: Daggerfall Covenant",
    [5] = "1: Fighters Guild",
    [6] = "1: Mages Guild",
  },
  ObjectiveLevelDLC = { [1] = {
    [1] = { [1] = { internalId = 0 } },
    [3] = { [1] = { internalId = 9001 } },
  } },
  ObjectiveLevelClassic = { [1] = {
    [1] = { [1] = { internalId = 5001 } },
  }, [5] = {
    [1] = { [1] = { internalId = 5077 } },
  }, [6] = {
    [1] = { [1] = { internalId = 5076 } },
  } },
}

TQG = tqg
KanaQuestMap.Chronology:BuildIndex(tqg)
assert(
  KanaQuestMap.Chronology:Format(9001) ==
    "Дополнение #3 - Thieves Guild",
  "direct TQG quest must use the DLC release number"
)
assert(
  KanaQuestMap.Chronology:Format(7001) ==
    "Дополнение #3 - Thieves Guild",
  "side quest must use its zone DLC release number"
)
assert(
  KanaQuestMap.Chronology:Format(5001) ==
    "Базовая игра - Daggerfall Covenant",
  "base game quest must use its campaign name without TQG order or ESO grammar suffix"
)
assert(
  KanaQuestMap.Chronology:Format(5077) ==
    "Базовая игра - Fighters Guild",
  "Basile's Invitation must use the base-game Fighters Guild label"
)
assert(
  KanaQuestMap.Chronology:Format(5076) ==
    "Базовая игра - Mages Guild",
  "Nemarc's Invitation must use the base-game Mages Guild label"
)
assert(KanaQuestMap.Chronology:Format(0) == nil, "internalId 0 is not a quest")
assert(KanaQuestMap.Chronology:Format(9999) == nil, "unknown quest has no chronology")

KanaQuestMap.Chronology:BuildIndex(nil)
TQG = nil
assert(KanaQuestMap.Chronology:Format(9001) == nil, "missing TQG must be safe")

print("PASS: chronology adapter")
