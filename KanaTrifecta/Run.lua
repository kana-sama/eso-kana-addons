KanaTrifecta = KanaTrifecta or {}
local K = KanaTrifecta
local Run = {}
Run.__index = Run
K.Run = Run

function K.Copy(value)
    if type(value) ~= 'table' then return value end
    local out = {}
    for key, item in pairs(value) do out[key] = K.Copy(item) end
    return out
end

function K.Name(value, language)
    if type(value) == 'table' then return value[language] or value.en or '' end
    return value or ''
end

function Run.New(profile, context)
    local fresh = context.freshness == 'fresh' and profile.supportStatus ~= 'unsupported'
    local self = setmetatable({profile=profile,profileKey=profile.key,profileVersion=profile.version,
        runKey=context.runKey,contextGeneration=context.contextGeneration,language=context.language or 'en',
        lifecycle=fresh and 'ready' or 'observing',clock={stopped=false,quality='unknown'},
        deathCount=0,deathCoverage=fresh and 'full' or 'unknown',members={},bosses={},
        additionalConditions={},failureReasons={},serverConfirmations={},seen={},deathWindowOpen=true},Run)
    for _, boss in ipairs(profile.bosses or {}) do
        self.bosses[boss.key] = {bossKey=boss.key,hasHardMode=boss.hasHardMode,
            requiresHardMode=boss.requiresHardMode,state='pending',mode='unknown'}
    end
    return self
end

function Run:StopIfKilled()
    local latest, count, allTimes = nil, 0, true
    for _, definition in ipairs(self.profile.bosses or {}) do
        local boss = self.bosses[definition.key]
        if not boss.killed then return end
        count = count + 1
        if boss.killedAtMs then latest = math.max(latest or boss.killedAtMs,boss.killedAtMs)
        else allTimes = false end
    end
    if count == 0 then return end
    self.clock.stopped = true
    if allTimes and latest and self.clock.startedAtMs then
        self.clock.stoppedElapsedMs = math.max(0,latest-self.clock.startedAtMs)
        if self.clock.rangeOffsetMs then
            self.clock.stoppedRangeMs={self.clock.stoppedElapsedMs+self.clock.rangeOffsetMs[1],self.clock.stoppedElapsedMs+self.clock.rangeOffsetMs[2]}
        end
    else
        self.clock.quality = 'unknown'
    end
end

function Run:ClassifyKill(boss)
    if not boss.killed then return end
    if not boss.requiresHardMode or boss.mode=='active' then boss.state='completed'
    elseif boss.mode=='inactive' then boss.state='failed'
    else boss.state='unknown' end
    boss.reason = boss.state=='failed' and 'hardmodeMissing' or (boss.state=='unknown' and 'hardmodeUnknown' or nil)
    self.failureReasons['boss:'..boss.bossKey] = boss.state=='failed' or nil
end

function Run:ObserveMember(kind,p,event)
    if not p.memberKey then return false end
    local member = self.members[p.memberKey]
    if p.human==false or p.inInstance==false then
        if member then member.inInstance=false;member.isDead=nil end
        return false
    end
    if not member then
        if kind~='MemberObserved' and p.inWindow~=true then
            self.deathCoverage='partial';return false
        end
        member={memberKey=p.memberKey,inInstance=true,transition=0}
        self.members[p.memberKey]=member
    end
    if p.inInstance==true then member.inInstance=true end
    if not member.inInstance then return false end
    local dead = kind=='MemberDied' or (kind=='MemberObserved' and p.isDead==true)
    if dead and member.isDead~=true and self.deathWindowOpen then
        if member.isDead==false or p.inWindow==true then
            self.deathCount=self.deathCount+1
            member.transition=member.transition+1
            member.lastDeath={atMs=event.atMs,evidence=K.Copy(event.evidence)}
            self.failureReasons.deaths=true
            if member.isDead==nil then self.deathCoverage='partial' end
        else
            self.deathCoverage='partial'
        end
    end
    member.isDead=dead
    return true
end

