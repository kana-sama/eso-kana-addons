local module, upstream = assert(arg[1]), assert(arg[2])
local function read(p) local f=assert(io.open(p)); local s=f:read('*a'); f:close(); return s end
local callback
EVENT_ADD_ON_LOADED=1
EVENT_MANAGER={RegisterForEvent=function(_,_,_,f) callback=f end,UnregisterForEvent=function() end}
function ZO_PostHook(object,name,hook)
    local original=object[name]
    object[name]=function(...) original(...); hook(...) end
end
BOTTOMLEFT=1; BOTTOMRIGHT=2
ZO_ChatWindow={}
local entry={anchors={}}
function entry:SetParent(p) self.parent=p end
function entry:ClearAnchors() self.anchors={} end
function entry:SetAnchor(point,relative) self.anchors[point]=relative end
function entry:SetMovable() end
function entry:SetHidden(v) self.hidden=v end
ZO_ChatWindowTextEntry=entry
local hideOfficial=false
local messenger={isOpen=false,window={IsHidden=function() return true end}}
local settings={Get=function(key,default) if key=='hideOfficialChat' then return hideOfficial end; return default end}
local source=read(upstream)
for _,name in ipairs({'DockNativeChatEntry','UndockNativeChatEntry'}) do
    local code=assert(source:match('(function Messenger%.'..name..'%b()%s.-)\nend'))..'\nend'
    assert(load(code,name,'t',setmetatable({Messenger=messenger,Settings=settings},{__index=_G})))()
end
AetherChat={Messenger=messenger}
-- Actual AetherChat initialization docks while isOpen=false.
messenger.DockNativeChatEntry()
assert(entry.parent==messenger.window)
dofile(module)
if callback then callback(nil,'KanaAetherChat') end
local function native()
    assert(entry.parent==ZO_ChatWindow and entry.anchors[BOTTOMLEFT]==ZO_ChatWindow,'stock chat anchor still points to AetherChat')
end
native(); assert(not entry.hidden); print('PASS startup restores stock input parent and anchors')
messenger.DockNativeChatEntry(); native(); print('PASS closed layout refresh cannot move native input')
messenger.isOpen=true; messenger.DockNativeChatEntry()
assert(entry.parent==messenger.window); print('PASS open AetherChat still docks input')
messenger.isOpen=false; messenger.UndockNativeChatEntry(); native(); print('PASS closing restores native input')
hideOfficial=true; messenger.DockNativeChatEntry(); native(); assert(entry.hidden)
print('PASS explicit hide-official-chat setting is respected')
