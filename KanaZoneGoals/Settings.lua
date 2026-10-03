local K=KanaZoneGoals

function K.AddCustomAchievement(zoneId,category,text)
    if type(zoneId)~='number' or zoneId<=0 or zoneId%1~=0 or not K.categoryById[category] then return false end
    local id=tonumber(text) or GetAchievementIdFromLink(text or '')
    if not id or id<=0 or id%1~=0 then return false end
    local name=GetAchievementInfo(id)
    if not name or name=='' then return false end
    local list=K.saved.custom[zoneId] or {};K.saved.custom[zoneId]=list
    for _,row in ipairs(list) do
        if row.id==id then row.category=category;K.Refresh();return true end
    end
    list[#list+1]={id=id,category=category};K.Refresh();return true
end

function K.OpenSettings()
    LibAddonMenu2:OpenToPanel(K.settingsPanel)
end

function K.RegisterSettings()
    local LAM=LibAddonMenu2
    -- LAM creates a global control with this ID; keep it separate from the addon table.
    local panelId=K.name..'SettingsPanel'
    K.settingsPanel=LAM:RegisterAddonPanel(panelId,{
        type='panel',name=K.name,displayName='KanaZoneGoals — цели местности',author='Kana',version=K.version,
        registerForRefresh=true,registerForDefaults=true,
    })
    local options={{type='description',text='Выберите цели, которые хотите выполнять. Отключённые категории не входят в общий прогресс. Настройки общие для персонажей аккаунта.'}}
    for _,category in ipairs(K.categories) do
        local id=category.id
        options[#options+1]={type='checkbox',name=category.name,width='full',default=true,
            tooltip=id=='dynamic' and 'В этой версии достижения событий добавляются вручную через раздел «Добавить достижение».' or nil,
            getFunc=function()return K.saved.categories[id]~=false end,
            setFunc=function(value)K.saved.categories[id]=value;K.Refresh()end}
    end
    options[#options+1]={type='checkbox',name='Исключать сеты данжей',default=true,
        tooltip='Скрывает сеты групповых подземелий, монстр-сеты и сеты испытаний.',
        getFunc=function()return K.saved.excludeDungeonSets~=false end,
        setFunc=function(value)K.saved.excludeDungeonSets=value;K.Refresh()end}
    options[#options+1]={type='checkbox',name='Скрывать выполненные цели',default=false,
        tooltip='Выполненные цели остаются в итоговом счётчике.',
        getFunc=function()return K.saved.hideCompleted end,
        setFunc=function(value)K.saved.hideCompleted=value;K.Refresh()end}
    options[#options+1]={type='description',text='Состав целей зависит от каталога источников. Можно добавить недостающее достижение в выбранную область. Прогресс будет читаться из игры.'}
    local pending={category='special',text='',zone=''}
    local labels,values={},{}
    for _,c in ipairs(K.categories) do
        if c.id~='quests' and c.id~='sets' and c.id~='antiquities' and c.id~='codex' and c.id~='collectibles' then labels[#labels+1]=c.name;values[#values+1]=c.id end
    end
    options[#options+1]={type='submenu',name='Добавить достижение',controls={
        {type='editbox',name='ID области',tooltip='Оставьте пустым для области, открытой на карте.',
            getFunc=function()return pending.zone end,setFunc=function(v)pending.zone=v end},
        {type='dropdown',name='Категория',choices=labels,choicesValues=values,
            getFunc=function()return pending.category end,setFunc=function(v)pending.category=v end},
        {type='editbox',name='ID или ссылка на достижение',width='full',
            getFunc=function()return pending.text end,setFunc=function(v)pending.text=v end},
        {type='button',name='Добавить',func=function()
            local zoneId=tonumber(pending.zone) or (K.mapPanel and K.mapPanel:GetCurrentZoneStoryZoneId())
            local ok=K.AddCustomAchievement(zoneId,pending.category,pending.text)
            d(ok and 'KanaZoneGoals: достижение добавлено.' or 'KanaZoneGoals: проверьте область и ID/ссылку достижения.')
        end},
    }}
    LAM:RegisterOptionControls(panelId,options)
end
