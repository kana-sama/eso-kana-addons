-- Run from eso-kana-addons: lua KanaLazySetCrafterAutoHide/tests/test.lua
local passed, failed = 0, 0
local function test(name, run)
    local ok, err = pcall(run)
    if ok then passed = passed + 1
    else failed = failed + 1; io.stderr:write(name .. ': ' .. tostring(err) .. '\n') end
end

local function fixture(options)
    options = options or {}
    local f = {events = {}, order = {}, scenes = {}, groups = {}, labels = {},
        station = 0, refreshes = 0, stockEntries = 0, stockExits = 0, otherEntries = 0}
    local a = setmetatable({}, {__index = _G})
    a._G = a
    for _, name in ipairs({'EVENT_ADD_ON_LOADED', 'EVENT_CRAFTING_STATION_INTERACT',
        'EVENT_END_CRAFTING_STATION_INTERACT', 'SCENE_SHOWING', 'SCENE_SHOWN',
        'SCENE_HIDING', 'SCENE_HIDDEN', 'KEYBIND_STRIP_ALIGN_RIGHT'}) do a[name] = name end
    a.CRAFTING_TYPE_BLACKSMITHING, a.CRAFTING_TYPE_CLOTHIER = 1, 2
    a.CRAFTING_TYPE_ENCHANTING, a.CRAFTING_TYPE_ALCHEMY = 3, 4
    a.CRAFTING_TYPE_PROVISIONING, a.CRAFTING_TYPE_WOODWORKING = 5, 6
    a.CRAFTING_TYPE_JEWELRYCRAFTING = 7
    a.GetCraftingInteractionType = function() return f.station end
    a.GetCVar = function() return options.language or 'ru' end
    a.EVENT_MANAGER = {}
    function a.EVENT_MANAGER:RegisterForEvent(name, event, callback)
        f.events[event] = f.events[event] or {}
        if not f.events[event][name] then
            f.order[event] = f.order[event] or {}; table.insert(f.order[event], name)
        end
        f.events[event][name] = callback
    end
    function a.EVENT_MANAGER:UnregisterForEvent(name, event)
        if f.events[event] then f.events[event][name] = nil end
    end
    function f:fire(event, ...)
        for _, name in ipairs(self.order[event] or {}) do
            local callback = self.events[event][name]
            if callback then callback(event, ...) end
        end
    end
    local function control(hidden)
        local c = {hidden = hidden, handlers = {}}
        function c:IsHidden() return self.hidden end
        function c:SetHidden(value)
            if self.hidden == value then return end
            self.hidden = value
            local handler = self.handlers[value and 'OnHide' or 'OnShow']
            if handler then handler(self) end
        end
        function c:GetHandler(name) return self.handlers[name] end
        function c:SetHandler(name, callback) self.handlers[name] = callback end
        return c
    end
    f.window, f.scroll, f.toggle = control(true), control(false), control(false)
    a.DolgubonSetCrafterWindow, a.CraftingQueueScroll, a.DolgubonSetCrafterToggle = f.window, f.scroll, f.toggle
    f.originalShows, f.originalHides = 0, 0
    f.window:SetHandler('OnShow', function() f.originalShows = f.originalShows + 1 end)
    f.window:SetHandler('OnHide', function() f.originalHides = f.originalHides + 1 end)
    function a.ZO_PostHookHandler(c, name, callback)
        local old = c:GetHandler(name)
        c:SetHandler(name, function(...) if old then old(...) end; callback(...) end)
    end
    f.settings = {OpenAtCraftStation = options.autoOpen == nil and true or options.autoOpen,
        closeOnExit = options.closeOnExit ~= false, showToggle = options.showToggle == true}
    local d = {name = 'DolgubonsLazySetCrafter', savedvars = {queue = options.queue or {}}}
    function d:GetSettings() return f.settings end
    function d:GetAutocraft() return options.autocraft ~= false end
    function d.toggleCraftButton(value) f.craftButton = value end
    function d.updateList() f.refreshes = f.refreshes + 1 end
    -- Mirrors SetCrafter.lua closeWindow: list refresh and both controls matter.
    local function close(hidden)
        if hidden == nil then hidden = not f.window:IsHidden() end
        d.updateList(); f.window:SetHidden(hidden); f.scroll:SetHidden(hidden)
    end
    d.close, f.slash = close, close -- the slash command captures the original local
    a.DolgubonSetCrafter = d
    if options.missingDependency then a.DolgubonSetCrafter = nil end
    f.crafter = d
    a.EVENT_MANAGER:RegisterForEvent(d.name, a.EVENT_CRAFTING_STATION_INTERACT, function(_, station)
        f.stockEntries = f.stockEntries + 1
        if station <= 3 or station > 5 then
            if not d:GetAutocraft() then d.toggleCraftButton(true) end
            if f.settings.OpenAtCraftStation == true then close(false) else f.toggle:SetHidden(false) end
        end
    end)
    a.EVENT_MANAGER:RegisterForEvent(d.name, a.EVENT_END_CRAFTING_STATION_INTERACT, function(_, station)
        f.stockExits = f.stockExits + 1
        if station <= 3 or station > 5 then
            d.toggleCraftButton(false)
            if f.settings.closeOnExit then close(true) end
            if not f.settings.showToggle then f.toggle:SetHidden(true) end
        end
    end)
    a.EVENT_MANAGER:RegisterForEvent('OtherAddon', a.EVENT_CRAFTING_STATION_INTERACT,
        function() f.otherEntries = f.otherEntries + 1 end)
    for _, name in ipairs({'smithing', 'enchanting', 'gamepad_smithing_root',
        'gamepad_smithing_refine', 'gamepad_smithing_creation', 'gamepad_smithing_deconstruct',
        'gamepad_smithing_improvement', 'gamepad_smithing_research',
        'gamepad_smithing_consolidatedSetSelection', 'gamepad_enchanting_mode',
        'gamepad_enchanting_creation', 'gamepad_enchanting_extraction',
        'gamepad_provisioner_root', 'gamepad_provisioner_options'}) do
        local scene = {state = a.SCENE_HIDDEN, callbacks = {}}
        function scene:RegisterCallback(_, callback) table.insert(self.callbacks, callback) end
        function scene:GetState() return self.state end
        function scene:set(state)
            local old = self.state; self.state = state
            for _, callback in ipairs(self.callbacks) do callback(old, state) end
        end
        f.scenes[name] = scene
    end
    a.SCENE_MANAGER = {GetScene = function(_, name) return f.scenes[name] end}
    a.KEYBIND_STRIP = {}
    function a.KEYBIND_STRIP:AddKeybindButtonGroup(group)
        assert(not f.groups[group], 'duplicate button group')
        f.groups[group] = true; self:UpdateKeybindButtonGroup(group)
    end
    function a.KEYBIND_STRIP:RemoveKeybindButtonGroup(group) f.groups[group] = nil; f.labels[group] = nil end
    function a.KEYBIND_STRIP:UpdateKeybindButtonGroup(group)
        assert(f.groups[group], 'updating an unregistered button group')
        f.labels[group] = group[1].name()
    end
    function f:button()
        local group = next(self.groups)
        assert(group, 'station toggle button missing')
        return group[1], self.labels[group]
    end
    function f:start(station, sameStation, sceneName)
        self.station = station or 1
        self.scene = self.scenes[sceneName or (self.station == 3 and 'enchanting' or 'smithing')]
        self.scene:set(a.SCENE_SHOWING)
        self:fire(a.EVENT_CRAFTING_STATION_INTERACT, self.station, sameStation)
        self.scene:set(a.SCENE_SHOWN)
    end
    function f:finish()
        local previous = self.station; self.station = 0
        self:fire(a.EVENT_END_CRAFTING_STATION_INTERACT, previous)
        self.scene:set(a.SCENE_HIDING); self.scene:set(a.SCENE_HIDDEN)
    end
    if options.upstream then
        -- Execute the installed SetCrafter.lua, including its private closeWindow
        -- and original entry/exit callbacks. Only ESO services stay simulated.
        a.IsConsoleUI = function() return false end
        a.GetNumUnlockedConsolidatedSmithingSets = function() return 0 end
        a.SLASH_COMMANDS = {}
        d.charSavedVars = {useCharacterSettings = false}
        d.savedvars.accountWideProfile = f.settings
        d.LazyCrafter = {GetCurrentSetInteractionIndex = function() return 0 end}
        assert(loadfile(options.upstream, 't', a))()
        f.slash = a.SLASH_COMMANDS['/dsc']
    end
    assert(loadfile('KanaLazySetCrafterAutoHide/KanaLazySetCrafterAutoHide.lua', 't', a))()
    f.api = a
    f:fire(a.EVENT_ADD_ON_LOADED, 'KanaLazySetCrafterAutoHide')
    return f
