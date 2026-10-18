local events = {}
EVENT_ADD_ON_LOADED = 1
EVENT_PLAYER_ACTIVATED = 2
EVENT_MANAGER = {
    RegisterForEvent = function(_, _, event, callback) events[event] = callback end,
    UnregisterForEvent = function(_, _, event) events[event] = nil end,
}
SLASH_COMMANDS = {}
NameLanguageNinja = {}
local function Original() return 'original' end
HarvensSkillTooltipMorph1 = { SetAbilityId = Original }
HarvensSkillTooltipMorph2 = { SetAbilityId = Original }
ZO_SavedVars = { NewAccountWide = function() return { enabled = false } end }

dofile('KanaSkillTranslations/KanaSkillTranslations.lua')
events[EVENT_ADD_ON_LOADED](nil, 'KanaSkillTranslations')
events[EVENT_PLAYER_ACTIVATED]()
assert(HarvensSkillTooltipMorph1.SetAbilityId == Original
    and HarvensSkillTooltipMorph2.SetAbilityId == Original,
    'disabled patch must leave original tooltips untouched')
assert(SLASH_COMMANDS['/kst'] == nil, 'diagnostic command must be absent')
print('PASS: disabled translation patch leaves Harven tooltips untouched')
