-- Run from eso-kana-addons: lua KanaBladeOfWoe/tests/test.lua
local function scenario(initial, pending)
    local state = {protected = initial, writes = {}, handlers = {}, saved = {enabled = true, restoreProtection = pending}}
    EVENT_ADD_ON_LOADED, EVENT_SYNERGY_ABILITY_CHANGED = 1, 2
    EVENT_PLAYER_ACTIVATED, EVENT_PLAYER_DEACTIVATED = 3, 4
    SETTING_TYPE_COMBAT, COMBAT_SETTING_PREVENT_ATTACKING_INNOCENTS = 10, 11
    EVENT_MANAGER = {
        RegisterForEvent = function(_, name, event, callback) state.handlers[event] = callback end,
        UnregisterForEvent = function(_, name, event) state.handlers[event] = nil end,
    }
    GetSetting_Bool = function() return state.protected end
    SetSetting = function(kind, setting, value)
        assert(kind == 10 and setting == 11)
        state.protected = tostring(value) == '1'
        state.writes[#state.writes + 1] = value
    end
    GetSynergyInfo = function() return state.name, state.icon end
    GetAbilityName = function(id) assert(id == 78219); return 'Клинок Горя' end
    GetCVar = function() return 'ru' end
    ZO_SavedVars = {NewAccountWide = function() return state.saved end}
    LibStub = nil
    LibAddonMenu2 = {
        RegisterAddonPanel = function(_, id) assert(id == 'KanaBladeOfWoeSettings') end,
        RegisterOptionControls = function(_, id, options) state.options = options end,
    }
    dofile('KanaBladeOfWoe/KanaBladeOfWoe.lua')
    state.handlers[EVENT_ADD_ON_LOADED](EVENT_ADD_ON_LOADED, 'KanaBladeOfWoe')
    function state:synergy(name, icon)
        self.name, self.icon = name, icon
        self.handlers[EVENT_SYNERGY_ABILITY_CHANGED]()
    end
    return state
end

local s = scenario(true)
assert(#s.writes == 0)
s:synergy('Localized kill', '/esoui/art/icons/ability_darkbrotherhood_003.dds')
assert(not s.protected and s.saved.restoreProtection)
s:synergy('Localized kill', '/esoui/art/icons/ability_darkbrotherhood_003.dds')
assert(#s.writes == 1, 'repeated synergy must not overwrite original state')
s:synergy(nil, nil)
assert(s.protected and not s.saved.restoreProtection)
s:synergy('Клинок Горя', nil)
assert(not s.protected, 'localized name fallback must tolerate missing icon')
s.options[1].setFunc(false)
assert(s.protected, 'disabling addon must immediately restore protection')
s:synergy('Клинок Горя', nil)
assert(s.protected, 'disabled addon must not unlock')
s.options[1].setFunc(true)
assert(not s.protected, 'enabling must inspect current synergy')
s.handlers[EVENT_PLAYER_DEACTIVATED]()
assert(s.protected, 'leaving world must restore protection')
s.handlers[EVENT_PLAYER_ACTIVATED]()
assert(not s.protected, 'entering world must inspect synergy')
s:synergy('Feed', '/esoui/art/icons/ability_vampire_002.dds')
assert(s.protected, 'unrelated synergies must not unlock')
print('PASS: Blade recognition, repeat, restore, settings, world transitions, unrelated synergy')

s = scenario(false)
s:synergy('Клинок Горя', nil)
s:synergy(nil, nil)
assert(not s.protected and #s.writes == 0, 'user-disabled protection must remain disabled')
s = scenario(false, true)
assert(s.protected and not s.saved.restoreProtection, 'recover outstanding override after reload')
print('PASS: preserve user setting and recover pending restoration')
