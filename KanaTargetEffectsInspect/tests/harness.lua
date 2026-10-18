return function()
    local h = {events={}, controls={}, cursor=false, gamepad=false, target=true, time=100, messages={}}
    for _, k in ipairs({'TOPLEFT','BOTTOM','CT_CONTROL','DT_LOW','SCENE_SHOWING','SCENE_SHOWN','SCENE_HIDING','SCENE_HIDDEN',
        'EVENT_ADD_ON_LOADED','EVENT_PLAYER_ACTIVATED','EVENT_PLAYER_DEACTIVATED','EVENT_RETICLE_TARGET_CHANGED',
        'EVENT_GAME_CAMERA_UI_MODE_CHANGED','EVENT_GAMEPAD_PREFERRED_MODE_CHANGED','EVENT_SCREEN_RESIZED'}) do _G[k]=k end
    SI_ABILITY_TOOLTIP_NAME='name'; BUFF_EFFECT_TYPE_BUFF=1; BUFF_EFFECT_TYPE_DEBUFF=2
    local C={};C.__index=C
    function h.control(name,parent)
        local c=setmetatable({name=name,parent=parent,width=40,height=40,x=0,y=0,scale=1,hidden=false,handlers={},children={}},C)
        h.controls[name]=c;return c
    end
    function C:GetName() return self.name end
    function C:GetParent() return self.parent end
    function C:SetHidden(v) self.hidden=v end
    function C:IsHidden() return self.hidden end
    function C:IsControlHidden() return self.hidden or (self.parent and self.parent:IsControlHidden()) or false end
    function C:GetAlpha() return self.alpha or 1 end
    function C:SetAlpha(v) self.alpha=v end
    function C:SetScale(v) self.scale=v end
    function C:GetScale() return self.scale end
    function C:GetWidth() return self.width*self.scale end
    function C:GetHeight() return self.height*self.scale end
    function C:GetLeft() return self.x end
    function C:GetTop() return self.y end
    function C:GetRight() return self.x+self:GetWidth() end
    function C:GetBottom() return self.y+self:GetHeight() end
    function C:GetScreenRect() return self:GetLeft(),self:GetTop(),self:GetRight(),self:GetBottom() end
    function C:SetAnchor(_,relative,_,x,y) self.x=relative.x+(x or 0);self.y=relative.y+(y or 0) end
    function C:ClearAnchors() self.x=0;self.y=0 end
    function C:SetAnchorFill(relative) self.x=relative.x;self.y=relative.y;self.width=relative.width;self.height=relative.height end
    function C:SetDimensions(w,v) self.width=w;self.height=v end
    function C:SetMouseEnabled(v) self.mouse=v end
    function C:SetDrawTier(v) self.tier=v end
    function C:SetHandler(k,fn) self.handlers[k]=fn end
    function C:GetHandler(k) return self.handlers[k] end
    function C:GetNamedChild(k) return self.children[k] end
    function C:SetText(v) self.text=v end
    function C:GetText() return self.text end
    GuiRoot=h.control('GuiRoot');GuiRoot:SetDimensions(1920,1080)
    WINDOW_MANAGER={CreateTopLevelWindow=function(_,name) return h.control(name,GuiRoot) end,
        CreateControl=function(_,name,parent) return h.control(name,parent) end}
    local function icon(name,parent)
        local c=h.control(name,parent)
        c.duration=h.control(name..'Duration',c)
        c.blinkAnimation={Stop=function() c.blink=false end}
        c.cooldown={ResetCooldown=function() c.cooldownReset=true end,SetHidden=function(_,v) c.cooldownHidden=v end}
        return c
    end
    ZO_ControlPool={New=function(_,template,parent)
        assert(template=='ZO_BuffDebuffIcon')
        local p={active={},free={},next=0}
        function p:SetCustomFactoryBehavior(fn) self.factory=fn end
        function p:SetCustomResetBehavior(fn) self.reset=fn end
        function p:AcquireObject()
            local c=table.remove(self.free)
            if not c then self.next=self.next+1;c=icon(parent.name..'Icon'..self.next,parent);c.key=self.next;if self.factory then self.factory(c) end end
            self.active[c.key]=c;c:SetHidden(false);return c,c.key
        end
        function p:GetActiveObjects() return self.active end
        function p:ReleaseAllObjects()
            for _,c in pairs(self.active) do c:SetHidden(true);c:ClearAnchors();if self.reset then self.reset(c) end;self.free[#self.free+1]=c end
            self.active={}
        end
        return p
    end}
    ApplyTemplateToControl=function(c,template) assert(template=='ZO_BuffDebuffIcon_Keyboard_Template');c:SetDimensions(40,40) end
    ZO_GetPlatformTemplate=function(name) return name..'_Keyboard_Template' end
    local function scene(name)
        local s={name=name,state=SCENE_HIDDEN,callbacks={},fragments={}}
        function s:GetName() return self.name end
        function s:GetState() return self.state end
        function s:RegisterCallback(key,fn) self.callbacks[key]=self.callbacks[key] or {};table.insert(self.callbacks[key],fn) end
        function s:AddFragment(f) self.fragments[#self.fragments+1]=f end
        function s:stateTo(state)
            local old=self.state;self.state=state
            for _,fn in ipairs(self.callbacks.StateChange or {}) do fn(old,state) end
            for _,f in ipairs(self.fragments) do f.control:SetHidden(state==SCENE_HIDING or state==SCENE_HIDDEN) end
        end
        return s
    end
    HUD_SCENE=scene('hud');HUD_SCENE.state=SCENE_SHOWN
    HUD_UI_SCENE=scene('hudui');h.menu=scene('inventory')
    SCENE_MANAGER={current=HUD_SCENE}
    function SCENE_MANAGER:GetCurrentScene() return self.current end
    function SCENE_MANAGER:GetNextScene() return self.next end
    function SCENE_MANAGER:IsShowing(name) return self.current.name==name end
    function SCENE_MANAGER:IsInUIMode() return h.cursor end
    function SCENE_MANAGER:SetInUIMode(value)
        h.cursor=value
        if h.onCamera then h.onCamera() end
        h.emit(EVENT_GAME_CAMERA_UI_MODE_CHANGED)
        return true
    end
    function h.switch(s)
        SCENE_MANAGER.next=s
        SCENE_MANAGER.current:stateTo(SCENE_HIDING);SCENE_MANAGER.current:stateTo(SCENE_HIDDEN)
        SCENE_MANAGER.current=s;SCENE_MANAGER.next=nil
        s:stateTo(SCENE_SHOWING);s:stateTo(SCENE_SHOWN)
    end
    ZO_SimpleSceneFragment={New=function(_,control) return {control=control} end}
    ZO_PreHook=function(obj,key,fn) local prev=obj[key];obj[key]=function(...) if not fn(...) then return prev(...) end end end
    EVENT_MANAGER={RegisterForEvent=function(_,name,event,fn) h.events[event]=h.events[event] or {};h.events[event][name]=fn end,
        UnregisterForEvent=function(_,name,event) if h.events[event] then h.events[event][name]=nil end end}
    function h.emit(event,...) for _,fn in pairs(h.events[event] or {}) do fn(event,...) end end
    IsGameCameraUIModeActive=function() return h.cursor end
    IsGameCameraActive=function() return true end
    IsInGamepadPreferredMode=function() return h.gamepad end
    DoesUnitExist=function(tag) assert(tag=='reticleover');return h.target end
    GetFrameTimeSeconds=function() return h.time end
    GetCVar=function() return 'ru' end
    zo_strformat=function(_,s) return s end
    GetNumBuffs=function() error('no second effect tracker') end;GetUnitBuffInfo=GetNumBuffs
    d=function(s) table.insert(h.messages,s) end
    InformationTooltip={lines={}}
    function InformationTooltip:GetOwner() return self.owner end
    function InformationTooltip:AddLine(text,...) table.insert(self.lines,text) end
    function InformationTooltip:AddVerticalPadding(v) self.padding=v end
    InitializeTooltip=function(t,c) t.owner=c;t.lines={} end
    ClearTooltip=function(t) t.owner=nil;t.lines={} end
    h.frame=h.control('TargetFrame',GuiRoot)
    local function container(tag,parent)
        local c={control=h.control(tag,parent),styleObject={},updates=0}
        c.buffPool={container=h.control(tag..'Buffs',c.control),activeObjects={}}
        c.debuffPool={container=h.control(tag..'Debuffs',c.control),activeObjects={}}
        function c:GetPools() return self.buffPool,self.debuffPool end
        function c:GetControl() return self.control end
        function c:RefreshContainerVisibility()
            for _,p in ipairs({self.buffPool,self.debuffPool}) do p.container:SetHidden(self.contextHidden or not next(p.activeObjects)) end
        end
        function c:Update()
            self.updates=self.updates+1
            self.buffPool.activeObjects={};self.debuffPool.activeObjects={}
            for i,e in ipairs(self.effects or {}) do
                local p=e.debuff and self.debuffPool or self.buffPool
                local control=icon(tag..'Native'..i,p.container);control.x=e.x or 800+i*45;control.y=e.y or 200;control.scale=e.scale or 1
                control.data=e;control.showCooldown=false;p.activeObjects[i]=control
            end
            self:RefreshContainerVisibility();self.isDirty=false
        end
        function c.styleObject:SetupIcon(control) control.renderedName=control.data.buffName;control.renderedStacks=control.data.stackCount end
        function c.styleObject:UpdateDurations(owner)
            for _,p in ipairs({owner:GetPools()}) do for _,control in pairs(p.activeObjects) do
                local data=control.data
                control.duration:SetHidden(data.permanent or data.duration==0)
                control.duration:SetText(math.max(data.timeEnding-h.time,0))
            end end
        end
        return c
    end
    h.native=container('reticleover',h.frame);h.player=container('player',GuiRoot)
    BUFF_DEBUFF={containerObjectsByUnitTag={reticleover=h.native,player=h.player}}
    function h.effect(id,extra)
        local e={buffName='Effect '..id,abilityId=id,timeStarted=90,timeEnding=110,duration=20,permanent=false,stackCount=2,iconFilename='icon.dds',effectType=1}
        for k,v in pairs(extra or {}) do e[k]=v end
        return e
    end
    function h.set(effects)
        h.target=effects~=nil;h.frame:SetHidden(not h.target);h.native.effects=effects or {};h.native:Update();h.emit(EVENT_RETICLE_TARGET_CHANGED)
    end
    function h.enter(onCamera)
        h.onCamera=onCamera;SCENE_MANAGER:SetInUIMode(true);h.onCamera=nil;h.switch(HUD_UI_SCENE)
    end
    function h.period(onCamera)
        -- OnToggleHUDUIBinding -> Show(hudui) -> leader swaps current scene -> OnPreSceneStateChange.
        SCENE_MANAGER.next=HUD_UI_SCENE
        HUD_SCENE:stateTo(SCENE_HIDING);HUD_SCENE:stateTo(SCENE_HIDDEN)
        SCENE_MANAGER.current=HUD_UI_SCENE;SCENE_MANAGER.next=nil
        h.onCamera=onCamera;SCENE_MANAGER:SetInUIMode(true);h.onCamera=nil
        HUD_UI_SCENE:stateTo(SCENE_SHOWING);HUD_UI_SCENE:stateTo(SCENE_SHOWN)
    end
    function h.exit() SCENE_MANAGER:SetInUIMode(false);h.switch(HUD_SCENE) end
    function h.load()
        for line in io.lines(TEST_ROOT..'/KanaTargetEffectsInspect.addon') do
            local file=line:match('^%s*(.-)%s*$')
            if file~='' and file:sub(1,1)~='#' then assert(loadfile(TEST_ROOT..'/'..file))() end
        end
        h.emit(EVENT_ADD_ON_LOADED,'KanaTargetEffectsInspect')
        assert(KanaTargetEffectsInspect and KanaTargetEffectsInspect.instance,'inspection addon did not initialize')
        h.addon=KanaTargetEffectsInspect.instance
    end
    function h.icons()
        local out={}
        for _,c in pairs(h.controls) do if c.renderedName and not c:IsControlHidden() then out[#out+1]=c end end
        table.sort(out,function(a,b) return a.x<b.x end);return out
    end
    return h
end
