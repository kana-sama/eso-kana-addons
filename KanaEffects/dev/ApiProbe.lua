-- Opt-in local report only. No player chat and no registrations at file load.
local ApiProbe = {}
KanaEffects.ApiProbe = ApiProbe
local nextId = 0
local BUFF_FIELDS = { "name", "startTime", "endTime", "effectSlot", "stacks", "icon",
    "deprecatedBuffType", "effectType", "abilityType", "statusEffectType", "abilityId", "canClickOff", "castByPlayer" }
local function pack(...) return { n = select("#", ...), ... } end
local function captureCall(report, key, callback)
    local result = pack(pcall(callback))
    if result[1] then
        if result.n == 2 then report[key] = result[2]
        else
            local values = {n = result.n - 1}
            for index = 2, result.n do values[index - 1] = result[index] end
            report[key] = values
        end
    else report[key] = { error = tostring(result[2]) } end
end

function ApiProbe.Start(api, options)
    options = options or {}
    nextId = nextId + 1
    local owner = "KanaEffectsApiProbe" .. nextId
    local maximum = options.maxSamples or 100
    assert(type(maximum) == "number" and maximum >= 1 and maximum % 1 == 0, "maxSamples must be positive integer")
    local report = options.report or {}
    report.sourceStatus = "live sample; interpretation of clocks/context requires manual verification"
    report.samples, report.hud, report.capabilities = {}, {}, {}
    for key, value in pairs(api.capabilities or {}) do report.capabilities[key] = value end
    report.expectedBuffReturnOrder = BUFF_FIELDS
    if api.GetAPIVersion then captureCall(report, "apiVersion", api.GetAPIVersion) end
    if api.GetUIGlobalScale then captureCall(report, "uiGlobalScale", api.GetUIGlobalScale) end
    if api.GetUICustomScale then captureCall(report, "uiCustomScale", api.GetUICustomScale) end
    local root = api.controls and api.controls.GuiRoot
    if root then
        captureCall(report, "guiRootDimensions", function() return root:GetDimensions() end)
        captureCall(report, "guiRootScale", function() return root:GetScale() end)
    end
    local probe = { report = report, stopped = false, events = {}, callbacks = {} }
    function probe:Capture(label)
        if self.stopped then return end
        local sample = { label = label or "manual", units = {} }
        captureCall(sample, "frameTimeSeconds", api.Now)
        if api.GetGameTimeSeconds then captureCall(sample, "gameTimeSeconds", api.GetGameTimeSeconds) end
        if api.GetGameTimeMilliseconds then captureCall(sample, "gameTimeMilliseconds", api.GetGameTimeMilliseconds) end
        if api.GetUIMousePosition then captureCall(sample, "mouseUiPosition", api.GetUIMousePosition) end
        for _, tag in ipairs(options.unitTags or {"player", "reticleover", "boss1", "boss2", "boss3", "boss4", "boss5", "boss6"}) do
            local unit = { buffs = {} }; sample.units[tag] = unit
            if api.DoesUnitExist then captureCall(unit, "exists", function() return api.DoesUnitExist(tag) end) end
            if api.GetUnitName then captureCall(unit, "name", function() return api.GetUnitName(tag) end) end
            if api.GetNumBuffs and api.GetUnitBuffInfo then
                captureCall(unit, "buffCount", function() return api.GetNumBuffs(tag) end)
                if type(unit.buffCount) == "number" then
                    for index = 1, math.min(unit.buffCount, 64) do
                        local buff = {buffIndex = index}; unit.buffs[index] = buff
                        local values = pack(pcall(api.GetUnitBuffInfo, tag, index))
                        if values[1] then
                            buff.returnCount = values.n - 1
                            for fieldIndex, field in ipairs(BUFF_FIELDS) do buff[field] = values[fieldIndex + 1] end
                            if type(buff.startTime) == "number" and type(buff.endTime) == "number" then
                                buff.fullDurationRaw = buff.endTime - buff.startTime
                            end
                            if type(buff.endTime) == "number" and type(sample.frameTimeSeconds) == "number" then
                                buff.remainingAgainstFrameSeconds = buff.endTime - sample.frameTimeSeconds
                            end
                            -- Self context is a reported fact. Other casts have no caster tag
                            -- and are deliberately not classified with the recipient tag.
                            if buff.castByPlayer == true and api.GetAbilityBuffType then
                                buff.casterContext = "player"
                                captureCall(buff, "buffTypeForPlayerCaster", function() return api.GetAbilityBuffType(buff.abilityId, "player") end)
                            else buff.casterContext = "unverified: no caster unit tag" end
                        else buff.error = tostring(values[2]) end
                    end
                end
            end
        end
        report.samples[#report.samples + 1] = sample
        while #report.samples > maximum do table.remove(report.samples, 1) end
    end
    function probe:Stop()
        if self.stopped then return end
        self.stopped = true
        for _, event in ipairs(self.events) do api.eventManager:UnregisterForEvent(owner, event) end
        for _, entry in ipairs(self.callbacks) do api.hudManager:UnregisterCallback(entry.name, entry.callback) end
        if self.hudControl then self.hudControl:SetHidden(true) end
        if self.setHudValid then
            self.setHudValid(false)
            if api.capabilities.nativeHudRebuild then api.hudManager:RebuildAllElements() end
            report.hud.removal = "unverified: no public unregister; content hidden, isValid=false, registration retained until reload"
        end
    end
    local manager = api.eventManager
    if manager and type(manager.RegisterForEvent) == "function" and type(manager.UnregisterForEvent) == "function" then
        for _, eventName in ipairs({"EVENT_RETICLE_TARGET_CHANGED", "EVENT_BOSSES_CHANGED", "EVENT_SCREEN_RESIZED"}) do
            local event = api.constants[eventName]
            if event then
                manager:RegisterForEvent(owner, event, function() if not probe.stopped then probe:Capture(eventName) end end)
                probe.events[#probe.events + 1] = event
            end
        end
    end
    if options.hud == true then
        local hud = api.hudManager
        if not (api.capabilities.nativeHudRegistration and api.capabilities.controls) then
            report.hud.registration = "unavailable"
        else
            captureCall(report.hud, "registration", function()
                local control = api.controls.CreateControl(owner .. "Control", root, api.constants.CT_CONTROL)
                control:SetDimensions(100, 32)
                control:SetAnchor(api.constants.TOPLEFT, root, api.constants.TOPLEFT, 20, 20)
                control:SetHidden(true)
                -- Public HUD manager geometry reads this reference directly.
                control.hudElementRef = control
                probe.hudControl = control
                local valid = true
                probe.setHudValid = function(value) valid = value end
                local optionsTable = {}
                if api.hudOptionTypes and api.hudOptionTypes.BOOLEAN then
                    optionsTable[1] = { key = "probeOption", type = api.hudOptionTypes.BOOLEAN,
                        name = "KanaEffects probe", defaultValue = false, dontSave = true,
                        callback = function(_, subKey, oldValue, value)
                            if probe.stopped then return end
                            report.hud.optionCallback = { oldValue = oldValue, value = value, subKey = subKey }
                        end }
                end
                local element = hud:RegisterKeyboardElement(control, "KanaEffects API probe", {isValid=function() return valid end}, optionsTable)
                probe.hudElement = element
                report.hud.initialValid = element:IsValid()
                if #optionsTable > 0 then
                    element:SetCustomOptionValue("probeOption", nil, true)
                    report.hud.optionsCallbackObserved = report.hud.optionCallback ~= nil
                end
                if api.capabilities.nativeHudCallbacks then
                    local callback = function()
                        if not probe.stopped then report.hud.rebuildCallbacks = (report.hud.rebuildCallbacks or 0) + 1 end
                    end
                    hud:RegisterCallback("RebuildAllElements", callback)
                    probe.callbacks[1] = {name="RebuildAllElements", callback=callback}
                end
                if api.capabilities.nativeHudRebuild then hud:RebuildAllElements() end
                return "registered; inspect native editor then call Stop and inspect filtering"
            end)
        end
    end
    ApiProbe.LastReport = report
    probe:Capture("start")
    return probe
end
