-- Engine text-buffer behavior is simulated; rendering still needs an ESO check.
local addon = assert(arg[1])
local callback
EVENT_ADD_ON_LOADED = 1
EVENT_MANAGER = {
    RegisterForEvent=function(_,_,_,fn) callback=fn end,
    UnregisterForEvent=function() end,
}
dofile('/tmp/esoui-live/esoui/libraries/utility/zo_hook.lua')
local buffer={position=0, rows=100, maxRows=100}
function buffer:GetScrollPosition() return self.position end
function buffer:SetScrollPosition(n) self.position=n end
function buffer:Clear() self.rows=0; self.position=0 end
function buffer:AddMessage(lines)
    -- Native text buffers track the viewed lines while appending, including
    -- wrapped messages and eviction at the history limit.
    if self.position>0 then self.position=math.min(self.rows-1,self.position+lines) end
    self.rows=math.min(self.maxRows,self.rows+lines)
end
local function append(lines)
    buffer:AddMessage(lines)
    buffer:SetScrollPosition(0)
end
local messenger={window={GetNamedChild=function(_,name) if name=='Messages' then return buffer end end}}
messenger.OnMessageReceived=function(lines, switchChannel)
    if switchChannel then buffer:Clear() end
    append(lines)
end
messenger.OnFriendPlayerStatusChanged=append
messenger.OnGuildMemberPlayerStatusChanged=append
AetherChat={Messenger=messenger}
dofile(addon)
if callback then callback(nil,'KanaAetherChat') end
local function check(name, start, fn, expected)
    buffer.position=start; buffer.rows=100
    fn()
    assert(buffer.position==expected,name..': got '..buffer.position..', expected '..expected)
    print('PASS '..name)
end
check('follows new messages at bottom',0,function() messenger.OnMessageReceived(3) end,0)
check('keeps viewed lines with wrapped message and full history',12,function() messenger.OnMessageReceived(3) end,15)
check('multiple arrivals preserve view',12,function() messenger.OnMessageReceived(2); messenger.OnMessageReceived(4) end,18)
check('friend notification preserves view',9,function() messenger.OnFriendPlayerStatusChanged(1) end,10)
check('guild notification preserves view',9,function() messenger.OnGuildMemberPlayerStatusChanged(2) end,11)
check('channel switch resets view',12,function() messenger.OnMessageReceived(3,true) end,0)
check('manual scroll to bottom still works',12,function() messenger.OnMessageReceived(1); buffer:SetScrollPosition(0) end,0)
check('returns to following after manual scroll',12,function() messenger.OnMessageReceived(1); buffer:SetScrollPosition(0); messenger.OnMessageReceived(2) end,0)
