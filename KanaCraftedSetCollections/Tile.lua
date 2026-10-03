KanaCraftedSetCollections = KanaCraftedSetCollections or {}
local addon = KanaCraftedSetCollections

function addon.IsCraftedEntry(entry)
    if not entry then return false end
    if entry.kanaCrafted then return true end
    if entry.GetDataSource then
        local source = entry:GetDataSource()
        return source and source.kanaCrafted or false
    end
    return false
end

function addon.MakeHeader(row)
    return {
        kanaCrafted = true,
        row = row,
        GetId = function() return row.setId end,
        GetFormattedName = function()
            if zo_strformat and SI_ITEM_SET_NAME_FORMATTER then
                return zo_strformat(SI_ITEM_SET_NAME_FORMATTER, row.name)
            end
            return row.name
        end,
        GetNumPieces = function() return 1 end,
        GetNumUnlockedPieces = function() return 1 end,
    }
end

function addon.MakePiece(row)
    return {
        kanaCrafted = true,
        row = row,
        GetIcon = function() return row.icon or "EsoUI/Art/Inventory/inventory_tabIcon_armor_up.dds" end,
        GetItemLink = function() return row.itemLink end,
        IsUnlocked = function() return true end,
        IsNew = function() return false end,
        ClearNew = function() end,
    }
end

function addon.InstallTileHooks()
    if addon.tileHooksInstalled then return true end
    local tileClass = ZO_ItemSetCollectionPieceTile_Keyboard
    if not tileClass or not tileClass.CanReconstruct or not tileClass.RefreshMouseoverVisuals then return false end

    local originalCanReconstruct = tileClass.CanReconstruct
    tileClass.CanReconstruct = function(tile, ...)
        if addon.IsCraftedEntry(tile.itemSetCollectionPieceData) then return false end
        return originalCanReconstruct(tile, ...)
    end

    local originalRefreshMouseoverVisuals = tileClass.RefreshMouseoverVisuals
    tileClass.RefreshMouseoverVisuals = function(tile, ...)
        local piece = tile.itemSetCollectionPieceData
        if addon.IsCraftedEntry(piece) then
            if piece:GetItemLink() and tile:IsMousedOver() then
                ClearTooltip(ItemTooltip)
                local offsetX = tile.control:GetParent():GetLeft() - tile.control:GetLeft() - 5
                InitializeTooltip(ItemTooltip, tile.control, RIGHT, offsetX, 0, LEFT)
                ItemTooltip:SetLink(piece:GetItemLink())
            end
            return
        end
        return originalRefreshMouseoverVisuals(tile, ...)
    end

    addon.tileHooksInstalled = true
    return true
end
