-- Run from the repository root: lua KanaBackBarReminder/tests/run.lua
local addonPath = (arg[0]:match('^(.*)/tests/[^/]+$') or '.') .. '/KanaBackBarReminder.lua'
local passed = 0
local function check(condition, message)
    assert(condition, message)
    passed = passed + 1
end

local entry = loadfile(addonPath)
check(entry ~= nil, 'KanaBackBarReminder entry point must exist')

local controls, events, fragments, options, panel
local activeBar, character = 0, 'character-a'
local saved = {}
local methods = {}
function methods:SetHidden(hidden)
    local changed = self.hidden ~= hidden
    self.hidden = hidden
    local handler = self.handlers[hidden and 'OnHide' or 'OnShow']
    if changed and handler then handler(self) end
end
function methods:IsControlHidden()
    return self.hidden or (self.parent and self.parent:IsControlHidden()) or false
end
function methods:SetMouseEnabled(value) self.mouseEnabled = value end
function methods:SetAnchorFill(target) self.fill = target end
function methods:SetAnchor(...) self.anchor = {...} end
function methods:ClearAnchors() self.anchor = nil end
function methods:SetDimensions(width, height) self.width, self.height = width, height end
function methods:SetHandler(name, handler) self.handlers[name] = handler end
function methods:SetTexture(texture) self.texture = texture end
function methods:SetColor(...) self.color = {...} end
function methods:SetCenterColor(...) self.color = {...} end
function methods:SetEdgeColor(...) self.edgeColor = {...} end
function methods:SetDrawTier(value) self.tier = value end
function methods:SetDrawLayer(value) self.layer = value end
function methods:SetBlendMode(value) self.blendMode = value end
local function control(name, parent)
    local result = setmetatable({parent = parent, handlers = {}}, {__index = methods})
    controls[name] = result
    return result
end

