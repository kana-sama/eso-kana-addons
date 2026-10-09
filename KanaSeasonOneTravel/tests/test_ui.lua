-- Smoke test of UI initialization and scene ownership; no rendering claims.
local controls, events, updates = {}, {}, {}
local Control = {}
Control.__index = Control
function Control:SetDimensions(w, h) self.width, self.height = w, h end
function Control:SetHeight(h) self.height = h end
function Control:SetAnchor(...) self.anchor = { ... } end
function Control:SetFont(font) self.font = font end
function Control:SetText(text) self.text = text end
function Control:SetTexture(texture) self.texture = texture end
function Control:SetColor(...) end
function Control:SetMouseEnabled(value) self.mouseEnabled = value end
function Control:GetNamedChild(suffix) return controls[self.name .. suffix] end
function Control:SetHandler(name, fn) self.handlers[name] = fn end
function Control:GetHandler(name) return self.handlers[name] end
function Control:SetEnabled(value) self.enabled = value end
function Control:SetAlpha(value) self.alpha = value end
function Control:SetHidden(value) self.hidden = value end
function Control:SetMouseOverEnabled(value) self.mouseOverEnabled = value end
function Control:SetCheckState(value) self.checkState = value end
function Control:SetModifyTextType(value) self.modifyTextType = value end
function Control:SetMaxLineCount(value) self.maxLineCount = value end
function Control:SetWrapMode(value) self.wrapMode = value end
WINDOW_MANAGER = {}
function WINDOW_MANAGER:CreateControl(name, parent, kind)
    assert(not controls[name], "Duplicate control: " .. name)
    local control = setmetatable({ name = name, parent = parent, kind = kind, handlers = {} }, Control)
    controls[name] = control
    return control
end
function WINDOW_MANAGER:CreateControlFromVirtual(name, parent, template)
    local control = self:CreateControl(name, parent)
    control.template = template
    if template == "ZO_WorldMapInfoContent" then control.hidden = true end
    if template == "ZO_ScrollContainer" then
        self:CreateControl(name .. "ScrollChild", control, CT_CONTROL)
    end
    if template == "ZO_WorldMapHouseRow" then
        local nameLabel = self:CreateControl(name .. "Name", control, CT_LABEL)
        nameLabel:SetAnchor(TOPLEFT, control, TOPLEFT, 20, 0)
        nameLabel:SetDimensions(290, 23)
        nameLabel:SetFont("ZoFontHeader")
        nameLabel:SetMaxLineCount(1)
        nameLabel:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
        local locationLabel = self:CreateControl(name .. "Location", control, CT_LABEL)
        locationLabel:SetAnchor(TOPLEFT, nameLabel, BOTTOMLEFT, 10, 0)
        locationLabel:SetDimensions(280, 28)
        locationLabel:SetFont("ZoFontHeader")
        locationLabel:SetMaxLineCount(1)
        locationLabel:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
    end
    return control
