KanaBuffPanels = KanaBuffPanels or {}
local Rules = {}; Rules.__index = Rules
KanaBuffPanels.Rules = Rules

local function positiveInteger(n)
    return type(n) == 'number' and n > 0 and n < math.huge and n == math.floor(n)
end
local function validEffectId(kind, id)
    -- Artificial effects are zero-based: ESO Plus uses ID 0.
    return (kind == 'ability' and positiveInteger(id))
        or (kind == 'artificial' and (id == 0 or positiveInteger(id)))
end
local function trim(s)
    return type(s) == 'string' and s:gsub('^%s+', ''):gsub('%s+$', '') or ''
end
local function validKey(key)
    if type(key) ~= 'string' then return false end
    local kind, id = key:match('^(%a+):(%d+)$')
    return validEffectId(kind, tonumber(id))
end

function Rules.EffectKey(data)
    if type(data) ~= 'table' then return nil end
    local kind, id = 'ability', data.abilityId
    if data.isArtificial then kind, id = 'artificial', data.effectId end
    if validEffectId(kind, id) then return kind .. ':' .. string.format('%.0f', id) end
end

function Rules.New(saved, normalizeName)
    local self = setmetatable({saved=saved, normalizeName=normalizeName}, Rules)
    for _, key in ipairs({'panels', 'assignments', 'hidden'}) do
        if type(saved[key]) ~= 'table' then saved[key] = {} end
    end
    local maxId = 0
    for id, panel in pairs(saved.panels) do
        if not positiveInteger(id) or type(panel) ~= 'table' or trim(panel.name) == '' then
            saved.panels[id] = nil
        else
            panel.name = trim(panel.name); maxId = math.max(maxId, id)
        end
    end
    saved.nextPanelId = math.max(positiveInteger(saved.nextPanelId) and saved.nextPanelId or 1, maxId + 1)
    for key, id in pairs(saved.assignments) do
        if not validKey(key) or not saved.panels[id] then saved.assignments[key] = nil end
    end
    for key, value in pairs(saved.hidden) do
        if not validKey(key) then saved.hidden[key] = nil
        elseif type(value) ~= 'table' or type(value.name) ~= 'string' then saved.hidden[key] = {name=key} end
    end
    return self
end

function Rules:ValidateName(name, exceptId)
    name = trim(name)
    if name == '' then return nil, 'emptyName' end
    local normalized = self.normalizeName(name)
    for id, panel in pairs(self.saved.panels) do
        if id ~= exceptId and self.normalizeName(panel.name) == normalized then return nil, 'duplicateName' end
    end
    return name
end
function Rules:AddPanel(name)
    local value, err = self:ValidateName(name)
    if not value then return nil, err end
    local id = self.saved.nextPanelId
    self.saved.nextPanelId = id + 1
    self.saved.panels[id] = {name=value}
    return id
end
function Rules:RenamePanel(id, name)
    if not self.saved.panels[id] then return false, 'missingPanel' end
    local value, err = self:ValidateName(name, id)
    if not value then return false, err end
    self.saved.panels[id].name = value
    return true
end
function Rules:RemovePanel(id)
    if not self.saved.panels[id] then return false end
    self.saved.panels[id] = nil
    for key, assignedId in pairs(self.saved.assignments) do
        if assignedId == id then self.saved.assignments[key] = nil end
    end
    return true
end
function Rules:Assign(key, id)
    if not validKey(key) then return false, 'invalidEffect' end
    if id ~= nil and not self.saved.panels[id] then return false, 'missingPanel' end
    self.saved.assignments[key] = id
    return true
end
function Rules:Hide(key, name)
    if not validKey(key) then return false end
    self.saved.hidden[key] = {name=type(name) == 'string' and name or key}
    return true
end
function Rules:Unhide(key)
    if key then self.saved.hidden[key] = nil end
end
function Rules:Destination(key)
    if key == nil then return 'default' end
    if self.saved.hidden[key] then return 'hidden' end
    local id = self.saved.assignments[key]
    return id and self.saved.panels[id] and id or 'default'
end
