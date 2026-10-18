-- Only the ESO boundary is simulated. All addon modules run unchanged.
return function()
    unpack = unpack or table.unpack -- ESO is Lua 5.1; local CLI can be 5.4.
    local H = {events={}, updates={}, controls={}, options={}, fragments={}, now=10,
        exists=true, physical=7000, spell=7000, difficulty=0, buffs={}, sceneVisible=false}
    for _, key in ipairs({'CT_CONTROL','CT_LABEL','CT_TEXTURE','CT_BACKDROP','TOP','BOTTOM','TOPLEFT','TOPRIGHT','CENTER','BOTTOMLEFT',
        'TEXT_ALIGN_RIGHT','TEXT_ALIGN_CENTER','BAR_ALIGNMENT_REVERSE','NUMBER_ABBREVIATION_PRECISION_TENTHS',
        'RESOURCE_NUMBERS_SETTING_PERCENT_ONLY','DT_LOW','DT_HIGH','DL_TEXT','DL_BACKGROUND','DL_CONTROLS','EVENT_ADD_ON_LOADED',
        'EVENT_RETICLE_TARGET_CHANGED','EVENT_PLAYER_ACTIVATED','EVENT_ACTION_SLOTS_ACTIVE_HOTBAR_UPDATED',
        'EVENT_SCREEN_RESIZED','STAT_PHYSICAL_PENETRATION','STAT_SPELL_PENETRATION',
        'STAT_BONUS_OPTION_APPLY_BONUS','HOTBAR_CATEGORY_CHAMPION','SI_ABILITY_NAME','COMBAT_MECHANIC_FLAGS_HEALTH',
        'INSTANCE_TYPE_PUBLIC_DUNGEON','INSTANCE_TYPE_GROUP','INSTANCE_TYPE_RAID','INSTANCE_TYPE_SOLO'}) do _G[key]=key end
    DUNGEON_DIFFICULTY_NONE=0
    local C={}; C.__index=C
    local function control(name,parent)
        H.controlsCreated=(H.controlsCreated or 0)+1
        local c=setmetatable({name=name,parent=parent,handlers={},width=0,height=0},C)
        if name then H.controls[name]=c end
        return c
    end
    function C:SetDimensions(w,h) self.width,self.height=w,h end
    function C:SetWidth(w) self.width=w end
    function C:SetHeight(h) self.height=h end
    function C:GetScale() return (self.scale or 1)*(self.parent and self.parent:GetScale() or 1) end
    function C:GetWidth() return self.fill and self.fill:GetWidth() or self.width*self:GetScale() end
    function C:GetHeight() return self.fill and self.fill:GetHeight() or self.height*self:GetScale() end
    function C:SetAnchor(...) self.anchor={...} end
    function C:GetAnchor(index) if index==0 and self.anchor then return true,unpack(self.anchor) end;return false end
    function C:GetNumAnchors() return self.anchor and 1 or 0 end
    function C:ClearAnchors() self.anchor=nil end
    function C:SetAnchorFill(parent) self.fill=parent end
    function C:SetScale(s) self.scale=s end
    function C:GetNamedChild(suffix) return H.controls[self.name..suffix] end
    function C:SetMinMax(min,max)
        self.min,self.max=min,max
        if self.gloss then self.gloss:SetMinMax(min,max) end
    end
    function C:SetValue(value)
        self.value=value
        if self.gloss then self.gloss:SetValue(value) end
    end
    function C:SetClampedToScreen(v) self.clamped=v end
    function C:SetMovable(v) self.movable=v end
    function C:SetMouseEnabled(v) self.mouse=v end
    function C:SetHandler(key,fn) self.handlers[key]=fn end
    function C:SetHidden(v)
        local changed=self.hidden~=v; self.hidden=v
        local fn=self.handlers[v and 'OnHide' or 'OnShow']
        if changed and fn then fn(self) end
    end
    function C:IsHidden() return self.hidden==true end
    function C:IsControlHidden() return self.hidden or (self.parent and self.parent:IsControlHidden()) or false end
    function C:SetText(v) self.text=v end
    function C:GetText() return self.text or '' end
    function C:GetAlpha() return self.alpha or 1 end
    function C:SetAlpha(v) self.alpha=v end
    function C:SetColor(...) self.color={...} end
    function C:SetCenterColor(...) self.color={...} end
    function C:GetCenter()
        if self.center then return self.center[1],self.center[2] end
        if self==GuiRoot then return self.width/2,self.height/2 end
        if self.fill then return self.fill:GetCenter() end
        local a=self.anchor
        if a then
            local points={[TOP]={0,-.5},[BOTTOM]={0,.5},[CENTER]={0,0},
                [TOPLEFT]={-.5,-.5},[TOPRIGHT]={.5,-.5},[BOTTOMLEFT]={-.5,.5}}
            local own,relative=assert(points[a[1]]),assert(points[a[3]])
            local x,y=a[2]:GetCenter()
            x=x+relative[1]*a[2]:GetWidth()-own[1]*self:GetWidth()
            y=y+relative[2]*a[2]:GetHeight()-own[2]*self:GetHeight()
            return x+(a[4] or 0)*self:GetScale(),y+(a[5] or 0)*self:GetScale()
        end
        return 0,0
    end
    function C:GetTop() local _,y=self:GetCenter();return y-self:GetHeight()/2 end
    function C:GetBottom() local _,y=self:GetCenter();return y+self:GetHeight()/2 end
    function C:GetLeft() local x=self:GetCenter();return x-self:GetWidth()/2 end
    function C:GetRight() local x=self:GetCenter();return x+self:GetWidth()/2 end
    function C:SetFont(font) self.font=font end
    function C:GetFont() return self.font or 'ZoFontWinH5' end
    function C:GetFontFaceName() return self.face or 'EsoFont' end
    function C:GetFontSize() return self.fontSize or 16 end
    function C:GetFontStyle() return self.fontStyle or 'soft-shadow-thick' end
    function C:SetHorizontalAlignment(value) self.horizontalAlignment=value end
    function C:SetVerticalAlignment(value) self.verticalAlignment=value end
    function C:SetBarAlignment(value) self.barAlignment=value end
    function C:SetTexture(value) self.texture=value end
    function C:GetTextureFileName() return self.texture end
    function C:SetTextureCoords(...) self.coords={...} end
    function C:GetTextureCoords() return unpack(self.coords or {0,1,0,1}) end
    for _, method in ipairs({'SetEdgeColor','SetDrawTier','SetDrawLayer','SetDrawLevel'}) do
        C[method]=function() end
    end
    GuiRoot=control('GuiRoot'); GuiRoot:SetDimensions(1920,1080)
    WINDOW_MANAGER={CreateControl=function(_,name,parent) return control(name,parent) end,
        CreateTopLevelWindow=function(_,name) return control(name,GuiRoot) end,
        CreateControlFromVirtual=function(_,name,parent,template)
            assert(template=='ZO_ArrowStatusBarWithBG' or template=='ZO_TargetAttributeStatusBar_Keyboard_Template'
                or template=='ZO_TargetAttributeStatusBarGloss_Keyboard_Template','unsupported native template: '..template)
            local bar=control(name,parent);bar.template=template
            if template=='ZO_ArrowStatusBarWithBG' then
                bar.gloss=control(name..'Gloss',bar)
                control(name..'BG',bar);control(name..'Overlay',bar)
            end
            return bar
        end}
    -- Native target frame: HP, then the name below it. Moving the frame must
    -- move the addon through anchors without rewriting the native controls.
    ZO_TargetUnitFramereticleover=control('ZO_TargetUnitFramereticleover',GuiRoot)
    H.target=ZO_TargetUnitFramereticleover;H.target:SetDimensions(281,23)
    H.target:SetAnchor(TOP,GuiRoot,TOP,0,88)
    H.targetText=control(H.target.name..'TextArea',H.target);H.targetText:SetDimensions(150,22)
    H.targetText:SetAnchor(TOP,H.target,BOTTOM,0,7)
    H.hp=control(H.target.name..'BgContainer',H.target);H.hp:SetDimensions(281,23)
    H.hp:SetAnchor(CENTER,H.target,CENTER)
    for _,suffix in ipairs({'FrameLeft','FrameRight','FrameCenter'}) do
        local c=control(H.target.name..suffix,H.target);c:SetDimensions(21,23)
        c:SetTexture('EsoUI/Art/UnitAttributeVisualizer/targetBar_dynamic_frame.dds')
    end
    H.healthNumbers=control(H.target.name..'ResourceNumbers',H.target)
    H.healthNumbers.face='EsoBold';H.healthNumbers.fontSize=18;H.healthNumbers.text='40K 100%'
    H.luiNumbers=control(H.target.name..'LUIEExtenderLabel',H.target)
    H.luiNumbers.face='LuiFont';H.luiNumbers.fontSize=16
    H.caption=control(H.target.name..'Caption',H.target);H.caption:SetDimensions(150,22)
    H.caption:SetAnchor(TOP,H.targetText,BOTTOM,0,1);H.caption:SetHidden(true)
    EVENT_MANAGER={RegisterForEvent=function(_,ns,id,fn) H.events[id]=fn end,
        UnregisterForEvent=function(_,ns,id) H.events[id]=nil end,
        RegisterForUpdate=function(_,id,interval,fn) H.updates[id]={interval=interval,fn=fn} end,
        UnregisterForUpdate=function(_,id) H.updates[id]=nil end}
    ZO_SimpleSceneFragment={New=function(_,root)
        return {Show=function() H.sceneVisible=true;root:SetHidden(false) end,
            Hide=function() H.sceneVisible=false;root:SetHidden(true) end}
    end}
    HUD_SCENE={AddFragment=function(_,fragment) H.fragments[#H.fragments+1]=fragment end}
    HUD_UI_SCENE=HUD_SCENE
    SCENE_MANAGER={Show=function(_,scene) H.requestedScene=scene; H.fragments[1]:Show() end}
    ZO_SavedVars={NewCharacterIdSettings=function(_,name,version,namespace,defaults)
        local data={};for k,v in pairs(defaults) do data[k]=v end
        -- Do not let production rely on pairs() over the native saved-vars proxy.
        H.saved=setmetatable({}, {__index=data,__newindex=function(_,k,v)data[k]=v end})
        return H.saved
    end}
    LibAddonMenu2={RegisterAddonPanel=function(_,name) H.panel=control(name);return H.panel end,
        RegisterOptionControls=function(_,name,options) H.options=options end,
        OpenToPanel=function(_,panel) H.opened=panel end}
    SLASH_COMMANDS={}
    GetCVar=function() return 'ru' end
    ZO_AbbreviateAndLocalizeNumber=function(value,precision,lowercase)
        assert(precision==NUMBER_ABBREVIATION_PRECISION_TENTHS and lowercase==false)
        H.abbreviationCalls=(H.abbreviationCalls or 0)+1
        if value<1000 then return tostring(value) end
        local text=string.format('%.1f',math.floor(value/100+.5)/10):gsub('%.0$',''):gsub('%.',',')
        return text..'K'
    end
    ZO_FormatResourceBarCurrentAndMax=function(value,max,setting)
        assert(setting==RESOURCE_NUMBERS_SETTING_PERCENT_ONLY)
        local percent=value/max*100
        if percent>=10 then return math.floor(percent+.5) end
        return string.format('%.1f',percent):gsub('%.0$',''):gsub('%.',',')
    end
    DoesUnitExist=function() return H.exists end
    IsUnitAttackable=function() return true end
    IsUnitPlayer=function() return H.player end
    IsUnitDeadOrReincarnating=function() return H.dead end
    IsUnitJusticeGuard=function() return false end
    IsPlayerInAvAWorld=function() return false end
    IsActiveWorldBattleground=function() return false end
    GetUnitZoneIndex=function() return H.zone or 1 end
    GetZoneId=function(index) return index end
    GetCurrentZoneDungeonDifficulty=function() return H.difficulty end
    GetCurrentSubZonePOIIndices=function() return nil,nil end
    GetPOIInstanceType=function() return 0 end
    IsInstanceEndlessDungeon=function() return H.archive end
    GetCurrentZoneHouseId=function() return H.house and 10 or 0 end
    GetPlayerStat=function(stat) return stat==STAT_PHYSICAL_PENETRATION and H.physical or H.spell end
    GetUnitName=function() return H.name or 'Монстр' end
    GetItemLinkName=function(link) return 'Манекен '..assert(link:match('item:(%d+):'))..'^n' end
    GetUnitPower=function(tag,power)
        assert(tag=='reticleover' and power==COMBAT_MECHANIC_FLAGS_HEALTH)
        return H.health or 10000,H.maxHealth or 40000,H.maxHealth or 40000
    end
    GetFrameTimeSeconds=function() return H.now end
    GetNumBuffs=function() return #H.buffs end
    GetUnitBuffInfo=function(_,i)
        local b=H.buffs[i];return '',0,b.finish or 0,i,1,'',0,0,0,0,b.id,false,false
    end
    GetAbilityName=function() return '' end
    zo_strformat=function(_,text)return text:gsub('%^%a','') end
    GetSlotBoundId=function(slot) return H.fon and slot==5 and 276 or 0 end
    GetNumPointsSpentOnChampionSkill=function()return 50 end
    function H.fire(event) assert(H.events[event],event)() end
    function H.tick() for _,u in pairs(H.updates)do u.fn() end end
    function H.frame()
        local root=KanaPenetration.view.root
        if not root:IsHidden() and root.handlers.OnUpdate then root.handlers.OnUpdate(root) end
    end
    function H.option(name)
        for _,o in ipairs(H.options)do if o.name==name then return o end end
        error('Missing option '..name)
    end
    function H.load()
        KanaPenetration=nil
        for _,file in ipairs({'Model','Observer','View','Settings','Core'})do dofile('KanaPenetration/'..file..'.lua') end
        H.events[EVENT_ADD_ON_LOADED](EVENT_ADD_ON_LOADED,'unrelated')
        assert(not KanaPenetration.view,'unrelated load event initialized addon')
        H.events[EVENT_ADD_ON_LOADED](EVENT_ADD_ON_LOADED,'KanaPenetration')
        return KanaPenetration
    end
    return H
end