end

test('empty queue hides an already open window on entering', function()
    local f = fixture(); f.crafter.close(false); f:start()
    assert(f.window:IsHidden() and f.scroll:IsHidden(), 'empty queue must start collapsed')
end)
test('nonempty global queue opens even when upstream auto-open is off', function()
    local f = fixture({queue = {{station = 6}}, autoOpen = false}); f:start(1)
    assert(not f.window:IsHidden() and not f.scroll:IsHidden())
    assert(f.settings.OpenAtCraftStation == false, 'must not rewrite settings')
end)
test('sets-only auto-open does not suppress a queued ordinary station', function()
    local f = fixture({queue = {{}}, autoOpen = 'sets'}); f:start()
    assert(not f.window:IsHidden())
end)
test('bottom button opens and closes an empty queue and refreshes its label', function()
    local f = fixture(); f:start()
    local b, before = f:button(); b.callback()
    local _, after = f:button()
    assert(not f.window:IsHidden() and not f.scroll:IsHidden() and before ~= after)
    b.callback(); assert(f.window:IsHidden() and f.scroll:IsHidden())
    local _, last = f:button(); assert(last == before)
end)
test('nonempty queue can be manually collapsed and reopened', function()
    local f = fixture({queue = {{}}}); f:start()
    f:button().callback(); assert(f.window:IsHidden())
    f:button().callback(); assert(not f.window:IsHidden())
end)
test('clearing or adding to the queue leaves the manual state alone', function()
    local f = fixture({queue = {{}}}); f:start()
    f.crafter.savedvars.queue = {}; f.crafter.updateList(); assert(not f.window:IsHidden())
    f:button().callback(); f.crafter.savedvars.queue = {{}}; f.crafter.updateList()
    assert(f.window:IsHidden())
end)
test('repeated sameStation preserves manual choice and does not duplicate buttons', function()
    local f = fixture({queue = {{}}}); f:start(); f:button().callback()
    f:start(1, true); assert(f.window:IsHidden())
    f:button().callback(); f.crafter.savedvars.queue = {}; f:start(1, true)
    assert(not f.window:IsHidden())
end)
test('each fresh interaction recomputes visibility', function()
    local f = fixture(); f:start(); f:button().callback(); f:finish(); f:start()
    assert(f.window:IsHidden())
    f:finish(); f.crafter.savedvars.queue = {{}}; f:start()
    assert(not f.window:IsHidden())
end)
test('a fresh entry can carry sameStation after a real exit', function()
    local f = fixture({queue = {{}}}); f:start(); f:button().callback(); f:finish()
    f:start(1, true); assert(not f.window:IsHidden())
end)
test('all five supported professions get a button and queue-based visibility', function()
    for _, station in ipairs({1, 2, 3, 6, 7}) do
        local f = fixture(); f:start(station)
        assert(f.window:IsHidden()); f:button().callback(); assert(not f.window:IsHidden())
    end
end)
test('alchemy provisioning and no interaction are unaffected', function()
    for _, station in ipairs({0, 4, 5}) do
        local f = fixture(); f.crafter.close(false); f:start(station)
        assert(not f.window:IsHidden()); assert(not next(f.groups))
    end
end)
test('native craft keys are not reused by the button', function()
    local f = fixture(); f:start(); local b = f:button()
    assert(b.keybind == 'SET_CRAFTER_OPEN')
end)
test('cross and captured slash toggle refresh the label without replacing handlers', function()
    local f = fixture(); f:start(); local _, before = f:button()
    f.crafter.close(); local _, after = f:button()
    assert(before ~= after and f.originalShows == 1)
    f.slash(); local _, last = f:button()
    assert(before == last and f.originalHides == 1)
end)
test('scene hiding removes only our button and returning preserves window state', function()
    local f = fixture(); f:start(); f:button().callback()
    f.scene:set(f.api.SCENE_HIDING); assert(not next(f.groups))
    f.scene:set(f.api.SCENE_SHOWING); f:button(); assert(not f.window:IsHidden())
    f:finish(); assert(not next(f.groups))
end)
test('late hide of the old gamepad scene cannot remove the new scene button', function()
    local f = fixture(); f:start(1, false, 'gamepad_smithing_root')
    local nextScene = f.scenes.gamepad_smithing_creation
    nextScene:set(f.api.SCENE_SHOWING); f.scene:set(f.api.SCENE_HIDING)
    f:button().callback(); assert(not f.window:IsHidden())
end)
test('furnishing scenes retain the toggle at smithing and enchanting stations', function()
    for _, station in ipairs({1, 3}) do
        local f = fixture(); f:start(station, false,
            station == 1 and 'gamepad_smithing_root' or 'gamepad_enchanting_mode')
        f:button().callback(); assert(not f.window:IsHidden())
        f.scene:set(f.api.SCENE_HIDING)
        local recipes = f.scenes.gamepad_provisioner_root
        recipes:set(f.api.SCENE_SHOWING)
        f:button().callback(); assert(f.window:IsHidden())
        recipes:set(f.api.SCENE_HIDING)
        local recipeOptions = f.scenes.gamepad_provisioner_options
        recipeOptions:set(f.api.SCENE_SHOWING)
        f:button().callback(); assert(not f.window:IsHidden())
        recipeOptions:set(f.api.SCENE_HIDING); f.scene:set(f.api.SCENE_SHOWING)
        f:button(); assert(not f.window:IsHidden())
    end
end)
test('shared recipe scenes do not add the toggle to an ordinary cooking fire', function()
    local f = fixture(); f:start(5, false, 'gamepad_provisioner_root')
    assert(not next(f.groups))
    f.scenes.gamepad_provisioner_options:set(f.api.SCENE_SHOWING)
    assert(not next(f.groups))
end)
test('manual crafting still gets enabled on entry and disabled on exit', function()
    local f = fixture({autocraft = false}); f:start(); assert(f.craftButton == true)
    f:finish(); assert(f.craftButton == false and f.stockExits == 1)
end)
test('auto-crafting remains unchanged by visibility management', function()
    local f = fixture(); f:start(); assert(f.craftButton == nil)
end)
test('exit and floating icon preferences are retained', function()
    local f = fixture({closeOnExit = false, showToggle = true}); f:start()
    f:button().callback(); f:finish()
    assert(not f.window:IsHidden() and not f.toggle:IsHidden())
    assert(f.settings.closeOnExit == false and f.settings.showToggle == true)
end)
test('lower button replaces the forced floating icon', function()
    local f = fixture({autoOpen = false}); f:start()
    assert(f.toggle:IsHidden(), 'do not force a second toggle when showToggle is off')
end)
test('unrelated events and original exit callback stay registered', function()
    local f = fixture(); f:start(); f:finish()
    assert(f.otherEntries == 1 and f.stockExits == 1 and f.stockEntries == 0)
end)
test('missing dependency preserves the original entry handler', function()
    local f = fixture({missingDependency = true}); f:start()
    assert(f.stockEntries == 1 and not next(f.groups))
end)
test('repeated initialization does not register duplicate hooks or buttons', function()
    local f = fixture(); assert(f.api.KanaLazySetCrafterAutoHide, 'addon missing')
    f.api.KanaLazySetCrafterAutoHide.Initialize(f.api); f:start(); f:button().callback()
    assert(f.originalShows == 1)
end)
test('English labels track visibility too', function()
    local f = fixture({language = 'en'}); f:start(); local b, before = f:button()
    assert(before:find('Show', 1, true)); b.callback()
    local _, after = f:button(); assert(after:find('Hide', 1, true))
end)

