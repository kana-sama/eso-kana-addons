-- Uses unmodified native scene-group/menu methods with rendering boundaries doubled.
local function eq(a,b) assert(a==b, tostring(a)..' ~= '..tostring(b)) end
local function read(path) local f=assert(io.open(path)); local s=f:read('*a'); f:close(); return s:gsub('\r\n','\n') end
local native=read('/tmp/esoui-live/esoui/ingame/mainmenu/keyboard/zo_mainmenu_keyboard.lua')
local function method(name)
    local start=assert(native:find('function MainMenu_Keyboard:'..name..'(',1,true))
    local stop=assert(native:find('\nend',start,true))+4
    assert((loadstring or load)(native:sub(start,stop)))()
end
MainMenu_Keyboard={}
method('AddRawScene'); method('SetupSceneGroupBar')
ZO_STATE={SHOWING=1,SHOWN=2,HIDING=3,HIDDEN=4}; SCENE_SHOWING=1
ZO_InitializingCallbackObject={Subclass=function() return {} end}
dofile('/tmp/esoui-live/esoui/libraries/zo_scene/zo_scenegroup.lua')
local scenes={}
local function scene(name)
    local s={name=name,fragments={},callbacks={}}
    function s:GetName() return self.name end
    function s:SetSceneGroup(g) self.group=g end
    function s:AddFragment(f) self.fragments[f]=true end
    function s:RegisterCallback(_,fn) table.insert(self.callbacks,fn) end
    scenes[name]=s; return s
end
SCENE_MANAGER={GetScene=function(_,name) return scenes[name] end,WillCurrentSceneConfirmHide=function() return false end}
function SCENE_MANAGER:Show(name)
    self.shown=name
    for _,fn in ipairs(scenes[name].callbacks) do fn(4,SCENE_SHOWING) end
end
local group=setmetatable({}, {__index=ZO_SceneGroup})
for _,name in ipairs({'collectionsBook','outfitStylesBook','itemSetsBook'}) do scene(name) end
group:Initialize('collectionsBook','outfitStylesBook','itemSetsBook')
function SCENE_MANAGER:GetSceneGroup() return group end
MENU_CATEGORY_COLLECTIONS=9
ZO_CATEGORY_LAYOUT_INFO={[9]={}}
TITLE_FRAGMENT={}; COLLECTIONS_TITLE_FRAGMENT={}
MAIN_MENU_MANAGER={HasBlockingScene=function() return false end}
ZO_MenuBar_ClearButtons=function(bar) bar.buttons={} end
ZO_MenuBar_AddButton=function(bar,data) table.insert(bar.buttons,data) end
ZO_MenuBar_SetDescriptorEnabled=function() end
ZO_MenuBar_SelectDescriptor=function(bar,key) bar.selected=key; return true end
GetString=function(id) return id end
ZO_CreateStringId=function(name,value) _G[name]=value end
local menu=setmetatable({categoryInfo={[9]={subcategoryBarFragment={}}},categoryAreaFragments={{}},sceneInfo={},categoryBar={},sceneGroupBar={},sceneGroupInfo={}}, {__index=MainMenu_Keyboard})
function menu:IsShowing() return true end
menu.sceneGroupBarLabel={SetText=function(self,s) self.text=s end,GetText=function(self) return self.text end,SetHidden=function() end}
local original1={descriptor='collectionsBook',categoryName='Collections'}
local original2={descriptor='outfitStylesBook',categoryName='Outfit styles'}
local original3={descriptor='itemSetsBook',categoryName='Item sets'}
local info={category=9,menuBarIconData={original1,original2,original3},sceneGroupBarFragment={}}
menu.sceneGroupInfo.collectionsSceneGroup=info
MAIN_MENU_KEYBOARD=menu
KanaOutfitBrowser={}
dofile('KanaOutfitBrowser/Collections.lua')
local addonScene=scene('kanaOutfitBrowser')
assert(KanaOutfitBrowser.Collections.Register(addonScene))
eq(info.menuBarIconData[1],original1); eq(info.menuBarIconData[2],original2)
eq(info.menuBarIconData[3].descriptor,'kanaOutfitBrowser'); eq(info.menuBarIconData[4],original3)
assert(group:HasScene('kanaOutfitBrowser')); eq(addonScene.group,group)
assert(addonScene.fragments[info.sceneGroupBarFragment]); assert(addonScene.fragments[TITLE_FRAGMENT]); assert(addonScene.fragments[COLLECTIONS_TITLE_FRAGMENT])
assert(addonScene.fragments[menu.categoryAreaFragments[1]])
eq(menu.sceneInfo.kanaOutfitBrowser.sceneGroupName,'collectionsSceneGroup')
print('PASS collections tab joins native group and preserves existing tabs/fragments')
menu:SetupSceneGroupBar(9,'collectionsSceneGroup')
menu.sceneGroupBar.buttons[3].callback()
eq(SCENE_MANAGER.shown,'kanaOutfitBrowser'); eq(group:GetActiveScene(),'kanaOutfitBrowser')
eq(menu.sceneGroupBar.selected,'kanaOutfitBrowser'); eq(menu.categoryBar.selected,9)
menu.sceneGroupBar.buttons[4].callback(); eq(SCENE_MANAGER.shown,'itemSetsBook')
print('PASS native tab callback opens addon and existing neighbor')
assert(KanaOutfitBrowser.Collections.Register(addonScene))
eq(#info.menuBarIconData,4); eq(group:GetNumScenes(),4); eq(#addonScene.callbacks,1)
print('PASS repeated registration is idempotent')
local before=#info.menuBarIconData
menu.sceneGroupInfo.collectionsSceneGroup=nil
local ok,reason=KanaOutfitBrowser.Collections.Register(scene('unavailable'))
eq(ok,false); assert(type(reason)=='string'); eq(#info.menuBarIconData,before)
print('PASS unavailable native group fails without mutation')
print('4 collections tests passed')
