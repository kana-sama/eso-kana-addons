KanaOutfitBrowser = KanaOutfitBrowser or {}
local KOB = KanaOutfitBrowser

local Model = {}
Model.__index = Model

Model.FAVORITES_TITLE = "Любимое"
Model.OTHERS_TITLE = "Остальные"

local function copyArray(source)
    local result = {}
    for index, value in ipairs(source) do
        result[index] = value
    end
    return result
end

local function firstVariant(row)
    for weight = 1, 4 do
        if row.variants[weight] then
            return row.variants[weight]
        end
    end
    return nil
end

local function rowLess(left, right)
    local leftName = left.name or ""
    local rightName = right.name or ""
    if leftName ~= rightName then
        return leftName < rightName
    end
    return (left.styleKey or "") < (right.styleKey or "")
end

local function replaceVariantIndex(self, variants)
    self.variants = {}
    self.variantsByKey = {}

    for _, entry in ipairs(variants or {}) do
        if entry.key ~= nil and self.variantsByKey[entry.key] == nil then
            self.variants[#self.variants + 1] = entry
            self.variantsByKey[entry.key] = entry
        end
    end
end

function Model.New(variants, accountPrefs, characterPrefs)
    accountPrefs = accountPrefs or {}
    accountPrefs.favorites = accountPrefs.favorites or {}
    accountPrefs.hidden = accountPrefs.hidden or {}

    characterPrefs = characterPrefs or {}
    if characterPrefs.preferredWeight == nil then
        characterPrefs.preferredWeight = 1
    end
    characterPrefs.showHidden = characterPrefs.showHidden == true

    local self = setmetatable({
        variants = {},
        variantsByKey = {},
        accountPrefs = accountPrefs,
        characterPrefs = characterPrefs,
        favoriteSnapshot = {},
        hasFavoriteSnapshot = false,
        rows = {},
        styleRows = {},
        sequence = {},
        positionByKey = {},
        rowByKey = {},
        selectedKey = nil,
    }, Model)

    replaceVariantIndex(self, variants)

    return self
end

function Model:_updateFavoriteSnapshotPresence()
    self.hasFavoriteSnapshot = false
    for _, entry in ipairs(self.variants) do
        if self.favoriteSnapshot[entry.key] then
            self.hasFavoriteSnapshot = true
            return
        end
    end
end

function Model:_buildStyleRows(entries)
    local rowsByStyle = {}
    local rows = {}

    for _, entry in ipairs(entries) do
        local row = rowsByStyle[entry.styleKey]
        if not row then
            row = {
                kind = "style",
                name = entry.name,
                styleKey = entry.styleKey,
                variants = {},
            }
            rowsByStyle[entry.styleKey] = row
            rows[#rows + 1] = row
        end

        if row.variants[entry.weight] == nil then
            row.variants[entry.weight] = entry
        end
    end

    table.sort(rows, rowLess)
    return rows
end

function Model:_appendGroup(entries, title, includeHeader)
    local groupRows = self:_buildStyleRows(entries)
    if #groupRows == 0 then
        return
    end

    if includeHeader then
        self.rows[#self.rows + 1] = { kind = "header", title = title }
    end

    for _, row in ipairs(groupRows) do
        self.rows[#self.rows + 1] = row
        self.styleRows[#self.styleRows + 1] = row
        local rowIndex = #self.styleRows

        for weight = 1, 4 do
            local entry = row.variants[weight]
            if entry then
                self.sequence[#self.sequence + 1] = entry
                self.positionByKey[entry.key] = #self.sequence
                self.rowByKey[entry.key] = rowIndex
            end
        end
    end
end

function Model:_chooseOldOrderNeighbor(previousOrder, previousSelectedKey)
    if not previousOrder or not previousSelectedKey then
        return self.sequence[1] and self.sequence[1].key or nil
    end

    local selectedIndex = nil
    for index, key in ipairs(previousOrder) do
        if key == previousSelectedKey then
            selectedIndex = index
            break
        end
    end

    if selectedIndex then
        for index = selectedIndex + 1, #previousOrder do
            if self.positionByKey[previousOrder[index]] then
                return previousOrder[index]
            end
        end
        for index = selectedIndex - 1, 1, -1 do
            if self.positionByKey[previousOrder[index]] then
                return previousOrder[index]
            end
        end
    end

    return self.sequence[1] and self.sequence[1].key or nil
end

function Model:_setSelectedKey(key, updatePreference)
    if key ~= nil and not self.positionByKey[key] then
        return false
    end

    local changed = self.selectedKey ~= key
    self.selectedKey = key
    self.characterPrefs.selectedKey = key

    if updatePreference and key then
        local weight = self.variantsByKey[key].weight
        if weight >= 1 and weight <= 3 then
            self.characterPrefs.preferredWeight = weight
        end
    end

    return changed
end

function Model:_rebuild(previousOrder, previousSelectedKey)
    self.rows = {}
    self.styleRows = {}
    self.sequence = {}
    self.positionByKey = {}
    self.rowByKey = {}

    local favorites = {}
    local others = {}
    for _, entry in ipairs(self.variants) do
        local isHidden = self.accountPrefs.hidden[entry.key] == true
        if self.characterPrefs.showHidden or not isHidden then
            if self.favoriteSnapshot[entry.key] then
                favorites[#favorites + 1] = entry
            else
                others[#others + 1] = entry
            end
        end
    end

    if self.hasFavoriteSnapshot then
        self:_appendGroup(favorites, Model.FAVORITES_TITLE, true)
        self:_appendGroup(others, Model.OTHERS_TITLE, true)
    else
        self:_appendGroup(others, nil, false)
    end

    if self.selectedKey and self.positionByKey[self.selectedKey] then
        self.characterPrefs.selectedKey = self.selectedKey
        return
    end

    local replacement = self:_chooseOldOrderNeighbor(previousOrder, previousSelectedKey)
    self:_setSelectedKey(replacement, false)
end

function Model:Open()
    self.favoriteSnapshot = {}
    for key, isFavorite in pairs(self.accountPrefs.favorites) do
        if isFavorite == true then
            self.favoriteSnapshot[key] = true
        end
    end
    self:_updateFavoriteSnapshotPresence()

    self.selectedKey = self.characterPrefs.selectedKey
    self:_rebuild()
end

function Model:RefreshCatalog(variants)
    local previousOrder = {}
    for index, entry in ipairs(self.sequence) do
        previousOrder[index] = entry.key
    end
    local previousSelectedKey = self.selectedKey

    replaceVariantIndex(self, variants)
    self:_updateFavoriteSnapshotPresence()
    self:_rebuild(previousOrder, previousSelectedKey)

    return self:GetSelected()
end

function Model:GetRows()
    return self.rows
end

function Model:GetSelected()
    if not self.selectedKey then
        return nil
    end
    return self.variantsByKey[self.selectedKey]
end

function Model:GetPosition()
    if not self.selectedKey then
        return 0, 0
    end
    return self.positionByKey[self.selectedKey] or 0, #self.sequence
end

function Model:Select(key)
    if not self.positionByKey[key] then
        return false
    end
    return self:_setSelectedKey(key, true)
end

function Model:MoveHorizontal(delta)
    local position = self.selectedKey and self.positionByKey[self.selectedKey]
    if not position or delta == 0 then
        return false
    end

    local step = delta < 0 and -1 or 1
    local target = self.sequence[position + step]
    if not target then
        return false
    end

    return self:_setSelectedKey(target.key, true)
end

function Model:MoveVertical(delta)
    local rowIndex = self.selectedKey and self.rowByKey[self.selectedKey]
    if not rowIndex or delta == 0 then
        return false
    end

    local step = delta < 0 and -1 or 1
    local targetRow = self.styleRows[rowIndex + step]
    if not targetRow then
        return false
    end

    return self:SelectRow(targetRow)
end

function Model:SelectRow(row)
    if not row or row.kind ~= "style" then
        return false
    end

    local target = row.variants[self.characterPrefs.preferredWeight] or firstVariant(row)
    if not target or not self.positionByKey[target.key] then
        return false
    end

    return self:_setSelectedKey(target.key, false)
end

function Model:ToggleFavorite()
    if not self.selectedKey then
        return false
    end

    if self.accountPrefs.favorites[self.selectedKey] then
        self.accountPrefs.favorites[self.selectedKey] = nil
    else
        self.accountPrefs.favorites[self.selectedKey] = true
    end
    return true
end

function Model:ToggleHidden()
    if not self.selectedKey then
        return false
    end

    local selectedKey = self.selectedKey
    local previousOrder = {}
    for index, entry in ipairs(self.sequence) do
        previousOrder[index] = entry.key
    end

    if self.accountPrefs.hidden[selectedKey] then
        self.accountPrefs.hidden[selectedKey] = nil
    else
        self.accountPrefs.hidden[selectedKey] = true
    end

    if not self.characterPrefs.showHidden then
        self:_rebuild(previousOrder, selectedKey)
    end
    return true
end

function Model:SetShowHidden(showHidden)
    showHidden = showHidden and true or false
    if self.characterPrefs.showHidden == showHidden then
        return false
    end

    local previousOrder = {}
    for index, entry in ipairs(self.sequence) do
        previousOrder[index] = entry.key
    end
    local previousSelectedKey = self.selectedKey

    self.characterPrefs.showHidden = showHidden
    self:_rebuild(previousOrder, previousSelectedKey)
    return true
end

KOB.Model = Model
