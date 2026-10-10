if GetCVar and GetCVar('language.2')=='ru' then
    local strings={achievements='Достижения подземелья',catalogUnavailable='Список достижений пока недоступен',
        hardMode='У босса есть хардмод',hardmodeMissing='Босс убит без обязательного хардмода',
        hardmodeUnknown='Босс убит, режим последнего боя не подтверждён',pending='Подтверждённого убийства ещё нет',
        completed='Подтверждённое убийство',
        timerLimit='Лимит',timerElapsed='Прошло',timerRemaining='Осталось',timerOvertime='Превышение',
        showBossKillTimes='Показывать время убийства боссов',
        back='Назад',partialProfile='Часть правил этого подземелья ещё не проверена',unsupported='Правила подземелья пока недоступны'}
    for key,value in pairs(strings) do KanaTrifecta.Strings[key]=value end
end
