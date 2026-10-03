local A, M = KanaInfoBar, KanaInfoBar.Model
local lastDPS, lastGroup, lastTime, observedData
local count, value, used, capacity = 0,0,0,0
local treasures={}

local function Capture(data)
    if data and data.DPSOut~=nil and ((data.DPSOut or 0)>0 or (data.dpstime or 0)>0 or (data.hpstime or 0)>0) then
        lastDPS, lastGroup, lastTime = data.DPSOut, data.groupDPSOut or 0, data.dpstime or 0
    end
    observedData = data
end

local function ShortNumber(n)
    if n>=10000 then return string.format('%.0fk',n/1000) end
    if n>=1000 then return string.format('%.1fk',n/1000) end
    return tostring(math.floor(n+.5))
end

function A:RefreshInventory()
    local items={}
    for slot=0,GetBagSize(BAG_BACKPACK)-1 do
        local stack = GetSlotStackSize(BAG_BACKPACK,slot)
        if stack>0 and IsItemStolen(BAG_BACKPACK,slot) and GetItemType(BAG_BACKPACK,slot)==ITEMTYPE_TREASURE then
            items[#items+1]={stolen=true,kind=ITEMTYPE_TREASURE,count=stack,
                price=GetItemSellValueWithBonuses(BAG_BACKPACK,slot)}
        end
    end
    treasures=items
    count,value=M.TotalTreasure(items,ITEMTYPE_TREASURE)
    used,capacity=GetNumBagUsedSlots(BAG_BACKPACK),GetBagUseableSize(BAG_BACKPACK)
end

function A:InitializeProviders()
    self:RefreshInventory()
    local function queue()
        EVENT_MANAGER:UnregisterForUpdate('KanaInfoBarBag')
        EVENT_MANAGER:RegisterForUpdate('KanaInfoBarBag',100,function()
            EVENT_MANAGER:UnregisterForUpdate('KanaInfoBarBag')
            self:RefreshInventory()
        end)
    end
    EVENT_MANAGER:RegisterForEvent('KanaInfoBarBag',EVENT_INVENTORY_SINGLE_SLOT_UPDATE,queue)
    EVENT_MANAGER:AddFilterForEvent('KanaInfoBarBag',EVENT_INVENTORY_SINGLE_SLOT_UPDATE,
        REGISTER_FILTER_BAG_ID,BAG_BACKPACK)
    for _, event in ipairs({EVENT_INVENTORY_FULL_UPDATE,EVENT_INVENTORY_BAG_CAPACITY_CHANGED,EVENT_PLAYER_ACTIVATED}) do
        EVENT_MANAGER:RegisterForEvent('KanaInfoBarBag',event,queue)
    end
    EVENT_MANAGER:RegisterForEvent('KanaInfoBarDPS',EVENT_PLAYER_COMBAT_STATE,function(_,inCombat)
        if inCombat then
            lastDPS,lastGroup,lastTime=nil,nil,nil
            -- CM may still expose the preceding fight until its next recap.
            observedData=CMX and CMX.currentdata
            self.waitingForRecap=true
        end
    end)
    if CombatMetrics_LiveReport and CombatMetrics_LiveReport.Update then
        ZO_PostHook(CombatMetrics_LiveReport,'Update',function(_,data)
            self.waitingForRecap=false
            Capture(data)
        end)
    end
end

