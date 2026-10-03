local root = arg[1] or '.'
local events = {}
SLASH_COMMANDS = {}
local diagnosticLines = {}
function d(text) diagnosticLines[#diagnosticLines + 1] = text end
EVENT_PLAYER_ACTIVATED = 1
EVENT_MANAGER = {
    RegisterForEvent = function(_, name, event, callback) events[event] = callback end,
    UnregisterForEvent = function(_, name, event) events[event] = nil end,
}
function GetCVar() return 'ru' end
function ZO_Tooltip_AddDivider(t) t.lines[#t.lines + 1] = 'divider' end
local function tooltip()
    local t = {lines = {}}
    function t:AddLine(text) self.lines[#self.lines + 1] = text end
    function t:SetAbilityId(id) self.lines = {'original:' .. id}; return 'kept', nil, 42 end
    function t:SetProgressionAbility(index, morph, rank)
        return self:SetAbilityId(GetAbilityProgressionAbilityId(index, morph, rank))
    end
    function t:SetSkillLineAbilityId(id) return self:SetAbilityId(id) end
    function t:SetSkillUpgradeAbility() return self:SetAbilityId(503) end
    return t
end
HarvensSkillTooltipMorph1 = tooltip()
HarvensSkillTooltipMorph2 = tooltip()
SkillTooltip = tooltip()
function GetAbilityProgressionAbilityId(index, morph, rank) return index * 100 + morph * 10 + rank end
SKILLS_DATA_MANAGER = {
    GetSkillDataByIndices = function()
        return {
            IsPassive = function() return true end,
            IsPurchased = function() return true end,
            GetCurrentRank = function() return 2 end,
            GetNumRanks = function() return 4 end,
            GetProgressionData = function(_, rank)
                return {GetAbilityId = function() return 500 + rank end}
            end,
        }
    end,
}
local names = {en = {[114] = 'Morph one', [124] = 'Morph two', [503] = 'Passive III'}}
local descriptions = {en = {[114] = 'Description <<1>>', [124] = 'Description two', [503] = 'Passive description'}}
LibMultilingualName = {
    ALL_LANG_CODES = {'en', 'ru', 'de'},
    GetRawSkillName = function(lang, id) return names[lang] and names[lang][id] end,
    GetSkillName = function(lang, id) return names[lang][id] end,
    GetRawAbilityDescription = function(lang, id) return descriptions[lang] and descriptions[lang][id] end,
    GetAbilityDescription = function(lang, id) return descriptions[lang][id] end,
}
NameLanguageNinja = {
    SaveData = {
        Languages = {en = true, ru = true, de = true},
        DontShowClientLanguage = true,
        To = {Skill = {Tooltip = {Body = true}}},
        Description = {OutputSkill = true, Languages = {en = true, ru = true, de = true}},
    },
    GetColoredText = function(lang, text) return lang .. ':' .. text end,
}
local ninja = NameLanguageNinja
local file = io.open(root .. '/KanaSkillTranslations.lua')
if file then file:close(); dofile(root .. '/KanaSkillTranslations.lua') end
-- LAM creates a control named NameLanguageNinja during EVENT_ADD_ON_LOADED.
NameLanguageNinja = {isSettingsPanel = true}
if events[1] then events[1]() end
local count = 0
local function expect(t, expected, label)
    count = count + 1
    assert(table.concat(t.lines, '|') == expected, label .. ': ' .. table.concat(t.lines, '|'))
end
local a, b = HarvensSkillTooltipMorph1, HarvensSkillTooltipMorph2
a:SetProgressionAbility(1, 1, 4)
expect(a, 'original:114|divider|en:Morph one|Description <<1>>', 'morph and rank; nested setters add once')
b:SetProgressionAbility(1, 2, 4)
expect(b, 'original:124|divider|en:Morph two|Description two', 'other morph uses its own ID')
a:SetProgressionAbility(1, 1, 4)
expect(a, 'original:114|divider|en:Morph one|Description <<1>>', 'same ability rebuild')
a:SetSkillUpgradeAbility(1, 2, 3)
expect(a, 'original:503|divider|en:Passive III|Passive description', 'next passive rank')
local x, y, z = a:SetSkillLineAbilityId(124, 1, 2, 3)
assert(x == 'kept' and y == nil and z == 42, 'preserve return values')
expect(a, 'original:124|divider|en:Morph two|Description two', 'skill line ID')
a:SetAbilityId(999)
expect(a, 'original:999', 'missing translation has no divider')
SkillTooltip:SetAbilityId(114)
expect(SkillTooltip, 'original:114', 'standard tooltip untouched')
local settings = ninja.SaveData
settings.Description.OutputSkill = false
settings.DontShowDivider = true
a:SetAbilityId(114)
expect(a, 'original:114|en:Morph one', 'live settings and descriptions disabled')
settings.Languages.en = false
a:SetAbilityId(114)
expect(a, 'original:114', 'no enabled available language')
settings.Description.OutputSkill = true
a:SetAbilityId(114)
expect(a, 'original:114|Description <<1>>', 'description independent of name selection')
settings.To.Skill.Tooltip.Body = false
a:SetAbilityId(114)
expect(a, 'original:114', 'body disabled')
settings.To.Skill.Tooltip.Body = true
settings.Description.Languages.en = false
names.ru = {[114] = 'Russian name'}
descriptions.ru = {[114] = 'Russian description'}
a:SetAbilityId(114)
expect(a, 'original:114', 'client language suppressed')
settings.DontShowClientLanguage = false
a:SetAbilityId(114)
expect(a, 'original:114|ru:Russian name|Russian description', 'client language allowed')
ninja.SaveData = nil
a:SetAbilityId(114)
expect(a, 'original:114', 'settings not ready')
assert(events[1] == nil, 'initialization event unregistered')
print('PASS: ' .. count .. ' tooltip scenarios and return values')

ninja.SaveData = settings
SLASH_COMMANDS['/kst']()
assert(diagnosticLines[1] == '[KST 1.0.2] initialized=true')
assert(table.concat(diagnosticLines, '\n'):find('hooks=4/4', 1, true))
assert(table.concat(diagnosticLines, '\n'):find('id=114', 1, true))
print('PASS: runtime diagnostics report hooks and last ability')

-- Ninja can replace the settings table when resetting/changing profiles.
local replacement = {
    To = {Skill = {Tooltip = {Body = true}}},
    Languages = {en = true},
    Description = {OutputSkill = false},
    DontShowDivider = true,
}
ninja.SaveData = replacement
a:SetAbilityId(114)
expect(a, 'original:114|en:Morph one', 'new settings table after global replaced by panel')
print('PASS: panel name collision and replacement settings')
