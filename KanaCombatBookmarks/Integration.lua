local addon = KanaCombatBookmarks
local Integration = {}
addon.Integration = Integration
local GRACE_MS = 10000

local function restoreLoadedUnitIds(fight, a)
    if not fight or not fight.log or not fight.unitConversion then return fight end
    -- CMX 22 Save(false) stores raw events after compacting fight.units. Its
    -- loader returns before applying/clearing unitConversion without stringlog.
    -- Load gives us a decoded copy, so the saved payload and live fight stay intact.
    local conversion = fight.unitConversion
    for _, line in ipairs(fight.log) do
        local kind = line[1]
        if kind == a.LIBCOMBAT_EVENT_DAMAGE_OUT or kind == a.LIBCOMBAT_EVENT_DAMAGE_IN
            or kind == a.LIBCOMBAT_EVENT_DAMAGE_SELF or kind == a.LIBCOMBAT_EVENT_HEAL_OUT
            or kind == a.LIBCOMBAT_EVENT_HEAL_IN or kind == a.LIBCOMBAT_EVENT_HEAL_SELF then
            line[4] = conversion[line[4]] or line[4]
            line[5] = conversion[line[5]] or line[5]
        elseif kind == a.LIBCOMBAT_EVENT_EFFECTS_IN or kind == a.LIBCOMBAT_EVENT_EFFECTS_OUT
            or kind == a.LIBCOMBAT_EVENT_GROUPEFFECTS_IN or kind == a.LIBCOMBAT_EVENT_GROUPEFFECTS_OUT then
            line[3] = conversion[line[3]] or line[3]
        elseif kind == a.LIBCOMBAT_EVENT_DEATH then
            line[4] = conversion[line[4]] or line[4]
            -- Death carries an ability ID here; resurrection carries a unit ID.
            if line[3] > 2 then line[5] = conversion[line[5]] or line[5] end
        end
    end
    fight.unitConversion = nil
    return fight
end

function Integration:IsRecording()
    local a = self.api
    local db = a.CMX.db
    if not db or db.lightmode then return false end
    local ava = a.IsPlayerInAvAWorld() or a.IsActiveWorldBattleground()
    return not (ava and (db.offincyrodil or db.lightmodeincyrodil))
end

function Integration:Attach(fight, state)
    state = state or (fight and self.byLog[fight.log])
    if not state then return end
    if state.fight ~= fight then
        -- COMBATSTART is fired just before PrepareFight; use the finalized origin.
        local correction = state.startMs - fight.combatstart
        for _, entry in ipairs(state.data.entries) do entry.offsetMs = entry.offsetMs + correction end
        state.startMs = fight.combatstart
        state.fight = fight
    end
    fight.kanaCombatBookmarks = state.data
end

function Integration:GetViewedFight()
    if self.api.CMX.GetAbilityStats then
        local stats = self.api.CMX.GetAbilityStats()
        if stats then return stats[1] end
    end
    return self.viewedFight
end

function Integration:Mark()
    local a = self.api
    local now = a.GetGameTimeMilliseconds()
    local state = self.active
    local log = a.CMX.currentdata and a.CMX.currentdata.log
    if state and state.log ~= log then state = nil end
    if state and not a.LibCombat.data.inCombat then
        if not state.endMs or now < state.endMs or now - state.endMs > GRACE_MS then state = nil end
    end
    if not state and not a.LibCombat.data.inCombat and self.lastFight then
        local fight = self.lastFight
        local ending = fight.combatend
        if ending and now >= ending and now - ending <= GRACE_MS then state = self.byLog[fight.log] end
    end
    if not self:IsRecording() or not state or #state.log == 0 then
        a.ZO_AlertNoSuppression(a.UI_ALERT_CATEGORY_ALERT, nil, 'Закладка не создана: нет записываемого боя CMX.')
        return nil, 'no_fight'
    end
    state.names = state.names or addon.Names.New(nil, state.data.entries)
    local entry = addon.Model.Add(state.data.entries, now - state.startMs, state.names:Next())
    a.PlaySound(a.SOUNDS.LOCKPICKING_CHAMBER_LOCKED)
    a.ZO_AlertNoSuppression(a.UI_ALERT_CATEGORY_ALERT, nil,
        'Закладка: |cFFD54F' .. entry.name .. '|r · ' .. addon.Model.Time(entry.offsetMs))
    if state.fight and self.onChanged then self.onChanged() end
    return entry
end

function Integration.Install(api)
    if api.CMX.kanaCombatBookmarksAdapter then return api.CMX.kanaCombatBookmarksAdapter end
    local self = setmetatable({api = api, byLog = setmetatable({}, {__mode = 'kv'})}, {__index = Integration})
    api.CMX.kanaCombatBookmarksAdapter = self
    api.LibCombat:RegisterForCombatEvent('KanaCombatBookmarks', api.LIBCOMBAT_EVENT_MESSAGES, function(_, time, message)
        if not self:IsRecording() then self.active = nil; return end
        local log = api.CMX.currentdata and api.CMX.currentdata.log
        if not log then return end
        if message == api.LIBCOMBAT_MESSAGE_COMBATSTART then
            local state = self.byLog[log]
            if not state then
                state = {log = log, startMs = time, data = {version = 1, entries = {}}}
                self.byLog[log] = state
            end
            state.endMs = nil
            self.active = state
            self.lastFight = nil
            self.lastState = nil
        elseif message == api.LIBCOMBAT_MESSAGE_COMBATEND and self.active and self.active.log == log then
            self.active.endMs = time
        end
    end)
    api.LibCombat:RegisterForCombatEvent('KanaCombatBookmarks', api.LIBCOMBAT_EVENT_FIGHTSUMMARY, function(_, fight)
        -- CMX can re-register after us when recording mode changes. Its summary
        -- then has no log yet; it will attach this exact currentdata.log next.
        local log = fight.log or (api.CMX.currentdata and api.CMX.currentdata.log)
        local state = self.byLog[log]
        self:Attach(fight, state)
        self.lastFight = self:IsRecording() and fight or nil
        self.lastState = self.lastFight and state or nil
        if self.active == state then self.active = nil end
        if self.onChanged then self.onChanged() end
    end)
    -- Also cover another addon's Save inside an earlier FIGHTSUMMARY callback.
    local save = api.CombatMetricsFightData.Save
    api.CombatMetricsFightData.Save = function(fight, ...)
        self:Attach(fight)
        return save(fight, ...)
    end
    local load = api.CombatMetricsFightData.Load
    if type(load) == 'function' then
        api.CombatMetricsFightData.Load = function(...)
            return restoreLoadedUnitIds(load(...), api)
        end
    end
    return self
end
