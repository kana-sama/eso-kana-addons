local K=KanaStatSources
local S={};K.Stats=S
S.Definitions={
    {'maxHealth','STAT_HEALTH_MAX'}, {'maxMagicka','STAT_MAGICKA_MAX'}, {'maxStamina','STAT_STAMINA_MAX'},
    {'healthRecovery','STAT_HEALTH_REGEN_COMBAT'}, {'magickaRecovery','STAT_MAGICKA_REGEN_COMBAT'}, {'staminaRecovery','STAT_STAMINA_REGEN_COMBAT'},
    {'weaponDamage','STAT_POWER'}, {'spellDamage','STAT_SPELL_POWER'},
    {'weaponCritical','STAT_CRITICAL_STRIKE'}, {'spellCritical','STAT_SPELL_CRITICAL'},
    {'physicalPenetration','STAT_PHYSICAL_PENETRATION'}, {'spellPenetration','STAT_SPELL_PENETRATION'},
    {'physicalResistance','STAT_PHYSICAL_RESIST'}, {'spellResistance','STAT_SPELL_RESIST'}, {'criticalResistance','STAT_CRITICAL_RESISTANCE'},
}
S.Strings={
    ru={source='Источник',bonus='Бонус',value='Вклад в итог',total='Итого',unknown='Неизвестно',base='Базовое значение',attributes='Атрибуты',preview='Предпросмотр атрибутов',unavailable='Данные недоступны',formulaUnknown='Формула не распознана',rating='Итого рейтинг',scroll='Колесо мыши: источники',dump='Снимок',disk='Для записи на диск: /reloadui или выход из игры.',rank='ранг',points='очков'},
    en={source='Source',bonus='Bonus',value='Contribution',total='Total',unknown='Unknown',base='Base value',attributes='Attributes',preview='Attribute preview',unavailable='Data unavailable',formulaUnknown='Formula not recognized',rating='Total rating',scroll='Mouse wheel: sources',dump='Snapshot',disk='Use /reloadui or exit the game to save to disk.',rank='rank',points='points'},
}
function S.Text(language,key) return (S.Strings[language] or S.Strings.en)[key] or key end
function S.List(api)
    local out={}
    for _,d in ipairs(S.Definitions) do
        local id=api and api[d[2]]
        local name=d[1]
        if id and api.GetString then local ok,text=pcall(api.GetString,'SI_DERIVEDSTATS',id);if ok and text~='' then name=text end end
        out[#out+1]={key=d[1],id=id,name=name,critical=d[1]=='weaponCritical' or d[1]=='spellCritical'}
    end
    return out
end
function S.KeyForId(api,id) if id==nil then return nil end;for _,d in ipairs(S.Definitions) do if api[d[2]]==id then return d[1] end end end
function S.Number(value,language,decimals)
    local text=string.format('%.'..(decimals or 0)..'f',value)
    if language=='ru' then text=text:gsub('%.',',') end
    return text
end
