local K=KanaZoneGoals
local ROW='KanaZoneGoalsRow'
local ROW_TYPE=73102

local function progress(current,total)
    if type(current)~='number' or type(total)~='number' or total<=0 then return '—' end
    return string.format('%d / %d',current,total)
end

local categoryIcons={
    sets='EsoUI/Art/Collections/collections_tabIcon_itemSets_up.dds',
    fishing='EsoUI/Art/Icons/achievements_indexicon_fishing_up.dds',
    meetings='EsoUI/Art/Journal/journal_quest_companion.dds',
    museums='EsoUI/Art/Icons/quest_strosmkai_open_treasure_chest.dds',
    collectibles='EsoUI/Art/Notifications/collectionsbutton_up.dds',
    antiquities='EsoUI/Art/TreeIcons/antiquities_indexIcon_scryable_UP.dds',
    dynamic='EsoUI/Art/Campaign/campaignbrowser_indexicon_specialevents_up.dds',
    special='EsoUI/Art/ZoneStories/completionTypeIcon_groupBoss.dds',
    dungeons='EsoUI/Art/Icons/achievements_indexicon_dungeons_up.dds',
    quests='EsoUI/Art/Icons/achievements_indexicon_quests_up.dds',
    dailies='EsoUI/Art/Journal/journal_quest_repeat.dds',
    styles='EsoUI/Art/TreeIcons/Gamepad/gp_lorelibrary_categoryicon_craftingstyle.dds',
    global='EsoUI/Art/Progression/progression_indexicon_world_up.dds',
}
K.categoryIcons=categoryIcons

function K.HideGoalTooltip()
    K.hoveredRow=nil
    if KanaZoneGoalsTooltip then KanaZoneGoalsTooltip:SetHidden(true) end
end

function K.LeaveTooltip()
    zo_callLater(function()
        if not (K.hoveredRow and MouseIsOver(K.hoveredRow)) and
            not (KanaZoneGoalsTooltip and MouseIsOver(KanaZoneGoalsTooltip)) then K.HideGoalTooltip() end
    end,100)
end

local function entryName(name,current,total)
    name=K.CleanName(name)
    if type(total)=='number' and total>1 then return name..'  '..progress(current,total) end
    return name
end

