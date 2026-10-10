local K=KanaTrifecta
local Observer={};Observer.__index=Observer;K.Observer=Observer
function Observer.New(api,emit)
    return setmetatable({api=api,emit=emit,serial=0,tags={},members={},registered={},bossUnits={},pulls={}},Observer)
end
function Observer:ReadContext()
    local a=self.api
    local index=a.GetUnitZoneIndex('player')
    return {zoneId=a.GetZoneId(index),difficulty=a.GetCurrentZoneDungeonDifficulty(),
        language=a.GetCVar and a.GetCVar('language.2') or 'en',members=self:ReadRoster()}
end
function Observer:ReadRoster()
    local a,result=self.api,{}
    if not a.GetGroupSize or not a.GetUnitDisplayName then return result end
    local units={'player'}
    for i=1,a.GetGroupSize() do units[#units+1]=a.GetGroupUnitTagByIndex(i) end
    for _,tag in ipairs(units) do
        if not (a.IsGroupCompanionUnitTag and a.IsGroupCompanionUnitTag(tag)) then
            local display,name=a.GetUnitDisplayName(tag),a.GetRawUnitName(tag)
            if display and display~='' and name and name~='' then
                local index=a.GetUnitZoneIndex(tag)
                result[display..'\31'..name]={zoneId=index and a.GetZoneId(index),
                    inCombat=a.IsUnitInCombat and a.IsUnitInCombat(tag) or false,
                    dead=a.IsUnitDead(tag)}
            end
        end
    end
    return result
end
function Observer:Emit(kind,payload,atMs,evidence,key)
    if not self.context then return end
    self.serial=self.serial+1
    self.emit({kind=kind,key=key or ('event:'..self.context.contextGeneration..':'..self.serial),
        contextGeneration=self.context.contextGeneration,atMs=atMs or self.api.GetGameTimeMilliseconds(),
        wallSec=self.api.GetTimeStamp(),payload=K.Copy(payload),evidence=evidence or {source='unitState'}})
end
function Observer:SyncMembers(skipDeathState)
    if not self.context then return end
    local a, tags, current={}, {}, {}
    a=self.api
    local units={'player'}
    for i=1,a.GetGroupSize() do units[#units+1]=a.GetGroupUnitTagByIndex(i) end
    for _,tag in ipairs(units) do
        local human=not (a.IsGroupCompanionUnitTag and a.IsGroupCompanionUnitTag(tag))
        local display,name=a.GetUnitDisplayName(tag),a.GetRawUnitName(tag)
        if human and display and display~='' and name and name~='' then
            local key=display..'\31'..name
            tags[tag]=key
            local same=tag=='player' or a.IsGroupMemberInSameInstanceAsPlayer(tag)
            local online=not a.IsUnitOnline or a.IsUnitOnline(tag)
            if not current[key] or tag=='player' then
                current[key]={memberKey=key,isDead=a.IsUnitDead(tag),inInstance=same and online,human=true,online=online,
                    inWindow=self.context.freshness=='fresh'}
            end
        end
    end
    self.tags=tags
    for key,p in pairs(current) do
        local old=self.members[key]
        if skipDeathState and old and old.inInstance then p.isDead=old.isDead end
        if old and not old.inInstance then p.inWindow=false end
        if old and old.inInstance and not p.inInstance then self:Emit('CoverageLost',{deaths=true}) end
        if not old or old.isDead~=p.isDead or old.inInstance~=p.inInstance or old.online~=p.online then
            if old and old.online and not p.online then self:Emit('CoverageLost',{deaths=true}) end
            self:Emit('MemberObserved',p)
        end
    end
    for key,old in pairs(self.members) do
        if not current[key] and old.inInstance then self:Emit('MemberObserved',{memberKey=key,inInstance=false,human=true}) end
    end
    self.members=current
end
function Observer:Death(tag,dead)
    if not self.context then return end
    self:SyncMembers(true)
    local key=self.tags[tag]
    local member=key and self.members[key]
    if not member or not member.inInstance or not member.online then return end
    self:Emit(dead and 'MemberDied' or 'MemberRevived',
        {memberKey=key,inInstance=true,human=true,inWindow=self.context.freshness=='fresh'},nil,{source='deathState',tag=tag})
    member.isDead=dead
    if dead then
        local allDead,count=true,0
        for _,m in pairs(self.members) do
            if m.inInstance and m.online then count=count+1;allDead=allDead and m.isDead end
        end
        if count>0 and allDead then self:Handle({kind='wipe'}) end
    end
end
function Observer:Handle(signal)
    if not self.context or (signal.contextGeneration and signal.contextGeneration~=self.context.contextGeneration) then return end
    signal.contextGeneration=self.context.contextGeneration
    signal.atMs=signal.atMs or self.api.GetGameTimeMilliseconds()
    if self.recordEvidence then self.recordEvidence(signal) end
    if self.profile and self.profile.Observe then
        for _,event in ipairs(K.Profiles:Observe(self.profile,signal,self.context,self.snapshot and self.snapshot() or {})) do
            event.contextGeneration=self.context.contextGeneration
            event.atMs=event.atMs or signal.atMs
            event.wallSec=event.wallSec or self.api.GetTimeStamp()
            self.serial=self.serial+1;event.key=event.key or ('profile:'..self.context.contextGeneration..':'..self.serial)
            self.emit(event)
        end
    end
end
function Observer:Bind(eventName,handler,filters,suffix,startOnly)
    local a=self.api;local event=a[eventName]
    if not event or not a.EVENT_MANAGER then return end
    local name='KanaTrifectaObserver_'..eventName..(suffix or '')
    local generation=self.context.contextGeneration
    a.EVENT_MANAGER:RegisterForEvent(name,event,function(...)
        if self.context and self.context.contextGeneration==generation then handler(...) end
    end)
    for _,filter in ipairs(filters or {}) do a.EVENT_MANAGER:AddFilterForEvent(name,event,unpack(filter)) end
    self.registered[#self.registered+1]={name,event,startOnly}
end
function Observer:Activate(profile,context)
    self:Deactivate();self.profile,self.context=profile,context
    self:Bind('EVENT_UNIT_DEATH_STATE_CHANGED',function(_,tag,dead)
        if tag:match('^boss%d+$') then self:ScanBosses('deathState',tag,dead) else self:Death(tag,dead) end
    end)
    for _,event in ipairs({'EVENT_GROUP_UPDATE','EVENT_GROUP_MEMBER_JOINED','EVENT_GROUP_MEMBER_LEFT','EVENT_GROUP_MEMBER_CONNECTED_STATUS','EVENT_GROUP_MEMBER_SUBZONE_CHANGED','EVENT_GROUP_MEMBER_IN_REMOTE_REGION'}) do
        self:Bind(event,function() self:SyncMembers() end)
    end
    self:Bind('EVENT_BOSSES_CHANGED',function() self:ScanBosses('bossesChanged') end)
    self:Bind('EVENT_POWER_UPDATE',function(_,tag,_,power)
        if power==self.api.POWERTYPE_HEALTH and tag:match('^boss%d+$') then self:ScanBosses('power',tag) end
    end, self.api.REGISTER_FILTER_POWER_TYPE and {{self.api.REGISTER_FILTER_POWER_TYPE,self.api.POWERTYPE_HEALTH}} or nil)
    self:Bind('EVENT_PLAYER_COMBAT_STATE',function(_,combat)
        self:Handle({kind='combatState',inCombat=combat});self:ScanBosses('combatState')
    end)
    local function combat(_,result,isError,ability,graphic,slot,source,sourceType,target,targetType,value,power,damage,log,sourceId,targetId,abilityId)
        if isError then return end
        local sourceInInstance=false
        local rawName=K.CleanName(source)
        for key,member in pairs(self.members) do
            if member.inInstance and member.online and K.CleanName(key:match('\31(.*)$'))==rawName then sourceInInstance=true;break end
        end
        local damageResult=result==self.api.ACTION_RESULT_DAMAGE or result==self.api.ACTION_RESULT_CRITICAL_DAMAGE
            or result==self.api.ACTION_RESULT_DOT_TICK or result==self.api.ACTION_RESULT_DOT_TICK_CRITICAL
            or result==self.api.ACTION_RESULT_BLOCKED_DAMAGE
        self:Handle({kind='combat',result=result,sourceName=source,sourceType=sourceType,targetName=target,
            targetType=targetType,sourceUnitId=sourceId,targetUnitId=targetId,abilityId=abilityId,hitValue=value,
            sourceInInstance=sourceInInstance,isDamage=damageResult,
            isEnemyDeath=targetType==self.api.COMBAT_UNIT_TYPE_OTHER and (result==self.api.ACTION_RESULT_KILLING_BLOW
                or result==self.api.ACTION_RESULT_DIED or result==self.api.ACTION_RESULT_DIED_XP),
            isStartAbility=profile.startAbilityId~=nil and abilityId==profile.startAbilityId and result==self.api.ACTION_RESULT_EFFECT_GAINED})
    end
    -- Keep result-filtered boss deaths after the timer's start subscriptions are removed.
    for _,name in ipairs({'ACTION_RESULT_KILLING_BLOW','ACTION_RESULT_DIED','ACTION_RESULT_DIED_XP'}) do
        local result=self.api[name]
        if result then
            local filters={{self.api.REGISTER_FILTER_COMBAT_RESULT,result}}
            if self.api.REGISTER_FILTER_TARGET_COMBAT_UNIT_TYPE then
                filters[#filters+1]={self.api.REGISTER_FILTER_TARGET_COMBAT_UNIT_TYPE,self.api.COMBAT_UNIT_TYPE_OTHER}
            end
            self:Bind('EVENT_COMBAT_EVENT',combat,filters,'Death'..result)
        end
    end
    local snapshot=self.snapshot and self.snapshot() or {}
    if not (snapshot.clock or {}).startedAtMs and not (snapshot.clock or {}).stopped
        and (snapshot.lifecycle=='ready' or snapshot.lifecycle=='observing') then
        if K.Profiles.CanUseCombatStart(profile,snapshot) then
            if self.api.REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE then
                for _,sourceType in ipairs({self.api.COMBAT_UNIT_TYPE_PLAYER,self.api.COMBAT_UNIT_TYPE_GROUP}) do
                    self:Bind('EVENT_COMBAT_EVENT',combat,{{self.api.REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE,sourceType}},tostring(sourceType),true)
                end
            else self:Bind('EVENT_COMBAT_EVENT',combat,nil,'Start',true) end
        end
        if profile.startAbilityId then
            self:Bind('EVENT_COMBAT_EVENT',combat,{
                {self.api.REGISTER_FILTER_ABILITY_ID,profile.startAbilityId},
                {self.api.REGISTER_FILTER_COMBAT_RESULT,self.api.ACTION_RESULT_EFFECT_GAINED}},'StartAbility',true)
        end
    end
    self:Bind('EVENT_ZONE_CHANGED',function(_,_,_,_,_,subzoneId) self:Handle({kind='subzone',subzoneId=subzoneId}) end)
    self:SyncMembers()
    if self.api.IsUnitInCombat and self.api.IsUnitInCombat('player') then
        self:Handle({kind='combatState',inCombat=true})
    end
    self:ScanBosses('activate')
end
function Observer:ScanBosses(source,deathTag,isDead)
    if not self.context or not self.api.DoesUnitExist then return end
    local a=self.api;local units={}
    for i=1,(a.MAX_BOSSES or 6) do
        local tag='boss'..i
        if a.DoesUnitExist(tag) then
            local hp,maxHp=a.GetUnitPower(tag,a.POWERTYPE_HEALTH)
            local unit={tag=tag,name=a.GetUnitName(tag),health=hp,maxHealth=maxHp,
                inCombat=a.IsUnitInCombat and a.IsUnitInCombat(tag) or false,
                isDead=a.IsUnitDead(tag)}
            if tag==deathTag then unit.isDead=isDead end
            self.bossUnits[tag]=K.Copy(unit);units[#units+1]=unit
        elseif tag==deathTag and isDead==true and self.bossUnits[tag] then
            local unit=K.Copy(self.bossUnits[tag]);unit.isDead=true;unit.inCombat=false
            units[#units+1]=unit
        end
    end
    self:Handle({kind='bossSnapshot',units=units,source=source})
end
function Observer:StopStartObservation()
    for i=#self.registered,1,-1 do
        local entry=self.registered[i]
        if entry[3] then
            self.api.EVENT_MANAGER:UnregisterForEvent(entry[1],entry[2]);table.remove(self.registered,i)
        end
    end
end
function Observer:Deactivate()
    if self.api.EVENT_MANAGER then
        for _,entry in ipairs(self.registered) do self.api.EVENT_MANAGER:UnregisterForEvent(entry[1],entry[2]) end
    end
    self.registered={};self.context=nil;self.profile=nil;self.tags={};self.members={};self.bossUnits={};self.pulls={}
end
