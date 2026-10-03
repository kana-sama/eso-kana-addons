-- Run from eso-kana-addons: lua KanaLeadList/tests/test_leadlist.lua
-- Exercise the installed upstream filters, not a second implementation of them.
dofile((os.getenv('ESOUI_PATH') or '/tmp/esoui-live') .. '/esoui/libraries/utility/zo_tableutils.lua')
internalassert = assert
ZO_SortFilterList = { Subclass = function() return {} end }
EVENT_ADD_ON_LOADED = 1
EVENT_PLAYER_ACTIVATED = 2
EVENT_ZONE_CHANGED = 3
CT_LABEL, CT_TEXTURE = 1, 2
local events = {}
EVENT_MANAGER = {
    RegisterForEvent = function(_, name, event, callback) events[name .. event] = callback end,
    UnregisterForEvent = function() end,
}
SLASH_COMMANDS = {}
ZO_CreateStringId = function() end
GetCVar = function() return 'ru' end
zo_strlower = string.lower
ZO_CachedStrFormat = function(_, text) return text end
GetCurrentMapZoneIndex = function() return 1 end
GetZoneId = function() return 1 end
GetParentZoneId = function(id) return id end
GetUnitZoneIndex = function() return 1 end
GetZoneNameById = function() return 'Даашан' end
ZO_ScrollList_GetDataList = function(list) return list end
ZO_ScrollList_CreateDataEntry = function(_, data) return {data = data} end
local saved = {}
if arg[1] == 'restore' then saved.firstDig, saved.hideSimple = true, true end
local columns = {'Lead','Zone','Location','Lore','Dug','Set','Expiration'}
if arg[1] == 'restore' then saved.hiddenColumns = {Zone=true, Lore=true} end
if arg[1] == 'allhidden' then
    saved.hiddenColumns = {}
    for _, key in ipairs(columns) do saved.hiddenColumns[key] = true end
end
local function uiControl(width)
    local control = {width=width, handlers={}, children={}}
    function control:GetWidth() return self.width end
    function control:GetFont() return 'TestFont' end
    function control:SetWidth(value) self.width=value end
    function control:SetHidden(value)
        self.hidden=value
        -- ESO ShowMenu installs OnEffectivelyHidden=ClearMenu on its owner.
        if value and ZO_Menu and ZO_Menu.owner == self then ClearMenu() end
    end
    function control:ClearAnchors() self.anchor=nil end
    function control:SetAnchor(...) self.anchor={...} end
    function control:GetNamedChild(key)
        if not self.children[key] then self.children[key]=uiControl(0) end
        return self.children[key]
    end
    function control:GetHandler(event) return self.handlers[event] end
    function control:SetHandler(event, fn) self.handlers[event]=fn end
    function control:SetMouseEnabled(value) self.mouseEnabled=value end
    return control
end
local widths = {300,170,220,72,72,220,110}
ILLMainWindowHeaders = uiControl(0)
ILLMainWindowList = uiControl(1200)
ILLMainWindowList.children.Contents = uiControl(1200)
zo_strupper = string.upper
local headerLeftClicks = 0
for i,key in ipairs(columns) do
    local control=uiControl(widths[i])
    control:SetHandler('OnMouseUp', function() headerLeftClicks=headerLeftClicks+1 end)
    ILLMainWindowHeaders.children[key]=control
end
MOUSE_BUTTON_INDEX_RIGHT, MENU_ADD_OPTION_CHECKBOX = 2, 2
ZO_Menu = {items={}}
ClearMenu = function() ZO_Menu.items={}; ZO_Menu.owner=nil end
AddMenuItem = function(label, callback, _, _, _, _, _, _, _, _, _, enabled)
    table.insert(ZO_Menu.items,{label=label,callback=callback,item={enabled=enabled},checkbox={}})
    return #ZO_Menu.items
end
UpdateMenuItemState = function(i,state)
    local entry=ZO_Menu.items[i]
    if entry and entry.checkbox then entry.checkbox.checked=state end
