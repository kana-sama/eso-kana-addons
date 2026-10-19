local A = KanaScribingScriptSourceHint
A.name = 'KanaScribingScriptSourceHint'
local displayName = '|cFF0000Kana|r |c4488FFCharacter Knowledge|r: |cFFFFFFscribing script source hint|r'

local function selection(api)
    local list = api.CharacterKnowledge.list
    local c = A.tracker.context
    return list and list.server or c.world, list and list.account or c.account, list and list.charId or c.character
end

function A.BuildTooltip(api, scriptId, source)
    local info = A.Sources.details[source]
    if not info then return end
    local world, account, character = selection(api)
    local characterName = api.LibCharacterKnowledge.GetCharacterNameAndAccount(world, character) or tostring(character)
    local result = {
        title = A.Sources.names[source], description = info.description, location = info.location,
        context = characterName .. ' · ' .. world,
    }
    if A.settings.dailyTracking then
        local received = A.tracker:Received(source, world, account, character)
        result.status = received and '|c66DD88Страница за это занятие сегодня получена.|r'
            or 'Получение страницы сегодня не зафиксировано.'
        if not received and A.tracker:Received(source, world, account) then
            result.account = 'Другой персонаж на аккаунте сегодня уже получал страницу за это занятие.'
        end
        local c = A.tracker.context
        result.note = not received and 'Ранее полученную страницу аддон мог не увидеть.' or nil
        if world == c.world and account == c.account then
            result.note = (result.note and result.note .. '\n' or '') .. 'ПКМ — исправить отметку.'
        end
    else
        result.status = 'Дневной учёт выключен.'
    end
    return result
end

local function fingerprint(data)
    return table.concat({data.title or '', data.description or '', data.location or '',
        data.context or '', data.status or '', data.account or '', data.note or ''}, '\n')
end

function A.ShowSources(api, icon)
    local id, source = icon.kanaScriptId, icon.kanaSource
    if not id or not source or not A.settings.sourceHints then return end
    local data = A.BuildTooltip(api, id, source)
    local stamp = fingerprint(data)
    A.tooltip:Show(icon, data)
    local update = A.name .. 'TooltipRefresh'
    api.EVENT_MANAGER:UnregisterForUpdate(update)
    api.EVENT_MANAGER:RegisterForUpdate(update, 1000, function()
        if A.tooltip.owner ~= icon or icon.kanaScriptId ~= id or icon.kanaSource ~= source
            or not A.settings.sourceHints then
            api.EVENT_MANAGER:UnregisterForUpdate(update)
            return
        end
        local current = A.BuildTooltip(api, id, source)
        local nextStamp = fingerprint(current)
        if nextStamp ~= stamp then
            stamp = nextStamp
            local bar = A.tooltip.scroll and A.tooltip.scroll:GetNamedChild('ScrollBar')
            local scroll = bar and bar:GetValue()
            A.tooltip:Show(icon, current)
            if bar and scroll then bar:SetValue(scroll) end
        end
    end)
end

function A.RefreshIcons(api)
    local world, account, character = selection(api)
    for row in pairs(A.rows) do
        for _, icon in ipairs(row.kanaSources.icons) do
            if icon.kanaSource and not icon:IsHidden() then
                local received = A.settings.dailyTracking
                    and A.tracker:Received(icon.kanaSource, world, account, character)
                icon:SetAlpha(received and 0.45 or 1)
            end
        end
    end
end

local function correct(api, row, icon, button, inside)
    if not inside then return end
    local world, account, character = selection(api)
    local c, source = A.tracker.context, icon.kanaSource
    if source and button == api.MOUSE_BUTTON_INDEX_RIGHT and A.settings.dailyTracking
        and world == c.world and account == c.account then
        local received = A.tracker:Received(source, world, account, character)
        api.ClearMenu()
        api.AddMenuItem((received and 'Снять отметку: ' or 'Получено сегодня: ') .. A.Sources.names[source], function()
            A.tracker:SetReceived(source, world, account, character, not received)
            A.RefreshIcons(api)
        end)
        api.ShowMenu(icon)
        return
    end
    api.CharacterKnowledgeListRow_OnMouseUp(row, button, inside)
end

local function createIcon(api, row, index)
    -- ColorRow enumerates every direct child through GetChild. Unnamed
    -- controls can count as children without being returned by that API.
    local icon = api.WINDOW_MANAGER:CreateControl(row:GetName() .. 'KanaScribingSource' .. index, row, api.CT_TEXTURE)
    icon.nonRecolorable = true
    icon:SetDrawLayer(api.DL_OVERLAY)
    icon:SetHandler('OnMouseEnter', function(control)
        if not control.kanaSource then return end
        -- CK owns private tooltip references; restore its native row hover
        -- and keyboard action after asking it to clear those tooltips.
        api.CharacterKnowledgeListRow_OnMouseExit(row)
        api.CharacterKnowledge.list:Row_OnMouseEnter(row)
        A.ShowSources(api, control)
    end)
    icon:SetHandler('OnMouseExit', function(control)
        api.CharacterKnowledge.list:Row_OnMouseExit(row)
        A.tooltip:Leave(control)
    end)
    icon:SetHandler('OnMouseUp', function(control, button, inside)
        if control.kanaSource then correct(api, row, control, button, inside) end
    end)
    api.ZO_PostHookHandler(icon, 'OnEffectivelyHidden', function()
        if A.tooltip.owner == icon then A.tooltip:Hide() end
    end)
    return icon
end

