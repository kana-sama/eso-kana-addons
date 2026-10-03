local NAME = 'KanaCrux'
local EFFECT_ID = 184220 -- Crux / Знак; independent of client language.
local DIAMETER = 96
local segments, halos = {}, {}
local full, core, highlight
local active = false
local started = 0

local function Stacks()
    local count, now = 0, GetFrameTimeSeconds()
    for i = 1, GetNumBuffs('player') do
        local _, _, ending, _, stacks, _, _, _, _, _, id = GetUnitBuffInfo('player', i)
        if id == EFFECT_ID and (ending == 0 or ending > now) then
            count = math.max(count, stacks or 0)
        end
    end
    return math.min(3, count)
end

local function Animate()
    local t = GetFrameTimeSeconds() - started
    local pulse = (math.sin(t * 5) + 1) * 0.5
    core:SetColor(1, 1, 1, 1)
    highlight:SetColor(0.65 + 0.35 * pulse, 1, 0.45 + 0.3 * pulse, 0.35 + 0.45 * pulse)
    for i, halo in ipairs(halos) do
        local wave = 0.5 + 0.5 * math.sin(t * 2.1 + i * 2)
        local diameter = DIAMETER * (1.02 + 0.07 * wave)
        halo:SetDimensions(diameter, diameter)
        halo:SetTextureRotation(t * (i == 2 and -0.13 or 0.09) + (i - 1) * 2.1, 0.5, 0.5)
        halo:SetColor(0.65, 1, 0.5, 0.20 + 0.22 * wave)
    end
end

local function Refresh()
    local count = Stacks()
    for i, segment in ipairs(segments) do segment:SetHidden(count == 3 or count < i) end
    full:SetHidden(count ~= 3)
    if active ~= (count == 3) then
        active = count == 3
        if active then
            started = GetFrameTimeSeconds()
            Animate()
            full:SetHandler('OnUpdate', Animate)
        else
            full:SetHandler('OnUpdate', nil)
        end
    end
end

local function Texture(name, parent, file, additive)
    local control = WINDOW_MANAGER:CreateControl(name, parent, CT_TEXTURE)
    control:SetTexture('eso-kana-addons/KanaAuras/textures/' .. file .. '.dds')
    control:SetBlendMode(additive and TEX_BLEND_MODE_ADD or TEX_BLEND_MODE_ALPHA)
    control:SetMouseEnabled(false)
    control:SetColor(1, 1, 1, 1)
    return control
end

local function Initialize(_, addon)
    if addon ~= 'KanaAuras' then return end
    EVENT_MANAGER:UnregisterForEvent(NAME, EVENT_ADD_ON_LOADED)
    local root = WINDOW_MANAGER:CreateTopLevelWindow(NAME .. 'Window')
    root:SetDimensions(DIAMETER, DIAMETER)
    root:SetAnchor(CENTER, ZO_ReticleContainerReticle or GuiRoot, CENTER, 0, 0)
    root:SetMouseEnabled(false)
    root:SetHidden(true)
    for i, side in ipairs({'Left','Right','Top'}) do
        local segment = Texture(NAME .. side, root, 'CruxJade' .. side)
        segment:SetAnchorFill(root)
        segment:SetColor(0.55, 0.65, 0.5, 1)
        segment:SetHidden(true)
        segments[i] = segment
    end
    full = WINDOW_MANAGER:CreateControl(NAME .. 'Full', root, CT_CONTROL)
    full:SetAnchorFill(root)
    full:SetMouseEnabled(false)
    full:SetHidden(true)
    core = Texture(NAME .. 'Core', full, 'CruxJadeFull')
    core:SetAnchorFill(full)
    highlight = Texture(NAME .. 'Highlight', full, 'CruxJadeFull', true)
    highlight:SetAnchorFill(full)
    highlight:SetColor(1, 1, 0.8, 0.85)
    for i = 1, 3 do
        local halo = Texture(NAME .. 'Halo' .. i, full, 'CruxJadeSmoke', true)
        halo:SetAnchor(CENTER, full, CENTER, 0, 0)
        halo:SetDimensions(DIAMETER, DIAMETER)
        halos[i] = halo
    end
    local fragment = ZO_SimpleSceneFragment:New(root)
    HUD_SCENE:AddFragment(fragment)
    HUD_UI_SCENE:AddFragment(fragment)
    EVENT_MANAGER:RegisterForEvent(NAME, EVENT_PLAYER_ACTIVATED, Refresh)
    EVENT_MANAGER:RegisterForUpdate(NAME, 50, Refresh)
    Refresh()
    SLASH_COMMANDS['/kanacrux'] = function()
        d(string.format('Crux: stacks=%d full=%s textureLoaded=%s', Stacks(),
            tostring(not full:IsHidden()), tostring(core:IsTextureLoaded())))
    end
end
EVENT_MANAGER:RegisterForEvent(NAME, EVENT_ADD_ON_LOADED, Initialize)
