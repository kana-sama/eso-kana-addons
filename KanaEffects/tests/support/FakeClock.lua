local FakeClock = {}
TestSupport.FakeClock = FakeClock
function FakeClock.New(now)
    return setmetatable({ time = now or 0 }, { __index = FakeClock })
end
function FakeClock:Now() return self.time end
function FakeClock:Set(now) self.time = now end
function FakeClock:Advance(seconds) self.time = self.time + seconds end
