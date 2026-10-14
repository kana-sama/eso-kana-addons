local K = KanaArchiveAchievements
local V = {}
K.View = V
local ICON = 'esoui/art/treeicons/achievements_indexicon_summary_up.dds'
local MARGIN, PANEL_GAP, FOOTER_GAP = 24, 24, 16

function V.New(api)
    local self = setmetatable({api = api, cards = {}}, {__index = V})
    local wm = api.WINDOW_MANAGER
    self.root = wm:CreateTopLevelWindow('KanaArchiveAchievementsPanel')
    self.root:SetDrawTier(api.DT_HIGH)
    self.root:SetMouseEnabled(true)
    self.root:SetHidden(true)
    self.scroll = wm:CreateControlFromVirtual('KanaArchiveAchievementsScroll', self.root, 'ZO_ScrollContainer')
    self.scroll:SetAnchor(api.TOPLEFT, self.root, api.TOPLEFT)
    self.viewport = self.scroll:GetNamedChild('Scroll')
    self.child = self.viewport:GetNamedChild('Child')
    self.child:SetResizeToFitDescendents(false)
    self.child:SetMouseEnabled(true)
    local function wheel(_, delta) api.ZO_Scroll_OnMouseWheel(self.scroll, delta) end
    self.root:SetHandler('OnMouseWheel', wheel)
    self.child:SetHandler('OnMouseWheel', wheel)
    self.root:SetHandler('OnUpdate', function()
        local bounds = self:Bounds()
        if bounds and (bounds.width ~= self.width or bounds.top ~= self.top or bounds.height ~= self.availableHeight) then self:Layout() end
    end)
    local ru = api.GetCVar('language.2') == 'ru'
    self.keybinds = {
        alignment = api.KEYBIND_STRIP_ALIGN_RIGHT,
        {name = ru and 'Достижения: вверх' or 'Achievements: scroll up', keybind = 'UI_SHORTCUT_LEFT_TRIGGER', callback = function() self:Scroll(-160) end},
        {name = ru and 'Достижения: вниз' or 'Achievements: scroll down', keybind = 'UI_SHORTCUT_RIGHT_TRIGGER', callback = function() self:Scroll(160) end},
    }
    return self
end

local function Pool(api, template, parent, factory)
    local pool = api.ZO_ControlPool:New(template, parent)
    if factory then pool:SetCustomFactoryBehavior(factory) end
    return pool
end

function V:CreateCard(index)
    local a = self.api
    local control = a.WINDOW_MANAGER:CreateControlFromVirtual('KanaArchiveAchievementsCard' .. index, self.child, 'KanaArchiveAchievementsCard')
    control:SetAnchor(a.TOPLEFT, self.child, a.TOPLEFT)
    control:SetHandler('OnMouseWheel', function(_, delta) a.ZO_Scroll_OnMouseWheel(self.scroll, delta) end)
    local check = Pool(a, 'ZO_AchievementCheckbox', control, function(c) c.label = c:GetNamedChild('Label') end)
    local bars = Pool(a, 'ZO_AchievementsStatusBar', control, function(c)
        c:SetWidth(345)
        c.label, c.progress = c:GetNamedChild('Label'), c:GetNamedChild('Progress')
        a.ZO_StatusBar_SetGradientColor(c, a.ZO_XP_BAR_GRADIENT_COLORS)
        for _, name in ipairs({'BGLeft', 'BGRight', 'BGMiddle'}) do c:GetNamedChild(name):SetDrawLevel(2) end
    end)
    local labels = Pool(a, 'ZO_AchievementRewardLabel', control)
    local function iconFactory(c) c.label, c.icon = c:GetNamedChild('Label'), c:GetNamedChild('Icon') end
    local icons = Pool(a, 'ZO_AchievementRewardItem', control, iconFactory)
    local thumbs = Pool(a, 'ZO_AchievementLineThumb', control, iconFactory)
    local dyes = Pool(a, 'ZO_AchievementDyeSwatch', control)
    local frames = Pool(a, 'ZO_AchievementIconCharacterFrameBorder', control)
    local object = a.AchievementContainer:New(control, check, bars, labels, icons, thumbs, dyes, frames)
    -- Native Expand plays a sound; hovering a choice should stay silent.
    object.PlayExpandCollapseSound = function() end
    local card = {control = control, object = object}
    self.cards[index] = card
    return card
end

