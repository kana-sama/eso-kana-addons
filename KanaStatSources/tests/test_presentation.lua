local T=dofile('KanaStatSources/tests/support.lua')
local K=T.load({'Core','Stats','Rules','Critical','Model','Descriptions','sources/Equipment','sources/Skills','sources/Champion','sources/Effects','capture/Equipment','capture/Build','Table','Tooltip'})
local function api()return dofile('KanaStatSources/tests/fixtures/controls.lua')()end
return {
 two_columns_and_short_names=function()
    local a=api();local v=K.Table.New(a,a.InformationTooltip)
    v:Render({available=true,total=1000,rows={{name='Ring',label='Ring [Ring 1] — enchantment',icon='ring.dds',value=1000}}},'en',{width=1800,height=900,title='Title',description='Description'})
    T.eq(#v.rows[1].labels,2);T.eq(v.rows[1].labels[1].text,'Ring')
    T.eq(v.rows[1].labels[2].text,'1000');T.eq(v.headers,nil)
    T.eq(v.rows[1].icon.texture,'ring.dds');T.eq(v.rows[1].icon.hidden,false)
 end,
 width_measured_once_without_scaling=function()
    local a=api();local v=K.Table.New(a,a.InformationTooltip)
    local b={available=true,total=10,rows={{name=string.rep('Name ',20),value=10}}}
    local bounds={width=1800,height=900,title='Title',description='Description'}
    v:Render(b,'en',bounds)
    T.eq(v.rows[1].labels[1].width>=v.rows[1].labels[1]:GetStringWidth(b.rows[1].name),true)
    T.eq(v.description.width,v.width);T.eq(v.control.scale,nil)
    local width,height=v.width,v.height
    for i=1,20 do a.InformationTooltip:SetDimensions(i*70,i*19);bounds.keepLayout=true;v:Render(b,'en',bounds);T.eq(v.width,width);T.eq(v.height,height)end
    T.eq(v.width<1100,true)
 end,
 native_stats_style=function()
    local a=api();local v=K.Table.New(a,a.InformationTooltip)
    v:Render({available=true,total=10,rows={{name='Source',value=10}}},'en',{width=1200,height=800,title='Title',description='Description'})
    T.eq(v.rows[1].labels[1].font,'ZoFontHeader');T.eq(v.description.font,'ZoFontHeader')
    T.eq(v.rows[1].labels[2].font,'ZoFontHeader')
    T.eq(v.rows[1].labels[1].color[1]>v.rows[1].labels[1].color[3],true)
    T.eq(v.rows[1].labels[2].color[1],1)
 end,
 refresh_can_add_sources_without_losing_viewport=function()
    local a=api();local v=K.Table.New(a,a.InformationTooltip)
    local b={available=true,total=10,rows={{name='Source',value=10}}}
    local bounds={width=1200,height=800,title='Title',description='Description'}
    v:Render(b,'en',bounds);local width,height=v.width,v.height
    for i=2,20 do b.rows[i]={name='Source '..i,value=1}end
    bounds.keepLayout=true;v:Render(b,'en',bounds)
    T.eq(v.width,width);T.eq(v.height,height);T.eq(v.bodyHeight>=22,true)
    v:Scroll(-10000);T.eq(v.offset+v.bodyHeight,v.contentHeight)
 end,
 attribute_preview_keeps_sources_reachable=function()
    local a=api();local v=K.Table.New(a,a.InformationTooltip)
    local b={available=true,total=10,rows={{name='Source',value=10}}}
    local bounds={width=1200,height=800,title='Title',description='Description'}
    v:Render(b,'en',bounds);local width,height=v.width,v.height
    b.preview={amount=5,total=15};bounds.keepLayout=true;v:Render(b,'en',bounds)
    T.eq(v.width,width);T.eq(v.height,height);T.eq(v.bodyHeight>=22,true)
    T.eq(v.preview.parent,v.content);T.eq(v.previewValue.text,'+5 → 15')
    local footerY=v.footer.anchor[5]
    T.eq(footerY+v.footer.height<=v.height,true)
    v:Scroll(-10000);T.eq(v.offset+v.bodyHeight,v.contentHeight)
 end,
 russian_preview_does_not_enlarge_source_width=function()
    local a=api();local v=K.Table.New(a,a.InformationTooltip)
    local b={available=true,total=12000,rows={{name='Базовое значение',value=12000}}}
    local bounds={width=1200,height=800,title='Макс. магия'}
    v:Render(b,'ru',bounds);local height=v.height;T.eq(a.InformationTooltip:GetWidth(),350)
    b.preview={amount=100,total=12100};bounds.keepLayout=true;v:Render(b,'ru',bounds)
    T.eq(a.InformationTooltip:GetWidth(),350);T.eq(v.height,height)
    T.eq(v.preview.height>=v.preview:GetTextHeight(),true)
    v:Scroll(-10000);T.eq(v.offset+v.bodyHeight,v.contentHeight)
 end,
 narrower_source_width_keeps_title_body_and_footer_inside=function()
    local a=api();local v=K.Table.New(a,a.InformationTooltip)
    local b={available=true,total=10,rows={{name=string.rep('N',100),value=10}}}
    local bounds={width=1800,height=900,title=string.rep('Title ',25)}
    v:Render(b,'en',bounds)
    b.rows[1].name='Short';bounds.keepLayout=true;v:Render(b,'en',bounds)
    T.eq(a.InformationTooltip:GetWidth(),350);T.eq(v.bodyHeight>=22,true)
    T.eq(v.title.height>=v.title:GetTextHeight(),true)
    T.eq(v.footer.anchor[5]+v.footer.height<=v.height,true)
    T.eq(v.rows[1].labels[1].hidden,false)
 end,
 empty_tooltip_can_gain_sources=function()
    local a=api();local v=K.Table.New(a,a.InformationTooltip)
    local b={available=true,total=0,rows={}}
    v:Render(b,'en',{width=1200,height=800,title='Title'})
    local height=v.height
    b.rows={{name='Source',value=10}}
    v:Render(b,'en',{width=1200,height=800,title='Title',keepLayout=true})
    T.eq(v.height,height);T.eq(v.bodyHeight>=22,true)
 end,
 preview_wraps_inside_frozen_tooltip=function()
    local a=api();local v=K.Table.New(a,a.InformationTooltip)
    local b={available=true,total=12000,rows={{name='Base value',value=12000}}}
    local bounds={width=1200,height=800,title='Maximum Magicka'}
    v:Render(b,'en',bounds);local width,height=v.width,v.height
    b.preview={amount=100,total=12100};bounds.keepLayout=true;v:Render(b,'en',bounds)
    T.eq(v.width,width);T.eq(v.height,height)
    T.eq(v.preview.maxLines,nil);T.eq(v.previewValue.maxLines,nil)
    for _,label in ipairs({v.preview,v.previewValue})do
        for word in label.text:gmatch('%S+')do T.eq(label:GetStringWidth(word)<=label.width,true)end
        T.eq(label.height>=label:GetTextHeight(),true)
    end
    v:Scroll(-10000);T.eq(v.offset+v.bodyHeight,v.contentHeight)
 end,
 long_description_scrolls_with_sources=function()
    local a=api();local v=K.Table.New(a,a.InformationTooltip)
    v:Render({available=true,total=10,rows={{name='Source',value=10}}},'en',{width=400,height=320,title='Title',description=string.rep('Description ',80)})
    T.eq(v.bodyHeight>=22,true);T.eq(v.height+32<=320-64,true)
    T.eq(v.description.parent,v.content)
    v:Scroll(-10000);T.eq(v.offset+v.bodyHeight,v.contentHeight)
 end,
 critical_rows_are_percentages=function()
    local a=api();local v=K.Table.New(a,a.InformationTooltip)
    v:Render({available=true,total=10000,critical={verified=true,rating=10000,pointsPerPercent=200,slope=0.005,chance=50,offset=0},rows={{name='Source',value=1000}}},'en',{width=1200,height=800})
    T.eq(v.rows[1].labels[2].text,'5.0%')
    T.eq(v.footerValue.text,'50.0%');T.eq(v.formula,nil)
 end,
 native_tooltip_restored_after_exit=function()
    local a=api();local before={a.InformationTooltip:GetDimensionConstraints()}
    local bridge=K.Tooltip.Install(a,function()return {available=true,total=1,rows={{name='Source',value=1}}},'en'end)
    local row=a.Control();row.statEntry={statType=1}
    a.ZO_StatsEntry_OnMouseEnter(row);T.eq(a.originalCalls,nil)
    T.eq(bridge.view.description.text,'Native description 1')
    a.ZO_StatsEntry_OnMouseExit(row)
    local after={a.InformationTooltip:GetDimensionConstraints()};for i=1,4 do T.eq(after[i],before[i])end
    local other=a.Control();other.statEntry={statType=100}
    local result=a.ZO_StatsEntry_OnMouseEnter(other);T.eq(result,'native');T.eq(a.originalCalls,1)
 end,
 metadata_keeps_item_and_passive_icons=function()
    local s={meta={language='en'},constants={},equipment={{slot=1,name='Ring',icon='ring.dds',enchant={description='Adds 1000 Maximum Magicka.',hasCharges=false}}},skills={{id=1,name='Passive',icon='skill.dds',purchased=true,passive=true,lineActive=true,rank=2,description='Increases Maximum Magicka by 2000.'}}}
    local items=K.Sources.Equipment.Build(s);local skills=K.Sources.Skills.Build(s)
    T.eq(items[1].source.name,'Ring');T.eq(items[1].source.icon,'ring.dds')
    T.eq(skills[1].source.name,'Passive');T.eq(skills[1].source.icon,'skill.dds')
    local model=K.Model.Build({stats={maxMagicka={total=3000}},consistent=true}, {items[1],skills[1]})
    T.eq(model.maxMagicka.rows[1].name,'Ring');T.eq(model.maxMagicka.rows[1].icon,'ring.dds')
    local effects=K.Sources.Effects.Build({meta={language='en'},effects={{abilityId=61218,endTime=0,name='Food',icon='food.dds',description='Adds 1000 Maximum Magicka.'}}})
    T.eq(effects[1].source.name,'Food');T.eq(effects[1].source.icon,'food.dds')
    local a=dofile('KanaStatSources/tests/fixtures/capture.lua')()
    a.GetItemLinkIcon=function(link)return link..'.dds' end
    local gear=K.CaptureEquipment.Read(a)
    T.eq(gear.equipment[1].icon,'item:0.dds');T.eq(gear.sets[100].icon,'item:0.dds')
 end,
 reused_icon_hidden_when_absent=function()
    local a=api();local v=K.Table.New(a,a.InformationTooltip)
    v:Render({available=true,total=10,rows={{name='Ring',icon='ring.dds',value=10}}},'en',{width=1200,height=800})
    v:Render({available=true,total=10,rows={{labelKey='unknown',value=10}}},'en',{width=1200,height=800})
    T.eq(v.rows[1].icon.hidden,true);T.eq(v.rows[1].labels[1].text,'Unknown')
 end,
 champion_branch_icon_uses_native_type=function()
    local a=dofile('KanaStatSources/tests/fixtures/capture.lua')()
    a.CHAMPION_DISCIPLINE_TYPE_WORLD=77
    a.GetNumChampionDisciplines=function()return 1 end
    a.GetChampionDisciplineId=function(index)T.eq(index,1);return 400 end
    a.GetChampionDisciplineType=function(id)T.eq(id,400);return 77 end
    a.GetNumChampionDisciplineSkills=function()return 1 end
    a.GetChampionSkillId=function()return 10 end
    a.GetNumPointsSpentOnChampionSkill=function()return 50 end
    a.GetChampionSkillType=function()return 1 end
    a.CanChampionSkillTypeBeSlotted=function()return false end
    a.GetChampionSkillName=function()return 'Star' end
    a.GetChampionSkillCurrentBonusText=function()return 'Maximum Health: 1000' end
    local s=K.CaptureBuild.Read(a);s.meta={language='en'}
    T.eq(s.champion[1].disciplineId,400)
    local c=K.Sources.Champion.Build(s)
    T.eq(c[1].source.name,'Star');T.eq(c[1].source.icon,'EsoUI/Art/Champion/champion_points_stamina_icon.dds')
 end,
 all_champion_branch_colours=function()
    for _,entry in ipairs({{'WORLD','stamina'},{'COMBAT','magicka'},{'CONDITIONING','health'}})do
        local a=dofile('KanaStatSources/tests/fixtures/capture.lua')()
        a['CHAMPION_DISCIPLINE_TYPE_'..entry[1]]=77
        a.GetNumChampionDisciplines=function()return 1 end
        a.GetChampionDisciplineId=function()return 400 end
        a.GetChampionDisciplineType=function()return 77 end
        a.GetNumChampionDisciplineSkills=function()return 1 end
        a.GetChampionSkillId=function()return 10 end
        a.GetNumPointsSpentOnChampionSkill=function()return 50 end
        local s=K.CaptureBuild.Read(a)
        T.eq(s.champion[1].icon,'EsoUI/Art/Champion/champion_points_'..entry[2]..'_icon.dds')
    end
 end,
}
