local NAME = 'KanaWerewolfForm'
local WIDTH, HEIGHT, DEFAULT_GAP = 300, 150, 30
-- The luminous channel occupies this horizontal range in the aligned DDS atlas.
-- Flat native-style fills need one clipped texture, avoiding seams between strips.
local CHANNEL_LEFT, CHANNEL_RIGHT, SLICES = 0.07, 0.93, 1
local root, content, frame, devourPreview
local devourGain = 0
local devourEndpoint, devourUntil, devourTicks = nil, 0, 0
local meal, mealLine, mealSpark
local mealMarks, mealFlashes, mealCores, mealHalos, mealAwards = {}, {}, {}, {}, {}
local mealLastTick
local ultimateMaximum = 500
local DEVOUR_IDS = {[32634]=true,[33208]=true,[33209]=true,[37233]=true,
    [39050]=true,[266520]=true,[268571]=true}
local devourNames = {}
local DEVOUR_ULTIMATE = 75 -- One complete corpse: five ticks of 15.
local slices, border = {}, {}
local crest, borderPlane
local CREST_SIZE, CREST_Y = 68, 64
local wolfGlow, wolf, bloodMist
local eyes = {}
local rampageEnd, rampageDuration = 0, 20
-- Werewolf Rampage family, names verified in the installed ability database.
local RAMPAGE_IDS = {[266377]=true,[266523]=true,[266524]=true,
    [267416]=true,[267417]=true,[267418]=true,
    [267425]=true,[267426]=true,[267427]=true,[267428]=true}
local rampageNames = {}
local function Rampage(now)
    local ending, duration = 0, 20
    for i = 1, GetNumBuffs('player') do
        local name, beginning, finish, _, _, _, _, _, _, _, id = GetUnitBuffInfo('player', i)
        if (RAMPAGE_IDS[id] or rampageNames[name]) and finish and finish > now and finish > ending then
            ending = finish
            duration = beginning and finish > beginning and finish - beginning or 20
        end
    end
    return ending, duration
end
local furyFraction, furyReady = 0, false
local furyStarted = 0
local fraction, low, visible = 0, false, false
local anchorTarget, anchorPoint, anchorX, anchorY
local updateSockets
local dragging, dragMouseY, dragBottom = false, 0, 0

local function Anchor()
    local cm = CombatMetronome
    local settings = cm and cm.SV and cm.SV.Progressbar
    local radial = settings and settings.radialCooldown
        and type(settings.radialCenterX) == 'number' and type(settings.radialCenterY) == 'number'
    local gap = KanaAurasSettings.wolfGap
    local target = radial and GuiRoot or ZO_ReticleContainerReticle or GuiRoot
    local point = radial and TOPLEFT or CENTER
    local x = radial and settings.radialCenterX or 0
    local radius = radial and (tonumber(settings.radialOuterRadius) or 60) or 60
    local y = (radial and settings.radialCenterY or 0) - radius - gap
    if type(KanaAurasSettings.wolfY) == 'number' then
        if not radial then
            x = (ZO_ReticleContainerReticle or GuiRoot):GetCenter()
        end
        target, point = GuiRoot, TOPLEFT
        y = math.max(HEIGHT, math.min(GuiRoot:GetHeight(), KanaAurasSettings.wolfY))
    end
    -- Use saved geometry: the live ring starts unsized while hidden after /reloadui.
    if target ~= anchorTarget or point ~= anchorPoint or x ~= anchorX or y ~= anchorY then
        root:ClearAnchors()
        root:SetAnchor(BOTTOM, target, point, x, y)
        anchorTarget, anchorPoint, anchorX, anchorY = target, point, x, y
    end
end

local function Drag()
    if not dragging then return end
    local _, y = GetUIMousePosition()
    KanaAurasSettings.wolfY = math.max(HEIGHT, math.min(GuiRoot:GetHeight(), dragBottom + y - dragMouseY))
    Anchor()
end

local function StopDrag()
    if not dragging then return end
    Drag()
    dragging = false
    root:SetHandler('OnUpdate', nil)
end

local function Fill(controls, value)
    local range = CHANNEL_RIGHT - CHANNEL_LEFT
    local edge = CHANNEL_LEFT + range * value
    for i, slice in ipairs(controls) do
        local left = CHANNEL_LEFT + (i - 1) * range / SLICES
        local right = math.min(edge, left + range / SLICES)
        slice:SetHidden(right <= left)
        if right > left then
            slice:SetDimensions(WIDTH * (right - left), HEIGHT)
            slice:SetTextureCoords(left, right, 0, 1)
        end
    end
