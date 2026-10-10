local F=dofile('KanaTrifecta/tests/fixtures.lua')
local function setup(dedicated)
 assert(KanaTrifecta.Achievements,'Achievements not implemented')
 local shown,reset={},0;local ctx={contextGeneration=1,profileKey='fixture'}
 local api={GetAchievementInfo=function(id) if id==999 then return '' end;return 'A'..id,'Description',10,'icon',id==1 end,
 GetAchievementNumCriteria=function() return 1 end,GetAchievementCriterion=function() return 'Defeat',1,1 end,
 GetCategoryInfoFromAchievementId=function() return 1,2,1 end,
 GetAchievementSubCategoryInfo=function() return 'Dungeon',dedicated and 2 or 3 end,
 GetAchievementId=function(_,_,i) return i end,
 ACHIEVEMENTS={ShowAchievement=function(_,id) shown[#shown+1]=id end,ResetFilters=function() reset=reset+1 end,
 contentSearchEditBox={SetText=function(_,t) assert(t=='') end}},
 ACHIEVEMENTS_MANAGER={SetSearchString=function(_,t) assert(t=='') end},CallLater=function(fn) apiLater=fn end}
 local m=KanaTrifecta.Achievements.New(api,function() return ctx end)
 local p=F.NewRun().profile;p.achievementCatalogIds={1,2,1};p.journalAnchorAchievementId=1
 return m,p,shown,function() return reset end,ctx
end
return {
 fallback_uses_native_window=function()
  dofile('KanaTrifecta/lang/en.lua')
  local m,p=setup(false);local a=m.api;local ui=dofile('KanaTrifecta/tests/ui_stubs.lua').api()
  for k,v in pairs(ui) do a[k]=v end
  a.FRAGMENT_GROUP={MOUSE_DRIVEN_UI_WINDOW={},FRAME_TARGET_STANDARD_RIGHT_PANEL={}}
  local scene={AddFragmentGroup=function() end,AddFragment=function(self,f) self.fragment=f end}
  a.ZO_Scene={New=function() return scene end};a.ZO_FadeSceneFragment=a.ZO_SimpleSceneFragment
  a.SCENE_MANAGER={Show=function(_,name) assert(name=='kanaTrifectaAchievements') end}
  assert(m:Open(p,1));assert(m.root.isTopLevelWindow,'Achievement list must be a native top-level window')
  assert(m.root.values.SetDrawTier==a.DT_LOW);assert(scene.fragment.control==m.root)
  assert(#m.rows==2);assert(m.child:GetHeight()>0)
 end,
 dedicated_native_resets_filter=function() local m,p,shown,reset=setup(true);assert(m:Open(p,1));assert(shown[1]==1);assert(reset()==1) end,
 mixed_exact_catalog=function() local m,p=setup(false);local rows=m:BuildCatalog(p);assert(#rows==2);assert(rows[1].completed);assert(not rows[2].completed);assert(not m:IsDedicated(p)) end,
 stale_context_and_invalid_catalog=function() local m,p,shown,_,ctx=setup(true);ctx.contextGeneration=2;assert(not m:Open(p,1));assert(#shown==0);p.achievementCatalogIds={999};assert(not m:Availability(p)) end,
}
