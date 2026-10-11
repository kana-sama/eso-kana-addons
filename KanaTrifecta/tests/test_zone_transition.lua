local F=dofile('KanaTrifecta/tests/fixtures.lua')
local S=dofile('KanaTrifecta/tests/ui_stubs.lua')
local function setup()
 dofile('KanaTrifecta/profiles/catalog.lua')
 local a=S.api();local state={zone=636,difficulty=1,now=0};local events,updates,pending={},{},{}
 a.EVENT_PLAYER_ACTIVATED=1;a.EVENT_PLAYER_DEACTIVATED=2;a.EVENT_ZONE_CHANGED=3
 a.EVENT_MANAGER={RegisterForEvent=function(_,name,event,fn) events[event]=fn end,
  UnregisterForEvent=function() end,RegisterForUpdate=function(_,name,ms,fn) updates[name]=fn end,
  UnregisterForUpdate=function(_,name) updates[name]=nil end}
 a.GetGameTimeMilliseconds=function() return state.now end;a.GetTimeStamp=function() return 1000 end
 a.GetUnitZoneIndex=function() return 1 end;a.GetZoneId=function() return state.zone end
 a.GetCurrentZoneDungeonDifficulty=function() return state.difficulty end
 a.GetGroupSize=function() return 0 end;a.GetUnitDisplayName=function() return '@one' end
 a.GetRawUnitName=function() return 'Char' end;a.IsUnitDead=function() return false end
 a.CallLater=function(fn) pending[#pending+1]=fn end
 a.ZO_SavedVars={NewAccountWide=function() return {} end};a.SLASH_COMMANDS={}
 local b=KanaTrifecta.Bootstrap.New(a);b:Initialize();b.hud.root:SetHidden(false)
 local function settle() local fn=table.remove(pending,1);assert(fn);fn() end
 settle()
 return b,state,events,updates,settle
end
return {
 veteran_wayshrine_entry_recovers_after_delayed_difficulty_without_reload=function()
  local b,s,events,updates,settle=setup()
  events[2]();s.zone=146;events[1]();settle()
  assert(not b.context and b.hud.content:IsHidden())
  s.difficulty=2;s.now=1500
  assert(updates.KanaTrifectaContext,'Context must remain observable while panel is hidden')
  updates.KanaTrifectaContext();settle()
  assert(b.run.profileKey=='wayrest_sewers_i' and not b.hud.content:IsHidden())
  assert(b.hud.timer.text=='15:00' and not b.run.clock.startedAtMs)
  local run=b.run;updates.KanaTrifectaContext();assert(b.run==run,'Polling must preserve the run')
 end,
 pending_old_zone_refresh_cannot_activate_during_loadscreen=function()
  local b,s,events,updates,settle=setup()
  s.zone=146;s.difficulty=2;events[3]();events[2]();settle()
  assert(not b.context and b.hud.content:IsHidden(),'Old callback must not reattach during teleport')
  if updates.KanaTrifectaContext then updates.KanaTrifectaContext() end
  assert(not b.context)
  s.zone=283;events[1]();settle()
  assert(b.run.profileKey=='fungal_grotto_i' and not b.hud.content:IsHidden())
 end,
}
