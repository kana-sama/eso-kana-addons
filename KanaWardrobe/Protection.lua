local KW=KanaWardrobe
local Protection={}; KW.Protection=Protection
local Instance={}; Instance.__index=Instance
function Protection.New(repo,inventory)
    return setmetatable({repo=repo,inventory=inventory,records={},reported={},notify=function() end},Instance)
end
function Instance:Explain(uid) return self.repo:Memberships(uid,"all") end
function Instance:Report(problem)
    local uid=problem.details.uid or ""
    local key=problem.code..":"..uid
    if not self.reported[key] then self.reported[key]=true; self.notify(problem) end
end
function Instance:Check(uid,location)
    location=location or self.inventory:Resolve(uid,false,false)
    if not location then return nil,KW.Problem("itemMissing",{uid=uid}) end
    if self.inventory:IsLocked(location) then return location end
    local record=self.records[uid]
    if record and record.blocked then return nil,KW.Problem(record.blocked,{uid=uid}) end
    if not self.inventory:CanLock(location) then return nil,KW.Problem("cannotLock",{uid=uid}) end
    return location
end
function Instance:Lock(uid,knownLocation)
    local location,problem=self:Check(uid,knownLocation)
    if not location then return false,problem end
    local record=self.records[uid] or {observed=false,recoveries=0}
    self.records[uid]=record
    if self.inventory:IsLocked(location) then record.observed=true; return true end
    if record.observed then
        if record.recoveries>=1 then
            record.blocked="lockConflict"
            return false,KW.Problem("lockConflict",{uid=uid})
        end
        record.recoveries=record.recoveries+1
        self:Report(KW.Problem("lockConflict",{uid=uid}))
    end
    -- Reserve the attempt before making the request: native events or other
    -- addons can synchronously cause another inventory refresh.
    if record.pending then return false,KW.Problem("lockPending",{uid=uid}) end
    record.pending=true
    local ok,result=pcall(self.inventory.SetLocked,self.inventory,location,true)
    record.pending=false
    local current=self.inventory:Resolve(uid,false,false)
    if not ok or not result or not current or not self.inventory:IsLocked(current) then
        record.blocked="lockFailed"
        return false,KW.Problem("lockFailed",{uid=uid})
    end
    record.observed=true
    return true
end
function Instance:Ensure(slots)
    local uids,seen={},{}
    for _,value in pairs(slots or {}) do
        if value.kind=="item" and not seen[value.uid] then
            seen[value.uid]=true; uids[#uids+1]=value.uid
        end
    end
    table.sort(uids)
    -- An explicit Save attempt may retry a failed initial request. Automatic
    -- inventory events never reset this limit or a detected external conflict.
    for _,uid in ipairs(uids) do
        local record=self.records[uid]
        if record and record.blocked=="lockFailed" and not record.observed then record.blocked=nil end
    end
    -- Reject inaccessible/unlockable instances before changing any flags.
    for _,uid in ipairs(uids) do
        local location,problem=self:Check(uid)
        if not location then return false,problem end
    end
    for _,uid in ipairs(uids) do
        local ok,problem=self:Lock(uid)
        if not ok then return false,problem end
    end
    return true
end
function Instance:EnsureBuild(build)
    return self:Ensure(KW.BuildModel.Equipment(build))
end
function Instance:RefreshAccessible()
    if self.refreshing then return true end
    self.refreshing=true
    local firstProblem
    local ok,err=pcall(function()
        local state=self.inventory:Capture(false)
        for uid,location in pairs(state.byUid) do
            if #self:Explain(uid)>0 then
                local locked,problem=self:Lock(uid,location)
                if not locked then firstProblem=firstProblem or problem; self:Report(problem) end
            end
        end
    end)
    self.refreshing=false
    if not ok then error(err,0) end
    return firstProblem==nil,firstProblem
end
-- Do not intercept native item-action discovery or callbacks: it feeds
-- protected actions such as UseItem. Maintain locks through inventory events.
function Instance:Attach(events,onProblem)
    if self.events then
        for _,handle in ipairs(self.handles) do self.events:Unsubscribe(handle) end
    end
    self.events=events; self.notify=onProblem or self.notify
    self.handles={}
    for _,name in ipairs({"PresetsChanged","InventoryChanged"}) do
        self.handles[#self.handles+1]=events:Subscribe(name,function() self:RefreshAccessible() end)
    end
    return self:RefreshAccessible()
end
