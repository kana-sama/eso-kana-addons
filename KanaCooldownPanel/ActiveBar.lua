local addon = KanaCooldownPanel
local PADDING, DURATION = 4, 0.18

function addon:CreateActiveBarHighlight(parent, width, cellHeight, gap)
    local control = WINDOW_MANAGER:CreateControl('KanaCooldownPanelActiveBar', parent, CT_TEXTURE)
    control:SetDimensions(width + PADDING * 2, cellHeight + PADDING * 2)
    control:SetTexture('eso-kana-addons/KanaCooldownPanel/textures/ActiveRow.dds')
    control:SetTextureCoords(0, 234 / 256, 0, 50 / 64)
    control:SetColor(1, 1, 1, 0.14)
    control:SetDrawLayer(DL_BACKGROUND)
    control:SetDrawLevel(0)
    control:SetMouseEnabled(false)
    control:SetHidden(true)
    local state = {control = control}
    self.activeBarHighlight = state

    local function Place(y)
        state.y = y
        control:ClearAnchors()
        control:SetAnchor(TOPLEFT, parent, TOPLEFT, -PADDING, y)
    end

    local function Stop()
        state.moving = false
        control:SetHandler('OnUpdate', nil)
    end

    local function Tick()
        local progress = math.max(0, math.min(1, (GetFrameTimeSeconds() - state.started) / DURATION))
        local eased = progress * progress * (3 - 2 * progress)
        Place(state.from + (state.target - state.from) * eased)
        if progress >= 1 then Place(state.target); Stop() end
    end

    function state:Reset()
        Stop()
        self.y, self.target, self.bar, self.fixed, self.count = nil, nil, nil, nil, nil
        control:SetHidden(true)
    end

    function state:Update(bars, activeRowVisible)
        if not addon.settings.highlightActiveBar or not activeRowVisible or parent:IsControlHidden() then
            self:Reset()
            return
        end
        local active, row = GetActiveHotbarCategory(), nil
        for index, bar in ipairs(bars) do
            if bar == active then row = index; break end
        end
        if not row then self:Reset(); return end
        local fixed = addon.settings.fixedBars
        local destination = (row - 1) * (cellHeight + gap) - PADDING
        if self.moving then Tick() end
        -- Only weapon swaps within an already visible fixed two-row layout animate.
        -- Layout changes, enabling, scene returns and one-row forms snap to their row.
        if self.target ~= destination or self.fixed ~= fixed or self.count ~= #bars then
            local animate = fixed and self.fixed and #bars == 2 and self.count == 2
                and self.bar ~= active and self.y ~= nil and self.y ~= destination
            self.target = destination
            if animate then
                self.from, self.started, self.moving = self.y, GetFrameTimeSeconds(), true
                control:SetHandler('OnUpdate', Tick)
            else
                Stop()
                Place(destination)
            end
        end
        self.bar, self.fixed, self.count = active, fixed, #bars
        control:SetHidden(false)
    end
end
