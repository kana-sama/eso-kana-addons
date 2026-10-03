local ADDON_NAME = "KanaPlayerPing"

local function Initialize()
    local ring = WINDOW_MANAGER:CreateControl(ADDON_NAME .. "Waves", GuiRoot, CT_CONTROL)
    ring:SetHidden(true)
    ring:SetMouseEnabled(false)
    ring:SetDimensions(1, 1)

    -- Animate geometry explicitly; no sprite animation or network map ping.
    local waves = {}
    for index = 1, 3 do
        local wave = WINDOW_MANAGER:CreateControl(ADDON_NAME .. "Wave" .. index, ring, CT_TEXTURE)
        wave:SetMouseEnabled(false)
        wave:SetTexture("eso-kana-addons/KanaPlayerPing/ring-bold.dds")
        wave:SetColor(0.35, 0.8, 1, 1)
        wave:SetDrawLayer(DL_OVERLAY)
        wave:SetAnchor(CENTER, ring, CENTER, 0, 0)
        waves[index] = wave
    end

    local function Animate(_, time)
        for index, wave in ipairs(waves) do
            local phase = (time / 1.8 + (index - 1) / #waves) % 1
            local size = 12 + phase * 78
            wave:SetDimensions(size, size)
            wave:SetAlpha(math.min(1, phase * 12, (1 - phase) / 0.2))
        end
    end

    local attachedControl
    local playing = false

    local function Update()
        local manager = ZO_WorldMap_GetPinManager()
        local pin = manager and manager:GetPlayerPin()
        local control = pin and pin:GetControl()

        if control and control ~= attachedControl then
            ring:SetParent(control)
            ring:ClearAnchors()
            ring:SetAnchor(CENTER, control, CENTER, 0, 0)
            attachedControl = control
        end

        local visible = control ~= nil and not control:IsControlHidden()
        ring:SetHidden(not visible)
        if visible and not playing then
            Animate(nil, GetFrameTimeSeconds())
            ring:SetHandler("OnUpdate", Animate)
            playing = true
        elseif not visible and playing then
            ring:SetHandler("OnUpdate", nil)
            playing = false
        end
    end

    -- Parenting follows the player's pin every frame. Poll only for pin
    -- replacement and map visibility, including maps reused by minimaps.
    EVENT_MANAGER:RegisterForUpdate(ADDON_NAME, 250, Update)
    Update()
end

EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED, function(_, name)
    if name ~= ADDON_NAME then return end
    EVENT_MANAGER:UnregisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED)
    Initialize()
end)
