dofile('Core.lua')
local K=KanaZoneGoals
K.saved={categories={},custom={},ignored={},expanded={}}
GetAchievementInfo=function(id)return id==872 and 'M\'aiq' or '' end
GetAchievementIdFromLink=function(s) return tonumber(s:match('achievement:(%d+)')) or 0 end
K.Refresh=function() end
local f=loadfile('Settings.lua');if f then f() end
assert(type(K.AddCustomAchievement)=='function','missing category settings')
assert(not K.AddCustomAchievement(0,'meetings','872'),'invalid zone accepted')
assert(not K.AddCustomAchievement(3,'books','872'),'excluded category accepted')
assert(not K.AddCustomAchievement(3,'meetings','999999'),'invalid achievement accepted')
assert(K.AddCustomAchievement(3,'meetings','|H1:achievement:872:0:0|hName|h'))
assert(#K.saved.custom[3]==1,'custom achievement missing')
assert(K.AddCustomAchievement(3,'global','872'))
assert(#K.saved.custom[3]==1 and K.saved.custom[3][1].category=='global','duplicate must update category')
local controls
local panelId
LibAddonMenu2={RegisterAddonPanel=function(_,id)
    panelId=id
    -- LAM creates a named ESO control, which also assigns the corresponding global.
    local panel={};_G[id]=panel;return panel
end,RegisterOptionControls=function(_,id,v)
    assert(id==panelId,'option controls must target the registered settings panel')
    controls=v
end}
dofile('UI.lua')
K.RegisterSettings()
assert(KanaZoneGoals==K,'settings panel overwrote the addon namespace used by XML handlers')
local checks={}
for _,v in ipairs(controls) do if v.type=='checkbox' then checks[#checks+1]=v end end
checks[1].setFunc(false);assert(K.saved.categories.sets==false,'first checkbox incorrect')
checks[2].setFunc(false);assert(K.saved.categories.fishing==false,'checkbox closure captures wrong category')
checks[1].setFunc(true);assert(K.saved.categories.sets==true and K.saved.categories.fishing==false,'checkboxes not independent')
print('PASS settings: validation/link parsing/deduplication/independent toggles')

assert(type(KanaZoneGoals.ShowGoalTooltip)=='function' and type(KanaZoneGoals.LeaveTooltip)=='function')
assert(load('KanaZoneGoals.ShowGoalTooltip(...)'))({})
local leaveCallback
zo_callLater=function(fn)leaveCallback=fn end
assert(load('KanaZoneGoals.LeaveTooltip()'))()
assert(type(leaveCallback)=='function','MouseExit handler did not run after registering settings')
leaveCallback()
print('PASS XML MouseEnter/MouseExit handlers after LAM global-control registration')
