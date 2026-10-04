TestSupport.NativeRecording = {}
function TestSupport.NativeRecording.New(options)
    options=options or {}
    local api={constants={CT_CONTROL='control',CT_LABEL='label',CT_TEXTURE='texture',CT_BACKDROP='backdrop',
        TOPLEFT='tl',TOP='top',BOTTOM='bottom',MOUSE_BUTTON_INDEX_RIGHT=2,TEXT_ALIGN_RIGHT='right',TEXT_ALIGN_CENTER='center',TEXT_ALIGN_LEFT='left',
        TEXT_ALIGN_TOP='top',TEXT_WRAP_MODE_ELLIPSIS='ellipsis',DL_BACKGROUND=0,DL_CONTROLS=1,DL_TEXT=2,DL_OVERLAY=3,DT_LOW=0,DT_HIGH=3,SPACE_INTERFACE=1},controls={},created={},updates={},scale=0.8,calls={}}
    api.Now=function() return api.time or 0 end
    api.constants.BSTATE_NORMAL='normal'; api.constants.BSTATE_PRESSED='pressed'; api.constants.BSTATE_DISABLED='disabled'
    api.constants.INTERFACE_COLOR_TYPE_TEXT_COLORS='text'
    api.interfaceColors={normal={0.77,0.76,0.72,1},selected={0.86,0.82,0.67,1},highlight={1,1,1,1},disabled={0.4,0.4,0.4,1},error={1,0,0,1}}
    for role,suffix in pairs({normal='NORMAL',selected='SELECTED',highlight='HIGHLIGHT',disabled='DISABLED',error='FAILED'}) do api.constants['INTERFACE_TEXT_COLOR_'..suffix]=role end
    api.GetInterfaceColor=function(kind,role) assert(kind=='text'); return unpack(assert(api.interfaceColors[role])) end
    api.informationTooltip={}
    function api.informationTooltip:GetOwner() return api.lastTooltip and api.lastTooltip.owner end
    api.InitializeTooltip=function(tip,owner) assert(tip==api.informationTooltip); api.lastTooltip={owner=owner} end
    api.SetTooltipText=function(tip,value) assert(tip==api.informationTooltip); api.lastTooltip.text=value end
    api.ClearTooltipImmediately=function(tip) assert(tip==api.informationTooltip); api.lastTooltip=nil end
    api.GetUIGlobalScale=function() return api.scale end
    api.fonts={game={GetFontInfo=function() return 'native-face',16,'shadow' end},gameBold={GetFontInfo=function() return 'native-bold-face',16,'shadow' end}}
    api.CreateFont=function(symbol,descriptor)
        api.fontCreates=(api.fontCreates or 0)+1
        return {SetFont=function(self,desc) self.descriptor=desc end}
    end
    api.GetStringWidthScaled=function(font,text,scale,space)
        TestSupport.Assert.Equal(scale,1); TestSupport.Assert.Equal(space,1); api.widthCalls=(api.widthCalls or 0)+1
        return #text*7
    end
    api.eventManager={RegisterForUpdate=function(_,key,interval,callback)
        TestSupport.Assert.Equal(interval,string.find(key,'KanaEffectsGestures',1,true) and 0 or 100); api.updates[key]=callback; api.registers=(api.registers or 0)+1
    end,UnregisterForUpdate=function(_,key) api.updates[key]=nil end}
    local function control(name,parent,kind)
        local c={name=name,parent=parent,kind=kind,handlers={},calls={},hidden=false}
        local function record(self,method) self.calls[method]=(self.calls[method] or 0)+1 end
        function c:SetHandler(key,fn) self.handlers[key]=fn; record(self,'SetHandler') end
        function c:SetHidden(v)
            -- Workload suites need observable direct visibility transitions,
            -- without emulating every native descendant on every label write.
            if options.directVisibility then
                local before=self:IsControlHidden(); self.hidden=v; record(self,'SetHidden')
                local after=self:IsControlHidden(); local handler=self.handlers[after and 'OnEffectivelyHidden' or 'OnEffectivelyShown']
                if before~=after and handler then handler(self,after) end
                return
            end
            local old={}; for _,child in ipairs(api.created) do old[child]=child:IsControlHidden() end
            self.hidden=v; record(self,'SetHidden')
            for _,child in ipairs(api.created) do
                local hidden=child:IsControlHidden()
                local handler=child.handlers[hidden and 'OnEffectivelyHidden' or 'OnEffectivelyShown']
                if old[child]~=hidden and handler then handler(child,hidden) end
            end
        end
        function c:IsControlHidden() return self.hidden or (self.parent and self.parent:IsControlHidden()) or false end
        function c:SetAnchorFill(target) self.anchorFill=target end
        function c:ClearAnchors() self.anchor=nil; record(self,'ClearAnchors') end
        function c:SetAnchor(point,to,relative,x,y) self.anchor={x=x,y=y,to=to}; record(self,'SetAnchor') end
        function c:SetDimensions(w,h) self.width=w; self.height=h; record(self,'SetDimensions') end
        function c:SetText(v) self.text=v; record(self,'SetText') end
        function c:SetFont(v) self.font=v; record(self,'SetFont') end
        function c:SetNormalFontColor(...) self.normalFontColor={...} end
        function c:SetMouseOverFontColor(...) self.mouseOverFontColor={...} end
        function c:SetPressedFontColor(...) self.pressedFontColor={...} end
        function c:SetDisabledFontColor(...) self.disabledFontColor={...} end
        function c:SetNormalTexture(v) self.normalTexture=v end
        function c:SetPressedTexture(v) self.pressedTexture=v end
        function c:SetMouseOverTexture(v) self.mouseOverTexture=v end
        function c:SetDisabledTexture(v) self.disabledTexture=v end
        function c:SetState(state,locked) self.state=state; self.locked=locked end
        function c:GetFontHeight() return 19 end
        function c:SetTexture(v) self.texture=v; record(self,'SetTexture') end
        function c:SetTextureCoords(...) self.coords={...} end
        function c:SetColor(...) self.color={...} end
        function c:SetCenterColor(...) self.center={...} end
        function c:SetEdgeColor(...) self.edge={...} end
        function c:SetEdgeTexture(...) self.edgeTexture={...} end
        function c:SetInsets(...) self.insets={...} end
        function c:SetAlpha(v) self.alpha=v end
        function c:SetDesaturation(v) self.desaturation=v end
        function c:SetMouseEnabled(v) self.mouse=v end
        function c:SetDrawLayer(v) self.layer=v end
        function c:SetDrawLevel(v) self.level=v end
        function c:GetDrawLevel() return self.level or 0 end
        function c:GetDrawLayer() return self.layer or 1 end
        function c:GetDrawTier() return self.tier or 1 end
        function c:SetDrawTier(v) self.tier=v end
        function c:SetAllowBringToTop(v) self.allowBringToTop=v end
        function c:SetTextureRotation(angle,x,y) self.rotation=angle; self.rotationX=x; self.rotationY=y end
        function c:SetHorizontalAlignment(v) self.align=v end
        function c:SetVerticalAlignment(v) self.valign=v end
        function c:SetWrapMode(v) self.wrap=v end
        function c:SetMaxLineCount(v) self.lines=v end
        api.created[#api.created+1]=c; return c
    end
    api.controls.CreateTopLevelWindow=function(name) return control(name,api.controls.GuiRoot,'control') end
    api.controls.CreateControl=control; api.controls.GuiRoot=control('screen',nil,'control')
    function api.controls.GuiRoot:GetDimensions() return 2560,1440 end
    function api.controls.GuiRoot:GetLeft() return 0 end
    function api.controls.GuiRoot:GetTop() return 0 end
    return api
end
