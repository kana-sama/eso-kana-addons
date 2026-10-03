KanaQuestMap.Chronology = KanaQuestMap.Chronology or {}
local Chronology = KanaQuestMap.Chronology

Chronology.index = {}
Chronology.zoneIndex = {}
Chronology.releaseIndex = {}
Chronology.source = nil

local categories = {
  { objective = "ObjectiveLevelClassic", zone = "ZoneLevelClassic", top = "TopLevelClassic", baseGame = true },
  { objective = "ObjectiveLevelDLC", zone = "ZoneLevelDLC", top = "TopLevelDLC" },
  { objective = "ObjectiveLevelGroup", zone = "ZoneLevelGroup", top = "TopLevelGroup" },
}

local function format_name(name)
  if type(name) ~= "string" then return nil end
  if type(zo_strformat) == "function" then
    name = zo_strformat("<<1>>", name)
  else
    name = name:gsub("%^%a+", "")
  end
  return name
end

local function format_top_level(name)
  name = format_name(name)
  if not name then return nil end
  return name:gsub("^%d+:%s*", "")
end

local function is_primary_release_zone(zone)
  if type(zone) ~= "table" or zone.isDungeonDLC then return false end
  if type(zone.id) ~= "number" or type(zone.name) ~= "number" then return false end
  return zone.name == math.floor(zone.name * 10) / 10
end

local function get_release_name(zoneId, fallback)
  if type(GetZoneIndex) ~= "function" or type(GetCollectibleIdForZone) ~= "function" or type(GetCollectibleName) ~= "function" then
    return fallback
  end
  local collectibleId = GetCollectibleIdForZone(GetZoneIndex(zoneId))
  local name = collectibleId and format_name(GetCollectibleName(collectibleId)) or nil
  if type(name) == "string" and name ~= "" then return name end
  return fallback
end

function Chronology:BuildIndex(tqg)
  self.index = {}
  self.zoneIndex = {}
  self.releaseIndex = {}
  self.source = tqg
  if type(tqg) ~= "table" then return end

  local dlcZones = tqg.ZoneLevelDLC
  if type(dlcZones) == "table" then
    local releaseNumber = 0
    for progression = 1, #dlcZones do
      local zones = dlcZones[progression]
      if type(zones) == "table" then
        for zoneIndex = 1, #zones do
          local zone = zones[zoneIndex]
          if is_primary_release_zone(zone) then
            releaseNumber = releaseNumber + 1
            local zoneName = format_name(GetZoneNameById(zone.id))
            self.releaseIndex[zone.id] = {
              releaseNumber = releaseNumber,
              releaseName = get_release_name(zone.id, zoneName),
              zoneName = zoneName,
            }
          end
        end
      end
    end
  end

  for _, category in ipairs(categories) do
    local objectives = tqg[category.objective]
    local zones = tqg[category.zone]
    local topLevels = tqg[category.top]
    if type(objectives) == "table" and type(zones) == "table" then
      for progression, zoneObjectives in pairs(objectives) do
        local progressionZones = zones[progression]
        if type(zoneObjectives) == "table" and type(progressionZones) == "table" then
          for zoneIndex, steps in pairs(zoneObjectives) do
            local zone = progressionZones[zoneIndex]
            local zoneName = type(zone) == "table" and type(zone.id) == "number" and format_name(GetZoneNameById(zone.id)) or nil
            local topLevel = type(topLevels) == "table" and format_top_level(topLevels[progression]) or nil
            if type(zoneName) == "string" and zoneName ~= "" or type(topLevel) == "string" and topLevel ~= "" then
              local entry = self.releaseIndex[zone.id] or {
                baseGame = category.baseGame,
                releaseName = topLevel or zoneName,
              }
              if type(zone.id) == "number" and self.zoneIndex[zone.id] == nil then self.zoneIndex[zone.id] = entry end
              if type(steps) == "table" then
                for _, step in pairs(steps) do
                  local questId = type(step) == "table" and step.internalId or nil
                  if type(questId) == "number" and questId ~= 0 and self.index[questId] == nil then
                    self.index[questId] = entry
                  end
                end
              end
            end
          end
        end
      end
    end
  end
end

function Chronology:Get(questId)
  if self.source ~= TQG then self:BuildIndex(TQG) end
  local entry = self.index[questId]
  if entry or type(GetQuestZoneId) ~= "function" then return entry end
  return self.zoneIndex[GetQuestZoneId(questId)]
end

function Chronology:Format(questId)
  local entry = self:Get(questId)
  if not entry then return nil end
  if entry.releaseNumber then
    return string.format("Дополнение #%d - %s", entry.releaseNumber, entry.releaseName)
  end
  if entry.baseGame then
    return string.format("Базовая игра - %s", entry.releaseName)
  end
  return nil
end
