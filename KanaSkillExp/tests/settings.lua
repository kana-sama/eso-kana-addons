GetCVar = function() return 'ru' end
EVENT_ADD_ON_LOADED = 1
EVENT_MANAGER = { RegisterForEvent = function() end }
local saved = { entries = { { kind = 'line', id = 42 } }, manualOnly = true,
    manualTracker = false, nativeBarBackground = false }
ZO_SavedVars = { NewCharacterIdSettings = function(_, name, version)
    assert(name == 'KanaSkillExp_Data' and version == 1,
        'existing character saved-variable identity must be reused')
    return saved
end }
SkillExp = { skillsForm = { GetNumChildren = function() return 0 end } }
local originalToggle = function() end
SkillExp_ToggleSkillsForm = originalToggle
local controls
LibAddonMenu2 = {
    RegisterAddonPanel = function(_, id, panel)
        assert(id == 'KanaSkillExp_Options' and panel.displayName:find('SkillExp'),
            'own settings panel must be registered')
    end,
    RegisterOptionControls = function(_, _, options) controls = options end,
}

dofile('KanaSkillExp/Selection.lua')
dofile('KanaSkillExp/KanaSkillExp.lua')
KanaSkillExp:Initialize()
assert(#saved.entries == 1 and saved.entries[1].id == 42,
    'existing manual selection must survive')
assert(KanaSkillExp.form == nil and SkillExp_ToggleSkillsForm == originalToggle,
    'disabled tracker must leave the original display and toggle alone')
assert(#controls == 3 and controls[1].getFunc() == false
    and controls[2].getFunc() == true and controls[3].getFunc() == false,
    'three separate settings must reflect existing values')
controls[2].setFunc(false)
assert(saved.manualOnly == false and saved.manualTracker == false,
    'changing display mode must not enable the tracker')
print('PASS: existing selection, independent settings, disabled original UI untouched')