end
ZO_CheckButton_SetEnableState = function(checkbox,enabled) checkbox.enabled=enabled end
ShowMenu = function(owner) ZO_Menu.owner=owner end
ZO_SavedVars = { NewAccountWide = function() return saved end }
ILeadList = {}
dofile('LeadList/locale/ui_ru.lua')
ILL_DROPDOWN_MAJOR_CANFIND, ILL_DROPDOWN_MAJOR_CANSCRY = 1, 2
ILL_DROPDOWN_MAJOR_MISSINGCODEX, ILL_DROPDOWN_MAJOR_NEVERDUGOUT = 3, 4
ILL_DROPDOWN_MAJOR_ACTIONABLE, ILL_DROPDOWN_MAJOR_ALL = 5, 6
ILL_DROPDOWN_MAJOR_GROUPDUNGEONS, ILL_DROPDOWN_MAJOR_LATESTDLC = 7, 8
ILL_DROPDOWN_ZONE_ALL, ILL_DROPDOWN_ZONE_CURRENT = 1, 2
ILL_DROPDOWN_SETTYPE_ALL, ILL_DROPDOWN_SETTYPE_NOOBVIOUS = 1, 2
ILL_DROPDOWN_SETTYPE_MULTIPART, ILL_DROPDOWN_SETTYPE_MYTHIC = 3, 4
dofile('LeadList/leadlist.lua')
local ILL = ILeadList
ILLUnitList.SetupUnitRow = function(_, control, data) control.data = data end
-- Tooltip engine and the already-tested upstream hover body are external here.
local leadEnters, leadExits = 0, 0
ILL.RowMouseEnter = function() leadEnters = leadEnters + 1 end
ILL.RowMouseExit = function() leadExits = leadExits + 1 end
local hideWindow
ILLMainWindow = {GetHandler = function() end, SetHandler = function(_, _, fn) hideWindow = fn end}
TOPLEFT, TOPRIGHT = 1, 2
GuiRoot = {}
InformationTooltip = {GetLeft = function() return 600 end}
local rewardTooltip = {
    GetWidth = function() return 416 end,
    SetReward = function(self, id, quantity, flags) self.reward = {id, quantity, flags} end,
    SetHidden = function(self, hidden) self.hidden = hidden end,
}
WINDOW_MANAGER = {CreateControlFromVirtual = function(_, name)
    if name == 'KanaLeadListRewardTooltip' then return rewardTooltip end
    return {}
end}
WINDOW_MANAGER.CreateControl = function(_, _, _, kind)
    if kind == CT_TEXTURE then
        local texture=uiControl(0)
        texture.SetAnchorFill=function() end
        texture.SetColor=function() end
        texture.SetDrawLayer=function() end
        return texture
    end
    return {SetHidden=function() end, SetFont=function() end, GetStringWidth=function(_, text) return #text*4 end}
end
InitializeTooltip = function(tooltip, owner, point, x, y, relativePoint)
    tooltip.hidden, tooltip.anchor = false, {owner, point, x, y, relativePoint}
end
ClearTooltip = function(tooltip) tooltip.hidden, tooltip.reward = true, nil end
ClearTooltipImmediately = ClearTooltip
ILL.TREASURE, ILL.FURNISHING, ILL.MOTIF_CHAPTER = 'Treasure', 'Furniture', 'Motif'
ILL.ZONEID_ALLZONES = 10000
ILL.savedVars = {DropdownChoice = {Major = ILL.DropdownData.ChoicesMajor[6], Zone = ILL.DropdownData.ChoicesZone[1], SetType = ILL.DropdownData.ChoicesSetType[1]}}
ILL.setsminfound = {}
local list = setmetatable({list = {}, masterList = {}, currentSortKey = 'Zone', currentSortOrder = ZO_SORT_ORDER_UP}, {__index = ILLUnitList})
list.sortHeaderGroup = {SelectHeaderByKey = function(_, key) list.currentSortKey=key end}
list.sortFunction = function(a,b) return ZO_TableOrderingFunction(a.data,b.data,list.currentSortKey,ILLUnitList.SORT_KEYS,list.currentSortOrder) end
function list:RefreshData() self:FilterScrollList(); self:SortScrollList() end
ILL.UnitList = list
local callbacks = {}
for _, name in ipairs({'Major','SetType'}) do
    local combo = {
        CreateItemEntry = function(_, label, callback) return {name = label, callback = callback} end,
        AddItem = function(_, entry) callbacks[entry.name] = entry.callback end,
        SetSelectedItem = function() end,
    }
    _G['ILL_Dropdown' .. name] = {comboBox = combo}
end
local extension = io.open('KanaLeadList/KanaLeadList.lua')
local initialMajor, initialSetType
if extension then
    extension:close()
    dofile('KanaLeadList/KanaLeadList.lua')
    if arg[1] == 'deferred' then ILL.UnitList = nil end
    if events.KanaLeadList1 then events.KanaLeadList1(1, 'KanaLeadList') end
    if arg[1] == 'deferred' then
        ILL.UnitList = list
        assert(events.KanaLeadList2, 'initialization was not deferred')
        events.KanaLeadList2()
    end
    initialMajor, initialSetType = ILL.savedVars.DropdownChoice.Major, ILL.savedVars.DropdownChoice.SetType
end
local passed, failed = 0, 0
local function test(name, fn)
    local ok, err = pcall(fn)
    if ok then passed = passed + 1; print('PASS ' .. name)
    else failed = failed + 1; print('FAIL ' .. name .. ': ' .. err) end
end
local function row(id, zone, lead, have, dug)
    return {Aid=id, Zone=zone, ZoneId=1, Lead=lead, HaveLead=have, Dug=dug, Set='Other', SetId=0, Diff=3, Repeatable=true, Lore=0}
end
test('custom entries are available and saved selections survive initialization', function()
    assert(callbacks['Можно выкопать впервые'], 'missing major menu entry')
    assert(callbacks['Скрыть обычные и простую мебель'], 'missing type menu entry')
    if arg[1] == 'restore' then
        assert(initialMajor == 'Можно выкопать впервые' and initialSetType == 'Скрыть обычные и простую мебель', 'lost saved selection')
    else
        assert(initialMajor == ILL.DropdownData.ChoicesMajor[6] and initialSetType == ILL.DropdownData.ChoicesSetType[1], 'changed existing selection')
    end
    ILL.savedVars.DropdownChoice.Major = ILL.DropdownData.ChoicesMajor[6]
    ILL.savedVars.DropdownChoice.SetType = ILL.DropdownData.ChoicesSetType[1]
end)
test('Russian locale keeps equal zones together in both directions', function()
    list.currentSortKey = 'Zone'
    local old = os.setlocale(nil, 'collate')
    assert(os.setlocale('ru_RU.UTF-8', 'collate'), 'Russian test locale unavailable')
    local ok, err = pcall(function()
        for _, order in ipairs({ZO_SORT_ORDER_UP, ZO_SORT_ORDER_DOWN}) do
            list.currentSortOrder = order
            list.list = {{data=row(1,'Даашан','A')}, {data=row(2,'Рифт','B')}, {data=row(3,'Даашан','C')}}
            list:SortScrollList()
            local ids = {}
            for i, entry in ipairs(list.list) do ids[i] = entry.data.Aid end
            assert(table.concat(ids, ',') == (order and '1,3,2' or '2,3,1'), table.concat(ids, ','))
        end
    end)
    os.setlocale(old, 'collate')
    assert(ok, err)
end)
test('combined filter requires a lead AND zero recoveries', function()
    list.masterList = {row(1,'Даашан','A',true,0),row(2,'Даашан','B',true,1),row(3,'Даашан','C',false,0)}
    ILL.savedVars.DropdownChoice.Major = 'Можно выкопать впервые'
    list:FilterScrollList()
    assert(#list.list == 1 and list.list[1].data.Aid == 1, 'wrong intersection')
    assert(ILL.savedVars.DropdownChoice.Major == 'Можно выкопать впервые', 'selection overwritten')
end)
test('original filters keep their separate meanings', function()
    ILL.savedVars.DropdownChoice.Major = ILL.DropdownData.ChoicesMajor[2]
    list:FilterScrollList()
    assert(#list.list == 2 and list.list[2].data.Aid == 2)
    ILL.savedVars.DropdownChoice.Major = ILL.DropdownData.ChoicesMajor[4]
    list:FilterScrollList()
    assert(#list.list == 2 and list.list[2].data.Aid == 3)
end)
-- Synthetic reward IDs model API branches, not an invented lead database.
REWARD_ENTRY_TYPE_ITEM, REWARD_ENTRY_TYPE_COLLECTIBLE, REWARD_ENTRY_TYPE_REWARD_LIST = 1, 2, 3
ITEMTYPE_FURNISHING = 10
SPECIALIZED_ITEMTYPE_FURNISHING_CRAFTING_STATION = 11
SPECIALIZED_ITEMTYPE_FURNISHING_ATTUNABLE_STATION = 12
SPECIALIZED_ITEMTYPE_FURNISHING_TARGET_DUMMY = 13
COLLECTIBLE_CATEGORY_TYPE_FURNITURE, COLLECTIBLE_CATEGORY_TYPE_HOUSE_BANK = 20, 21
LINK_STYLE_DEFAULT = 0
GetAntiquityRewardId = function(id) return id end
GetAntiquitySetRewardId = function(id) return id + 100 end
GetRewardType = function(id) return ({[104]=2,[105]=2,[106]=3,[107]=3,[108]=3,[109]=2})[id] or 1 end
GetItemRewardItemLink = function(id) return tostring(id) end
GetItemLinkItemType = function(link)
    if link == '4' then return 99, 0 end -- an individual fragment is NOT the final reward
    return ITEMTYPE_FURNISHING, link == '7' and SPECIALIZED_ITEMTYPE_FURNISHING_TARGET_DUMMY or 0
end
GetItemLinkFurnitureDataId = tonumber
GetFurnitureDataCategoryInfo = function(id)
    if id == 2 or id == 104 or id == 109 then return 25, 104 end -- Services / Crafting Stations
    if id == 8 then return nil, nil end -- unknown metadata must not hide a reward
    return 1, 2
end
GetCollectibleRewardCollectibleId = function(id) return id end
GetCollectibleCategoryType = function(id) return id == 105 and COLLECTIBLE_CATEGORY_TYPE_HOUSE_BANK or COLLECTIBLE_CATEGORY_TYPE_FURNITURE end
GetCollectibleFurnitureDataId = function(id) return id end
GetRewardListIdFromReward = function(id) return id end
GetNumRewardListEntries = function() return 2 end
GetRewardListEntryInfo = function(id,i)
    if id == 106 then return i == 1 and 1 or 2 end
    if id == 108 then return i == 1 and 1 or 108 end -- cyclic/unknown => retain
    return i == 1 and 1 or 3
end
test('hide simple furniture, retain services, classify multipart final rewards', function()
    local rows = {}
    for id=1,11 do rows[id] = row(id,'Даашан',tostring(id),true,0) end
    rows[4].SetId, rows[5].SetId, rows[6].SetId = 4, 5, 6
    rows[9].SetId, rows[10].SetId, rows[11].SetId = 7, 8, 9
    rows[2].Set, rows[2].Diff = ILL.FURNISHING, 1 -- even low-quality services remain
    rows[1].Set = 'a gold decorative reward'
    ILL.setsminfound = {[4]=0,[5]=0,[6]=0,[7]=0,[8]=0,[9]=0}
    list.masterList = rows
    ILL.savedVars.DropdownChoice.Major = ILL.DropdownData.ChoicesMajor[6]
    ILL.savedVars.DropdownChoice.SetType = 'Скрыть обычные и простую мебель'
    list:FilterScrollList()
    local ids = {}
    for _, entry in ipairs(list.list) do ids[#ids+1] = entry.data.Aid end
    assert(table.concat(ids, ',') == '2,4,5,6,7,8,10,11', table.concat(ids, ','))
end)
test('new type filter preserves ordinary-filter rules and combines with first dig', function()
    local originalType = GetItemLinkItemType
    GetItemLinkItemType = function() return 99, 0 end
    local a, b, c = row(20,'Даашан','A',true,0), row(21,'Даашан','B',true,0), row(22,'Даашан','C',true,1)
    a.Set, a.Diff = ILL.TREASURE, 1
    b.Set, b.Diff = ILL.TREASURE, 2
    c.Set = ILL.MOTIF_CHAPTER
    list.masterList = {a,b,c}
    ILL.savedVars.DropdownChoice.Major = 'Можно выкопать впервые'
    list:FilterScrollList()
    assert(#list.list == 1 and list.list[1].data.Aid == 21, 'scry mode/intersection changed')
    ILL.savedVars.DropdownChoice.Major = ILL.DropdownData.ChoicesMajor[6]
    list:FilterScrollList()
    assert(#list.list == 0, 'normal mode must hide ordinary treasure and motifs')
    GetItemLinkItemType = originalType
end)
test('reward tooltip shows final set reward alongside the original lead', function()
    local control = {data=row(4,'Даашан','fragment',true,0)}
    control.data.SetId = 9
    local previous = leadEnters
    ILL.RowMouseEnter(control)
    assert(leadEnters == previous + 1, 'lost upstream lead tooltip')
    assert(rewardTooltip.reward and rewardTooltip.reward[1] == 109, 'showed fragment instead of final reward')
    assert(rewardTooltip.reward[2] == 1 and rewardTooltip.reward[3] == 0)
    assert(rewardTooltip.anchor[1] == InformationTooltip, 'not anchored beside lead tooltip')
    ILL.RowMouseExit(control)
    assert(rewardTooltip.hidden and leadExits == 1, 'tooltip did not clear on exit')
    control.data.SetId = 0
    ILL.RowMouseEnter(control)
    assert(rewardTooltip.reward[1] == 4, 'individual reward missing')
    assert(hideWindow, 'missing close cleanup')
    hideWindow()
    assert(rewardTooltip.hidden, 'tooltip remains after closing window')
end)
test('missing reward clears previous tooltip and keeps lead hover working', function()
    local old = GetAntiquityRewardId
    GetAntiquityRewardId = function() return 0 end
    ILL.RowMouseEnter({data=row(1,'Даашан','unknown',true,0)})
    assert(rewardTooltip.hidden and not rewardTooltip.reward, 'stale reward retained')
    GetAntiquityRewardId = old
end)
test('original UI callbacks persist custom choices and switching back clears them', function()
    PlaySound = function() end
    SOUNDS = {POSITIVE_CLICK = 1}
    list.masterList = {}
    callbacks['Можно выкопать впервые']()
    callbacks['Скрыть обычные и простую мебель']()
    assert(saved.firstDig and saved.hideSimple, 'custom choices were not saved')
    ILL.savedVars.DropdownChoice.Major = ILL.DropdownData.ChoicesMajor[6]
    ILL.savedVars.DropdownChoice.SetType = ILL.DropdownData.ChoicesSetType[1]
    list:RefreshData()
    assert(not saved.firstDig and not saved.hideSimple, 'old custom choices would return on reload')
end)
test('left double click scries current pooled row and closes LeadList', function()
    MOUSE_BUTTON_INDEX_LEFT, ANTIQUITY_SCRYING_RESULT_SUCCESS = 1, 0
    local checked, started, hidden, other = nil, nil, false, 0
    CanScryForAntiquity = function(id) checked = id; return 0 end
    ScryForAntiquity = function(id) assert(hidden, 'list still open'); started = id end
    SCENE_MANAGER = {HideTopLevel = function(_, window)
        assert(window == ILLMainWindow); hidden = true; hideWindow()
    end}
    local handler = function() other = other + 1 end
    local control = uiControl(0)
    control.GetHandler = function() return handler end
    control.SetHandler = function(_, _, fn) handler = fn end
    list:SetupUnitRow(control, row(41,'Даашан','A',true,0))
    list:SetupUnitRow(control, row(42,'Даашан','B',false,1))
    handler(control, 2)
    assert(not started and other == 1, 'right click changed')
    handler(control, 1)
    assert(checked == 42 and started == 42, 'missing action or stale pooled row ID')
end)
test('scry refusal shows the game reason without closing the list', function()
    local started, hidden, alert = false, false, nil
    CanScryForAntiquity = function() return 7 end
    GetString = function(prefix, result)
        assert(prefix == 'SI_ANTIQUITYSCRYINGRESULT' and result == 7)
        return 'Неверная зона'
    end
    ZO_Alert = function(_, _, message) alert = message end
    ScryForAntiquity = function() started = true end
    SCENE_MANAGER = {HideTopLevel = function() hidden = true end}
    local handler
    local control = uiControl(0)
    control.GetHandler = function() return handler end
    control.SetHandler = function(_, _, fn) handler = fn end
    list:SetupUnitRow(control, row(43,'Даашан','C',true,0))
    assert(handler, 'double click not registered')
    handler(control, 1)
    assert(alert == 'Неверная зона' and not started and not hidden, 'refusal not respected')
    control.data = nil
    handler(control, 1)
end)
test('header menu collapses columns, preserves left click and keeps one visible', function()
    local headers = ILLMainWindowHeaders
    local lead = headers:GetNamedChild('Lead')
    assert(headers:GetHandler('OnMouseUp'), 'header context menu missing')
    if arg[1] == 'restore' then
        assert(headers:GetNamedChild('Zone').hidden and headers:GetNamedChild('Lore').hidden, 'lost column settings')
    elseif arg[1] == 'allhidden' then
        assert(not lead.hidden, 'all-hidden saved state not repaired')
    end
    local before = headerLeftClicks
    lead:GetHandler('OnMouseUp')(lead,1,true)
    assert(headerLeftClicks == before+1, 'left-click sorting replaced')
    lead:GetHandler('OnMouseUp')(lead,2,true)
    assert(headerLeftClicks == before+1 and #ZO_Menu.items==7, 'right click sorted or menu missing')
    -- Show every column before exercising a fresh layout.
    for i,key in ipairs(columns) do if saved.hiddenColumns[key] then ZO_Menu.items[i].callback() end end
    local control=uiControl(0)
    list:SetupUnitRow(control,row(44,'Даашан','D',true,0))
    list.currentSortKey='Zone'
    ZO_Menu.items[2].callback()
    assert(headers:GetNamedChild('Zone').hidden and control:GetNamedChild('Zone').hidden, 'header/row mismatch')
    local leadWidth=headers:GetNamedChild('Lead'):GetWidth()
    assert(headers:GetNamedChild('Location').anchor[4]==leadWidth and control:GetNamedChild('Location').anchor[4]==leadWidth, 'hidden column left a gap')
    assert(list.currentSortKey=='Lead', 'sorting still uses hidden column')
    ZO_Menu.items[2].callback()
    assert(not control:GetNamedChild('Zone').hidden and control:GetNamedChild('Location').anchor[4]==headers:GetNamedChild('Lead'):GetWidth()+headers:GetNamedChild('Zone'):GetWidth(), 'show failed')
    for i=2,7 do ZO_Menu.items[i].callback() end
    ZO_Menu.items[1].callback() -- stale/forced callback must still respect invariant
    assert(not saved.hiddenColumns.Lead and not lead.hidden, 'last column was hidden')
    assert(ZO_Menu.items[1].checkbox.checked and not ZO_Menu.items[1].checkbox.enabled, 'last checkbox not protected')
    local recycled=uiControl(0)
    list:SetupUnitRow(recycled,row(45,'Даашан','E',true,0))
    assert(recycled:GetNamedChild('Zone').hidden and not recycled:GetNamedChild('Lead').hidden, 'new row ignored visibility')
end)
test('hiding the right-clicked first header keeps the column menu alive', function()
    local headers=ILLMainWindowHeaders
    headers:GetHandler('OnMouseUp')(headers,2,true)
    for i,key in ipairs(columns) do if saved.hiddenColumns[key] then ZO_Menu.items[i].callback() end end
    local lead=headers:GetNamedChild('Lead')
    lead:GetHandler('OnMouseUp')(lead,2,true)
    ZO_Menu.items[1].callback()
    assert(lead.hidden and saved.hiddenColumns.Lead, 'first column not hidden')
    assert(#ZO_Menu.items==7 and not ZO_Menu.items[1].checkbox.checked, 'menu closed with its header')
    ZO_Menu.items[1].callback()
    assert(not lead.hidden, 'cannot restore first column in same menu')
end)
test('free width goes to clipped text and recalculates with filtered rows', function()
    local headers=ILLMainWindowHeaders
    headers:GetHandler('OnMouseUp')(headers,2,true)
    for i,key in ipairs(columns) do
        local wantHidden=key~='Zone' and key~='Set' and key~='Expiration'
        if (saved.hiddenColumns[key]==true)~=wantHidden then ZO_Menu.items[i].callback() end
    end
    ILL.savedVars.DropdownChoice.Major=ILL.DropdownData.ChoicesMajor[6]
    ILL.savedVars.DropdownChoice.SetType=ILL.DropdownData.ChoicesSetType[1]
    local data=row(60,'Short','hidden lead',true,0)
    data.Set=string.rep('X',180) -- measured 720 px: this column needs most space
    data.Expiration=86400
    list.masterList={data}
    list:FilterScrollList()
    local zone,set,expiry=headers:GetNamedChild('Zone'),headers:GetNamedChild('Set'),headers:GetNamedChild('Expiration')
    assert(set:GetWidth()>=732, 'long reward still clipped despite spare width')
    assert(math.abs(zone:GetWidth()+set:GetWidth()+expiry:GetWidth()-1200)<0.01, 'table does not fill available width')
    local previous=set:GetWidth()
    data.Set='Short'; data.Zone=string.rep('Z',180)
    list:FilterScrollList()
    assert(zone:GetWidth()>=732 and set:GetWidth()<previous, 'filter/content change did not redistribute width')
end)
test('current-zone highlighting follows the player and resets recycled rows', function()
    local zone=57
    GetZoneId=function() return zone end
    local control=uiControl(0)
    local data=row(70,'Даашан','A',true,0)
    data.ZoneId=57
    list:SetupUnitRow(control,data)
    assert(control.kanaCurrentZoneHighlight and not control.kanaCurrentZoneHighlight.hidden, 'current zone not highlighted')
    zone=19
    assert(events.KanaLeadListCurrentZone3, 'zone change not registered')
    events.KanaLeadListCurrentZone3()
    assert(control.kanaCurrentZoneHighlight.hidden, 'highlight remained after travel')
    data.ZoneId=19
    list:SetupUnitRow(control,data)
    assert(not control.kanaCurrentZoneHighlight.hidden, 'recycled row not updated')
    data.ZoneId=ILL.ZONEID_ALLZONES+50 -- unknown special zone must not match
    list:SetupUnitRow(control,data)
    assert(control.kanaCurrentZoneHighlight.hidden, 'unknown zone highlighted')
end)
test('row recoloring tolerates missing children and preserves the zone background', function()
    -- Execute the actual upstream method unless the addon overrides it.
    local file=assert(io.open((os.getenv('ESOUI_PATH') or '/tmp/esoui-live')..'/esoui/libraries/zo_sortfilterlist/zo_sortfilterlist.lua'))
    local source=file:read('*a'):gsub('\r\n','\n'); file:close()
    local body=assert(source:match('(function ZO_SortFilterList:ColorRow.-)\nfunction ZO_SortFilterList:SetupRow'))
    assert(load(body))()
    local rowControl=uiControl(0)
    local data=row(80,'Zone','Reward',true,0)
    list:SetupUnitRow(rowControl,data)
    local texture=rowControl.kanaCurrentZoneHighlight
    local recolored=false
    texture.GetType=function() return CT_TEXTURE end
    texture.GetControlAlpha=function() return 0.22 end
    texture.SetColor=function() recolored=true end
    local labelColor
    local label={GetType=function() return CT_LABEL end, GetControlAlpha=function() return 0.7 end,
        SetColor=function(_,r,g,b,a) labelColor={r,g,b,a} end}
    rowControl.GetNumChildren=function() return 3 end
    rowControl.GetChild=function(_,i) return ({[1]=label,[3]=texture})[i] end
    local color={UnpackRGB=function() return 0.2,0.3,0.4 end}
    list.GetRowColors=function() return color,color end
    list.automaticallyColorRows=true
    local colorRow=ILLUnitList.ColorRow or ZO_SortFilterList.ColorRow
    colorRow(list,rowControl,data,false)
    assert(labelColor and labelColor[1]==0.2 and labelColor[4]==0.7, 'label coloring changed')
    assert(not recolored, 'current zone background recolored')
end)
print(string.format('%d passed, %d failed', passed, failed))
if failed > 0 then os.exit(1) end