A:RegisterWidget({id='dps',name='Свой DPS',sample='999k',
    icon='eso-kana-addons/KanaInfoBar/textures/dps.dds',
    read=function()
        local data=CMX and CMX.currentdata
        if data and (not A.waitingForRecap or data~=observedData) then
            A.waitingForRecap=false
            Capture(data)
        end
        local available=CMX~=nil
        if not available then lastDPS,lastGroup,lastTime=nil,nil,nil end
        local grouped=IsUnitGrouped('player')
        local ratio=lastGroup and lastGroup>0 and math.floor(lastDPS/lastGroup*100+.5)
        local text=lastDPS and ShortNumber(lastDPS) or '—'
        if grouped then text=text..' / '..(ratio and ratio..'%' or '—') end
        local share=grouped and ('\nДоля группового DPS: '..(ratio and ratio..'%' or 'нет групповых данных')) or ''
        local detail=not available and 'Combat Metrics не загружен.' or not lastDPS and 'Нет данных текущего боя.' or
            string.format('%s\nСвой DPS: %.0f%s\nВремя урона: %.1f с',
                IsUnitInCombat('player') and 'Текущий бой' or 'Последний бой',lastDPS,
                share,lastTime)
        return {text=text,visible=true,detail=detail,clickable=available}
    end,
    action=function()
        if CombatMetrics_Report and not SCENE_MANAGER:IsShowing('CMX_REPORT_SCENE') then
            CombatMetrics_Report:Toggle()
        end
    end,clickHint='ЛКМ — открыть Combat Metrics',
})
A:RegisterWidget({id='messages',name='Непрочитанные сообщения',sample='999',
    icon='eso-kana-addons/KanaInfoBar/textures/messages.dds',
    read=function()
        local messenger=AetherChat and AetherChat.Messenger
        local n=messenger and messenger.GetTotalUnreadCount and messenger.GetTotalUnreadCount() or 0
        return {text=tostring(n),visible=n>0,color='gold',clickable=messenger~=nil,
            detail=messenger and ('Непрочитанных: '..n..'\nУчитываются настройки уведомлений AetherChat.') or 'AetherChat не загружен.'}
    end,
    action=function()
        local messenger=AetherChat and AetherChat.Messenger
        if messenger and messenger.Show then
            if messenger.RecordInteraction then messenger.RecordInteraction() end
            messenger.Show(false)
        end
    end,clickHint='ЛКМ — открыть AetherChat',
})
A:RegisterWidget({id='ping',name='Пинг',sample='999',icon='eso-kana-addons/KanaInfoBar/textures/ping.dds',tooltip=false,
    read=function()
        local n=GetLatency()
        return {text=tostring(n),visible=true,color=M.PingColor(n)}
    end,
})
A:RegisterWidget({id='fps',name='FPS',sample='999',icon='eso-kana-addons/KanaInfoBar/textures/fps.dds',tooltip=false,
    read=function()
        local n=math.floor(GetFramerate()+.5)
        return {text=tostring(n),visible=true}
    end,
})
A:RegisterWidget({id='inventory',name='Инвентарь',sample='999/999',
    icon='eso-kana-addons/KanaInfoBar/textures/inventory.dds',
    read=function()
        return {text=capacity>0 and used..'/'..capacity or '—',visible=true,
            color=M.BagColor(used,capacity),clickable=true,
            detail=string.format('Занято: %d\nВместимость: %d\nСвободно: %d',used,capacity,math.max(0,capacity-used))}
    end,
    action=function() A:OpenInventory(false) end,clickHint='ЛКМ — открыть инвентарь',
})
A:RegisterWidget({id='durability',name='Прочность снаряжения',sample='100%',
    icon='eso-kana-addons/KanaInfoBar/textures/durability.dds',
    read=function()
        local items={}
        for slot=0,GetBagSize(BAG_WORN)-1 do
            if DoesItemHaveDurability(BAG_WORN,slot) then
                items[#items+1]={condition=GetItemCondition(BAG_WORN,slot),
                    cost=GetItemRepairCost(BAG_WORN,slot)}
            end
        end
        local minimum,average,cost,pieces=M.GearStatus(items)
        if not minimum then
            return {text='—',visible=true,color='normal',detail='Нет надетых вещей с прочностью.'}
        end
        return {text=minimum..'%',visible=true,color=M.GearColor(minimum),
            detail=string.format('Минимальная прочность: %d%%\nСредняя прочность: %d%%\nПочинка надетых вещей: %d зол.\nВещей с прочностью: %d',
                minimum,average,cost,pieces)}
    end,
})
A:RegisterWidget({id='treasure',name='Краденые сокровища',sample='99999g',
    icon='eso-kana-addons/KanaInfoBar/textures/treasure.dds',
    read=function()
        local limit,usedSales=GetFenceSellTransactionInfo()
        local available=type(limit)=='number' and type(usedSales)=='number'
        local remaining=available and math.max(0,limit-usedSales) or 0
        local today,saleCount=M.BestTreasureSale(treasures,remaining,ITEMTYPE_TREASURE)
        local todayText=available and today..'g' or '—'
        local quotaDetail=available and string.format('Осталось продаж: %d из %d\nСамых дорогих сокровищ к продаже: %d',remaining,limit,saleCount)
            or 'Квота скупщика пока недоступна.'
        return {text=value..'g',visible=count>0,color='normal',clickable=true,
            detail=string.format('Всего сокровищ: %d\nОбщая стоимость: %d зол.\nМожно продать сегодня: %s\n%s\nТолько краденые сокровища, включая хлам.\nЦена учитывает бонусы продажи скупщику.',count,value,todayText,quotaDetail)}
    end,
    action=function() A:OpenInventory(true) end,clickHint='ЛКМ — открыть все краденые вещи в инвентаре',
})
