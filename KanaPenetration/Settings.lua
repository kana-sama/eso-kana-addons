local K = KanaPenetration
local DISPLAY_NAME = '|cFF0000Kana|r Armor Penetration Bar'
K.Defaults = {enabled=true, showNumbers=true, profile='auto', customResistance=18200,
    crusher=2108, alkosh=6000, tremorscale=2640}

function K.Normalize(settings)
    for _, key in ipairs({'enabled','showNumbers'}) do
        if type(settings[key]) ~= 'boolean' then settings[key] = K.Defaults[key] end
    end
    if not ({auto=true, overland=true, dungeon=true, custom=true})[settings.profile] then settings.profile = 'auto' end
    for _, range in ipairs({{'customResistance',0,100000}, {'crusher',0,10000}, {'alkosh',0,10000},
        {'tremorscale',0,10000}}) do
        local key, low, high = unpack(range)
        local value = settings[key]
        if type(value) ~= 'number' or value ~= value or value == math.huge or value == -math.huge then
            value = K.Defaults[key]
        end
        settings[key] = math.max(low, math.min(high, value))
    end
end

function K:RegisterSettings()
    local s, ru = self.saved, self.russian
    local function L(russian, english) return ru and russian or english end
    local function Get(key) return function() return s[key] end end
    local function Set(key)
        return function(value)
            s[key] = value
            K.Normalize(s)
            self:Refresh()
        end
    end
    local function Slider(key, name, min, max, step)
        return {type='slider', name=name, min=min, max=max, step=step,
            getFunc=Get(key), setFunc=Set(key), default=K.Defaults[key], width='full'}
    end
    self.panel = LibAddonMenu2:RegisterAddonPanel('KanaPenetrationOptions', {
        type='panel', name=DISPLAY_NAME, displayName=DISPLAY_NAME, author='Kana', version='1.0.0',
        registerForRefresh=true, registerForDefaults=true,
    })
    LibAddonMenu2:RegisterOptionControls('KanaPenetrationOptions', {
        {type='description', text=L(
            'Личное пробитие / сопротивление цели после дебаффов. ≈ означает расчёт по предполагаемой броне, ? — неизвестное значение. 100% относится только к броне. Эффекты, игнорирующие броню отдельных атак, не моделируются.',
            'Personal penetration / target resistance after debuffs. ≈ is an estimate using assumed armor; ? is unknown. 100% only concerns armor. Effects that bypass armor for particular attacks are not modeled.')},
        {type='checkbox',name=L('Включить','Enable'),getFunc=Get('enabled'),setFunc=Set('enabled'),default=true},
        {type='checkbox',name=L('Показывать числа','Show numbers'),getFunc=Get('showNumbers'),setFunc=Set('showNumbers'),default=true},
        {type='description',text=L(
            'Шкала между HP и именем повторяет размер рамки цели. Две строки: физическое пробитие сверху, магическое снизу. Тире вместо процента означает, что расчётная броня уже снята.',
            'Between HP and the name, the bar follows the target frame size. With two rows, physical penetration is above spell penetration. A dash means the estimated armor is already stripped.')},
        {type='header',name=L('Сопротивление цели','Target resistance')},
        {type='description',text=L(
            'Авто: 9100 для оверленда, квестов, логов, публичных подземелий и всех целей Архива, кроме То’ат Копировальщицы; для неё, групповых подземелий и испытаний — 18200. Манекены распознаются отдельно: 18200, у Прототипа 9100; встроенные дебаффы рейдовых манекенов учтены. Для одиночных арен выберите профиль вручную. Ручной профиль действует на все цели, пока вы не вернёте «Авто».',
            'Auto: 9100 for overland, quests, delves, public dungeons and Archive targets other than Tho’at Replicanum; 18200 for Tho’at, group dungeons and trials. Dummies are recognized separately: 18200, or 9100 for the Precursor; trial dummy debuffs are included. Select a manual profile for solo arenas. A manual profile applies to all targets until you switch back to Auto.')},
        {type='dropdown',name=L('Профиль сопротивления','Resistance profile'),
            choices={L('Авто','Auto'),L('Оверленд — 9100','Overland — 9100'),L('Подземелье — 18200','Dungeon — 18200'),L('Своё значение','Custom')},
            choicesValues={'auto','overland','dungeon','custom'},getFunc=Get('profile'),setFunc=Set('profile'),default='auto',width='full'},
        Slider('customResistance',L('Своё базовое сопротивление','Custom base resistance'),0,100000,1),
        {type='header',name=L('Предполагаемая сила дебаффов','Assumed debuff strength')},
        {type='description',text=L(
            'Эти величины используются только пока соответствующий дебафф виден на цели. Сила чужих эффектов не читается напрямую. Major/Minor Breach и остальные поддерживаемые фиксированные эффекты учитываются автоматически.',
            'These values are used only while the corresponding debuff is visible on the target. Other players’ debuff strength is not directly available. Major/Minor Breach and other supported fixed effects are handled automatically.')},
        Slider('crusher','Crusher',0,10000,1),
        Slider('alkosh','Alkosh',0,10000,1),
        Slider('tremorscale','Tremorscale',0,10000,1),
        {type='description',text=L(
            '«Сила природы»: часть статусов скрыта от списка эффектов цели. При активной звезде показывается диапазон: от видимого бонуса до максимально возможного. Заполнение полосы соответствует нижней границе.',
            'Force of Nature: some statuses are absent from the target buff list. With this star active, the display spans the visible bonus to the maximum possible bonus. The bar fills to the lower bound.')},
    })
end