end

-- Clip along each side in an unrotated square, then rotate the parent 45 degrees.
-- This keeps the moving end perpendicular to the diamond side, including thick rims.
local function FillBorder(value)
    local size = CREST_SIZE / math.sqrt(2)
    for i, segment in ipairs(border) do
        local q = math.max(0, math.min(1, value * 4 - (i - 1)))
        segment:SetHidden(q <= 0)
        if q > 0 then
            local x, y, w, h, u1, u2, v1, v2
            if i == 1 then
                x,y,w,h,u1,u2,v1,v2 = 0,0,size*q,size,0,q,0,1
            elseif i == 2 then
                x,y,w,h,u1,u2,v1,v2 = 0,0,size,size*q,0,1,0,q
            elseif i == 3 then
                x,y,w,h,u1,u2,v1,v2 = size*(1-q),0,size*q,size,1-q,1,0,1
            else
                x,y,w,h,u1,u2,v1,v2 = 0,size*(1-q),size,size*q,0,1,1-q,1
            end
            segment:ClearAnchors()
            segment:SetAnchor(TOPLEFT, borderPlane, TOPLEFT, x, y)
            segment:SetDimensions(w, h)
            segment:SetTextureCoords(u1, u2, v1, v2)
        end
    end
end

-- Retarget from the currently displayed value; unchanged polls never restart motion.
local formMotion, furyMotion = {}, {}
local function Value(motion, now)
    if not motion.started then return motion.target or 0 end
    local t = math.min(1, math.max(0, (now - motion.started) / 0.18))
    local ease = t * t * (3 - 2 * t)
    return motion.from + (motion.target - motion.from) * ease
end
local function Target(motion, value, now, snap)
    if snap then
        motion.from, motion.target, motion.started = value, value, nil
    elseif motion.target ~= value then
        motion.from = Value(motion, now)
        motion.target, motion.started = value, now
    end
end

-- One one-second cycle: the border leads, the wolf follows 250 ms later.
local function FuryBeat(elapsed)
    local phase = elapsed % 1
    return phase < 0.5 and math.sin(math.pi * phase / 0.5) ^ 2 or 0
end

local function AnimateMeal(now)
    if not mealLastTick or now >= devourUntil + 0.25 then
        meal:SetHidden(true)
        return
    end
    meal:SetHidden(false)
    meal:SetAlpha(math.max(0, 1 - math.max(0, now - devourUntil) / 0.25))
    -- First award is immediate, then four one-second intervals. Interpolate only
    -- the moving head: checkpoints light exclusively on actual energize events.
    local progress = math.min(1, (devourTicks - 1 + math.min(1, now - mealLastTick)) / 4)
    local remaining = 258 * (1 - progress)
    mealLine:SetHidden(remaining <= 0)
    mealLine:SetDimensions(math.max(0.01, remaining), 4)
    mealSpark:ClearAnchors()
    mealSpark:SetAnchor(CENTER, meal, TOPLEFT, 21 + remaining, 90)
    for i = 1, 5 do
        local awarded = mealAwards[i]
        mealMarks[i]:SetColor(1, awarded and 0.85 or 0.8, awarded and 0.5 or 0.6, awarded and 1 or 0.45)
        -- Brief bright peak, then a soft tail; visible above the permanent markers.
        local age = awarded and math.max(0, now - awarded) or 1
        local flash = awarded and math.max(0, 1 - math.max(0, age - 0.12) / 0.43) or 0
        mealFlashes[i]:SetHidden(flash <= 0)
        mealFlashes[i]:SetColor(1, 0.96, 0.82, flash)
        mealCores[i]:SetHidden(flash <= 0)
        mealCores[i]:SetColor(1, 0.99, 0.94, flash)
        mealHalos[i]:SetHidden(flash <= 0)
        mealHalos[i]:SetColor(1, 0.78, 0.35, flash * 0.95)
    end
end

