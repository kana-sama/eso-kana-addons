local module = assert(arg[1])
local saved={}
EVENT_ADD_ON_LOADED=1; EVENT_PLAYER_ACTIVATED=2
ZO_SavedVars={NewCharacterIdSettings=function() return saved end}
function ZO_PostHook(o,n,h) local f=o[n]; o[n]=function(...) f(...); h(...) end end
local function session(items,guilds)
    local events={}
    EVENT_MANAGER={RegisterForEvent=function(_,n,e,f) events[e]=f end,UnregisterForEvent=function(_,n,e) events[e]=nil end}
    GetNumGuilds=function() return #guilds end
    GetGuildId=function(slot) return guilds[slot] end
    local active='zone'
    local m={BuildChannelItems=function() return items end,GetActiveChannel=function() return active end,
        SelectChannel=function(key,update,focus) active=key; assert(not focus,'unexpected focus') end}
    AetherChat={Messenger=m}
    dofile(module); events[1](nil,'KanaAetherChat')
    -- A startup selection must not clobber persisted state.
    m.SelectChannel('zone',false,false)
    events[2]()
    return m
end
local items={{id='zone'},{id='party'},{id='guild1'},{id='guild2'},{id='custom_test'}}
local m=session(items,{101,202}); m.SelectChannel('custom_test',true,false)
m=session(items,{101,202}); assert(m.GetActiveChannel()=='custom_test'); print('PASS custom tab survives reload and startup selection')
m.SelectChannel('guild1',true,false)
m=session(items,{202,101}); assert(m.GetActiveChannel()=='guild2'); print('PASS guild identity survives slot reorder')
m.SelectChannel('custom_test',true,false)
m=session({{id='zone'}},{}); assert(m.GetActiveChannel()=='zone'); print('PASS removed tab falls back to default')
m.SelectChannel('party',true,false)
m=session(items,{}); assert(m.GetActiveChannel()=='party'); print('PASS last channel selection is saved')
