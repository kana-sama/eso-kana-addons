local K = KanaPenetration
local M = K.Model
local Observer = {}
Observer.__index = Observer
K.Observer = Observer

-- Match the final boss's complete localized unit name, not Tho'at's shards.
local archiveBossNames = {
    ["Tho'at Replicanum"]=true, ["Tho’at Replicanum"]=true,
    ['То’ат Копировальщица']=true, ['То\'ат Копировальщица']=true,
    ["Replicanum de Tho'at"]=true,
    ['ソアト・レプリカヌム']=true, ['索特复影体']=true,
}

function Observer.New(api)
    local self = setmetatable({api=api}, Observer)
    self.lookup = M.BuildLookup(function(id) return self:Name(api.GetAbilityName(id)) end)
    self.dummies = M.BuildDummyLookup(function(id)
        return self:Name(api.GetItemLinkName('|H0:item:' .. id .. ':1:1:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h'))
    end)
    return self
end

function Observer:Name(text)
    return self.api.zo_strformat(self.api.SI_ABILITY_NAME, text or '')
end

function Observer:Context()
    local a = self.api
    local zoneIndex = a.GetUnitZoneIndex('player')
    local zoneId = zoneIndex and zoneIndex > 0 and a.GetZoneId(zoneIndex) or 0
    -- Compass POIs can describe a nearby entrance while the player is outside.
    -- Current-zone difficulty distinguishes group content from delves/publics.
    local difficulty = a.GetCurrentZoneDungeonDifficulty()
    return {
        zoneId=zoneId, unknown=zoneId == 0,
        dungeon=difficulty ~= nil and difficulty ~= a.DUNGEON_DIFFICULTY_NONE,
        archive=a.IsInstanceEndlessDungeon(), house=a.GetCurrentZoneHouseId() ~= 0,
    }
end

function Observer:ForceOfNature()
    local a = self.api
    for slot = 1, 12 do
        if a.GetSlotBoundId(slot, a.HOTBAR_CATEGORY_CHAMPION) == 276 then
            return a.GetNumPointsSpentOnChampionSkill(276) >= 50
        end
    end
    return false
end

function Observer:Capture(settings)
    local a, target = self.api, 'reticleover'
    if not a.DoesUnitExist(target) or not a.IsUnitAttackable(target) or a.IsUnitPlayer(target)
        or a.IsUnitDeadOrReincarnating(target) or a.IsUnitJusticeGuard(target)
        or a.IsPlayerInAvAWorld() or a.IsActiveWorldBattleground() then return nil end

    local now, effects = a.GetFrameTimeSeconds(), {}
    for index = 1, a.GetNumBuffs(target) do
        local name, startTime, endTime, _, _, _, _, _, _, _, id = a.GetUnitBuffInfo(target, index)
        if id and id > 0 and (not startTime or startTime <= now)
            and (not endTime or endTime == 0 or endTime > now) then
            effects[#effects + 1] = {id=id, name=self:Name(name)}
        end
    end
    local forceOfNature = self:ForceOfNature()
    local name, context = self:Name(a.GetUnitName(target)), self:Context()
    context.dummy = self.dummies[name]
    context.archiveBoss = context.archive and archiveBossNames[name] == true
    if not context.dummy and context.house then
        local _, maxHealth = a.GetUnitPower(target, a.COMBAT_MECHANIC_FLAGS_HEALTH)
        context.dummy = M.HousingDummy(maxHealth)
    end
    local reductions = M.Effects(effects, self.lookup, settings, forceOfNature,
        context.dummy and context.dummy.trial)
    local base, source = M.Profile(context, settings)
    local function Row(stat, reduction)
        local personal = M.Number(a.GetPlayerStat(stat, a.STAT_BONUS_OPTION_APPLY_BONUS))
        local low = personal and personal + reductions.bonus
        local high = personal and personal + reductions.bonusMax
        local row = M.Calculate(base, low, reduction)
        row.upperPenetration = high
        row.upperPercent = M.Calculate(base, high, reduction).percent
        return row
    end
    return {
        name=name, base=base, source=source,
        physical=Row(a.STAT_PHYSICAL_PENETRATION, reductions.physical),
        spell=Row(a.STAT_SPELL_PENETRATION, reductions.spell),
        -- Some status effects are only exposed as combat events. Do not silently
        -- treat an incomplete reticle buff list as the exact Force of Nature bonus.
        conditional=forceOfNature and reductions.bonus < reductions.bonusMax,
    }
end