function Run:Apply(event)
    if event.contextGeneration ~= self.contextGeneration then return false end
    local p, kind = event.payload or {}, event.kind
    if (kind=='BossKilled' or kind=='MemberDied' or kind=='AchievementAwarded') and event.key then
        if self.seen[event.key] then return false end
        self.seen[event.key] = true
    end
    if kind == 'RunStarted' then
        if self.clock.startedAtMs or self.clock.stopped or (self.lifecycle=='observing' and not p.localObservation) then return false end
        self.clock.startedAtMs, self.clock.startedAtWallSec = event.atMs, event.wallSec
        self.clock.quality = event.atMs and (p.uncertainStart and 'estimated' or 'observed') or 'unknown'
        self.clock.unboundedStart = p.uncertainStart or nil
        self.clock.localObservation = p.localObservation or nil
        self.clock.startEvidence = K.Copy(event.evidence)
        self.lifecycle = 'running'
    elseif kind == 'PullStarted' then
        local boss = self.bosses[p.bossKey]
        if not boss or boss.killed or boss.pullId==p.pullId then return false end
        boss.coverageLost=nil
        boss.pullId, boss.mode, boss.modePriority, boss.conflict, boss.pullActive = p.pullId, 'unknown', nil, false, true
    elseif kind == 'HardModeObserved' then
        local boss=self.bosses[p.bossKey]
        if not boss or boss.pullId~=p.pullId then return false end
        if p.endPull then boss.pullActive=false;return true end
        if p.mode~='active' and p.mode~='inactive' then return false end
        local priority=p.priority or 0
        if boss.modePriority==nil or priority>boss.modePriority then
            boss.mode,boss.modePriority,boss.conflict=p.mode,priority,false
        elseif priority==boss.modePriority and p.mode~=boss.mode then
            boss.mode,boss.conflict='unknown',true
        else return false end
        boss.modeEvidence=K.Copy(event.evidence)
        self:ClassifyKill(boss)
    elseif kind == 'BossKilled' then
        local boss = self.bosses[p.bossKey]
        if not boss or boss.killed or p.terminal~=true or boss.pullId~=p.pullId then return false end
        boss.killed, boss.killedAtMs, boss.evidence = true, event.atMs, K.Copy(event.evidence)
        self:ClassifyKill(boss)
        self:StopIfKilled()
    elseif kind=='MemberObserved' or kind=='MemberDied' or kind=='MemberRevived' then
        return self:ObserveMember(kind,p,event)
    elseif kind=='CoverageLost' then
        if p.deaths then self.deathCoverage=self.deathCoverage=='full' and 'partial' or self.deathCoverage end
        if p.time then self.clock.quality='unknown' end
        if p.bossKey and self.bosses[p.bossKey] then self.bosses[p.bossKey].coverageLost=true end
    elseif kind=='AchievementAwarded' then
        if p.historical then return false end
        local found=false
        for _,value in pairs(self.profile.achievementIds or {}) do
            if type(value)=='table' then
                for _,id in pairs(value) do if id==p.id then found=true end end
            elseif value==p.id then found=true end
        end
        if not found then return false end
        self.serverConfirmations[p.id]={atMs=event.atMs,evidence=K.Copy(event.evidence)}
    elseif kind == 'RunCompleted' then
        self.lifecycle='finished'
        if p.closeDeathWindow~=false then self.deathWindowOpen=false end
        for key,value in pairs(p.conditions or {}) do self.additionalConditions[key]=value end
    elseif kind == 'ContextLeft' then
        self.lifecycle = 'suspended'
    else
        return false
    end
    return true
end

local function formatSeconds(seconds)
    return string.format('%02d:%02d',math.floor(seconds/60),seconds%60)
end

function K.FormatDuration(ms)
    if type(ms)~='number' then return '—' end
    return formatSeconds(math.floor(math.max(0,ms)/1000))
end

