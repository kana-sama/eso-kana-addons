-- Run with an ESO UI source checkout to use the actual hook implementation.
unpack = unpack or table.unpack
dofile((arg[1] or '/tmp/esoui-live') .. '/esoui/libraries/utility/zo_hook.lua')
GetCVar = function() return 'ru' end
EVENT_MANAGER = {RegisterForEvent = function() end}
EVENT_ADD_ON_LOADED = 1
MOUSE_BUTTON_INDEX_RIGHT = 2
ZO_CommaDelimitNumber = tostring
local menu, displayed = {}, 0
function ClearMenu() menu = {} end
function AddMenuItem(label, callback) menu[#menu + 1] = {label = label, callback = callback} end
function ShowMenu() displayed = displayed + 1 end
function ZO_SkillsNavigationEntry_OnInitialized() end
SKILLS_WINDOW = {skillLinesTree = {}, skillLineIdToNode = {}}
dofile('KanaSkillExp/Selection.lua')
dofile('KanaSkillExp/KanaSkillExp.lua')
local addon = KanaSkillExp
addon.saved = {entries = {}}

local line = {
    GetId = function() return 45 end,
    GetName = function() return 'Test line' end,
    IsAvailable = function() return true end,
    GetCurrentRank = function() return 12 end,
    GetRankXPValues = function() return 100, 300, 150 end,
}
local abilityId = 900
local progression = {
    GetName = function() return 'Test ability' end,
    GetAbilityId = function() return abilityId end,
}
local skill = {
    IsPlayerSkill = function() return true end,
    IsPassive = function() return false end,
    IsCraftedAbility = function() return false end,
    GetProgressionId = function() return 78 end,
    GetCurrentProgressionData = function() return progression end,
    GetSkillLineData = function() return line end,
}
progression.GetSkillData = function() return skill end
addon:InstallMenus()
AddMenuItem('Native action', function() end)
ShowMenu({skillProgressionData = progression})
assert(#addon.saved.entries == 0, 'opening an ability menu must not select anything')
assert(#menu == 2 and menu[1].label == 'Native action', 'native menu actions must survive')
menu[2].callback()
assert(#addon.saved.entries == 1 and addon.saved.entries[1].id == 78,
    'the menu action must persist the selected progression')
ClearMenu()
ShowMenu({skillProgressionData = progression})
assert(menu[1].label == 'Удалить из SkillExp' and #addon.saved.entries == 1,
    'opening the remove menu must not remove anything')
menu[1].callback()
assert(#addon.saved.entries == 0, 'only clicking Remove may remove the entry')

local nativeClicks = 0
local control = {handlers = {OnMouseUp = function() nativeClicks = nativeClicks + 1 end}}
function control:GetHandler(name) return self.handlers[name] end
function control:SetHandler(name, handler) self.handlers[name] = handler end
control.node = {GetTree = function() return SKILLS_WINDOW.skillLinesTree end, GetData = function() return line end}
ZO_SkillsNavigationEntry_OnInitialized(control)
control.handlers.OnMouseUp(control, 1, true)
assert(nativeClicks == 1 and #addon.saved.entries == 0, 'left click must retain native selection behavior')
control.handlers.OnMouseUp(control, 2, true)
assert(nativeClicks == 1 and #addon.saved.entries == 0 and #menu == 1,
    'right click on a line must open a menu without selecting or toggling')
menu[1].callback()
assert(#addon.saved.entries == 1 and addon.saved.entries[1].id == 45,
    'line menu action must save a stable line ID')
local shownBefore = displayed
control.handlers.OnMouseUp(control, 2, false)
assert(displayed == shownBefore, 'releasing outside the line must not open its menu')

local requestedAbility
SKILLS_DATA_MANAGER = {
    GetSkillLineDataById = function(_, id) assert(id == 45); return line end,
    GetSkillDataByProgressionId = function(_, id) assert(id == 78); return skill end,
}
GetAbilityProgressionXPInfoFromAbilityId = function(id)
    requestedAbility = id
    return true, 4, 100, 300, 200, false
end
GetAbilityProgressionInfo = function() return 'Test', 1, 2 end
local entry = addon:EntryForSkill(skill)
local info = addon:GetInfo(entry)
assert(info.rank == 'II' and info.progress == 0.5 and requestedAbility == 900,
    'ability progress must use XP within the current rank')
abilityId = 901
info = addon:GetInfo(entry)
assert(requestedAbility == 901 and entry.id == 78,
    'a morph change must resolve the current ability without changing saved identity')
info = addon:GetInfo({kind = 'line', id = 45})
assert(info.rank == 12 and info.progress == 0.25, 'skill line progress must use line XP')
GetAbilityProgressionXPInfoFromAbilityId = function() return true, 4, 100, 100, 100, true end
info = addon:GetInfo(entry)
assert(info.progress == 1 and info.maxed and info.canMorph, 'morph-ready skills must stay visible at 100 percent')
SKILLS_DATA_MANAGER.GetSkillDataByProgressionId = function() return nil end
info = addon:GetInfo(entry)
assert(info.name == 'Test ability' and not info.available,
    'unavailable selections must retain a named placeholder')
assert(#addon.saved.entries == 1 and addon.saved.entries[1].id == 45,
    'XP, morph and availability refreshes must not change the saved list')
print('PASS: actual ESO hooks, menu actions, native clicks, XP, morphs and unavailable selections')