function K.TooltipEntries(group,zoneId)
    local entries={}
    local zoneName=zoneId and K.CleanName(GetZoneNameById(zoneId)) or ''
    local goals={}
    for _,goal in ipairs(group.goals) do goals[#goals+1]=goal end
    if group.id=='fishing' then
        table.sort(goals,function(a,b)
            if a.waterOrder~=b.waterOrder then return (a.waterOrder or 5)<(b.waterOrder or 5) end
            if a.complete~=b.complete then return not a.complete end
            return a.name<b.name
        end)
    end
    local previousWater
    for _,goal in ipairs(goals) do
        if not K.saved.hideCompleted or not goal.complete then
            if group.id=='fishing' and previousWater~=(goal.water or 'Другие водоёмы') then
                previousWater=goal.water or 'Другие водоёмы'
                entries[#entries+1]={name=previousWater,heading=true}
            end
            local name=goal.name
            if group.id=='fishing' and zo_strformat then name=zo_strformat('<<C:1>>',K.CleanName(name)) end
            local displayName=entryName(name,goal.current,goal.total)
            local details=group.id=='antiquities' and not goal.complete and goal.rewardName~=nil
            entries[#entries+1]={name=displayName,complete=goal.complete,unavailable=goal.unavailable,wrapped=details,
                rewardName=details and goal.rewardName or nil,rewardQuality=goal.rewardQuality,
                rewardAntiquityQuality=goal.rewardAntiquityQuality,
                leadSource=details and (goal.leadSource or 'Источник неизвестен') or nil,
                quality=goal.quality,antiquityQuality=goal.antiquityQuality,goal=goal}
            if group.id~='sets' and group.id~='antiquities' then
                for _,c in ipairs(goal.criteria or {}) do
                    local criterionName=K.CleanName(c.name)
                    -- Local achievement criteria can contain only the current region name.
                    if criterionName~=zoneName and criterionName~=K.CleanName(goal.name) then
                        entries[#entries+1]={name='    '..entryName(criterionName,c.current,c.total),
                            complete=type(c.current)=='number' and type(c.total)=='number' and c.total>0 and c.current>=c.total,
                            quality=c.quality,goal=goal}
                    end
                end
            end
        end
    end
    return entries
end

-- Keep each water group intact; pairs of groups form a two-column block.
function K.FishingTooltipRows(items)
    local groups={}
    for _,item in ipairs(items) do
        if item.heading or #groups==0 then groups[#groups+1]={} end
        local group=groups[#groups];group[#group+1]=item
    end
    local rows={}
    for i=1,#groups,2 do
        if i>1 then rows[#rows+1]={spacer=true} end
        local left,right=groups[i],groups[i+1] or {}
        for j=1,math.max(#left,#right) do rows[#rows+1]={left=left[j],right=right[j]} end
    end
    return rows
end

function K.QuestTooltipRows(items)
    local rows={}
    local half=math.ceil(#items/2)
    for i=1,half do rows[#rows+1]={left=items[i],right=items[i+half]} end
    return rows
end

function K.SetupTooltipCell(row,entry,width,height)
    row.kzgData=entry
    row:SetHidden(entry==nil)
    row:SetResizeToFitDescendents(false)
    row:SetDimensions(width,height or 30)
    if not entry then return end
    local label=row:GetNamedChild('Label')
    label:SetText(entry.name)
    label:SetWidth(width-32)
    label:SetHeight(entry.wrapped and (height or 30)-5 or 25)
    label:SetWrapMode(ELLIPSIS)
    local checkbox=row:GetNamedChild('Checkbox')
    checkbox:SetResizeToFitFile(false)
    checkbox:SetDimensions(20,20)
    checkbox:ClearAnchors()
    checkbox:SetAnchor(TOPLEFT,row,TOPLEFT,0,2)
    label:ClearAnchors()
    label:SetAnchor(TOPLEFT,row,TOPLEFT,28,0)
    checkbox:SetTexture(entry.unavailable and 'EsoUI/Art/Buttons/decline_up.dds' or 'EsoUI/Art/Cadwell/check.dds')
    checkbox:SetColor(1,entry.unavailable and 0 or 1,entry.unavailable and 0 or 1,1)
    checkbox:SetAlpha(not entry.heading and (entry.complete or entry.unavailable) and 1 or 0)
    label:SetColor(ZO_SELECTED_TEXT:UnpackRGB())
    if entry.unavailable then label:SetColor(1,0,0,1)
    elseif entry.heading then label:SetColor(ZO_SELECTED_TEXT:UnpackRGB())
    elseif entry.antiquityQuality then label:SetColor(GetAntiquityQualityColor(entry.antiquityQuality):UnpackRGB())
    elseif entry.quality then label:SetColor(GetItemQualityColor(entry.quality):UnpackRGB()) end
    -- SetColor also assigns alpha; apply dimming last, including for rarity-colored names.
    label:SetAlpha((entry.heading or entry.complete or entry.unavailable) and 1 or 0.55)
end

local ANTIQUITY_TITLE_FONT='ZoFontGameBold'
local ANTIQUITY_DETAIL_FONT='ZoFontGameSmall'

function K.AntiquityBlockLayout(entry,measure,width)
    local function height(text,font)
        measure:SetFont(font)
        measure:SetWidth(width-32)
        measure:SetText(text)
        return math.ceil(measure:GetTextHeight())
    end
    local layout={titleHeight=height(entry.name,ANTIQUITY_TITLE_FONT)}
    layout.rewardY=layout.titleHeight+5
    if entry.rewardName then
        layout.rewardHeight=height(entry.rewardName,ANTIQUITY_DETAIL_FONT)
        layout.sourceY=layout.rewardY+layout.rewardHeight+5
        layout.sourceHeight=height(entry.leadSource or '',ANTIQUITY_DETAIL_FONT)
        layout.height=layout.sourceY+layout.sourceHeight+18
    else layout.height=layout.titleHeight+12 end
    return layout
end

function K.SetupAntiquityBlock(row,entry,width)
    row.kzgData=entry
    local layout=entry.layout
    local title=row:GetNamedChild('Name')
    local reward=row:GetNamedChild('Reward')
    local source=row:GetNamedChild('Source')
    local function place(label,text,y,height,font)
        label:ClearAnchors()
        label:SetAnchor(TOPLEFT,row,TOPLEFT,32,y)
        label:SetDimensions(width-32,height)
        label:SetFont(font)
        label:SetText(text)
        label:SetHidden(false)
    end
    place(title,entry.name,0,layout.titleHeight,ANTIQUITY_TITLE_FONT)
    title:SetColor(GetAntiquityQualityColor(entry.antiquityQuality):UnpackRGB())
    title:SetAlpha(entry.complete and 1 or 0.55)
    row:GetNamedChild('Checkbox'):SetAlpha(entry.complete and 1 or 0)
    reward:SetHidden(not entry.rewardName)
    source:SetHidden(not entry.rewardName)
    if entry.rewardName then
        place(reward,entry.rewardName,layout.rewardY,layout.rewardHeight,ANTIQUITY_DETAIL_FONT)
        local color=entry.rewardQuality and GetItemQualityColor(entry.rewardQuality) or
            (entry.rewardAntiquityQuality and GetAntiquityQualityColor(entry.rewardAntiquityQuality)) or ZO_SELECTED_TEXT
        reward:SetColor(color:UnpackRGB())
        reward:SetAlpha(0.55)
        place(source,entry.leadSource or '',layout.sourceY,layout.sourceHeight,ANTIQUITY_DETAIL_FONT)
        source:SetColor(0.65,0.65,0.65,1)
        source:SetAlpha(1)
    end
end

function K.ShowGoalTooltip(control)
    local data=control.kzgData
    if not data then return end
    K.hoveredRow=control
    local tooltip=KanaZoneGoalsTooltip
    local list=tooltip:GetNamedChild('List')
    if not K.tooltipReady then
        ZO_ScrollList_AddDataType(list,1,'KanaZoneGoalsTooltipRow',30,function(row,entry)
            K.SetupTooltipCell(row,entry,442)
        end)
        ZO_ScrollList_AddDataType(list,2,'KanaZoneGoalsTooltipPair',30,function(row,entry)
            local width=(tooltip:GetWidth()-60)/2
            K.SetupTooltipCell(row:GetNamedChild('Left'),entry.left,width)
            K.SetupTooltipCell(row:GetNamedChild('Right'),entry.right,width)
        end)
        ZO_ScrollList_AddDataType(list,3,'KanaZoneGoalsTooltipSpacer',20,function()end)
        K.tooltipReady=true
    end
    ZO_ScrollList_Clear(list)
    local entries=ZO_ScrollList_GetDataList(list)
    local group=data.group
    local title=group and group.name or 'Дополнительные цели'
    tooltip:GetNamedChild('Title'):SetText(title..': '..K.CleanName(GetZoneNameById(data.zoneId)))
    local items=group and K.TooltipEntries(group,data.zoneId) or {{name=data.text or 'Настройки: /kzg'}}
    for _,entry in ipairs(items) do entry.zoneId=data.zoneId end
    local fishing=group and group.id=='fishing'
    local quests=group and group.id=='quests'
    local antiquities=group and group.id=='antiquities'
    local columns=fishing or quests
    tooltip:SetWidth((columns or antiquities) and math.min(antiquities and 650 or (quests and 780 or 700),GuiRoot:GetWidth()-40) or 480)
    local rows=fishing and K.FishingTooltipRows(items) or (quests and K.QuestTooltipRows(items) or items)
    local height=70
    for _,entry in ipairs(rows) do
        local typeId=entry.spacer and 3 or (columns and 2 or 1)
        local rowHeight=entry.spacer and 20 or 30
        if antiquities then
            local cellWidth=tooltip:GetWidth()-38
            entry.layout=K.AntiquityBlockLayout(entry,tooltip:GetNamedChild('Measure'),cellWidth)
            rowHeight=entry.layout.height
            typeId=100+rowHeight
            K.mythicTooltipTypes=K.mythicTooltipTypes or {}
            if not K.mythicTooltipTypes[typeId] then
                ZO_ScrollList_AddDataType(list,typeId,'KanaZoneGoalsAntiquityBlock',rowHeight,function(row,item)
                    K.SetupAntiquityBlock(row,item,tooltip:GetWidth()-38)
                end)
                K.mythicTooltipTypes[typeId]=true
            end
        end
        entries[#entries+1]=ZO_ScrollList_CreateDataEntry(typeId,entry)
        height=height+rowHeight
    end
    tooltip:SetHeight(math.min(height,GuiRoot:GetHeight()*0.7))
    tooltip:ClearAnchors()
    tooltip:SetAnchor(LEFT,control,RIGHT,40,0)
    tooltip:SetHidden(false)
    ZO_ScrollList_Commit(list)
end

function K.MapRightClick(button)
    if button==MOUSE_BUTTON_INDEX_RIGHT and K.mapPanel and K.mapPanel:IsShowing() then
        K.HideGoalTooltip()
        ZO_WorldMap_MouseUp(ZO_WorldMapContainer,button,true)
    end
end

function K.GoalClicked(control,button)
    if button~=MOUSE_BUTTON_INDEX_LEFT then K.MapRightClick(button);return end
    local data=control.kzgData
    if not data or not data.goal then return end
    local goal=data.goal
    K.HideGoalTooltip()
    if goal.achievementId then ACHIEVEMENTS:ShowAchievement(goal.achievementId)
    elseif goal.setId then LibSets.OpenItemSetCollectionBookOfZone(data.zoneId) end
end

function K.RowClicked(control,button)
    if button~=MOUSE_BUTTON_INDEX_LEFT then K.MapRightClick(button);return end
    local data=control.kzgData
    if data and data.empty then K.OpenSettings() end
end

function K.SetupRow(control,data)
    control.kzgData=data
    local group=data.group
    local completed,total=group and group.completed or 0,group and group.total or 0
    local icon=categoryIcons[group and group.id or 'global']
    control.icon:SetTexture(icon)
    control.progressBar:SetMinMax(0,math.max(total,1))
    control.progressBar:SetValue(completed)
    control.progressBarProgressLabel:SetText(group and string.format('%d/%d',completed,total) or '—')
    local color=total>0 and completed>=total and ZO_NORMAL_TEXT or ZO_SELECTED_TEXT
    control.progressBarProgressLabel:SetColor(color:UnpackRGB())
end

function K.RestoreMapBackground()
    for _,entry in ipairs(K.mapBackgroundTextures or {}) do
        entry.control:SetHeight(entry.height)
        entry.control:SetMouseEnabled(entry.mouseEnabled)
    end
    K.mapBackgroundTextures=nil
    if K.mapBackgroundRightAnchor then
        local a=K.mapBackgroundRightAnchor
        a.control:ClearAnchors()
        a.control:SetAnchor(a.point,a.relativeTo,a.relativePoint,a.x,a.y)
        K.mapBackgroundRightAnchor=nil
    end
end

function K.ExtendMapBackground(background)
    if not K.mapBackgroundTextures then
        K.mapBackgroundTextures={}
        for _,name in ipairs({'Left','Right'}) do
            local texture=background:GetNamedChild(name)
            if texture then
                K.mapBackgroundTextures[#K.mapBackgroundTextures+1]={control=texture,height=texture:GetHeight(),mouseEnabled=texture:IsMouseEnabled()}
            end
        end
    end
    for _,entry in ipairs(K.mapBackgroundTextures) do
        entry.control:SetMouseEnabled(false)
        -- Put the texture's bottom fade below the last rows and the native button.
        entry.control:SetHeight(math.max(entry.height,GuiRoot:GetBottom()-entry.control:GetTop()+160))
    end
end

function K.ResizeMapPanel(panel)
    local background=ZO_SharedMediumLeftPanelBackground
    if not panel.control or not background then return end
    local left=background:GetLeft()-GuiRoot:GetLeft()+20
    local right=background:GetRight()-GuiRoot:GetLeft()-40
    panel.control:ClearAnchors()
    panel.control:SetAnchor(TOPLEFT,GuiRoot,TOPLEFT,left,100)
    panel.control:SetAnchor(BOTTOMRIGHT,GuiRoot,BOTTOMLEFT,right,-30)
    panel.control:GetNamedChild('Title'):SetHidden(true)
    panel.control:GetNamedChild('TitleDivider'):SetHidden(true)
    panel.list:ClearAnchors()
    panel.list:SetAnchor(TOPLEFT,panel.control,TOPLEFT,0,0)
    panel.list:SetAnchor(BOTTOMRIGHT,panel.control,BOTTOMRIGHT,0,-50)
    local texture=background:GetNamedChild('Right')
    if texture then
        if not K.mapBackgroundRightAnchor then
            local valid,point,relativeTo,relativePoint,x,y=texture:GetAnchor(0)
            if valid then K.mapBackgroundRightAnchor={control=texture,point=point,relativeTo=relativeTo,relativePoint=relativePoint,x=x,y=y} end
        end
        texture:ClearAnchors()
        texture:SetAnchor(TOPRIGHT,panel.control,TOPRIGHT,105,-75)
    end
    K.ExtendMapBackground(background)
end

function K.AppendGoals(panel)
    if not panel:IsShowing() then return end
    K.ResizeMapPanel(panel)
    local zoneId=panel:GetCurrentZoneStoryZoneId()
    if not zoneId or zoneId==0 then return end
    local goals,notices=K.CollectGoals(zoneId)
    local filtered=goals
    local groups,done,total=K.GroupGoals(filtered,K.saved.categories)
    local entries=ZO_ScrollList_GetDataList(panel.list)
    local function add(data)
        data.zoneId=zoneId
        entries[#entries+1]=ZO_ScrollList_CreateDataEntry(ROW_TYPE,data)
    end
    local added=false
    for _,group in ipairs(groups) do
        if not K.saved.hideCompleted or group.completed<group.total or group.unavailableCount>0 then
            add({group=group});added=true

        end
    end
    if not added then add({empty=true,text=total>0 and 'Выбранные цели выполнены. Настройки' or 'Нет выбранных целей в каталоге. Настройки'}) end
    for _,notice in ipairs(notices) do add({empty=true,text=notice}) end
    ZO_ScrollList_Commit(panel.list)
end

function K.AttachMapPanel(panel)
    if not panel or not panel.list or panel.kzgAttached then return end
    panel.kzgAttached=true
    ZO_ScrollList_AddDataType(panel.list,ROW_TYPE,ROW,ZO_WORLD_MAP_ZONE_STORY_ROW_HEIGHT,K.SetupRow)
    -- The map exploration panel owns this scroll list. Native rows are rebuilt first.
    ZO_PostHook(panel,'RefreshInfo',function(self) K.HideGoalTooltip();K.AppendGoals(self) end)
    ZO_PostHook(panel,'OnHiding',function() K.HideGoalTooltip();K.RestoreMapBackground() end)
end

function K.Refresh()
    if K.mapPanel and K.ready then
        K.HideGoalTooltip()
        K.mapPanel:RefreshInfo()
    end
end

function K.ScheduleRefresh()
    if K.refreshPending then return end
    K.refreshPending=true
    zo_callLater(function()
        K.refreshPending=false
        if K.ready and K.mapPanel and K.mapPanel:IsShowing() then K.Refresh() end
    end,150)
end
