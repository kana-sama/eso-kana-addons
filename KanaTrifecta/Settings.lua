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
    local visibleName='|cFF0000Kana|r |cFFFFFFTrifecta Tracker|r'
    instance.settingsPanel=menu:RegisterAddonPanel(name,{type='panel',name=visibleName,displayName=visibleName,
        author='Kana',version='0.1.0',registerForRefresh=true,registerForDefaults=true})
    menu:RegisterOptionControls(name,{{type='checkbox',name=K.Strings.showBossKillTimes,default=true,
        getFunc=function() return instance.settings.showBossKillTimes end,
        setFunc=function(value) Settings.SetBossKillTimes(instance,value) end},
        {type='checkbox',name='Записывать диагностику',default=false,
        getFunc=function() return instance.diagnostics.enabled end,
        setFunc=function(value) instance.diagnostics:SetEnabled(value) end},
        {type='button',name='Показать состояние',func=function()
            local api=instance.api
            local snapshot=instance.run and instance.run:Snapshot() or {}
            api.d(instance.diagnostics:Status(snapshot))
            local current=instance.observer:ReadContext()
            local manager=api.SCENE_MANAGER
            local scene=manager and manager:GetCurrentScene()
            local gamepad=api.IsInGamepadPreferredMode and api.IsInGamepadPreferredMode() or false
            api.d(string.format('zone=%s; difficulty=%s; gamepad=%s; scene=%s',
                tostring(current.zoneId),tostring(current.difficulty),tostring(gamepad),scene and scene:GetName() or '?'))
            if instance.hud then api.d(instance.hud:Status()) end
        end},
        {type='button',name='Сохранить журнал диагностики',func=function()
            instance.saved.dump=instance.diagnostics:Dump(instance.run and instance.run:Snapshot() or {})
            if instance.api.d then instance.api.d('Kana Trifecta Tracker: журнал сохранён в KanaTrifectaState.dump.') end
        end}})
end
