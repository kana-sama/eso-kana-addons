local K=KanaStatSources
K.CaptureBuild={}
function K.CaptureBuild.Read(api,capabilities)
    local data={attributes={},skills={},bars={front={},back={},werewolf={}},champion={}},errors
    errors={};local read=K.Core.Reader(api,errors,capabilities)
    local resources={{'health','ATTRIBUTE_HEALTH','STAT_HEALTH_MAX'},{'magicka','ATTRIBUTE_MAGICKA','STAT_MAGICKA_MAX'},{'stamina','ATTRIBUTE_STAMINA','STAT_STAMINA_MAX'}}
    for _,a in ipairs(resources) do
        data.attributes[a[1]]={spent=read('GetAttributeSpentPoints',api[a[2]]),perPoint=read('GetAttributeDerivedStatPerPointValue',api[a[2]],api[a[3]])}
    end
    data.attributes.unspent=read('GetAttributeUnspentPoints')
    local slots={}
    for _,bar in ipairs({{'front','HOTBAR_CATEGORY_PRIMARY'},{'back','HOTBAR_CATEGORY_BACKUP'},{'werewolf','HOTBAR_CATEGORY_WEREWOLF'}}) do
        if api[bar[2]]~=nil then
            for slot=3,8 do
                local id=read('GetSlotBoundId',slot,api[bar[2]])
                if id and id>0 then
                    data.bars[bar[1]][slot]={slot=slot,abilityId=id,name=read('GetAbilityName',id),description=read('GetAbilityDescription',id),slotType=read('GetSlotType',slot,api[bar[2]])}
                end
            end
        end
    end
    for slot=1,12 do local id=read('GetSlotBoundId',slot,api.HOTBAR_CATEGORY_CHAMPION);if id and id>0 then slots[id]=slot end end
    for discipline=1,read('GetNumChampionDisciplines') or 0 do
        local disciplineId=read('GetChampionDisciplineId',discipline)
        local disciplineType=disciplineId and read('GetChampionDisciplineType',disciplineId)
        local icon
        -- Native ZO_ChampionDisciplineData:GetPointPoolIcon uses these three
        -- already coloured textures, selected by discipline type (not index).
        for _,entry in ipairs({
            {'CHAMPION_DISCIPLINE_TYPE_WORLD','EsoUI/Art/Champion/champion_points_stamina_icon.dds'},
            {'CHAMPION_DISCIPLINE_TYPE_COMBAT','EsoUI/Art/Champion/champion_points_magicka_icon.dds'},
            {'CHAMPION_DISCIPLINE_TYPE_CONDITIONING','EsoUI/Art/Champion/champion_points_health_icon.dds'},
        }) do if api[entry[1]]~=nil and disciplineType==api[entry[1]] then icon=entry[2] end end
        for index=1,read('GetNumChampionDisciplineSkills',discipline) or 0 do
            local id=read('GetChampionSkillId',discipline,index)
            local points=id and read('GetNumPointsSpentOnChampionSkill',id)
            if points and points>0 then
                local kind=read('GetChampionSkillType',id)
                local slottable=kind and read('CanChampionSkillTypeBeSlotted',kind)
                data.champion[#data.champion+1]={id=id,points=points,discipline=discipline,disciplineId=disciplineId,disciplineType=disciplineType,icon=icon,name=read('GetChampionSkillName',id),description=read('GetChampionSkillDescription',id,points),currentBonus=read('GetChampionSkillCurrentBonusText',id,points),skillType=kind,slottable=slottable,slot=slots[id],abilityId=read('GetChampionAbilityId',id),jumpPoints={read('GetChampionSkillJumpPoints',id)}}
            end
        end
    end
    for skillType=1,read('GetNumSkillTypes') or 0 do
        for line=1,read('GetNumSkillLines',skillType) or 0 do
            local lineId=read('GetSkillLineId',skillType,line)
            local _,_,active=read('GetSkillLineDynamicInfo',skillType,line)
            for index=1,read('GetNumSkillAbilities',skillType,line) or 0 do
                local name,icon,earnedRank,passive,ultimate,purchased,progression,rank=read('GetSkillAbilityInfo',skillType,line,index)
                if purchased then
                    local id=read('GetSkillAbilityId',skillType,line,index,false)
                    local record={id=id,name=name,icon=icon,rank=rank,earnedRank=earnedRank,passive=passive,ultimate=ultimate,purchased=purchased,lineId=lineId,lineActive=active,skillType=skillType,description=id and read('GetAbilityDescription',id),progression=progression,classId=read('GetSkillLineClassId',skillType,line)}
                    if api.GetCraftedAbilitySkillCraftedAbilityId then
                        local crafted=read('GetCraftedAbilitySkillCraftedAbilityId',skillType,line,index)
                        if crafted and crafted>0 then
                            record.craftedId=crafted
                            record.scripts={read('GetCraftedAbilityActiveScriptIds',crafted)}
                            record.craftedDescription=read('GetCraftedAbilityDescription',crafted)
                        end
                    end
                    data.skills[#data.skills+1]=record
                end
            end
        end
    end
    return data,errors
end
