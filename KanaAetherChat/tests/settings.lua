-- Run from the repository root: lua KanaAetherChat/tests/settings.lua
local root = 'KanaAetherChat/'
local saved = {}
ZO_SavedVars = {NewAccountWide = function(_, name, version, section, defaults)
    assert(name == 'KanaAetherChatSavedVariables' and version == 1)
    if not saved[section] then
        saved[section] = {}
        for key, value in pairs(defaults) do saved[section][key] = value end
    end
    return saved[section]
end}
dofile(root .. 'Settings.lua')
local settings = KanaAetherChatSettings
for key in pairs(settings.defaults) do assert(settings:Get(key) == true, key .. ' changed default') end

local events, hooks = {}, 0
EVENT_ADD_ON_LOADED = 1
EVENT_MANAGER = {
    RegisterForEvent = function(_, name, _, callback) events[name] = callback end,
    UnregisterForEvent = function(_, name) events[name] = nil end,
}
ZO_PostHook = function() hooks = hooks + 1 end
ZO_PreHook = function() hooks = hooks + 1 end
ZO_PreHookHandler = function() hooks = hooks + 1 end
local widget = {hidden = false, SetHidden = function(self, value) self.hidden = value end}
AetherChat = {Messenger = {minBar = widget, window = {}}}
SCENE_MANAGER = {IsShowing = function() return true end}
local options
LibAddonMenu2 = {
    RegisterAddonPanel = function(_, id, panel)
        assert(id == 'KanaAetherChat_Panel' and panel.name == 'Kana AetherChat Patch')
    end,
    RegisterOptionControls = function(_, _, controls) options = controls end,
}
dofile(root .. 'Widget.lua')
events.KanaAetherChat_Widget(nil, 'KanaAetherChat')
assert(#options == 12 and saved.Widget.hideWidget and not saved.Widget.compactNativeChat)
assert(widget.hidden)
local byName = {}
for _, option in ipairs(options) do byName[option.name] = option end
byName['Скрыть плавающий виджет'].setFunc(false)
assert(not saved.Widget.hideWidget and not widget.hidden)
for _, option in ipairs(options) do
    if option.requiresReload and option.default == true then
        option.setFunc(false)
        assert(not option.getFunc(), option.name .. ' did not disable')
    end
end
for key in pairs(settings.defaults) do assert(settings:Get(key) == false, key .. ' not saved') end

ZO_ChatWindowTextEntryEditBox = {}
ZO_ChatWindowTextEntry = {}
SCENE_MANAGER = {IsShowing = function() return true end}
dofile(root .. 'KanaAetherChat.lua')
events.KanaAetherChat(nil, 'KanaAetherChat')
assert(hooks == 1, 'disabled patches installed hooks') -- widget suppression only
assert(not SLASH_COMMANDS or SLASH_COMMANDS['/kacdebug'] == nil)
for _, module in ipairs({'Scroll.lua', 'NativeChat.lua', 'LastChannel.lua'}) do
    dofile(root .. module)
    local name = 'KanaAetherChat_' .. module:match('^(.-)%.lua$')
    events[name](nil, 'KanaAetherChat')
end
assert(hooks == 1, 'disabled auxiliary modules installed hooks')
print('AetherChat settings: 12 controls and disabled patches passed')