end
function GetCVar() return "ru" end
function ZO_CreateStringId(name, value) _G[name] = value end
function ZO_CheckButton_SetCheckState(control, value) control.checked = value end
function ZO_CheckButton_SetToggleFunction(control, fn) control.toggle = fn end
function ClearTooltip() end
local menu = {}
function ClearMenu() menu = {} end
function AddMenuItem(label, callback) menu[#menu + 1] = { label = label, callback = callback } end
function ShowMenu(control) end
function ZO_SelectableLabel_OnMouseEnter(label) label.hover = true end
function ZO_SelectableLabel_OnMouseExit(label) label.hover = false end
function zo_callLater(fn) fn() end
GuiRoot = {}
CT_LABEL, CT_CONTROL, TOPLEFT, RIGHT, LEFT, CT_BUTTON, TOPRIGHT, CT_TEXTURE, BOTTOMLEFT, BOTTOMRIGHT = 1, 2, 3, 4, 5, 6, 7, 8, 9, 10
MOUSE_BUTTON_INDEX_LEFT, MOUSE_BUTTON_INDEX_RIGHT = 1, 2
TRISTATE_CHECK_BUTTON_CHECKED = 1
MODIFY_TEXT_TYPE_UPPERCASE = 2
TEXT_WRAP_MODE_ELLIPSIS = 3
ZO_SELECTED_TEXT = { UnpackRGBA = function() return 1, 1, 1, 1 end }
ZO_DISABLED_TEXT = { UnpackRGBA = function() return 0.4, 0.4, 0.4, 1 end }
SCENE_FRAGMENT_SHOWING, SCENE_FRAGMENT_HIDDEN = "showing", "hidden"
SCENE_HIDING, SCENE_HIDDEN = "hiding", "scene-hidden"
SI_MAP_INFO_MODE_LOCATIONS = "Locations"
for _, name in ipairs({ "ADD_ON_LOADED", "START_FAST_TRAVEL_INTERACTION",
    "END_FAST_TRAVEL_INTERACTION", "FAST_TRAVEL_NETWORK_UPDATED" }) do _G["EVENT_" .. name] = name end
EVENT_MANAGER = {
    RegisterForEvent = function(_, _, event, fn) events[event] = fn end,
    UnregisterForEvent = function(_, _, event) events[event] = nil end,
    RegisterForUpdate = function(_, name, interval, fn) updates[name] = fn end,
    UnregisterForUpdate = function(_, name) updates[name] = nil end,
}
ZO_FadeSceneFragment = { New = function(_, control)
    return { control = control, RegisterCallback = function(self, _, fn) self.onState = fn end }
end }
local tabs = {}
WORLD_MAP_SCENE = { RegisterCallback = function(self, event, fn) self.onState = fn end }
WORLD_MAP_INFO = { modeBar = { lastName = SI_MAP_INFO_MODE_LOCATIONS,
    GetLastFragment = function(self) return self.lastName end,
    Add = function(_, name, fragments, data)
    tabs[#tabs + 1] = { name = name, fragments = fragments, data = data }
end }, SelectTab = function(self, name) self.modeBar.lastName = name end }
local canTravel, done, permanent, travelled, highSeasActive = false, {}, {}, nil, true
KanaSeasonOneTravel = {
    InitializeTracking = function() end,
    CanTravel = function() return canTravel end,
    Resolve = function(key) return key ~= "bilsa" and key or nil end,
    Travel = function(key) travelled = key end,
    IsDone = function(key) return done[key] == true end,
    IsPermanentDone = function(key) return permanent[key] == true end,
    SetDone = function(key, checked) done[key] = checked end,
    IsHighSeasActive = function() return highSeasActive end,
}
function GetFastTravelNodeOutboundOnlyInfo(key) return key == "holgunn" end
dofile("../UI.lua")
events.ADD_ON_LOADED(nil, "unrelated")
assert(#tabs == 0)
events.ADD_ON_LOADED(nil, "KanaSeasonOneTravel")
assert(#tabs == 1 and tabs[1].name == "Первый сезон", "Register one native map tab title")
assert(tabs[1].fragments[1].control.template == "ZO_WorldMapInfoContent")
local addon = KanaSeasonOneTravel
local prefix = "KanaSeasonOneTravel"
local count, nativeRows = 0, 0
for name, control in pairs(controls) do
    if name:find("Check$") and control.kind == CT_TEXTURE then count = count + 1 end
    assert(control.template ~= "ZO_ReadOnlyCheckBox", "Completion icon must have no checkbox frame")
    if name:find("Row$") and control.template == "ZO_WorldMapHouseRow" then nativeRows = nativeRows + 1 end
end
assert(count == 8 and nativeRows == 8, "The Vault replaces the duplicate Thieves Guild row")
assert(not controls[prefix .. "thievesRow"], "Do not show a second Daggerfall destination")
assert(controls[prefix .. "nowhereCheck"], "The Vault has an achievement check")
assert(controls[prefix .. "nowhereRow"].parent == controls[prefix .. "Panel"],
    "Eight native rows fit directly in the map panel")
local farmCheck = controls[prefix .. "farmCheck"]
local farmName = controls[prefix .. "farmRowName"]
assert(controls[prefix .. "farmRow"].mouseEnabled and not farmName.mouseEnabled,
    "The native row must receive clicks instead of its house-name label")
assert(farmCheck.texture == "EsoUI/Art/Miscellaneous/check_icon_32.dds",
    "Completion mark must be a borderless ESO check icon")
assert(farmCheck.anchor[2] == controls[prefix .. "farmRow"] and farmCheck.anchor[3] == TOPLEFT
    and farmCheck.anchor[4] + farmCheck.width / 2 == farmName.anchor[4] - 12
    and farmCheck.anchor[5] == farmName.anchor[5],
    "Completion mark must align with the native row name")
assert(farmName.anchor[4] == 20 and controls[prefix .. "farmRowLocation"].anchor[2] == farmName
    and controls[prefix .. "farmRowLocation"].anchor[3] == BOTTOMLEFT
    and controls[prefix .. "farmRowLocation"].anchor[4] == 10,
    "Name and location must keep the native house row anchors")
assert(controls[prefix .. "Heading1"].font == "ZoFontHeader2")
assert(controls[prefix .. "Heading2"].font == "ZoFontHeader2")
assert(controls[prefix .. "Heading3"].font == "ZoFontHeader2")
assert(controls[prefix .. "farmRowName"].font == "ZoFontHeader")
assert(controls[prefix .. "farmRowLocation"].text == "Ауридон")
assert(controls[prefix .. "urcelmoRowLocation"].text:find("Скайвотч", 1, true))
assert(controls[prefix .. "holgunnRowLocation"].maxLineCount == 1
    and controls[prefix .. "holgunnRowLocation"].wrapMode == TEXT_WRAP_MODE_ELLIPSIS,
    "Long locations must stay on one line like native house rows")
local firstRow = controls[prefix .. "farmRow"]
local nextRow = controls[prefix .. "bilsaRow"]
assert(nextRow.anchor[5] - firstRow.anchor[5] == 60,
    "Rows must use the native house-list step")
assert(controls[prefix .. "Heading2"].anchor[5] == controls[prefix .. "vampireRow"].anchor[5] + 60,
    "The next category must follow the third row without a custom gap")
assert(controls[prefix .. "Heading3"].anchor[5] == controls[prefix .. "arabelleRow"].anchor[5] + 60)
assert(not controls[prefix .. "highseasRow"].hidden, "Show High Seas during the event")
highSeasActive = false
addon.Refresh()
assert(controls[prefix .. "highseasRow"].hidden, "Hide High Seas outside the event")
highSeasActive = true
-- The visible tab's one-second update must handle event boundaries too.
addon.Refresh()
assert(not controls[prefix .. "highseasRow"].hidden)
assert(controls[prefix .. "farmCheck"].hidden, "No checkmark before completion")
assert(controls[prefix .. "farmRowName"].enabled, "Readable list on an ordinary map")
controls[prefix .. "farmRow"].handlers.OnMouseUp(nil, MOUSE_BUTTON_INDEX_LEFT, true)
assert(travelled == nil, "Ordinary map cannot travel")
canTravel = true
WORLD_MAP_INFO:SelectTab(SI_MAP_INFO_MODE_LOCATIONS)
events.START_FAST_TRAVEL_INTERACTION()
assert(WORLD_MAP_INFO.modeBar:GetLastFragment() == SI_MAP_INFO_MODE_LOCATIONS,
    "First wayshrine opening keeps the native Locations tab")
assert(controls[prefix .. "farmRowName"].enabled)
assert(not controls[prefix .. "bilsaRowName"].enabled, "Unknown shrine disabled")
assert(not controls[prefix .. "holgunnRowName"].enabled, "Outbound-only shrine disabled")
controls[prefix .. "arabelleRow"].handlers.OnMouseUp(nil, MOUSE_BUTTON_INDEX_LEFT, true)
assert(travelled == "arabelle", "A row must retain its own destination")
controls[prefix .. "arabelleRow"].handlers.OnMouseUp(nil, MOUSE_BUTTON_INDEX_RIGHT, true)
assert(#menu == 1 and menu[1].label:find("Отметить", 1, true), "Manual correction uses the native context menu")
menu[1].callback()
assert(done.arabelle and not done.urcelmo, "A checkbox must retain its own activity")
controls[prefix .. "arabelleRow"].handlers.OnMouseUp(nil, MOUSE_BUTTON_INDEX_RIGHT, true)
assert(#menu == 1 and menu[1].label:find("Снять", 1, true), "Completed entry offers a clear action")
menu[1].callback()
assert(not done.arabelle, "The context menu must also clear a mark")
permanent.arabelle, done.arabelle = true, true
ClearMenu()
controls[prefix .. "arabelleRow"].handlers.OnMouseUp(nil, MOUSE_BUTTON_INDEX_RIGHT, true)
assert(#menu == 0, "A permanent 20/20 check must not offer a daily clear action")
permanent.arabelle, done.arabelle = false, false
controls[prefix .. "highseasRow"].handlers.OnMouseUp(nil, MOUSE_BUTTON_INDEX_RIGHT, true)
assert(#menu == 1 and menu[1].label:find("Отметить", 1, true))
menu[1].callback()
assert(done.highseas, "High Seas allows manual completion correction")
ClearMenu()
controls[prefix .. "nowhereRow"].handlers.OnMouseUp(nil, MOUSE_BUTTON_INDEX_RIGHT, true)
assert(#menu == 0, "The Vault achievement cannot be changed manually")
done.nowhere = true
addon.Refresh()
assert(not controls[prefix .. "nowhereCheck"].hidden, "The earned Vault achievement shows a check")
controls[prefix .. "arabelleRow"].handlers.OnMouseUp(nil, MOUSE_BUTTON_INDEX_RIGHT, true)
menu[1].callback()
addon.fragment.onState(nil, SCENE_FRAGMENT_SHOWING)
assert(updates[prefix .. "DailyReset"], "Refresh checkmarks while visible")
updates[prefix .. "DailyReset"]()
assert(not controls[prefix .. "arabelleCheck"].hidden)
done.arabelle = false
updates[prefix .. "DailyReset"]()
assert(controls[prefix .. "arabelleCheck"].hidden, "Observe an online daily reset")
highSeasActive = false
updates[prefix .. "DailyReset"]()
assert(controls[prefix .. "highseasRow"].hidden and not controls[prefix .. "highseasRowName"].enabled,
    "Hide and disable High Seas when the event ends with the tab open")
assert(controls[prefix .. "highseasRow"].anchor[5] + controls[prefix .. "highseasRow"].height < 595,
    "All eight rows fit in the native map panel")
addon.fragment.onState(nil, SCENE_FRAGMENT_HIDDEN)
assert(not updates[prefix .. "DailyReset"], "Stop UI updates when tab hidden")
-- The native fast-travel handler always forces Locations before this addon's
-- START handler. Closing a shrine map on Season 1 should be remembered.
WORLD_MAP_INFO:SelectTab(SI_KANA_SEASON_ONE_TAB)
WORLD_MAP_SCENE.onState(nil, SCENE_HIDING)
WORLD_MAP_SCENE.onState(nil, SCENE_HIDDEN)
canTravel = false
events.END_FAST_TRAVEL_INTERACTION()
assert(controls[prefix .. "farmRowName"].enabled, "Text remains readable after leaving the wayshrine")
WORLD_MAP_INFO:SelectTab(SI_MAP_INFO_MODE_LOCATIONS)
canTravel = true
events.START_FAST_TRAVEL_INTERACTION()
assert(WORLD_MAP_INFO.modeBar:GetLastFragment() == SI_KANA_SEASON_ONE_TAB,
    "Reopen the Season 1 tab after native Locations selection")
-- Choosing a different tab before leaving the shrine clears the preference.
WORLD_MAP_INFO:SelectTab(SI_MAP_INFO_MODE_LOCATIONS)
WORLD_MAP_SCENE.onState(nil, SCENE_HIDING)
WORLD_MAP_SCENE.onState(nil, SCENE_HIDDEN)
canTravel = false
events.END_FAST_TRAVEL_INTERACTION()
WORLD_MAP_INFO:SelectTab(SI_MAP_INFO_MODE_LOCATIONS)
canTravel = true
events.START_FAST_TRAVEL_INTERACTION()
assert(WORLD_MAP_INFO.modeBar:GetLastFragment() == SI_MAP_INFO_MODE_LOCATIONS,
    "Choosing another tab must keep native behavior on the next wayshrine")
-- Fast travel may end the wayshrine interaction before the map scene hides.
WORLD_MAP_INFO:SelectTab(SI_KANA_SEASON_ONE_TAB)
canTravel = false
events.END_FAST_TRAVEL_INTERACTION()
WORLD_MAP_INFO:SelectTab(SI_MAP_INFO_MODE_LOCATIONS)
canTravel = true
events.START_FAST_TRAVEL_INTERACTION()
assert(WORLD_MAP_INFO.modeBar:GetLastFragment() == SI_KANA_SEASON_ONE_TAB,
    "Travelling from the tab must count as closing it, even before scene hiding")
-- A normal-map close must not override the last shrine-map choice.
WORLD_MAP_SCENE.onState(nil, SCENE_HIDING)
WORLD_MAP_SCENE.onState(nil, SCENE_HIDDEN)
assert(controls[prefix .. "Panel"].hidden, "Refresh must not override native fragment visibility")
print("KanaSeasonOneTravel: UI initialization and lifecycle checks passed")
