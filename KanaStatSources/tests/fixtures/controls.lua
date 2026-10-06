return function()
    local api={CT_CONTROL=1,CT_LABEL=2,CT_SCROLL=3,CT_TEXTURE=4,TOPLEFT=1,TOPRIGHT=2,CENTER=3,RIGHT=4,TEXT_ALIGN_RIGHT=2,SCROLL_BOUNDING_CONTAINED=1};local created={}
    local C={};C.__index=C
    function C:SetHidden(v)
        local was=self.hidden;self.hidden=v
        if v and was==false then local f=self:GetHandler('OnHide');if f then f(self)end end
    end
    function C:IsControlHidden()return self.hidden~=false end
    function C:SetScale(v)self.scale=v end
    function C:SetDimensions(w,h)self.width=w;self.height=h end
    function C:GetWidth()return self.width or 416 end
    function C:GetHeight()return self.height or 100 end
    function C:GetDimensionConstraints()return (unpack or table.unpack)(self.constraints or {0,0,350,0})end
    function C:SetDimensionConstraints(...)self.constraints={...}end
    function C:GetResizeToFitPadding()return 32,32 end
    function C:SetText(v)self.text=v end
    local function stringWidth(text)
        local _,bytes=(text or ''):gsub('[\128-\191]','');return (#(text or '')-bytes)*8
    end
    function C:GetTextHeight()
        local lines=0
        local width=self.width==0 and math.huge or math.max(1,self.width or 400)
        for line in ((self.text or '')..'\n'):gmatch('(.-)\n') do lines=lines+math.max(1,math.ceil(stringWidth(line)/width))end
        return math.max(1,math.min(self.maxLines or lines,lines))*18
    end
    function C:SetFont(v)self.font=v end
    function C:GetStringWidth(text)return stringWidth(text)*api.GetUIGlobalScale()end
    function C:GetTextDimensions()
        local width=0
        for line in ((self.text or '')..'\n'):gmatch('(.-)\n')do width=math.max(width,stringWidth(line))end
        if self.width and self.width>0 then width=math.min(width,self.width)end
        return width,self:GetTextHeight()
    end
    function C:SetMaxLineCount(v)self.maxLines=v end
    function C:SetTexture(v)self.texture=v end
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
    function api.WINDOW_MANAGER:CreateControlFromVirtual(name,parent,template)
        if template=='TooltipTopLevel' then
            assert(parent==api.GuiRoot);return self:CreateControl(name,parent,'tooltipTopLevel')
        end
        assert(template=='ZO_BaseTooltip' and parent.kind=='tooltipTopLevel')
        local c=self:CreateControl(name,parent,'tooltip');c.hidden=true;c.constraints={0,0,350,0};return c
    end
    api.GuiRoot=setmetatable({width=1280,height=720},C);api.InformationTooltip=setmetatable({},C)
    api.GetUIGlobalScale=function()return 1 end;api.GetCVar=function()return 'ru' end
    api.ZO_PostHook=function(name,fn)local original=api[name];api[name]=function(...)local function pack(...)return {n=select('#',...),...}end;local v=pack(original(...));fn(...);return (unpack or table.unpack)(v,1,v.n)end end
    api.ZO_PreHook=function(name,fn)local original=api[name];api[name]=function(...)if not fn(...)then return original(...)end end end
    api.ZO_PostHookHandler=function(control,event,fn)local original=control:GetHandler(event);control:SetHandler(event,function(...)if original then original(...)end;fn(...)end)end
    api.ZO_StatsEntry_OnMouseEnter=function(control)api.InformationTooltip:ClearLines();api.InformationTooltip.title=control.statEntry.statType;api.originalCalls=(api.originalCalls or 0)+1;return 'native',nil,42 end
    -- Native ClearTooltip starts a fade without clearing or resizing contents.
    api.ClearTooltip=function(tooltip)tooltip.owner=nil;if not tooltip:IsControlHidden()then tooltip.fading=true end end
    api.ClearTooltipImmediately=function(tooltip)tooltip.fading=false;tooltip.owner=nil;tooltip:SetHidden(true)end
    api.CompleteFade=function(tooltip)if tooltip.fading then tooltip.fading=false;tooltip:SetHidden(true)end end
    api.ZO_StatsEntry_OnMouseExit=function()api.ClearTooltip(api.InformationTooltip)end
    api.InitializeTooltip=function(tooltip,owner)tooltip:ClearLines();tooltip:SetHidden(false);tooltip.owner=owner;tooltip.fading=false end
    api.GetString=function(_,id)return 'Stat '..id end
    api.zo_strformat=function(text,value)return text=='<<1>>' and tostring(value) or tostring(text)end
    api.ZO_STAT_TOOLTIP_DESCRIPTIONS={};for i=1,15 do api.ZO_STAT_TOOLTIP_DESCRIPTIONS[i]='Native description '..i end
    for index,d in ipairs(KanaStatSources.Stats.Definitions)do api[d[2]]=index end
    api.created=created;api.Control=function()return setmetatable({},C)end
    return api
end
