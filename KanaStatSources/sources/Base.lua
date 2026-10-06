local K=KanaStatSources
K.Sources.Base={}
local evidence='ZOS Update 29 v6.3.5 base stats; rule limited to API 101051, level 50 CP160+, no battle leveling'
local baseIcon='EsoUI/Art/MainMenu/menuBar_character_up.dds'
local function attributeIcon(resource)
    return '/esoui/art/characterwindow/Gamepad/gp_characterSheet_'..resource..'Icon.dds'
end
function K.Sources.Base.Build(s)
    local out,diagnostics={},{};local context=s.context or {};local language=(s.meta or {}).language or 'en'
    if (s.meta or {}).apiVersion==101051 and context.level==50 and (context.championPoints or 0)>=160 and context.battleLeveled==false and context.championBattleLeveled==false then
        for _,p in ipairs({{'maxHealth',16000},{'maxMagicka',12000},{'maxStamina',12000},{'weaponDamage',1000},{'spellDamage',1000}}) do
            out[#out+1]={key='base:'..p[1],category='base',stat=p[1],amount=p[2],operation='flat',label=K.Stats.Text(language,'base'),icon=baseIcon,evidence=evidence}
        end
    else diagnostics[#diagnostics+1]={category='base',reason='base scaling not verified for this context'} end
    if (s.meta or {}).apiVersion==101051 then
        for _,stat in ipairs({'weaponCritical','spellCritical'})do
            out[#out+1]={key='base:'..stat,category='base',stat=stat,amount=10,operation='criticalChance',label=K.Stats.Text(language,'base'),icon=baseIcon,evidence='ZOS v1.6.5 base Critical Hit chance 10%; running-client GetCriticalStrikeChance calibration'}
        end
    end
    for _,p in ipairs({{'health','maxHealth'},{'magicka','maxMagicka'},{'stamina','maxStamina'}}) do
        local a=(s.attributes or {})[p[1]] or {}
        if K.Core.Finite(a.spent) and K.Core.Finite(a.perPoint) and a.spent>0 then
            out[#out+1]={key='attributes:'..p[1],category='attributes',stat=p[2],amount=a.spent*a.perPoint,operation='effectiveFlat',name=K.Stats.Text(language,'attributes'),icon=attributeIcon(p[1]),label=K.Stats.Text(language,'attributes')..' ('..a.spent..')',evidence='GetAttributeDerivedStatPerPointValue; native ZO_AttributeSpinner_Shared preview',source={spent=a.spent,perPoint=a.perPoint}}
        end
    end
    return out,diagnostics
end