local function Animate()
    local t = GetFrameTimeSeconds()
    AnimateMeal(t)
    local displayed = Value(formMotion, t)
    Fill(slices, displayed)
    if devourEndpoint and t >= devourUntil then devourEndpoint = nil end
    local previewEnd = devourEndpoint and math.min(1, devourEndpoint / ultimateMaximum)
        or math.min(1, displayed + devourGain)
    devourPreview:SetHidden(previewEnd <= displayed)
    if previewEnd > displayed then
        local range = CHANNEL_RIGHT - CHANNEL_LEFT
        local left, right = CHANNEL_LEFT + range * displayed, CHANNEL_LEFT + range * previewEnd
        devourPreview:ClearAnchors()
        devourPreview:SetAnchor(TOPLEFT, content, TOPLEFT, WIDTH * left, 0)
        devourPreview:SetDimensions(WIDTH * (right - left), HEIGHT)
        devourPreview:SetTextureCoords(left, right, 0, 1)
    end
    local rampaging = rampageEnd > t
    FillBorder( rampaging and math.min(1, (rampageEnd - t) / rampageDuration) or Value(furyMotion, t))
    bloodMist:SetHidden(not rampaging)
    for _, eye in ipairs(eyes) do eye:SetHidden(not rampaging) end
    wolfGlow:SetHidden(not rampaging and not furyReady)
    local pulse = 0.5 + 0.5 * math.sin(t * 6)
    local borderBeat = FuryBeat(t - furyStarted)
    if rampaging then
        local beat = 0.5 + 0.5 * math.sin(t * 8)
        wolf:SetColor(1, 0.12, 0.08, 1)
        wolfGlow:SetDimensions(72, 72)
        wolfGlow:SetColor(1, 0.025, 0.015, 0.45 + 0.55 * beat)
        bloodMist:SetTextureRotation(t * 0.4, 0.5, 0.5)
        bloodMist:SetColor(1, 0.08, 0.04, 0.35 + 0.3 * beat)
        for _, eye in ipairs(eyes) do eye:SetColor(1, 0.12 + 0.2 * beat, 0.06, 0.7 + 0.3 * beat) end
    elseif furyReady then
        local beat = FuryBeat(t - furyStarted - 0.25)
        wolf:SetColor(1, 0.72 + 0.18 * beat, 0.25, 1)
        local size = 68 + 8 * beat
        wolfGlow:SetDimensions(size, size)
        wolfGlow:SetColor(1, 0.55 + 0.35 * beat, 0.12, 0.2 + 0.8 * beat)
    else
        wolf:SetColor(1, 1, 1, 1)
    end
    for i, slice in ipairs(border) do
        local wave = furyReady and borderBeat or (0.5 + 0.5 * math.sin(t * 4 - i * 0.4))
        if rampaging then
            slice:SetColor(1, 0.08 + 0.12 * wave, 0.035, 0.85 + 0.15 * pulse)
        else
            slice:SetColor(1, 0.65 + 0.25 * wave, 0.12, furyReady and (0.5 + 0.5 * borderBeat) or 0.9)
        end
    end
    for i, slice in ipairs(slices) do
        -- Keep a restrained blue fill; low resource retains its warning pulse.
        local wave = 0.5 + 0.5 * math.sin(t * 2.8 - i * 0.38)
        if low then
            slice:SetColor(1, 0.18 + 0.15 * wave, 0.06, 0.55 + 0.45 * pulse)
        else
            slice:SetColor(0.12 + 0.06 * wave, 0.65 + 0.05 * wave, 1, 1)
        end
    end
end

local function Refresh()
    -- AetherChat's main window has no explicit XML tier. Separate tiers keep
    -- even additive HUD flashes below its backdrop, regardless of focus/order.
    local chat = AetherChat_MessengerWindow
    if chat and chat:GetDrawTier() < DT_MEDIUM then
        chat:SetDrawTier(DT_MEDIUM)
    end
    Anchor()
    local current, maximum, effective = GetUnitPower('player', COMBAT_MECHANIC_FLAGS_ULTIMATE)
    maximum = effective and effective > 0 and effective or maximum
    local show = IsPlayerInWerewolfForm() and maximum and maximum > 0
    content:SetHidden(not show)
    root:SetMouseEnabled(not not show)
    if not show then StopDrag() end
    updateSockets(not not show)
    local wasRampaging = rampageEnd > 0
    if show then
        rampageEnd, rampageDuration = Rampage(GetFrameTimeSeconds())
        ultimateMaximum = maximum
        devourGain = DEVOUR_ULTIMATE / maximum
        fraction = math.max(0, math.min(1, (current or 0) / maximum))
        low = fraction <= 0.2
        Target(formMotion, fraction, GetFrameTimeSeconds(), not visible)
        local fury, maxFury, effectiveFury = GetUnitPower('player', COMBAT_MECHANIC_FLAGS_WEREWOLF)
        maxFury = effectiveFury and effectiveFury > 0 and effectiveFury or maxFury
        furyFraction = maxFury and maxFury > 0 and math.max(0, math.min(1, (fury or 0) / maxFury)) or 0
        if furyFraction >= 1 and rampageEnd == 0 and not furyReady then furyStarted = GetFrameTimeSeconds() end
        furyReady = furyFraction >= 1 and rampageEnd == 0
        Target(furyMotion, furyFraction, GetFrameTimeSeconds(), not visible or wasRampaging)
        wolfGlow:SetHidden(not furyReady)
        Animate()
    end
    if not show then
        furyReady, rampageEnd = false, 0
        devourEndpoint, devourTicks = nil, 0
        mealLastTick = nil
        meal:SetHidden(true)
        wolfGlow:SetHidden(true)
        bloodMist:SetHidden(true)
        for _, eye in ipairs(eyes) do eye:SetHidden(true) end
    end
    if visible ~= not not show then
        visible = not not show
        content:SetHandler('OnUpdate', visible and Animate or nil)
    end
