local F=dofile('KanaTrifecta/tests/fixtures.lua')
local S=dofile('KanaTrifecta/tests/ui_stubs.lua')
return {
 timer_tooltip_has_two_columns_and_other_hover_stays_quiet=function()
  local a=S.api();local shown,cleared
  a.InitializeTooltip=function(t) shown=t end;a.ClearTooltip=function(t) cleared=t end
  local h=KanaTrifecta.Hud.New(a,function() end);local r=F.NewRun();F.Start(r,0);F.Kill(r,'a',1000)
  h:SetVisible(true);h:Render(r:View(61000))
  h.timer:GetHandler('OnMouseEnter')()
  assert(shown and shown~=a.InformationTooltip)
  assert(h.tooltipRows[1].value.text=='25:00')
  assert(h.tooltipRows[2].value.text=='01:01')
  assert(h.tooltipRows[3].value.text=='23:59')
  assert(h.tooltipRows[1].label.values.SetHorizontalAlignment==a.TEXT_ALIGN_LEFT)
  assert(h.tooltipRows[1].value.values.SetHorizontalAlignment==a.TEXT_ALIGN_RIGHT)
  assert(h.tooltipBody.anchor[1]==a.CENTER,'Native tooltip content must anchor inside its cell')
  assert(not h.deaths:GetHandler('OnMouseEnter'))
  assert(not h.rows[1].label:GetHandler('OnMouseEnter') and not h.rows[1].icon:GetHandler('OnMouseEnter'))
  h:Render(r:View(1800000))
  assert(h.tooltipRows[2].value.text=='30:00' and h.tooltipRows[3].value.text=='05:00')
  assert(h.tooltipRows[3].label.text==KanaTrifecta.Strings.timerOvertime)
  h.button:GetHandler('OnMouseEnter')();assert(h.medal.values.SetTexture:find('over.dds',1,true))
  h.timer:GetHandler('OnMouseExit')();assert(cleared==shown)
 end,

 native_quest_color_and_compact_icons_share_text_edge=function()
  local a=S.api();local h=KanaTrifecta.Hud.New(a,function() end);h:SetVisible(true);local v=F.NewRun():View(0)
  h:Render(v)
  assert(h.title.color[1]==0.9 and h.title.color[3]==0,'Title must use native quest yellow')
  assert(h.title:GetWidth()==h.title:GetTextWidth(),'Achievement icon must follow the actual title width')
  assert(h.deaths:GetWidth()==h.deaths:GetTextWidth(),'Skull must follow the actual counter width')
  assert(h.rows[1].label:GetWidth()==h.rows[1].label:GetTextWidth(),'HM icon must follow the actual boss text')
  assert(h.scrollChild:GetWidth()==h.width,'Bosses must reach the title and quest text edge')
  assert(h.scroll.anchor[4]==a.ZO_SCROLL_BAR_WIDTH and h.scroll:GetWidth()==h.width+a.ZO_SCROLL_BAR_WIDTH)
  assert(h.root.anchor[4]==0 and h.title.anchor[4]==0 and h.rows[1].label.anchor[4]==0)
 end,
 native_window_registered_with_hud_fragment=function()
  local a=S.api();local h=KanaTrifecta.Hud.New(a,function() end)
  assert(h.root.isTopLevelWindow,'HUD must be registered as a native top-level window')
  assert(h.root.values.SetDrawTier==a.DT_LOW);assert(h.fragment.control==h.root)
  assert(h.root.values.SetMouseEnabled==false);assert(h.content.values.SetMouseEnabled==false)
  assert(h.button.values.SetMouseEnabled==true)
  h.root:SetHidden(false);h:SetVisible(true);h:Render(F.NewRun():View(0))
  assert(h.root.anchor[2]==a.questTrackerControl);assert(not S.isHidden(h.title))
  h:SetVisible(false);h.root:SetHidden(false);assert(S.isHidden(h.title))
 end,
 status_reports_visibility_and_geometry_without_mutation=function()
  local a=S.api();local h=KanaTrifecta.Hud.New(a,function() end)
  local before=h.root:IsHidden();local status=h:Status()
  assert(status:find('UI v1',1,true));assert(status:find('rootHidden=true',1,true))
  assert(status:find('anchor=Quest',1,true));assert(status:find('rendered=false',1,true))
  assert(h.root:IsHidden()==before)
  h.root:SetHidden(false);h:SetVisible(true);h:Render(F.NewRun():View(0))
  status=h:Status();assert(status:find('rootHidden=false',1,true));assert(status:find('rendered=true',1,true))
  a.questTrackerControl=nil;h:Render(F.NewRun():View(0))
  assert(h:Status():find('anchor=missing',1,true))
 end,
 named_control_lookup_without_tracker_object=function()
  local a=S.api();a.FOCUSED_QUEST_TRACKER=nil
  a.WINDOW_MANAGER.GetControlByName=function(_,name,suffix)
   assert(name=='ZO_FocusedQuestTrackerPanelContainerQuestContainer');assert(suffix=='');return a.questTrackerControl
  end
  local h=KanaTrifecta.Hud.New(a,function() end);h.root:SetHidden(false);h:SetVisible(true);h:Render(F.NewRun():View(0))
  assert(h.root.anchor[2]==a.questTrackerControl);assert(not S.isHidden(h.content))
 end,
 quest_anchor_and_recreation=function()
  assert(KanaTrifecta.Hud,'Hud not implemented');local a=S.api();local h=KanaTrifecta.Hud.New(a,function() end)
  h:SetVisible(true);h:Render(F.NewRun():View(0));assert(h.root.anchor[2]==a.questTrackerControl);assert(h.root.anchor[5]==18)
  a.questTrackerControl=nil;h:Render(F.NewRun():View(0));assert(h.content.hidden)
  a.questTrackerControl=S.control('NewQuest');h:Render(F.NewRun():View(0));assert(not h.content.hidden)
 end,
 scene_return_outside_hidden=function()
  local a=S.api();local h=KanaTrifecta.Hud.New(a,function() end);h:SetVisible(false);h.root:SetHidden(false)
  assert(S.isHidden(h.content))
 end,
 short_height_and_controls_reused=function()
  local a=S.api();local h=KanaTrifecta.Hud.New(a,function() end);h:SetVisible(true);local v=F.NewRun():View(0)
  v.bossRows[3].name=string.rep('Long boss ',30);h:Render(v);h:Relayout(200,150)
  assert(h.scroll:GetHeight()<=150-h.listTop);assert(h.scrollChild:GetHeight()>h.scroll:GetHeight());assert(h.rows[3].icon)
  local row=h.rows[3];v.timer.text='24:59';h:Render(v);assert(h.rows[3]==row)
 end,
}
