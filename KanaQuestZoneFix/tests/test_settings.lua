-- Run from eso-kana-addons: lua KanaQuestZoneFix/tests/test_settings.lua
local events = {}
EVENT_ADD_ON_LOADED = 1
EVENT_MANAGER = {
    RegisterForEvent = function(_, name, _, fn) events[name] = fn end,
    UnregisterForEvent = function(_, name) events[name] = nil end,
}

local stored = { questZones = false, misplacedPin = true, alternateBranches = false }
ZO_SavedVars = {
    NewAccountWide = function(_, name, version, namespace)
        assert(name == "KanaQuestZoneFixSaved" and version == 1 and namespace == nil,
            "own saved-variable identity must stay stable")
        return stored
    end,
}

local options
LibAddonMenu2 = {
    RegisterAddonPanel = function(_, id, panel)
        assert(id == "KanaQuestZoneFix_Options" and panel.displayName:find("LibQuestData"),
            "settings must belong to the overlay")
    end,
    RegisterOptionControls = function(_, _, controls) options = controls end,
}

GetQuestZoneId = function() return 283 end
LibQuestData_QuestLocationData = {
    ["deshaan/mournhold_base_0"] = { {0, 0, 0, 0, 7237}, {0, 0, 0, 0, 1234} },
}
LibQuestData = { conditional_quest_list = {} }
LibQuestData_Internal = { show_breadcrumb_quest = function() return true end }
local originalZone = GetQuestZoneId
local originalFilter = LibQuestData_Internal.show_breadcrumb_quest

dofile("KanaQuestZoneFix/KanaQuestZoneFix.lua")
dofile("KanaQuestZoneFix/LibQuestDataPatch.lua")
dofile("KanaQuestZoneFix/Settings.lua")
events.KanaQuestZoneFix(nil, "KanaQuestZoneFix")

assert(KanaQuestZoneFix.settings == stored, "existing account settings must be reused")
assert(GetQuestZoneId == originalZone, "disabled zone correction must leave API untouched")
assert(LibQuestData_Internal.show_breadcrumb_quest == originalFilter,
    "disabled branch correction must leave library filter untouched")
assert(#LibQuestData_QuestLocationData["deshaan/mournhold_base_0"] == 1,
    "enabled location correction must remove only the wrong pin")
assert(#options == 3 and options[1].getFunc() == false and options[2].getFunc() == true
    and options[3].getFunc() == false, "three independent switches must read saved values")
options[1].setFunc(true)
assert(stored.questZones == true and stored.alternateBranches == false,
    "changing one switch must not alter the others")
assert(events.KanaQuestZoneFix == nil, "initialization event must be removed")
print("PASS: own settings, old values, three independent switches")
