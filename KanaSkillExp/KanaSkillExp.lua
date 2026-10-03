KanaSkillExp = {}
local addon = KanaSkillExp
local selection = KanaSkillExpSelection
local NAME = 'KanaSkillExp'
local ROW_HEIGHT, WIDTH = 26, 184
local rows = {}
local ru = GetCVar('language.2') == 'ru'
local ADD = ru and 'Добавить в SkillExp' or 'Add to SkillExp'
local REMOVE = ru and 'Удалить из SkillExp' or 'Remove from SkillExp'
local UNAVAILABLE = ru and 'Недоступно' or 'Unavailable'
local RANKS = {'I', 'II', 'III', 'IV'}

function addon:EntryForSkill(skillData)
    if not skillData or not skillData:IsPlayerSkill() then return end
    local progression = skillData:GetCurrentProgressionData()
    if not progression then return end
    local name = progression:GetName()
    if not skillData:IsPassive() and not skillData:IsCraftedAbility() then
        return {kind = 'ability', id = skillData:GetProgressionId(), name = name}
    end
    local lineId = skillData:GetSkillLineData():GetId()
    local _, _, skillIndex = skillData:GetIndices()
    return {kind = 'skill', id = lineId .. ':' .. skillIndex,
        lineId = lineId, skillIndex = skillIndex, name = name}
end

-- Constructing a menu never changes the selection. Only its action does.
function addon:AddSelectionMenuItem(entry)
    if not entry then return end
    local selected = selection.Find(self.saved.entries, entry) ~= nil
    AddMenuItem(selected and REMOVE or ADD, function()
        if selected then
            selection.Remove(self.saved.entries, entry)
        else
            selection.Add(self.saved.entries, entry)
        end
        self:Refresh()
    end)
end

function addon:ShowSelectionMenu(control, entry)
    ClearMenu()
    self:AddSelectionMenuItem(entry)
    ShowMenu(control)
end

function addon:HookLineControl(control)
    if control.kanaSkillExpHooked then return end
    control.kanaSkillExpHooked = true
    ZO_PreHookHandler(control, 'OnMouseUp', function(label, button, upInside)
        if button ~= MOUSE_BUTTON_INDEX_RIGHT or not upInside then return end
        local node = label.node
        if not node or node:GetTree() ~= SKILLS_WINDOW.skillLinesTree then return end
        local line = node:GetData()
        if not line or line.isSubclassingNode or not line.GetId then return end
        self:ShowSelectionMenu(label, {kind = 'line', id = line:GetId(), name = line:GetName()})
        return true
    end)
end

function addon:InstallMenus()
    -- Append before the native menu is laid out, retaining ESO's existing actions.
    ZO_PreHook('ShowMenu', function(control)
        local progression = control and control.skillProgressionData
        if progression then
            self:AddSelectionMenuItem(self:EntryForSkill(progression:GetSkillData()))
        end
    end)
    ZO_PostHook('ZO_SkillsNavigationEntry_OnInitialized', function(control)
        self:HookLineControl(control)
    end)
    -- The skill tree may already have been populated before addon loading.
    for _, node in pairs(SKILLS_WINDOW.skillLineIdToNode or {}) do
        self:HookLineControl(node.control)
    end
end

