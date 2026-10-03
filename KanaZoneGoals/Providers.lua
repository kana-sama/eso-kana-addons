local K = KanaZoneGoals

function K.MapBasename(texture)
    local name=(texture or ''):lower():gsub('\\','/'):match('([^/]+)$') or ''
    return name:gsub('%.dds$',''):gsub('_%d+$','')
end

-- Criterion order and item IDs from MapPins' PrecursorItems (see THIRD_PARTY_NOTICES).
local precursorParts={129900,129901,129902,129903,129904,129905,129906,
    129907,129908,129909,129910,129911,129912,129913}

local function precursorInventory()
    local owned={}
    if not GetBagSize or not GetItemId then return owned end
    -- Inspect real slots by item ID; generated links may have different item variants.
    local bags={BAG_BACKPACK,BAG_BANK,BAG_SUBSCRIBER_BANK,BAG_WORN,
        BAG_HOUSE_BANK_ONE,BAG_HOUSE_BANK_TWO,BAG_HOUSE_BANK_THREE,
        BAG_HOUSE_BANK_FOUR,BAG_HOUSE_BANK_FIVE,BAG_HOUSE_BANK_SIX,
        BAG_HOUSE_BANK_SEVEN,BAG_HOUSE_BANK_EIGHT,BAG_HOUSE_BANK_NINE,BAG_HOUSE_BANK_TEN}
    for _,bag in pairs(bags) do
        for slot=0,GetBagSize(bag)-1 do
            local itemId=GetItemId(bag,slot)
            if itemId and itemId>0 then owned[itemId]=true end
        end
    end
    return owned
end

local function hasPrecursorPart(index, owned)
    local itemId=precursorParts[index]
    if not itemId then return false end
    if owned[itemId] then return true end
    if not GetItemLinkStacks then return false end
    -- ESO includes backpack, bank, craft bag, house banks and newer storage types.
    for _,count in pairs({GetItemLinkStacks(K.ItemLink(itemId))}) do
        if type(count)=='number' and count>0 then return true end
    end
    return false
end

