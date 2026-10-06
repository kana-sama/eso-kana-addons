local K=KanaStatSources
local D={};K.Descriptions=D
local capitals={}
do local upper,lower='АБВГДЕЁЖЗИЙКЛМНОПРСТУФХЦЧШЩЪЫЬЭЮЯ','абвгдеёжзийклмнопрстуфхцчшщъыьэюя';for i=1,#upper,2 do capitals[upper:sub(i,i+1)]=lower:sub(i,i+1) end end
function D.Clean(s) return (s or ''):gsub('|[cC]%x%x%x%x%x%x',''):gsub('|[rR]',''):gsub('|u[0-9]+:[0-9]+:(.-)|u','%1'):gsub(' ',' '):gsub(' ',' '):gsub('\r',''):gsub('​','') end
-- Lua 5.1 on macOS may apply a single-byte locale to UTF-8. Lowercase ASCII
-- separately, then map complete Russian characters without touching their bytes.
function D.Lower(s) return s:gsub('[A-Z]',string.lower):gsub('[\192-\244][\128-\191]+',capitals) end
function D.Tokens(s,language)
    s=D.Clean(s);local count
    repeat s,count=s:gsub('([0-9]) ([0-9][0-9][0-9])','%1%2') until count==0
    local values={}
    s=s:gsub('[0-9][0-9%.,]*',function(raw)
        local ending=raw:match('[%.,]+$') or '';raw=raw:sub(1,#raw-#ending)
        local number=language=='ru' and raw:gsub(',','.') or raw:gsub(',','')
        values[#values+1]=tonumber(number)
        return '@'..#values..'@'..ending
    end)
    return D.Lower(s),values
end
local aliases={
    {{'weaponDamage','spellDamage'},{'weapon and spell damage','сила оружия и заклинаний','силу оружия и заклинаний','силы оружия и заклинаний'}},
    {{'weaponCritical','spellCritical'},{'weapon and spell critical rating','weapon and spell critical','critical chance','critical rating','критический рейтинг','крит. рейтинг','критический рейтинг оружия и заклинаний','шанс критического удара','шанс крит. удара'}},
    {{'physicalResistance','spellResistance'},{'physical and spell resistance','физическую и магическую сопротивляемость','физическая и магическая сопротивляемость','физической и магической сопротивляемости','armor','броню'}},
    {{'physicalPenetration','spellPenetration'},{'physical and spell penetration','offensive penetration','physical and magical penetration','физическое и магическое пробивание','физического и магического пробивания','пробивание'}},
    {{'healthRecovery'},{'health recovery','восстановление здоровья','восст. здоровья'}},
    {{'magickaRecovery'},{'magicka recovery','восстановление магии','восст. магии'}},
    {{'staminaRecovery'},{'stamina recovery','восстановление запаса сил','восст. запаса сил'}},
    {{'maxHealth'},{'maximum health','max health','максимальное здоровье','максимального здоровья','макс. здоровье'}},
    {{'maxMagicka'},{'maximum magicka','max magicka','максимальная магия','максимальный запас магии','максимального запаса магии','максимальную магию','макс. магия'}},
    {{'maxStamina'},{'maximum stamina','max stamina','максимальный запас сил','максимального запаса сил','макс. запас сил'}},
    {{'weaponDamage'},{'weapon damage','силу оружия','сила оружия','силы оружия'}},
    {{'spellDamage'},{'spell damage','силу заклинаний','сила заклинаний','силы заклинаний'}},
    {{'weaponCritical'},{'weapon critical rating','weapon critical','критический рейтинг оружия'}},
    {{'spellCritical'},{'spell critical rating','spell critical','критический рейтинг заклинаний'}},
    {{'physicalResistance'},{'physical resistance','физическую сопротивляемость','физическая сопротивляемость'}},
    {{'spellResistance'},{'spell resistance','магическую сопротивляемость','магическая сопротивляемость'}},
    {{'criticalResistance'},{'critical resistance','критическое сопротивление','критическую сопротивляемость','сопротивляемость критическому урону'}},
}
local function escape(s) return s:gsub('([%^%$%(%)%%%.%[%]%*%+%-%?])','%%%1') end
function D.Parse(raw,language,kind)
    if language~='ru' and language~='en' then return {},raw or '' end
    local text,values=D.Tokens(raw,language);text=text:gsub('^[ \t\n]*%([^%)]*%)[ \t\n]*','')
    local clauses={}
    while text~='' do
        text=text:gsub('^[ \t\n%.,;]+','');if text=='' then break end
        local matched=false
        for _,definition in ipairs(aliases) do
            for _,alias in ipairs(definition[2]) do
                local a=escape(alias);local index,percent,tail,sign
                index,percent,tail=text:match('^adds @([0-9]+)@([%%]?) '..a..'(.*)$')
                if not index then index,percent,tail=text:match('^'..a..'[ \t]*%+@([0-9]+)@([%%]?)(.*)$') end
                if not index and kind=='champion' then index,percent,tail=text:match('^'..a..':[ \t]*@([0-9]+)@([%%]?)(.*)$') end
                if not index then
                    for _,verb in ipairs({'increases? your ','increases? ','increase ','увеличивает ваши ','увеличивает ваше ','увеличивает ','повышает '}) do
                        index,percent,tail=text:match('^'..verb..a..' [bn][ya] @([0-9]+)@([%%]?)(.*)$')
                        if not index then index,percent,tail=text:match('^'..verb..a..' на @([0-9]+)@([%%]?)(.*)$') end
                        if index then break end
                    end
                end
                if not index then index,percent,tail=text:match('^reduces your '..a..' by @([0-9]+)@([%%]?)(.*)$');if index then sign=-1 end end
                if not index then index,percent,tail=text:match('^уменьшает '..a..' на @([0-9]+)@([%%]?)(.*)$');if index then sign=-1 end end
                if not index and kind=='effect' then index,percent,tail=text:match('^'..a..' by @([0-9]+)@([%%]?)(.*)$') end
                if index then
                    local ending=tail
                    if kind=='effect' then ending=ending:gsub('^ for @[0-9]+@ hours?%.?$',''):gsub('^ for @[0-9]+@ minutes?%.?$',''):gsub('^ for @[0-9]+@ seconds?%.?$',''):gsub('^ на @[0-9]+@ ч%.?$','') end
                    local conjunction=kind=='effect' and (ending:match('^ and (.*)$') or ending:match('^ и (.*)$'))
                    if ending=='' or ending:match('^[%.,;\n]') or conjunction then
                        local operation=percent=='%' and 'percent' or 'flat'
                        if percent=='%' and (definition[1][1]=='weaponCritical' or definition[1][1]=='spellCritical') then operation='criticalChance' end
                        clauses[#clauses+1]={stats=definition[1],operation=operation,amount=values[tonumber(index)]*(sign or 1),confirmed=true,raw=raw}
                        text=conjunction or ending;matched=true;break
                    end
                end
            end
            if matched then break end
        end
        if not matched then break end
    end
    return clauses,text
end
