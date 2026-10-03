KanaOutfitBrowser = KanaOutfitBrowser or {}

local Model = {}
Model.__index = Model
KanaOutfitBrowser.NativeSetModel = Model

local function normalizedName(name)
    -- ESO provides UTF-8 case folding; Lua's lower is enough for ASCII fixtures.
    if zo_strlower then return zo_strlower(name or "") end
    return string.lower(name or "")
end

function Model.New(variants, prefs)
    prefs = prefs or {}
    prefs.favorites = prefs.favorites or {}
    prefs.hidden = prefs.hidden or {}
    prefs.showHidden = prefs.showHidden == true
    local self = setmetatable({prefs=prefs, families={}, byKey={}, visible={}}, Model)
    local seen = {}
    for _, variant in ipairs(variants or {}) do
        if variant.styleKey and variant.key and not seen[variant.key] then
            seen[variant.key] = true
            local family = self.byKey[variant.styleKey]
            if not family then
                family = {key=variant.styleKey, name=variant.name or "", variants={}}
                self.byKey[family.key] = family
                self.families[#self.families+1] = family
            end
            family.variants[#family.variants+1] = variant
        end
    end
    for _, family in ipairs(self.families) do
        table.sort(family.variants, function(a, b)
            local aw, bw = a.weight or 4, b.weight or 4
            if aw ~= bw then return aw < bw end
            return tostring(a.key) < tostring(b.key)
        end)
    end
    return self
end

function Model:_Filter()
    self.visible = {}
    for _, family in ipairs(self.families) do
        if self.prefs.showHidden or not family.openingHidden then
            self.visible[#self.visible+1] = family
        end
    end
end

function Model:Open()
    -- Persist discovery order: names/API enumeration must not reshuffle existing styles.
    self.prefs.styleOrder = self.prefs.styleOrder or {}
    local ranks = {}
    for i, key in ipairs(self.prefs.styleOrder) do ranks[key] = i end
    local added = {}
    for _, family in ipairs(self.families) do
        if not ranks[family.key] then added[#added + 1] = family end
    end
    table.sort(added, function(a, b)
        local an, bn = normalizedName(a.name), normalizedName(b.name)
        if an ~= bn then return an < bn end
        return tostring(a.key) < tostring(b.key)
    end)
    for _, family in ipairs(added) do
        self.prefs.styleOrder[#self.prefs.styleOrder + 1] = family.key
        ranks[family.key] = #self.prefs.styleOrder
    end
    for _, family in ipairs(self.families) do
        family.favorite = self.prefs.favorites[family.key] == true
        family.hidden = self.prefs.hidden[family.key] == true
        family.openingFavorite = family.favorite
        family.openingHidden = family.hidden
    end
    table.sort(self.families, function(a, b)
        if a.openingFavorite ~= b.openingFavorite then return a.openingFavorite end
        return ranks[a.key] < ranks[b.key]
    end)
    self:_Filter()
end

function Model:GetSets()
    return self.visible
end

function Model:ToggleFavorite(key)
    local family = self.byKey[key]
    if not family then return false end
    family.favorite = not (self.prefs.favorites[key] == true)
    self.prefs.favorites[key] = family.favorite or nil
    return true
end

function Model:ToggleHidden(key)
    local family = self.byKey[key]
    if not family then return false end
    family.hidden = not (self.prefs.hidden[key] == true)
    self.prefs.hidden[key] = family.hidden or nil
    return true
end

function Model:SetShowHidden(value)
    self.prefs.showHidden = value == true
    self:_Filter()
end
