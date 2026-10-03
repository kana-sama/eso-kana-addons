local NAME = 'KanaHeatShock'
local EFFECT_ID = 134340 -- Heat Shock / Тепловой шок (local game ability database).
local stones = {}
local content, bar, timer, warning
local urgent = false

local function ReadTarget()
    if not DoesUnitExist('reticleover') or not IsUnitAttackable('reticleover') or IsUnitDead('reticleover') then
        return false, 0, 0, 0
    end
    local now = GetFrameTimeSeconds()
    local stacks, remaining, duration = 0, 0, 0
    for i = 1, GetNumBuffs('reticleover') do
        local _, started, ending, _, count, _, _, _, _, _, id = GetUnitBuffInfo('reticleover', i)
        if id == EFFECT_ID and ending > now and count > 0 then
            count = math.min(3, count)
            local left = ending - now
            -- Shared target debuff: don't sum duplicate records or different casters.
            if count > stacks or (count == stacks and left < remaining) then
                stacks, remaining, duration = count, left, ending - started
            end
        end
    end
    return true, stacks, remaining, duration
end

local function Pulse()
    local brightness = 0.7 + 0.3 * (0.5 + 0.5 * math.sin(GetFrameTimeSeconds() * 8))
    for _, stone in ipairs(stones) do stone:SetColor(1, brightness, 0.55, 1) end
    warning:SetColor(1, brightness, 0.25, 1)
end

local function Refresh()
    local visible, stacks, remaining, duration = ReadTarget()
    content:SetHidden(not visible or stacks == 0)
    local nextUrgent = visible and stacks == 3 and remaining < 2
    if nextUrgent ~= urgent then
        urgent = nextUrgent
        content:SetHandler('OnUpdate', urgent and Pulse or nil)
    end
    warning:SetHidden(not urgent)
    for i, stone in ipairs(stones) do
        local active = i <= stacks
        stone:SetDesaturation(active and 0 or 1)
        if active then stone:SetColor(1, 0.9, 0.75, 1)
        else stone:SetColor(0.27, 0.27, 0.27, 0.65) end
    end
    if urgent then Pulse() end
    bar:SetValue(duration > 0 and math.min(1, remaining / duration) or 0)
    bar:SetColor(1, urgent and 0.25 or 0.6, 0.08, 1)
    timer:SetText(stacks > 0 and string.format('%.1f', remaining) or '—')
end

local function Initialize(_, addon)
    if addon ~= 'KanaAuras' then return end
    EVENT_MANAGER:UnregisterForEvent(NAME, EVENT_ADD_ON_LOADED)
    local root = WINDOW_MANAGER:CreateTopLevelWindow('KanaHeatWindow')
    root:SetAnchor(CENTER, ZO_ReticleContainerReticle or GuiRoot, CENTER, 0, 112)
    root:SetDimensions(104, 76)
    root:SetMouseEnabled(false)
    root:SetHidden(true)
    content = WINDOW_MANAGER:CreateControl('KanaHeatContent', root, CT_CONTROL)
    content:SetAnchorFill(root)
    content:SetMouseEnabled(false)
    for i = 1, 3 do
        local stone = WINDOW_MANAGER:CreateControl('KanaHeatStone' .. i, content, CT_TEXTURE)
        stone:SetAnchor(TOPLEFT, content, TOPLEFT, (i - 1) * 36, 0)
        stone:SetDimensions(32, 32)
        stone:SetTexture('eso-kana-addons/KanaAuras/textures/HeatStone.dds')
        stone:SetBlendMode(TEX_BLEND_MODE_ADD)
        stones[i] = stone
    end
    local background = WINDOW_MANAGER:CreateControl('KanaHeatBarBackground', content, CT_TEXTURE)
    background:SetAnchor(TOPLEFT, content, TOPLEFT, 0, 35)
    background:SetDimensions(104, 4)
    background:SetTexture('')
    background:SetColor(0.08, 0.06, 0.04, 0.9)
    bar = WINDOW_MANAGER:CreateControl('KanaHeatBar', content, CT_STATUSBAR)
    bar:SetAnchorFill(background)
    bar:SetTexture('')
    bar:SetMinMax(0, 1)
    timer = WINDOW_MANAGER:CreateControl('KanaHeatTimer', content, CT_LABEL)
    timer:SetAnchor(TOPLEFT, content, TOPLEFT, 0, 40)
    timer:SetDimensions(104, 18)
    timer:SetFont('ZoFontGame')
    timer:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    warning = WINDOW_MANAGER:CreateControl('KanaHeatWarning', content, CT_LABEL)
    warning:SetAnchor(TOPLEFT, content, TOPLEFT, 0, 58)
    warning:SetDimensions(104, 20)
    warning:SetFont('ZoFontGameBold')
    warning:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    warning:SetText('ОБНОВИ')
    local fragment = ZO_SimpleSceneFragment:New(root)
    HUD_SCENE:AddFragment(fragment)
    HUD_UI_SCENE:AddFragment(fragment)
    EVENT_MANAGER:RegisterForEvent(NAME, EVENT_RETICLE_TARGET_CHANGED, Refresh)
    EVENT_MANAGER:RegisterForEvent(NAME, EVENT_PLAYER_ACTIVATED, Refresh)
    EVENT_MANAGER:RegisterForUpdate(NAME, 50, Refresh)
    Refresh()
    SLASH_COMMANDS['/kanaheat'] = function()
        local visible, stacks, remaining = ReadTarget()
        d(string.format('Heat Shock: target=%s stacks=%d remaining=%.1f textureLoaded=%s',
            tostring(visible), stacks, remaining, tostring(stones[1]:IsTextureLoaded())))
        if visible then
            for i = 1, GetNumBuffs('reticleover') do
                local name, _, ending, _, count, _, _, _, _, _, id = GetUnitBuffInfo('reticleover', i)
                if id == EFFECT_ID then
                    d(string.format('%s id=%d stacks=%d remaining=%.1f', name, id, count, ending - GetFrameTimeSeconds()))
                end
            end
        end
    end
end
EVENT_MANAGER:RegisterForEvent(NAME, EVENT_ADD_ON_LOADED, Initialize)
