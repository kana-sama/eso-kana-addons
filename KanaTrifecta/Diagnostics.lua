local K=KanaTrifecta
local Diagnostics={};Diagnostics.__index=Diagnostics;K.Diagnostics=Diagnostics
function Diagnostics.New(capacity)
    return setmetatable({capacity=capacity or 512,events={},next=1,count=0,enabled=false},Diagnostics)
end
function Diagnostics:SetEnabled(enabled) self.enabled=enabled end
function Diagnostics:Record(event)
    if not self.enabled then return end
    self.events[self.next]=K.Copy(event)
    self.next=self.next%self.capacity+1;self.count=math.min(self.count+1,self.capacity)
end
function Diagnostics:RecordEvidence(signal)
    self:Record({kind='Evidence',key=signal.kind,atMs=signal.atMs,
        contextGeneration=signal.contextGeneration,evidence=signal})
end
function Diagnostics:Dump(snapshot)
    local events={}
    local first=self.count==self.capacity and self.next or 1
    for offset=0,self.count-1 do events[#events+1]=K.Copy(self.events[(first+offset-1)%self.capacity+1]) end
    return {events=events,snapshot=K.Copy(snapshot),apiVersion=GetAPIVersion and GetAPIVersion() or nil}
end
function Diagnostics:Status(snapshot)
    return string.format('KanaTrifecta: %s; profile=%s; deaths=%s; debug=%s',
        snapshot.lifecycle or 'outside',snapshot.profileKey or '-',snapshot.deathCount or '?',tostring(self.enabled))
end