EVENT_ADD_ON_LOADED, EVENT_PLAYER_ACTIVATED, EVENT_ACTION_SLOTS_ACTIVE_HOTBAR_UPDATED = 1, 2, 3
HOTBAR_CATEGORY_PRIMARY, HOTBAR_CATEGORY_BACKUP = 0, 1
CT_CONTROL, CT_TEXTURE, CT_BACKDROP = 1, 2, 3
CENTER, TOPLEFT = 'CENTER', 'TOPLEFT'
DT_LOW, DL_OVERLAY, TEX_BLEND_MODE_ADD = 1, 2, 3
WINDOW_MANAGER = {
    CreateTopLevelWindow = function(_, name) return control(name) end,
    CreateControl = function(_, name, parent, kind)
        assert(kind == CT_CONTROL or kind == CT_TEXTURE or kind == CT_BACKDROP, 'Signals must not create text')
        return control(name, parent)
    end,
}
EVENT_MANAGER = {
    RegisterForEvent = function(_, _, event, callback) events[event] = callback end,
    UnregisterForEvent = function(_, _, event) events[event] = nil end,
}
ZO_SimpleSceneFragment = {New = function(_, root)
    return {
        Show = function() root:SetHidden(false) end,
        Hide = function() root:SetHidden(true) end,
    }
end}
HUD_SCENE = {AddFragment = function(_, fragment) fragments[#fragments + 1] = fragment end}
HUD_UI_SCENE = {AddFragment = HUD_SCENE.AddFragment}
ZO_SavedVars = {NewCharacterIdSettings = function(_, name, version, namespace, defaults)
    assert(name == 'KanaBackBarReminderSV' and version == 1 and namespace == nil)
    if not saved[character] then
        saved[character] = {}
        for key, value in pairs(defaults) do saved[character][key] = value end
    end
    _G[name] = saved
    return saved[character]
end}
LibAddonMenu2 = {
    RegisterAddonPanel = function(_, name, data)
        assert(name ~= 'KanaBackBarReminderSV', 'Settings panel must not overwrite saved variables')
        panel = data
        _G[name] = control(name)
    end,
    RegisterOptionControls = function(_, _, data) options = data end,
}
GetActiveHotbarCategory = function() return activeBar end
GetCVar = function() return 'ru' end

local function reload()
    controls, events, fragments, options, panel = {}, {}, {}, nil, nil
    GuiRoot = control('GuiRoot')
    ZO_ReticleContainerReticle = control('Reticle', GuiRoot)
    assert(loadfile(addonPath))()
    events[EVENT_ADD_ON_LOADED](EVENT_ADD_ON_LOADED, 'AnotherAddon')
    check(not controls.KanaBackBarReminderWindow, 'Ignore unrelated addon-loaded events')
    events[EVENT_ADD_ON_LOADED](EVENT_ADD_ON_LOADED, 'KanaBackBarReminder')
end
local function swap(bar)
    activeBar = bar
    events[EVENT_ACTION_SLOTS_ACTIVE_HOTBAR_UPDATED](EVENT_ACTION_SLOTS_ACTIVE_HOTBAR_UPDATED, true, false, bar)
end
local function visible(name) return not controls[name]:IsControlHidden() end
local function signals(glow, brackets, message)
    check(visible('KanaBackBarReminderGlow') == glow and visible('KanaBackBarReminderBrackets') == brackets, message)
end

reload()
check(events[EVENT_ADD_ON_LOADED] == nil, 'Unregister load handler after initialization')
check(#fragments == 2 and fragments[1] == fragments[2], 'Attach one overlay to both gameplay HUD scenes')
check(controls.KanaBackBarReminderWindow.fill == GuiRoot, 'Overlay follows screen size and UI scale')
check(controls.KanaBackBarReminderGlow.fill == controls.KanaBackBarReminderWindow, 'Glow covers all four screen edges')
check(controls.KanaBackBarReminderGlow.texture:match('EdgeGlow%.dds$'), 'Use the full-frame glow texture')
check(controls.KanaBackBarReminderBrackets.anchor[2] == ZO_ReticleContainerReticle, 'Brackets follow the actual reticle')
check(panel.registerForRefresh and panel.registerForDefaults, 'Settings support refresh and defaults')
check(panel.name == '|cFF0000Kana|r Back Bar Reminder' and panel.displayName == panel.name,
    'Display the spaced addon name with only the Kana prefix red')
check(#options == 4 and options[1].type == 'checkbox' and options[2].type == 'checkbox' and options[3].type == 'checkbox'
    and options[4].type == 'dropdown', 'Expose both effects, glow intensity and the main-bar choice')
check(options[1].getFunc() and options[3].getFunc(), 'Both effects are enabled by default')
check(options[4].getFunc() == 0, 'Primary weapon pair is the default main bar')
for _, option in ipairs(options) do check(not option.requiresReload, 'Settings must apply immediately') end
for _, item in pairs(controls) do
    if item ~= GuiRoot and item ~= ZO_ReticleContainerReticle and item.mouseEnabled ~= nil then
        check(item.mouseEnabled == false, 'Overlay must not intercept mouse input')
    end
end

fragments[1]:Show()
signals(false, false, 'Opening the HUD on the main bar must not reveal effects')
swap(1)
signals(true, true, 'Both effects appear on the side bar')
check(not options[2].getFunc() and controls.KanaBackBarReminderGlow.color[4] == 0.3,
    'Existing settings keep the original glow intensity by default')
options[2].setFunc(true)
check(controls.KanaBackBarReminderGlow.color[4] == 1,
    'Intense mode immediately increases the glow alpha from 0.3 to 1')
check(controls.KanaBackBarReminderBracket1.color[4] == 0.85,
    'Increasing glow intensity must not brighten the brackets')
options[1].setFunc(false)
signals(false, true, 'Intense glow still respects the independent glow toggle')
check(options[2].disabled(), 'Disable the intensity control when glow itself is disabled')
options[1].setFunc(true)
check(controls.KanaBackBarReminderGlow.color[4] == 1 and not options[2].disabled(),
    'Re-enabling glow restores the chosen intensity immediately')
swap(0)
signals(false, false, 'Intense mode must not reveal either effect on the main bar')
swap(1)
options[2].setFunc(false)
check(controls.KanaBackBarReminderGlow.color[4] == 0.3,
    'Disabling intense mode immediately restores the original intensity')
events[EVENT_PLAYER_ACTIVATED]()
signals(true, true, 'Player activation preserves the actual side-bar state')
options[1].setFunc(false)
signals(false, true, 'Disabling glow keeps brackets visible without a reload')
options[3].setFunc(false)
signals(false, false, 'Both effects can be disabled')
options[1].setFunc(true)
signals(true, false, 'Glow can be used independently')
options[3].setFunc(true)
signals(true, true, 'Brackets can be re-enabled immediately')
swap(0)
signals(false, false, 'Returning to the main bar hides both effects')

fragments[1]:Hide()
swap(1)
signals(false, false, 'Gameplay effects stay hidden while a menu owns the scene')
fragments[1]:Show()
signals(true, true, 'Returning to gameplay refreshes the current bar')
fragments[1]:Hide()
swap(0)
fragments[1]:Show()
signals(false, false, 'A fragment reopening on main must not resurrect stale effects')

options[4].setFunc(1)
signals(true, true, 'Choosing backup as main makes primary the side bar')
swap(1)
signals(false, false, 'The chosen main bar remains visually normal')
for _, bar in ipairs({2, 3, 5}) do
    swap(bar)
    signals(false, false, 'Special hotbars must not be treated as a side weapon bar')
end
swap(nil)
signals(false, false, 'An unavailable hotbar must not show a side-bar warning')

ZO_ReticleContainerReticle = nil
swap(0)
check(controls.KanaBackBarReminderBrackets.anchor[2] == GuiRoot, 'Missing reticle falls back to screen center')
ZO_ReticleContainerReticle = control('LateReticle', GuiRoot)
events[EVENT_PLAYER_ACTIVATED]()
check(controls.KanaBackBarReminderBrackets.anchor[2] == ZO_ReticleContainerReticle, 'Use a reticle that becomes available later')

options[1].setFunc(false)
options[2].setFunc(true)
reload()
fragments[1]:Show()
signals(false, true, 'A reload preserves the selected main bar and independent toggles')
check(options[4].getFunc() == 1 and not options[1].getFunc() and options[2].getFunc(), 'Settings and glow intensity survive reload')
character = 'character-b'
reload()
check(options[4].getFunc() == 0 and options[1].getFunc() and not options[2].getFunc(), 'Characters have independent settings and intensity')
saved[character] = {showGlow = 'invalid', showBrackets = false, intenseGlow = 'invalid', mainBar = 999}
reload()
check(options[1].getFunc() == true and options[3].getFunc() == false and options[4].getFunc() == 0
    and options[2].getFunc() == false,
    'Repair invalid settings while preserving a saved disabled effect')

print(('PASS: %d KanaBackBarReminder behavior checks'):format(passed))
