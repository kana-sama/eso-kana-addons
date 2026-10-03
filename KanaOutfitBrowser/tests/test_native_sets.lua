-- Integration boundaries are doubled; run the production insertion and handlers.
OUTFIT_SLOT_HEAD, OUTFIT_SLOT_CHEST, OUTFIT_SLOT_SHOULDERS = 1, 2, 3
OUTFIT_SLOT_HANDS, OUTFIT_SLOT_WAIST, OUTFIT_SLOT_LEGS, OUTFIT_SLOT_FEET = 4, 5, 6, 7
EVENT_MANAGER = {RegisterForEvent=function() end}
EVENT_ADD_ON_LOADED = 1
ZO_ToggleButton_SetState=function(control, state) control.state=state end
ZO_ScrollList_AddOperation=function(list, id, data) list.headers[#list.headers+1]=data end
zo_strlower = string.lower
SCENE_MANAGER = {IsShowing=function() return true end}
ZO_OUTFIT_MANAGER = {GetShowLocked=function() return true end}
ZO_CheckButton_SetEnableState = function(control, enabled) control.enabled=enabled end
ZO_CheckButton_SetCheckState = function(control, checked) control.checked=checked end
ZO_UpdateCollectibleEntryDataIconVisuals = function(entry, category) entry.visualCategory=category end
local function control()
    local c = {handlers={}}
    function c:SetAnchor(...) self.anchor={...} end
    function c:SetHidden(value) self.hidden=value end
    function c:IsHidden() return self.hidden == true end
    function c:SetText(value) self.text=value end
    function c:SetColor(...) self.color={...} end
    function c:SetNormalTexture(value) self.normal=value end
    function c:SetPressedTexture(value) self.pressed=value end
    function c:SetMouseOverTexture(value) self.over=value end
    function c:SetHandler(name, fn) self.handlers[name]=fn end
    function c:SetMinMax(a, b) self.min,self.max=a,b end
    function c:SetValue(value) self.value=value end
    return c
end
local data = {}
for i=1, 21 do
    local id=i
    data[id]={GetId=function() return id end, IsUnlocked=function() return id % 2 == 1 end,
        IsHiddenFromCollection=function() return id == 12 end}
end
ZO_COLLECTIBLE_DATA_MANAGER = {GetCollectibleDataById=function(_, id) return data[id] end}
dofile('KanaOutfitBrowser/NativeSetModel.lua')
dofile('KanaOutfitBrowser/NativeSets.lua')
local KOB=KanaOutfitBrowser
local variants = {
    {key='a:1',styleKey='a',name='Altmer',weight=1,slots={}},
    {key='a:3',styleKey='a',name='Altmer',weight=3,slots={}},
    {key='b:2',styleKey='b',name='Breton',weight=2,slots={}},
}
for n, variant in ipairs(variants) do
    for slot=1,7 do variant.slots[slot]={collectibleId=(n-1)*7+slot} end
end
variants[1].slots[3]=nil
KOB.Catalog={Build=function() return variants end, MigratePreferences=function() end}
local function fixture(prefs)
    local grid={entries={},breaks={},autoFillRows=true,refreshes=0}
    function grid:GetData() return self.layout or self.entries end
    function grid:FillRowWithEmptyCells() end
    grid.list={headers={}}
    grid.templateOperationIds={KanaOutfitSetHeader=10}
    grid.headerPrePadding,grid.headerPostPadding=15,0
    function grid:AddEntry(entry) self.entries[#self.entries+1]=entry end
    function grid:AddLineBreak(size) self.breaks[#self.breaks+1]=size end
    function grid:RefreshGridList() self.refreshes=self.refreshes+1 end
    local pool={}
    function pool:AcquireObject()
        return {SetDataSource=function(self, source) self.source=source end}
    end
    local panel={gridListPanelControl=control(),gridListPanelList=grid,entryDataObjectPool=pool,typeFilterControl=control(),
        typeFilterDropDown={GetNumItems=function() return 3 end},
        progressBar=control(),progressBarProgressLabel=control(),GetActorCategory=function() return 42 end}
    local book={contentSearchEditBox={GetText=function() return '' end}}
    local sets=KOB.NativeSets.New(book,panel,prefs or {})
    sets.showHidden=control()
    sets.showUnknown=control()
    panel.collectibleCategoryData=sets.category
    return sets,panel,grid
end
local function equal(a,b) assert(a==b,tostring(a)..' ~= '..tostring(b)) end
local count=0
local function test(name, fn) fn(); count=count+1; print('PASS native sets: '..name) end
local function order(sets)
    local result={}
    for _, family in ipairs(sets.model:GetSets()) do result[#result+1]=family.key end
    return table.concat(result,',')
end

test('seven cells per variant preserve real native sources and placeholders',function()
    local sets,panel,grid=fixture()
    sets:Inject()
    equal(#grid.entries,21)
    equal(#grid.breaks,3)
    equal(grid.entries[1].source,data[1])
    equal(grid.entries[1].visualCategory,42)
    equal(grid.entries[3].isEmptyCell,true)
    equal(grid.entries[12].isEmptyCell,true)
    equal(grid.entries[7].source,data[7])
    equal(grid.entries[8].source,data[8])
    equal(grid.entries[15].source,data[15])
    equal(grid.entries[1].gridHeaderName,grid.entries[14].gridHeaderName)
    assert(grid.entries[1].gridHeaderName~=grid.entries[15].gridHeaderName)
    equal(grid.entries[1].gridHeaderTemplate,'KanaOutfitSetHeader')
    equal(grid.autoFillRows,false)
    equal(panel.progressBar.max,19)
    equal(panel.progressBar.value,10)
end)

test('hide and favorite clicks refresh icons and text without reshuffling',function()
    local sets,_,grid=fixture()
    sets:Inject()
    local family=sets.model:GetSets()[2]
    local children={Title=control(),Hide=control(),Favorite=control(),ExpandedState=control()}
    local header={GetNamedChild=function(_,name) return children[name] end}
    sets:DecorateHeader(header,family)
    equal(children.Hide.normal,'EsoUI/Art/Miscellaneous/Keyboard/visible_up.dds')
    equal(children.Favorite.normal,'eso-kana-addons/KanaOutfitBrowser/Textures/star_outline.dds')
    children.Favorite.handlers.OnClicked()
    equal(grid.refreshes,1)
    equal(order(sets),'a,b')
    sets:DecorateHeader(header,family)
    equal(children.Favorite.normal,'eso-kana-addons/KanaOutfitBrowser/Textures/star_filled.dds')
    children.Hide.handlers.OnClicked()
    equal(grid.refreshes,2)
    equal(order(sets),'a,b')
    sets:DecorateHeader(header,family)
    equal(children.Hide.normal,'EsoUI/Art/Miscellaneous/Keyboard/hidden_up.dds')
    equal(children.Title.color[1],0.42)
    sets:LeaveSession()
    sets:BeginSession()
    equal(order(sets),'a')
end)

test('leaving session restores native autofill and hides custom control',function()
    local sets,panel,grid=fixture()
    sets:Inject()
    sets:LeaveSession()
    equal(grid.autoFillRows,true)
    equal(sets.model,nil)
    equal(sets.showHidden.hidden,true)
    equal(panel.typeFilterControl.hidden,false)
    sets:LeaveSession()
    equal(grid.autoFillRows,true)
    panel.typeFilterDropDown.GetNumItems=function() return 2 end
    sets:LeaveSession()
    equal(panel.typeFilterControl.hidden,true)
end)

test('false native autofill state survives exit',function()
    local sets,_,grid=fixture()
    grid.autoFillRows=false
    sets:Inject()
    sets:LeaveSession()
    equal(grid.autoFillRows,false)
end)
test('pool reuse in native categories does not retain custom headers',function()
    local sets,panel,grid=fixture()
    sets:Inject()
    local recycled=grid.entries[1]
    equal(recycled.gridHeaderTemplate,'KanaOutfitSetHeader')
    -- Native pool reset drops only the source; extra fields survive until our hook.
    recycled:SetDataSource(nil)
    panel.collectibleCategoryData={}
    sets:Inject()
    recycled:SetDataSource(data[2])
    equal(recycled.gridHeaderTemplate,nil)
    equal(recycled.gridHeaderName,nil)
    equal(grid.autoFillRows,true)
    equal(sets.model,nil)
end)
test('locked filter distinguishes unlearned parts from missing catalog slots',function()
    ZO_OUTFIT_MANAGER.GetShowLocked=function() return false end
    local sets,_,grid=fixture()
    sets:Inject()
    equal(grid.entries[1].source,data[1])
    equal(grid.entries[2].isEmptyCell,true)
    equal(grid.entries[2].iconFile,'EsoUI/Art/Miscellaneous/status_locked.dds')
    equal(grid.entries[2].source,nil)
    equal(grid.entries[3].isEmptyCell,true)
    equal(grid.entries[3].iconFile,nil)
    ZO_OUTFIT_MANAGER.GetShowLocked=function() return true end
    local all,_,allGrid=fixture()
    all:Inject()
    equal(allGrid.entries[2].source,data[2])
    equal(allGrid.entries[2].isEmptyCell,nil)
end)
test('unknown filter applies per variant not whole family and follows locked toggle',function()
    local original={}
    for i=1,7 do original[i]=data[i].IsUnlocked; data[i].IsUnlocked=function() return false end end
    local sets,panel,grid=fixture()
    sets:Inject()
    equal(#grid.entries,14) -- unknown light row removed; known heavy row in same family stays
    equal(grid.entries[1].source,data[8])
    equal(sets.showUnknown.enabled,true)
    sets.prefs.showUnknown=true
    grid.entries={}
    sets:Inject()
    equal(#grid.entries,21)
    ZO_OUTFIT_MANAGER.GetShowLocked=function() return false end
    grid.entries={}
    sets:Inject()
    equal(#grid.entries,14)
    equal(sets.showUnknown.enabled,false)
    equal(sets.prefs.showUnknown,true) -- disabled preference is preserved
    sets:LeaveSession()
    equal(sets.showUnknown.hidden,true)
    for i=1,7 do data[i].IsUnlocked=original[i] end
    ZO_OUTFIT_MANAGER.GetShowLocked=function() return true end
end)
test('scroll restores after commit and ignores other categories and restore events',function()
    local sets,panel,grid=fixture({scrollPosition=420})
    function grid:ScrollToAbsoluteValue(value, callback, instantly)
        equal(instantly,true)
        self.position=math.min(value,300)
        sets:SaveScrollPosition(0) -- native range/reset event must not erase saved position
    end
    function grid:GetScrollValue() return self.position end
    sets:Inject()
    equal(sets.pendingScroll,420)
    sets:SaveScrollPosition(0)
    equal(sets.prefs.scrollPosition,420)
    sets:RestoreScrollPosition()
    equal(grid.position,300)
    equal(sets.prefs.scrollPosition,300)
    sets:SaveScrollPosition(180)
    panel.collectibleCategoryData={}
    sets:SaveScrollPosition(0)
    equal(sets.prefs.scrollPosition,180)
    sets:LeaveSession()
    panel.collectibleCategoryData=sets.category
    sets:Inject()
    sets:RestoreScrollPosition()
    equal(grid.position,180)
end)
test('collapsed style retains one header and no item rows',function()
    local sets,_,grid=fixture({collapsed={a=true}})
    sets:Inject()
    equal(#grid.entries,7)
    equal(#grid.list.headers,1)
    equal(grid.list.headers[1].header.key,'a')
    equal(grid.entries[1].kobFamilyKey,'b')
end)

test('filter rebuild anchors to row identity and offset instead of old pixels',function()
    local sets,_,grid=fixture()
    function grid:ScrollToAbsoluteValue(value) self.position=value end
    function grid:GetScrollValue() return self.position or 0 end
    local function row(key,top) return {top=top,bottom=top+70,data={kobRowKey=key,kobFamilyKey='a'}} end
    sets:Inject()
    grid.layout={row('first',0),row('target',200),row('next',270)}
    sets:RestoreScrollPosition()
    sets:SaveScrollPosition(215)
    grid.layout={}
    sets:SaveScrollPosition(0) -- native clear must not erase the anchor
    sets:Inject()
    grid.layout={row('first',0),row('target',70),row('next',140)}
    sets:RestoreScrollPosition()
    equal(grid.position,85)
    sets:Inject()
    grid.layout={row('first',0),row('next',70)}
    sets:RestoreScrollPosition()
    equal(grid.position,70) -- removed target falls forward to surviving next row
end)
test('repeated empty searches discard the old row anchor before next rebuild',function()
    local sets,_,grid=fixture()
    function grid:ScrollToAbsoluteValue(value) self.position=#self:GetData()==0 and 0 or value end
    function grid:GetScrollValue() return self.position or 0 end
    local function row(key,top) return {top=top,bottom=top+70,data={kobRowKey=key,kobFamilyKey='a'}} end
    sets:Inject()
    grid.layout={row('first',0),row('middle',70),row('last',140)}
    sets:RestoreScrollPosition()
    sets:SaveScrollPosition(150)
    for i=1,2 do
        grid.layout={}
        sets:SaveScrollPosition(0)
        sets:Inject()
        sets:RestoreScrollPosition()
    end
    equal(sets.scrollAnchor,nil)
    equal(sets.prefs.scrollPosition,0)
    sets:Inject()
    grid.layout={row('different',0)}
    sets:RestoreScrollPosition()
    equal(grid.position,0)
end)
test('station uses its own search with the shared native grid',function()
    local original=SCENE_MANAGER.IsShowing
    SCENE_MANAGER.IsShowing=function(_,scene) return scene=='restyle_station_keyboard' end
    local sets,_,grid=fixture()
    sets.stationBook={contentSearchEditBox={GetText=function() return 'Breton' end}}
    sets:Inject()
    equal(sets.book,sets.stationBook)
    equal(#grid.entries,7)
    equal(grid.entries[1].kobFamilyKey,'b')
    SCENE_MANAGER.IsShowing=original
end)

test('station sets category only appears when outfit styles are enabled',function()
    local sets=fixture()
    local parent={}
    local old=ZO_COLLECTIBLE_DATA_MANAGER.GetCategoryDataById
    ZO_COLLECTIBLE_DATA_MANAGER.GetCategoryDataById=function() return {GetParentData=function() return parent end} end
    GetOutfitSlotDataCollectibleCategoryId=function() return 10 end
    local enabled=true
    local node={data={referenceData=parent}}
    local station={collectibleCategoryNodes={node},added=0}
    function station:GetRestyleCategoryData() return {IsSpecializedCollectibleCategoryEnabled=function() return enabled end} end
    function station:AddCategory(template,at,name,reference)
        equal(at,node); equal(name,'Сеты'); equal(reference,sets.category)
        self.added=self.added+1
    end
    sets:AddCategory(station)
    equal(station.added,1)
    enabled=false
    sets:AddCategory(station)
    equal(station.added,1)
    ZO_COLLECTIBLE_DATA_MANAGER.GetCategoryDataById=old
end)
print('Native sets tests passed: '..count)