function V:UpdateIndicators(selector, model)
    local a = self.api
    for _, buff in ipairs(selector.buffControls or {}) do
        local icon = buff.kanaArchiveIndicator
        if not icon then
            icon = a.WINDOW_MANAGER:CreateControl(nil, buff, a.CT_TEXTURE)
            icon:SetTexture(ICON)
            icon:SetDimensions(20, 20)
            icon:SetDrawTier(a.DT_HIGH)
            icon:SetDrawLayer(a.DL_OVERLAY)
            icon:SetDrawLevel(4)
            icon:SetMouseEnabled(false)
            icon:SetExcludeFromResizeToFitExtents(true)
            buff.kanaArchiveIndicator = icon
        end
        icon:ClearAnchors()
        -- The native label is 220 units wide with centered, wrapping text.
        -- Measure the text itself; label text/font measurements are UI units.
        local lineHeight = buff.nameLabel:GetFontHeight()
        local textWidth = buff.nameLabel:GetTextWidth()
        icon:SetAnchor(a.TOPLEFT, buff.nameLabel, a.TOP, textWidth / 2 + 4, math.max(0, (lineHeight - 20) / 2))
        -- Parent visibility already hides the child. Copying its temporary
        -- hidden state during scene opening leaves the badge hidden afterwards.
        icon:SetHidden(#model:GetGoals(buff.abilityId, buff.bucketType) == 0)
    end
end

function V:HideIndicators(selector)
    for _, buff in ipairs(selector.buffControls or {}) do
        if buff.kanaArchiveIndicator then buff.kanaArchiveIndicator:SetHidden(true) end
    end
end

function V:Bounds()
    if not self.selector then return end
    local a, selector = self.api, self.selector
    local scale, gui = self.root:GetScale(), a.GuiRoot
    local width, height = gui:GetWidth() / scale, gui:GetHeight() / scale
    local bottom = selector.control:GetBottom()
    for _, control in ipairs({selector.control:GetNamedChild('BG'), selector.rerollButton, selector.currencyLabel}) do
        if not control:IsHidden() then bottom = math.max(bottom, control:GetBottom()) end
    end
    local limit = height - FOOTER_GAP
    local strip = a.ZO_KeybindStripControl
    if strip and not strip:IsHidden() then limit = math.min(limit, (strip:GetTop() - gui:GetTop()) / scale - FOOTER_GAP)
    else limit = height - 80 end
    local footer = a.IsInGamepadPreferredMode() and a.GAMEPAD_GENERIC_FOOTER and a.GAMEPAD_GENERIC_FOOTER.control
    if footer and not footer:IsHidden() then limit = math.min(limit, (footer:GetTop() - gui:GetTop()) / scale - FOOTER_GAP) end
    local top = (bottom - gui:GetTop()) / scale + PANEL_GAP
    return {width = math.max(0, width - MARGIN * 2), screenWidth = width, top = top, height = math.max(0, limit - top)}
end

function V:Layout()
    local bounds = self:Bounds()
    if not bounds then return end
    local a = self.api
    local _, offset = self.viewport:GetScrollOffsets()
    self.width, self.top, self.availableHeight = bounds.width, bounds.top, bounds.height
    local contentWidth = math.max(0, bounds.width - a.ZO_SCROLL_BAR_WIDTH)
    local heights = {}
    for i = 1, self.count or 0 do
        heights[i] = self.cards[i].control:GetHeight() / self.cards[i].control:GetScale() + 4
    end
    local positions, contentHeight = K.Model.Layout(contentWidth, heights)
    self.contentHeight = contentHeight
    local height = math.min(bounds.height, contentHeight)
    self.root:ClearAnchors()
    self.root:SetAnchor(a.TOPLEFT, a.GuiRoot, a.TOPLEFT, (bounds.screenWidth - bounds.width) / 2, bounds.top)
    self.root:SetDimensions(bounds.width, height)
    self.scroll:SetDimensions(bounds.width, height)
    self.child:SetDimensions(contentWidth, contentHeight)
    for i, position in ipairs(positions) do
        local control = self.cards[i].control
        control:ClearAnchors()
        control:SetAnchor(a.TOPLEFT, self.child, a.TOPLEFT, position.x, position.y)
    end
    self.root:SetHidden(height <= 0 or self.count == 0)
    a.ZO_Scroll_UpdateScrollBar(self.scroll)
    self:SetOffset(math.min(offset, math.max(0, contentHeight - height)))
    self:UpdateKeybinds()
end

function V:SetOffset(offset)
    local _, extents = self.viewport:GetScrollExtents()
    if extents > 0 then self.api.ZO_Scroll_ScrollAbsoluteInstantly(self.scroll, offset) else self.viewport:SetVerticalScroll(0) end
end

function V:UpdateKeybinds()
    local needed = self.api.IsInGamepadPreferredMode() and not self.root:IsHidden() and self.contentHeight > self.root:GetHeight() / self.root:GetScale()
    if needed and not self.bindingsAdded then self.api.KEYBIND_STRIP:AddKeybindButtonGroup(self.keybinds); self.bindingsAdded = true
    elseif not needed and self.bindingsAdded then self.api.KEYBIND_STRIP:RemoveKeybindButtonGroup(self.keybinds); self.bindingsAdded = false end
end

function V:Show(selector, ids, resetScroll)
    if #ids == 0 then self:Hide(); return end
    local _, offset = self.viewport:GetScrollOffsets()
    self.selector, self.count = selector, #ids
    for i, id in ipairs(ids) do
        local card = self.cards[i] or self:CreateCard(i)
        card.object:Hide()
        -- AchievementContainer.Show calls a TopLevelWindow-only method.
        -- Embedded cards use its native renderer and expanded layout directly.
        card.control:SetHidden(false)
        card.object.progress, card.object.timestamp = self.api.GetAchievementProgress(id), self.api.GetAchievementTimestamp(id)
        self.api.Achievement.Show(card.object, id)
        card.object:Expand()
    end
    for i = #ids + 1, #self.cards do self.cards[i].object:Hide() end
    self:Layout()
    self.root:BringWindowToTop()
    self:SetOffset(resetScroll and 0 or math.min(offset, math.max(0, self.contentHeight - self.root:GetHeight() / self.root:GetScale())))
end

function V:Hide()
    self.count = 0
    self.root:SetHidden(true)
    for _, card in ipairs(self.cards) do card.object:Hide() end
    self.selector = nil
    self:UpdateKeybinds()
end

function V:Scroll(delta)
    if not self.root:IsHidden() then self.api.ZO_Scroll_ScrollRelative(self.scroll, delta) end
end
