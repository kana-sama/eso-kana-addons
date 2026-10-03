unpack = unpack or table.unpack
zo_strlen=string.len; zo_floor=math.floor; zo_min=math.min
CHATTER_START_BANK=1; CHATTER_START_SHOP=2; CHATTER_START_STABLE=3; CHATTER_START_TRADINGHOUSE=4
EVENT_ADD_ON_LOADED=1; EVENT_CHATTER_END=2
local now=100; local name='Мирри'; local hidden=false; local selected=0; local rendered={}; local updates={}; local events={}; local saved={}
function GetFrameTimeMilliseconds() return now end
function GetUnitName() return name end
function GetCVar() return 'ru' end
function zo_strformat(_, s) return s end
function d() end
SLASH_COMMANDS={}
ZO_SavedVars={New=function(_,key,version,namespace,defaults) local id=key..namespace; saved[id]=saved[id] or defaults; return saved[id] end, NewAccountWide=function(_,key,version,namespace,defaults) local id=key..namespace; saved[id]=saved[id] or defaults; return saved[id] end}
EVENT_MANAGER={RegisterForUpdate=function(_,key,_,fn) updates[key]=fn end,UnregisterForUpdate=function(_,key) updates[key]=nil end,RegisterForEvent=function(_,key,event,fn) events[event]=fn end,UnregisterForEvent=function() end}
ZO_InteractWindow={IsHidden=function() return hidden end}
local label={text=''}
function label:SetText(s) self.text=s end
function label:GetText() return self.text end
function label:GetTextHeight() return 20 end
function label:GetColor() return 1,1,1 end
ZO_InteractWindowTargetAreaBodyText=label
ZO_InteractWindowTargetAreaTitle={SetMouseEnabled=function() end,SetHandler=function() end}
INTERACTION={PopulateChatterOption=function(_,id,callback,text,kind) rendered[id]={callback=callback,text=text} end,ShowQuestRewards=function() return 'reward' end,SelectChatterOptionByIndex=function(_,id) if rendered[id] then selected=selected+1 end end}
INTERACT_WINDOW={SelectChatterOptionByIndex=function(_,id) INTERACTION:SelectChatterOptionByIndex(id) end}
function ZO_PreHook(object,key,fn) local old=object[key]; object[key]=function(...) if not fn(...) then return old(...) end end end
LibAddonMenu2={RegisterAddonPanel=function() end,RegisterOptionControls=function() end}
dofile(SOURCE)
local addon=KanaSlowAddonGlobal or SlowDialogsGlobal
addon.InitOptions=function() end
addon.OnAddonLoaded(nil,KanaSlowAddonGlobal and 'KanaSlowAddon' or 'SlowDialogs')
local function begin(text,kind)
 rendered={}; label:SetText(text); INTERACTION:PopulateChatterOption(1,function() end,'Ответ',kind or 99)
end
if CASE=='toggle' then
 begin('Реплика')
 assert(type(SLASH_COMMANDS['/kslow'])=='function','missing no-argument toggle command')
 SLASH_COMMANDS['/kslow'](); assert(label.text=='Реплика','toggle must reveal current text')
 begin('Следующая'); assert(label.text=='Следующая' and rendered[1],'remembered NPC must bypass delay')
 addon.OnAddonLoaded(nil,'KanaSlowAddon'); begin('После загрузки'); assert(label.text=='После загрузки','saved preference lost')
 SLASH_COMMANDS['/kslow'](); begin('Медленно'); assert(label.text~='Медленно','second toggle must restore slow text')
 name='Доска объявлений'; begin('Объявление'); SLASH_COMMANDS['/kslow'](); begin('Задание'); assert(label.text=='Задание','board name not remembered')
 hidden=true; name='Другой'; SLASH_COMMANDS['/kslow'](); hidden=false; begin('Другой текст'); assert(label.text~='Другой текст','outside dialogue must not toggle')
elseif CASE=='action' then
 begin('Полная реплика')
 INTERACT_WINDOW:SelectChatterOptionByIndex(1)
 assert(label.text=='Полная реплика','action must finish current text immediately')
 assert(selected==0,'finishing text must not select an answer')
 INTERACT_WINDOW:SelectChatterOptionByIndex(1); assert(selected==1,'next action should select normally')
elseif CASE=='service' then
 begin('Магазин',CHATTER_START_SHOP); assert(label.text=='Магазин' and rendered[1],'shop must render immediately')
 INTERACTION:PopulateChatterOption(2,function() end,'Пока',99); assert(rendered[2],'later options must not remain queued')
elseif CASE=='close' then
 begin('Старая реплика'); if events[EVENT_CHATTER_END] then events[EVENT_CHATTER_END]() end
 assert(next(updates)==nil,'closed dialogue must cancel pending animation')
elseif CASE=='natural' then
 begin('Обычная реплика'); assert(label.text~='Обычная реплика' and not rendered[1])
 now=100000; for _,fn in pairs(updates) do fn() end
 assert(label.text=='Обычная реплика' and rendered[1] and next(updates)==nil,'natural completion must flush once')
end
