local Profiles = {items={},zones={}}
KanaTrifecta.Profiles = Profiles
local K=KanaTrifecta
function K.CleanName(name)
    return (name or ''):gsub('%^.*$',''):gsub('|c%x%x%x%x%x%x',''):gsub('|r',''):gsub('^%s+',''):gsub('%s+$','')
end

function K.MatchName(name)
    local cleaned=K.CleanName(name):gsub('’',"'"):gsub('‘',"'")
    return (zo_strlower or string.lower)(cleaned)
end

-- This rule needs an observed whole-party transition; entering a zone alone is insufficient.
function Profiles.ClassifyFresh(profile,previous,current)
    if previous and previous.profileKey==profile.key then return 'unknown' end
    if current.freshEntry then return 'fresh' end
    return 'unknown'
end

-- Unknown history permits a local start; fresh runs keep observable dungeon thresholds.
function Profiles.CanUseCombatStart(profile,snapshot)
    return snapshot.lifecycle=='observing' or profile.startRule==0 or profile.startRule==-1
end

function Profiles.ObserveEncounters(profile,signal,context,snapshot)
    local events={}
    local function emit(kind,payload,evidence)
        events[#events+1]={kind=kind,payload=payload,atMs=signal.atMs,
            evidence=evidence or {source=signal.kind,profile=profile.key}}
    end
    local clock=snapshot.clock or {}
    if not clock.startedAtMs and not clock.stopped and (snapshot.lifecycle=='ready' or snapshot.lifecycle=='observing') then
        local engagement=(signal.kind=='combatState' and signal.inCombat)
            or (signal.kind=='combat' and signal.sourceInInstance and signal.isDamage and (signal.hitValue or 0)>0)
        local starts=Profiles.CanUseCombatStart(profile,snapshot) and engagement
        local uncertain=starts and (snapshot.lifecycle=='observing' or profile.startRule~=0)
        if type(profile.startRule)=='number' and profile.startRule>0 then
            if signal.kind=='subzone' and signal.subzoneId==profile.startRule then
                starts=true;uncertain=snapshot.lifecycle=='observing'
            elseif signal.kind=='bossSnapshot' then
                -- Raidificator also starts at boss engagement if a subzone trigger was missed.
                for _,unit in ipairs(signal.units or {}) do
                    if unit.inCombat then starts=true;uncertain=true;break end
                end
            end
        end
        if profile.startAbilityId and signal.kind=='combat' and signal.isStartAbility then
            starts=true;uncertain=snapshot.lifecycle=='observing'
        end
        if starts then emit('RunStarted',{uncertainStart=uncertain,localObservation=uncertain or nil}) end
    end
    if signal.kind=='wipe' then
        for key,boss in pairs(snapshot.bosses or {}) do
            if not boss.killed and boss.pullId then emit('HardModeObserved',{bossKey=key,pullId=boss.pullId,endPull=true}) end
        end
        return events
    end
    local units=signal.units or {}
    if signal.kind=='combat' and signal.isEnemyDeath then
        units={{name=signal.targetName,isDead=true,combatDeath=true}}
    elseif signal.kind~='bossSnapshot' then return events end
    for _,unit in ipairs(units) do
        local name=K.MatchName(unit.name)
        for _,definition in ipairs(profile.bosses or {}) do
            local match=false
            for _,alias in ipairs(definition.aliases or {}) do if K.MatchName(alias)==name then match=true end end
            if K.MatchName(K.Name(definition.name,context.language))==name then match=true end
            local boss=(snapshot.bosses or {})[definition.key]
            if match and boss and not boss.killed and (not unit.combatDeath or boss.pullActive) then
                local pull=boss.pullId
                if unit.inCombat and (not pull or not boss.pullActive) then
                    pull=definition.key..':'..signal.atMs
                    emit('PullStarted',{bossKey=definition.key,pullId=pull})
                end
                if pull and unit.inCombat and definition.healthModes then
                    local mode=definition.healthModes[unit.maxHealth]
                    if mode then emit('HardModeObserved',{bossKey=definition.key,pullId=pull,mode=mode,priority=1},
                        {source='bossMaxHealth',maxHealth=unit.maxHealth,reference=definition.healthSource}) end
                end
                -- Zero HP, disappearance and combat exit alone are deliberately insufficient.
                if unit.isDead==true and definition.terminalDeath then
                    if not pull then pull=definition.key..':death:'..signal.atMs;emit('PullStarted',{bossKey=definition.key,pullId=pull}) end
                    emit('BossKilled',{bossKey=definition.key,pullId=pull,terminal=true},
                        {source=unit.combatDeath and 'bossCombatDeath' or 'bossUnitDeath',name=unit.name,tag=unit.tag,result=unit.combatDeath and signal.result or nil})
                end
            end
        end
    end
    return events
end

function Profiles:Validate(profile)
    local errors, keys = {}, {}
    if type(profile.key)~='string' or not profile.version then errors[#errors+1]='identity' end
    if profile.activityType~='dungeon' then errors[#errors+1]='activityType' end
    if type(profile.zoneIds)~='table' or #profile.zoneIds==0 then errors[#errors+1]='zoneIds' end
    for _,boss in ipairs(profile.bosses or {}) do
        if not boss.key or keys[boss.key] then errors[#errors+1]='bossKey' end
        keys[boss.key or false]=true
    end
    if profile.supportStatus=='validated' and (not profile.bosses or #profile.bosses==0) then errors[#errors+1]='bosses' end
    return errors
end

function Profiles:Register(profile)
    local errors=self:Validate(profile)
    if #errors>0 then return false,errors end
    self.items[profile.key]=profile
    for _,zoneId in ipairs(profile.zoneIds) do self.zones[zoneId]=profile end
    return true,errors
end

function Profiles:Find(zoneId,difficulty)
    if difficulty~=(DUNGEON_DIFFICULTY_VETERAN or 2) then return nil end
    return self.zones[zoneId]
end

function Profiles:List()
    local list={}
    for _,profile in pairs(self.items) do list[#list+1]=profile end
    table.sort(list,function(a,b) return a.key<b.key end)
    return list
end

function Profiles:Observe(profile,signal,context,snapshot)
    return profile.Observe and profile:Observe(signal,context,snapshot) or {}
end

function Profiles:ClassifyContext(profile,previous,current)
    return profile.ClassifyContext and profile:ClassifyContext(previous,current) or 'unknown'
end
