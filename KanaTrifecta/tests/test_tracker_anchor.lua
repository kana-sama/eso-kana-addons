local F=dofile('KanaTrifecta/tests/fixtures.lua')
local S=dofile('KanaTrifecta/tests/ui_stubs.lua')
local function tracker(name,bottom)
 local c=S.control(name);c.bottom=bottom
 c.GetBottom=function(self) return self.bottom end
 local owner={active=true,detached=false}
 function owner:IsActive() return self.active end
 function owner:IsDetached() return self.detached end
 function owner:GetContainerControl() return c end
 return {control=S.control(name..'Panel'),owner=owner},c
end
local function readyManager(trackers)
 local manager={trackers=trackers,isFullyLoaded=true,element={}}
 function manager:GetPlatformHUDElement() return self.element end
 return manager
end
return {
 waits_for_native_hud_initialization_then_attaches_without_reload=function()
  local a=S.api();local ac,achievement=tracker('Achievement',380)
  local manager=readyManager({ac});manager.isFullyLoaded=false;manager.element=nil
  local calls=0
  function ac.owner:IsDetached()
   calls=calls+1
   return manager:GetPlatformHUDElement():GetCustomOptionValue('SeparatedTrackers','Achievement')
  end
  a.HUD_TRACKER_MANAGER=manager
  local h=KanaTrifecta.Hud.New(a,function() end);h:SetVisible(true);local v=F.NewRun():View(0)
  h:Render(v);assert(calls==0 and h.content:IsHidden())
  manager.isFullyLoaded=true
  h:Render(v);assert(calls==0 and h.content:IsHidden())
  manager.element={GetCustomOptionValue=function() return false end}
  h:Render(v)
  assert(calls>0 and not h.content:IsHidden() and h.root.anchor[2]==achievement)
 end,
 follows_lowest_visible_tracker_and_switches_without_reload=function()
  local a=S.api();local q,quest=tracker('QuestText',200)
  q.owner.GetTrackerControl=function() return quest end
  local e,endeavor=tracker('Endeavor',290);local ac,achievement=tracker('Achievement',380)
  a.HUD_TRACKER_MANAGER=readyManager({q,e,ac})
  local h=KanaTrifecta.Hud.New(a,function() end);h:SetVisible(true);local v=F.NewRun():View(0);h:Render(v)
  assert(h.root.anchor[2]==achievement,'Panel must sit below achievement, not quest')
  achievement:SetHidden(true);h:Render(v);assert(h.root.anchor[2]==endeavor)
  e.owner.active=false;h:Render(v);assert(h.root.anchor[2]==quest)
  achievement:SetHidden(false);h:Render(v);assert(h.root.anchor[2]==achievement)
  q.owner.active=false;ac.owner.active=false;h:Render(v);assert(h.content:IsHidden())
 end,
 ignores_hidden_parents_and_detached_trackers_outside_main_stack=function()
  local a=S.api();local q,quest=tracker('QuestText',200)
  local ac,achievement=tracker('Achievement',380);local detached=tracker('Detached',600)
  local parent=S.control('HiddenTrackerParent');parent:SetHidden(true);achievement.parent=parent
  detached.owner.detached=true;a.HUD_TRACKER_MANAGER=readyManager({q,ac,detached})
  local h=KanaTrifecta.Hud.New(a,function() end);assert(h:ResolveAnchor()==quest)
  parent:SetHidden(false);assert(h:ResolveAnchor()==achievement)
 end,
 moving_same_tracker_recalculates_available_boss_scroll_height=function()
  local a=S.api();local ac,achievement=tracker('Achievement',200)
  a.HUD_TRACKER_MANAGER=readyManager({ac})
  local h=KanaTrifecta.Hud.New(a,function() end);h:SetVisible(true);local v=F.NewRun():View(0)
  for _,row in ipairs(v.bossRows) do row.name=string.rep('Long boss ',25) end
  h:Render(v);local initial=h.scroll:GetHeight()
  achievement.bottom=620;h:Render(v)
  assert(h.scroll:GetHeight()<initial,'Tracker growth must shrink available height')
  assert(h.scrollChild:GetHeight()>h.scroll:GetHeight() and h.rows[3].data)
  assert(h.root.anchor[4]==0 and h.rows[3].label.anchor[4]==0)
 end,
}
