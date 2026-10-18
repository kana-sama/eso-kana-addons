local F=dofile('KanaTrifecta/tests/fixtures.lua')
local S=dofile('KanaTrifecta/tests/ui_stubs.lua')
return {
 diagnostic_actions_are_available_in_own_settings=function()
  local a=S.api();local options,panel
  local messages={}
  a.d=function(value) messages[#messages+1]=value end
  a.LibAddonMenu2={
   RegisterAddonPanel=function(_,id,data) panel=data;return {} end,
   RegisterOptionControls=function(_,id,controls) options=controls end,
  }
  local b=KanaTrifecta.Bootstrap.New(a)
  b.saved={};b.observer.ReadContext=function() return {zoneId=123,difficulty=2} end
  b.hud={Status=function() return 'HUD visible' end}
  KanaTrifecta.Settings.Initialize(b)
  assert(panel.displayName:find('Trifecta Tracker') and #options==4)
  assert(options[2].getFunc()==false)
  options[2].setFunc(true)
  assert(b.diagnostics.enabled and options[2].getFunc())
  options[3].func()
  assert(#messages==3 and messages[1]:find('debug=true')
   and messages[2]:find('zone=123') and messages[3]=='HUD visible')
  options[4].func()
  assert(type(b.saved.dump)=='table' and type(b.saved.dump.events)=='table')
 end,
}
