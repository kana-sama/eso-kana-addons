local KW=KanaWardrobe
local Effects={}; KW.EffectModel=Effects
local function clean(s)
    return (s or ""):gsub("|[cC]%x%x%x%x%x%x", ""):gsub("|[rR]", "")
        :gsub("|u[0-9]+:[0-9]+:(.-)|u", "%1"):gsub(" ", " "):gsub(" ", " ")
        :gsub("​", ""):gsub("﻿", ""):gsub("\r\n", "\n"):gsub("\r", "\n")
end
local capitals={}
do
    local upper,lower="АБВГДЕЁЖЗИЙКЛМНОПРСТУФХЦЧШЩЪЫЬЭЮЯ","абвгдеёжзийклмнопрстуфхцчшщъыьэюя"
    for i=1,#upper,2 do capitals[upper:sub(i,i+1)]=lower:sub(i,i+1) end
end
local function lower(s)
    if zo_strlower then return zo_strlower(s) end
    return s:lower():gsub("[\192-\244][\128-\191]+",capitals)
end
local function tokenize(s,language)
    s=clean(s)
    local count
    repeat s,count=s:gsub("([0-9]) ([0-9][0-9][0-9])","%1%2") until count==0
    local comma=language=="ru" or language=="de" or language=="fr" or s:find("[\208\209]")~=nil
    local values={}
    -- Do not use %d: ESO/macOS classifies bytes B2/B3/B9 as digits. Those
    -- also occur inside Russian UTF-8 letters; replacing them corrupts text.
    s=s:gsub("[0-9][0-9%.,]*",function(raw)
        local suffix=raw:match("[%.,]+$") or ""
        raw=raw:sub(1,#raw-#suffix)
        local n=raw
        if comma then
            if raw:find(",",1,true) then n=raw:gsub("%.",""):gsub(",",".") end
        else n=raw:gsub(",","") end
        values[#values+1]=tonumber(n) or 0
        return "@"..#values.."@"..suffix
    end)
    return lower(s),values,s
end
local definitions={
    health={"Здоровье","Health",1},magicka={"Магия","Magicka",2},stamina={"Запас сил","Stamina",3},
    healthRecovery={"Восстановление здоровья","Health recovery",4},magickaRecovery={"Восстановление магии","Magicka recovery",5},staminaRecovery={"Восстановление запаса сил","Stamina recovery",6},
    power={"Сила оружия и заклинаний","Weapon and spell damage",10},critical={"Критический рейтинг","Critical rating",11},
    penetration={"Пробивание","Penetration",12},resistance={"Сопротивление","Resistance",13},
    criticalChance={"Шанс критического удара","Critical chance",11,"%"},criticalResistance={"Критическое сопротивление","Critical resistance",15},
    monsterDirectDamage={"Прямой урон по монстрам","Direct damage to monsters",16,"%",category="damage"},
    monsterDamage={"Урон по монстрам","Damage to monsters",17,"%",category="damage"},
    damageOverTime={"Периодический урон","Damage over time",18,"%",category="damage"},
    channeledDamage={"Потоковый урон","Channeled damage",19,"%",category="damage"},
    healing={"Исходящее исцеление","Healing done",20,"%"},statusChance={"Шанс наложения эффектов состояния","Status effect chance",21,"%"},
    blockCost={"Стоимость блока","Block cost",30,"%",-1},rollCost={"Стоимость переката и спринта","Roll dodge and sprint cost",31,"%",-1},
    movement={"Скорость передвижения","Movement speed",32,"%"},mundus={"Эффект камня Мундуса","Mundus Stone effect",40,"%"},
    experience={"Опыт за убийства","Experience from kills",41,"%"},
}
local aliases={
    health={"макс. здоровье","максимальное здоровье","maximum health"},
    magicka={"макс. магия","максимальный запас магии","maximum magicka"},
    stamina={"макс. запас сил","максимальный запас сил","maximum stamina"},
    healthRecovery={"восст. здоровья","восстановление здоровья","health recovery"},
    magickaRecovery={"восст. магии","восстановление магии","magicka recovery"},
    staminaRecovery={"восст. запаса сил","восстановление запаса сил","stamina recovery"},
    power={"сила оружия и заклинаний","weapon and spell damage"},
    critical={"шанс крит. удара","шанс критического удара","критический рейтинг","weapon and spell critical","critical chance","critical rating"},
    penetration={"пробивание","физическое и магическое пробивание","physical and spell penetration","offensive penetration"},
    resistance={"физическая и магическая сопротивляемость","physical and spell resistance","armor"},
}
local function escaped(s) return s:gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])","%%%1") end
-- Consume the whole description, clause by clause. A conditional sentence must
-- never contribute its embedded stat numbers to permanent totals.
local function parseStats(description,language)
    local text,values=tokenize(description,language)
    text=text:gsub("^%s*%([^%)]*%)%s*","")
    local found={}
    while text~="" do
        text=text:gsub("^[%s%.,;]+","")
        if text=="" then return found end
        local matched=false
        for key,names in pairs(aliases) do
            for _,name in ipairs(names) do
                local pattern=escaped(name)
                local index,tail=text:match("^"..pattern.."%s*%+@([0-9]+)@(.*)$")
                if not index then index,tail=text:match("^adds @([0-9]+)@ "..pattern.."(.*)$") end
                local percent=false
                if not index and key=="critical" then
                    index,tail=text:match("^adds @([0-9]+)@%% "..pattern.."(.*)$")
                    percent=index~=nil
                end
                if index then
                    local statKey=percent and "criticalChance" or key
                    if key=="critical" and tail:sub(1,1)=="%" then
                        statKey="criticalChance";tail=tail:sub(2)
                    end
                    -- Require a clause boundary, not 'for 10 seconds'.
                    if tail=="" or tail:match("^[%.,;\n]") then
                        found[statKey]=(found[statKey] or 0)+values[tonumber(index)]
                        text=tail;matched=true;break
                    end
                end
            end
            if matched then break end
        end
        if not matched then return nil end
    end
    return next(found) and found or nil
