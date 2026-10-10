local K=KanaTrifecta
local Bootstrap={};Bootstrap.__index=Bootstrap;K.Bootstrap=Bootstrap
function Bootstrap.New(api)
    local self=setmetatable({api=api,generation=0,refreshToken=0},Bootstrap)
    self.diagnostics=K.Diagnostics.New(512)
    self.observer=K.Observer.New(api,function(event) self:Apply(event) end)
    self.observer.snapshot=function() return self.run and self.run:Snapshot() or {} end
    self.observer.recordEvidence=function(signal) self.diagnostics:RecordEvidence(signal) end
    return self
end
function Bootstrap:Apply(event)
    if not self.run or event.contextGeneration~=self.generation then return end
    if self.run:Apply(event) then
        self.diagnostics:Record(event)
        if event.kind=='RunStarted' then self.observer:StopStartObservation() end
        self:UpdateView()
    end
end
function Bootstrap:Later(fn,delay)
    (self.api.CallLater or self.api.zo_callLater)(fn,delay)
end
function Bootstrap:RefreshContext()
    self.refreshToken=self.refreshToken+1
    local token,first=self.refreshToken,self.observer:ReadContext()
    self:Later(function()
        if token~=self.refreshToken then return end
        local current=self.observer:ReadContext()
        if current.zoneId~=first.zoneId or current.difficulty~=first.difficulty then self:RefreshContext();return end
        local profile=K.Profiles:Find(current.zoneId,current.difficulty)
        if not profile then
            if self.run then
                self.run:Apply({kind='ContextLeft',contextGeneration=self.generation,payload={}})
                self:Save()
            end
            self.observer:Deactivate();self.context=nil
            if self.api.EVENT_MANAGER then self.api.EVENT_MANAGER:UnregisterForUpdate('KanaTrifectaHud') end
            self:UpdateView();return
        end
        if self.context and self.context.profileKey==profile.key then self.observer:SyncMembers();return end
        self.generation=self.generation+1
        current.contextGeneration=self.generation;current.profileKey=profile.key
        current.runKey=profile.key..':'..self.api.GetTimeStamp()..':'..self.generation
        local exit=self.exitContext
        local fresh=exit and self.api.GetGameTimeMilliseconds()-exit.atMs<60000 and exit.zoneId~=current.zoneId
        local memberCount=0
        for key,member in pairs(current.members or {}) do
            memberCount=memberCount+1
            local before=exit and exit.members and exit.members[key]
            if not before or before.zoneId==current.zoneId or member.inCombat then fresh=false end
        end
        current.freshEntry=fresh and memberCount>0 or false
        current.freshness=K.Profiles:ClassifyContext(profile,self.run and self.run:Snapshot() or (self.saved and self.saved.active),current)
        local marker=self.saved and self.saved.reloadMarker
        if marker then
            self.saved.reloadMarker=nil
            local same=marker.zoneId==current.zoneId and marker.profileKey==profile.key
                and self.api.GetTimeStamp()-marker.wallSec>=0 and self.api.GetTimeStamp()-marker.wallSec<60
            for key in pairs(current.members or {}) do if not marker.members[key] then same=false end end
            for key in pairs(marker.members or {}) do if not current.members[key] then same=false end end
            if same then current.freshness='same' end
        end
        current.language=current.language=='ru' and 'ru' or 'en'
        if self.api.GetZoneNameById then
            local name=self.api.GetZoneNameById(current.zoneId)
            if name and name~='' then profile.name[current.language]=K.CleanName(name) end
        end
        self.context=current
        self.run=K.Run.New(profile,current)
        if K.State and self.saved and self.saved.active then
            local restored=K.State:Restore(self.saved.active,profile,current,self:Clocks())
            if restored then self.run=restored end
        end
        self.observer:Activate(profile,current)
        if self.api.EVENT_MANAGER then
            self.api.EVENT_MANAGER:RegisterForUpdate('KanaTrifectaHud',250,function() self:UpdateView() end)
        end
        if self.achievements then
            local available,reason=self.achievements:Availability(profile)
            self.hud:SetAchievementsAvailable(available,reason)
        end
        self:UpdateView()
    end,250)
end
function Bootstrap:Clocks()
    return {nowMs=self.api.GetGameTimeMilliseconds(),nowWallSec=self.api.GetTimeStamp(),monotonicContinuous=false}