end

-- Track actual Ultimate ticks from feeding, not unrelated resource regeneration.
local function OnDevourTick(_, result, isError, abilityName, _, _, _, _, _, targetType,
    amount, powerType, _, _, _, _, abilityId)
    if isError or result ~= ACTION_RESULT_POWER_ENERGIZE or targetType ~= COMBAT_UNIT_TYPE_PLAYER
        or powerType ~= COMBAT_MECHANIC_FLAGS_ULTIMATE or not IsPlayerInWerewolfForm()
        or not (DEVOUR_IDS[abilityId] or devourNames[abilityName]) or not amount or amount <= 0 then return end
    local now = GetFrameTimeSeconds()
    if not devourEndpoint or now >= devourUntil then
        local current = GetUnitPower('player', COMBAT_MECHANIC_FLAGS_ULTIMATE)
        -- Energize reports the tick already applied: pin the pre-tick forecast.
        devourEndpoint = math.max(0, current - amount) + DEVOUR_ULTIMATE
        devourTicks = 0
        mealAwards = {}
    end
    devourTicks = math.min(5, devourTicks + 1)
    mealLastTick = now
    mealAwards[devourTicks] = now
    -- Missing the next one-second tick means the meal was interrupted.
    devourUntil = now + (devourTicks >= 5 and 0.2 or 1.25)
    Refresh()
end

local function Texture(suffix, file, parent)
    local control = WINDOW_MANAGER:CreateControl(NAME .. suffix, parent or content, CT_TEXTURE)
    control:SetTexture('eso-kana-addons/KanaAuras/textures/' .. file .. '.dds')
    control:SetBlendMode(TEX_BLEND_MODE_ALPHA)
    control:SetMouseEnabled(false)
    return control
end

