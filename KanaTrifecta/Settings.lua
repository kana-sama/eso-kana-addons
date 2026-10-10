local K=KanaTrifecta
local Settings={};K.Settings=Settings
function Settings.SetBossKillTimes(instance,value)
    instance.settings.showBossKillTimes=value==true
    instance:UpdateView()
end
function Settings.Initialize(instance)
    local saved=instance.saved
    if type(saved.settings)~='table' then saved.settings={} end
    if type(saved.settings.showBossKillTimes)~='boolean' then saved.settings.showBossKillTimes=true end
    instance.settings=saved.settings
    local menu=instance.api.LibAddonMenu2
    if not menu then return end
    local name='KanaTrifectaOptions'
    instance.settingsPanel=menu:RegisterAddonPanel(name,{type='panel',name='KanaTrifecta',displayName='KanaTrifecta',
        author='Kana',version='0.1.0',registerForRefresh=true,registerForDefaults=true})
    menu:RegisterOptionControls(name,{{type='checkbox',name=K.Strings.showBossKillTimes,default=true,
        getFunc=function() return instance.settings.showBossKillTimes end,
        setFunc=function(value) Settings.SetBossKillTimes(instance,value) end}})
end
