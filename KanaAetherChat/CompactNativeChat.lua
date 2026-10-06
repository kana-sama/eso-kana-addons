local ADDON_NAME = "KanaAetherChat"
local EVENT_NAME = ADDON_NAME .. "_CompactNativeChat"

local function ResizeRect(rect, edge, dx, dy, minWidth, minHeight, maxWidth, maxHeight)
    local left, top, width, height = rect.left, rect.top, rect.width, rect.height
    if edge == "move" then return left + dx, top + dy, width, height end
    if edge:find("left", 1, true) then
        width = math.max(minWidth, math.min(maxWidth, rect.width - dx))
        left = rect.left + rect.width - width
    elseif edge:find("right", 1, true) then
        width = math.max(minWidth, math.min(maxWidth, rect.width + dx))
    end
    if edge:find("top", 1, true) then
        height = math.max(minHeight, math.min(maxHeight, rect.height - dy))
        top = rect.top + rect.height - height
    elseif edge:find("bottom", 1, true) then
        height = math.max(minHeight, math.min(maxHeight, rect.height + dy))
    end
    return left, top, width, height
end

local function Install()
    EVENT_MANAGER:UnregisterForEvent(EVENT_NAME, EVENT_PLAYER_ACTIVATED)
    local saved = ZO_SavedVars:NewAccountWide("KanaAetherChatSavedVariables", 1, "Widget", {
        compactNativeChat = false,
    })
    if not saved.compactNativeChat then return end
    local container = CHAT_SYSTEM and CHAT_SYSTEM.primaryContainer
    if not container or not container.windowContainer then return end
    local root = container.control
    local content = container.windowContainer
    local entry = ZO_ChatWindowTextEntry
    local decorations, hookedBuffers = {}, {}
    local drag
    local hovered = false
    local ownControls = {}
    local minWidth = container.system.minContainerWidth or 200
    local minHeight = container.system.minContainerHeight or 80
    local maxWidth = container.system.maxContainerWidth or GuiRoot:GetWidth()
    local maxHeight = container.system.maxContainerHeight or GuiRoot:GetHeight()

    local background = WINDOW_MANAGER:CreateControl(EVENT_NAME .. "Background", root, CT_BACKDROP)
    ownControls[background] = true
    background:SetAnchorFill(root)
    background:SetDrawTier(DT_LOW)
    background:SetDrawLayer(DL_BACKGROUND)
    background:SetCenterColor(0.03, 0.03, 0.03, 0.8)
    background:SetEdgeColor(0.55, 0.55, 0.5, 0.9)
    background:SetEdgeTexture(nil, 1, 1, 1)
    background:SetMouseEnabled(false)
    background:SetHidden(true)

    local function IsLocked()
        -- ESO's primary-window lock belongs to the first tab.
        return container:IsLocked(1) ~= false
    end
    local function FinishDrag()
        if drag then
            drag = nil
            container:UpdateScrollVisibility()
            container:SaveSettings()
        end
    end
    local function BeginDrag(_, button)
        if button ~= MOUSE_BUTTON_INDEX_LEFT or IsLocked() or drag then return end
        local x, y = GetUIMousePosition()
        local left, top = root:GetLeft(), root:GetTop()
        local width, height = root:GetWidth(), root:GetHeight()
        -- The text buffer fills the window and can receive clicks at its edges.
        -- Resolve resize vs move here, regardless of which chat surface was hit.
        local border = 8
        local horizontal = x <= left + border and "left" or x >= left + width - border and "right"
        local vertical = y <= top + border and "top" or y >= top + height - border and "bottom"
        local edge = vertical and horizontal and (vertical .. "-" .. horizontal)
            or vertical or horizontal or "move"
        drag = {edge = edge, x = x, y = y, left = left, top = top, width = width, height = height}
    end
    local function OpenMenu(_, button, upInside)
        if button == MOUSE_BUTTON_INDEX_RIGHT and upInside ~= false then
            container:ShowContextMenu(1)
        end
    end
    local function MakeInteractive(control)
        control:SetMouseEnabled(true)
        if hookedBuffers[control] then return end
        hookedBuffers[control] = true
        control:SetHandler("OnMouseDown", BeginDrag, EVENT_NAME)
        control:SetHandler("OnMouseUp", OpenMenu, EVENT_NAME)
        control:SetHandler("OnMouseWheel", function(_, delta, ctrl, alt, shift)
            ZO_ChatSystem_OnMouseWheel(root, -delta, ctrl, alt, shift)
        end, EVENT_NAME)
        if control ~= root and control ~= content then
            -- Right-click anywhere, including a player/item link, opens chat options.
            ZO_PreHookHandler(control, "OnLinkMouseUp", function(_, _, button)
                if button == MOUSE_BUTTON_INDEX_RIGHT then
                    container:ShowContextMenu(1)
                    return true
                end
            end)
        end
    end
    local function HideDecoration(control)
        if not control or control == content or ownControls[control] then return end
        if not decorations[control] then
            decorations[control] = true
            ZO_PreHook(control, "SetHidden", function(self, hidden)
                -- The native input is shared with AetherChat. Hide it only here.
                return not hidden and (self ~= entry or self:GetParent() == root)
            end)
        end
        control:SetHidden(true)
    end
    local function Layout()
        content:ClearAnchors()
        content:SetAnchorFill(root)
        root:SetDimensionConstraints(minWidth, minHeight, maxWidth, maxHeight)
        root:SetResizeHandleSize(0) -- resize is handled by the same lock-aware mouse handler
        root:SetMovable(false)
        root:SetMouseEnabled(true)
        for index = 1, root:GetNumChildren() do
            HideDecoration(root:GetChild(index))
        end
        -- It may already be docked in AetherChat, outside root's child list.
        if entry and entry:GetParent() == root then HideDecoration(entry) end
        for _, window in ipairs(container.windows) do
            HideDecoration(window.tab)
            if window.buffer then MakeInteractive(window.buffer) end
        end
    end

    -- The ordinary chat fades the whole container. Here only our background
    -- fades by hover; individual message-line fading remains ESO's behavior.
    if container.fadeAnim then container.fadeAnim:Stop() end
    -- Otherwise a previously minimized chat would have no visible restore button.
    if CHAT_SYSTEM:IsMinimized() then CHAT_SYSTEM:Maximize() end
    root:SetAlpha(1)
    ZO_PreHook(container, "FadeIn", function()
        if container.currentBuffer then container.currentBuffer:ShowFadedLines() end
        return true
    end)
    ZO_PreHook(container, "FadeOut", function() return true end)
    MakeInteractive(content)
    -- Keep the native root wheel handler; adding another would scroll twice.
    root:SetHandler("OnMouseDown", BeginDrag, EVENT_NAME)
    root:SetHandler("OnMouseUp", OpenMenu, EVENT_NAME)

    root:SetHandler("OnUpdate", function()
        local locked = IsLocked()
        if locked then FinishDrag() end
        local inside = MouseIsOver(root) or drag ~= nil
        if inside and not hovered and container.currentBuffer then
            container.currentBuffer:ShowFadedLines()
        end
        hovered = inside
        background:SetHidden(not inside)
        if drag then
            local x, y = GetUIMousePosition()
            local left, top, width, height = ResizeRect(drag, drag.edge, x - drag.x, y - drag.y,
                minWidth, minHeight, maxWidth, maxHeight)
            root:ClearAnchors()
            root:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, left, top)
            root:SetDimensions(width, height)
        end
    end, EVENT_NAME)
    root:SetHandler("OnEffectivelyHidden", FinishDrag, EVENT_NAME)
    EVENT_MANAGER:RegisterForEvent(EVENT_NAME, EVENT_GLOBAL_MOUSE_UP, FinishDrag)
    ZO_PostHook(container, "PerformLayout", Layout)
    ZO_PostHook(container, "SetAsPrimary", Layout)
    ZO_PostHook(container, "UpdateInteractivity", Layout)
    ZO_PostHook(AetherChat.Messenger, "UndockNativeChatEntry", Layout)
    Layout()
end

EVENT_MANAGER:RegisterForEvent(EVENT_NAME, EVENT_PLAYER_ACTIVATED, Install)
