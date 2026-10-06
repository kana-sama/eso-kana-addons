local K=KanaStatSources
K.Sources.Base={}
local evidence='ZOS Update 29 v6.3.5 base stats; rule limited to API 101051, level 50 CP160+, no battle leveling'
local recoveryEvidence='UESP confirmed recovery formulas at level 50: round(5.592*50+29.4)=309; round(9.30612*50+48.7)=514; verified against API 101051 client dump'
local criticalResistanceEvidence='ZOS Update 26 baseline critical resistance; UESP Update 29 base rating 1320; verified against API 101051 level-50 client dump'
local baseIcon='EsoUI/Art/MainMenu/menuBar_character_up.dds'
local function attributeIcon(resource)
    return '/esoui/art/characterwindow/Gamepad/gp_characterSheet_'..resource..'Icon.dds'
end
function K.Sources.Base.Build(s)
    local out,diagnostics={},{};local context=s.context or {};local language=(s.meta or {}).language or 'en'
    if (s.meta or {}).apiVersion==101051 and context.level==50 and (context.championPoints or 0)>=160 and context.battleLeveled==false and context.championBattleLeveled==false then
        for _,p in ipairs({{'maxHealth',16000},{'maxMagicka',12000},{'maxStamina',12000},{'weaponDamage',1000},{'spellDamage',1000},
            {'healthRecovery',309,recoveryEvidence},{'magickaRecovery',514,recoveryEvidence},{'staminaRecovery',514,recoveryEvidence},{'criticalResistance',1320,criticalResistanceEvidence}}) do
            out[#out+1]={key='base:'..p[1],category='base',stat=p[1],amount=p[2],operation='flat',label=K.Stats.Text(language,'base'),icon=baseIcon,evidence=p[3] or evidence}
        end
    else diagnostics[#diagnostics+1]={category='base',reason='base scaling not verified for this context'} end
    if (s.meta or {}).apiVersion==101051 then
        for _,stat in ipairs({'weaponCritical','spellCritical'})do
            local raw=(s.stats or {})[stat] or {};local base=raw.withoutBonus
            -- Only critical stats use this native baseline. Other stats can
            -- return their full total with DONT_APPLY_BONUS (see recovery).
            -- A naked API 101051 character has 2181 rating, or 9.953449%, so
            -- converting a nominal 10% back to rating creates a false -10.
            if K.Core.Finite(base) and base>=0 and base==math.floor(base) then
                out[#out+1]={key='base:'..stat,category='base',stat=stat,amount=base,operation='flat',label=K.Stats.Text(language,'base'),icon=baseIcon,evidence='GetPlayerStat(critical stat, STAT_BONUS_OPTION_DONT_APPLY_BONUS); API 101051 naked/no-critical-CP dump #4 confirms native critical baseline'}
            elseif K.Core.Finite(raw.total) then
                diagnostics[#diagnostics+1]={category='base',stat=stat,reason='native critical baseline unavailable or invalid'}
            end
        end
    end
    for _,p in ipairs({{'health','maxHealth'},{'magicka','maxMagicka'},{'stamina','maxStamina'}}) do
        local a=(s.attributes or {})[p[1]] or {}
        if K.Core.Finite(a.spent) and K.Core.Finite(a.perPoint) and a.spent>0 then
            out[#out+1]={key='attributes:'..p[1],category='attributes',stat=p[2],amount=a.spent*a.perPoint,operation='flat',name=K.Stats.Text(language,'attributes'),icon=attributeIcon(p[1]),label=K.Stats.Text(language,'attributes')..' ('..a.spent..')',evidence='GetAttributeDerivedStatPerPointValue raw attribute delta; UESP resource formulas apply percentages after attributes; API 101051 client replay',source={spent=a.spent,perPoint=a.perPoint}}
        end
    end
    return out,diagnostics
end
