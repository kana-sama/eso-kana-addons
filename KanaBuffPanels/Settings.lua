local Addon = KanaBuffPanels
local Settings = {}
Settings.__index = Settings
Addon.Settings = Settings

local function ChoiceLists(records, filter)
    local entries = {}
    for key, record in pairs(records) do
        local label = filter and (record.name .. " (" .. key .. ")") or record.name
        if not filter or LocaleAwareToLower(label):find(filter, 1, true) then
            entries[#entries + 1] = {key = key, label = label, sort = LocaleAwareToLower(label)}
        end
    end
    table.sort(entries, function(a, b)
        if a.sort == b.sort then return tostring(a.key) < tostring(b.key) end
        return a.sort < b.sort
    end)
    local names, keys = {}, {}
    for i, entry in ipairs(entries) do names[i], keys[i] = entry.label, entry.key end
    return names, keys
end

function Settings:Refresh()
    local panelData, hiddenData = self.panelChoice, self.hiddenChoice
    panelData.choices, panelData.choicesValues = ChoiceLists(self.rules.saved.panels)
    hiddenData.choices, hiddenData.choicesValues = ChoiceLists(self.rules.saved.hidden, LocaleAwareToLower(self.search))
    if not self.selected or not self.rules.saved.panels[self.selected] then
        self.selected = panelData.choicesValues[1]
        self.draft = self.selected and self.rules.saved.panels[self.selected].name or ""
    end
    local hiddenSelected = false
    for _, key in ipairs(hiddenData.choicesValues) do if key == self.hiddenSelected then hiddenSelected = true;break end end
    if not hiddenSelected then self.hiddenSelected = hiddenData.choicesValues[1] end
    for _, data in ipairs({panelData, hiddenData}) do
        local control = _G[data.reference]
        if control then control:UpdateChoices(data.choices, data.choicesValues) end
    end
    CALLBACK_MANAGER:FireCallbacks("LAM-RefreshPanel", self.panel)
end

function Settings.Register(rules, onChanged)
    local self = setmetatable({rules = rules, draft = "", search = ""}, Settings)
    local s = Addon.Strings
    self.panel = LibAddonMenu2:RegisterAddonPanel("KanaBuffPanelsSettings", {
        type = "panel", name = "Kana Buff Panels", displayName = Addon.displayName,
        author = "Kana", version = "1.0.0", registerForRefresh = true,
    })
    local function finish(ok, err)
        if ok then onChanged()
        elseif err then d(Addon.displayName .. ": " .. (s[err] or err)) end
    end
    self.panelChoice = {type = "dropdown", name = s.panel, reference = "KanaBuffPanelsPanel",
        choices = {}, choicesValues = {}, scrollable = true,
        getFunc = function() return self.selected end,
        setFunc = function(id)
            self.selected = id
            self.draft = rules.saved.panels[id] and rules.saved.panels[id].name or ""
        end}
    self.hiddenChoice = {type = "dropdown", name = s.effect, reference = "KanaBuffPanelsHidden",
        choices = {}, choicesValues = {}, scrollable = true,
        getFunc = function() return self.hiddenSelected end,
        setFunc = function(key) self.hiddenSelected = key end}
    local options = {
        {type = "description", text = s.guide},
        {type = "header", name = s.panels},
        self.panelChoice,
        {type = "editbox", name = s.name, reference = "KanaBuffPanelsName",
            getFunc = function() return self.draft end, setFunc = function(value) self.draft = value end},
        {type = "button", name = s.create, reference = "KanaBuffPanelsCreate", func = function()
            local id, err = rules:AddPanel(self.draft)
            if id then self.selected = id;self.draft = rules.saved.panels[id].name end
            finish(id, err)
        end},
        {type = "button", name = s.rename, reference = "KanaBuffPanelsRename",
            disabled = function() return not self.selected end,
            func = function() finish(rules:RenamePanel(self.selected, self.draft)) end},
        {type = "button", name = s.delete, reference = "KanaBuffPanelsDelete", tooltip = s.deleteTip,
            disabled = function() return not self.selected end,
            func = function() finish(rules:RemovePanel(self.selected)) end},
        {type = "header", name = s.hidden},
        {type = "editbox", name = s.search, reference = "KanaBuffPanelsSearch",
            getFunc = function() return self.search end,
            setFunc = function(value) self.search = value;self:Refresh() end},
        self.hiddenChoice,
        {type = "button", name = s.show, reference = "KanaBuffPanelsShow",
            disabled = function() return not self.hiddenSelected end,
            func = function()
                if self.hiddenSelected then rules:Unhide(self.hiddenSelected);onChanged() end
            end},
    }
    LibAddonMenu2:RegisterOptionControls("KanaBuffPanelsSettings", options)
    CALLBACK_MANAGER:RegisterCallback("LAM-PanelControlsCreated", function(panel)
        if panel == self.panel then self:Refresh() end
    end)
    self:Refresh()
    return self
end