function K.AchievementGoal(id, category, selected)
    local name, description, _, icon = GetAchievementInfo(id)
    if not name or name=='' then return nil end
    local all, shown = {}, {}
    local owned=id==1958 and precursorInventory() or nil
    for index=1,GetAchievementNumCriteria(id) do
        local text, current, total = GetAchievementCriterion(id,index)
        if id==1958 and current<total and hasPrecursorPart(index, owned) then current=total end
        local criterion={index=index,name=K.CleanName(text),current=current,total=total,quality=K.TextQuality(text)}
        all[#all+1]=criterion
        if not selected or selected[index] then shown[#shown+1]=criterion end
    end
    local current,total=K.SumCriteria(all,selected)
    if #all==0 and not selected then current=IsAchievementComplete(id) and 1 or 0;total=1 end
    return {key='achievement:'..id,category=category,name=K.CleanName(name),description=description,icon=icon,
        current=current,total=total,achievementId=id,criteria=shown,localCriteria=selected~=nil}
end

function K.ResolveMapGoals(rows, maps)
    local zones={}
    for _,row in ipairs(rows) do
        local map=maps[row[1]]
        if map and (not row[5] or map.publicDungeon) then
            local zone=zones[map.zoneId] or {};zones[map.zoneId]=zone
            local id=row[2]
            local entry=zone[id] or {id=id,category=row[4],criteria={}};zone[id]=entry
            if row[3]==0 then entry.whole=true else entry.criteria[row[3]]=true end
        end
    end
    return zones
end

local function zoneStory(id)
    if not id or id==0 then return nil end
    local parent=GetZoneStoryZoneIdForZoneId(id)
    return parent and parent>0 and parent or id
end
K.ZoneStoryId=zoneStory

local function addAchievement(index,zoneId,id,category)
    if not zoneId or zoneId==0 or not id or id==0 then return end
    local zone=index[zoneId] or {};index[zoneId]=zone
    -- Explicit whole-zone records take priority over individual pin criteria.
    local row=zone[id] or {id=id,category=category,criteria={}}
    row.whole=true;zone[id]=row
end

function K.BuildCatalog()
    local maps,ambiguous={},{}
    -- LibMapData.BuildMapTextureNamesLookup stores texture -> {mapId, ...}.
    -- A texture may belong to several maps, so resolve every ID before using it.
    for texture,mapIds in pairs(LibMapData.textureNamesLookup or {}) do
        local key=K.MapBasename(texture)
        for _,mapId in ipairs(mapIds) do
            local _,_,_,zoneIndex=GetMapInfoById(mapId)
            if zoneIndex and zoneIndex>0 then
                local id=GetZoneId(zoneIndex)
                local zoneId=zoneStory(id)
                if zoneId and not ambiguous[key] then
                    if maps[key] and maps[key].zoneId~=zoneId then
                        maps[key]=nil;ambiguous[key]=true
                    else
                        local publicDungeon=LibSets.IsPublicDungeonZoneId(id)
                        maps[key]={zoneId=zoneId,publicDungeon=publicDungeon or (maps[key] and maps[key].publicDungeon) or false}
                    end
                end
            end
        end
    end
    K.catalog=K.ResolveMapGoals(K.mapGoals,maps)
    for _,row in ipairs(K.publicDungeons) do addAchievement(K.catalog,zoneStory(row[1]),row[2],'dungeons') end
    for _,row in ipairs(K.dailyGoals) do
        local zoneIndex=GetFastTravelNodePOIIndicies(row[1])
        if zoneIndex and zoneIndex>0 then addAchievement(K.catalog,zoneStory(GetZoneId(zoneIndex)),row[2],'dailies') end
    end
    for _,row in ipairs(K.extraAchievements or {}) do addAchievement(K.catalog,zoneStory(row[1]),row[2],row[3]) end
    -- A local museum collection must include every required piece, not just mapped pins.
    for _,zone in pairs(K.catalog) do
        for _,row in pairs(zone) do if row.category=='museums' and row.id~=1958 then row.whole=true end end
    end
    K.questCatalog={}
    if LibQuestData and LibQuestData.quest_data then
        for id in pairs(LibQuestData.quest_data) do
            local zoneId=zoneStory(GetQuestZoneId(id))
            local repeatType=LibQuestData:get_quest_repeat(id)
            local name=GetQuestName(id)
            local questType=LibQuestData:get_quest_type(id)
            -- A dungeon's parent region does not make its quest a regional side quest.
            if zoneId and questType~=QUEST_TYPE_DUNGEON and repeatType==QUEST_REPEAT_NOT_REPEATABLE and name and name~='' then
                local list=K.questCatalog[zoneId] or {};K.questCatalog[zoneId]=list
                list[#list+1]=id
            end
        end
    end
    K.antiquityCatalog={}
    local id=GetNextAntiquityId()
    while id do
        local zoneId=zoneStory(GetAntiquityZoneId(id))
        if zoneId then
            local list=K.antiquityCatalog[zoneId] or {};K.antiquityCatalog[zoneId]=list
            list[#list+1]=id
        end
        id=GetNextAntiquityId(id)
    end
end

function K.FishingGoals(achievementId,sourceZone)
    local goals={}
    local orders=RFT.orders and (RFT.orders[achievementId] or RFT.orders[0]) or {}
    local qualities=RFT.quality and (RFT.quality[achievementId] or RFT.quality[0]) or {}
    local items=RFT.achievementToItem and RFT.achievementToItem[achievementId] or {}
    local window=RFT.window or {}
    local types=RFT.types and (RFT.types[sourceZone] or RFT.types[0]) or {}
    local waters={
        {pool=window.column1,name='Солёная вода'}, {pool=window.column2,name='Озёрная вода'},
        {pool=window.column3,name='Речная вода'}, {pool=window.column4,name='Грязная вода'},
    }
    for index=1,GetAchievementNumCriteria(achievementId) do
        local name,current,total=GetAchievementCriterion(achievementId,index)
        local quality=qualities[index]
        if items[index] then
            local link=K.ItemLink(items[index])
            local itemName=GetItemLinkName(link)
            if itemName and itemName~='' then name=itemName end
            quality=quality or GetItemLinkQuality(link)
        end
        local water,waterOrder='Другие водоёмы',5
        for i,row in ipairs(waters) do
            if row.pool and orders[index]==row.pool then
                water=types[i] and GetString(types[i]) or row.name
                waterOrder=types[i] or i;break
            end
        end
        goals[#goals+1]={key='fish:'..achievementId..':'..index,category='fishing',
            name=K.CleanName(name),current=current,total=total,quality=quality,
            water=water,waterOrder=waterOrder,achievementId=achievementId}
    end
    return goals
end

function K.IncludeSet(id,zoneId)
    local instance=LibSets.IsDungeonSet(id) or LibSets.IsMonsterSet(id) or LibSets.IsTrialSet(id)
    if instance then return K.saved.excludeDungeonSets==false end
    -- Lead locations and PvP vendors do not make a set part of this region's collection.
    local zones=LibSets.GetItemSetCollectionZoneIds(GetItemSetCollectionCategoryId(id)) or {}
    for _,sourceZone in ipairs(zones) do if zoneStory(sourceZone)==zoneId then return true end end
    return false
end

function K.AntiquityLeadSource(id)
    local data=ILeadList
    local location=data and data.Locations and data.Locations[id]
    local source=location and (location[1]~='' and location[1] or location[3])
    if not source or source=='' then return 'Источник зацепки пока не указан в Lead List' end
    local zoneId=data.FindScryDifferentZones and data.FindScryDifferentZones[id] or GetAntiquityZoneId(id)
    local zoneName=data.ZONENAME_SPECIAL and data.ZONENAME_SPECIAL[zoneId]
    if not zoneName then zoneName=GetZoneNameById(zoneId) end
    zoneName=K.CleanName(zoneName)
    return (zoneName~='' and zoneName..' — ' or '')..K.CleanName(source):gsub('%s+',' ')
end

local function includedItem(itemId,rewardLink)
    if not itemId or itemId==0 then return nil end
    local link=rewardLink and rewardLink~='' and rewardLink or K.ItemLink(itemId)
    local itemType=GetItemLinkItemType(link)
    if itemType==ITEMTYPE_TREASURE or itemType==ITEMTYPE_SIEGE or itemType==ITEMTYPE_FURNISHING then return nil end
    local name=GetItemLinkName(link)
    if name and name~='' then return K.CleanName(name),GetItemLinkQuality(link) end
    return nil
end

function K.IncludedAntiquityReward(rewardId,visited)
    if not rewardId or rewardId==0 then return nil end
    visited=visited or {}
    if visited[rewardId] then return nil end
    visited[rewardId]=true
    local kind=GetRewardType(rewardId)
    if not kind then return nil end
    if kind==REWARD_ENTRY_TYPE_ITEM then
        local link=GetItemRewardItemLink(rewardId,1,0,LINK_STYLE_DEFAULT)
        return includedItem(GetItemRewardItemId(rewardId),link)
    end
    if kind==REWARD_ENTRY_TYPE_COLLECTIBLE then
        local collectibleId=GetCollectibleRewardCollectibleId(rewardId)
        if not collectibleId or collectibleId==0 then return nil end
        local category=GetCollectibleCategoryType(collectibleId)
        if category==COLLECTIBLE_CATEGORY_TYPE_FURNITURE or category==COLLECTIBLE_CATEGORY_TYPE_HOUSE_BANK then return nil end
        local name=GetCollectibleName(collectibleId)
        return name and name~='' and K.CleanName(name) or nil
    end
    if kind==REWARD_ENTRY_TYPE_REWARD_LIST then
        local listId=GetRewardListIdFromReward(rewardId)
        for i=1,GetNumRewardListEntries(listId) do
            local childId=GetRewardListEntryInfo(listId,i)
            local name,quality=K.IncludedAntiquityReward(childId,visited)
            if name then return name,quality end
        end
    end
    return nil
end

function K.AntiquityGoal(id)
    local antiquitySetId=GetAntiquitySetId(id)
    local multipart=antiquitySetId and antiquitySetId>0
    -- Classify the final reward, not a fragment's appearance or quality.
    local rewardId=multipart and GetAntiquitySetRewardId(antiquitySetId) or GetAntiquityRewardId(id)
    local rewardName,rewardQuality=K.IncludedAntiquityReward(rewardId)
    if not rewardName and multipart then
        local itemId=ILeadList and ILeadList.SETID_2_ITEMID and ILeadList.SETID_2_ITEMID[antiquitySetId]
        if itemId then rewardName,rewardQuality=includedItem(itemId) end
    end
    if not rewardName then return nil end
    local recovered=GetNumAntiquitiesRecovered(id)>0
    return {key='antiquity:'..id,category='antiquities',name=K.CleanName(GetAntiquityName(id)),
        current=recovered and 1 or 0,total=1,antiquityQuality=GetAntiquityQuality(id),
        antiquityId=id,rewardName=rewardName,rewardQuality=rewardQuality,
        rewardAntiquityQuality=not rewardQuality and multipart and GetAntiquitySetQuality(antiquitySetId) or nil,leadSource=not recovered and K.AntiquityLeadSource(id) or nil}
end

function K.QuestUnavailable(id)
    if HasCompletedQuest(id) or HasQuest(id) then return false end
    if LibQuestData.known_removed_quest and LibQuestData.known_removed_quest[id] then return true end
    local filters=LibQuestData_Internal
    -- Missing prerequisites are temporary; only the irreversible breadcrumb/choice filter applies.
    return filters and filters.show_breadcrumb_quest and not filters:show_breadcrumb_quest(id) or false
end

function K.CollectGoals(zoneId)
    local goals,notices={},{}
    local function add(goal) if goal then goals[#goals+1]=goal end end
    local function on(category) return K.saved.categories[category]~=false end
    local zone=K.catalog[zoneId] or {}
    local merged={}
    for id,row in pairs(zone) do merged[id]=row end
    for _,row in ipairs(K.saved.custom[zoneId] or {}) do merged[row.id]={id=row.id,category=row.category,whole=true} end
    for _,row in pairs(merged) do
        if on(row.category) then add(K.AchievementGoal(row.id,row.category,not row.whole and row.criteria or nil)) end
    end
    if on('sets') then
        if LibSets.AreSetsLoaded() then
            for id in pairs(LibSets.GetSetIdsByDropZone(zoneId) or {}) do
                local total=GetNumItemSetCollectionPieces(id)
                if total and total>0 and K.IncludeSet(id,zoneId) then
                    add({key='set:'..id,category='sets',name=GetItemSetName(id),current=GetNumItemSetCollectionSlotsUnlocked(id),total=total,
                        setId=id,description='Открыть все предметы сета в коллекции.'})
                end
            end
        else notices[#notices+1]='LibSets ещё загружает данные сетов.' end
    end
    if on('fishing') then
        if RFT and RFT.zoneToAchievement then
            local seen={}
            for sourceZone,ids in pairs(RFT.zoneToAchievement) do
                if zoneStory(sourceZone)==zoneId then
                    for _,id in ipairs(ids) do if not seen[id] then for _,fish in ipairs(K.FishingGoals(id,sourceZone)) do add(fish) end;seen[id]=true end end
                end
            end
        else notices[#notices+1]='Для рыбалки включите Rare Fish Tracker.' end
    end
    if on('antiquities') then
        for _,id in ipairs(K.antiquityCatalog[zoneId] or {}) do add(K.AntiquityGoal(id)) end
    end
    if on('quests') then
        if LibQuestData and LibQuestData.quest_data then
            local story={}
            if ZONE_COMPLETION_TYPE_PRIORITY_QUESTS then
                for i=1,GetNumZoneActivitiesForZoneCompletionType(zoneId,ZONE_COMPLETION_TYPE_PRIORITY_QUESTS) do
                    story[GetZoneActivityIdForZoneCompletionType(zoneId,ZONE_COMPLETION_TYPE_PRIORITY_QUESTS,i)]=true
                end
            end
            for _,id in ipairs(K.questCatalog[zoneId] or {}) do
                if not story[id] and not LibQuestData:is_prologue_quest(id) then
                    add({key='quest:'..id,category='quests',name=GetQuestName(id),current=HasCompletedQuest(id) and 1 or 0,total=1,questId=id,unavailable=K.QuestUnavailable(id),
                        description='Выполнение этим персонажем. Список из LibQuestData: альтернативные и недоступные задания могут требовать исключения.'})
                end
            end
        else notices[#notices+1]='Для побочных заданий включите LibQuestData.' end
    end
    if on('collectibles') then
        for _,row in ipairs(K.collectibleGoals or {}) do
            if zoneStory(row[1])==zoneId then
                local id=row[2]
                local name=GetCollectibleName(id)
                if name and name~='' then
                    add({key='collectible:'..id,category='collectibles',name=name,current=IsCollectibleUnlocked(id) and 1 or 0,total=1,
                        collectibleId=id,description=GetCollectibleDescription(id)})
                end
            end
        end
        for _,row in pairs(merged) do
            local hasReward,id=GetAchievementRewardCollectible(row.id)
            if hasReward and id and id>0 then
                add({key='collectible:'..id,category='collectibles',name=GetCollectibleName(id),current=IsCollectibleUnlocked(id) and 1 or 0,total=1,
                    collectibleId=id,description=GetCollectibleDescription(id)})
            end
        end
    end
    return goals,notices
end