end
local traitKeys={
    WEAPON_TRAINING="experience",ARMOR_TRAINING="experience",ARMOR_DIVINES="mundus",
    JEWELRY_SWIFT="movement",WEAPON_PRECISE="criticalChance",WEAPON_CHARGED="statusChance",
    WEAPON_POWERED="healing",WEAPON_SHARPENED="penetration",WEAPON_DEFENDING="resistance",
    ARMOR_IMPENETRABLE="criticalResistance",ARMOR_STURDY="blockCost",ARMOR_WELL_FITTED="rollCost",
    JEWELRY_HEALTHY="health",JEWELRY_ARCANE="magicka",JEWELRY_ROBUST="stamina",JEWELRY_PROTECTIVE="resistance",
}
local function traitIs(trait,name) return _G["ITEM_TRAIT_TYPE_"..name]~=nil and trait.id==_G["ITEM_TRAIT_TYPE_"..name] end
local damageRules={
    {"^прямой урон, наносимый монстрам, увеличивается на%s+([0-9]+[.,]?[0-9]*)%%",{"monsterDirectDamage"}},
    {"^урон, наносимый монстрам, увеличивается на%s+([0-9]+[.,]?[0-9]*)%%",{"monsterDamage"}},
    {"^ваши атаки с периодическим уроном, а также атаки с необходимостью поддержания наносят на%s+([0-9]+[.,]?[0-9]*)%%%s+больше урона",{"damageOverTime","channeledDamage"}},
}
-- Only consume complete, known unconditional sentences at the beginning.
-- Unknown/conditional text retains its wording, paragraphs and source title.
local function extractDamage(description,add)
    local remaining=clean(description):gsub("^%s*%([^%)]*%)%s*",""):gsub("^%s+","")
    while remaining~="" do
        local matched=false
        local normalized=lower(remaining)
        for _,rule in ipairs(damageRules)do
            local raw,ending=normalized:match(rule[1].."%.()")
            if not raw then raw,ending=normalized:match(rule[1].."()%s*$")end
            if raw then
                local value=tonumber((raw:gsub(",",".")))
                for _,key in ipairs(rule[2])do add(key,value)end
                remaining=remaining:sub(ending):gsub("^%s+","")
                matched=true;break
            end
        end
        if not matched then break end
    end
    return remaining
