local A = KanaScribingScriptSourceHint
local F = {}
A.Filter = F

local function isScribing(api, list)
    return list.filterId == api.LibCharacterKnowledge.ITEM_CATEGORY_SCRIBING
        and not list.researchModeIsSelected
end

local function updateControl(api, list)
    if not list.headers then return end
    local check = list.kanaHideKnown
    if not check then
        check = api.WINDOW_MANAGER:CreateControlFromVirtual(
            list.frame:GetName() .. 'KanaScribingHideKnown', list.frame, 'ZO_CheckButton')
        list.kanaHideKnown = check
        api.ZO_CheckButton_SetLabelText(check, 'Скрывать известные')
        check.label:SetMaxLineCount(1)
        api.ZO_CheckButton_SetToggleFunction(check, function()
            F.SetHideKnown(api, api.ZO_CheckButton_IsChecked(check))
        end)
    end
    -- Share the search row, respecting the optional native account filter.
    local searchLabel = list.frame:GetNamedChild('Search'):GetNamedChild('Label')
    local account = list.singleAccount
    local left = account:IsHidden() and account:GetLeft() or account.label:GetRight() + 12
    check:ClearAnchors()
    check:SetAnchor(api.LEFT, searchLabel, api.LEFT, left - searchLabel:GetLeft(), 0)
    check.label:SetWidth(math.max(1, searchLabel:GetLeft() - left - check:GetWidth() - 5 - 12))
    api.ZO_CheckButton_SetCheckState(check, A.settings.hideKnown == true)
    check:SetHidden(not isScribing(api, list))
end

function F.SetHideKnown(api, value)
    A.settings.hideKnown = value == true
    local list = api.CharacterKnowledge.list
    if list then
        updateControl(api, list)
        if isScribing(api, list) then list:RefreshFilters() end
    end
end

function F.Install(api)
    api.ZO_PostHook(api.CharacterKnowledgeList, 'FilterScrollList', function(list)
        updateControl(api, list)
        if not A.settings.hideKnown or not isScribing(api, list) then return end
        local entries = api.ZO_ScrollList_GetDataList(list.list)
        -- CK refreshes ratioKnown for the selected character before filtering.
        -- Filter its already-searched results, retaining native sort and counts.
        for i = #entries, 1, -1 do
            if entries[i].data.ratioKnown == 1 then table.remove(entries, i) end
        end
    end)
    api.ZO_PostHook(api.CharacterKnowledgeList, 'UpdateState', function(list)
        updateControl(api, list)
    end)
    if api.CharacterKnowledge.list then
        updateControl(api, api.CharacterKnowledge.list)
        if isScribing(api, api.CharacterKnowledge.list) then api.CharacterKnowledge.list:RefreshFilters() end
    end
end
