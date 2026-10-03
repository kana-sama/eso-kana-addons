-- Fixed deterministic workload through Sources' native ingestion boundary.
-- Synthetic adapter, Catalog, Store and History never touch live state or storage.
local Replay={}; Replay.__index=Replay; KanaEffects.Replay=Replay
local sequence=0
local function clone(t) local r={}; for k,v in pairs(t or {}) do r[k]=v end; return r end
local function invalidate(report,reason)
    report.status='incomplete'; report.reason=reason
    report.p50MS=nil; report.p95MS=nil; report.maxMS=nil
end
local function profile()
    local p={schemaVersion=1,widgets={},sets={},hidden={},longThreshold=60,editor={toolbarX=10,toolbarY=20}}
    for i=1,10 do
        local slots={}; for row=1,4 do slots[row]={}; for column=1,5 do slots[row][column]={kind='ability',id=1000000+(i-1)*20+(row-1)*5+column} end end
        p.widgets[i]={id='perf-'..i,name='Replay '..i,type='table',unitTag='player',
            layout={columns=5,rows=4,fixedAxis='columns',count=5,gap=4,absent='ghost',ghostAlpha=0.3},
            anchor={pointX=0,pointY=0,relativeTo='screen',relativePointX=0,relativePointY=0,x=20+((i-1)%2)*480,y=20+math.floor((i-1)/2)*230},
            style={mode='right',iconSize=32,timerFontSize=16,nameFontSize=16,rowWidth=160},slots=slots,
            rules={includeSets={},excludeSets={},named='any',mergePairs=true}}
    end
    return p
end
function Replay.New(deps)
    sequence=sequence+1; return setmetatable({deps=deps,owner='KanaEffectsReplay'..sequence,active=false},Replay)
end
function Replay:_Adapter()
    local native=self.deps.api; local constants=clone(native.constants); local callbacks={}
    local api={constants=constants,Now=native.Now,NormalizeName=native.NormalizeName,GetAPIVersion=native.GetAPIVersion,language=native.language,
        DoesAbilityExist=function() return true end,GetAbilityName=function(id) return 'Replay '..id end,
        GetAbilityIcon=function() return 'EsoUI/Art/Icons/icon_missing.dds' end,
        DoesUnitExist=function(tag) return tag=='player' end,GetUnitName=function() return 'Replay' end}
    api.eventManager={RegisterForEvent=function(_,owner,event,fn) callbacks[owner]={event=event,fn=fn} end,
        UnregisterForEvent=function(_,owner) callbacks[owner]=nil end,AddFilterForEvent=function() end}
    api.GetNumBuffs=function() return 200 end
    api.GetUnitBuffInfo=function(_,index) return 'Replay '..index,self.started,self.started+60,index,1,'EsoUI/Art/Icons/icon_missing.dds','',constants.BUFF_EFFECT_TYPE_BUFF,0,0,1000000+index,false,true end
    api.Emit=function(slot,ending)
        for _,c in pairs(callbacks) do if c.event==constants.EVENT_EFFECT_CHANGED then
            c.fn(constants.EVENT_EFFECT_CHANGED,constants.EFFECT_RESULT_UPDATED,slot,'Replay '..slot,'player',self.started,ending,1,'EsoUI/Art/Icons/icon_missing.dds','',constants.BUFF_EFFECT_TYPE_BUFF,0,0,'Replay',7,1000000+slot,constants.COMBAT_UNIT_TYPE_PLAYER)
        end end
    end
    return api
