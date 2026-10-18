local Addon = KanaQuestZoneFix
local addonName = "KanaQuestZoneFix"
local visibleName = "|cFF0000Kana|r |c4488FFLibQuestData|r|cFFFFFF: quest fixes|r"

local defaults = {
    questZones = true,
    misplacedPin = true,
    alternateBranches = true,
}

function Addon:FeatureEnabled(key)
    return self.settings == nil or self.settings[key] ~= false
end

function Addon:Initialize()
    if self.initialized then return end
    self.initialized = true
    self.settings = ZO_SavedVars:NewAccountWide("KanaQuestZoneFixSaved", 1, nil, defaults)
    for key, value in pairs(defaults) do
        if self.settings[key] == nil then self.settings[key] = value end
    end
    self:InstallZoneCorrections()
    self:InstallLocationCorrection()
    self:InstallAlternativeBranchCorrection()

    if LibAddonMenu2 then
        local panelId = addonName .. "_Options"
        LibAddonMenu2:RegisterAddonPanel(panelId, {
            type = "panel", name = visibleName, displayName = visibleName, author = "Kana",
            version = "1.2.0", registerForRefresh = true,
        })
        local options = {}
        local function AddSwitch(key, label)
            options[#options + 1] = {
                type = "checkbox", name = label,
                getFunc = function() return Addon:FeatureEnabled(key) end,
                setFunc = function(value) Addon.settings[key] = value end,
                default = true, requiresReload = true,
            }
        end
        AddSwitch("questZones", "Правильные зоны заданий подземелий")
        AddSwitch("misplacedPin", "Удаление ошибочной точки в Морнхолде")
        AddSwitch("alternateBranches", "Доступность альтернативных веток заданий")
        LibAddonMenu2:RegisterOptionControls(panelId, options)
    end
end

EVENT_MANAGER:RegisterForEvent(addonName, EVENT_ADD_ON_LOADED, function(_, loadedName)
    if loadedName ~= addonName then return end
    Addon:Initialize()
    EVENT_MANAGER:UnregisterForEvent(addonName, EVENT_ADD_ON_LOADED)
end)
