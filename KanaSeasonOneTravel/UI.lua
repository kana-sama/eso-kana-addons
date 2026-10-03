local addon = KanaSeasonOneTravel
local addonName = "KanaSeasonOneTravel"
local groups = { { "farm", "bilsa", "vampire" }, { "urcelmo", "holgunn", "arabelle" } }
local labels = {
    en = {
        title = "Season One", groups = { "Dynamic encounters", "Freerunners" },
        names = {
            farm = "Farm Aflame", bilsa = "Bilsa's Delivery", vampire = "Vampire Hunt",
            urcelmo = "Battlereeve Urcelmo", holgunn = "Holgunn One-Eye", arabelle = "Lady Arabelle Davaux",
        },
        locations = {
            farm = "Auridon", bilsa = "Stonefalls", vampire = "Glenumbra",
            urcelmo = "Skywatch", holgunn = "Ebonheart", arabelle = "Aldcroft",
        },
        mark = "Mark completed today", clear = "Clear today's checkmark",
        edit = "Right-click to change today's checkmark.",
        travel = "Travel to the wayshrine near this activity.",
        shrine = "Open the map at a wayshrine to travel.",
        unknown = "The destination wayshrine is undiscovered or unavailable.",
    },
    ru = {
        title = "Первый сезон", groups = { "Динамические события", "Вольнонаёмники" },
        names = {
            farm = "Пожар на ферме", bilsa = "Доставка Бильсы", vampire = "Охота на вампира",
            urcelmo = "Урсельмо", holgunn = "Холгун", arabelle = "Арабелла",
        },
        locations = {
            farm = "Ауридон", bilsa = "Стоунфолз", vampire = "Гленумбра",
            urcelmo = "Скайвотч", holgunn = "Эбонхарт", arabelle = "Альдкрофт",
        },
        mark = "Отметить за сегодня", clear = "Снять сегодняшнюю отметку",
        edit = "Правая кнопка: изменить сегодняшнюю отметку.",
        travel = "Переместиться к святилищу рядом с этим пунктом.",
        shrine = "Для перемещения открой карту через святилище.",
        unknown = "Святилище назначения не открыто или недоступно.",
    },
}
local panel, fragment, locale
local rows = {}
local reopenSeasonTab, shrineMapOpen = false, false

local function RefreshChecks()
    for key, row in pairs(rows) do
        row.check:SetHidden(not addon.IsDone(key))
    end
end

local function Tooltip(control, text)
    InitializeTooltip(InformationTooltip, control, RIGHT, -8, 0, LEFT)
    SetTooltipText(InformationTooltip, text)
end

function addon.Refresh()
    if not panel then return end
    for key, row in pairs(rows) do
        local node = addon.Resolve(key)
        local available = node and not GetFastTravelNodeOutboundOnlyInfo(node)
        row.available = available == true
        local enabled = row.available
        row.name:SetEnabled(enabled)
        row.location:SetColor((enabled and ZO_SELECTED_TEXT or ZO_DISABLED_TEXT):UnpackRGBA())
    end
    RefreshChecks()
end

local function MakeLabel(name, parent, text, x, y, width, height, font)
    local label = WINDOW_MANAGER:CreateControl(addonName .. name, parent, CT_LABEL)
    label:SetAnchor(TOPLEFT, parent, TOPLEFT, x, y)
    label:SetDimensions(width, height)
    label:SetFont(font)
    label:SetText(text)
    return label
end

local function ShowCompletionMenu(control, key)
    ClearMenu()
    AddMenuItem(addon.IsDone(key) and locale.clear or locale.mark,
        function() addon.SetDone(key, not addon.IsDone(key)) end)
    ShowMenu(control)
end

