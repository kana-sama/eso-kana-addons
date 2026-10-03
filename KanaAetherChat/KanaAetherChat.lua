local ADDON_NAME = "KanaAetherChat"

local function Initialize(_, addonName)
    if addonName ~= ADDON_NAME then return end
    EVENT_MANAGER:UnregisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED)

    local messenger = AetherChat.Messenger
    local editBox = ZO_ChatWindowTextEntryEditBox
    local sceneManager = SCENE_MANAGER
    local focusRequest = 0
    local ownsCursor = false
    local FOCUS_UPDATE = ADDON_NAME .. "_Focus"

    -- Keep guild rows visible even when AetherChat's private folder flag is
    -- collapsed. Mutate the returned list in place so its internal currentItems
    -- (selection, navigation and saved ordering) sees the same rows as the UI.
    local buildChannelItems = messenger.BuildChannelItems
    messenger.BuildChannelItems = function(...)
        local items = buildChannelItems(...)
        local folderIndex
        for index, item in ipairs(items) do
            if item.id == "guilds_folder" then folderIndex = index end
            if item.isGuildChild then return items end
        end
        if not folderIndex then return items end
        local folder = items[folderIndex]
        folder.name = folder.name:gsub("^%[%+%]", "[-]")
        local insertAt = folderIndex + 1
        for slot = 1, GetNumGuilds() do
            local guildId = GetGuildId(slot)
            if guildId and guildId > 0 then
                table.insert(items, insertAt, {
                    id = "guild" .. slot,
                    name = "  " .. GetGuildName(guildId),
                    prefix = "/g" .. slot,
                    icon = "/esoui/art/guild/tabicon_roster_up.dds",
                    isGuildChild = true,
                })
                insertAt = insertAt + 1
            end
        end
        return items
    end
    messenger.RefreshChannelList()

    -- AetherChat unhides the control before refreshing its HUD fragment.
    -- HUD fragment Show then skips its animation and never calls OnShown.
    -- Complete only that idle, already-visible case; leave real fades alone.
    local fragment = messenger.fragment
    if fragment then
        ZO_PostHook(fragment, "Show", function()
            if fragment:GetState() == SCENE_FRAGMENT_SHOWING
                and not messenger.window:IsHidden()
                and not fragment:GetAnimation():IsPlaying() then
                fragment:OnShown()
            end
        end)
    end

    -- Raise all parts of the docked input together. Raising only its container
    -- does not establish the edit box's order relative to the background.
    local entryControl = ZO_ChatWindowTextEntry
    local originalDrawing = {}
    local function RaiseControl(control, layer)
        if not control then return end
        if not originalDrawing[control] then
            originalDrawing[control] = {control:GetDrawTier(), control:GetDrawLayer()}
        end
        control:SetDrawTier(DT_HIGH)
        if layer then control:SetDrawLayer(layer) end
    end
    ZO_PostHook(messenger, "DockNativeChatEntry", function()
        RaiseControl(entryControl)
        RaiseControl(entryControl:GetNamedChild("Edit"), DL_BACKGROUND)
        RaiseControl(entryControl:GetNamedChild("Label"), DL_TEXT)
        RaiseControl(editBox, DL_TEXT)
    end)
    ZO_PostHook(messenger, "UndockNativeChatEntry", function()
        for control, drawing in pairs(originalDrawing) do
            control:SetDrawTier(drawing[1])
            control:SetDrawLayer(drawing[2])
        end
        originalDrawing = {}
    end)

    local function IsVisible()
        return messenger.isOpen and messenger.window and not messenger.window:IsHidden()
    end

    local function IsHUD()
        return sceneManager:IsShowing("hud") or sceneManager:IsShowing("hudui")
    end

    local function RestoreCursor()
        if ownsCursor then
            ownsCursor = false
            if IsHUD() and not sceneManager:IsLockedInUIMode() then
                sceneManager:SetInUIMode(false)
            end
        end
    end

    local function CancelFocus()
        focusRequest = focusRequest + 1
        EVENT_MANAGER:UnregisterForUpdate(FOCUS_UPDATE)
    end

    local function RefreshInputDrawing()
        -- In-game reproduction: after Escape/reopen the focused edit can stop
        -- drawing until ANY resize-edge Glow is shown. Tooltips alone do not
        -- help. Reproduce only that confirmed rendering trigger, without moving
        -- the window, changing text, or calling mouse/focus event handlers.
        local edge = messenger.window:GetNamedChild("ResizeBottom")
        local glow = edge and edge:GetNamedChild("Glow")
        if not glow or not glow:IsHidden() then return end
        glow:SetHidden(false)
        -- Let the visible backdrop reach a rendered frame before hiding it.
        zo_callLater(function()
            if not MouseIsOver(edge) then glow:SetHidden(true) end
        end, 32)
    end

    local function FocusInput()
        CancelFocus()
        if not messenger.isOpen or messenger.isFadingOut or not IsHUD() then return end
        local request = focusRequest
        local deadline = GetGameTimeMilliseconds() + 1500

        if not sceneManager:IsInUIMode() then
            ownsCursor = sceneManager:SetInUIMode(true) == true
        end

        -- 1.3.3 opens asynchronously. Wait for the window/fragment and its fade,
        -- instead of dropping the request when the first frame is still hidden.
        EVENT_MANAGER:RegisterForUpdate(FOCUS_UPDATE, 16, function()
            if request ~= focusRequest or not messenger.isOpen or messenger.isFadingOut
                or not IsHUD() or GetGameTimeMilliseconds() >= deadline then
                CancelFocus()
                return
            end
            if not IsVisible() or messenger.isFadingIn then return end
            if messenger.fragment and messenger.fragment:GetState() ~= SCENE_FRAGMENT_SHOWN then return end
            CancelFocus()
            messenger.DockNativeChatEntry()
            -- Preserve the draft/channel and leave the original chat minimized.
            CHAT_SYSTEM:StartTextEntry(nil, nil, nil, true)
            if CHAT_SYSTEM.textEntry:IsOpen() then
                editBox:TakeFocus()
                CHAT_SYSTEM.textEntry:FadeIn()
                RefreshInputDrawing()
            end
        end)
    end

    -- Explicit close must finish before cursor/focus callbacks can run. In
    -- 1.3.3 Hide(true) leaves isOpen=true and allows RecordInteraction to reopen
    -- the window; its fade also refuses to close the loot channel.
    local originalHide = messenger.Hide
    messenger.Hide = function()
        CancelFocus()
        originalHide(false)
        RestoreCursor()
    end

    -- Named handlers run alongside ESO's handlers. Never wrap SubmitTextEntry
    -- or call the native OnEnter handler from addon code: that taints the stack
    -- reaching the private SendChatMessage API.
    local commandPending = false
    local textRevision = 0
    editBox:SetHandler("OnTextChanged", function()
        textRevision = textRevision + 1
        local revision = textRevision
        local text = editBox:GetText()
        if text ~= "" then
            commandPending = text:match("^%s*/") ~= nil
        else
            -- Native submit clears text before our OnEnter handler may run.
            -- Retain the command flag for this event only, not the next input.
            zo_callLater(function()
                if revision == textRevision then commandPending = false end
            end, 0)
        end
    end, ADDON_NAME .. "_CommandText")
    editBox:SetHandler("OnEnter", function()
        if not commandPending or not IsVisible() then return end
        local request = focusRequest
        zo_callLater(function()
            -- Enter may only accept autocomplete. Close after actual submission,
            -- when the native entry is closed, and never after a newer opening.
            if request == focusRequest and not CHAT_SYSTEM.textEntry:IsOpen() then
                CancelFocus()
                messenger.Hide()
            end
        end, 0)
    end, ADDON_NAME .. "_CommandEnter")

    local function CloseOnEscape()
        if not IsVisible() or not IsHUD() then return false end
        -- Let an actual modal dialog handle its own Escape first.
        if ZO_Dialogs_IsShowingDialog() then return false end
        messenger.Hide()
        return true
    end

    -- These are the existing AetherChat bindings, so no new key assignment is needed.
    ZO_PostHook(messenger, "Toggle", function()
        if messenger.isOpen and not messenger.isFadingOut then FocusInput() end
    end)
    ZO_PostHook(messenger, "FocusChatInput", function()
        if editBox:HasFocus() then
            FocusInput()
        else
            CancelFocus()
            RestoreCursor()
        end
    end)

    -- Capture rendering state before entering a diagnostic slash command changes
    -- focus. Message contents are neither stored nor printed.
    local snapshots = {}
    local function CaptureVisualState(reason)
        local entry = CHAT_SYSTEM.textEntry
        local lines = {string.format(
            "%s: focus=%s nativeOpen=%s scene=%s open=%s fadeIn=%s fadeOut=%s fragment=%s",
            reason, tostring(editBox:HasFocus()), tostring(entry:IsOpen()),
            tostring(sceneManager:GetCurrentSceneName()), tostring(messenger.isOpen),
            tostring(messenger.isFadingIn), tostring(messenger.isFadingOut),
            tostring(messenger.fragment and messenger.fragment:GetState()))}
        local control = editBox
        for _ = 1, 6 do
            if not control then break end
            local width, height = control:GetDimensions()
            lines[#lines + 1] = string.format(
                "%s: hidden=%s alpha=%.2f size=%.0fx%.0f tier=%s layer=%s level=%s",
                control:GetName(), tostring(control:IsHidden()), control:GetAlpha(),
                width, height, tostring(control:GetDrawTier()),
                tostring(control:GetDrawLayer()), tostring(control:GetDrawLevel()))
            if control == messenger.window then break end
            control = control:GetParent()
        end
        local nativeControl = entry:GetControl()
        lines[#lines + 1] = "nativeControl=" .. tostring(nativeControl and nativeControl:GetName())
        snapshots[reason] = lines
    end
    ZO_PostHook(messenger, "FocusChatInput", function()
        CaptureVisualState("hotkey")
        zo_callLater(function() CaptureVisualState("after600ms") end, 600)
    end)
    ZO_PostHookHandler(editBox, "OnTextChanged", function()
        -- Retain the last normal typing state while the diagnostic is entered.
        local text = editBox:GetText()
        if editBox:HasFocus() and text ~= "" and not text:match("^/kac") then
            CaptureVisualState("typing")
        end
    end)
    SLASH_COMMANDS["/kacdebug"] = function()
        d("KanaAetherChat 1.2.0: visual diagnostics (no message text)")
        for _, reason in ipairs({"hotkey", "after600ms", "typing"}) do
            for _, line in ipairs(snapshots[reason] or {reason .. ": no snapshot"}) do
                d(line)
            end
        end
    end

    -- Focused edit controls consume Escape before the global game-menu binding.
    ZO_PreHookHandler(editBox, "OnEscape", CloseOnEscape)
    local searchBox = messenger.window:GetNamedChild("SearchBox")
    local searchEdit = searchBox and searchBox:GetNamedChild("Edit")
    if searchEdit then
        ZO_PreHookHandler(searchEdit, "OnEscape", CloseOnEscape)
    end
    ZO_PreHook(sceneManager, "OnToggleGameMenuBinding", CloseOnEscape)
end

EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED, Initialize)
