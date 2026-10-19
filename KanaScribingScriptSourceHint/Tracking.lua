local A = KanaScribingScriptSourceHint
local T = {}
A.Tracking = T
local Tracker = {}
Tracker.__index = Tracker

function T.NextReset(now, world, nativeReset)
    if nativeReset and nativeReset > now and nativeReset <= now + 86400 then return nativeReset end
    local offset = (world:find('EU', 1, true) and 3 or 10) * 3600
    return math.floor((now - offset) / 86400) * 86400 + offset + 86400
end

function T.New(saved, context)
    saved.receipts = saved.receipts or {}
    return setmetatable({saved = saved, context = context}, Tracker)
end

function Tracker:Received(source, world, account, character)
    local worlds = self.saved.receipts[world]
    local chars = worlds and worlds[account]
    if not chars then return false end
    local now = self.context.now()
    local function received(entries)
        local expiry = entries and entries[source]
        return type(expiry) == 'number' and expiry > now
    end
    if character then return received(chars[tostring(character)]) end
    for _, entries in pairs(chars) do if received(entries) then return true end end
    return false
end

function Tracker:SetReceived(source, world, account, character, received)
    if not A.Sources.names[source] or not world or not account or not character then return end
    local all = self.saved.receipts
    all[world] = all[world] or {}
    all[world][account] = all[world][account] or {}
    local chars = all[world][account]
    character = tostring(character)
    chars[character] = chars[character] or {}
    chars[character][source] = received and self.context.reset() or nil
end

function Tracker:Record(source)
    local c = self.context
    self:SetReceived(source, c.world, c.account, c.character, true)
end

function Tracker:Loot(group, scriptId, slot, personal, quantity)
    if not personal or not quantity or quantity <= 0 then return false end
    local source = A.Sources.SourceForLoot(group, scriptId, slot)
    if not source then return false end
    self:Record(source)
    return true
end
