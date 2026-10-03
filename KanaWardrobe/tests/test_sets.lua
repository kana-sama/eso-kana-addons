local Fake = dofile(ROOT .. "/tests/support/fake_eso.lua")
local function setup()
    local KW = Fake.Load()
    local f=io.open(ROOT .. "/SetModel.lua", "r")
    if f then f:close(); dofile(ROOT .. "/SetModel.lua") end
    assert(KW.SetModel and KW.SetModel.Build, "SetModel.Build is not implemented")
    return KW
end
local function meta(setId, extra)
    local m={valid=true,availableToEquip=true,setId=setId or 10,familyId=setId or 10,
        setName="Set",perfected=false,twoHanded=false,weight=1,max=5,
        bonuses={{required=2,description="Two",perfected=false},{required=5,description="Five",perfected=false}}}
    for k,v in pairs(extra or {}) do m[k]=v end
    return m
end
local function fixture(KW)
    local preset={slots={}}
    local data={}
    local function add(slot, m)
        local link="link"..tostring(slot)
        preset.slots[slot]={kind="item",uid="uid"..tostring(slot),link=link}
        data[link]=m or meta()
        return link
    end
    local function build() return KW.SetModel.Build(preset,function(ref) return data[ref.link] end) end
    return preset,data,add,build
