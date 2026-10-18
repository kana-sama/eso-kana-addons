local ADDON_NAME = 'KanaSkillTranslations'
-- Capture during file loading: Ninja's EVENT_ADD_ON_LOADED creates a LAM
-- panel also named NameLanguageNinja, replacing the global with a UI control.
-- Keep the addon table, not SaveData, so settings/profile changes stay live.
local ninja = NameLanguageNinja
local settings

local function AddTranslations(tooltip, abilityId)
    local library = LibMultilingualName
    local ninjaSettings = ninja and ninja.SaveData
    local output = ninjaSettings and ninjaSettings.To and ninjaSettings.To.Skill
    if not abilityId or abilityId == 0 or not library or not output
        or not output.Tooltip or not output.Tooltip.Body then
        return
    end

    local clientLanguage = string.lower(GetCVar('language.2'))
    local lines = {}
    local description = ninjaSettings.Description or {}
    local languages = library.ALL_LANG_CODES
    for _, language in ipairs(languages) do
        if not ninjaSettings.DontShowClientLanguage or language ~= clientLanguage then
            if ninjaSettings.Languages and ninjaSettings.Languages[language]
                and library.GetRawSkillName(language, abilityId) then
                lines[#lines + 1] = ninja.GetColoredText(language, library.GetSkillName(language, abilityId))
            end
        end
    end
    if description.OutputSkill then
        for _, language in ipairs(languages) do
            if not ninjaSettings.DontShowClientLanguage or language ~= clientLanguage then
                if description.Languages and description.Languages[language]
                    and library.GetRawAbilityDescription(language, abilityId) then
                    -- Keep the library's description unchanged, like Name Language Ninja.
                    lines[#lines + 1] = library.GetAbilityDescription(language, abilityId)
                end
            end
        end
        if description.OutputSkillId then
            lines[#lines + 1] = 'skillId:' .. abilityId
        end
    end
    if #lines == 0 then return end
    if not ninjaSettings.DontShowDivider then
        ZO_Tooltip_AddDivider(tooltip)
    end
    for _, line in ipairs(lines) do
        tooltip:AddLine(line)
    end
end

local function AbilityId(id)
    return id
end

local function ProgressionAbilityId(progressionIndex, morph, rank)
    return GetAbilityProgressionAbilityId(progressionIndex, morph, rank)
end

local function UpgradeAbilityId(skillType, skillLineIndex, skillIndex)
    local skill = SKILLS_DATA_MANAGER:GetSkillDataByIndices(skillType, skillLineIndex, skillIndex)
    if not skill or not skill:IsPassive() then return end
    local rank = skill:IsPurchased() and skill:GetCurrentRank() or 0
    if rank >= skill:GetNumRanks() then return end
    local progression = skill:GetProgressionData(rank + 1)
    return progression and progression:GetAbilityId()
end

local function HookTooltip(tooltip)
    if not tooltip then return end
    -- A setter may call another setter. Append only after the outermost one,
    -- retaining all original return values (including nils).
    local depth = 0
    local function Finish(self, abilityId, ...)
        depth = depth - 1
        if depth == 0 then AddTranslations(self, abilityId) end
        return ...
    end
    local function Hook(method, resolveAbilityId)
        local original = tooltip[method]
        if type(original) ~= 'function' then return end
        local wrapper = function(self, ...)
            local abilityId = resolveAbilityId(...)
            depth = depth + 1
            return Finish(self, abilityId, original(self, ...))
        end
        tooltip[method] = wrapper
    end
    Hook('SetAbilityId', AbilityId)
    Hook('SetProgressionAbility', ProgressionAbilityId)
    Hook('SetSkillLineAbilityId', AbilityId)
    Hook('SetSkillUpgradeAbility', UpgradeAbilityId)
end

local function Initialize()
    EVENT_MANAGER:UnregisterForEvent(ADDON_NAME .. 'Activate', EVENT_PLAYER_ACTIVATED)
    if settings and settings.enabled == false then return end
    HookTooltip(HarvensSkillTooltipMorph1)
    HookTooltip(HarvensSkillTooltipMorph2)
end

-- Dependencies finish loading and initialize their controls/settings first.
EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. 'Activate', EVENT_PLAYER_ACTIVATED, Initialize)
EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED, function(_, loadedName)
    if loadedName ~= ADDON_NAME then return end
    EVENT_MANAGER:UnregisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED)
    settings = ZO_SavedVars:NewAccountWide('KanaSkillTranslationsSaved', 1, nil, { enabled = true })
    if settings.enabled == nil then settings.enabled = true end
    if LibAddonMenu2 then
        local panelId = ADDON_NAME .. '_Options'
        local visibleName = "|cFF0000Kana|r |c4488FFHarven's Improved Skills Window|r|cFFFFFF: translations|r"
        LibAddonMenu2:RegisterAddonPanel(panelId, {
            type = 'panel', name = visibleName, displayName = visibleName,
            author = 'Kana', version = '1.0.2', registerForRefresh = true,
        })
        LibAddonMenu2:RegisterOptionControls(panelId, {
            { type = 'checkbox', name = 'Переводы в подсказках навыков',
              getFunc = function() return settings.enabled ~= false end,
              setFunc = function(value) settings.enabled = value end,
              default = true, requiresReload = true },
        })
    end
end)