end
function Effects.Build(items,sets)
    local result={stats={},details={},armor={front=0,back=0},contributions={}}
    local details,conditional={},{}
    local currentSource
    local function contribution(key,value,front,back)
        local entries=result.contributions[key] or {};result.contributions[key]=entries
        entries[#entries+1]={source=currentSource,front=front and value or 0,back=back and value or 0}
    end
    local function add(key,value,front,back)
        local entry=result.stats[key] or {front=0,back=0};result.stats[key]=entry
        if front then entry.front=entry.front+value end
        if back then entry.back=entry.back+value end
        contribution(key,value,front,back)
    end
    local function detail(description,front,back,source,origins)
        description=clean(description):gsub("^%s*%([^%)]*%)%s*","")
        if description=="" then return end
        local key=description
        local e=details[key]
        if not e then e={description=description,source=source,front=false,back=false,sources={}};details[key]=e;result.details[#result.details+1]=e end
        e.front=e.front or front;e.back=e.back or back
        for _,origin in ipairs(origins or {{source=currentSource,front=front,back=back}})do
            if origin.source and ((front and origin.front) or (back and origin.back))then
                e.sources[#e.sources+1]={source=origin.source,front=front and origin.front,back=back and origin.back}
            end
        end
    end
    local function passive(description,language,front,back,source)
        description=extractDamage(description,function(key,value)add(key,value,front,back)end)
        if description=="" then return end
        local stats=parseStats(description,language)
        if stats then for key,value in pairs(stats) do add(key,value,front,back) end
        else detail(description,front,back,source) end
    end
    for _,item in ipairs(items) do
        local m=item.metadata
        currentSource=item.source or {slot=item.slot,link=item.link or m.link,kind="item"}
        local front=item.slot~=KW.Slots.Back.main and item.slot~=KW.Slots.Back.off
        local back=item.slot~=KW.Slots.Front.main and item.slot~=KW.Slots.Front.off
        if m.armorRating then
            if front then result.armor.front=result.armor.front+m.armorRating end
            if back then result.armor.back=result.armor.back+m.armorRating end
            contribution("armor",m.armorRating,front,back)
        end
        local enchant=m.enchant
        if enchant then
            -- Native enchant descriptions already represent this item's glyph
            -- (including Infused). Never apply the trait percentage a second time.
            if enchant.hasCharges then detail(enchant.description,front,back,enchant.name)
            else passive(enchant.description,enchant.language,front,back) end
        end
        local trait=m.trait
        if trait then
            local template,values,original=tokenize(trait.description,trait.language)
            local handled=false
            for name,key in pairs(traitKeys) do
                if traitIs(trait,name) and #values==1 then add(key,values[1],front,back);handled=true;break end
            end
            if traitIs(trait,"ARMOR_PROSPEROUS") and #values==1 then
                for _,key in ipairs({"healthRecovery","magickaRecovery","staminaRecovery"}) do add(key,values[1],front,back) end
                handled=true
            elseif traitIs(trait,"JEWELRY_TRIUNE") and #values==3 then
                local resources={health={"health","здоровье","здоровья"},magicka={"magicka","магии","магия"},stamina={"stamina","запас сил","запаса сил"}}
                local found={}
                for key,names in pairs(resources) do
                    for _,name in ipairs(names) do
                        local index=template:match(escaped(name).." by @([0-9]+)@") or template:match(escaped(name).." на @([0-9]+)@")
                        if index then found[key]=values[tonumber(index)];break end
                    end
                end
                if found.health and found.magicka and found.stamina then
                    for key,value in pairs(found)do add(key,value,front,back)end
                    handled=true
                end
            elseif traitIs(trait,"JEWELRY_BLOODTHIRSTY") or traitIs(trait,"JEWELRY_HARMONY") then
                local index
                if traitIs(trait,"JEWELRY_HARMONY") and #values==1 then index=1
                else index=template:match("up to @([0-9]+)@") or template:match("до @([0-9]+)@") end
                if index then
                    index=tonumber(index)
                    local key=template:gsub("@([0-9]+)@",function(i)return tonumber(i)==index and "VALUE" or tostring(values[tonumber(i)])end)
                    local c=conditional[key]
                    if not c then c={original=original,values=values,index=index,front=0,back=0,source=trait.name,sources={}};conditional[key]=c end
                    if front then c.front=c.front+values[index]end
                    if back then c.back=c.back+values[index]end
                    c.sources[#c.sources+1]={source=currentSource,front=front,back=back}
                    handled=true
                end
            elseif traitIs(trait,"ARMOR_INFUSED") or traitIs(trait,"JEWELRY_INFUSED")
                or traitIs(trait,"ARMOR_REINFORCED") or traitIs(trait,"ARMOR_NIRNHONED") then
                handled=true
            elseif traitIs(trait,"WEAPON_INFUSED") and #values==2 then
                -- Glyph strength is already included, but the cooldown change
                -- remains a separate local effect and must stay visible.
                local ru=trait.language=="ru"
                detail((ru and "Перезарядка зачарования: −" or "Enchantment cooldown: −")..tostring(values[2]).."%",front,back,trait.name)
                handled=true
            end
            if not handled then
                -- Local weapon modifiers, conditional traits and unknown text
                -- keep their actual effect; never replace it with an item count.
                detail(trait.description,front,back,trait.name)
            end
        end
    end
    local conditionalKeys={};for key in pairs(conditional)do conditionalKeys[#conditionalKeys+1]=key end;table.sort(conditionalKeys)
    for _,key in ipairs(conditionalKeys)do
        local c=conditional[key]
        local function description(value)
            return c.original:gsub("@([0-9]+)@",function(i)return tostring(tonumber(i)==c.index and value or c.values[tonumber(i)])end)
        end
        if c.front==c.back then detail(description(c.front),true,true,c.source,c.sources)
        else
            if c.front>0 then detail(description(c.front),true,false,c.source,c.sources)end
            if c.back>0 then detail(description(c.back),false,true,c.source,c.sources)end
        end
    end
    for _,set in ipairs(sets) do
        currentSource=KW.Copy(set.representativeSource or {link=set.representativeLink})
        currentSource.kind="set";currentSource.setName=set.setName;currentSource.setId=set.familyId or set.setId
        for _,bonus in ipairs(set.bonuses) do
            if bonus.activeFront or bonus.activeBack then
                passive(bonus.description,nil,bonus.activeFront,bonus.activeBack,set.setName)
            end
        end
    end
    return result
end
local function number(n,ru)
    local s=string.format("%.1f",n):gsub("0+$",""):gsub("%.$","")
    return ru and s:gsub("%.",",") or s
end
local function pair(a,b,ru,suffix,sign)
    local function one(v) return (v==0 and "" or (sign or "+"))..number(v,ru)..(suffix or "") end
    if math.abs(a-b)<0.00001 then return one(a) end
    return "[ "..(a~=0 and one(a) or "—").." | "..(b~=0 and one(b) or "—").." ]"
end
local function sourceName(source,ru)
    local name=source.kind=="set" and source.setName or source.name
    if not name and source.link and GetItemLinkName then name=GetItemLinkName(source.link)end
    if name and name~="" then
        if zo_strformat and SI_TOOLTIP_ITEM_NAME then name=zo_strformat(SI_TOOLTIP_ITEM_NAME,name)end
    else name=source.link or (ru and "Предмет" or "Item")end
    return name
end

-- Keep one decimal in every row while preserving the displayed total. Largest
-- remainders distribute the rounding tenth instead of inventing another bonus.
local function roundedParts(rows,bar,total)
    local target=math.floor(tonumber(number(total,false))*10+0.5)
    local sum,order=0,{}
    for i,row in ipairs(rows)do
        local exact=row[bar]*10
        row[bar.."Units"]=math.floor(exact+0.0000001)
        sum=sum+row[bar.."Units"]
        if row[bar]~=0 then order[#order+1]={index=i,fraction=exact-row[bar.."Units"]}end
    end
    table.sort(order,function(a,b)if math.abs(a.fraction-b.fraction)>0.0000001 then return a.fraction>b.fraction end;return a.index<b.index end)
    for i=1,(#order>0 and math.max(0,target-sum) or 0)do
        local entry=order[(i-1)%#order+1]
        if entry then local row=rows[entry.index];row[bar.."Units"]=row[bar.."Units"]+1 end
    end
    for _,row in ipairs(rows)do row[bar]=row[bar.."Units"]/10 end
end

function Effects.Breakdown(e,key,total,language,bar,suffix,sign,divisor,title)
    local contributions=e.contributions or {}
    local keys=key=="criticalChance" and {"critical","criticalChance"} or {key}
    local rows,index={},{}
    divisor=divisor or 1
    for _,stat in ipairs(keys)do for _,part in ipairs(contributions[stat] or {})do
        local source=part.source or {}
        local id=(source.kind or "item")..":"..tostring(source.setId or "")..":"..tostring(source.uid or source.slot or source.link)
        local f,b=part.front,part.back
        if stat=="critical" then f,b=GetCriticalStrikeChance(f),GetCriticalStrikeChance(b)end
        f,b=f/divisor,b/divisor
        if bar then f=bar=="front" and f or b;b=f end
        if f~=0 or b~=0 then
            local row=index[id]
            if not row then row={name=sourceName(source,language=="ru"),link=source.link,source=source,front=0,back=0};index[id]=row;rows[#rows+1]=row end
            row.front=row.front+f;row.back=row.back+b
        end
    end end
    if #rows==0 then return nil end
    local f,b=total.front/divisor,total.back/divisor
    if bar then f=bar=="front" and f or b;b=f end
    for _,row in ipairs(rows)do row.frontPresent=row.front~=0;row.backPresent=row.back~=0 end
    roundedParts(rows,"front",f);roundedParts(rows,"back",b)
    local different=f~=b
    for _,row in ipairs(rows)do
        different=different or row.front~=row.back or row.frontPresent~=row.backPresent
        row.value=pair(row.front,row.back,language=="ru",suffix,sign)
    end
    return {kind="breakdown",title=title,rows=rows,front=tonumber(number(f,false)),back=tonumber(number(b,false)),
        frontPresent=f~=0,backPresent=b~=0,
        value=pair(f,b,language=="ru",suffix,sign),differentBars=different,bar=bar,suffix=suffix,sign=sign,language=language}
end
function Effects.Present(summary,language)
    local ru=language=="ru"
    local e=summary.effects
    -- Convert at presentation time using the same player-scaled API as the
    -- native character sheet. Keep raw totals intact across repeated hovers.
    local stats={}
    for key,value in pairs(e.stats)do stats[key]=value end
    if stats.critical then
        local rating=stats.critical
        local chance=stats.criticalChance or {front=0,back=0}
        stats.criticalChance={
            front=chance.front+GetCriticalStrikeChance(rating.front),
            back=chance.back+GetCriticalStrikeChance(rating.back),
        }
        stats.critical=nil
    end
    local view={metrics={},sets={},rows={},details={},detailSources={},specials={},differentBars=false,barGroups={
        {bar="front",title=ru and "I · Основная" or "I · Main",rows={},details={},detailSources={}},
        {bar="back",title=ru and "II · Запасная" or "II · Backup",rows={},details={},detailSources={}},
    }}
    local function formatted(v,suffix,sign,divisor)
        v=v or {front=0,back=0};divisor=divisor or 1
        if v.front~=v.back then view.differentBars=true end
        return pair(v.front/divisor,v.back/divisor,ru,suffix,sign)
    end
    local armorIcons={"eso-kana-addons/KanaWardrobe/assets/hood.dds",
        "EsoUI/Art/Inventory/inventory_tabIcon_armorMedium_up.dds",
        "EsoUI/Art/Inventory/inventory_tabIcon_armorHeavy_up.dds"}
    local function contributes(v)return v and (v.front~=0 or v.back~=0)end
    for i,kind in ipairs({ARMORTYPE_LIGHT or 1,ARMORTYPE_MEDIUM or 2,ARMORTYPE_HEAVY or 3})do
        local count=(summary.armor or {})[kind] or 0
        if count~=0 then
            view.metrics[#view.metrics+1]={icon=armorIcons[i],value=tostring(count)}
        end
    end
    if contributes(e.armor)then
        view.metrics[#view.metrics+1]={icon="EsoUI/Art/Inventory/inventory_tabIcon_armor_up.dds",
            value=formatted(e.armor,nil,""),tooltip=Effects.Breakdown(e,"armor",e.armor,language,nil,nil,"",1,ru and "Броня" or "Armor")}
    end
    for _,resource in ipairs({{"health","ED817B"},{"stamina","8DD590"},{"magicka","82B6FA"}})do
        local key,color=resource[1],resource[2]
        local stat,recovery=e.stats[key],e.stats[key.."Recovery"]
        if contributes(stat) or contributes(recovery) then
            view.metrics[#view.metrics+1]={key=key,icon="/esoui/art/characterwindow/Gamepad/gp_characterSheet_"..key.."Icon.dds",
                value=contributes(stat) and formatted(stat) or nil,
                recovery=contributes(recovery) and formatted(recovery,"/s",nil,2) or nil,
                tooltip=contributes(stat) and Effects.Breakdown(e,key,stat,language,nil,nil,nil,1,definitions[key][ru and 1 or 2]),
                recoveryTooltip=contributes(recovery) and Effects.Breakdown(e,key.."Recovery",recovery,language,nil,"/s",nil,2,definitions[key.."Recovery"][ru and 1 or 2]),
                color=color}
        end
    end
    for _,set in ipairs(summary.sets)do
        local function completeness(count)
            local color=count>=set.max and "8DD590" or "E6C65B"
            return "|c"..color..count.."/"..set.max.."|r"
        end
        local n=completeness(set.front)
        if set.front~=set.back then
            view.differentBars=true;n="["..n.." | "..completeness(set.back).."]"
        end
        view.sets[#view.sets+1]={name=set.setName,value=n,tooltip={kind="item",link=set.representativeLink}}
    end
    local keys={};for key in pairs(stats)do if definitions[key] and definitions[key][3]>6 then keys[#keys+1]=key end end
    table.sort(keys,function(a,b)return definitions[a][3]<definitions[b][3]end)
    for _,key in ipairs(keys)do
        local d,v=definitions[key],stats[key]
        local exclusive=(v.front~=0 and v.back==0) and 1 or ((v.back~=0 and v.front==0) and 2 or nil)
        local rows=exclusive and view.barGroups[exclusive].rows or view.rows
        local value
        if exclusive then
            local n=exclusive==1 and v.front or v.back
            value=formatted({front=n,back=n},d[4],d[5]==-1 and "−" or "+")
            view.differentBars=true
        else value=formatted(v,d[4],d[5]==-1 and "−" or "+")end
        rows[#rows+1]={name=d[ru and 1 or 2],value=value,category=d.category,
            tooltip=Effects.Breakdown(e,key,v,language,exclusive and (exclusive==1 and "front" or "back"),d[4],d[5]==-1 and "−" or "+",1,d[ru and 1 or 2])}
    end
    local specials={{},{},{}}
    for _,entry in ipairs(e.details)do
        local exclusive=entry.front~=entry.back and (entry.front and 1 or 2) or nil
        if exclusive then view.differentBars=true end
        -- Native paragraph breaks identify a compound effect; visual wrapping
        -- of a long single paragraph must not split or reclassify it.
        if entry.description:find("\n[ \t]*[^\n \t]")then
            local target=specials[exclusive and exclusive+1 or 1]
            local title=clean(entry.source or "")
            if title=="" then title=ru and "Особый эффект" or "Special effect" end
            if exclusive then title=title.." · "..view.barGroups[exclusive].title end
            target[#target+1]={description=entry.description,
                bar=exclusive and view.barGroups[exclusive].bar or nil,
                tooltip={kind="item",sources=entry.sources,bar=exclusive and view.barGroups[exclusive].bar or nil},
                title=title}
        else
            local target=exclusive and view.barGroups[exclusive].details or view.details
            target[#target+1]=entry.description
            local origins=exclusive and view.barGroups[exclusive].detailSources or view.detailSources
            origins[#target]={kind="item",sources=entry.sources,bar=exclusive and view.barGroups[exclusive].bar or nil}
        end
    end
    for _,group in ipairs(specials)do
        for _,entry in ipairs(group)do view.specials[#view.specials+1]=entry end
    end
    return view
end
