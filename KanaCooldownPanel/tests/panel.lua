-- Exercise user-visible behavior through the ESO event, control and menu boundary.
local controls, events, updates, fragments = {}, {}, {}, {}
local methods = {}
function methods:SetDimensions(w, h) self.width, self.height = w, h end
function methods:SetAnchor(...) self.anchor = {...} end
function methods:ClearAnchors() self.anchor = nil end
function methods:GetTop() return self.anchor[5] end
function methods:SetHidden(hidden)
    local changed = self.hidden ~= hidden
    self.hidden = hidden
    local handler = self.handlers[hidden and 'OnHide' or 'OnShow']
    if changed and handler then handler(self) end
end
function methods:IsHidden() return self.hidden end
function methods:IsEffectivelyHidden()
    return self.hidden or (self.parent and self.parent:IsEffectivelyHidden()) or false
end
function methods:SetMouseEnabled(enabled) self.mouseEnabled = enabled end
function methods:SetHandler(name, callback) self.handlers[name] = callback end
function methods:SetText(text) self.text = text end
function methods:SetColor(...) self.color = {...} end
function methods:SetCenterColor(...) self.color = {...} end
function methods:SetTexture(texture) self.texture = texture end
function methods:SetAlpha(alpha) self.alpha = alpha end
function methods:SetDrawLayer(layer) self.layer = layer end
function methods:SetDrawLevel(level) self.level = level end
for _, name in ipairs({'SetAnchorFill', 'SetEdgeColor', 'SetFont',
    'SetHorizontalAlignment', 'SetVerticalAlignment', 'SetDrawTier', 'SetTextureCoords', 'SetBlendMode'}) do
    methods[name] = function() end
end
local function control(name, parent)
    local result = setmetatable({parent = parent, handlers = {}}, {__index = methods})
    controls[name] = result
    return result