end
local function previewEnvironment(callback)
    local saved={}
    local function install(key,value) saved[key]={_G[key]}; _G[key]=value end
    for _,key in ipairs({"CENTER","TOPLEFT","TOPRIGHT","BOTTOMLEFT","BOTTOMRIGHT","CT_CONTROL","CT_LABEL","CT_BACKDROP","CT_TEXTURE","DL_CONTROLS","TEXT_ALIGN_LEFT","TEXT_ALIGN_RIGHT"}) do
        install(key,key)
    end
    install("ZO_SCROLL_BAR_WIDTH",16)
    install("GetString",function(_,kind)return ({[1]="Light",[2]="Medium",[3]="Heavy"})[kind] or "Trait" end)
    local function control(name,parent,kind)
        local c={name=name,parent=parent,kind=kind,children={},handlers={},anchors={},width=320,height=500,scale=1}
        function c:GetName() return self.name end
        -- ESO renders controls through a TopLevelControl, not directly via GuiRoot.
        function c:HasVisibleWindow()
            local current=self;local window=false
            while current do
                if current.hidden then return false end
                if current.topLevel then window=true end
                current=current.parent
            end
            return window
        end
        function c:GetNamedChild(key)
            self.children[key]=self.children[key] or control(self.name..key,self); return self.children[key]
        end
        function c:SetHidden(value) self.hidden=value end
        function c:SetAlpha(value) self.alpha=value end
        function c:GetAlpha() return self.alpha or 1 end
        function c:IsHidden()return self.hidden==true end
        function c:SetDimensions(w,h) self.width=w; self.height=h end
        function c:SetWidth(w) self.width=w end
        function c:SetHeight(h) self.height=h end
        function c:SetScale(value) self.scale=value end
        function c:GetScale() return self.scale*(self.parent and self.parent:GetScale() or 1) end
        function c:ClearAnchors() self.anchors={} end
        function c:SetAnchor(point,relative,relativePoint,x,y)
            self.anchors[#self.anchors+1]={point=point,relative=relative,relativePoint=relativePoint,x=x or 0,y=y or 0}
        end
        local function coordinate(c,a,axis)
            local ending=axis=="x" and "RIGHT" or "BOTTOM"
            local relative=a.relative or c.parent
            local point=a.relativePoint or a.point
            local atEnd=point:find(ending,1,true)
            local base=axis=="x" and relative:GetLeft() or relative:GetTop()
            local size=axis=="x" and relative:GetWidth() or relative:GetHeight()
            return base+(atEnd and size or point==CENTER and size/2 or 0)+a[axis]*c:GetScale()
        end
        function c:GetWidth()
            if self.anchors[2] then return coordinate(self,self.anchors[2],"x")-self:GetLeft() end
            return self.width*self:GetScale()
        end
        function c:GetHeight()
            if self.anchors[2] and self.anchors[2].point:find("BOTTOM",1,true) then return coordinate(self,self.anchors[2],"y")-self:GetTop() end
            if self.kind==CT_LABEL then
                if not self.text or self.text=="" then return 0 end
                local plain=self.text:gsub("|c%x%x%x%x%x%x",""):gsub("|r","")
                local height=0
                for paragraph in (plain.."\n"):gmatch("(.-)\n")do
                    local _,length=paragraph:gsub("[^\128-\191]","")
                    height=height+math.max(1,math.ceil(length/math.max(1,math.floor(self.width/8))))*20
                end
                return math.min(height,(self.maxLines or math.huge)*20)*self:GetScale()
            end
            return self.height*self:GetScale()
        end
        function c:GetTextWidth()
            local plain=(self.text or ""):gsub("|c%x%x%x%x%x%x",""):gsub("|r","")
            local _,length=plain:gsub("[^\128-\191]","")
            return length*8
        end
        function c:GetRight() return self:GetLeft()+self:GetWidth() end
        function c:GetBottom() return self:GetTop()+self:GetHeight() end
        function c:GetLeft()
            local a=self.anchors[1];if not a then return self.left or 0 end
            local own=a.point:find('RIGHT',1,true) and 1 or a.point==CENTER and .5 or 0
            return coordinate(self,a,'x')-own*self.width*self:GetScale()
        end
        function c:GetTop()
            local a=self.anchors[1];if not a then return self.top or 0 end
            local own=a.point:find('BOTTOM',1,true) and 1 or a.point==CENTER and .5 or 0
            return coordinate(self,a,'y')-own*self.height*self:GetScale()
        end
        function c:SetText(value) self.text=value end
        function c:SetTexture(value)self.texture=value end
        function c:SetTextureCoords(...)self.textureCoords={...}end
        function c:SetHorizontalAlignment(value)self.align=value end
        function c:SetFont(value)self.font=value end
        function c:SetMaxLineCount(value)self.maxLines=value end
        function c:SetHandler(event,fn) self.handlers[event]=fn end
        function c:SetMouseEnabled(value) self.mouseEnabled=value end
        function c:SetDrawLayer(value) self.layer=value end
        function c:SetDrawLevel(value) self.level=value end
        for _,key in ipairs({"SetVertexColors","SetColor","SetCenterColor","SetEdgeColor","SetEdgeTexture",
            "SetResizeToFitDescendents","SetDrawTier","SetVerticalScroll","SetClampedToScreen"}) do c[key]=function() end end
        if kind==CT_CONTROL then c.SetColor=nil end
        return c
    end
    local root=control("Root"); root.width=1400; root.height=900
    install("GuiRoot",root)
    install("WINDOW_MANAGER",{
        CreateTopLevelWindow=function(_,name)
            local c=control(name,root);c.topLevel=true;return c
        end,
        CreateControl=function(_,name,parent,kind) return control(name,parent,kind) end,
        CreateControlFromVirtual=function(_,name,parent,template)
            local c=control(name,parent)
            if template=="ZO_ScrollContainer" then
                local scroll=c:GetNamedChild("Scroll")
                scroll:SetAnchor(TOPLEFT,c,TOPLEFT,0,0)
                scroll:SetAnchor(BOTTOMRIGHT,c,BOTTOMRIGHT,-ZO_SCROLL_BAR_WIDTH,0)
                scroll:GetNamedChild("Child"):SetAnchor(TOPLEFT,scroll,TOPLEFT,0,0)
            end
            return c
        end,
    })
    local nativeAddSet=function() error("Native AddSet should not render worn counts") end
    install("ZO_TOOLTIP_STYLES",{tooltip={width=400,fontFace="native"},bodyHeader={uppercase=true},bodySection={customSpacing=30,childSpacing=10},
        bodyDescription={},activeBonus={},inactiveBonus={},itemBonusSuppressedSection={},itemBonusSuppressedDescription={}})
    install("ZO_Tooltip",{
        AddSet=nativeAddSet,
        Initialize=function(self,c,styles)
            c.styles=styles; c.AddSet=self.AddSet; c.lines={}
            function c:GetStyle(key) return self.styles[key] end
            function c:Reset() self.lines={};self.height=0 end
            function c:SetClearOnHidden() end
            function c:AcquireSection(style)
                local section={lines={},style=style or {}}
                function section:AddLine(text,...) self.lines[#self.lines+1]={text=text,styles={...}} end
                return section
            end
            function c:AddSection(section)
                self.height=self.height+(section.style.customSpacing or 0)
                for i,line in ipairs(section.lines) do
                    self.lines[#self.lines+1]=line
                    local plain=line.text:gsub("|c%x%x%x%x%x%x",""):gsub("|r","")
                    -- Include explicit paragraphs as well as wrapping. A
                    -- constant tooltip height previously hid real overflows.
                    for paragraph in (plain.."\n"):gmatch("(.-)\n")do
                        local _,length=paragraph:gsub("[^\128-\191]","")
                        self.height=self.height+math.max(1,math.ceil(length/math.max(1,math.floor(self.styles.tooltip.width/8))))*20
                    end
                    if i>1 then self.height=self.height+(section.style.childSpacing or 0)end
                end
            end
            function c:AddSetRestrictions(id) self.restrictedSet=id end
            function c:AcquireStatusBar(style)
                -- ZO_TooltipStatusBar:ApplyStyles -> ZO_StatusBar_SetGradientColor:
                -- both endpoints are ZO_ColorDef instances with inherited methods.
                local colors=style.statusBarGradientColors
                local r,g,b,a=colors[1]:UnpackRGBA()
                local r1,g1,b1,a1=colors[2]:UnpackRGBA()
                self.barColors={r,g,b,a,r1,g1,b1,a1}
            end
            function c:LayoutItem(link,equipped,creator,full,preview,name,slot,locked,trade,extra)
                error("Preset summary must never render a whole item tooltip")
            end
        end,
    })
    install("ITEM_BONUS_SUPPRESSION_TYPE_NONE",0)
    install("GetItemSetSuppressionInfo",function(id) assert(id==10); return 7,321 end)
    install("ZO_Scroll_ResetToTop",function() end)
    install("MouseIsOver",function(c) return c.mouseOver==true end)
    local ok,err=pcall(callback,root,nativeAddSet,control,install)
    for key,value in pairs(saved) do _G[key]=value[1] end
    if not ok then error(err) end
end
return {
 resource_metrics_wrap_as_one_group=function()
        local KW=setup()
        previewEnvironment(function(root)
            dofile(ROOT..'/SummaryView.lua')
            local view=KW.SummaryView.New(root,'GroupedResources',root)
            local data={metrics={{icon='light',value='1'},{icon='medium',value='1'},{icon='heavy',value='5'},
                {icon='armor',value='[ 15401 | 13741 ]'},
                {key='health',icon='health',value='+3990'},
                {key='stamina',icon='stamina',value='+2568',recovery='+62/s'},
                {key='magicka',icon='magicka',value='+2568',recovery='+62/s'}},
                description={attributes={health=64,magicka=0,stamina=0}},sets={},rows={},details={},barGroups={},specials={}}
            for _,factor in ipairs({.75,1,1.5,2})do
             root:SetScale(factor)
             for _,width in ipairs({900,680,340,128})do
                view:Layout(data,width,'en')
                local icons={}
                for _,e in ipairs(view.controls)do
                    local c=e.control
                    if not c:IsHidden() and (c.texture=='health' or c.texture=='stamina' or c.texture=='magicka')then icons[#icons+1]=c end
                end
                assert(#icons==3)
                assert(icons[1]:GetTop()==icons[2]:GetTop() and icons[2]:GetTop()==icons[3]:GetTop(),'one resource was stranded on the next line')
                for _,c in ipairs(icons)do assert(c:GetRight()<=view.control:GetRight()-16*view.control:GetScale()+.1,'resource group exceeds available width')end
             end
            end
        end)
 end,
    attributes_share_metric_baseline_and_align_right_without_overlap=function()
        local KW=setup()
        previewEnvironment(function(root)
            dofile(ROOT.."/SummaryView.lua")
            local view=KW.SummaryView.New(root,"AttributeMetrics",root)
            local metrics={
                {icon="armor",value="7"},{icon="armor",value="10812"},
                {icon="health",recovery="+33.5/s"},
                {icon="stamina",value="+3702",recovery="+43.5/s"},
                {icon="magicka",recovery="+38.5/s"},
            }
            local data={metrics=metrics,sets={},rows={},details={},barGroups={},specials={},
                description={attributes={health=0,magicka=0,stamina=64}}}
            for _,scale in ipairs({.75,1,1.5,2})do
             root:SetScale(scale)
             for _,width in ipairs({1140,900,680,340,128})do
                view:Layout(data,width,"en")
                local points={};local stamina
                for _,e in ipairs(view.controls)do
                    local c=e.control
                    if not c:IsHidden() and c.kind==CT_LABEL then
                        if c.text=='0' or c.text=='64' then points[#points+1]=c end
                        if c.text:gsub('|c%x%x%x%x%x%x',''):gsub('|r','')=='+3702  +43.5/s' then stamina=c end
                        assert(c.text~='Attribute points')
                    end
                end
                assert(#points==3)
                assert(points[1]:GetTop()==points[3]:GetTop(),'point values must stay together')
                assert(math.abs(points[3]:GetRight()-(view.control:GetRight()-16*view.control:GetScale()))<.1,'point values must align to the right edge')
                if width>=900 then
                    assert(points[1]:GetTop()==stamina:GetTop(),'attributes must share the metric baseline when they fit')
                end
                for _,point in ipairs(points)do
                    for _,e in ipairs(view.controls)do
                        local c=e.control
                        if not c:IsHidden() and c.kind==CT_LABEL and c~=point then
                            local overlapX=math.min(c:GetRight(),point:GetRight())-math.max(c:GetLeft(),point:GetLeft())
                            local overlapY=math.min(c:GetBottom(),point:GetBottom())-math.max(c:GetTop(),point:GetTop())
                            assert(overlapX<=.1 or overlapY<=.1,'summary labels overlap')
                        end
                    end
                end
             end
            end
        end)
    end,
    complete_description_uses_soft_surface_for_attributes_without_equipment=function()
        local KW=setup();dofile(ROOT.."/BuildDescription.lua")
        previewEnvironment(function(root)
            dofile(ROOT.."/SummaryView.lua");dofile(ROOT.."/SetPreview.lua")
            local p=KW.SetPreview.New()
            p:SetSafeArea({x=40,y=60,width=340,height=300,scale=1})
            p:Show(root,{name="Points",description=KW.BuildDescription.Build({attributes={health=0,magicka=0,stamina=64,unspentAtCapture=7}})},root)
            assert(p.surface and p.background:IsHidden(),"partial build fell back to legacy black backdrop")
            assert(p.control:GetLeft()==40 and p.control:GetRight()<=380 and p.control:GetBottom()<=360)
            local values={};local firstZero
            for _,entry in ipairs(p.effectView.controls)do
                if not entry.control:IsHidden() and entry.control.text then
                    values[#values+1]=entry.control.text
                    if entry.control.text=='0' then firstZero=firstZero or entry.control end
                end
            end
            assert(not table.concat(values," "):find("Attribute points",1,true), "attribute label must be absent")
            local zeroes=0;for _,value in ipairs(values)do if value=="0"then zeroes=zeroes+1 end end
            assert(zeroes==2,"absolute zero points were omitted")
            assert(firstZero:GetTop()==p.effectView.control:GetTop()+6,'attribute summary must use the first row')
            assert(p.closeButton.parent==p.control and p.title.parent==p.control,"header/close must stay outside scroll")
        end)
    end,
    safe_area_changes_relayout_and_close_prevents_geometry_resurrection=function()
        local KW=setup();dofile(ROOT.."/BuildDescription.lua")
        previewEnvironment(function(root,_,control,install)
            local stopped=0;local closeCount=0
            install("ZO_AlphaAnimation",{New=function()return {FadeIn=function()end,Stop=function()stopped=stopped+1 end}end})
            dofile(ROOT.."/SummaryView.lua");dofile(ROOT.."/SetPreview.lua")
            local p=KW.SetPreview.New();p:SetCloseCallback(function()closeCount=closeCount+1 end)
            p:Show(root,{name="No bounds",description=KW.BuildDescription.Build({attributes={health=1,magicka=2,stamina=3}})},root)
            assert(p.control:IsHidden(),'new complete description guessed a placement before safe-area handoff')
            p:SetSafeArea({x=30,y=50,width=400,height=300,scale=1})
            p:Hide()
            local layouts=0;p:SetLayoutChangedCallback(function()layouts=layouts+1 end)
            p:Show(root,{name="Points",description=KW.BuildDescription.Build({attributes={health=1,magicka=2,stamina=3}})},root)
            p:SetSafeArea({x=30,y=50,width=400,height=300,scale=1});assert(layouts==1,'unchanged bounds rebuilt the description')
            p:SetSafeArea({x=30,y=50,width=200,height=150,scale=2})
            assert(p.control:GetLeft()==60 and p.control:GetTop()==100 and p.control:GetRight()<=460 and p.control:GetBottom()<=400,'safe-area native scale conversion failed')
            p:SetSafeArea({x=10,y=50,width=220,height=150,scale=1})
            assert(p.control:GetLeft()==10 and p.control:GetRight()<=230)
            p:SetSafeArea(nil);assert(p.control:IsHidden(),"missing safe area must hide instead of crossing native page")
            p:SetSafeArea({x=10,y=50,width=220,height=150,scale=1});assert(not p.control:IsHidden())
            local generation=p.generation;p.closeButton.handlers.OnClicked()
            assert(p.control:IsHidden() and closeCount==1 and p.generation>generation and stopped>0)
            p:SetSafeArea({x=20,y=50,width=300,height=150,scale=1})
            assert(p.control:IsHidden(),"geometry change reopened closed description")
        end)
    end,
    compact_skill_grids_bars_native_saved_tooltips_and_pool_reuse=function()
        local KW=setup();dofile(ROOT.."/BuildDescription.lua")
        previewEnvironment(function(root,_,control,install)
            local tip=control("SkillTooltip",root);tip.lines={};tip.calls={}
            function tip:GetOwner()return self.owner end
            function tip:AddLine(value)self.lines[#self.lines+1]=value end
            for _,method in ipairs({"SetActiveSkill","SetPassiveSkill","SetAbilityId"})do
                tip[method]=function(self,...)self.calls[#self.calls+1]={method=method,args={...}}end
            end
            install("SkillTooltip",tip)
            install("InitializeTooltip",function(t,c)t.owner=c;t.hidden=false;t.lines={}end)
            install("ClearTooltipImmediately",function(t)t.owner=nil;t.hidden=true end)
            dofile(ROOT.."/SummaryView.lua");dofile(ROOT.."/SetPreview.lua")
            local function rec(kind,index)
                local native={}
                function native:GetIndices()return 1,2,index end
                function native:GetPointAllocator()error("saved tooltip consulted current allocator")end
                local function progression(value)return {GetName=function()return kind..value end,GetIcon=function()return kind..value..".dds"end,
                    GetAbilityId=function()return 100+value end,SetKeyboardTooltip=function()error("mutable native helper")end}end
                function native:GetMorphData(morph)return progression(morph)end
                function native:GetRankData(rank)return progression(rank)end
                return {native=native,available=true,mutable=true,lineId=10}
            end
            local catalog={available=true,byKey={['10:active:1']=rec('active',1),['10:passive:2']=rec('passive',2),['10:active:3']=rec('active',3)}}
            local saved={abilities={skills={['10:active:1']={kind='active',purchased=true,morph=2},['10:passive:2']={kind='passive',rank=0}},
                bars={front={[1]={kind='skill',skillKey='10:active:3',expectedMorph=1},[2]={kind='empty'}}}}}
            local p=KW.SetPreview.New();p:SetSafeArea({x=10,y=10,width=500,height=400,scale=1})
            p:Show(root,{name="Skills",description=KW.BuildDescription.Build(saved,catalog)},root)
            local v=p.effectView;assert(#v.skillIcons==2 and #v.barIcons==12)
            assert(v.skillIcons[1].width==28 and v.barIcons[1].width==32)
            assert(v.barIcons[2].texture~=v.barIcons[3].texture,"empty and unchanged bar slots look identical")
            v.skillIcons[1].hitTarget.handlers.OnMouseEnter();local active=tip.calls[#tip.calls]
            assert(active.method=='SetActiveSkill' and active.args[4]==2 and active.args[5]==true)
            for i=9,12 do assert(active.args[i]==false,"saved tooltip advertised current advice/cost")end
            v.skillIcons[2].hitTarget.handlers.OnMouseEnter();local passive=tip.calls[#tip.calls]
            assert(passive.method=='SetPassiveSkill' and passive.args[4]==1 and passive.args[5]==0 and passive.args[7]==false)
            assert(table.concat(tip.lines,' '):find('Disabled',1,true))
            v.barIcons[1].hitTarget.handlers.OnMouseEnter();local bar=tip.calls[#tip.calls]
            assert(bar.method=='SetAbilityId' and bar.args[1]==101,"bar-only reference invented purchase state")
            v.barIcons[1].hitTarget.handlers.OnMouseExit();assert(tip:IsHidden() and not p.control:IsHidden())
            p:Show(root,{name="Nothing",description=KW.BuildDescription.Build({})},root)
            assert(#v.skillIcons==0 and #v.barIcons==0)
            for _,entry in ipairs(v.controls)do if not entry.control:IsHidden()then assert(not entry.control.handlers.OnMouseEnter,"pool retained stale skill tooltip")end end
        end)
    end,
    skill_sections_compact_bars_branch_spacing_separator_and_hover_targets=function()
        local KW=setup()
        previewEnvironment(function(root,_,control,install)
            dofile(ROOT..'/SummaryView.lua')
            local tip=control('SkillTooltip',root)
            function tip:GetOwner()return self.owner end
            function tip:AddLine()end
            install('SkillTooltip',tip)
            install('InitializeTooltip',function(t,c)t.owner=c;t.hidden=false end)
            install('ClearTooltipImmediately',function(t)t.owner=nil;t.hidden=true end)
            local function skill(line,index)
                return {kind='active',name='Skill '..index,lineId=line,category=1,available=false,tooltip={}}
            end
            local d={bars={front={},back={},werewolf={}},enabled={},disabled={skill(11,6)}}
            for i=1,6 do d.bars.front[i]=skill(10,i);d.bars.back[i]=skill(20,i);d.bars.werewolf[i]=skill(50,i)end
            d.enabled={skill(10,1),skill(10,2),skill(20,3),skill(20,4),skill(30,5)}
            local data={description=d,metrics={},sets={{name='Set',value='5/5'}},rows={},details={},barGroups={},specials={}}
            local v=KW.SummaryView.New(root,'GroupedSkills',root)
            for _,scale in ipairs({.75,1,2})do
                root:SetScale(scale)
                for _,width in ipairs({128,500,1000})do
                    v:Layout(data,width)
                    local labels={}
                    for _,entry in ipairs(v.controls)do
                        if not entry.control:IsHidden() and entry.control.text then labels[entry.control.text]=true end
                    end
                    assert(labels['Bars'] and labels['Enabled talents'] and labels['Disabled talents'])
                    assert(not labels['Main bar'] and not labels['Backup bar'],'redundant individual bar headings')
                    if width>=500 then
                        assert(v.barIcons[1]:GetTop()==v.barIcons[7]:GetTop())
                        local gap=(v.barIcons[7]:GetLeft()-v.barIcons[6]:GetRight())/scale
                        assert(gap==24,'bars spread into unrelated halves of the panel')
                        assert(#v.barIcons==18)
                        if width>=1000 then assert(v.barIcons[13]:GetTop()==v.barIcons[1]:GetTop())
                        else assert(v.barIcons[13]:GetTop()>v.barIcons[1]:GetTop() and v.barIcons[13]:GetLeft()==v.barIcons[1]:GetLeft())end
                    end
                    if width>=500 then
                        local ordinary=(v.skillIcons[2]:GetLeft()-v.skillIcons[1]:GetRight())/scale
                        local branch=(v.skillIcons[3]:GetLeft()-v.skillIcons[2]:GetRight())/scale
                        assert(ordinary==2 and branch==12,'branch groups need a small distinct gap')
                    end
                    for _,icons in ipairs({v.skillIcons,v.barIcons})do
                        for _,icon in ipairs(icons)do
                            local hit=icon.hitTarget
                            assert(hit and hit.kind==CT_CONTROL and hit.mouseEnabled and not icon.mouseEnabled,
                                'native hover must target a control above the decorative texture')
                            assert(hit.layer==DL_CONTROLS and hit.level==1)
                            assert(hit:GetLeft()==icon:GetLeft() and hit:GetRight()==icon:GetRight())
                            assert(hit:GetTop()==icon:GetTop() and hit:GetBottom()==icon:GetBottom())
                            assert(icon:GetRight()<=v.control:GetRight())
                            hit.handlers.OnMouseEnter();assert(tip:GetOwner()==hit and not tip:IsHidden())
                            hit.handlers.OnMouseExit();assert(tip:IsHidden())
                        end
                    end
                    local last=v.skillIcons[#v.skillIcons]:GetBottom()
                    local sets=v.control:GetTop()+v.sections.setsTop*scale
                    local divider=false
                    for _,entry in ipairs(v.controls)do
                        local c=entry.control
                        if not c:IsHidden() and c.kind==CT_TEXTURE and not c.texture and c.height==1
                            and c:GetTop()>last and c:GetTop()<sets then divider=true end
                    end
                    assert(divider,'talents run directly into equipment sets')
                    assert(not v.control:IsHidden(),'hover exit closed the description')
                end
            end
            v:Layout({description={enabled={},disabled={}},metrics={},sets={{name='Set',value='1/5'}},rows={},details={},barGroups={},specials={}},500)
            assert(v.sections.setsTop==4,'empty skill section added blank space')
        end)
    end,
    talent_branches_remain_atomic_even_when_wider_than_available_row=function()
        local KW=setup()
        previewEnvironment(function(root)
            dofile(ROOT..'/SummaryView.lua')
            local d={enabled={},disabled={}}
            for _,group in ipairs({'enabled','disabled'})do
                for line=1,3 do
                    for index=1,(line==1 and 9 or 3)do
                        d[group][#d[group]+1]={lineId=line,category=1,name='Saved',kind='active',tooltip={}}
                    end
                end
            end
            local v=KW.SummaryView.New(root,'AtomicBranches',root)
            for _,scale in ipairs({.75,1,2})do
                root:SetScale(scale)
                for _,width in ipairs({128,260,500,1000})do
                    v:Layout({description=d,metrics={},sets={},rows={},details={},barGroups={},specials={}},width)
                    assert(#v.skillIcons==30)
                    for _,offset in ipairs({0,15})do
                        local branchStarts={1,10,13}
                        for group,start in ipairs(branchStarts)do
                            local last=group==1 and 9 or group==2 and 12 or 15
                            local top=v.skillIcons[offset+start]:GetTop()
                            for i=start,last do
                                local icon=v.skillIcons[offset+i]
                                assert(icon:GetTop()==top,'skill-line group split between rows')
                                assert(icon:GetRight()<=v.control:GetRight(),'atomic branch overflowed description')
                            end
                            if group>1 then
                                local before=v.skillIcons[offset+start-1]
                                local first=v.skillIcons[offset+start]
                                assert(first:GetTop()>before:GetTop() or first:GetLeft()-before:GetRight()>=12*scale,
                                    'whole branches overlap or lost their gap')
                            end
                        end
                    end
                end
            end
        end)
    end,
    canonical_equipment_description_uses_only_saved_items=function()
        local KW=setup();local equipment={[EQUIP_SLOT_HEAD]={kind='item',uid='one',link='head'}}
        local summary=KW.SetModel.Build({equipment=equipment},function(ref)assert(ref.uid=='one');return meta()end)
        assert(#summary.sets==1 and summary.sets[1].front==1 and summary.sets[1].back==1)
    end,
    saved_tooltips_keep_unresolved_crafted_and_foreign_native_owners=function()
        local KW=setup()
        previewEnvironment(function(root,_,control,install)
            local tip=control('SkillTooltip',root);tip.lines={}
            function tip:GetOwner()return self.owner end
            function tip:AddLine(line)self.lines[#self.lines+1]=line end
            function tip:SetAbilityId(id)self.ability=id end
            install('SkillTooltip',tip)
            install('InitializeTooltip',function(t,c)t.owner=c;t.hidden=false;t.lines={}end)
            install('ClearTooltipImmediately',function(t)t.owner=nil;t.hidden=true end)
            install('ResetCraftedAbilityScriptSelectionOverride',function()error('description reset native scribing draft')end)
            dofile(ROOT..'/SummaryView.lua')
            local v=KW.SummaryView.New(root,'Skills',root)
            local unavailable={name='42:active:7',available=false,kind='active',tooltip={inactive=true},
                unresolvedReason={code='skillUnavailable',details={reason='lineUnavailable'}}}
            local crafted={kind='skill',available=true,tooltip={kind='crafted',abilityId=777,
                progression={SetKeyboardTooltip=function()error('native helper mutates script override')end}}}
            v:ShowSavedTooltip(root,unavailable,false)
            assert(table.concat(tip.lines,' '):find('Skill line unavailable',1,true) and table.concat(tip.lines,' '):find('Disabled',1,true))
            v:ShowSavedTooltip(root,crafted,true);assert(tip.ability==777)
            local foreign=control('Other addon',root);tip.owner=foreign
            v:Hide();assert(not tip:IsHidden() and tip.owner==foreign,'hide cleared another native tooltip owner')
        end)
    end,
    compact_description_order_and_narrow_grids_preserve_every_slot=function()
        local KW=setup();dofile(ROOT..'/BuildDescription.lua')
        previewEnvironment(function(root)
            dofile(ROOT..'/SummaryView.lua')
            local skill={kind='active',name='Saved',available=false,tooltip={},unresolvedReason={details={reason='missingSkill'}}}
            local d=KW.BuildDescription.Build({attributes={health=0,magicka=2,stamina=3},abilities={bars={}}})
            d.enabled={skill,skill,skill,skill};d.disabled={skill}
            local v=KW.SummaryView.New(root,'Order',root)
            local data={description=d,metrics={{value='+123',icon='stat'}},sets={{name='Set name',value='5/5'}},
                rows={{name='Gear numeric',value='+20'}},details={'Special effect'},barGroups={},specials={}}
            v:Layout(data,500)
            local positions={};for _,entry in ipairs(v.controls)do if entry.control.text then positions[entry.control.text]=entry.control:GetTop()end end
            assert(positions['Attribute points']==nil and positions['0']==positions['+123'] and positions['+123']<positions['Bars'])
            assert(positions['Bars']<positions['Enabled talents'] and positions['Disabled talents']<positions['|cC9C3A4Set name|r'])
            assert(positions['|cC9C3A4Set name|r']<positions['|cC9C3A4Gear numeric|r'] and positions['|cC9C3A4Gear numeric|r']<positions['|cD5D1C1Special effect|r'])
            assert(v.barIcons[1]:GetTop()==v.barIcons[7]:GetTop(),'wide bars should share one compact row')
            v:Layout(data,128)
            assert(#v.barIcons==12 and #v.skillIcons==5)
            assert(v.barIcons[7]:GetTop()>v.barIcons[6]:GetTop(),'narrow bars should follow reading order')
            for _,icon in ipairs(v.barIcons)do assert(icon:GetRight()<=v.control:GetRight(),'narrow bar clipped a slot')end
            assert(v.skillIcons[4]:GetTop()==v.skillIcons[1]:GetTop(),'narrow skill grid split one branch')
        end)
    end,
    description_limits_long_header_and_native_popups_share_one_owner=function()
        local KW=setup();dofile(ROOT..'/BuildDescription.lua')
        previewEnvironment(function(root,_,control,install)
            local tip=control('SkillTooltip',root)
            function tip:GetOwner()return self.owner end
            function tip:AddLine()end
            install('SkillTooltip',tip)
            install('InitializeTooltip',function(t,c)t.owner=c;t.hidden=false end)
            install('ClearTooltipImmediately',function(t)t.owner=nil;t.hidden=true end)
            dofile(ROOT..'/SummaryView.lua');dofile(ROOT..'/SetPreview.lua')
            local p=KW.SetPreview.New();p:SetSafeArea({x=10,y=10,width=180,height=240,scale=1})
            p:Show(root,{name=string.rep('Long title ',30),description=KW.BuildDescription.Build({attributes={health=1,magicka=2,stamina=3}})},root)
            assert(p.title:GetHeight()<=40 and p.scroll:GetTop()<p.control:GetBottom(),'unbounded title consumes the available body height')
            local v=p.effectView;v:ShowSavedTooltip(root,{kind='empty'},true)
            v.tooltips={Hide=function()end,Show=function()end,Leave=function()end}
            local row=control('Gear row',root);v:Bind(row,{kind='item',link='item'});row.handlers.OnMouseEnter()
            assert(tip:IsHidden(),'gear hover left the skill popup visible')
            p:SetSafeArea({x=10,y=10,width=100,height=80,scale=1})
            assert(p.control:IsHidden() or p.scroll:GetHeight()>0,'header left a negative scroll viewport inside safe area')
        end)
    end,
    native_close_invalidates_real_ui_hover_and_preview_generation=function()
        local KW=setup();dofile(ROOT..'/BuildDescription.lua')
        previewEnvironment(function(root,_,control,install)
            local timers={};install('zo_callLater',function(fn)timers[#timers+1]=fn end)
            dofile(ROOT..'/Dialogs.lua');dofile(ROOT..'/SummaryView.lua');dofile(ROOT..'/SetPreview.lua');dofile(ROOT..'/UI.lua')
            local preview=KW.SetPreview.New();preview:SetSafeArea({x=20,y=20,width=400,height=300,scale=1})
            local preset={name='Points',attributes={health=1,magicka=2,stamina=3}}
            local session={GetView=function()return {state='idle',isEditor=false}end}
            local ui=KW.UI.New(KW.Presets.New({},'EU','@a','1','One'),session,preview,KW.Inventory.New(Fake.New()))
            ui.visible=true;root.mouseOver=true
            preview:Show(root,{name='Points',description=KW.BuildDescription.Build(preset)},root)
            ui:Hover({preset=preset,missing={}},root)
            local serial,generation=ui.hoverSerial,preview.generation
            preview.closeButton.handlers.OnClicked()
            for _,fn in ipairs(timers)do fn()end
            assert(ui.hoverSerial>serial and preview.generation>generation)
            assert(preview.control:IsHidden() and not preview.visible,'delayed UI Show reopened real native Close')
        end)
    end,
    source_tooltips_use_native_items_and_clear_on_relayout_hide_and_pool_reuse=function()
        local KW=setup();dofile(ROOT.."/EffectModel.lua")
        previewEnvironment(function(root,_,control,install)
            local timers={}
            install("zo_callLater",function(fn)timers[#timers+1]=fn end)
            local function tooltip(name)
                local c=control(name,root)
                c.calls={};c.lines={}
                function c:GetOwner()return self.owner end
                function c:SetLink(link)self.calls[#self.calls+1]=link end
                function c:AddLine(line)self.lines[#self.lines+1]=line end
                function c:AddControl(body)self.body=body end
                return c
            end
            local item,info=tooltip("ItemTooltip"),tooltip("InformationTooltip")
            install("ItemTooltip",item);install("InformationTooltip",info)
            install("InitializeTooltip",function(t,owner)t.owner=owner;t.hidden=false;t.lines={}end)
            install("ClearTooltipImmediately",function(t)t.owner=nil;t.hidden=true end)
            dofile(ROOT.."/PreviewTooltips.lua");dofile(ROOT.."/SummaryView.lua");dofile(ROOT.."/SetPreview.lua")
            local p=KW.SetPreview.New()
            local row=control("Preset",root);row.left=400;row.width=250;row.top=200
            local origin={link="Real item",uid="one",slot=0}
            local e=KW.EffectModel.Build({{slot=0,source=origin,metadata={enchant={description="Adds 100 Maximum Stamina."}}}}, {})
            e.details={{description="Special",sources={{source=origin,front=true,back=true}},front=true,back=true},
                {description="Paragraph one.\n\nParagraph two.",source="Source",sources={{source=origin,front=true,back=true}},front=true,back=true}}
            local summary={name="Preset",armor={},sets={{setName="Set",front=5,back=5,max=5,representativeLink="Set item"}},effects=e}
            p:Show(row,summary,row)
            local v=p.effectView
            local interactive={}
            for _,entry in ipairs(v.controls)do
                if entry.control.handlers.OnMouseEnter then interactive[#interactive+1]=entry.control end
            end
            assert(#interactive>=6,"set, stat, special, heading and every paragraph need hover targets")
            local setRow,special,metric
            for _,c in ipairs(interactive)do
                if c.kind==CT_CONTROL then setRow=c
                elseif c.text=="|cD5D1C1Special|r"then special=c
                elseif c.text and c.text:find("100",1,true)then metric=c end
            end
            setRow.handlers.OnMouseEnter()
            assert(item.calls[#item.calls]=="Set item")
            special.handlers.OnMouseEnter()
            assert(item.calls[#item.calls]=="Real item")
            metric.handlers.OnMouseEnter()
            assert(item:IsHidden() and info.body and not info:IsHidden())
            local function assertTooltipBody()
                -- Native AddControl registers a cell; it does not anchor the
                -- supplied control. ESO's own tooltip containers then anchor
                -- CENTER with an implicit relative control (the tooltip cell).
                local anchors=info.body.anchors
                assert(#anchors==1 and anchors[1].point==CENTER and anchors[1].relative==nil,
                    "breakdown body must be anchored inside its native tooltip cell, not at screen origin")
                assert(info.body.width>0 and info.body.height>0)
                local body=v.tooltips
                local viewport=body.scroll:GetNamedChild("Scroll")
                assert(body.child.anchors[1].relative==viewport and body.child.anchors[2].relative==viewport
                    and body.child.anchors[2].point==TOPRIGHT,
                    "content must follow the actual scroll viewport width")
                for _,label in ipairs(body.labels)do
                    if not label:IsHidden()then
                        assert(label.anchors[1].relative==body.child)
                        assert(label.width<=info.body.width-ZO_SCROLL_BAR_WIDTH-12,
                            "numeric columns must remain within the tooltip content width")
                        if label.align==TEXT_ALIGN_RIGHT then
                            assert(label.anchors[1].point==TOPRIGHT and label.anchors[1].x==0,
                                "values must follow the visible right edge instead of a fixed horizontal offset")
                        end
                    end
                end
            end
            assertTooltipBody()
            -- Repeated hovers clear native cells and reuse the same body.
            metric.handlers.OnMouseEnter()
            assertTooltipBody()
            local text={};for _,label in ipairs(v.tooltips.labels)do if not label:IsHidden()then text[#text+1]=label.text end end
            assert(#text==2 and text[1]=="Real item" and text[2]=="+100",
                "breakdown must contain only item names and effect values")
            v.tooltips:Show(metric,{kind="breakdown",title="Must not render",differentBars=true,
                rows={{name="Weapon",value="[ +6% | +3% ]"}}})
            text={};for _,label in ipairs(v.tooltips.labels)do if not label:IsHidden()then text[#text+1]=label.text end end
            assert(#text==2 and text[1]=="Weapon" and text[2]=="[ +6% | +3% ]",
                "bar differences belong in the value column, without extra headers or columns")
            -- Layout must follow the actual viewport, including its insets,
            -- rather than assuming the stock scrollbar is its only padding.
            for _,factor in ipairs({.75,1,2})do
                info:SetScale(factor)
                local viewport=v.tooltips.scroll:GetNamedChild('Scroll')
                viewport.anchors[2].x=-ZO_SCROLL_BAR_WIDTH-40
                v.tooltips:Show(metric,{kind='breakdown',rows={
                    {name='Сапоги материнских объятий с длинным названием',value='[ +142 | +61 ]'},
                    {name='Вторая вещь',value='+12'},
                }})
                local name,value,nextName=v.tooltips.labels[1],v.tooltips.labels[2],v.tooltips.labels[3]
                assert(name:GetRight()+16*name:GetScale()<=value:GetLeft()+.1,'item name collides with its effect column')
                assert(nextName:GetTop()>=math.max(name:GetBottom(),value:GetBottom())+6*name:GetScale()-.1,'wrapped row collides with the next item')
                assert(value:GetRight()<=v.tooltips.child:GetRight()+.1)
                assert(value:GetWidth()/value:GetScale()>=value:GetTextWidth(),'bar values should fit their measured column')
            end
            info:SetScale(1)
            info.mouseOver=true;metric.handlers.OnMouseExit()
            local pending=timers;timers={};for _,fn in ipairs(pending)do fn()end
            assert(not info:IsHidden() and p:ContainsMouse(),"crossing into tooltip must keep preview open")
            p:Hide();assert(info:IsHidden() and v.tooltips.body:IsHidden())
            for _,fn in ipairs(timers)do fn()end
            p:Show(row,{name="Empty",armor={},sets={},effects={stats={},details={}}},row)
            for _,entry in ipairs(v.controls)do
                if not entry.control:IsHidden()then assert(not entry.control.handlers.OnMouseEnter,"reused control retained stale source")end
            end
            assert(info:IsHidden())
            -- Never clear a native tooltip taken over by another inventory row.
            v.tooltips:Show(setRow,{kind="item",link="Set item"})
            item.owner=control("Other inventory row",root)
            p:Hide();assert(not item:IsHidden())
        end)
    end,
    preview_fades_only_when_opening_and_stops_on_hide=function()
        local KW=setup();dofile(ROOT.."/EffectModel.lua")
        previewEnvironment(function(root,_,control,install)
            local created,starts,stops=0,0,0
            install("ZO_ALPHA_ANIMATION_OPTION_FORCE_ALPHA",2)
            install("ZO_ALPHA_ANIMATION_OPTION_PREVENT_CALLBACK",1)
            install("ZO_AlphaAnimation",{New=function(_,target)
                created=created+1
                return {
                    FadeIn=function(self,delay,duration,option)
                        assert(delay==0 and duration==160 and option==2)
                        starts=starts+1;self.playing=true;target:SetAlpha(0)
                    end,
                    Stop=function(self,option)
                        assert(option==1);stops=stops+1;self.playing=false
                    end,
                }
            end})
            dofile(ROOT.."/SummaryView.lua");dofile(ROOT.."/SetPreview.lua")
            local row=control("Row",root);row.left=100;row.width=250;row.top=200
            local other=control("Other",root);other.left=100;other.width=250;other.top=240
            local summary={name="A",armor={},sets={},effects={stats={},details={}}}
            local p=KW.SetPreview.New();p:Show(row,summary)
            assert(starts==1 and p.control:GetAlpha()==0 and not p.control:IsHidden())
            p.control:SetAlpha(.5)
            summary.name="B";p:Show(other,summary);p:Refresh(summary)
            assert(starts==1 and p.control:GetAlpha()==.5,"switching rows must continue the existing fade")
            p:Hide()
            assert(stops==1 and not p.appearance.playing and p.control:IsHidden() and p.control:GetAlpha()==1)
            p:Show(row,summary)
            assert(starts==2 and created==1,"reopening must reuse the animation")
        end)
    end,
    experimental_summary_uses_composition_and_total_effects_without_item_cards=function()
        local KW=setup();dofile(ROOT.."/EffectModel.lua")
        previewEnvironment(function(root,_,control)
            dofile(ROOT.."/SummaryView.lua");dofile(ROOT.."/SetPreview.lua")
            root.width=2400;root.height=1350
            local _,_,add,build=fixture(KW)
            add(EQUIP_SLOT_HEAD,meta(10,{armorType=2,enchant={description="Adds 100 Maximum Stamina."}}))
            add(EQUIP_SLOT_CHEST,meta(10,{armorType=2,enchant={description="Adds 220 Maximum Stamina."}}))
            local summary=build()
            local row=control("Row",root);row.left=550;row.width=280;row.top=320
            local preview=KW.SetPreview.New();preview:Show(row,summary)
            local data=preview.effectView.data
            assert(data.metrics[1].value=="2" and data.sets[1].value=="|cE6C65B2/5|r" and data.metrics[2].value=="+320")
            assert(#preview.cards==0 and not preview.overview)
            local sections=preview.effectView.sections
            assert(sections.metricsBottom<sections.setsTop and sections.setsTop<sections.effectsTop)
            assert(not preview.needsScroll and preview.control:GetRight()<=root:GetRight()-8)
            preview:Hide();assert(not preview:ContainsMouse())
        end)
    end,
    effect_grid_stacks_sections_aligns_numbers_and_reuses_controls=function()
        local KW=setup();dofile(ROOT.."/EffectModel.lua")
        previewEnvironment(function(root,_,control)
            dofile(ROOT.."/SummaryView.lua");dofile(ROOT.."/SetPreview.lua")
            root.width=2400;root.height=1350
            local row=control("Row",root);row.left=565;row.width=285;row.top=410
            local summary={name="Preset",armor={[2]=7},sets={{setName="Set",front=5,back=5,max=5}},effects={armor={front=7000,back=7000},
                stats={power={front=742,back=742},penetration={front=3085,back=3085},critical={front=1268,back=1268},
                    criticalChance={front=6.2,back=0},statusChance={front=0,back=225},mundus={front=56.7,back=56.7}},
                details={{description=string.rep("Special effect. ",20),front=true,back=true}}}}
            local p=KW.SetPreview.New();p:Show(row,summary)
            assert(not p.needsScroll and p.control:GetHeight()<600)
            local v=p.effectView
            assert(v.sections.detailsTop>v.sections.effectsTop and v.sections.effectsTop>v.sections.setsTop)
            local edges={};local texts={}
            for _,entry in ipairs(v.controls)do
                local c=entry.control
                if not c:IsHidden()then
                    assert(c:GetLeft()>=v.control:GetLeft() and c:GetRight()<=v.control:GetRight()+0.1)
                    assert(c:GetBottom()<=v.control:GetBottom()+0.1)
                    if c.align==TEXT_ALIGN_RIGHT and c.font=="ZoFontHeader" then
                        local edge=c:GetRight();edges[edge]=(edges[edge] or 0)+1
                    end
                    if c.text then texts[#texts+1]=c.text end
                end
            end
            local edgeCount=0;for _,count in pairs(edges)do edgeCount=edgeCount+1;assert(count>=2)end
            assert(edgeCount==2,"numeric values must share exactly two column edges")
            local short=KW.Copy(summary);short.effects.stats={};short.effects.details={};short.sets={}
            p:Show(row,short);p:Show(row,summary)
            local allocated=#v.controls
            for i=1,10 do p:Show(row,short);p:Show(row,summary)end
            assert(#v.controls==allocated,"hover must reuse controls instead of leaking a new layout")
            root.width=1100;root.height=700;row.left=40;row.width=250
            p:Show(row,summary)
            assert(p.control:GetLeft()>=8 and p.control:GetRight()<=root:GetRight()-8)
            assert(p.control:GetBottom()<=root:GetBottom()-8)
        end)
    end,
    compound_effect_follows_bar_groups_with_separator_and_no_top_bar_legend=function()
        local KW=setup();dofile(ROOT.."/EffectModel.lua")
        previewEnvironment(function(root,_,control)
            dofile(ROOT.."/SummaryView.lua");dofile(ROOT.."/SetPreview.lua")
            root.width=2400;root.height=1350
            local anchor=control("Anchor",root);anchor.left=565;anchor.width=285;anchor.top=410
            local long="One compound effect.\n\nIts second paragraph.\n\nIts last paragraph."
            local summary={name="Preset",armor={},sets={},effects={stats={criticalChance={front=6,back=0}},details={
                {description=long,source="Mythic set",front=true,back=true},
                {description="Main proc",front=true,back=false},
                {description="Shared proc",front=true,back=true},
                {description="Backup proc",front=false,back=true}}}}
            local p=KW.SetPreview.New();p:Show(anchor,summary)
            assert(p.message:IsHidden() and p.message.text=="","there must be no I/II legend above the metrics")
            local labels,rules={},{}
            for _,entry in ipairs(p.effectView.controls)do
                local c=entry.control
                if not c:IsHidden() then
                    if c.kind==CT_LABEL then labels[c.text:gsub("|c%x%x%x%x%x%x",""):gsub("|r","")]=c
                    elseif c.kind==CT_TEXTURE and c:GetHeight()==1 then rules[#rules+1]=c end
                end
            end
            assert(not labels[long] and labels["One compound effect."] and labels["Its second paragraph."] and labels["Its last paragraph."])
            assert(labels["Main proc"] and labels["Backup proc"])
            local front=p.effectView.data.barGroups[1].title;local back=p.effectView.data.barGroups[2].title
            assert(labels[front]:GetTop()>labels["Shared proc"]:GetBottom())
            assert(labels["Main proc"]:GetTop()>labels[front]:GetBottom())
            assert(labels[back]:GetTop()==labels[front]:GetTop())
            assert(labels[back]:GetLeft()>labels[front]:GetRight())
            assert(labels["Mythic set"]:GetTop()>math.max(labels["Backup proc"]:GetBottom(),labels["Main proc"]:GetBottom()))
            assert(labels["One compound effect."]:GetTop()>labels["Mythic set"]:GetBottom())
            local precedingRule=false
            for _,rule in ipairs(rules)do if rule:GetTop()==labels["Mythic set"]:GetTop()-12 then precedingRule=true end end
            assert(precedingRule,"the compound effect must have its own separator")
        end)
    end,
    special_text_columns_keep_reading_order_balance_wrapped_heights_and_reuse_controls=function()
        local KW=setup()
        previewEnvironment(function(root)
            dofile(ROOT.."/SummaryView.lua")
            local view=KW.SummaryView.New(root,"TestColumns",root)
            local values={"First short.","Second short.","Third short.",(string.rep("Fourth long paragraph. ",12):gsub(" $",""))}
            local data={metrics={},sets={},rows={},details=values,barGroups={},specials={
                {title="Source",description=table.concat(values,"\n\n")},
                {title="Next source",description="Last paragraph.\n\nClosing paragraph."}}}
            local function labels()
                local result={}
                for _,e in ipairs(view.controls)do
                    local c=e.control
                    if not c.hidden and c.kind==CT_LABEL then
                        local t=c.text:gsub("|c%x%x%x%x%x%x",""):gsub("|r","")
                        result[t]=result[t] or {};table.insert(result[t],c)
                    end
                end
                return result
            end
            local h=view:Layout(data,1000,"en");local l=labels()
            -- A count-based 2+2 split is much taller here; the three short
            -- paragraphs belong left, the long fourth belongs right.
            for instance=1,2 do
                local a,b,c,d=l[values[1]][instance],l[values[2]][instance],l[values[3]][instance],l[values[4]][instance]
                assert(a:GetLeft()==b:GetLeft() and b:GetLeft()==c:GetLeft())
                assert(b:GetTop()>a:GetBottom() and c:GetTop()>b:GetBottom())
                assert(d:GetLeft()>c:GetRight() and d:GetTop()==a:GetTop())
                assert(a:GetWidth()==d:GetWidth() and a:GetWidth()<500)
            end
            assert(l.Source[1]:GetTop()>l[values[4]][1]:GetBottom())
            assert(l["Next source"][1]:GetTop()>math.max(l[values[3]][2]:GetBottom(),l[values[4]][2]:GetBottom()))
            local allocated=#view.controls
            assert(view:Layout(data,1000,"en")==h and #view.controls==allocated)
            view:Layout(data,380,"en");l=labels()
            assert(l[values[4]][1]:GetTop()>l[values[3]][1]:GetBottom(),"narrow panels preserve linear reading order")
            for _,e in ipairs(view.controls)do if not e.control.hidden then
                assert(e.control:GetRight()<=view.control:GetRight()+.01)
                assert(e.control:GetBottom()<=view.control:GetBottom()+.01)
            end end
        end)
    end,
    description_has_own_content_sized_surface_at_fixed_top_with_native_stat_fonts=function()
        local KW=setup();dofile(ROOT.."/EffectModel.lua")
        previewEnvironment(function(root,_,control)
            dofile(ROOT.."/SummaryView.lua");dofile(ROOT.."/SetPreview.lua")
            root.width=2400;root.height=1350
            local panel=control("Panel",root);panel.left=550;panel.width=300;panel.top=300;panel.height=650
            local row=control("Row",root);row.left=570;row.width=260;row.top=420
            local summary={name="Preset",armor={},sets={},effects={stats={power={front=100,back=100}},details={}}}
            local p=KW.SetPreview.New();local layouts=0
            p:SetLayoutChangedCallback(function()layouts=layouts+1 end)
            p:Show(row,summary,panel)
            assert(p.control:GetTop()==panel:GetTop() and p.control:GetLeft()==panel:GetRight()+36)
            assert(p.control:GetHeight()<panel:GetHeight(),"short description must not leave an empty block below")
            assert(p.background:IsHidden() and not p.headingDivider:IsHidden())
            assert(p.surface and #p.surface.tiles==9)
            assert(p.background:GetLeft()==p.control:GetLeft() and p.background:GetRight()==p.control:GetRight())
            assert(p.background:GetBottom()==p.control:GetBottom())
            assert(p.title.font=="ZoFontHeader4")
            local boldName=false
            for _,e in ipairs(p.effectView.controls)do
                if e.control.text and e.control.text:find("Weapon and spell damage",1,true)then
                    boldName=e.control.font=="ZoFontHeader"
                end
            end
            assert(boldName,"stat names must match native character stat typography")
            row.top=600;p:Show(row,summary,panel)
            assert(p.control:GetTop()==panel:GetTop(),"hovering another row must not move the section")
            assert(layouts==2);p:Hide();assert(layouts==3)
        end)
    end,
    separate_description_stops_before_bag_and_scrolls_after_height_limit=function()
        local KW=setup();dofile(ROOT.."/EffectModel.lua")
        previewEnvironment(function(root,_,control)
            dofile(ROOT.."/SummaryView.lua");dofile(ROOT.."/SetPreview.lua")
            root.width=2400;root.height=1350
            local panel=control("Panel",root);panel.left=550;panel.width=300;panel.top=300;panel.height=550
            local old=ZO_PlayerInventory
            local bag=control("Bag",root);bag.left=1800;ZO_PlayerInventory=bag
            local ok,err=pcall(function()
                local summary={name="Preset",armor={},sets={},effects={stats={},details={{description=string.rep("Long effect. ",600),source="Set",front=true,back=true}}}}
                local p=KW.SetPreview.New();p:Show(panel,summary,panel)
                assert(p.control:GetRight()<=bag:GetLeft()-24,"leave a gap before bag")
                assert(p.control:GetTop()==panel:GetTop() and p.control:GetBottom()<=root:GetBottom()-64)
                assert(p.needsScroll and p.child:GetHeight()>p.scroll:GetHeight())
                bag.left=1150;p:Show(panel,summary,panel)
                assert(p.control:GetLeft()>=panel:GetRight()+12)
                assert(p.control:GetRight()<=bag:GetLeft()-24,"a narrow gap must not trigger screen-wide overlap")
            end)
            ZO_PlayerInventory=old;assert(ok,err)
        end)
    end,
    preview_widens_long_descriptions_before_resorting_to_scroll=function()
        local KW=setup()
        previewEnvironment(function(root,_,control)
            dofile(ROOT.."/SummaryView.lua");dofile(ROOT.."/SetPreview.lua")
            root.width=2400;root.height=800
            local _,_,add,build=fixture(KW);add(EQUIP_SLOT_HEAD,meta(10,{armorType=2}))
            local summary=build();summary.sets[1].bonuses[2].description=string.rep("A long bonus. ",300)
            local anchor=control("Row",root);anchor.left=400;anchor.width=200
            local preview=KW.SetPreview.New();preview:Show(anchor,summary)
            assert(not preview.needsScroll,"widen text columns into unused space before adding scroll")
            assert(preview.control:GetWidth()>1000)
        end)
    end,
    preview_scrolls_only_real_overflow_and_keeps_all_cards_reachable=function()
        local KW=setup()
        previewEnvironment(function(root,_,control)
            dofile(ROOT.."/SummaryView.lua");dofile(ROOT.."/SetPreview.lua")
            root.width=900;root.height=600
            local _,_,add,build=fixture(KW);add(EQUIP_SLOT_HEAD)
            local summary=build();summary.sets[1].bonuses[2].description=string.rep("A long bonus. ",100)
            for i=2,8 do summary.sets[i]=KW.Copy(summary.sets[1])end
            local anchor=control("Row",root);anchor.left=380;anchor.width=180
            local preview=KW.SetPreview.New();preview:Show(anchor,summary)
            assert(preview.needsScroll and preview.child:GetHeight()>preview.scroll:GetHeight())
            for _,card in ipairs(preview.cards)do assert(card.control:GetBottom()<=preview.child:GetBottom()+0.01)end
            assert(preview.control:GetBottom()<=root:GetBottom())
        end)
    end,
    preview_uses_available_width_for_overview_and_three_sets_without_scroll=function()
        local KW=setup()
        previewEnvironment(function(root,_,control)
            dofile(ROOT.."/SummaryView.lua");dofile(ROOT.."/SetPreview.lua")
            root.width=2400;root.height=1200
            local _,_,add,build=fixture(KW)
            add(EQUIP_SLOT_HEAD,meta(10,{armorType=2,enchant={name="Recovery",description="Stamina recovery +76."}}))
            add(EQUIP_SLOT_RING1,meta(10,{enchant={name="Recovery",description="Stamina recovery +90."}}))
            local summary=build()
            for i=2,3 do summary.sets[i]=KW.Copy(summary.sets[1])end
            for _,card in ipairs(summary.sets)do
                card.bonuses[2].description=string.rep("Long but readable bonus description. ",10)
            end
            local anchor=control("Row",root);anchor.left=570;anchor.width=260;anchor.top=340
            local preview=KW.SetPreview.New();preview:Show(anchor,summary)
            local overview=preview.overview.control
            for _,card in ipairs(preview.cards)do
                assert(card.control:GetTop()==overview:GetTop(),"sets must sit beside the summary, not below it")
            end
            assert(preview.cards[3].control:GetLeft()>preview.cards[2].control:GetRight())
            assert(preview.control:GetRight()<=root:GetRight()-8)
            assert(not preview.needsScroll and preview.child:GetHeight()<=preview.scroll:GetHeight(),"do not scroll when horizontal space is free")
            assert(preview.styles.bodySection.childSpacing<=3 and preview.styles.bodySection.customSpacing==0,"native gamepad margins must not leak into compact summary")
        end)
    end,
    summary_sums_localized_decimals_and_multiple_passive_values_without_summing_proc_duration=function()
        local KW=setup();local _,_,add,build=fixture(KW)
        add(EQUIP_SLOT_HEAD,meta(0,{enchant={name="Resources",description="Здоровье +|cffffff1 000|r, магия +250,5.",language="ru"},trait={id=7,name="Training",description="Gain 9% experience."}}))
        add(EQUIP_SLOT_CHEST,meta(0,{enchant={name="Resources",description="Здоровье +500, магия +100,5.",language="ru"},trait={id=7,name="Training",description="Gain 6% experience."}}))
        add(EQUIP_SLOT_MAIN_HAND,meta(0,{enchant={name="Drain",description="Deals 100 damage over 5 seconds.",hasCharges=true}}))
        add(EQUIP_SLOT_OFF_HAND,meta(0,{enchant={name="Drain",description="Deals 100 damage over 5 seconds.",hasCharges=true}}))
        local summary=build()
        assert(summary.enchants[1].descriptionFront=="Здоровье +1500, магия +351.")
        assert(summary.enchants[2].descriptionFront=="Deals 100 damage over 5 seconds.","proc duration and damage are not permanent additive stats")
        assert(#summary.traits==1 and summary.traits[1].front==2,"trait names should not split by magnitude")
    end,
    summary_sums_passive_enchants_and_groups_traits_per_bar=function()
        local KW=setup();local _,_,add,build=fixture(KW)
        local same={name="Stamina",description="Adds 100 stamina."}
        local trait={id=7,name="Training",description="Gain 9% experience."}
        add(EQUIP_SLOT_HEAD,meta(0,{armorType=2,enchant=same,trait=trait}))
        add(EQUIP_SLOT_CHEST,meta(0,{armorType=2,enchant=same,trait=trait}))
        add(EQUIP_SLOT_FEET,meta(0,{armorType=1,enchant={name="Stamina",description="Adds 50 stamina."}}))
        add(EQUIP_SLOT_MAIN_HAND,meta(0,{twoHanded=true,armorType=3,enchant={name="Drain",description="Deals 100 damage over 5 seconds.",hasCharges=true},trait=trait}))
        add(EQUIP_SLOT_BACKUP_MAIN,meta(0,{twoHanded=true,enchant={name="Drain",description="Deals 50 damage over 5 seconds.",hasCharges=true},trait={id=17,name="Training",description="Gain 6% experience."}}))
        local result=build()
        assert(result.armor[2]==2 and result.armor[1]==1 and result.armor[3]==nil,"only body armor counts")
        assert(#result.enchants==3,"passive magnitudes sum; weapon procs keep their actual values")
        assert(result.enchants[1].descriptionFront=="Adds 250 stamina." and result.enchants[1].descriptionBack=="Adds 250 stamina.")
        assert(result.enchants[2].descriptionFront=="Deals 100 damage over 5 seconds." and result.enchants[2].back==0)
        assert(result.enchants[3].descriptionBack=="Deals 50 damage over 5 seconds." and result.enchants[3].front==0)
        assert(#result.traits==1 and result.traits[1].front==3 and result.traits[1].back==3)
        assert(#result.sets==0,"nonset equipment still contributes to overview")
    end,
    summary_renders_armor_grouped_effects_without_item_clutter=function()
        local KW=setup()
        previewEnvironment(function(root)
            dofile(ROOT.."/SummaryView.lua");dofile(ROOT.."/SetPreview.lua")
            local _,_,add,build=fixture(KW)
            for _,slot in ipairs({EQUIP_SLOT_HEAD,EQUIP_SLOT_CHEST})do
                add(slot,meta(10,{armorType=2,enchant={name="Stamina",description="Adds 100 stamina."},trait={id=7,name="Training",description="Gain 9% experience."}}))
            end
            local preview=KW.SetPreview.New();preview:Show(root,build())
            local text={};for _,line in ipairs(preview.overview.tooltip.lines)do text[#text+1]=line.text end
            local content=table.concat(text,"\n")
            assert(content:find("Medium: 2",1,true) and not content:find("Heavy",1,true))
            assert(content:find("Adds 200 stamina.",1,true) and content:find("Training: 2",1,true))
            assert(not content:find("I:",1,true),"identical bars should use a single count")
            assert(not preview.overview.control.hidden)
            preview.overview.control.mouseOver=true;assert(preview:ContainsMouse())
        end)
    end,
    preview_has_renderable_window_for_default_and_guiroot_parent=function()
        local KW=setup()
        previewEnvironment(function(root)
            dofile(ROOT.."/SummaryView.lua");dofile(ROOT.."/SetPreview.lua")
            local _,_,add,build=fixture(KW);add(EQUIP_SLOT_HEAD)
            for _,explicitRoot in ipairs({false,true})do
                local preview=KW.SetPreview.New(explicitRoot and root or nil)
                preview:Show(root,build())
                assert(preview.control:HasVisibleWindow(),"preview has no top-level window: ESO will not render it")
                assert(preview.cards[1].tooltip:HasVisibleWindow(),"set card must belong to visible window")
                preview:Hide();assert(not preview.cards[1].tooltip:HasVisibleWindow())
                preview:Show(root,build());assert(preview.cards[1].tooltip:HasVisibleWindow())
            end
        end)
    end,
    preview_skips_item_condition_bars_and_keeps_styles_private=function()
        local KW=setup()
        previewEnvironment(function(root)
            local Color={}
            function Color:UnpackRGBA()return self.r,self.g,self.b,self.a end
            local first=setmetatable({r=.1,g=.2,b=.3,a=1},{__index=Color})
            local second=setmetatable({r=.4,g=.5,b=.6,a=.8},{__index=Color})
            local nativeBar={width=200,height=14,statusBarGradientColors={first,second}}
            ZO_TOOLTIP_STYLES.conditionOrChargeBar=nativeBar
            ZO_TOOLTIP_STYLES.bodyHeader.fontColor=first
            dofile(ROOT.."/SummaryView.lua");dofile(ROOT.."/SetPreview.lua")
            local _,_,add,build=fixture(KW);add(EQUIP_SLOT_HEAD)
            local preview=KW.SetPreview.New(root)
            local other=KW.SetPreview.New(root)
            for _=1,2 do
                preview:Show(root,build())
                assert(preview.cards[1].tooltip.barColors==nil,"preset summary must not build durability bars")
                preview:Hide()
            end
            assert(preview.styles.bodyHeader.fontColor==first,"native color objects stay intact")
            assert(preview.styles.conditionOrChargeBar.statusBarGradientColors[2]==second)
            preview.styles.conditionOrChargeBar.width=123
            preview.styles.tooltip.width=250
            assert(nativeBar.width==200 and other.styles.conditionOrChargeBar.width==200,"local overrides must stay private")
            assert(ZO_TOOLTIP_STYLES.tooltip.width==400 and other.styles.tooltip.width~=250)
        end)
    end,
    preview_uses_final_height_to_stay_beside_hovered_preset=function()
        local KW=setup()
        previewEnvironment(function(root,_,control)
            dofile(ROOT.."/SummaryView.lua");dofile(ROOT.."/SetPreview.lua")
            local _,_,add,build=fixture(KW); add(EQUIP_SLOT_HEAD)
            local anchor=control("Row",root); anchor.left=300;anchor.top=260;anchor.width=220
            local boundary=control("Panel",root);boundary.left=292;boundary.width=248
            local preview=KW.SetPreview.New(root);preview:Show(anchor,build(),boundary)
            assert(preview.control:GetTop()==anchor:GetTop(),"Short preview must align to hovered preset")
            assert(preview.control:GetLeft()>=boundary:GetRight()+10,"Preview overlaps panel")
            anchor.top=800;preview:Refresh(build())
            assert(preview.control:GetBottom()<=root:GetBottom(),"Preview extends below screen")
        end)
    end,
    preview_left_fallback_fits_multiple_columns_without_covering_anchor=function()
        local KW=setup()
        previewEnvironment(function(root,_,control)
            dofile(ROOT.."/SummaryView.lua");dofile(ROOT.."/SetPreview.lua")
            local _,_,add,build=fixture(KW);add(EQUIP_SLOT_HEAD)
            local summary=build();summary.sets[2]=KW.Copy(summary.sets[1])
            local anchor=control("Row",root);anchor.left=1000;anchor.width=220
            local preview=KW.SetPreview.New(root);preview:Show(anchor,summary)
            assert(preview.control:GetRight()<=anchor:GetLeft()-10,"Left fallback overlaps preset panel")
            assert(preview.control:GetLeft()>=0)
        end)
    end,
    preview_wrapped_header_does_not_collide_with_cards=function()
        local KW=setup()
        previewEnvironment(function(root,_,control)
            dofile(ROOT.."/SummaryView.lua");dofile(ROOT.."/SetPreview.lua")
            local _,_,add,build=fixture(KW);add(EQUIP_SLOT_HEAD)
            KW.Strings.SET_ITEMS_MISSING=string.rep("Unavailable item ",20)
            KW.Strings.PRESET_SETS=string.rep("Preset sets ",6)
            local summary=build();summary.availableToEquip=false
            local anchor=control("Row",root);anchor.left=200;anchor.width=220
            local preview=KW.SetPreview.New(root);preview:Show(anchor,summary)
            assert(preview.title:GetWidth()<=preview.control:GetWidth()-20)
            assert(preview.scroll:GetTop()>=preview.message:GetBottom()+10,"Wrapped warning covers first card")
            assert(preview.scroll:GetHeight()>0)
        end)
    end,
    preview_scaled_cards_fit_viewport_and_scroll_child=function()
        local KW=setup()
        previewEnvironment(function(root,_,control)
            dofile(ROOT.."/SummaryView.lua");dofile(ROOT.."/SetPreview.lua")
            local _,_,add,build=fixture(KW);add(EQUIP_SLOT_HEAD)
            local summary=build();for i=2,8 do summary.sets[i]=KW.Copy(summary.sets[1]) end
            local anchor=control("Row",root);anchor.left=400;anchor.top=260;anchor.width=220
            for _,scale in ipairs({0.75,1,1.4}) do
                local parent=control("Parent",root);parent:SetScale(scale)
                local preview=KW.SetPreview.New(parent);preview:Show(anchor,summary)
                assert(preview.control:GetLeft()>=0 and preview.control:GetRight()<=root:GetRight()+0.01)
                assert(preview.control:GetTop()>=0 and preview.control:GetBottom()<=root:GetBottom()+0.01)
                local first=preview.cards[1]
                assert(math.abs(first.control:GetHeight()-first.tooltip:GetHeight()-20*scale)<0.01,"Scaled tooltip height counted twice")
                assert(preview.child:GetWidth()<=preview.scroll:GetNamedChild("Scroll"):GetWidth()+0.01)
                assert(preview.cards[8].control:GetBottom()<=preview.child:GetBottom()+0.01,"Last set cannot be scrolled into view")
            end
        end)
    end,
    preview_renders_both_thresholds_and_keeps_every_set_reachable=function()
        local KW=setup()
        previewEnvironment(function(root)
            dofile(ROOT.."/SummaryView.lua");dofile(ROOT.."/SetPreview.lua")
            local _,_,add,build=fixture(KW)
            add(EQUIP_SLOT_HEAD); add(EQUIP_SLOT_CHEST); add(EQUIP_SLOT_LEGS)
            add(EQUIP_SLOT_MAIN_HAND,meta(10,{twoHanded=true}))
            local summary=build()
            for i=2,8 do summary.sets[i]=KW.Copy(summary.sets[1]) end
            local preview=KW.SetPreview.New(root); preview:Show(root,summary)
            assert(#preview.cards==8 and not preview.cards[8].control.hidden)
            assert(preview.child.height<=preview.control.height or preview.needsScroll,"overflow must remain reachable")
            local found=false
            for _,line in ipairs(preview.cards[1].tooltip.lines) do
                if line.text:find("Five",1,true) then
                    assert(line.text:find("Main bar: ",1,true) and not line.text:find("II",1,true))
                    found=true
                end
            end
            assert(found,"Full bonus description not rendered")
        end)
    end,
    preview_diagnostic_gate_and_hover_do_not_capture_empty_area=function()
        local KW=setup()
        previewEnvironment(function(root)
            dofile(ROOT.."/SummaryView.lua");dofile(ROOT.."/SetPreview.lua")
            local _,_,add,build=fixture(KW); add(EQUIP_SLOT_HEAD)
            local preview=KW.SetPreview.New(root)
            assert(preview:ShowDiagnostic(root,build().sets[1])==false)
            KW.Debug=true
            assert(preview:ShowDiagnostic(root,build().sets[1]))
            assert(#preview.cards==2 and preview.cards[1].tooltip.presetSet.front==3)
            assert(preview.cards[2].tooltip.presetSet.front==5)
            assert(preview.control.mouseEnabled==false)
            assert(preview.scroll:GetNamedChild("Scroll").mouseEnabled==false)
            assert(preview.ContainsMouse,"ContainsMouse is not implemented")
            preview.control.mouseOver=true
            assert(not preview:ContainsMouse())
            preview.cards[2].control.mouseOver=true
            assert(preview:ContainsMouse())
            preview:Hide(); assert(not preview:ContainsMouse())
        end)
    end,
    preview_owns_renderer_and_preserves_suppression_and_restrictions=function()
        local KW=setup()
        previewEnvironment(function(root,nativeAddSet)
            local f=io.open(ROOT.."/SetPreview.lua","r")
            if f then f:close(); dofile(ROOT.."/SummaryView.lua");dofile(ROOT.."/SetPreview.lua") end
            assert(KW.SetPreview and KW.SetPreview.New,"SetPreview.New is not implemented")
            local _,_,add,build=fixture(KW); add(EQUIP_SLOT_HEAD)
            local preview=KW.SetPreview.New(root)
            preview:Show(root,build())
            local tooltip=preview.cards[1].tooltip
            assert(tooltip.layoutLink==nil and tooltip.restrictedSet==10)
            assert(tooltip.suppression==7 and tooltip.suppressionRef==321)
            assert(ZO_Tooltip.AddSet==nativeAddSet and ZO_TOOLTIP_STYLES.tooltip.fontFace=="native")
            assert(tooltip.styles~=ZO_TOOLTIP_STYLES and tooltip.styles.tooltip~=ZO_TOOLTIP_STYLES.tooltip)
            preview:Refresh({sets={},complete=false,unavailable={{code="setDataUnavailable"}}})
            assert(preview.cards[1].control.hidden and preview.message.text~="")
        end)
    end,
    present_but_temporarily_unequipable_is_not_missing=function()
        local KW=setup(); local _,_,add,build=fixture(KW)
        add(EQUIP_SLOT_HEAD,meta(10,{availableToEquip=false,physicalAvailable=true}))
        assert(#build().sets[1].missingUids==0)
    end,
    two_handed_counts_only_preset=function()
        local KW=setup(); local _,_,add,build=fixture(KW)
        add(EQUIP_SLOT_HEAD); add(EQUIP_SLOT_CHEST); add(EQUIP_SLOT_LEGS)
        add(EQUIP_SLOT_MAIN_HAND,meta(10,{twoHanded=true,weight=2}))
        GetItemLinkSetInfo=function() error("Model read live equipment") end
        local s=build(); assert(s.sets[1].front==5 and s.sets[1].back==3)
        GetItemLinkSetInfo=function() return true,"Set",2,99,5,10,99 end
        s=build(); assert(s.sets[1].front==5 and s.sets[1].back==3)
    end,
    bow_staff_and_greatsword_count_two=function()
        for _,weaponType in ipairs({"bow","staff","greatsword"}) do
            local KW=setup(); local _,_,add,build=fixture(KW)
            add(EQUIP_SLOT_BACKUP_MAIN,meta(10,{weaponType=weaponType,twoHanded=true,weight=2}))
            local card=build().sets[1]; assert(card.front==0 and card.back==2)
        end
    end,
    two_one_handed_and_shield_count_one_each=function()
        local KW=setup(); local _,_,add,build=fixture(KW)
        add(EQUIP_SLOT_MAIN_HAND); add(EQUIP_SLOT_OFF_HAND)
        add(EQUIP_SLOT_BACKUP_OFF,meta(10,{weaponType="shield"}))
        local card=build().sets[1]; assert(card.front==2 and card.back==1)
    end,
    six_parts_are_not_clamped=function()
        local KW=setup(); local _,_,add,build=fixture(KW)
        for i=1,6 do add(KW.Slots.Order[i]) end
        local card=build().sets[1]; assert(card.front==6 and card.back==6 and card.max==5)
    end,
    single_piece_set_has_own_threshold=function()
        local KW=setup(); local _,_,add,build=fixture(KW)
        add(EQUIP_SLOT_RING1,meta(12,{max=1,bonuses={{required=1,description="One"}}}))
        local card=build().sets[1]; assert(card.front==1 and card.max==1)
        assert(card.bonuses[1].activeFront and card.bonuses[1].activeBack)
    end,
    distinct_bar_sets_stable_slot_order=function()
        local KW=setup(); local _,_,add,build=fixture(KW)
        local back=add(EQUIP_SLOT_BACKUP_MAIN,meta(3,{twoHanded=true,weight=2}))
        local front=add(EQUIP_SLOT_MAIN_HAND,meta(99,{twoHanded=true,weight=2}))
        local s=build(); assert(#s.sets==2)
        assert(s.sets[1].representativeLink==front and s.sets[1].front==2 and s.sets[1].back==0)
        assert(s.sets[2].representativeLink==back and s.sets[2].front==0 and s.sets[2].back==2)
    end,
    no_set_and_empty_weapon_are_not_unknown=function()
        local KW=setup(); local p,_,add,build=fixture(KW)
        add(EQUIP_SLOT_HEAD,meta(0)); p.slots[EQUIP_SLOT_MAIN_HAND]={kind="empty"}
        local s=build(); assert(#s.sets==0 and s.complete and #s.unavailable==0)
    end,
    mixed_perfected_family_uses_separate_threshold=function()
        local KW=setup(); local _,data,add,build=fixture(KW)
        local normal=add(EQUIP_SLOT_HEAD); add(EQUIP_SLOT_CHEST); add(EQUIP_SLOT_LEGS)
        local perfected=add(EQUIP_SLOT_MAIN_HAND,meta(11,{familyId=10,perfected=true,twoHanded=true,weight=2,
            bonuses={{required=5,description="Common"},{required=5,description="Perfect",perfected=true}}}))
        local s=build(); local c=s.sets[1]
        assert(#s.sets==1 and c.representativeLink==perfected and c.representativeLink~=normal)
        assert(c.front==5 and c.back==3 and c.perfectedFront==2 and c.perfectedBack==0)
        assert(c.bonuses[1].activeFront and not c.bonuses[1].activeBack)
        assert(not c.bonuses[2].activeFront and not c.bonuses[2].activeBack)
        c.bonuses[1].description="Changed"; assert(data[perfected].bonuses[1].description=="Common")
    end,
    missing_instance_uses_saved_link=function()
        local KW=setup(); local p,_,add,build=fixture(KW)
        add(EQUIP_SLOT_HEAD,meta(10,{availableToEquip=false}))
        local s=build(); assert(s.sets[1].front==1 and s.complete)
        assert(s.sets[1].missingUids[1]==p.slots[EQUIP_SLOT_HEAD].uid and not s.availableToEquip)
    end,
    invalid_saved_link_marks_summary_incomplete=function()
        local KW=setup(); local p,_,add,build=fixture(KW)
        add(EQUIP_SLOT_HEAD,meta(0,{valid=false})); add(EQUIP_SLOT_CHEST)
        local s=build(); assert(not s.complete and #s.unavailable==1)
        assert(s.unavailable[1].uid==p.slots[EQUIP_SLOT_HEAD].uid)
        assert(s.unavailable[1].code=="setDataUnavailable")
    end,
}