local function Initialize(_, addon)
    if addon ~= 'KanaAuras' then return end
    EVENT_MANAGER:UnregisterForEvent(NAME, EVENT_ADD_ON_LOADED)
    KanaAurasSettings = type(KanaAurasSettings) == 'table' and KanaAurasSettings or {}
    local gap = KanaAurasSettings.wolfGap
    if type(gap) ~= 'number' or gap ~= gap or gap < 0 or gap > 300 then
        KanaAurasSettings.wolfGap = DEFAULT_GAP
    end
    local savedY = KanaAurasSettings.wolfY
    if type(savedY) ~= 'number' or savedY ~= savedY or math.abs(savedY) == math.huge then
        KanaAurasSettings.wolfY = nil
    end
    if GetAbilityName then
        for id in pairs(DEVOUR_IDS) do
            local name = GetAbilityName(id)
            if name and name ~= '' then devourNames[name] = true end
        end
        for _, id in ipairs({266377,267416,267425}) do
            local name = GetAbilityName(id)
            if name and name ~= '' then rampageNames[name] = true end
        end
    end
    root = WINDOW_MANAGER:CreateTopLevelWindow(NAME .. 'Window')
    root:SetDrawTier(DT_LOW)
    root:SetDimensions(WIDTH, HEIGHT)
    root:SetMouseEnabled(false)
    root:SetHidden(true)
    root:SetHandler('OnMouseDown', function(_, button)
        if button ~= MOUSE_BUTTON_INDEX_LEFT or not visible then return end
        local _, y = GetUIMousePosition()
        dragging, dragMouseY, dragBottom = true, y, root:GetBottom()
        root:SetHandler('OnUpdate', Drag)
    end)
    root:SetHandler('OnMouseUp', function(_, button)
        if button == MOUSE_BUTTON_INDEX_LEFT then StopDrag() end
    end)
    root:SetHandler('OnHide', StopDrag)
    content = WINDOW_MANAGER:CreateControl(NAME .. 'Content', root, CT_CONTROL)
    content:SetAnchorFill(root)
    content:SetMouseEnabled(false)
    content:SetHidden(true)
    frame = Texture('Frame', 'EsoWolfFrame')
    frame:SetAnchorFill(content)
    frame:SetColor(1, 1, 1, 1)
    devourPreview = Texture('DevourPreview', 'EsoWolfForm')
    devourPreview:SetColor(0.65, 0.85, 1, 0.20)
    devourPreview:SetHidden(true)
    for i = 1, SLICES do
        local left = CHANNEL_LEFT + (i - 1) * (CHANNEL_RIGHT - CHANNEL_LEFT) / SLICES
        slices[i] = Texture('Fill' .. i, 'EsoWolfForm')
        slices[i]:SetAnchor(TOPLEFT, content, TOPLEFT, WIDTH * left, 0)
        slices[i]:SetHidden(true)
    end
    crest = Texture('Crest', 'EsoWolfCrestNeutral')
    crest:SetAnchor(CENTER, content, TOP, 0, CREST_Y)
    crest:SetDimensions(68, 68)
    borderPlane = WINDOW_MANAGER:CreateControl(NAME .. 'BorderPlane', content, CT_CONTROL)
    borderPlane:SetDimensions(CREST_SIZE / math.sqrt(2), CREST_SIZE / math.sqrt(2))
    borderPlane:SetAnchor(CENTER, crest, CENTER, 0, 0)
    borderPlane:SetMouseEnabled(false)
    borderPlane:SetTransformNormalizedOriginPoint(0.5, 0.5)
    borderPlane:SetTransformRotation(0, 0, math.pi / 4)
    for i = 1, 4 do
        border[i] = Texture('Border' .. i, 'EsoWolfSide' .. i, borderPlane)
        border[i]:SetHidden(true)
    end
    wolf = Texture('Wolf', 'EsoWolfGlyph')
    wolf:SetAnchor(CENTER, content, TOP, 0, CREST_Y)
    wolf:SetDimensions(68, 68)
    wolf:SetColor(1, 1, 1, 1)
    wolfGlow = Texture('WolfGlow', 'EsoWolfGlyph')
    wolfGlow:SetAnchor(CENTER, content, TOP, 0, CREST_Y)
    wolfGlow:SetBlendMode(TEX_BLEND_MODE_ADD)
    wolfGlow:SetDimensions(68, 68)
    wolfGlow:SetHidden(true)
    bloodMist = Texture('BloodMist', 'BloodSmoke')
    bloodMist:SetAnchor(CENTER, content, TOP, 0, CREST_Y)
    bloodMist:SetDimensions(94, 94)
    bloodMist:SetBlendMode(TEX_BLEND_MODE_ADD)
    bloodMist:SetHidden(true)
    for i, x in ipairs({-12, 12}) do
        eyes[i] = Texture('Eye' .. i, 'EsoBloodFlash')
        eyes[i]:SetAnchor(CENTER, content, TOP, x * 0.6, CREST_Y + 2)
        eyes[i]:SetDimensions(12, 8)
        eyes[i]:SetBlendMode(TEX_BLEND_MODE_ADD)
        eyes[i]:SetHidden(true)
    end
    updateSockets = KanaAurasCreateBloodSockets(content)
    meal = WINDOW_MANAGER:CreateControl(NAME .. 'Meal', content, CT_CONTROL)
    meal:SetAnchorFill(content)
    meal:SetMouseEnabled(false)
    meal:SetHidden(true)
    local function MealTexture(name, file, width, height, x, y)
        local texture = Texture('Meal' .. name, file, meal)
        texture:SetDrawLayer(DL_OVERLAY)
        texture:SetDrawLevel(30)
        texture:SetDimensions(width, height)
        texture:SetAnchor(CENTER, meal, TOPLEFT, x, y)
        return texture
    end
    local track = MealTexture('Track', 'DevourThread', 258, 4, 150, 90)
    track:SetColor(0.85, 0.7, 0.45, 0.25)
    mealLine = MealTexture('Line', 'DevourThread', 258, 4, 150, 90)
    mealLine:ClearAnchors()
    mealLine:SetAnchor(LEFT, meal, TOPLEFT, 21, 90)
    mealLine:SetColor(1, 0.88, 0.58, 1)
    mealSpark = MealTexture('Spark', 'DevourSpark', 18, 18, 279, 90)
    mealSpark:SetColor(1, 0.92, 0.7, 1)
    for i = 1, 5 do
        local x = 279 - (i - 1) * 258 / 4
        local outline = MealTexture('TickOutline' .. i, 'DevourMark', 9, 13, x, 90)
        outline:SetColor(0.025, 0.02, 0.015, 1)
        outline:SetDrawLevel(31)
        mealMarks[i] = MealTexture('Tick' .. i, 'DevourMark', 6, 9, x, 90)
        mealMarks[i]:SetDrawLevel(32)
        mealHalos[i] = MealTexture('Halo' .. i, 'DevourHalo', 72, 44, x, 90)
        mealHalos[i]:SetBlendMode(TEX_BLEND_MODE_ADD)
        mealHalos[i]:SetDrawLevel(33)
        mealFlashes[i] = MealTexture('Flash' .. i, 'DevourSpark', 52, 40, x, 90)
        mealFlashes[i]:SetBlendMode(TEX_BLEND_MODE_ADD)
        mealFlashes[i]:SetDrawLevel(34)
        mealCores[i] = MealTexture('FlashCore' .. i, 'DevourSpark', 20, 20, x, 90)
        mealCores[i]:SetBlendMode(TEX_BLEND_MODE_ADD)
        mealCores[i]:SetDrawLevel(35)
    end
    local fragment = ZO_SimpleSceneFragment:New(root)
    HUD_SCENE:AddFragment(fragment)
    HUD_UI_SCENE:AddFragment(fragment)
    EVENT_MANAGER:RegisterForEvent(NAME, EVENT_PLAYER_ACTIVATED, Refresh)
    EVENT_MANAGER:RegisterForEvent(NAME .. 'Drag', EVENT_GLOBAL_MOUSE_UP, function(_, button)
        if button == MOUSE_BUTTON_INDEX_LEFT then StopDrag() end
    end)
    EVENT_MANAGER:RegisterForEvent(NAME .. 'Devour', EVENT_COMBAT_EVENT, OnDevourTick)
    EVENT_MANAGER:AddFilterForEvent(NAME .. 'Devour', EVENT_COMBAT_EVENT,
        REGISTER_FILTER_COMBAT_RESULT, ACTION_RESULT_POWER_ENERGIZE)
    EVENT_MANAGER:AddFilterForEvent(NAME .. 'Devour', EVENT_COMBAT_EVENT,
        REGISTER_FILTER_TARGET_COMBAT_UNIT_TYPE, COMBAT_UNIT_TYPE_PLAYER)
    EVENT_MANAGER:RegisterForUpdate(NAME, 50, Refresh)
    Refresh()
    SLASH_COMMANDS['/kanawolf'] = function(args)
        local value = (args or ''):match('^%s*height%s+(%S+)%s*$')
        if value then
            local gap = value == 'reset' and DEFAULT_GAP or tonumber(value)
            if gap and gap == gap and gap >= 0 and gap <= 300 then
                StopDrag()
                KanaAurasSettings.wolfY = nil
                KanaAurasSettings.wolfGap = gap
                Anchor()
                d(string.format('KanaAuras: отступ над кругом — %g. /kanawolf height reset', gap))
            else
                d('Высота: /kanawolf height 45 (от 0 до 300) или /kanawolf height reset')
            end
            return
        end
        d(string.format('Fury: %.0f%% ready=%s', furyFraction * 100, tostring(furyReady)))
        d(string.format('Rampage: %.1fs', math.max(0, rampageEnd - GetFrameTimeSeconds())))
        d('Положение: включи курсор и тяни панель мышью вверх/вниз. Сброс: /kanawolf height reset')
        local current, maximum, effective = GetUnitPower('player', COMBAT_MECHANIC_FLAGS_ULTIMATE)
        d(string.format('Werewolf: form=%s ultimate=%s/%s effective=%s fill=%.0f%% textureLoaded=%s',
            tostring(IsPlayerInWerewolfForm()), tostring(current), tostring(maximum), tostring(effective),
            fraction * 100, tostring(frame:IsTextureLoaded())))
    end
end
EVENT_MANAGER:RegisterForEvent(NAME, EVENT_ADD_ON_LOADED, Initialize)