local function Initialize()
    addon.InitializeTracking()
    locale = GetCVar("Language.2") == "ru" and labels.ru or labels.en
    ZO_CreateStringId("SI_KANA_SEASON_ONE_TAB", locale.title)
    panel = WINDOW_MANAGER:CreateControlFromVirtual(addonName .. "Panel", GuiRoot, "ZO_WorldMapInfoContent")
    fragment = ZO_FadeSceneFragment:New(panel)
    addon.fragment = fragment

    local y = 0
    for groupIndex, group in ipairs(groups) do
        local header = MakeLabel("Heading" .. groupIndex, panel, locale.groups[groupIndex],
            20, y, 290, 32, "ZoFontHeader2")
        header:SetColor(ZO_SELECTED_TEXT:UnpackRGBA())
        header:SetModifyTextType(MODIFY_TEXT_TYPE_UPPERCASE)
        y = y + 32
        for _, key in ipairs(group) do
            local row = {}
            local control = WINDOW_MANAGER:CreateControlFromVirtual(addonName .. key .. "Row", panel, "ZO_WorldMapHouseRow")
            control:SetDimensions(310, 60)
            control:SetAnchor(TOPLEFT, panel, TOPLEFT, 20, y)
            control:SetMouseEnabled(true)
            control:SetHandler("OnMouseEnter", function()
                if row.name.enabled then ZO_SelectableLabel_OnMouseEnter(row.name) end
                local travelHint = not row.available and locale.unknown
                    or (addon.CanTravel() and locale.travel or locale.shrine)
                Tooltip(control, travelHint .. "\n" .. locale.edit)
            end)
            control:SetHandler("OnMouseExit", function()
                ZO_SelectableLabel_OnMouseExit(row.name)
                ClearTooltip(InformationTooltip)
            end)
            control:SetHandler("OnMouseUp", function(_, button, upInside)
                if not upInside then return end
                if button == MOUSE_BUTTON_INDEX_LEFT then
                    if addon.CanTravel() and row.available then addon.Travel(key) end
                elseif button == MOUSE_BUTTON_INDEX_RIGHT then
                    ShowCompletionMenu(control, key)
                end
            end)
            local name = control:GetNamedChild("Name")
            name:SetText(locale.names[key])
            name:SetMouseEnabled(false)
            local location = control:GetNamedChild("Location")
            location:SetText(locale.locations[key])
            location:SetMouseEnabled(false)
            local check = WINDOW_MANAGER:CreateControl(addonName .. key .. "Check", control, CT_TEXTURE)
            check:SetDimensions(20, 20)
            check:SetAnchor(TOPLEFT, control, TOPLEFT, -2, 0)
            check:SetTexture("EsoUI/Art/Miscellaneous/check_icon_32.dds")
            check:SetColor(ZO_SELECTED_TEXT:UnpackRGBA())
            check:SetMouseEnabled(false)
            row.button, row.name, row.location, row.check = control, name, location, check
            rows[key] = row
            y = y + 60
        end
    end

    WORLD_MAP_INFO.modeBar:Add(SI_KANA_SEASON_ONE_TAB, { fragment }, {
        normal = "EsoUI/Art/Journal/journal_tabIcon_achievements_up.dds",
        pressed = "EsoUI/Art/Journal/journal_tabIcon_achievements_down.dds",
        highlight = "EsoUI/Art/Journal/journal_tabIcon_achievements_over.dds",
        callback = addon.Refresh,
    })
    fragment:RegisterCallback("StateChange", function(_, newState)
        if newState == SCENE_FRAGMENT_SHOWING then
            addon.Refresh()
            EVENT_MANAGER:RegisterForUpdate(addonName .. "DailyReset", 1000, RefreshChecks)
        elseif newState == SCENE_FRAGMENT_HIDDEN then
            EVENT_MANAGER:UnregisterForUpdate(addonName .. "DailyReset")
            ClearTooltip(InformationTooltip)
        end
    end)
    WORLD_MAP_SCENE:RegisterCallback("StateChange", function(_, newState)
        if newState == SCENE_HIDING and shrineMapOpen then
            reopenSeasonTab = WORLD_MAP_INFO.modeBar:GetLastFragment() == SI_KANA_SEASON_ONE_TAB
        elseif newState == SCENE_HIDDEN then
            shrineMapOpen = false
        end
    end)
    EVENT_MANAGER:RegisterForEvent(addonName, EVENT_START_FAST_TRAVEL_INTERACTION, function()
        shrineMapOpen = true
        -- The native handler selects Locations on every interaction start.
        -- Run after it, once the map has started showing.
        zo_callLater(function()
            if addon.CanTravel() and reopenSeasonTab then
                WORLD_MAP_INFO:SelectTab(SI_KANA_SEASON_ONE_TAB)
            end
            addon.Refresh()
        end, 0)
    end)
    EVENT_MANAGER:RegisterForEvent(addonName, EVENT_END_FAST_TRAVEL_INTERACTION, function()
        if shrineMapOpen then
            reopenSeasonTab = WORLD_MAP_INFO.modeBar:GetLastFragment() == SI_KANA_SEASON_ONE_TAB
            shrineMapOpen = false
        end
        zo_callLater(addon.Refresh, 0)
    end)
    EVENT_MANAGER:RegisterForEvent(addonName, EVENT_FAST_TRAVEL_NETWORK_UPDATED,
        function() zo_callLater(addon.Refresh, 0) end)
    addon.Refresh()
end

EVENT_MANAGER:RegisterForEvent(addonName, EVENT_ADD_ON_LOADED, function(_, loadedName)
    if loadedName ~= addonName then return end
    EVENT_MANAGER:UnregisterForEvent(addonName, EVENT_ADD_ON_LOADED)
    Initialize()
end)
