local NAME = "KanaAuras"
local AURA_NAME = "кипящая ярость"
local DIAMETER = 96
local COLOR = { 1, 1, 1, 0.95 } -- Цвет пламени уже задан в текстурах.
local segments = {}
local glow
local glowSegments = {}
local halos = {}
local flameTrails = {}
local burning = false
local burnStarted = 0

local function AnimateFire()
    local t = GetFrameTimeSeconds() - burnStarted
    for i, fire in ipairs(glowSegments) do
        -- Unsynchronized tongues keep the ring alive without flashing it off.
        local phase = t * 4.8 + (i - 1) * 2.1
        local wave = (math.sin(phase) + 1) * 0.5
        local flutter = (math.sin(t * 11.3 + i) + 1) * 0.5
        fire:SetColor(1, 0.95 + 0.05 * flutter, 0.85 + 0.15 * wave, 1)
        local size = DIAMETER * (1.08 + 0.14 * wave)
        halos[i]:SetDimensions(size, size)
        halos[i]:SetColor(1, 0.65 + 0.25 * flutter, 0.25, 0.75 + 0.20 * wave)
        for layer, trail in ipairs(flameTrails[i]) do
            -- Continuously emit overlapping waves of fire outwards. Zero alpha
            -- at both ends of each cycle avoids a visible reset or hard blink.
            local age = (t / 0.9 + (layer - 1) / 3 + (i - 1) / 9) % 1
            local extent = DIAMETER * (1.02 + 0.40 * age)
            trail:SetDimensions(extent, extent)
            trail:SetColor(1, 0.72 - 0.35 * age, 0.18 * (1 - age),
                0.95 * math.sin(math.pi * age))
        end
    end
end

local function GetStacks()
    local now = GetFrameTimeSeconds()
    local stacks = 0
    for i = 1, GetNumBuffs("player") do
        local name, _, finish, _, count = GetUnitBuffInfo("player", i)
        if name and (finish == 0 or finish > now)
            and zo_strlower(zo_strformat("<<1>>", name)) == AURA_NAME then
            -- Несколько записей одного эффекта не суммируем в выдуманные стаки.
            stacks = math.max(stacks, count or 0)
        end
    end
    return math.min(3, stacks)
end

local function Refresh()
    local stacks = GetStacks()
    for index, segment in ipairs(segments) do
        segment:SetHidden(stacks == 3 or stacks < index)
    end
    -- At full stacks use the complete burning artwork, avoiding doubled contours.
    glow:SetHidden(stacks ~= 3)
    local full = stacks == 3
    if full ~= burning then
        burning = full
        if full then
            burnStarted = GetFrameTimeSeconds()
            AnimateFire()
            glow:SetHandler("OnUpdate", AnimateFire)
        else
            glow:SetHandler("OnUpdate", nil)
        end
    end
end

