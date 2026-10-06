return function()
    local api={CT_CONTROL=1,CT_LABEL=2,CT_SCROLL=3,TOPLEFT=1,TOPRIGHT=2,CENTER=3,TEXT_ALIGN_RIGHT=2,SCROLL_BOUNDING_CONTAINED=1};local created={}
    local C={};C.__index=C
    function C:SetHidden(v)self.hidden=v end
    function C:SetScale(v)self.scale=v end
    function C:SetDimensions(w,h)self.width=w;self.height=h end
    function C:GetWidth()return self.width or 416 end
    function C:GetHeight()return self.height or 100 end
    function C:SetText(v)self.text=v end
    function C:GetTextHeight()local _,length=(self.text or ''):gsub('[\128-\191]','');return math.max(18,math.ceil((#(self.text or '')-length)*8/math.max(1,self.width or 400))*18) end
    function C:SetFont(v)self.font=v end
    function C:SetColor(...)self.color={...} end
    function C:SetHorizontalAlignment(v)self.alignment=v end
    function C:SetAnchor(...)self.anchor={...} end
    function C:ClearAnchors()self.anchor=nil end
    function C:SetMouseEnabled(v)self.mouse=v end
    -- ESO routes OnMouseWheel on mouse-enabled controls. There is no
    -- SetMouseWheelEnabled method in the native Control API.
    function C:SetScrollBounding(v)self.bounding=v end
    function C:SetVerticalScroll(v)self.scroll=v end
    function C:GetHandler(e)return (self.handlers or {})[e] end
    function C:SetHandler(e,fn)self.handlers=self.handlers or {};self.handlers[e]=fn end
    function C:AddControl(control)self.insertions=(self.insertions or 0)+1;self.control=control;control.parent=setmetatable({},C) end
    function C:AddVerticalPadding()end
    function C:ClearLines()self.control=nil;local f=self:GetHandler('OnCleared');if f then f(self)end end
    api.WINDOW_MANAGER={CreateControl=function(_,name,parent,kind)local c=setmetatable({name=name,parent=parent,kind=kind},C);created[#created+1]=c;return c end}
    api.GuiRoot=setmetatable({width=1280,height=720},C);api.InformationTooltip=setmetatable({},C)
    api.GetUIGlobalScale=function()return 1 end;api.GetCVar=function()return 'ru' end
    api.ZO_PostHook=function(name,fn)local original=api[name];api[name]=function(...)local function pack(...)return {n=select('#',...),...}end;local v=pack(original(...));fn(...);return (unpack or table.unpack)(v,1,v.n)end end
    api.ZO_PostHookHandler=function(control,event,fn)local original=control:GetHandler(event);control:SetHandler(event,function(...)if original then original(...)end;fn(...)end)end
    api.ZO_StatsEntry_OnMouseEnter=function(control)api.InformationTooltip:ClearLines();api.InformationTooltip.title=control.statEntry.statType;api.originalCalls=(api.originalCalls or 0)+1;return 'native',nil,42 end
    api.ZO_StatsEntry_OnMouseExit=function()api.InformationTooltip:ClearLines()end
    for index,d in ipairs(KanaStatSources.Stats.Definitions)do api[d[2]]=index end
    api.created=created;api.Control=function()return setmetatable({},C)end
    return api
end
