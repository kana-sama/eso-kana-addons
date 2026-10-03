local NAME = 'KanaBloodHunger'
local EFFECT_ID = 267744 -- Blood Hunger, verified in LibMultilingualName.
local SEGMENT_WIDTH, SEGMENT_HEIGHT = 60, 12
local SOCKETS = {{-96, 30}, {-32, 30}, {32, 30}, {96, 30}}
local content, full
local orbs, glows, smoke, cores, flashes = {}, {}, {}, {}, {}
local births, previousCount = {}, 0
local active, started = false, 0

local function Stacks()
    local count, now = 0, GetFrameTimeSeconds()
    for i = 1, GetNumBuffs('player') do
        local _, _, ending, _, stacks, _, _, _, _, _, id = GetUnitBuffInfo('player', i)
        if id == EFFECT_ID and (ending == 0 or ending > now) then
            count = math.max(count, stacks or 0)
        end
    end
    return math.max(0, math.min(4, count))
end

local function Animate()
    local t = GetFrameTimeSeconds() - started
    local pulse = 0.5 + 0.5 * math.sin(t * 5)
    for i = 1, 4 do
        glows[i]:SetColor(1, 0.7 + 0.3 * pulse, 0.7 + 0.3 * pulse, 0.15 + 0.85 * pulse)
    end
    for i, layer in ipairs(smoke) do
        local wave = 0.5 + 0.5 * math.sin(t * 2.3 + i * 1.7)
        layer:SetColor(1, 0.55, 0.55, 0.2 + 0.18 * wave)
    end
end

local function AnimateArrivals()
    local now, running = GetFrameTimeSeconds(), false
    for i = 1, 4 do
        local age = births[i] and math.max(0, now - births[i]) or 1
        if age < 0.42 then
            running = true
            -- Sharp light impulse with a small damped afterglow; geometry stays fixed.
            local fade = math.max(0, (age - 0.075) / 0.345)
            local intensity = (1 - fade) ^ 2
            flashes[i]:SetColor(1, 0.9, 0.65, intensity)
            flashes[i]:SetHidden(false)
        else
            births[i] = nil
            flashes[i]:SetHidden(true)
        end
    end
    if not running then content:SetHandler('OnUpdate', nil) end
end

local function Refresh(shown)
    local count = shown and Stacks() or 0
    local now = GetFrameTimeSeconds()
    local newStacks = count > previousCount
    for i = 1, 4 do
        if i > count then births[i] = nil
        elseif i > previousCount then births[i] = now end
    end
    previousCount = count
    if newStacks then content:SetHandler('OnUpdate', AnimateArrivals) end
    AnimateArrivals()
    content:SetHidden(not shown)
    for i, orb in ipairs(orbs) do orb:SetHidden(count == 4 or i > count) end
    full:SetHidden(count ~= 4)
    if active ~= (count == 4) then
        active = count == 4
        if active then
            started = GetFrameTimeSeconds()
            Animate()
            full:SetHandler('OnUpdate', Animate)
        else
            full:SetHandler('OnUpdate', nil)
        end
    end
end

local function Texture(name, parent, file, width, height, x, y, additive)
    local control = WINDOW_MANAGER:CreateControl(NAME .. name, parent, CT_TEXTURE)
    local layer = file == 'Smoke' and 'Glow' or file:gsub('Socket', '')
    local texture = 'EsoBloodSegment' .. name:match('%d+$') .. layer
    control:SetTexture('eso-kana-addons/KanaAuras/textures/' .. texture .. '.dds')
    control:SetBlendMode(additive and TEX_BLEND_MODE_ADD or TEX_BLEND_MODE_ALPHA)
    control:SetDimensions(width, height)
    control:SetAnchor(CENTER, parent, CENTER, x, y)
    control:SetMouseEnabled(false)
    control:SetColor(1, 1, 1, 1)
    return control
end

-- Four compact stack segments share the form tracker anchor and visibility.
function KanaAurasCreateBloodSockets(parent)
    content = WINDOW_MANAGER:CreateControl(NAME .. 'Content', parent, CT_CONTROL)
    content:SetAnchorFill(parent)
    content:SetMouseEnabled(false)
    content:SetHidden(true)
    for i = 1, 4 do
        local x, y = unpack(SOCKETS[i])
        local dormant = Texture('Dormant' .. i, content, 'SocketIdle', SEGMENT_WIDTH, SEGMENT_HEIGHT, x, y)
        dormant:SetColor(0.75, 0.75, 0.75, 1)
        orbs[i] = Texture('Active' .. i, content, 'SocketActive', SEGMENT_WIDTH, SEGMENT_HEIGHT, x, y)
        orbs[i]:SetColor(1, 1, 1, 1)
        orbs[i]:SetHidden(true)
    end
    full = WINDOW_MANAGER:CreateControl(NAME .. 'Full', content, CT_CONTROL)
    full:SetAnchorFill(content)
    full:SetMouseEnabled(false)
    full:SetHidden(true)
    for i = 1, 4 do
        local x, y = unpack(SOCKETS[i])
        cores[i] = Texture('Core' .. i, full, 'SocketActive', SEGMENT_WIDTH, SEGMENT_HEIGHT, x, y)
        glows[i] = Texture('Glow' .. i, full, 'SocketGlow', SEGMENT_WIDTH, SEGMENT_HEIGHT, x, y, true)
        smoke[i] = Texture('Smoke' .. i, full, 'Smoke', SEGMENT_WIDTH, SEGMENT_HEIGHT, x, y, true)
    end
    for i = 1, 4 do
        local x, y = unpack(SOCKETS[i])
        flashes[i] = Texture('Arrival' .. i, content, 'SocketFlash', SEGMENT_WIDTH, SEGMENT_HEIGHT, x, y, true)
        flashes[i]:SetDrawLevel(20)
        flashes[i]:SetHidden(true)
    end
    SLASH_COMMANDS['/kanablood'] = function()
        d(string.format('Blood Hunger: stacks=%d full=%s textureLoaded=%s', Stacks(),
            tostring(not full:IsHidden()), tostring(orbs[1]:IsTextureLoaded())))
    end
    return Refresh
end