end
function Replay:_Cleanup()
    self.active=false; local errors={}
    local function attempt(fn) local ok,err=pcall(fn); if not ok then errors[#errors+1]=tostring(err) end end
    if self.registered then attempt(function() self.deps.api.eventManager:UnregisterForUpdate(self.owner) end); self.registered=false end
    if self.sources then attempt(function() self.sources:Stop() end) end
    if self.ownsPreview and not self.deps.runtime.disposed and self.deps.runtime.previewCatalog==self.catalog then attempt(function() self.deps.runtime:EndPreview() end) end
    self.ownsPreview=false
    if #errors>0 then error(table.concat(errors,'; ')) end
end
function Replay:_ReportComplete(report)
    if self.reportNotified then return end
    self.reportNotified=true
    if self.onComplete then pcall(self.onComplete,report) end
end
function Replay:Stop(reason)
    if not self.active and not self.ownsPreview then
        if reason and self.deps.diagnostics.processing and self.report==self.deps.diagnostics.LastReport then self.deps.diagnostics:EndCapture(reason) end
        return self.report
    end
    local elapsed=self.deps.api.Now()-self.started
    if not reason and (not self.burst or self.events<500) then reason='workload incomplete: delayed callbacks skipped changes or burst' end
    local report=self.deps.diagnostics:EndCapture(reason) or {status='not measured'}
    self.report=report
    report.workload={widgets=10,initialEffects=200,visibleRepresentations=200,changesPerSecond=50,burst=250,events=self.events or 0,elapsedSeconds=elapsed,complete=reason==nil}
    if reason then invalidate(report,reason) end
    local ok,err=pcall(function() self:_Cleanup() end)
    if not ok then
        -- Native driver is always released even if a provider restoration fails.
        self.active=false; self.deps.api.eventManager:UnregisterForUpdate(self.owner); self.registered=false
        invalidate(report,'cleanup failed: '..tostring(err))
    end
    if self.deps.bounds then report.boundsAfter=self.deps.bounds() end
    report.boundsBefore=self.boundsBefore
    if self.catalog then report.replayCache=self.catalog:GetCacheStats() end
    Replay.LastReport=report
    if self.completed or report.status~='processing' then self:_ReportComplete(report) end
    return report
end
function Replay:_Changes()
    for _=1,5 do
        self.sequence=self.sequence+1; local slot=(self.sequence*37-1)%200+1
        self.adapter.Emit(slot,self.started+60+(self.sequence%9)/10); self.events=self.events+1
    end
end
function Replay:_Tick()
    local ok,err=pcall(function()
        local deps=self.deps
        if deps.runtime.disposed or deps.editor and deps.editor:IsOpen() or deps.nativeHud and deps.nativeHud:IsEditing() then self:Stop('editor or application interruption'); return end
        if deps.isVisible and not deps.isVisible() then self:Stop('HUD visibility interruption'); return end
        if deps.runtime.previewCatalog~=self.catalog then self:Stop('preview ownership lost'); return end
        local elapsed=deps.api.Now()-self.started
        -- Never catch up an arbitrary delay: at most five changes per100ms callback.
        if elapsed>=5 then self:Stop(); return end
        if elapsed>=1 and not self.burst then
            self.burst=true
            for i=1,250 do self.adapter.Emit((i-1)%200+1,self.started+60+(i%9)/10); self.events=self.events+1 end
        end
        self:_Changes()
    end)
    if not ok then self:Stop('replay failed: '..tostring(err)) end
end
function Replay:Start(options)
    local deps=self.deps; options=clone(options or {}); if options.native then options.requireOwned=true end
    if self.disposed or self.active or deps.runtime.disposed or deps.runtime.preview or deps.editor and deps.editor:IsOpen() or deps.nativeHud and deps.nativeHud:IsEditing() or deps.isVisible and not deps.isVisible() then return false,'close the editor/preview before capture' end
    if deps.diagnostics.capture or deps.diagnostics.processing then return false,'capture/report already active' end
    self.onComplete=options.onComplete; self.reportNotified=false; self.completed=nil
    options.onComplete=function(report)
        self.completed=report
        if not self.active then self:_ReportComplete(report) end
    end
    local ok,reason=deps.diagnostics:BeginCapture('10 widgets / 200 representations / 50 changes per second / 250 burst',options)
    if not ok then return false,reason end
    self.boundsBefore=deps.bounds and deps.bounds() or nil
    self.started=deps.api.Now(); self.active=true; self.sequence=0; self.events=0; self.burst=false
    local success,err=pcall(function()
        self.adapter=self:_Adapter(); self.catalog=KanaEffects.Catalog.New(self.adapter,nil,deps.diagnostics)
        self.store=KanaEffects.Store.New(); self.history=KanaEffects.History.New()
        -- Mark at the ingestion boundary before Source's History notification.
        local upsert,replace=self.store.Upsert,self.store.ReplaceUnit
        self.store.Upsert=function(store,row) row.synthetic=true; return upsert(store,row) end
        self.store.ReplaceUnit=function(store,unit,rows) for _,row in ipairs(rows) do row.synthetic=true end; return replace(store,unit,rows) end
        self.sources=KanaEffects.Sources.New(self.adapter,self.catalog,self.store,self.history,deps.diagnostics)
        self.sources:Start({player=true}); self:_Changes()
        -- Preview mutates before its dependency callbacks can fail. Cleanup's
        -- catalog guard conditionally unwinds this attempt, preserving takeover.
        self.ownsPreview=true
        local valid,issues=deps.runtime:Preview(profile(),self.store,self.catalog)
        assert(valid,issues and issues[1] and issues[1].message or 'preview failed')
        deps.api.eventManager:RegisterForUpdate(self.owner,100,function() if self.active then self:_Tick() end end); self.registered=true
    end)
    if not success then self:Stop('replay start failed: '..tostring(err)); return false,tostring(err) end
    return true
end
function Replay:Dispose()
    if self.disposed then return end
    self:Stop('disposed'); self.disposed=true
end