local function Initialize(_, addonName)
    if addonName ~= NAME then return end
    EVENT_MANAGER:UnregisterForEvent(NAME, EVENT_ADD_ON_LOADED)

    local root = WINDOW_MANAGER:CreateTopLevelWindow(NAME .. "Window")
    root:SetDimensions(DIAMETER, DIAMETER)
    root:SetAnchor(CENTER, ZO_ReticleContainerReticle or GuiRoot, CENTER, 0, 0)
    root:SetMouseEnabled(false)
    root:SetMovable(false)
    root:SetHidden(true)

    -- Порядок появления: слева, справа, сверху.
    glow = WINDOW_MANAGER:CreateControl(NAME .. "Glow", root, CT_CONTROL)
    glow:SetAnchorFill(root)
    glow:SetMouseEnabled(false)
    glow:SetHidden(true)
    for index, side in ipairs({ "Left", "Right", "Top" }) do
        local segment = WINDOW_MANAGER:CreateControl(NAME .. side, root, CT_TEXTURE)
        segment:SetAnchorFill(root)
        segment:SetTexture("eso-kana-addons/KanaAuras/textures/Circle" .. side .. ".dds")
        segment:SetBlendMode(TEX_BLEND_MODE_ADD)
        segment:SetColor(unpack(COLOR))
        segment:SetMouseEnabled(false)
        segment:SetHidden(true)
        segments[index] = segment
        local fire = WINDOW_MANAGER:CreateControl(NAME .. "Glow" .. side, glow, CT_TEXTURE)
        fire:SetAnchorFill(glow)
        fire:SetTexture("eso-kana-addons/KanaAuras/textures/CircleGlow" .. side .. ".dds")
        fire:SetBlendMode(TEX_BLEND_MODE_ADD)
        fire:SetColor(unpack(COLOR))
        fire:SetMouseEnabled(false)
        glowSegments[index] = fire
        local core = WINDOW_MANAGER:CreateControl(NAME .. "HotCore" .. side, glow, CT_TEXTURE)
        core:SetAnchorFill(glow)
        core:SetTexture("eso-kana-addons/KanaAuras/textures/CircleGlow" .. side .. ".dds")
        core:SetBlendMode(TEX_BLEND_MODE_ADD)
        core:SetColor(1, 1, 0.85, 0.85)
        core:SetMouseEnabled(false)
        local halo = WINDOW_MANAGER:CreateControl(NAME .. "Halo" .. side, glow, CT_TEXTURE)
        halo:SetAnchor(CENTER, glow, CENTER, 0, 0)
        halo:SetDimensions(DIAMETER, DIAMETER)
        halo:SetTexture("eso-kana-addons/KanaAuras/textures/CircleGlow" .. side .. ".dds")
        halo:SetBlendMode(TEX_BLEND_MODE_ADD)
        halo:SetMouseEnabled(false)
        halos[index] = halo
        flameTrails[index] = {}
        for layer = 1, 3 do
            local trail = WINDOW_MANAGER:CreateControl(NAME .. "Flame" .. side .. layer, glow, CT_TEXTURE)
            trail:SetAnchor(CENTER, glow, CENTER, 0, 0)
            trail:SetDimensions(DIAMETER, DIAMETER)
            trail:SetTexture("eso-kana-addons/KanaAuras/textures/CircleGlow" .. side .. ".dds")
            trail:SetBlendMode(TEX_BLEND_MODE_ADD)
            trail:SetMouseEnabled(false)
            flameTrails[index][layer] = trail
        end
    end

    local fragment = ZO_SimpleSceneFragment:New(root)
    HUD_SCENE:AddFragment(fragment)
    HUD_UI_SCENE:AddFragment(fragment)
    EVENT_MANAGER:RegisterForEvent(NAME, EVENT_PLAYER_ACTIVATED, Refresh)
    EVENT_MANAGER:RegisterForUpdate(NAME, 50, Refresh)
    Refresh()

    SLASH_COMMANDS["/kanauras"] = function()
        Refresh()
        local x, y = root:GetCenter()
        d(string.format("KanaAuras: stacks=%d rootHidden=%s alpha=%.2f center=%.0f,%.0f",
            GetStacks(), tostring(root:IsHidden()), root:GetAlpha(), x, y))
        for index, segment in ipairs(segments) do
            local width, height = segment:GetDimensions()
            local tw, th = segment:GetTextureFileDimensions()
            d(string.format("%d: hidden=%s loaded=%s size=%.0fx%.0f texture=%dx%d",
                index, tostring(segment:IsHidden()), tostring(segment:IsTextureLoaded()),
                width, height, tw, th))
        end
        for i, fire in ipairs(glowSegments) do
            d("Glow " .. i .. ": hidden=" .. tostring(glow:IsHidden()) .. " loaded=" .. tostring(fire:IsTextureLoaded()))
        end
        for i = 1, GetNumBuffs("player") do
            local name, _, finish, _, count, _, _, _, _, _, id = GetUnitBuffInfo("player", i)
            if id == 122658 or (name and zo_strlower(name):find("ярость", 1, true)) then
                d(string.format("Aura: %s id=%d stacks=%d remaining=%.1f",
                    name, id, count, finish - GetFrameTimeSeconds()))
            end
        end
    end
end

EVENT_MANAGER:RegisterForEvent(NAME, EVENT_ADD_ON_LOADED, Initialize)
