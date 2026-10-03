local ADDON_NAME = 'KanaSkillTranslations'
-- Capture during file loading: Ninja's EVENT_ADD_ON_LOADED creates a LAM
-- panel also named NameLanguageNinja, replacing the global with a UI control.
-- Keep the addon table, not SaveData, so settings/profile changes stay live.
local ninja = NameLanguageNinja
local diagnostics = { initialized = false, tooltips = {} }
local tooltipStates = {}


local function AddTranslations(tooltip, abilityId)
    local state = tooltipStates[tooltip]
    state.calls = state.calls + 1
    state.abilityId = abilityId
    state.lines = 0
    state.reason = 'settings/id unavailable'
    local library = LibMultilingualName
    local settings = ninja and ninja.SaveData
    local output = settings and settings.To and settings.To.Skill
    if not abilityId or abilityId == 0 or not library or not output
        or not output.Tooltip or not output.Tooltip.Body then
        return
    end

    local clientLanguage = string.lower(GetCVar('language.2'))
    local lines = {}
    local description = settings.Description or {}
    local languages = library.ALL_LANG_CODES
    for _, language in ipairs(languages) do
        if not settings.DontShowClientLanguage or language ~= clientLanguage then
            if settings.Languages and settings.Languages[language]
                and library.GetRawSkillName(language, abilityId) then
                lines[#lines + 1] = ninja.GetColoredText(language, library.GetSkillName(language, abilityId))
            end
        end
    end
    if description.OutputSkill then
        for _, language in ipairs(languages) do
            if not settings.DontShowClientLanguage or language ~= clientLanguage then
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
    state.lines = #lines
    state.reason = #lines > 0 and 'added' or 'no matching translations'
    if #lines == 0 then return end
    if not settings.DontShowDivider then
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

local function HookTooltip(tooltip, index)
    local state = { present = tooltip ~= nil, calls = 0, lines = 0, hooks = {} }
    diagnostics.tooltips[index] = state
    if not tooltip then return end
    tooltipStates[tooltip] = state
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
        state.hooks[method] = wrapper
    end
    Hook('SetAbilityId', AbilityId)
    Hook('SetProgressionAbility', ProgressionAbilityId)
    Hook('SetSkillLineAbilityId', AbilityId)
    Hook('SetSkillUpgradeAbility', UpgradeAbilityId)
end

local function Initialize()
    EVENT_MANAGER:UnregisterForEvent(ADDON_NAME, EVENT_PLAYER_ACTIVATED)
    diagnostics.initialized = true
    HookTooltip(HarvensSkillTooltipMorph1, 1)
    HookTooltip(HarvensSkillTooltipMorph2, 2)
end

-- Dependencies finish loading and initialize their controls/settings first.
EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_PLAYER_ACTIVATED, Initialize)

-- Run after hovering a skill; the last observations survive hiding the tooltip.
SLASH_COMMANDS['/kst'] = function()
    d('[KST 1.0.2] initialized=' .. tostring(diagnostics.initialized))
    local settings = ninja and ninja.SaveData
    local output = settings and settings.To and settings.To.Skill
    d('[KST] Ninja=' .. tostring(settings ~= nil)
        .. ' body=' .. tostring(output and output.Tooltip and output.Tooltip.Body)
        .. ' library=' .. tostring(LibMultilingualName ~= nil))
    for index = 1, 2 do
        local state = diagnostics.tooltips[index]
        local tooltip = index == 1 and HarvensSkillTooltipMorph1 or HarvensSkillTooltipMorph2
        if state then
            local active, total = 0, 0
            for method, wrapper in pairs(state.hooks) do
                total = total + 1
                if tooltip and tooltip[method] == wrapper then active = active + 1 end
            end
            d('[KST] tooltip ' .. index .. ' present=' .. tostring(state.present)
                .. ' hooks=' .. active .. '/' .. total .. ' calls=' .. state.calls
                .. ' id=' .. tostring(state.abilityId) .. ' lines=' .. state.lines
                .. ' status=' .. tostring(state.reason))
            if state.abilityId and LibMultilingualName then
                for _, language in ipairs(LibMultilingualName.ALL_LANG_CODES) do
                    if settings and settings.Languages and settings.Languages[language] then
                        d('[KST] ' .. index .. ' ' .. language .. ' name='
                            .. tostring(LibMultilingualName.GetRawSkillName(language, state.abilityId)))
                    end
                end
            end
        else
            d('[KST] tooltip ' .. index .. ': initialization not reached')
        end
    end
end
