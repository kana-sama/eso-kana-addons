-- Narrow experiment: one native waist entry at the top of the native head page.
-- No replacement controls, mouse handlers, preview calls, or catalog changes.
local ADDON = "KanaOutfitBrowser"
local EVENT_NAME = ADDON .. "NativeBeltProbe"

local function insertBelt(panel)
    if not SCENE_MANAGER:IsShowing("outfitStylesBook")
        or not panel.fragment:IsShowing() or panel.restyleSlotData
        or not panel.collectibleCategoryData
        or panel.collectibleCategoryData:GetId() ~= GetOutfitSlotDataCollectibleCategoryId(OUTFIT_SLOT_HEAD) then
        return
    end

    local category = ZO_COLLECTIBLE_DATA_MANAGER:GetCategoryDataById(
        GetOutfitSlotDataCollectibleCategoryId(OUTFIT_SLOT_WAIST))
    if not category then return end

    local belt
    for _, data in category:CollectibleIterator() do
        if data:IsOutfitStyle() and data:IsArmorStyle()
            and not data:IsHiddenFromCollection() and CanCollectibleBePreviewed(data:GetId()) then
            local eligible = { GetEligibleOutfitSlotsForCollectible(data:GetId()) }
            for _, slot in ipairs(eligible) do
                if slot == OUTFIT_SLOT_WAIST then
                    belt = data
                    break
                end
            end
            if belt and belt:IsUnlocked() then break end
        end
    end
    if not belt then return end

    local entry = panel.entryDataObjectPool:AcquireObject()
    entry:SetDataSource(belt)
    entry.gridHeaderName = "Пояс — проверка переноса"
    ZO_UpdateCollectibleEntryDataIconVisuals(entry, panel:GetActorCategory())
    panel.gridListPanelList:AddEntry(entry)
end

EVENT_MANAGER:RegisterForEvent(EVENT_NAME, EVENT_ADD_ON_LOADED, function(_, name)
    if name ~= ADDON then return end
    EVENT_MANAGER:UnregisterForEvent(EVENT_NAME, EVENT_ADD_ON_LOADED)
    local panel = ZO_OUTFIT_STYLES_PANEL_KEYBOARD
    -- RefreshVisible clears the grid, then releases the entry pool, then fills
    -- native head entries and commits. Insert immediately after that release.
    -- The stock XML template and its stock input handlers remain untouched.
    SecurePostHook(panel.entryDataObjectPool, "ReleaseAllObjects", function()
        insertBelt(panel)
    end)
end)
