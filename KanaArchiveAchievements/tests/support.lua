local S = {}
function S.New()
    local a, controls, events = {}, {}, {}
    local C = {}; C.__index = C
    local function control(name,parent)
        local c=setmetatable({name=name,parent=parent,children={},width=0,height=0,hidden=false,handlers={}},C)
        if name then controls[name]=c end
        return c
    end
    function C:GetNamedChild(name)
        if not self.children[name] then self.children[name]=control((self.name or '')..name,self) end
        return self.children[name]
    end
    function C:SetDimensions(w,h) self.width,self.height=w,h end
    function C:SetWidth(w) self.width=w end
    function C:SetHeight(h) self.height=h end
    function C:GetWidth()
        if self.parent and self.parent.template=='ZO_ScrollContainer' then return self.parent:GetWidth()-16*self:GetScale() end
        return self.width*self:GetScale()
    end
    function C:GetHeight()
        if self.parent and self.parent.template=='ZO_ScrollContainer' then return self.parent:GetHeight() end
        return self.height*self:GetScale()
    end
    function C:GetScale() return self.scale or (self.parent and self.parent:GetScale() or 1) end
    function C:SetHidden(v) self.hidden=v end
    function C:IsControlHidden() return self.hidden end
    function C:IsHidden() return self.hidden or (self.parent and self.parent:IsHidden() or false) end
    function C:SetMouseEnabled(v) self.mouse=v end
    function C:SetResizeToFitDescendents(v) self.resize=v end
    function C:SetExcludeFromResizeToFitExtents(v) self.exclude=v end
    function C:SetDrawTier(v) self.tier=v end
    function C:SetDrawLevel(v) self.level=v end
    function C:SetDrawLayer(v) self.layer=v end
    function C:SetTexture(v) self.texture=v end
    function C:GetTextureFileName() return self.texture end
    function C:SetColor(...) error('Native indicator colours must not be replaced') end
    function C:SetHandler(name,fn) self.handlers[name]=fn end
    function C:BringWindowToTop() assert(self.isTopLevel,'BringWindowToTop belongs to TopLevelWindow, not Control');self.broughtTop=true end
    function C:ClearAnchors() self.anchor=nil end
    function C:SetAnchor(point,relative,to,x,y) self.anchor={point=point,relative=relative,to=to,x=x or 0,y=y or 0} end
    function C:GetLeft()
        if self.anchor then
            local relative=self.anchor.relative
            local offset=self.anchor.to==a.TOP and relative:GetWidth()/2 or (self.anchor.to==a.TOPRIGHT and relative:GetWidth() or 0)
            return relative:GetLeft()+offset+self.anchor.x*self:GetScale()
        end
        return self.left or (self.parent and self.parent:GetLeft() or 0)
    end
    function C:GetTop()
        if self.anchor then return self.anchor.relative:GetTop()+self.anchor.y*self:GetScale() end
        return self.top or (self.parent and self.parent:GetTop() or 0)
    end
    function C:GetBottom() return self:GetTop()+self:GetHeight() end
    -- Native label measurements are already UI units, independent of scale.
    function C:GetFontHeight() return self.fontHeight or 26 end
    function C:GetTextWidth() return self.textWidth or 120 end
    function C:GetScrollOffsets() return 0,self.offset or 0 end
    function C:SetVerticalScroll(v) self.offset=v end
    function C:GetScrollExtents()
        return 0,math.max(0,self:GetNamedChild('Child'):GetHeight()-self:GetHeight())
    end
    a.TOPLEFT,a.TOPRIGHT,a.BOTTOMRIGHT,a.DT_HIGH,a.CT_TEXTURE=1,2,3,4,5
    a.DL_OVERLAY=7
    a.TOP=8
    a.KEYBIND_STRIP_ALIGN_RIGHT=6
    a.ZO_SCROLL_BAR_WIDTH=16
    a.GuiRoot=control('GuiRoot');a.GuiRoot:SetDimensions(1920,1080)
    a.ZO_KeybindStripControl=control('KeybindStrip',a.GuiRoot);a.ZO_KeybindStripControl.top=1000
    a.WINDOW_MANAGER={
        CreateTopLevelWindow=function(_,name) local c=control(name,a.GuiRoot);c.isTopLevel=true;return c end,
        CreateControl=function(_,name,parent,kind) local c=control(name,parent);c.kind=kind;return c end,
        CreateControlFromVirtual=function(_,name,parent,template)
            local c=control(name,parent);c.template=template
            if template=='ZO_ScrollContainer' then
                local scroll=c:GetNamedChild('Scroll');scroll:GetNamedChild('Child')
            end
            return c
        end,
    }
    a.ZO_ControlPool={New=function(_,template,parent)
        local pool={template=template,parent=parent}
        function pool:SetCustomFactoryBehavior(fn) self.factory=fn end
        return pool
    end}
    a.nativeInstances={}
    a.nativeRenders={}
    a.Achievement={Show=function(n,id)
        n.id=id
        n.parentControl:SetHeight(88)
        a.nativeRenders[id]=(a.nativeRenders[id] or 0)+1
    end}
    a.AchievementContainer={New=function(_,c,...)
        local pools={...};assert(#pools==7)
        for _,pool in ipairs(pools) do assert(pool.parent==c,'Native pools must be owned by this card') end
        local n={parentControl=c,pools=pools,collapsed=true,Show=a.AchievementContainer.Show}
        function n:Expand()
            self.collapsed=false
            self.parentControl:SetHeight(({[101]=700,[102]=200,[103]=160})[self.id] or 100)
        end
        function n:RefreshExpandedView()end
        function n:Hide() self.id=nil;self.collapsed=true;c:SetHidden(true) end
        a.nativeInstances[#a.nativeInstances+1]=n
        return n
    end}
    -- Exact native Show path, from ESO's achievements/keyboard/achievements.lua.
    -- Rendering/API calls beneath Achievement.Show are the boundary double;
    -- the TopLevelWindow-only call must not disappear from this contract.
    function a.AchievementContainer:Show(id, progress, timestamp)
        self.parentControl:SetHidden(false)
        self.parentControl:BringWindowToTop()
        self.progress = progress
        self.timestamp = timestamp
        a.Achievement.Show(self, id)
        if self.collapsed then
            self:Expand()
        else
            self:RefreshExpandedView()
        end
    end
    a.GetAchievementProgress=function(id)return 'progress:'..id end
    a.GetAchievementTimestamp=function(id)return id*100 end
    a.ZO_StatusBar_SetGradientColor=function()end;a.ZO_XP_BAR_GRADIENT_COLORS={}
    a.ZO_Scroll_UpdateScrollBar=function(c)c.updated=true end
    a.ZO_Scroll_ScrollAbsoluteInstantly=function(c,v)c:GetNamedChild('Scroll'):SetVerticalScroll(v)end
    a.ZO_Scroll_ScrollRelative=function(c,v)
        local scroll=c:GetNamedChild('Scroll');local _,extent=scroll:GetScrollExtents()
        scroll.offset=math.max(0,math.min(extent,(scroll.offset or 0)+v))
    end
    a.ZO_Scroll_OnMouseWheel=function(c,delta)a.ZO_Scroll_ScrollRelative(c,-delta*40)end
    a.KEYBIND_STRIP={groups={}}
    function a.KEYBIND_STRIP:AddKeybindButtonGroup(g) self.groups[g]=true end
    function a.KEYBIND_STRIP:RemoveKeybindButtonGroup(g) self.groups[g]=nil end
    a.IsInGamepadPreferredMode=function()return a.gamepad or false end
    a.GetCVar=function()return 'ru' end
    a.SecurePostHook=function(object,method,callback)
        local old=object[method]
        object[method]=function(self,...)local result=old(self,...);callback(self,...);return result end
    end
    a.EVENT_ACHIEVEMENT_UPDATED,a.EVENT_ACHIEVEMENT_AWARDED,a.EVENT_GAMEPAD_PREFERRED_MODE_CHANGED,a.EVENT_ADD_ON_LOADED=10,11,12,13
    a.EVENT_SCREEN_RESIZED=14
    a.EVENT_INTERFACE_SETTING_CHANGED=15
    a.EVENT_MANAGER={RegisterForEvent=function(_,name,id,fn)events[id]=fn end,UnregisterForEvent=function(_,name,id)events[id]=nil end}
    function a:Selector(name)
        local c=control(name,self.GuiRoot);c.top=250;c.left=500;c:SetDimensions(820,300)
        local selector={control=c,buffControls={},calls={}}
        c:GetNamedChild('BG'):SetDimensions(860,300)
        selector.rerollButton=control(name..'Reroll',c);selector.rerollButton.top=560;selector.rerollButton:SetDimensions(150,30)
        selector.currencyLabel=control(name..'Currency',c);selector.currencyLabel.top=560;selector.currencyLabel:SetDimensions(150,30)
        for i=1,3 do
            local buff=control(name..'Buff'..i,c);buff.abilityId=i;buff.bucketType=i-1;buff.nameLabel=buff:GetNamedChild('Name');buff.nameLabel:SetDimensions(220,52)
            selector.buffControls[i]=buff
        end
        for _,method in ipairs({'OnShowing','OnHiding','RefreshBuffs','SelectBuff','DeselectBuff','CommitChoice','SetIsRerolling'}) do
            selector[method]=function(self,value)
                self.calls[method]=(self.calls[method] or 0)+1
                if method=='SelectBuff' then self.selectedBuffControl=value end
                if method=='DeselectBuff' then self.selectedBuffControl=nil end
                if method=='SetIsRerolling' then self.isRerolling=value end
                if method=='OnShowing' then self.control:SetHidden(false) end
                if method=='OnHiding' then self.control:SetHidden(true) end
            end
        end
        return selector
    end
    return a,controls,events
end
function S.Load(path,api)
    api._G=api;api.KanaArchiveAchievements=KanaArchiveAchievements
    setmetatable(api,{__index=_G})
    local chunk,error
    if setfenv then chunk,error=loadfile(path);if chunk then setfenv(chunk,api)end
    else chunk,error=loadfile(path,'t',api)end
    assert(chunk,error);chunk()
end
return S