function addon:GetInfo(entry)
    local info = {name = entry.name, rank = '', progress = 0, available = false}
    local data, progression
    local lastXP, nextXP, currentXP
    if entry.kind == 'line' then
        data = SKILLS_DATA_MANAGER:GetSkillLineDataById(entry.id)
        if not data then return info end
        info.name = data:GetName()
        info.rank = data:GetCurrentRank()
        info.available = data:IsAvailable()
        lastXP, nextXP, currentXP = data:GetRankXPValues()
    else
        if entry.kind == 'ability' then
            data = SKILLS_DATA_MANAGER:GetSkillDataByProgressionId(entry.id)
        else
            local line = SKILLS_DATA_MANAGER:GetSkillLineDataById(entry.lineId)
            data = line and line:GetSkillDataByIndex(entry.skillIndex)
        end
        progression = data and data:GetCurrentProgressionData()
        if not progression then return info end
        info.name = progression:GetName()
        info.available = data:GetSkillLineData():IsAvailable()
        if data:IsPassive() then
            local rank = data:IsPurchased() and data:GetCurrentRank() or 0
            local maxRank = data:GetNumRanks()
            info.rank = rank .. '/' .. maxRank
            info.progress = maxRank > 0 and rank / maxRank or 0
            info.maxed = rank >= maxRank
            return info
        elseif data:IsCraftedAbility() then
            info.progress = data:IsPurchased() and 1 or 0
            info.maxed = data:IsPurchased()
            return info
        end
        local hasProgression, progressionIndex, canMorph
        hasProgression, progressionIndex, lastXP, nextXP, currentXP, canMorph =
            GetAbilityProgressionXPInfoFromAbilityId(progression:GetAbilityId())
        info.xpKey = progression:GetAbilityId()
        if not hasProgression then return info end
        local _, _, rank = GetAbilityProgressionInfo(progressionIndex)
        info.rank = RANKS[rank] or tostring(rank or '')
        info.canMorph = canMorph
    end
    if lastXP == nil or nextXP == nil or currentXP == nil then return info end
    info.maxed = info.canMorph or nextXP <= lastXP
    info.progress = info.maxed and 1 or math.max(0, math.min(1, (currentXP - lastXP) / (nextXP - lastXP)))
    info.currentXP = currentXP
    if not info.maxed then
        info.xpText = ZO_CommaDelimitNumber(currentXP - lastXP) .. ' / ' ..
            ZO_CommaDelimitNumber(nextXP - lastXP) .. ' XP'
    end
    return info
end

local function Label(name, parent, font)
    local label = WINDOW_MANAGER:CreateControl(name, parent, CT_LABEL)
    label:SetFont(font)
    label:SetColor(1, 1, 1, 1)
    label:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    return label
end

local function AddBarBackground(bar)
    if bar.kanaSkillExpBackground then return end
    local background = WINDOW_MANAGER:CreateControlFromVirtual(bar:GetName() .. 'Background', bar:GetParent(), 'ZO_ArrowStatusBar')
    background:SetAnchorFill(bar)
    background:SetMinMax(0, 1)
    background:SetValue(1)
    background:SetColor(0, 0, 0, 0.5)
    background:SetDrawLayer(DL_BACKGROUND)
    background:SetMouseEnabled(false)
    bar.kanaSkillExpBackground = background
end

function addon:CreateRow(index)
    local name = NAME .. 'Row' .. index
    local control = WINDOW_MANAGER:CreateControl(name, self.form, CT_CONTROL)
    control:SetDimensions(WIDTH, ROW_HEIGHT)
    control:SetAnchor(TOPLEFT, self.form, TOPLEFT, 8, (index - 1) * 24)
    control:SetMouseEnabled(true)
    local row = {control = control}
    row.bar = WINDOW_MANAGER:CreateControlFromVirtual(name .. 'Bar', control, 'ZO_ArrowStatusBar')
    row.bar:SetAnchorFill()
    row.bar:SetMinMax(0, 1)
    AddBarBackground(row.bar)
    row.label = Label(name .. 'Name', control, '$(BOLD_FONT)|15|outline')
    row.label:SetAnchor(LEFT, control, LEFT, 6, 0)
    row.label:SetDimensionConstraints(0, 0, WIDTH - 10, ROW_HEIGHT)
    row.rank = Label(name .. 'Rank', control, '$(BOLD_FONT)|15|outline')
    row.rank:SetDimensions(22, ROW_HEIGHT)
    row.rank:SetAnchor(RIGHT, control, LEFT, -6, 0)
    row.rank:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
    row.percent = Label(name .. 'Percent', control, '$(BOLD_FONT)|14|outline')
    row.percent:SetDimensions(34, ROW_HEIGHT)
    row.percent:SetAnchor(RIGHT, row.rank, LEFT, 2, 0)
    row.percent:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
    row.flash = Label(name .. 'Flash', control, '$(BOLD_FONT)|14|soft-shadow-thick')
    row.flash:SetAnchor(LEFT, control, RIGHT, 30, 0)
    row.flash:SetColor(0.3, 1, 0.3, 1)
    row.flash:SetHidden(true)
    row.morph = WINDOW_MANAGER:CreateControl(name .. 'Morph', control, CT_TEXTURE)
    row.morph:SetTexture('EsoUI/Art/Progression/morph_disabled.dds')
    row.morph:SetDimensions(28, 28)
    row.morph:SetAnchor(LEFT, control, RIGHT, 2, 0)
    row.morph:SetHidden(true)
    control:SetHandler('OnMouseEnter', function(c)
        ZO_Tooltips_ShowTextTooltip(c, RIGHT, row.tooltip)
    end)
    control:SetHandler('OnMouseExit', ZO_Tooltips_HideTextTooltip)
    control:SetHandler('OnMouseUp', function(c, button, upInside)
        if upInside and button == MOUSE_BUTTON_INDEX_RIGHT and row.entry then
            self:ShowSelectionMenu(c, row.entry)
        end
    end)
    return row