function Run:View(nowMs)
    local clock, limit = self.clock, self.profile.limitMs
    local elapsed, low, high
    if clock.stopped then
        elapsed = clock.stoppedElapsedMs
        if clock.stoppedRangeMs then low,high=clock.stoppedRangeMs[1],clock.stoppedRangeMs[2] end
    elseif clock.startedAtMs then
        elapsed = math.max(0,nowMs-clock.startedAtMs)
        if clock.rangeOffsetMs then low,high=elapsed+clock.rangeOffsetMs[1],elapsed+clock.rangeOffsetMs[2] end
    end
    if low then elapsed=(low+high)/2 end
    local timeText, timeRole, overtime = '--:--', 'hint', false
    if type(limit)=='number' and elapsed and clock.quality~='unknown' then
        local uncertain = clock.unboundedStart or (low and low<=limit and high>limit)
        overtime = (low or elapsed)>limit or (clock.stopped and self.profile.deadlineRule=='before' and (low or elapsed)>=limit)
        local seconds = elapsed<=limit and math.ceil((limit-elapsed)/1000) or math.floor((elapsed-limit)/1000)
        timeText = (clock.quality=='estimated' and not clock.localObservation and '~' or '')..formatSeconds(math.max(0,seconds))
        timeRole = overtime and 'error' or (uncertain and not clock.localObservation and 'hint' or 'normal')
    elseif not clock.stopped and not clock.startedAtMs and type(limit)=='number'
        and (self.lifecycle=='ready' or self.lifecycle=='observing') then
        timeText, timeRole = formatSeconds(math.ceil(limit/1000)), 'normal'
    end
    local rows, allKilled, unknownBoss = {}, true, false
    for _, definition in ipairs(self.profile.bosses or {}) do
        local boss = self.bosses[definition.key]
        allKilled=allKilled and boss.killed==true
        unknownBoss=unknownBoss or boss.state=='unknown' or boss.coverageLost==true
        local killElapsed=boss.killed and type(boss.killedAtMs)=='number' and type(clock.startedAtMs)=='number'
            and boss.killedAtMs-clock.startedAtMs or nil
        rows[#rows+1]={killTimeText=killElapsed and killElapsed>=0 and K.FormatDuration(killElapsed) or nil,bossKey=definition.key,name=K.Name(definition.name,self.language),
            hasHardMode=boss.hasHardMode,state=boss.state,
            colorRole=boss.state=='completed' and 'success' or (boss.state=='failed' and 'error' or 'hint'),
            evidence=boss.evidence,reason=boss.reason}
    end
    local deathText = tostring(self.deathCount)
    local reasons=K.Copy(self.failureReasons)
    if overtime and not clock.unboundedStart then reasons.time=true end
    local unknown = clock.unboundedStart or timeRole=='hint' or unknownBoss or self.deathCoverage~='full' or (clock.quality=='unknown' and self.lifecycle~='ready')
    for _,requirement in ipairs(self.profile.additionalRequirements or {}) do
        local key=type(requirement)=='table' and requirement.key or requirement
        if self.additionalConditions[key]==false then reasons['additional:'..key]=true
        elseif self.additionalConditions[key]~=true and self.lifecycle=='finished' then unknown=true end
    end
    local assessment='possible'
    if next(reasons) then assessment='failed'
    elseif unknown or (self.lifecycle=='finished' and (not allKilled or #rows==0)) then assessment='unknown'
    elseif self.lifecycle=='finished' and clock.stopped then assessment='fulfilledObserved' end
    return {lifecycle=self.lifecycle,title=K.Name(self.profile.name,self.language),
        timer={text=timeText,colorRole=timeRole,quality=clock.quality,elapsedMs=elapsed,stopped=clock.stopped,
            limitMs=limit,evidence=clock.startEvidence},
        deaths={text=deathText,count=self.deathCount,coverage=self.deathCoverage,
            colorRole=(overtime or reasons.time or self.deathCount>0) and 'error' or 'normal'},
        bossRows=rows,failureReasons=reasons,assessment=assessment,serverConfirmations=K.Copy(self.serverConfirmations)}
end

function Run:Snapshot()
    local snapshot = {schemaVersion=1}
    for _,key in ipairs({'runKey','contextGeneration','profileKey','profileVersion','language','lifecycle',
        'clock','deathCount','deathCoverage','members','bosses','additionalConditions','failureReasons','serverConfirmations','seen','deathWindowOpen'}) do
        snapshot[key]=K.Copy(self[key])
    end
    return snapshot
end
