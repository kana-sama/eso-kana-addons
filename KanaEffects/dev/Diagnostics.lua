-- Opt-in counters and bounded native nanosecond capture. No clocks imply FPS results.
local Diagnostics={}; Diagnostics.__index=Diagnostics; KanaEffects.Diagnostics=Diagnostics
local sequence=0
local function copy(t) local r={}; for k,v in pairs(t or {}) do r[k]=v end; return r end
local function count(t) local n=0; for _ in pairs(t) do n=n+1 end; return n end
local function limit(n,default,maximum) if type(n)~='number' or n~=n then return default end; return math.max(1,math.min(maximum,math.floor(n))) end
local function own(file)
    if type(file)~='string' then return false end
    local addonPath='AddOns/eso-kana-addons/KanaEffects/'
    file=string.gsub(file,'\\','/')
    return string.find(file,'/'..addonPath,1,true)~=nil or string.sub(file,1,#addonPath)==addonPath
end
local function union(intervals)
    table.sort(intervals,function(a,b) return a[1]<b[1] end)
    local total,first,last=0
    for _,span in ipairs(intervals) do
        if not last then first,last=span[1],span[2]
        elseif span[1]<=last then last=math.max(last,span[2])
        else total=total+last-first; first,last=span[1],span[2] end
    end
    return total+(last and last-first or 0)
end
function Diagnostics.New(api)
    sequence=sequence+1
    return setmetatable({api=api,owner='KanaEffectsProfiler'..sequence},Diagnostics)
end
function Diagnostics:Count(name,amount)
    local capture=self.capture
    if not capture then return end
    amount=amount or 1; capture.counters[name]=(capture.counters[name] or 0)+amount
end
function Diagnostics:_Unregister()
    if self.registered then self.api.eventManager:UnregisterForUpdate(self.owner); self.registered=false end
end
function Diagnostics:_Publish(report)
    self.LastReport=report; Diagnostics.LastReport=report
    if report.status~='processing' and self.onComplete then local fn=self.onComplete; self.onComplete=nil; pcall(fn,report) end
end
function Diagnostics:_Finish(status,reason)
    self:_Unregister(); local job=self.processing; self.processing=nil
    if not job then return end
    local report=job.report
    if report.status=='incomplete' then status='incomplete'; reason=report.reason end
    if status=='measured' and job.requireOwned and job.ownedRecords==0 then status='incomplete'; reason='owned source attribution unconfirmed for nonidle workload' end
    report.ownedRecords=job.ownedRecords
    report.status=status; report.reason=reason; report.recordsProcessed=job.records
    report.closuresCached=count(job.closures); report.processingSeconds=self.api.Now()-job.started
    if status=='measured' then
        table.sort(job.times); local n=#job.times
        report.frames=n; report.p50MS=job.times[math.ceil(n*0.5)]/1000000; report.p95MS=job.times[math.ceil(n*0.95)]/1000000; report.maxMS=job.times[n]/1000000
    end
    self:_Publish(report)
end
function Diagnostics:_Process()
    local job=self.processing; if not job then return end
    if self.api.IsScriptProfilerEnabled() then self:_Finish('incomplete','another profiler is active during report processing'); return end
    if self.api.Now()-job.started>=10 then self:_Finish('incomplete','processing deadline'); return end
    local processed=0
    while self.processing and processed<job.chunk do
        if job.frame>job.frameCount then self:_Finish('measured'); return end
        if not job.frameRecords then
            job.frameRecords=self.api.GetScriptProfilerFrameNumRecords(job.frame)
            if type(job.frameRecords)~='number' or job.frameRecords<0 or job.frameRecords%1~=0 then self:_Finish('incomplete','invalid frame record count'); return end
            job.index=1; job.intervals={}
        end
        if job.index>job.frameRecords then
            job.times[#job.times+1]=union(job.intervals); job.frame=job.frame+1; job.frameRecords=nil
            -- Empty frames count toward the per-update work limit as well.
            processed=processed+1
        else
            if job.records>=job.maxRecords then self:_Finish('incomplete','record safety cap'); return end
            local id,startNS,endNS,caller,kind=self.api.GetScriptProfilerRecordInfo(job.frame,job.index)
            job.index=job.index+1; job.records=job.records+1; processed=processed+1
            if kind==self.api.constants.SCRIPT_PROFILER_RECORD_DATA_TYPE_CLOSURE then
                local owned=job.closures[id]
                if owned==nil then
                    if job.closureCount>=4096 then self:_Finish('incomplete','closure safety cap'); return end
                    local _,file=self.api.GetScriptProfilerClosureInfo(id)
                    owned=own(file); job.closures[id]=owned; job.closureCount=job.closureCount+1
                end
                if owned then
                    job.ownedRecords=job.ownedRecords+1
                    if type(startNS)~='number' or type(endNS)~='number' or startNS~=startNS or endNS~=endNS or math.abs(startNS)==math.huge or math.abs(endNS)==math.huge or endNS<startNS then self:_Finish('incomplete','invalid nanosecond record'); return end
                    if #job.intervals>=2000 then self:_Finish('incomplete','owned intervals per frame safety cap'); return end
                    job.intervals[#job.intervals+1]={startNS,endNS}
                end
            end
        end
    end
end
function Diagnostics:_Tick()
    local ok,err=pcall(function()
        if self.capture and self.capture.native then
            if not self.api.IsScriptProfilerEnabled() then
                -- Ownership is lost: never stop a later profiler on disposal.
                self.capture.owns=false; self:EndCapture('profiler ownership lost')
            elseif self.api.Now()-self.capture.started>=self.capture.duration then self:EndCapture() end
        elseif self.processing then self:_Process() end
    end)
    if not ok then
        if self.capture then self:EndCapture('capture error: '..tostring(err)) end
        if self.processing then self:_Finish('incomplete','processing error: '..tostring(err)) end
    end
end
function Diagnostics:BeginCapture(label,options)
    if self.disposed or self.capture or self.processing then return false,'capture unavailable or already active' end
    options=options or {}; local api=self.api
    if options.native then
        for _,name in ipairs({'Now','StartScriptProfiler','StopScriptProfiler','IsScriptProfilerEnabled','GetScriptProfilerNumFrames','GetScriptProfilerFrameNumRecords','GetScriptProfilerRecordInfo','GetScriptProfilerClosureInfo'}) do
            if not api or type(api[name])~='function' then return false,'native profiler unavailable: '..name end
        end
        if not api.eventManager or not api.constants or api.constants.SCRIPT_PROFILER_RECORD_DATA_TYPE_CLOSURE==nil then return false,'native profiler update/constants unavailable' end
        if api.IsScriptProfilerEnabled() then return false,'another profiler is already active' end
    end
    self.onComplete=options.onComplete
    self.capture={label=label or 'capture',counters={},native=options.native==true,started=api and api.Now and api.Now() or 0,
        duration=math.min(5,limit(options.duration,5,5)),chunk=limit(options.recordsPerUpdate,1000,1000),maxRecords=limit(options.maxRecords,250000,250000),maxFrames=limit(options.maxFrames,1200,1200),requireOwned=options.requireOwned==true}
    if options.native then
        local ok,err=pcall(function()
            self.capture.owns=true; api.StartScriptProfiler()
            api.eventManager:RegisterForUpdate(self.owner,0,function() self:_Tick() end); self.registered=true
        end)
        if not ok then self:EndCapture('start error: '..tostring(err)); return false,'native capture failed' end
    end
    return true
end
function Diagnostics:EndCapture(reason)
    local capture=self.capture; if not capture then
        if reason and self.processing then self:_Finish('incomplete',reason) end
        return self.LastReport
    end
    self.capture=nil; self:_Unregister()
    local report={label=capture.label,counters=copy(capture.counters),status='not measured',reason=reason or 'counter-only capture',
        durationSeconds=self.api and self.api.Now and self.api.Now()-capture.started or nil,
        attribution='union of owned Lua closure inclusive nanosecond intervals per frame; native descendants included once',
        overhead='native profiler and capture/replay instrumentation included; report processing excluded; overhead not separately measured'}
    if not capture.native then self:_Publish(report); return report end
    local api=self.api
    if capture.owns and api.IsScriptProfilerEnabled() then
        local ok,err=pcall(api.StopScriptProfiler)
        if not ok then report.status='incomplete'; report.reason='stop failed: '..tostring(err); self:_Publish(report); return report end
    else reason=reason or 'profiler ownership lost' end
    if reason then report.status='incomplete'; report.reason=reason; self:_Publish(report); return report end
    local ok,frames=pcall(api.GetScriptProfilerNumFrames)
    if not ok or type(frames)~='number' or frames<1 or frames%1~=0 or frames>capture.maxFrames then report.status='incomplete'; report.reason='frame safety cap or unavailable frames'; self:_Publish(report); return report end
    report.status='processing'; report.reason=nil
    self.processing={report=report,started=api.Now(),frame=1,frameCount=frames,records=0,closureCount=0,closures={},times={},ownedRecords=0,requireOwned=capture.requireOwned,chunk=capture.chunk,maxRecords=capture.maxRecords}
    api.eventManager:RegisterForUpdate(self.owner,0,function() self:_Tick() end); self.registered=true
    self:_Publish(report); return report
end
function Diagnostics:Dispose()
    if self.disposed then return end
    if self.capture then self:EndCapture('disposed') end
    if self.processing then self:_Finish('incomplete','disposed') end
    self:_Unregister(); self.disposed=true
end