end
function Bootstrap:Save()
    if self.saved and self.run then
        self.saved.active=K.State and K.State:Save(self.run,self:Clocks()) or self.run:Snapshot()
    end
end
function Bootstrap:UpdateView()
    if not self.hud then return end
    local visible=self.context~=nil and self.run~=nil and not (self.api.IsInGamepadPreferredMode and self.api.IsInGamepadPreferredMode())
    self.hud:SetVisible(visible)
    if visible and not self.hud.root:IsHidden() then
        self.hud:Render(self.run:View(self.api.GetGameTimeMilliseconds()))
    end
end
function Bootstrap:Initialize()
    self.saved=self.api.ZO_SavedVars:NewAccountWide('KanaTrifectaState',1,nil,{})
    K.Settings.Initialize(self)
    if K.Achievements then
        self.achievements=K.Achievements.New(self.api,function() return self.context end)
    end
    if K.Hud then
        self.hud=K.Hud.New(self.api,function()
            if self.achievements and self.context then self.achievements:Open(self.run.profile,self.generation) end
        end,self.settings)
    end
    local em=self.api.EVENT_MANAGER
    for _,event in ipairs({'EVENT_PLAYER_ACTIVATED','EVENT_ZONE_CHANGED'}) do
        if self.api[event] then em:RegisterForEvent('KanaTrifecta_'..event,self.api[event],function() self:RefreshContext() end) end
    end
    if self.api.EVENT_PLAYER_DEACTIVATED then em:RegisterForEvent('KanaTrifectaSave',self.api.EVENT_PLAYER_DEACTIVATED,function()
        self.exitContext=self.observer:ReadContext();self.exitContext.atMs=self.api.GetGameTimeMilliseconds()
        if self.run then self.run:Apply({kind='ContextLeft',contextGeneration=self.generation,payload={}}) end
        self:Save();self.context=nil;self.observer:Deactivate()
        em:UnregisterForUpdate('KanaTrifectaHud');self:UpdateView()
    end) end
    if self.api.EVENT_ACHIEVEMENT_AWARDED then
        em:RegisterForEvent('KanaTrifectaAward',self.api.EVENT_ACHIEVEMENT_AWARDED,function(_,_,_,id)
            self.observer:Emit('AchievementAwarded',{id=id},nil,{source='achievementAwarded'})
        end)
    end
    if self.api.ZO_PreHook then
        self.api.ZO_PreHook('ReloadUI',function()
            self:Save()
            if self.context then self.saved.reloadMarker={zoneId=self.context.zoneId,profileKey=self.context.profileKey,
                wallSec=self.api.GetTimeStamp(),members=K.Copy(self.observer:ReadRoster())} end
        end)
    end
    self.api.SLASH_COMMANDS['/ktri']=function(command)
        if command=='bosstimes on' or command=='bosstimes off' then
            K.Settings.SetBossKillTimes(self,command=='bosstimes on');return
        elseif command=='settings' and self.settingsPanel then
            self.api.LibAddonMenu2:OpenToPanel(self.settingsPanel);return
        elseif command=='debug on' then self.diagnostics:SetEnabled(true)
        elseif command=='debug off' then self.diagnostics:SetEnabled(false)
        elseif command=='dump' then self.saved.dump=self.diagnostics:Dump(self.run and self.run:Snapshot() or {}) end
        self.api.d(self.diagnostics:Status(self.run and self.run:Snapshot() or {}))
        if command=='status' or command=='' then
            local current=self.observer:ReadContext()
            local manager=self.api.SCENE_MANAGER
            local scene=manager and manager:GetCurrentScene()
            local gamepad=self.api.IsInGamepadPreferredMode and self.api.IsInGamepadPreferredMode() or false
            self.api.d(string.format('zone=%s; difficulty=%s; gamepad=%s; scene=%s',
                tostring(current.zoneId),tostring(current.difficulty),tostring(gamepad),scene and scene:GetName() or '?'))
            if self.hud then self.api.d(self.hud:Status()) end
        end
    end
    self:RefreshContext()
end
if EVENT_MANAGER and EVENT_ADD_ON_LOADED then
    EVENT_MANAGER:RegisterForEvent('KanaTrifectaLoad',EVENT_ADD_ON_LOADED,function(_,name)
        if name~='KanaTrifecta' then return end
        EVENT_MANAGER:UnregisterForEvent('KanaTrifectaLoad',EVENT_ADD_ON_LOADED)
        K.instance=Bootstrap.New(_G);K.instance:Initialize()
    end)
end