local upstream = os.getenv('DLSC_SOURCE')
if upstream then
    test('installed upstream empty entry, button, captured slash and exit', function()
        local f = fixture({upstream = upstream, autocraft = false}); f:start()
        assert(f.window:IsHidden() and f.scroll:IsHidden() and f.craftButton == true)
        local b, before = f:button(); b.callback()
        assert(not f.window:IsHidden() and not f.scroll:IsHidden())
        f.slash(); local _, after = f:button()
        assert(f.window:IsHidden() and f.scroll:IsHidden() and before == after)
        b.callback(); f:finish()
        assert(f.window:IsHidden() and f.scroll:IsHidden() and f.craftButton == false)
        assert(f.refreshes == 5, 'all transitions must refresh upstream lists')
    end)
    test('installed upstream nonempty queue overrides auto-open false and sets', function()
        for _, autoOpen in ipairs({false, 'sets'}) do
            local f = fixture({upstream = upstream, autoOpen = autoOpen, queue = {{}}})
            f:start(); assert(not f.window:IsHidden())
            f.crafter.close(); f:start(1, true); assert(f.window:IsHidden())
            f:finish(); f:start(1, true); assert(not f.window:IsHidden())
            assert(f.settings.OpenAtCraftStation == autoOpen)
        end
    end)
    test('installed upstream honors keep-open and floating-icon settings on exit', function()
        local f = fixture({upstream = upstream, queue = {{}}, closeOnExit = false, showToggle = true})
        f:start(); f:finish()
        assert(not f.window:IsHidden() and not f.scroll:IsHidden() and not f.toggle:IsHidden())
    end)
end

print(string.format('%d passed, %d failed', passed, failed))
os.exit(failed == 0 and 0 or 1)
