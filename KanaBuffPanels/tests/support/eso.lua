-- Only the external ESO boundary is simulated. Unknown methods fail loudly.
return function()
    local h = {controls={},created=0,events={},callbacks={},gamepad=false,frames=0}
    for _,key in ipairs({'LEFT','RIGHT','TOP','BOTTOM','TOPLEFT','TOPRIGHT','BOTTOMLEFT','BOTTOMRIGHT','CENTER',
        'CT_CONTROL','CT_LABEL','EVENT_ADD_ON_LOADED','EVENT_SCREEN_RESIZED','EVENT_GAMEPAD_PREFERRED_MODE_CHANGED',
        'SCENE_SHOWING','SCENE_SHOWN','SCENE_HIDDEN','TEXT_ALIGN_LEFT','TEXT_ALIGN_RIGHT','TEXT_ALIGN_CENTER'}) do _G[key]=key end
    MOUSE_BUTTON_INDEX_RIGHT=2; MOUSE_BUTTON_INDEX_LEFT=1
    local points={LEFT={0,.5},RIGHT={1,.5},TOP={.5,0},BOTTOM={.5,1},TOPLEFT={0,0},TOPRIGHT={1,0},BOTTOMLEFT={0,1},BOTTOMRIGHT={1,1},CENTER={.5,.5}}
    local C={}; C.__index=C
    function h.control(name,parent)
        name=name or ('Anonymous'..h.created)
        local c=setmetatable({name=name,parent=parent,width=0,height=0,handlers={},hidden=false,alpha=1,children={},anchors={}},C)
        h.created=h.created+1;h.controls[name]=c
        if parent then parent.children[c]=true end
        return c
    end
    function C:GetName() return self.name end
    function C:SetParent(parent)
        if self.parent then self.parent.children[self]=nil end
        self.parent=parent
        if parent then parent.children[self]=true end
    end
    function C:GetParent() return self.parent end
    function C:SetAnchor(point,relative,relativePoint,x,y)
        local index=#self.anchors+1
        for i,a in ipairs(self.anchors) do if a[1]==point then index=i;break end end
        self.anchors[index]={point,relative or self.parent,relativePoint or point,x or 0,y or 0}
        self.anchor=self.anchors[1]
    end
    function C:GetAnchor(index) if self.anchors[index+1] then return true,unpack(self.anchors[index+1]) end;return false end
    function C:ClearAnchors() self.anchor=nil;self.anchors={} end
    function C:SetDimensions(w,v)
        local changed=self.width~=w or self.height~=v
        self.width,self.height=w,v
        if changed and self.handlers.OnRectChanged then self.handlers.OnRectChanged(self) end
    end
    function C:SetWidth(w) self.width=w end
    function C:SetHeight(v) self.height=v end
    function C:GetWidth() return self.width end
    function C:GetHeight() return self.height end
    function C:GetDimensions() return self.width,self.height end
    function C:GetLeft()
        if not self.anchor then return 0 end
        local a=self.anchor;return a[2]:GetLeft()+points[a[3]][1]*a[2]:GetWidth()+a[4]-points[a[1]][1]*self.width
    end
    function C:GetTop()
        if not self.anchor then return 0 end
        local a=self.anchor;return a[2]:GetTop()+points[a[3]][2]*a[2]:GetHeight()+a[5]-points[a[1]][2]*self.height
    end
    function C:GetRight() return self:GetLeft()+self.width end
    function C:GetBottom() return self:GetTop()+self.height end
    function C:GetCenter() return self:GetLeft()+self.width/2,self:GetTop()+self.height/2 end
    function C:SetHidden(value) self.hidden=value end
    function C:IsHidden() return self.hidden end
    function C:IsControlHidden() return self.hidden or (self.parent and self.parent:IsControlHidden()) or false end
    function C:SetAlpha(v) self.alpha=v end
    function C:GetAlpha() return self.alpha end
    function C:SetExcludeFromResizeToFitExtents(value) self.excluded=value end
    function C:SetMouseEnabled(v) self.mouse=v end
    function C:SetHandler(name,fn) self.handlers[name]=fn end
    function C:GetHandler(name) return self.handlers[name] end
    function C:GetNamedChild(suffix) return h.controls[self.name..suffix] end
    function C:SetFont(font) self.font=font end
    function C:GetFont() return self.font or 'native-font' end
    function C:GetFontHeight() return h.fontHeight or 10 end
    function C:SetHorizontalAlignment(alignment) self.horizontalAlignment=alignment end
    function C:GetHorizontalAlignment() return self.horizontalAlignment or TEXT_ALIGN_LEFT end
    function C:SetText(text) self.text=text end
    function C:GetText() return self.text or '' end
    function C:GetTextHeight() return (h.fontHeight or 10)*2 end
    function C:SetMaxLineCount(n) self.maxLines=n end
    GuiRoot=h.control('GuiRoot');GuiRoot:SetDimensions(1920,1080)
    h.hud=h.control('HUD',GuiRoot);h.hud:SetDimensions(1920,1080)
    WINDOW_MANAGER={CreateControl=function(_,name,parent,kind) return h.control(name,parent) end}
    GetNumBuffs=function() error('addon must not scan effects') end
    GetUnitBuffInfo=GetNumBuffs
    IsInGamepadPreferredMode=function() return h.gamepad end
    GetCVar=function() return 'ru' end
    LocaleAwareToLower=function(s) return s:lower() end
    zo_strformat=function(_,s) return s end
    SI_ABILITY_TOOLTIP_NAME='abilityName'
    EVENT_MANAGER={RegisterForEvent=function(_,name,event,fn) h.events[event]=h.events[event] or {};h.events[event][name]=fn end,
        UnregisterForEvent=function(_,name,event) if h.events[event] then h.events[event][name]=nil end end,
        RegisterForUpdate=function() error('addon must not create a timer') end}
    function h.emit(event,...)
        local listeners={};for _,fn in pairs(h.events[event] or {}) do listeners[#listeners+1]=fn end
        for _,fn in ipairs(listeners) do fn(event,...) end
    end
    local source={active={},free={},nextId=1}
    function source:AcquireObject()
        local control=table.remove(self.free)
        if not control then
            local id=self.nextId;self.nextId=id+1
            control=h.control('NativeBuff'..id,h.hud);control.key=id;control:SetDimensions(40,40)
            local frame=h.control(control.name..'Frame',control);frame:SetDimensions(40,40);frame:SetAnchor(CENTER,control,CENTER)
            control.duration=h.control(control.name..'Duration',control);control.duration:SetFont('native-font')
            control.duration:SetWidth(40)
            control.duration:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
            control.duration:SetAnchor(TOPLEFT,frame,BOTTOMLEFT)
            control.duration:SetAnchor(TOPRIGHT,frame,BOTTOMRIGHT)
            control.timerUpdates=0
            control:SetHandler('OnMouseEnter',function() h.tooltips=(h.tooltips or 0)+1 end)
            control:SetHandler('OnMouseExit',function() end)
        end
        control:SetHidden(false);self.active[control.key]=control
        return control,control.key
    end
    function source:ReleaseObject(key)
        local c=self.active[key];assert(c,'double release');self.active[key]=nil
        c:SetHidden(true);c:ClearAnchors();self.free[#self.free+1]=c
    end
    local function meta(name,parent)
        local p={container=h.control(name,parent),sourcePool=source,activeObjects={}}
        p.container:SetHeight(40)
        p.customAcquireBehavior=function(c)
            c:ClearAnchors()
            if not p.firstControl then p.firstControl=c;c:SetAnchor(LEFT,p.container,LEFT,0,0)
            else c:SetAnchor(LEFT,p.lastControl,RIGHT,5,0) end
            p.lastControl=c;c:SetParent(p.container)
        end
        p.customResetBehavior=function(c) c.blinkStopped=true end
        function p:SetCustomAcquireBehavior(fn) self.customAcquireBehavior=fn end
        function p:SetCustomResetBehavior(fn) self.customResetBehavior=fn end
        function p:AcquireObject()
            local c,k=self.sourcePool:AcquireObject();self.activeObjects[k]=c;self.customAcquireBehavior(c);return c,k
        end
        function p:ReleaseAllObjects()
            for k,c in pairs(self.activeObjects) do self.customResetBehavior(c);source:ReleaseObject(k) end
            self.activeObjects={}
        end
        function p:HasActiveObjects() return next(self.activeObjects)~=nil end
        function p:GetActiveObjects() return self.activeObjects end
        return p
    end
    local function unit(tag)
        local c={control=h.control(tag,h.hud),unitTag=tag,nextBuffs={},nextDebuffs={},updates=0,styleObject={}}
        c.control:SetDimensions(40,40);c.control:SetAnchor(CENTER,GuiRoot,CENTER,0,0)
        c.buffPool=meta(tag..'Buffs',c.control);c.debuffPool=meta(tag..'Debuffs',c.control)
        c.buffPool.container:SetAnchor(LEFT,c.control,LEFT,0,0)
        c.debuffPool.container:SetAnchor(LEFT,c.buffPool.container,RIGHT,5,0)
        function c:GetPools() return self.buffPool,self.debuffPool end
        function c:GetControl() return self.control end
        function c:GetUnitTag() return self.unitTag end
        function c:RefreshContainerVisibility()
            self.buffPool.container:SetHidden(self.contextHidden or not self.buffPool:HasActiveObjects())
            self.debuffPool.container:SetHidden(self.contextHidden or not self.debuffPool:HasActiveObjects())
        end
        function c:Update()
            self.updates=self.updates+1
            for _,p in ipairs({self.buffPool,self.debuffPool}) do p:ReleaseAllObjects();p.firstControl=nil end
            for _,pair in ipairs({{self.buffPool,self.nextBuffs},{self.debuffPool,self.nextDebuffs}}) do
                for _,data in ipairs(pair[2]) do local control=pair[1]:AcquireObject();control.data=data end
            end
            self.isDirty=false
        end
        function c:UpdateTime()
            for _,p in ipairs({self.buffPool,self.debuffPool}) do
                for _,control in pairs(p.activeObjects) do control.timerUpdates=control.timerUpdates+1 end
            end
        end
        c.control:SetHandler('OnUpdate',function() if c.isDirty then c:Update() end;c:RefreshContainerVisibility();c:UpdateTime() end)
        return c
    end
    h.source=source;h.player=unit('player');h.target=unit('reticleover')
    BUFF_DEBUFF={containerObjectsByUnitTag={player=h.player,reticleover=h.target}}
    function h.update(container,buffs,debuffs)
        container.nextBuffs=buffs or {};container.nextDebuffs=debuffs or {};container:Update()
    end
    function h.effect(id,name) return {abilityId=id,buffName=name or ('Effect '..id),duration=10,stackCount=1} end
    return h
end
