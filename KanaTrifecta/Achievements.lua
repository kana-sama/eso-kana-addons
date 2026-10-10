local K=KanaTrifecta
local Achievements={};Achievements.__index=Achievements;K.Achievements=Achievements
function Achievements.New(api,currentContext)
    return setmetatable({api=api,currentContext=currentContext,rows={}},Achievements)
end
function Achievements:Availability(profile)
    local ids=profile.achievementCatalogIds
    if not ids or #ids==0 or not self.api.GetAchievementInfo then return false,K.Strings and K.Strings.catalogUnavailable end
    for _,id in ipairs(ids) do
        local name=self.api.GetAchievementInfo(id)
        if type(id)~='number' or not name or name=='' then return false,K.Strings and K.Strings.catalogUnavailable end
    end
    return true
end
function Achievements:BuildCatalog(profile)
    local entries,seen={},{}
    for _,id in ipairs(profile.achievementCatalogIds or {}) do
        if not seen[id] then
            seen[id]=true
            local name,description,points,icon,completed,date,time=self.api.GetAchievementInfo(id)
            if name and name~='' then
                local entry={id=id,name=name,description=description,points=points,icon=icon,completed=completed,date=date,time=time,criteria={}}
                for i=1,self.api.GetAchievementNumCriteria(id) do
                    local text,count,required=self.api.GetAchievementCriterion(id,i)
                    entry.criteria[#entry.criteria+1]={description=text,count=count,required=required}
                end
                entries[#entries+1]=entry
            end
        end
    end
    return entries
end
function Achievements:IsCurrent(profile,generation)
    local c=self.currentContext();return c and c.profileKey==profile.key and c.contextGeneration==generation
end
function Achievements:IsDedicated(profile)
    local a=self.api;local anchor=profile.journalAnchorAchievementId
    if not anchor or not a.GetCategoryInfoFromAchievementId then return false end
    local top,sub=a.GetCategoryInfoFromAchievementId(anchor)
    if not top or not sub or sub==0 then return false end
    local ids={};for _,id in ipairs(profile.achievementCatalogIds or {}) do
        ids[id]=true;local t,s=a.GetCategoryInfoFromAchievementId(id);if t~=top or s~=sub then return false end
    end
    local _,count=a.GetAchievementSubCategoryInfo(top,sub)
    if not count or count==0 then return false end
    for i=1,count do if not ids[a.GetAchievementId(top,sub,i)] then return false end end
    return true
end
function Achievements:ShowNative(id,profile,generation)
    if not self:IsCurrent(profile,generation) then return false end
    local a=self.api
    a.ACHIEVEMENTS.contentSearchEditBox:SetText('');a.ACHIEVEMENTS_MANAGER:SetSearchString('')
    a.ACHIEVEMENTS:ResetFilters();a.ACHIEVEMENTS:ShowAchievement(id)
    -- Native ShowAchievement owns its first-show queue. Cancel only our outstanding ID if the context changed.
    if a.CallLater or a.zo_callLater then (a.CallLater or a.zo_callLater)(function()
        if not self:IsCurrent(profile,generation) and a.ACHIEVEMENTS.queuedShowAchievement==id then a.ACHIEVEMENTS.queuedShowAchievement=nil end
    end,0) end
    return true
end
function Achievements:CreateScene()
    if self.scene then return end
    local a=self.api;local wm=a.WINDOW_MANAGER
    self.root=wm:CreateTopLevelWindow('KanaTrifectaAchievementList');self.root:SetDrawTier(a.DT_LOW);self.root:SetMouseEnabled(false)
    self.root:SetDimensions(680,math.max(250,a.GuiRoot:GetHeight()-160));self.root:SetAnchor(a.TOPRIGHT,a.GuiRoot,a.TOPRIGHT,-40,80);self.root:SetHidden(true)
    local title=wm:CreateControl('KanaTrifectaAchievementTitle',self.root,a.CT_LABEL)
    title:SetFont('ZoFontWinH1');title:SetAnchor(a.TOPLEFT,self.root,a.TOPLEFT,0,0);title:SetDimensions(560,40);self.title=title
    local back=wm:CreateControlFromVirtual('KanaTrifectaAchievementBack',self.root,'ZO_DefaultButton')
    back:SetDimensions(100,32);back:SetAnchor(a.TOPRIGHT,self.root,a.TOPRIGHT,0,0);back:SetText(K.Strings.back)
    back:SetHandler('OnClicked',function() a.SCENE_MANAGER:ShowBaseScene() end)
    self.scroll=wm:CreateControlFromVirtual('KanaTrifectaAchievementScroll',self.root,'ZO_ScrollContainer')
    self.scroll:SetAnchor(a.TOPLEFT,self.root,a.TOPLEFT,0,50);self.scroll:SetAnchor(a.BOTTOMRIGHT,self.root,a.BOTTOMRIGHT,0,0)
    self.child=self.scroll:GetNamedChild('ScrollChild')
    self.scene=a.ZO_Scene:New('kanaTrifectaAchievements',a.SCENE_MANAGER)
    self.scene:AddFragmentGroup(a.FRAGMENT_GROUP.MOUSE_DRIVEN_UI_WINDOW)
    self.scene:AddFragmentGroup(a.FRAGMENT_GROUP.FRAME_TARGET_STANDARD_RIGHT_PANEL)
    self.scene:AddFragment(a.ZO_FadeSceneFragment:New(self.root))
end
function Achievements:FillScene(profile,generation)
    self:CreateScene();local a=self.api;self.title:SetText(K.Name(profile.name,self.currentContext().language))
    local y=0;local entries=self:BuildCatalog(profile)
    for i,entry in ipairs(entries) do
        local row=self.rows[i]
        if not row then
            row={};row.control=a.WINDOW_MANAGER:CreateControl('KanaTrifectaAchievement'..i,self.child,a.CT_CONTROL)
            row.control:SetMouseEnabled(true)
            row.label=a.WINDOW_MANAGER:CreateControl('KanaTrifectaAchievementName'..i,row.control,a.CT_LABEL)
            row.label:SetFont('ZoFontGameBold');row.label:SetAnchor(a.TOPLEFT,row.control,a.TOPLEFT,48,0);row.label:SetWidth(590)
            row.icon=a.WINDOW_MANAGER:CreateControl('KanaTrifectaAchievementIcon'..i,row.control,a.CT_TEXTURE)
            row.icon:SetDimensions(40,40);row.icon:SetAnchor(a.TOPLEFT,row.control,a.TOPLEFT,0,0)
            row.description=a.WINDOW_MANAGER:CreateControl('KanaTrifectaAchievementDescription'..i,row.control,a.CT_LABEL)
            row.description:SetFont('ZoFontGame');row.description:SetWidth(590);row.description:SetAnchor(a.TOPLEFT,row.label,a.BOTTOMLEFT,0,4)
            row.control:SetHandler('OnMouseUp',function(_,button,inside)
                if inside and button==a.MOUSE_BUTTON_INDEX_LEFT and row.entry then self:ShowNative(row.entry.id,self.openProfile,self.openGeneration) end
            end)
            self.rows[i]=row
        end
        row.entry=entry;row.control:SetHidden(false);row.icon:SetTexture(entry.icon);row.label:SetText(entry.name)
        row.label:SetColor((entry.completed and a.ZO_SUCCEEDED_TEXT or a.ZO_NORMAL_TEXT):UnpackRGBA())
        local lines={entry.description}
        for _,c in ipairs(entry.criteria) do lines[#lines+1]=string.format('%s (%d/%d)',c.description,c.count,c.required) end
        row.description:SetText(table.concat(lines,'\n'));row.description:SetColor(a.ZO_HINT_TEXT:UnpackRGBA())
        row.label:SetHeight(row.label:GetTextHeight());row.description:SetHeight(row.description:GetTextHeight())
        local height=math.max(40,row.label:GetTextHeight()+4+row.description:GetTextHeight())+16
        row.control:ClearAnchors();row.control:SetAnchor(a.TOPLEFT,self.child,a.TOPLEFT,0,y);row.control:SetDimensions(650,height);y=y+height
    end
    for i=#entries+1,#self.rows do self.rows[i].entry=nil;self.rows[i].control:SetHidden(true) end
    self.child:SetDimensions(650,y);self.openProfile=profile;self.openGeneration=generation
end
function Achievements:Open(profile,generation)
    if not self:IsCurrent(profile,generation) or not self:Availability(profile) then return false end
    if self:IsDedicated(profile) then return self:ShowNative(profile.journalAnchorAchievementId,profile,generation) end
    self:FillScene(profile,generation);self.api.SCENE_MANAGER:Show('kanaTrifectaAchievements');return true
end