end
WINDOW_MANAGER = {
    CreateControl = function(_, name, parent) return control(name, parent) end,
    CreateTopLevelWindow = function(_, name) return control(name) end,
}
EVENT_ADD_ON_LOADED, EVENT_PLAYER_ACTIVATED, EVENT_GLOBAL_MOUSE_UP, EVENT_PLAYER_COMBAT_STATE = 1, 2, 3, 4
EVENT_MANAGER = {
    RegisterForEvent = function(_, name, event, callback) events[event] = callback end,
    UnregisterForEvent = function() end,
    RegisterForUpdate = function(_, name, interval, callback) updates[name] = callback end,
}
ZO_SimpleSceneFragment = {New = function(_, root)
    return {Show = function() root:SetHidden(false) end, Hide = function() root:SetHidden(true) end}
end}
HUD_SCENE = {AddFragment = function(_, fragment) fragments[#fragments + 1] = fragment end}
HUD_UI_SCENE = HUD_SCENE
GuiRoot = {GetHeight = function() return 1000 end}
CT_BACKDROP, CT_LABEL, CT_CONTROL, DT_LOW = 1, 2, 3, 0
CT_TEXTURE, DL_BACKGROUND, DL_CONTROLS, DL_OVERLAY, TEX_BLEND_MODE_ADD = 4, 0, 1, 2, 1
TOP, TOPLEFT, BOTTOMRIGHT, TEXT_ALIGN_CENTER = 'TOP', 'TOPLEFT', 'BOTTOMRIGHT', 'CENTER'
MOUSE_BUTTON_INDEX_LEFT, MOUSE_BUTTON_INDEX_RIGHT = 1, 2
HOTBAR_CATEGORY_PRIMARY, HOTBAR_CATEGORY_BACKUP, HOTBAR_CATEGORY_WEREWOLF, HOTBAR_CATEGORY_COMPANION = 0, 1, 2, 3
ACTION_TYPE_NOTHING, ACTION_TYPE_ABILITY, ACTION_TYPE_CRAFTED_ABILITY = 0, 1, 2
ABILITY_SLOT_TYPE_ACTIONBAR, ACTION_BAR_FIRST_NORMAL_SLOT_INDEX = 1, 2
BAG_WORN, EQUIP_SLOT_RING1, EQUIP_SLOT_RING2 = 1, 11, 12
MENU_ADD_OPTION_CHECKBOX = 2
local combat, wolf, activeBar, now = false, false, HOTBAR_CATEGORY_PRIMARY, 0
local rings, calls = {}, {}
local bars = {
    [0] = {[3] = {101, 12000}, [4] = {102, 3500}, [5] = {103, 0}, [6] = {104, 0}},
    [1] = {[3] = {201, 8000}, [4] = {202, 0}},
    [2] = {[3] = {301, 7000}, [4] = {302, 0}},
}
local function slotData(slot, bar) return bars[bar] and bars[bar][slot] end
GetSlotBoundId = function(slot, bar) local s = slotData(slot, bar); return s and s[1] or 0 end
GetSlotType = function(slot, bar)
    local s = slotData(slot, bar)
    return s and (s.crafted and ACTION_TYPE_CRAFTED_ABILITY or ACTION_TYPE_ABILITY) or ACTION_TYPE_NOTHING
end
GetActionSlotEffectTimeRemaining = function(slot, bar)
    calls[#calls + 1] = {slot, bar}
    local s = slotData(slot, bar); return s and s[2] or 0
end
GetActionSlotEffectDuration = function(slot, bar)
    local s = slotData(slot, bar); return s and s.duration or 10000
end
GetSlotTexture = function(slot, bar) return 'skill-' .. GetSlotBoundId(slot, bar) .. '.dds' end
IsUnitInCombat = function(unit) assert(unit == 'player'); return combat end
IsPlayerInWerewolfForm = function() return wolf end
GetActiveHotbarCategory = function() return activeBar end
GetItemId = function(bag, slot) assert(bag == BAG_WORN); return rings[slot] or 0 end
GetCurrentCharacterId = function() return 'character-a' end
GetFrameTimeSeconds = function() return now end
GetCVar = function() return 'ru' end
local mouseX, mouseY = 500, 200
GetUIMousePosition = function() return mouseX, mouseY end
SKILLS_DATA_MANAGER = {GetProgressionDataByAbilityId = function(_, id)
    if id == 101 or id == 111 then
        return {GetSkillData = function() return {GetProgressionId = function() return 10 end} end}
    end
end}

local menu, shownOwner, nativeClicks = {}, nil, 0
ClearMenu = function() menu = {}; shownOwner = nil end
AddMenuItem = function(label, callback, itemType)
    menu[#menu + 1] = {label = label, callback = callback, itemType = itemType}
    return #menu
end
UpdateMenuItemState = function(index, checked) menu[index].checked = checked end
ShowMenu = function(owner) shownOwner = owner end
IsActionSlotRestricted = function(slot, bar) return bar == HOTBAR_CATEGORY_WEREWOLF end
ZO_AbilitySlot_OnSlotClicked = function(owner, button)
    nativeClicks = nativeClicks + 1
    if button == MOUSE_BUTTON_INDEX_RIGHT and owner.slotType == ABILITY_SLOT_TYPE_ACTIONBAR
        and owner.hotbarCategory ~= HOTBAR_CATEGORY_COMPANION
        and GetSlotBoundId(owner.slotNum, owner.hotbarCategory) ~= 0
        and not IsActionSlotRestricted(owner.slotNum, owner.hotbarCategory) then
        ClearMenu()
        AddMenuItem('Снять навык', function() end)
        ShowMenu(owner)
        return true
    end
end
local nativeShowMenu, nativeSlotClicked = ShowMenu, ZO_AbilitySlot_OnSlotClicked
local settingsOptions, panelData, panelName
LibAddonMenu2 = {
    RegisterAddonPanel = function(_, name, data)
        panelName, panelData = name, data
        _G[name] = {name = name}
        return _G[name]
    end,
    RegisterOptionControls = function(_, name, data)
        assert(name == panelName); settingsOptions = data
    end,
}
ZO_PreHook = function(name, hook)
    local original = _G[name]
    _G[name] = function(...)
        if hook(...) then return end
        return original(...)
    end
end

assert(loadfile('Model.lua'))()
assert(loadfile('Settings.lua'))()
assert(loadfile('KanaCooldownPanel.lua'))()
assert(loadfile('Menu.lua'))()
events[EVENT_ADD_ON_LOADED](EVENT_ADD_ON_LOADED, 'KanaCooldownPanel')
local root, content = controls.KanaCooldownPanelWindow, controls.KanaCooldownPanelContent
local function cell(i) return controls['KanaCooldownPanelCell' .. i] end
local function label(i) return controls['KanaCooldownPanelText' .. i] end
local function refresh() calls = {}; updates.KanaCooldownPanel() end
local function isBlack(i) return cell(i).color[1] < 0.1 and cell(i).color[2] < 0.1 end
local function isOrange(i) return cell(i).color[1] > 0.9 and cell(i).color[2] > 0.3 and cell(i).color[3] < 0.2 end
local function isRed(i) return cell(i).color[1] > 0.8 and cell(i).color[2] < 0.2 end
local function white(i) local c = label(i).color; return c[1] == 1 and c[2] == 1 and c[3] == 1 end
local function owner(slot, bar) return {slotNum = slot, hotbarCategory = bar, slotType = ABILITY_SLOT_TYPE_ACTIONBAR} end
local function open(slot, bar)
    ZO_AbilitySlot_OnSlotClicked(owner(slot, bar), MOUSE_BUTTON_INDEX_RIGHT)
end

assert(root.anchor[5] == 80, 'Default vertical position')
-- KanaAuras may load later: migration must happen after every addon is loaded.
KanaAurasSettings = {mirrorY = 140}
events[EVENT_PLAYER_ACTIVATED]()
fragments[1]:Show()
assert(root.anchor[5] == 140 and KanaCooldownPanelSettings.y == 140, 'Migrate the existing position')
KanaAurasSettings.mirrorY = 250
events[EVENT_PLAYER_ACTIVATED]()
assert(root.anchor[5] == 140, 'Do not overwrite a migrated or newly saved position')
assert(root.height == 88 and label(1).text == '8.0' and label(6).text == '12',
    'Two rows: inactive above active, timers visible outside combat')
assert(cell(8):IsHidden() and cell(10):IsHidden(), 'Missing uptime and empty slots skip outside combat')
assert(isBlack(6) and white(6), 'Normal timer has black background and white text')

bars[0][3][2] = 2000; refresh()
assert(isBlack(6), 'Exactly two seconds does not warn')
bars[0][3][2] = 1999; refresh()
assert(isOrange(6) and white(6), 'Below two seconds warns on background only')
combat = true; events[EVENT_PLAYER_COMBAT_STATE]()
assert(isRed(8) and label(8).text == '!' and white(8), 'Missing important uptime warns immediately in combat')
local alpha = cell(8).color[4]
now = 0.25; content.handlers.OnUpdate(content, now)
assert(cell(8).color[4] ~= alpha and white(8), 'Red background pulses without changing white text')
assert(cell(10):IsHidden(), 'Empty skill slots never warn')

open(3, 0)
assert(#menu == 3 and menu[1].label == 'Снять навык', 'Preserve the native action')
assert(menu[2].label == 'Не показывать в панели кулдаунов' and menu[2].itemType == MENU_ADD_OPTION_CHECKBOX)
assert(menu[3].label == 'Аптайм не важен' and not menu[3].checked)
assert(next(KanaCooldownPanelSettings.characters['character-a'].skills) == nil, 'Opening a menu changes no settings')
menu[3].callback()
assert(menu[3].checked and isBlack(6), 'Unimportant uptime suppresses orange immediately')
bars[0][3][2] = 0; refresh()
assert(cell(6):IsHidden(), 'Unimportant missing uptime skips even in combat')
menu[3].callback()
assert(isRed(6), 'Re-enabling uptime restores the missing warning')
menu[2].callback()
assert(cell(6):IsHidden() and not cell(7):IsHidden(), 'Hidden skill leaves a hole; next skill keeps its column')
assert(cell(7).anchor[4] == 46, 'No column collapse')

bars[0][5] = {111, 6000}; bars[0][3] = {105, 6000}; refresh()
assert(cell(8):IsHidden() and not cell(6):IsHidden(), 'Preferences follow the skill progression across slots/ranks')
open(5, 0); assert(menu[2].checked); menu[2].callback()
assert(not cell(8):IsHidden(), 'Hidden skill can be restored from the native bar')

activeBar = 1; refresh()
assert(label(1).text == '6.0' and label(6).text == '8.0', 'Weapon swap moves the correct categories between rows')
for _, ringSlot in ipairs({EQUIP_SLOT_RING1, EQUIP_SLOT_RING2}) do
    rings[ringSlot] = 187658; refresh()
    assert(root.height == 42 and label(1).text == '8.0' and cell(6):IsHidden(), 'Oakensoul in either ring slot: active row only')
    for _, call in ipairs(calls) do assert(call[2] == 1, 'Never query inaccessible back bar timers') end
    rings[ringSlot] = nil
end
refresh(); assert(root.height == 88, 'Removing Oakensoul restores both rows')
wolf, activeBar = true, 2; refresh()
assert(root.height == 42 and label(1).text == '7.0', 'Werewolf shows its active bar only')
open(3, 2)
assert(#menu == 2 and shownOwner.hotbarCategory == 2, 'Restricted werewolf slot still has preferences without remove action')
menu[1].callback(); assert(cell(1):IsHidden(), 'Werewolf skill can be hidden')
open(3, 2); menu[1].callback()

local before = nativeClicks
ZO_AbilitySlot_OnSlotClicked(owner(3, 2), MOUSE_BUTTON_INDEX_LEFT)
assert(nativeClicks == before + 1, 'Left clicks always pass through')
ClearMenu(); ShowMenu({slotNum = 3, hotbarCategory = 0})
assert(#menu == 0, 'Other context menus remain untouched')
ClearMenu(); ShowMenu(owner(8, 0)); assert(#menu == 0, 'Ultimate is outside the five slots')
ClearMenu(); ShowMenu(owner(3, HOTBAR_CATEGORY_COMPANION)); assert(#menu == 0, 'Companion menu is unchanged')
ClearMenu(); ShowMenu(owner(7, 0)); assert(#menu == 0, 'Empty slot has no preferences')

-- Crafted IDs have a separate namespace even if their number matches an ability.
wolf, activeBar = false, 0
bars[0][3] = {101, 5000, crafted = true}; refresh()
open(5, 0); menu[2].callback()
assert(cell(8):IsHidden() and not cell(6):IsHidden(), 'Crafted skill does not inherit normal skill preferences')
open(3, 0); menu[2].callback(); assert(cell(6):IsHidden())
open(3, 0); menu[2].callback()

root.handlers.OnMouseDown(root, MOUSE_BUTTON_INDEX_LEFT)
mouseX, mouseY = 900, 280; root.handlers.OnUpdate()
assert(root.anchor[4] == 0 and root.anchor[5] == 220 and KanaCooldownPanelSettings.y == 220,
    'Dragging changes and saves only vertical position')
events[EVENT_GLOBAL_MOUSE_UP](EVENT_GLOBAL_MOUSE_UP, MOUSE_BUTTON_INDEX_LEFT)
assert(root.handlers.OnUpdate == nil, 'Global release ends drag')

for _, bar in pairs(bars) do for _, data in pairs(bar) do data[2] = 0 end end
combat = false; events[EVENT_PLAYER_COMBAT_STATE]()
assert(content:IsHidden() and not root.mouseEnabled, 'No uptime outside combat leaves the entire panel inert')
assert(content.handlers.OnUpdate == nil, 'No red cells means no pulse update')
fragments[1]:Hide(); fragments[1]:Show()
assert(cell(1):IsEffectivelyHidden(), 'Closing a menu outside combat cannot flash an expired cell')
combat = true; refresh(); fragments[1]:Hide(); refresh()
assert(cell(1):IsEffectivelyHidden(), 'Polling cannot reveal the panel over an open menu')
combat = false; fragments[1]:Show()
assert(content:IsHidden(), 'Scene reveal refreshes combat state even before the next poll')

-- Recreate addon state against the same saved variables, as on character change/reload.
local saved = KanaCooldownPanelSettings
local function reload(characterId)
    ShowMenu, ZO_AbilitySlot_OnSlotClicked = nativeShowMenu, nativeSlotClicked
    GetCurrentCharacterId = function() return characterId end
    dofile('Model.lua'); dofile('Settings.lua'); dofile('KanaCooldownPanel.lua'); dofile('Menu.lua')
    events[EVENT_ADD_ON_LOADED](EVENT_ADD_ON_LOADED, 'KanaCooldownPanel')
    events[EVENT_PLAYER_ACTIVATED]()
end
reload('character-b')
assert(KanaCooldownPanelSettings == saved and controls.KanaCooldownPanelWindow.anchor[5] == 220,
    'New initialization preserves saved position')
bars[0][5][2] = 5000; refresh()
assert(not cell(8):IsHidden(), 'A second character has independent defaults')
open(5, 0); assert(not menu[2].checked, 'Other character does not inherit hidden skills')
reload('character-a')
assert(cell(8):IsHidden(), 'Original character restores hidden skills after reload')
open(5, 0); assert(menu[2].checked, 'Restored preferences appear checked in the menu')
print('PASS: four states, bars/rings, native menus, per-skill persistence, character isolation, migration, drag and scenes')

assert(panelName ~= 'KanaCooldownPanel' and panelName ~= 'KanaCooldownPanelSettings',
    'LAM panel must not overwrite addon or saved-variable globals')
assert(panelData.registerForRefresh and #settingsOptions == 4, 'Four settings with live dependent refresh')
local fixed, position, alert, style = unpack(settingsOptions)
assert(fixed.getFunc() == false and position.disabled(), 'Frontbar position is disabled until fixed layout is enabled')
assert(position.getFunc() == 'bottom' and alert.getFunc() == 'red' and style.getFunc() == 'square',
    'Existing presentation remains the default')
bars[0][3] = {401, 10000, duration = 10000}; bars[1][3] = {201, 8000, duration = 20000}
activeBar, wolf, combat = 0, false, true
fixed.setFunc(true); assert(not position.disabled(), 'Enabling fixed layout unlocks position')
for _, placement in ipairs({'top', 'bottom'}) do
    position.setFunc(placement)
    for _, category in ipairs({0, 1}) do
        activeBar = category; refresh()
        local front, back = placement == 'top' and 1 or 6, placement == 'top' and 6 or 1
        assert(label(front).text == '10' and label(back).text == '8.0', 'Fixed rows retain weapon identities across swaps')
    end
end
position.setFunc('top'); fixed.setFunc(false)
assert(position.disabled(), 'Turning fixed mode off disables the dependent option again')
activeBar = 0; refresh(); assert(label(6).text == '10', 'Inactive fixed placement is ignored in dynamic mode')
activeBar = 1; refresh(); assert(label(6).text == '8.0', 'Dynamic mode still keeps the active bar below')
fixed.setFunc(true)
for _, ringSlot in ipairs({EQUIP_SLOT_RING1, EQUIP_SLOT_RING2}) do
    rings[ringSlot] = 187658; refresh()
    assert(label(1).text == '8.0' and cell(6):IsHidden(), 'Single active row overrides fixed positions with Oakensoul')
    rings[ringSlot] = nil
end
wolf, activeBar = true, 2; bars[2][3][2] = 7000; refresh()
assert(label(1).text == '7.0' and cell(6):IsHidden(), 'Werewolf never displays a fixed weapon row')
wolf, activeBar = false, 0; refresh()

local function icon(i) return controls['KanaCooldownPanelIcon' .. i] end
local function glow(i) return controls['KanaCooldownPanelGlow' .. i] end
local function tint(i) return controls['KanaCooldownPanelTint' .. i] end
style.setFunc('skill')
assert(icon(1).texture == 'skill-401.dds' and icon(6).texture == 'skill-201.dds', 'Textures come from their native bar slots')
assert(icon(1).alpha == 0 and cell(1).color[4] == 0 and white(1), 'Full timer: transparent icon/background, opaque white text')
assert(math.abs(icon(6).alpha - 0.54) < 0.00001, 'Backbar opacity uses its own total duration')
bars[0][3][2] = 5000; refresh()
assert(math.abs(icon(1).alpha - 0.45) < 0.00001, 'Half duration gives half of the 0.9 opacity range')
bars[0][3][2] = 1; refresh()
assert(icon(1).alpha > 0.899 and icon(1).alpha < 0.9 and not tint(1):IsHidden(), 'Just before expiry icon approaches 0.9 with orange warning')
bars[0][3][2] = 0; refresh()
assert(icon(1).alpha == 1 and label(1).text == '!' and not tint(1):IsHidden(), 'Missing timer immediately makes the skill opaque with red alert')
assert(tint(1).layer > icon(1).layer and label(1).level > tint(1).level,
    'Red warning stays visible above opaque icons; timer stays above warning')
assert(glow(1):IsHidden(), 'Red alert must not show a gold frame')
alert.setFunc('gold')
assert(not glow(1):IsHidden() and label(1).text == '' and tint(1):IsHidden(), 'Gold alert replaces the exclamation and red tint')
assert(glow(1).color[1] > glow(1).color[2] and glow(1).color[2] > glow(1).color[3], 'Frame is tinted gold')
local glowAlpha = glow(1).alpha
now = now + 0.25; controls.KanaCooldownPanelContent.handlers.OnUpdate()
assert(glow(1).alpha ~= glowAlpha and icon(1).alpha == 1, 'Gold frame pulses independently of the opaque skill icon')
bars[0][3][2] = 10000; refresh()
assert(glow(1):IsHidden() and icon(1).alpha == 0 and tint(1):IsHidden(), 'Reapplying the skill clears its alert and resets opacity')
bars[0][3][2] = 15000; refresh(); assert(icon(1).alpha == 0, 'Extended effects never produce negative opacity')
bars[0][3].duration = 0; refresh(); assert(icon(1).alpha == 0, 'Unavailable native duration never divides by zero')
bars[0][3].duration = 10000
bars[0][3] = {999, 5000, crafted = true, duration = 10000}; refresh()
assert(icon(1).texture == 'skill-999.dds', 'Replacing a slot refreshes its icon, including crafted skills')
open(3, 0); menu[3].callback(); bars[0][3][2] = 1000; refresh()
assert(tint(1):IsHidden() and glow(1):IsHidden(), 'Unimportant uptime has no warning in skill mode')
bars[0][3][2] = 0; refresh(); assert(cell(1):IsHidden(), 'Unimportant missing skill remains a hole')
menu[3].callback(); open(3, 0); menu[2].callback()
assert(cell(1):IsHidden() and glow(1):IsHidden(), 'Hidden skill cannot leave a glow behind')
menu[2].callback()
style.setFunc('square')
assert(icon(1):IsHidden() and not glow(1):IsHidden() and isBlack(1), 'Gold alert also works for plain squares')
alert.setFunc('red')
assert(glow(1):IsHidden() and isRed(1) and label(1).text == '!', 'Changing alert style clears the previous treatment immediately')
style.setFunc('skill'); alert.setFunc('gold')
combat = false; refresh()
assert(cell(1):IsHidden() and glow(1):IsEffectivelyHidden(), 'Gold skill warning is absent outside combat')
reload('character-a')
assert(settingsOptions[1].getFunc() and settingsOptions[2].getFunc() == 'top'
    and settingsOptions[3].getFunc() == 'gold' and settingsOptions[4].getFunc() == 'skill',
    'All four presentation settings survive reload')
assert(KanaCooldownPanelSettings.y == 220 and KanaCooldownPanelSettings.characters['character-a'].skills['skill:10'].hidden,
    'Presentation settings preserve existing position and skill preferences')
print('PASS: live settings, fixed/dynamic rows, alert styles, native icons and opacity, persistence')