local unpack = unpack or table.unpack
local function restoreRow(row)
    local state = row.kanaSources
    if not state then return end
    for _, icon in ipairs(state.icons) do
        if A.tooltip.owner == icon then A.tooltip:Hide() end
        icon.kanaScriptId, icon.kanaSource, icon.kanaTooltipAnchor = nil, nil, nil
        icon:SetHidden(true)
        icon:SetMouseEnabled(false)
        icon:SetAlpha(1)
    end
    if state.active then
        row:GetNamedChild('Name'):SetWidth(state.nameWidth)
        local extended = row:GetNamedChild('Extended')
        extended:ClearAnchors()
        extended:SetAnchor(unpack(state.extendedAnchor))
        state.active = false
    end
end

local function installBrowser(api)
    api.ZO_PostHook(api.CharacterKnowledgeList, 'SetupItemRow', function(_, row, data)
        restoreRow(row)
        if not A.settings.sourceHints or not data.scriptId then return end
        local sources = A.Sources.DailyForScript(data.scriptId, api.GetCraftedAbilityScriptScribingSlot(data.scriptId))
        if #sources == 0 then return end
        local name, suffix, extended = row:GetNamedChild('Name'), row:GetNamedChild('NameSuffix'), row:GetNamedChild('Extended')
        local state = row.kanaSources
        if not state then
            state = {icons = {}, boundary = api.WINDOW_MANAGER:CreateControl(row:GetName() .. 'KanaScribingSourceBounds', row, api.CT_CONTROL)}
            state.boundary.nonRecolorable = true
            state.boundary:SetMouseEnabled(false)
            row.kanaSources = state
            A.rows[row] = true
        end
        -- Preserve the original name-cell boundary for all later columns.
        -- Reserve only the measured native icon widths within the name cell.
        state.nameWidth = name:GetWidth()
        state.extendedAnchor = {select(2, extended:GetAnchor(0))}
        state.boundary:ClearAnchors()
        state.boundary:SetAnchor(select(2, name:GetAnchor(0)))
        state.boundary:SetDimensions(state.nameWidth, name:GetHeight())
        local anchor = {unpack(state.extendedAnchor)}
        anchor[2] = state.boundary
        extended:ClearAnchors()
        extended:SetAnchor(unpack(anchor))
        local size, gap = math.min(suffix:GetWidth(), suffix:GetHeight()), 2
        name:SetWidth(math.max(1, state.nameWidth - #sources * size - (#sources - 1) * gap - 6))
        suffix:SetHidden(true)
        state.active = true
        for i, source in ipairs(sources) do
            local icon = state.icons[i]
            if not icon then icon = createIcon(api, row, i); state.icons[i] = icon end
            icon.kanaScriptId, icon.kanaSource = data.scriptId, source
            icon.kanaTooltipAnchor = state.icons[1]
            icon:SetTexture(A.Sources.details[source].icon)
            icon:SetDimensions(size, size)
            icon:ClearAnchors()
            icon:SetAnchor(api.RIGHT, state.boundary, api.RIGHT, -(#sources - i) * (size + gap), 0)
            icon:SetHidden(false)
            icon:SetMouseEnabled(true)
        end
        A.RefreshIcons(api)
    end)
end

function A.Initialize(api)
    A.settings = api.ZO_SavedVars:NewAccountWide(A.name .. 'Saved', 1, nil,
        {sourceHints = true, dailyTracking = true, hideKnown = false, receipts = {}})
    local world = api.LibCodesCommonCode.GetServerName()
    A.tracker = A.Tracking.New(A.settings, {
        world = world, account = api.GetDisplayName(), character = api.GetCurrentCharacterId(),
        now = api.GetTimeStamp,
        reset = function()
            return A.Tracking.NextReset(api.GetTimeStamp(), world,
                api.GetTimedActivityTypeResetTimeS(api.TIMED_ACTIVITY_TYPE_DAILY))
        end,
    })
    A.tooltip = A.Tooltip.New(api)
    A.rows = setmetatable({}, {__mode = 'k'})
    installBrowser(api)
    A.Filter.Install(api)
    A.Events.Install(api, A.tracker, function() return A.settings.dailyTracking end)
    api.EVENT_MANAGER:RegisterForUpdate(A.name .. 'SourcesRefresh', 1000, function() A.RefreshIcons(api) end)
    local menu = api.LibAddonMenu2
    if menu then
        local panel = A.name .. 'Settings'
        menu:RegisterAddonPanel(panel, {type = 'panel', name = displayName, displayName = displayName,
            author = 'Kana', version = '1.0.0', registerForRefresh = true, registerForDefaults = true})
        local options = {}
        for _, setting in ipairs({{'sourceHints', 'Показывать значки и подсказки источников'},
            {'dailyTracking', 'Учитывать получение страниц за текущий день'}}) do
            local key = setting[1]
            options[#options + 1] = {type = 'checkbox', name = setting[2],
                getFunc = function() return A.settings[key] end,
                setFunc = function(value) A.settings[key] = value end,
                default = true, requiresReload = true, width = 'full'}
        end
        options[#options + 1] = {type = 'checkbox', name = 'Скрывать известные (чаропись)',
            tooltip = 'Скрывать изученные страницы и гримуары для персонажа, выбранного в Character Knowledge.',
            getFunc = function() return A.settings.hideKnown == true end,
            setFunc = function(value) A.Filter.SetHideKnown(api, value) end,
            default = false, requiresReload = false, width = 'full'}
        menu:RegisterOptionControls(panel, options)
    end
end

if EVENT_MANAGER then
    EVENT_MANAGER:RegisterForEvent(A.name, EVENT_ADD_ON_LOADED, function(_, name)
        if name ~= A.name then return end
        EVENT_MANAGER:UnregisterForEvent(A.name, EVENT_ADD_ON_LOADED)
        A.Initialize(_G)
    end)
end
