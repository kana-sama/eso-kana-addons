-- Controller integration tests. Run from the eso-kana-addons directory.

local function fail(message)
    error(message, 2)
end

local function equal(actual, expected, message)
    if actual ~= expected then
        fail((message or "values differ") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
    end
end

local function truthy(value, message)
    if not value then
        fail(message or "expected truthy value")
    end
end

local tests = {}

local function test(name, fn)
    tests[#tests + 1] = { name = name, fn = fn }
end

local function variant(key)
    return {
        key = key,
        styleKey = key:match("^[^:]+"),
        name = key,
        weight = tonumber(key:match(":(%d+)$")) or 4,
        slots = {},
        missingSlots = {},
        knownCount = 7,
        partCount = 7,
    }
end

local function newModel(variants, accountPrefs, characterPrefs, calls)
    local self = {
        variants = variants,
        accountPrefs = accountPrefs,
        characterPrefs = characterPrefs,
        index = 1,
        opens = 0,
    }

    for index, value in ipairs(variants) do
        if value.key == characterPrefs.selectedKey then
            self.index = index
        end
    end

    function self:Open()
        self.opens = self.opens + 1
        if self.variants[self.index] then
            self.characterPrefs.selectedKey = self.variants[self.index].key
        end
    end

    function self:GetSelected()
        return self.variants[self.index]
    end

    function self:GetRows()
        return {}
    end

    function self:GetPosition()
        if #self.variants == 0 then
            return 0, 0
        end
        return self.index, #self.variants
    end

    function self:MoveHorizontal(delta)
        local nextIndex = math.max(1, math.min(#self.variants, self.index + delta))
        if nextIndex == self.index then
            return false
        end
        self.index = nextIndex
        self.characterPrefs.selectedKey = self.variants[self.index].key
        return true
    end

    function self:MoveVertical(delta)
        return self:MoveHorizontal(delta)
    end

    function self:Select(key)
        for index, value in ipairs(self.variants) do
            if value.key == key then
                if index == self.index then
                    return false
                end
                self.index = index
                self.characterPrefs.selectedKey = key
                return true
            end
        end
        return false
    end

    function self:SelectRow()
        return false
    end

    function self:ToggleFavorite()
        local selected = self:GetSelected()
        if not selected then
            return false
        end
        self.accountPrefs.favorites[selected.key] = not self.accountPrefs.favorites[selected.key] or nil
        return true
    end

    function self:ToggleHidden()
        local selected = self:GetSelected()
        if not selected then
            return false
        end
        self.accountPrefs.hidden[selected.key] = not self.accountPrefs.hidden[selected.key] or nil
        return true
    end

    function self:SetShowHidden(value)
        value = not not value
        if self.characterPrefs.showHidden == value then
            return false
        end
        self.characterPrefs.showHidden = value
        return true
    end

    function self:RefreshCatalog(nextVariants)
        calls.modelRefresh = calls.modelRefresh + 1
        local selectedKey = self:GetSelected() and self:GetSelected().key or nil
        self.variants = nextVariants
        self.index = #nextVariants > 0 and 1 or nil
        for index, value in ipairs(nextVariants) do
            if value.key == selectedKey then
                self.index = index
            end
        end
        if self:GetSelected() then
            self.characterPrefs.selectedKey = self:GetSelected().key
        end
        return self:GetSelected()
    end

    return self
end

local function fixture(options)
    options = options or {}
    local calls = {
        build = 0,
        modelNew = 0,
        modelRefresh = 0,
        previewNew = 0,
        previewOpen = 0,
        previewSelect = {},
        previewClose = 0,
        refresh = 0,
        show = 0,
        statuses = {},
        deferred = {},
    }
    local previewCallback
    local builds = options.builds or {
        { variant("breton:1"), variant("breton:3"), variant("dunmer:1") },
    }

    local ui = {}
    function ui:Refresh()
        calls.refresh = calls.refresh + 1
    end
    function ui:Show()
        calls.show = calls.show + 1
    end
    function ui:SetStatus(status, text)
        calls.statuses[#calls.statuses + 1] = { status = status, text = text }
    end

    local preview = {}
    function preview:Open()
        calls.previewOpen = calls.previewOpen + 1
        if options.previewUnavailable then
            return false, "preview unavailable"
        end
        return true
    end
    function preview:Select(selected)
        calls.previewSelect[#calls.previewSelect + 1] = selected and selected.key or false
    end
    function preview:Close()
        calls.previewClose = calls.previewClose + 1
    end

    local accountPrefs = { favorites = {}, hidden = {} }
    local characterPrefs = { selectedKey = nil, preferredWeight = 1, showHidden = false }
    local buildIndex = 0
    local deps = {
        accountPrefs = accountPrefs,
        characterPrefs = characterPrefs,
        catalogBuild = function()
            calls.build = calls.build + 1
            if options.catalogError == true or options.catalogError == calls.build then
                error("catalog exploded")
            end
            buildIndex = math.min(buildIndex + 1, #builds)
            return builds[buildIndex], options.diagnostics or {}
        end,
        modelNew = function(variants, account, character)
            calls.modelNew = calls.modelNew + 1
            return newModel(variants, account, character, calls)
        end,
        previewNew = function(callback)
            calls.previewNew = calls.previewNew + 1
            previewCallback = callback
            return preview
        end,
        ui = ui,
        defer = function(callback)
            calls.deferred[#calls.deferred + 1] = callback
        end,
    }

    local controller = KanaOutfitBrowser.Controller.New(deps)
    return controller, calls, function(status, text) previewCallback(status, text) end, accountPrefs, characterPrefs
end

test("open prepares the catalog and previews the selected set only after the scene is shown", function()
    local controller, calls = fixture()

    controller:Open()
    equal(calls.build, 1, "catalog build count")
    equal(calls.modelNew, 1, "model construction count")
    equal(calls.show, 1, "scene show count")
    equal(calls.previewOpen, 0, "preview must wait for native scene fragments")
    equal(#calls.previewSelect, 0, "selection must wait for native scene fragments")

    controller:OnSceneShown()
    equal(calls.previewOpen, 1, "preview open count")
    equal(calls.previewSelect[1], "breton:1", "initial selection")

    controller:MoveHorizontal(1)
    equal(calls.previewSelect[2], "breton:3", "changed selection")
end)

test("preference-only refreshes do not reapply the preview", function()
    local controller, calls = fixture()
    controller:Open()
    controller:OnSceneShown()

    controller:ToggleFavorite()
    equal(#calls.previewSelect, 1, "favorite toggle must not select preview again")
    truthy(controller.accountPrefs.favorites["breton:1"], "favorite preference saved")

    controller:SetShowHidden(true)
    equal(#calls.previewSelect, 1, "unchanged selected key must not select preview again")
    truthy(controller.characterPrefs.showHidden, "show hidden preference saved")
end)

test("an actual catalog refresh reapplies the current key once", function()
    local controller, calls = fixture({
        builds = {
            { variant("breton:1"), variant("dunmer:1") },
            { variant("breton:1"), variant("dunmer:1"), variant("orc:1") },
        },
    })
    controller:Open()
    controller:OnSceneShown()

    controller:QueueCatalogRefresh()
    controller:QueueCatalogRefresh()
    equal(#calls.deferred, 1, "catalog event burst must coalesce")
    calls.deferred[1]()

    equal(calls.build, 2, "catalog rebuilt")
    equal(calls.modelNew, 1, "live refresh must keep the open favorite snapshot")
    equal(calls.modelRefresh, 1, "existing model reconciles catalog")
    equal(#calls.previewSelect, 2, "catalog refresh reapplies preview once")
    equal(calls.previewSelect[2], "breton:1", "same stable selection restored")
end)

test("preview unavailability remains explicit and never selects", function()
    local controller, calls = fixture({ previewUnavailable = true })
    controller:Open()
    controller:OnSceneShown()

    equal(#calls.previewSelect, 0, "unavailable preview cannot select")
    local status = calls.statuses[#calls.statuses]
    equal(status.status, "unavailable", "unavailable status")
    equal(status.text, "preview unavailable", "unavailable reason")
end)

test("a catalog exception aborts opening without leaking an active controller", function()
    local controller, calls = fixture({ catalogError = true })

    equal(controller:Open(), false, "failed open result")
    equal(controller.open, false, "controller active flag")
    equal(calls.show, 0, "failed catalog must not enter preview scene")
    equal(calls.previewNew, 0, "failed catalog must not allocate preview")
    equal(controller.status, "error", "catalog exception status")
    truthy(controller.statusText:find("catalog exploded", 1, true), "catalog error detail")
end)

test("a deferred catalog exception keeps the open model and reports an error", function()
    local controller, calls = fixture({ catalogError = 2 })
    controller:Open()
    controller:OnSceneShown()
    controller:QueueCatalogRefresh()

    calls.deferred[1]()

    equal(controller.open, true, "open model survives refresh failure")
    equal(controller.model:GetSelected().key, "breton:1", "old catalog selection survives")
    equal(#calls.previewSelect, 1, "failed refresh does not relabel old preview")
    equal(controller.status, "error", "refresh exception status")
    truthy(controller.statusText:find("catalog exploded", 1, true), "refresh error detail")
end)

test("an empty catalog is distinct from preview failure", function()
    local controller, calls = fixture({ builds = { {} }, diagnostics = { "No armor styles found" } })
    controller:Open()
    controller:OnSceneShown()

    equal(#calls.previewSelect, 0, "empty catalog has nothing to preview")
    equal(controller.status, "empty", "empty status")
    equal(controller.statusText, "No armor styles found", "catalog diagnostic")
end)

test("losing the selected set clears the owned preview instead of leaving stale armor", function()
    local controller, calls = fixture()
    controller:Open()
    controller:OnSceneShown()

    controller.model.index = nil
    controller:OnModelChanged(false)

    equal(#calls.previewSelect, 2, "selection removal reaches preview adapter")
    equal(calls.previewSelect[2], false, "nil selection clears owned preview")
    equal(controller.status, "empty", "selection removal status")
end)

test("showing a first survivor after an empty open lazily starts preview", function()
    local controller, calls = fixture({ builds = { {} } })
    controller:Open()
    controller:OnSceneShown()
    equal(calls.previewOpen, 0, "empty scene does not reserve preview")

    controller.model.variants[1] = variant("returned:3")
    controller.model.index = 1
    controller:OnModelChanged(false)

    equal(calls.previewOpen, 1, "preview starts when a selectable set appears")
    equal(calls.previewSelect[1], "returned:3", "new survivor is previewed")
end)

test("close invalidates late callbacks and deferred catalog work", function()
    local controller, calls, emit = fixture()
    controller:Open()
    controller:OnSceneShown()
    controller:QueueCatalogRefresh()
    local statusCount = #calls.statuses

    controller:Close()
    equal(calls.previewClose, 1, "preview cleanup count")
    emit("ready", "late success")
    calls.deferred[1]()

    equal(#calls.statuses, statusCount, "late preview callback ignored")
    equal(calls.build, 1, "late catalog refresh ignored")
end)

test("native scene avoids item preview after both real-client rejections", function()
    local calls = {}
    local scene = {}
    function scene:AddFragmentGroup(group)
        calls[#calls + 1] = { "group", group }
    end
    function scene:AddFragment(fragment)
        calls[#calls + 1] = { "fragment", fragment }
    end

    local mouseGroup = {}
    local frameGroup = {}
    local optionsFragment, previewFragment = {}, {}
    local rootFragment = {}
    KanaOutfitBrowser.UI.AddSceneFragments(scene, mouseGroup, frameGroup, optionsFragment, previewFragment, rootFragment)

    equal(calls[1][1], "group", "mouse group operation")
    equal(calls[1][2], mouseGroup, "mouse group")
    equal(calls[2][2], frameGroup, "player framing group")
    equal(calls[3][2], rootFragment, "UI follows ordinary player framing")
    equal(#calls, 3, "no item-preview fragments are enabled")
end)

test("scene hiding removes keyboard interception before closing preview", function()
    local order = {}
    SCENE_SHOWING = "showing"
    SCENE_SHOWN = "shown"
    SCENE_HIDING = "hiding"
    SCENE_HIDDEN = "hidden"
    PushActionLayerByName = function(name)
        order[#order + 1] = "push:" .. name
    end
    RemoveActionLayerByName = function(name)
        order[#order + 1] = "remove:" .. name
    end

    local fake = {
        controller = {
            open = true,
            OnSceneShown = function()
                order[#order + 1] = "shown"
            end,
            Close = function()
                order[#order + 1] = "close"
            end,
        },
    }

    KanaOutfitBrowser.UI.OnSceneStateChanged(fake, nil, SCENE_SHOWING)
    KanaOutfitBrowser.UI.OnSceneStateChanged(fake, SCENE_SHOWING, SCENE_SHOWN)
    KanaOutfitBrowser.UI.OnSceneStateChanged(fake, SCENE_SHOWN, SCENE_HIDING)

    equal(order[1], "push:KanaOutfitBrowserScene", "input activation")
    equal(order[2], "shown", "controller opens preview at shown")
    equal(order[3], "remove:KanaOutfitBrowserScene", "input removed at hiding")
    equal(order[4], "close", "preview closes before native fragments hide")
end)

test("scene keyboard handler maps physical arrows and Escape without depending on user binds", function()
    KEY_LEFTARROW = 1
    KEY_RIGHTARROW = 2
    KEY_UPARROW = 3
    KEY_DOWNARROW = 4
    KEY_ESCAPE = 5
    local calls = {}
    KanaOutfitBrowser.controller = {
        open = true,
        MoveHorizontal = function(_, delta) calls[#calls + 1] = "h:" .. delta end,
        MoveVertical = function(_, delta) calls[#calls + 1] = "v:" .. delta end,
        ui = { Hide = function() calls[#calls + 1] = "close" end },
    }

    truthy(KanaOutfitBrowser.HandleKeyDown(KEY_LEFTARROW), "left consumed")
    truthy(KanaOutfitBrowser.HandleKeyDown(KEY_RIGHTARROW), "right consumed")
    truthy(KanaOutfitBrowser.HandleKeyDown(KEY_UPARROW), "up consumed")
    truthy(KanaOutfitBrowser.HandleKeyDown(KEY_DOWNARROW), "down consumed")
    truthy(KanaOutfitBrowser.HandleKeyDown(KEY_ESCAPE), "escape consumed")
    equal(KanaOutfitBrowser.HandleKeyDown(99), false, "unrelated key falls through")
    equal(table.concat(calls, ","), "h:-1,h:1,v:-1,v:1,close", "physical key actions")
end)

local function fakeButton()
    local button = { handlers = {} }
    function button:SetHandler(name, handler) self.handlers[name] = handler end
    function button:SetHidden(value) self.hidden = value end
    function button:SetEnabled(value) self.enabled = value end
    function button:SetAlpha(value) self.alpha = value end
    function button:SetText(value) self.text = value end
    function button:SetState(value) self.state = value end
    function button:SetNormalFontColor() end
    function button:SetPressedFontColor() end
    function button:SetMouseOverFontColor() end
    function button:SetDisabledFontColor() end
    return button
end

local function fakeStyleControl()
    local children = {
        Style = fakeButton(),
        Light = fakeButton(),
        Medium = fakeButton(),
        Heavy = fakeButton(),
        Unified = fakeButton(),
    }
    local control = { children = children }
    function control:GetNamedChild(name) return self.children[name] end
    function control:SetAlpha(value) self.alpha = value end
    function control:SetHidden(value) self.hidden = value end
    return control
end

test("scroll-list pool release hides rows and setup unhides acquired rows", function()
    BSTATE_NORMAL = 1
    BSTATE_PRESSED = 2

    local controller = {
        accountPrefs = { favorites = {}, hidden = {} },
        model = { GetSelected = function() return nil end },
        Select = function() end,
        SelectRow = function() end,
    }
    local ui = setmetatable({ controller = controller }, { __index = KanaOutfitBrowser.UI })

    local style = fakeStyleControl()
    KanaOutfitBrowser.UI.ResetStyleRowForPool(style)
    equal(style.hidden, true, "released style row hidden")
    ui:SetupStyleRow(style, { row = { name = "Breton", variants = {} } })
    equal(style.hidden, false, "acquired style row shown")

    local title = fakeButton()
    local header = { GetNamedChild = function(_, name) return name == "Title" and title end }
    function header:SetHidden(value) self.hidden = value end
    KanaOutfitBrowser.UI.ResetHeaderRowForPool(header)
    equal(header.hidden, true, "released header row hidden")
    ui:SetupHeaderRow(header, { row = { title = "Любимое" } })
    equal(header.hidden, false, "acquired header row shown")
    equal(title.text, "Любимое", "acquired header populated")
end)

test("same row membership refresh replaces production row data and tooltip closures", function()
    BSTATE_NORMAL = 1
    BSTATE_PRESSED = 2
    TOP = 1
    GetString = function(_, slotId) return "slot-" .. tostring(slotId) end

    local shownTooltip
    ZO_Tooltips_ShowTextTooltip = function(_, _, text) shownTooltip = text end
    ZO_Tooltips_HideTextTooltip = function() end

    local visible = fakeStyleControl()
    local list = { data = {}, visible = visible }
    ZO_ScrollList_Clear = function(target) target.data = {} end
    ZO_ScrollList_GetDataList = function(target) return target.data end
    ZO_ScrollList_CreateDataEntry = function(dataType, data)
        return { dataType = dataType, data = data }
    end
    ZO_ScrollList_ScrollDataIntoView = function() end

    local controller = {
        accountPrefs = { favorites = {}, hidden = {} },
        model = { GetSelected = function() return nil end },
        Select = function() end,
        SelectRow = function() end,
    }
    local ui = setmetatable({
        controller = controller,
        list = list,
        dataIndexByKey = {},
    }, { __index = KanaOutfitBrowser.UI })

    local function setupVisible()
        if list.data[1] then
            ui:SetupStyleRow(list.visible, list.data[1].data)
        end
    end
    ZO_ScrollList_Commit = function() setupVisible() end
    ZO_ScrollList_RefreshVisible = function() setupVisible() end

    local oldVariant = variant("breton:1")
    oldVariant.name = "Old variant"
    local oldRow = { kind = "style", styleKey = "breton", name = "Old style", variants = { [1] = oldVariant } }
    ui:RefreshRows({ oldRow }, oldVariant.key)
    equal(visible.children.Style.text, "Old style", "initial visible style")

    local newVariant = variant("breton:1")
    newVariant.name = "New variant"
    newVariant.missingSlots = { 7 }
    local newRow = { kind = "style", styleKey = "breton", name = "New style", variants = { [1] = newVariant } }
    ui:RefreshRows({ newRow }, newVariant.key)

    equal(list.data[1].data.row, newRow, "scroll entry receives refreshed row object")
    equal(visible.children.Style.text, "New style", "visible setup receives refreshed name")
    visible.children.Light.handlers.OnMouseEnter(visible.children.Light)
    truthy(shownTooltip:find("New variant", 1, true), "tooltip closure receives refreshed variant")
    truthy(shownTooltip:find("slot%-7"), "tooltip receives refreshed missing slots")
end)

test("entering from a native Collections tab opens once without showing recursively", function()
    local controller, calls = fixture()
    SCENE_SHOWING, SCENE_SHOWN, SCENE_HIDING = "showing", "shown", "hiding"
    PushActionLayerByName = function() end
    RemoveActionLayerByName = function() end
    local ui = { controller = controller }
    KanaOutfitBrowser.UI.OnSceneStateChanged(ui, nil, SCENE_SHOWING)
    equal(controller.open, true, "native tab opens controller")
    equal(calls.build, 1, "catalog built on tab entry")
    equal(calls.show, 0, "no recursive scene show")
    KanaOutfitBrowser.UI.OnSceneStateChanged(ui, SCENE_SHOWING, SCENE_SHOWN)
    equal(calls.previewOpen, 1, "preview starts after fragments show")
    KanaOutfitBrowser.UI.OnSceneStateChanged(ui, SCENE_SHOWN, SCENE_HIDING)
    equal(controller.open, false, "switching tabs closes controller")
    equal(calls.previewClose, 1, "switching tabs clears preview")
end)

test("catalog refresh preserves the unavailable-preview explanation", function()
    local controller = fixture({ previewUnavailable = true })
    controller:Open()
    controller:OnSceneShown()
    equal(controller.status, "unavailable")
    local reason = controller.statusText
    controller:RefreshCatalog()
    equal(controller.status, "unavailable", "catalog update must not claim preview is loading")
    equal(controller.statusText, reason, "restriction remains visible")
end)

test("UI registers direct native input targets on the current preview", function()
    local bindings = {}
    local ui = setmetatable({
        root = {}, previewButton = {},
        controller = { preview = { BindControl = function(_, control, event)
            bindings[#bindings + 1] = { control, event }
        end } },
    }, KanaOutfitBrowser.UI)
    ui:BindPreviewControls()
    equal(bindings[1][1], ui.previewButton)
    equal(bindings[1][2], "OnClicked")
    equal(bindings[2][1], ui.root)
    equal(bindings[2][2], "OnKeyUp")
end)

test("failed UI construction leaves controller closed and a later open can recover", function()
    local controller, calls = fixture()
    local goodUI = controller.ui
    controller.ui = nil
    controller.dependencies.uiNew = function() error("UI construction failed") end
    local ok, result = pcall(controller.Open, controller)
    equal(ok, true, "opening reports its original failure without poisoning toggle")
    equal(result, false, "failed open")
    equal(controller.open, false, "failed construction must not leave open=true")
    truthy(controller.statusText:find("UI construction failed", 1, true), "original failure retained")
    controller.dependencies.uiNew = function() return goodUI end
    controller:Toggle()
    equal(controller.open, true, "next toggle retries opening")
    equal(calls.show, 1, "recovery shows scene")
end)

test("scene creation uses native ZO_Scene constructor", function()
    local constructed
    SCENE_MANAGER = {} -- The native manager has no CreateScene method.
    local scene = {
        RegisterCallback = function() end,
        AddFragment = function() end,
        AddFragmentGroup = function() end,
    }
    ZO_Scene = { New = function(_, name, manager)
        equal(name, "kanaOutfitBrowser", "scene name")
        equal(manager, SCENE_MANAGER, "scene owner")
        constructed = true
        return scene
    end }
    ZO_ItemPreviewOptionsFragment = { New = function() return {} end }
    ZO_FadeSceneFragment = { New = function() return {} end }
    FRAGMENT_GROUP = { MOUSE_DRIVEN_UI_WINDOW = {}, FRAME_TARGET_STANDARD_RIGHT_PANEL = {} }
    ITEM_PREVIEW_KEYBOARD = { GetFragment = function() return {} end }
    local ui = setmetatable({ root = {} }, KanaOutfitBrowser.UI)
    ui:CreateScene()
    truthy(constructed, "native constructor called")
    equal(ui.scene, scene, "native scene retained")
end)

KanaOutfitBrowser = {}
dofile("KanaOutfitBrowser/UI.lua")
dofile("KanaOutfitBrowser/KanaOutfitBrowser.lua")

local failures = 0
for _, entry in ipairs(tests) do
    local ok, message = pcall(entry.fn)
    if ok then
        io.write("ok - ", entry.name, "\n")
    else
        failures = failures + 1
        io.write("not ok - ", entry.name, "\n", tostring(message), "\n")
    end
end

if failures > 0 then
    error(string.format("%d integration test(s) failed", failures))
end

io.write(string.format("%d integration tests passed\n", #tests))