end

function addon:ApplyDisplay()
    local manualOnly = self.saved.manualOnly == true
    local shown = SkillExp.config.formShown
    if self.displayMode ~= manualOnly then
        local movableForm = manualOnly and self.form or self.originalForm
        movableForm:ClearAnchors()
        local pos = SkillExp.config.formPos
        if pos then movableForm:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, pos.x, pos.y)
        else movableForm:SetAnchor(CENTER, GuiRoot, CENTER, 0, 0) end
        self.form:SetMovable(manualOnly)
        if not manualOnly then
            self.form:ClearAnchors()
            self.form:SetAnchor(TOPLEFT, self.originalForm, BOTTOMLEFT, 0, 4)
        end
        self.displayMode = manualOnly
    end
    if shown and not manualOnly then
        if self.originalForm:IsHidden() then self.originalToggle() end
    else
        self.originalForm:SetHidden(true)
    end
    self.form:SetHidden(not shown or (not manualOnly and #self.saved.entries == 0))
end

function addon:Refresh()
    if not self.form then return end
    for i, entry in ipairs(self.saved.entries) do
        local row = rows[i] or self:CreateRow(i)
        rows[i] = row
        local info = self:GetInfo(entry)
        local key = entry.kind .. ':' .. entry.id .. ':' .. tostring(info.xpKey or '')
        if row.key ~= key then
            row.lastXP = nil
            row.flash:SetHidden(true)
        end
        if not self.form:IsHidden() and row.lastXP and info.currentXP and info.currentXP > row.lastXP then
            row.flash:SetText('+' .. ZO_CommaDelimitNumber(info.currentXP - row.lastXP))
            row.flash:SetHidden(false)
            if row.flashCall then zo_removeCallLater(row.flashCall) end
            row.flashCall = zo_callLater(function()
                row.flash:SetHidden(true)
                row.flashCall = nil
            end, 1500)
        end
        row.key, row.lastXP, row.entry = key, info.currentXP, entry
        row.label:SetText(zo_strformat('<<1>>', info.name))
        row.rank:SetText(tostring(info.rank))
        row.bar:SetValue(info.progress)
        if info.maxed then row.bar:SetColor(0.15, 0.4, 0.15, 1)
        elseif entry.kind == 'line' then row.bar:SetColor(0.25, 0.45, 0.65, 1)
        else row.bar:SetColor(0.45, 0.28, 0.60, 1) end
        row.control:SetAlpha(info.available and 1 or 0.5)
        row.percent:SetText(SkillExp.config.showPercent and (math.floor(info.progress * 100) .. '%') or '')
        row.morph:SetHidden(not info.canMorph)
        row.tooltip = zo_strformat('<<1>>', info.name) .. '\n' .. tostring(info.rank)
        if info.xpText then row.tooltip = row.tooltip .. '\n' .. info.xpText end
        if not info.available then row.tooltip = row.tooltip .. '\n' .. UNAVAILABLE end
        row.control:SetHidden(false)
    end
    for i = #self.saved.entries + 1, #rows do
        rows[i].control:SetHidden(true)
        rows[i].key, rows[i].lastXP, rows[i].entry = nil, nil, nil
    end
    self.empty:SetHidden(#self.saved.entries > 0)
    self.form:SetHeight(math.max(48, #self.saved.entries * 24 + 2))
    self:ApplyDisplay()
end

function addon:Initialize()
    if self.form then return end
    self.saved = ZO_SavedVars:NewCharacterIdSettings('KanaSkillExp_Data', 1, nil,
        {entries = {}, manualOnly = false})
    self.originalForm = SkillExp.skillsForm
    self.originalToggle = SkillExp_ToggleSkillsForm
    for i = 1, self.originalForm:GetNumChildren() do
        local bar = self.originalForm:GetChild(i):GetNamedChild('Bar')
        if bar then AddBarBackground(bar) end
    end
    self.form = WINDOW_MANAGER:CreateControl(NAME .. 'Form', SkillExpContainer, CT_CONTROL)
    self.form:SetDimensions(200, 48)
    self.form:SetMouseEnabled(true)
    self.form:SetMovable(true)
    self.form:SetClampedToScreen(true)
    local pos = SkillExp.config.formPos
    if pos then self.form:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, pos.x, pos.y)
    else self.form:SetAnchor(CENTER, GuiRoot, CENTER, 0, 0) end
    self.form:SetHandler('OnMoveStop', function(control)
        SkillExp.config.formPos = {x = control:GetLeft(), y = control:GetTop()}
    end)
    self.form:SetHidden(not SkillExp.config.formShown)
    self.empty = Label(NAME .. 'Empty', self.form, '$(BOLD_FONT)|14|outline')
    self.empty:SetAnchor(TOPLEFT, self.form, TOPLEFT, 8, 0)
    self.empty:SetWidth(WIDTH)
    self.empty:SetText(ru and 'Добавьте навыки через контекстное меню в окне навыков.'
        or 'Add skills using the context menu in the Skills window.')
    SkillExp_ToggleSkillsForm = function()
        SkillExp.config.formShown = not SkillExp.config.formShown
        self:Refresh()
    end
    -- All original controls remain intact and continue driving the native list.
    local modeToggle = SkillExpComponents.CreateToggle(NAME .. 'ManualOnly', SkillExp_Settings,
        self.saved, 'manualOnly', ru and 'Только выбранные навыки' or 'Only selected skills',
        ru and 'Выключено: обычный SkillExp и выбранные навыки ниже. Включено: только выбранные навыки в постоянном порядке.'
            or 'Off: normal SkillExp with selected skills below. On: only selected skills in a fixed order.')
    modeToggle:SetAnchor(TOPLEFT, SkillExpSettingsHideMaxed, BOTTOMLEFT, 0, 8)
    modeToggle:SetHandler('OnMouseDown', function(control)
        control:SetChecked(not self.saved.manualOnly)
        self:Refresh()
    end)
    self:InstallMenus()
    local pending = false
    local function RequestRefresh()
        if pending then return end
        pending = true
        zo_callLater(function() pending = false; self:Refresh() end, 0)
    end
    for _, event in ipairs({'FullSystemUpdated', 'SkillLineAdded', 'SkillLineUpdated',
        'SkillLineRankUpdated', 'SkillLineXPUpdated', 'SkillProgressionUpdated', 'CraftedAbilityUpdated'}) do
        SKILLS_DATA_MANAGER:RegisterCallback(event, RequestRefresh)
    end
    EVENT_MANAGER:RegisterForEvent(NAME, EVENT_PLAYER_ACTIVATED, RequestRefresh)
    CALLBACK_MANAGER:RegisterCallback('OnSkillExpSettingChanged', RequestRefresh)
    self:Refresh()
end

EVENT_MANAGER:RegisterForEvent(NAME, EVENT_ADD_ON_LOADED, function(_, addonName)
    if addonName ~= NAME then return end
    EVENT_MANAGER:UnregisterForEvent(NAME, EVENT_ADD_ON_LOADED)
    addon:Initialize()
end)
