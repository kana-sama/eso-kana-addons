-- Retains real Store DTOs before reticleover loss; never reads native units.
local TargetView={}; TargetView.__index=TargetView; KanaEffects.TargetView=TargetView
local function copy(v) if type(v)~='table' then return v end; local r={}; for k,x in pairs(v) do r[k]=copy(x) end; return r end
function TargetView.New(store,clock)
    local self=setmetatable({store=store,clock=clock,listeners={},sequence=0},TargetView)
    self:_Observe()
    self.unsubscribe=store:Subscribe(function(change)
        if self.disposed then return end
        if change.unitIdentityChanged.reticleover then self:_Observe() else
            for key in pairs(change.units) do if string.match(key,'^reticleover:') then self:_Observe(); break end end
        end
    end)
    return self
end
function TargetView:_Observe()
    local now=self.clock:Now(); local snapshot=self.store:Snapshot('reticleover',now)
    if snapshot.unit and snapshot.unit.name~='' then
        snapshot.observedAt=now; snapshot.title=snapshot.unit.name; self.last=copy(snapshot)
    end
end
function TargetView:_Notify()
    local list={}; for id,fn in pairs(self.listeners) do list[id]=fn end
    for id,fn in pairs(list) do if not self.disposed and self.listeners[id]==fn then fn() end end
end
function TargetView:Capture()
    if self.disposed or not self.last then return nil end
    self.snapshot=copy(self.last); self.snapshot.openedAt=self.clock:Now(); self.snapshot.capturedAt=self.snapshot.observedAt
    self:_Notify(); return self:GetSnapshot()
end
function TargetView:GetSnapshot() return copy(self.snapshot) end
function TargetView:DisplayTime() return self.snapshot and self.snapshot.observedAt end
function TargetView:Provider()
    if not self.snapshot then return self.store end
    local captured=copy(self.snapshot)
    return {Snapshot=function(_,tag) assert(tag=='reticleover','target provider scope'); return copy(captured) end}
end
function TargetView:ResumeLive() if self.disposed then return end; self.snapshot=nil; self:_Notify() end
function TargetView:Subscribe(callback)
    if self.disposed then return function() end end
    self.sequence=self.sequence+1; local id=self.sequence; self.listeners[id]=callback
    return function() self.listeners[id]=nil end
end
function TargetView:Dispose() if self.disposed then return end; self.disposed=true; self.unsubscribe(); self.listeners={}; self.snapshot=nil; self.last=nil end
