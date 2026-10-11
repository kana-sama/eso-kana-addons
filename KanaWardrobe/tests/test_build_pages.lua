local Fake=dofile(ROOT..'/tests/support/fake_eso.lua')
local G=dofile(ROOT..'/tests/support/geometry_controls.lua')
local function load()
 return Fake.Load({'Core.lua','Slots.lua','BuildModel.lua','lang/en.lua','Presets.lua','Inventory.lua','SetModel.lua','Dialogs.lua','PageAdapters.lua','UI.lua'})
end
local function native(f)
 local scenes={}
 for _,page in ipairs({'inventory','skills','stats','collectionsBook'})do
  local s={callbacks={},fragments={},state=SCENE_HIDDEN}
  function s:AddFragment(v)self.fragments[#self.fragments+1]=v end
  function s:RegisterCallback(_,cb)self.callbacks[#self.callbacks+1]=cb end
  function s:IsShowing()return self.state==SCENE_SHOWING or self.state==SCENE_SHOWN end
  function s:Fire(state)self.state=state;for _,cb in ipairs(self.callbacks)do cb(nil,state)end end
  scenes[page]=s
 end
 f:Put('SCENE_MANAGER',{GetScene=function(_,p)return scenes[p]end,IsShowing=function(_,p)return scenes[p]:IsShowing()end})
 local function right(name,w,h)
  local c=f:Control(name,nil,nil,w,h);c:SetAnchor(RIGHT,GuiRoot,RIGHT,0,0);f:Put(name,c);return c
 end
 right('ZO_CollectionsBook_TopLevel',930,690)
 right('ZO_Skills',930,690);local skillBg=right('ZO_SharedRightBackground',960,750)
 right('ZO_StatsPanel',645,730);local statsBg=right('ZO_SharedStatsBackground',645,750)
 -- Source-shaped native art: root width does NOT stretch these single-anchored textures.
 -- windowtemplates.xml: ZO_RightFootPrintBackground / ZO_StatsFootPrintBackground.
 local left=f:Control('ZO_SharedRightBackgroundLeft',skillBg,CT_TEXTURE,1024,1024)
 left:SetAnchor(TOPLEFT,skillBg,TOPLEFT,-35,-75);left:SetTexture('EsoUI/Art/Miscellaneous/centerscreen_left.dds');skillBg.children.Left=left
 local cap=f:Control('ZO_SharedRightBackgroundRight',skillBg,CT_TEXTURE,64,1024)
 cap:SetAnchor(TOPLEFT,left,TOPRIGHT,0,0);skillBg.children.Right=cap
 local art=f:Control('ZO_SharedStatsBackgroundBG',statsBg,CT_TEXTURE,1024,1024)
 art:SetAnchor(TOPLEFT,statsBg,TOPLEFT,-75,-75);statsBg.children.BG=art
 -- Skills also draws TREE_UNDERLAY_FRAGMENT over RIGHT_BG_FRAGMENT. Its
 -- original left edge coincides with the main art; extending only one layer
 -- leaves the tree tint starting at the old edge, visibly splitting the list.
 local tree=f:Control('ZO_SharedTreeUnderlay',nil,nil,384,1024)
 tree:SetAnchor(RIGHT,GuiRoot,RIGHT,-611,82);f:Put('ZO_SharedTreeUnderlay',tree)
 local treeLeft=f:Control('ZO_SharedTreeUnderlayLeft',tree,CT_TEXTURE,256,1024)
 treeLeft:SetAnchor(TOPLEFT,tree,TOPLEFT,0,0);treeLeft:SetTexture('EsoUI/Art/Miscellaneous/centerscreen_indexArea_left.dds');tree.children.Left=treeLeft
 local treeRight=f:Control('ZO_SharedTreeUnderlayRight',tree,CT_TEXTURE,128,1024)
 treeRight:SetAnchor(TOPLEFT,treeLeft,TOPRIGHT,0,0);tree.children.Right=treeRight
 local advanced=f:Control('ZO_AdvancedStatsPanel',nil,nil,295,750)
 advanced:SetAnchor(TOPRIGHT,ZO_StatsPanel,TOPLEFT,0,0);advanced:SetHidden(true);f:Put('ZO_AdvancedStatsPanel',advanced)
 local strip={current={},groups={},adds=0,removes=0,updates=0}
 function strip:Descriptor(k)local v=self.current[k];return type(v)=='userdata'and v.keybindButtonDescriptor or v end
 function strip:HasKeybindButtonGroup(g)return self.groups[g]==true end
 function strip:GetButtonOrEtherealDescriptorForKeybind(k)return self.current[k]end
 function strip:HasKeybindButton(d)return self.current[d.keybind]~=nil end
 function strip:RemoveKeybindButton(d)assert(self:Descriptor(d.keybind)==d,'removed unrelated descriptor');self.current[d.keybind]=nil;self.removes=self.removes+1 end
 function strip:AddKeybindButton(d)assert(not self.current[d.keybind]);d.keybindButtonGroupDescriptor=nil;self.current[d.keybind]=d.ethereal and d or Fake.Control({keybindButtonDescriptor=d});self.adds=self.adds+1;if self.onAdd then self.onAdd(d)end end
 function strip:UpdateKeybindButton(d)
  assert(self:Descriptor(d.keybind)==d and d.keybindButtonGroupDescriptor,'lost group inheritance')
  self.effectiveAlignment=d.alignment or d.keybindButtonGroupDescriptor.alignment
  self.updates=self.updates+1;if self.onUpdate then self.onUpdate(d)end
 end
 local function group(k)
  local apply={keybind=k,name='Apply',callback=function()error('native Send must not run')end,ethereal=true}
  local other={keybind=k..'_OTHER',callback=function()end}
  local g={apply,other,alignment='RIGHT'};apply.keybindButtonGroupDescriptor=g;other.keybindButtonGroupDescriptor=g
  strip.groups[g]=true;strip.current[k]=apply;strip.current[other.keybind]=other
  return g,apply,other
 end
 local sg,sa,so=group('UI_SHORTCUT_SECONDARY');local ag,aa,ao=group('UI_SHORTCUT_PRIMARY')
 f:Put('KEYBIND_STRIP',strip);f:Put('SKILLS_WINDOW',{keybindStripDescriptor=sg});f:Put('STATS',{keybindButtons=ag})
 return scenes,strip,{skills=sa,stats=aa},{skills=sg,stats=ag},{so,ao}
end
local function save(repo,value)
 value.id=repo:NewDraft().id;return assert(repo:Save(value,0))
end
local function setup(kw)
 local api=Fake.New();local inv=kw.Inventory.New(api);local repo=kw.Presets.New({},'EU','@a','1','One')
 local s={view={state='idle',selected={},selection={},missing={},isEditor=false},calls={},owners={}}
 function s:GetView()return self.view end
 function s:GetNativeOwnership()return self.owners end
 for _,method in ipairs({'BeginNew','BeginEdit','Save','SaveAndApply','Cancel','Recover','Apply','SetAttributesEnabled','SetSelected','SetSkillSelected','SetBarSelected'})do
  s[method]=function(self,...)self.calls[#self.calls+1]={method,...};return true end
 end
 return repo,s,inv
end
return {
 missing_skill_repair_rows_stay_inside_editor_and_expose_explicit_choices=function()
  G.With(1280,720,1,function(f)
   local kw=load();local scenes=native(f);local repo,s,inv=setup(kw);local pages=kw.PageAdapters.New(_G)
   s.view={state='editing',isEditor=true,component='abilities',page='skills',selected={},selection={skills={['99:active:999']=true},bars={front={[1]=true},back={}}},name='Repair',draft={abilities={skills={['10:active:51']={kind='active',purchased=true,morph=2}}}},missing={['skill:99:active:999']={domain='skills',key='99:active:999',skillKey='99:active:999',ref={kind='active',purchased=true,morph=2},problem={code='skillUnavailable'}},['bar:front:1']={domain='front',key=1,skillKey='99:active:999',ref={kind='skill',skillKey='99:active:999',expectedMorph=2},problem={code='skillUnavailable'}}}}
   function s:ResolveMissingAbility(...)self.calls[#self.calls+1]={'ResolveMissingAbility',...};return true end
   local ui=kw.UI.New(repo,s,nil,inv,{pages=pages});scenes.skills:Fire(SCENE_SHOWN);ui:Refresh()
   assert(#ui.repairRows==2 and not ui.repairRows[1]:IsHidden() and not ui.repairRows[2]:IsHidden())
   assert(not ui.model.canSave and not ui.model.canSaveAndApply and ui.ghostButton:IsHidden())
   for _,row in ipairs(ui.repairRows)do assert(row:GetParent()==ui.editor);assert(row.title:GetText():find('99:active:999',1,true));assert(row.reason:GetText()==kw.Dialogs.Problem({code='skillUnavailable'}));assert(row:GetWidth()<=ui.editor:GetWidth())end
   local actions=ui:RepairChoices('skill:99:active:999');assert(#actions==2);actions[2].run();local call=s.calls[#s.calls];assert(call[1]=='ResolveMissingAbility' and call[2]=='skill:99:active:999' and call[3]=='replace' and call[4]=='10:active:51')
   actions[1].run();assert(s.calls[#s.calls][3]=='omit');ui:RepairChoices('bar:front:1')[2].run();assert(s.calls[#s.calls][2]=='bar:front:1' and s.calls[#s.calls][3]=='replace')
   s.view.missing={};ui:Refresh();assert(ui.repairRows[1]:IsHidden() and ui.repairRows[2]:IsHidden())
  end)
 end,
 all_pages_share_order_quickslot_and_editor_commands=function()
  G.With(1920,1080,1,function(f)
   local kw=load();local scenes=native(f);local repo,s,inv=setup(kw)
   local first=save(repo,{name='Gear',equipment={[0]={kind='empty'}}});save(repo,{name='Stats',attributes={health=1,magicka=2,stamina=3}})
   assert(repo:SaveQuick({equipment={[0]={kind='empty'}}}))
   local actual={equipment=inv:Capture(false).worn,attributes={health=1,magicka=2,stamina=3}};local captures=0
   local pages=kw.PageAdapters.New(_G)
   local ui=kw.UI.New(repo,s,{Hide=function()end},inv,{pages=pages,captureActual=function()captures=captures+1;return actual,{available=false}end})
   for _,page in ipairs({'inventory','skills','stats','collectionsBook'})do
    scenes[page]:Fire(SCENE_SHOWN);local before=captures;local m=ui:Refresh();assert(captures==before+1,'one capture per refresh')
    assert(m.rows[1].id==first.id and m.quickId==kw.Presets.QUICK_ID)
    ui.newButton.handlers.OnClicked();assert(s.calls[#s.calls][2]==page)
    ui:ContextMenu(m.rows[1])[1].run();assert(s.calls[#s.calls][4]==page)
   end
  end)
 end,
 included_domains_match_and_unsupported_does_not_block_gear=function()
  local kw=load();local repo,s,inv=setup(kw)
  save(repo,{name='Gear',equipment={[0]={kind='empty'}}});save(repo,{name='Mixed',equipment={[0]={kind='empty'}},attributes={health=5,magicka=0,stamina=0}})
  local ui=kw.UI.New(repo,s,nil,inv,{captureActual=function()return {equipment=inv:Capture(false).worn},{available=false}end})
  local m=ui:Refresh();assert(m.rows[1].matches and m.rows[1].canApply);assert(not m.rows[2].matches and not m.rows[2].canApply and m.rows[2].problem.code=='attributesUnavailable')
 end,
 native_background_width_is_restored_per_scene=function()
  G.With(1920,1080,1,function(f)
   local kw=load();local scenes=native(f);local p=kw.PageAdapters.New(_G)
   local widths={inventory=ZO_SharedWideLeftPanelBackground:GetWidth(),skills=ZO_SharedRightBackground:GetWidth(),stats=ZO_SharedStatsBackground:GetWidth(),collectionsBook=ZO_SharedRightBackground:GetWidth()}
   for _,page in ipairs({'inventory','skills','stats','collectionsBook'})do
    scenes[page]:Fire(SCENE_SHOWN);assert(p:Mount(page));p:SetBackgroundExpanded(page,true)
    assert(p:Get(page).background:GetWidth()>widths[page]);p:Unmount(page);assert(p:Get(page).background:GetWidth()==widths[page])
   end
  end)
 end,
 skills_background_extends_both_native_layers_and_restores_tree_for_other_pages=function()
  for _,factor in ipairs({1,1.25,2.5})do
   G.With(2560*factor,1440*factor,factor,function(f)
    local kw=load();local scenes=native(f);local pages=kw.PageAdapters.New(_G)
    local bg=ZO_SharedRightBackground;local main=bg:GetNamedChild('Left')
    local tree=ZO_SharedTreeUnderlay;local left=tree:GetNamedChild('Left');local right=tree:GetNamedChild('Right')
    local original={width=tree:GetWidth(),artWidth=left:GetWidth(),left=left:GetLeft(),right=right:GetRight(),top=left:GetTop(),height=left:GetHeight(),anchors=left:GetNumAnchors()}
    scenes.skills:Fire(SCENE_SHOWN);assert(pages:Mount('skills'))
    for _,screenWidth in ipairs({2560,2300,2560})do
     f.width=screenWidth*factor
     local nativeMainLeft=(screenWidth-995)*factor
     for _=1,3 do
      pages:SetBackgroundExpanded('skills',true)
      local coverage=assert(pages.textureWidths[bg].slices).edge
      local delta=nativeMainLeft-coverage:GetLeft()
      assert(delta>0)
      local treeCoverage=assert(pages.underlays.skills.art.slices).edge
      assert(math.abs(treeCoverage:GetLeft()-coverage:GetLeft())<.01,'only one native background layer covers the preset list')
      assert(math.abs(tree:GetWidth()-original.width-delta)<.01)
      assert(math.abs(left:GetRight()-treeCoverage:GetLeft()-original.artWidth-delta)<.01)
      assert(math.abs(right:GetRight()-(screenWidth-611)*factor)<.01,'tree right cap moved over native skills')
      assert(left:GetTop()==original.top and left:GetHeight()==original.height and left:GetNumAnchors()==original.anchors,'native tree vertical fade changed')
     end
    end
    pages:Mount('stats');pages:SetBackgroundExpanded('stats',true)
    assert(tree:GetWidth()==original.width and left:GetWidth()==original.artWidth and left:GetLeft()==original.left and right:GetRight()==original.right,'tree tint leaked to character page')
    pages:Unmount('stats')
    pages:Mount('inventory');pages:SetBackgroundExpanded('inventory',true)
    assert(tree:GetWidth()==original.width and left:GetWidth()==original.artWidth,'inventory changed the Skills-only layer')
    pages:Unmount('inventory')
   end)
  end
 end,
 skills_background_preserves_native_fade_width_and_tree_tint_sampling=function()
  for _,factor in ipairs({.75,1,2.5})do
   G.With(2560*factor,1440*factor,factor,function(f)
    local kw=load();local scenes=native(f);local pages=kw.PageAdapters.New(_G)
    local main=ZO_SharedRightBackground:GetNamedChild('Left')
    local tree=ZO_SharedTreeUnderlay:GetNamedChild('Left')
    local originals={}
    for _,texture in ipairs({main,tree})do
     originals[texture]={x=texture:GetLeft(),width=texture:GetWidth(),anchors={texture:GetAnchor(0)}}
    end
    scenes.skills:Fire(SCENE_SHOWN);assert(pages:Mount('skills'))
    for _,screenWidth in ipairs({2560,2300,2560})do
     f.width=screenWidth*factor
     for _=1,3 do
      pages:SetBackgroundExpanded('skills',true)
      for _,texture in ipairs({main,tree})do
       local parent=texture:GetParent()
       local fullWidth=originals[texture].width/factor
       local pieces={}
       for _,c in pairs(f.controls)do
        if c:GetParent()==parent and c.kind==CT_TEXTURE and c:GetTextureFileName()==texture:GetTextureFileName() and not c:IsHidden()then pieces[#pieces+1]=c end
       end
       table.sort(pieces,function(a,b)return a:GetLeft()<b:GetLeft()end)
       local function sourceX(x)
        for _,c in ipairs(pieces)do
         if x>=c:GetLeft() and x<c:GetRight()then
          local u0,u1=c:GetTextureCoords()
          return (u0+(u1-u0)*(x-c:GetLeft())/c:GetWidth())*fullWidth
         end
        end
        error('gap in native background')
       end
       local edge=pieces[1]:GetLeft()
       for _,offset in ipairs({8,16,32,48})do
        assert(math.abs(sourceX(edge+offset*factor)-offset)<.01,
         'native left fade stretched; main/tree fade borders diverge')
       end
       assert(#pieces==3,'background needs a fixed fade, flat extension and unchanged native remainder')
       for i=2,#pieces do assert(math.abs(pieces[i]:GetLeft()-pieces[i-1]:GetRight())<.01,'background pieces overlap or leave a seam')end
       local nativeLeft=(screenWidth-995)*factor
       assert(math.abs(sourceX(nativeLeft+128*factor)-128)<.01,'native page shading moved')
       for _,c in ipairs(pieces)do
        assert(c:GetTop()==texture:GetTop() and c:GetHeight()==texture:GetHeight(),'vertical fade changed')
        local _,_,v0,v1=c:GetTextureCoords();assert(v0==0 and v1==1)
       end
      end
     end
    end
    local writes=0
    for _,c in pairs(f.controls)do
     if c==main or c==tree or c:GetName():find('KanaWardrobeBackground',1,true)then
      local setAnchor=c.SetAnchor
      c.SetAnchor=function(self,...)writes=writes+1;return setAnchor(self,...)end
     end
    end
    local count=0;for _ in pairs(f.controls)do count=count+1 end
    for _=1,20 do pages:SetBackgroundExpanded('skills',true)end
    local after=0;for _ in pairs(f.controls)do after=after+1 end
    assert(writes==0 and count==after,'unchanged layout repeatedly rebuilt background controls')
    pages:Unmount('skills')
    for _,texture in ipairs({main,tree})do
     assert(texture:GetWidth()==originals[texture].width and texture:GetLeft()==originals[texture].x)
     local u0,u1,v0,v1=texture:GetTextureCoords();assert(u0==0 and u1==1 and v0==0 and v1==1)
     local anchor={texture:GetAnchor(0)};for i,value in ipairs(originals[texture].anchors)do assert(anchor[i]==value,'native anchor not restored')end
    end
    for _,c in pairs(f.controls)do
     if c:GetName():find('KanaWardrobeBackground',1,true)then assert(c:IsHidden(),'background extension leaked into another scene')end
    end
   end)
  end
 end,
 left_page_background_keeps_native_right_edge_and_vertical_gradient=function()
  for _,factor in ipairs({1,1.25,2.5})do
   G.With(2560*factor,1440*factor,factor,function(f)
    local kw=load();local scenes=native(f);local pages=kw.PageAdapters.New(_G)
    for _,page in ipairs({'skills','stats'})do
     local bg=pages:Get(page).background
     local art=bg:GetNamedChild(page=='skills' and 'Left' or 'BG')
     local cap=page=='skills' and bg:GetNamedChild('Right')or art
     local original={width=bg:GetWidth(),left=art:GetLeft(),right=cap:GetRight(),top=art:GetTop(),height=art:GetHeight(),artWidth=art:GetWidth(),anchors=art:GetNumAnchors()}
     scenes[page]:Fire(SCENE_SHOWN);assert(pages:Mount(page))
     for _=1,6 do
      pages:SetBackgroundExpanded(page,true)
      local list=pages:Bounds(page).list
      local coverage=page=='skills' and pages.textureWidths[bg].slices.edge or art
      assert(bg:GetWidth()>original.width and coverage:GetLeft()<=list.x*factor)
      assert(math.abs(cap:GetRight()-original.right)<.01,'native right background edge moved away from skills/stats')
      assert(art:GetTop()==original.top and art:GetHeight()==original.height and art:GetNumAnchors()==original.anchors,'vertical gradient or anchors changed')
     end
     pages:Unmount(page)
     assert(bg:GetWidth()==original.width and art:GetWidth()==original.artWidth and art:GetLeft()==original.left and cap:GetRight()==original.right)
    end
   end)
  end
 end,
 stats_advanced_panel_does_not_overlap_presets=function()
  G.With(1920,1080,1,function(f)
   local kw=load();native(f);local p=kw.PageAdapters.New(_G);local before=ZO_StatsPanel:Rect();local anchors=ZO_StatsPanel:GetNumAnchors()
   for _,advanced in ipairs({false,true})do
    ZO_AdvancedStatsPanel:SetHidden(not advanced);local b=assert(p:Bounds('stats')).list
    assert(b.x+b.width+12<=(advanced and ZO_AdvancedStatsPanel:GetLeft()or ZO_StatsPanel:GetLeft()))
    assert(b.x>=12 and b.y>=12 and b.y+b.height<=1080-64)
   end
   assert(ZO_StatsPanel:GetNumAnchors()==anchors and ZO_StatsPanel:GetLeft()==before.l)
  end)
 end,
 stats_background_follows_native_fragment_switch_when_advanced_stats_toggle=function()
  for _,factor in ipairs({1,1.25,2.5})do
   G.With(2560*factor,1440*factor,factor,function(f)
    local kw=load();local scenes=native(f);local pages=kw.PageAdapters.New(_G)
    local normal,right=ZO_SharedStatsBackground,ZO_SharedRightBackground
    local normalArt,rightArt=normal:GetNamedChild('BG'),right:GetNamedChild('Left')
    local original={normalWidth=normal:GetWidth(),normalArtWidth=normalArt:GetWidth(),
     rightWidth=right:GetWidth(),rightArtWidth=rightArt:GetWidth(),rightEdge=right:GetNamedChild('Right'):GetRight(),
     treeWidth=ZO_SharedTreeUnderlay:GetWidth(),statsLeft=ZO_StatsPanel:GetLeft()}
    scenes.stats:Fire(SCENE_SHOWN);pages:Mount('stats')
    for _,advanced in ipairs({false,true,false,true})do
     -- ESO removes STATS_BG_FRAGMENT and adds RIGHT_BG_FRAGMENT together
     -- with ADVANCED_STATS_FRAGMENT; these are distinct background controls.
     ZO_AdvancedStatsPanel:SetHidden(not advanced);normal:SetHidden(advanced);right:SetHidden(not advanced)
     pages:SetBackgroundExpanded('stats',true)
     local bg=pages:Get('stats').background
     assert(not bg:IsHidden(),'preset background still targets the hidden normal stats fragment')
     local list=pages:Bounds('stats').list
     local art=assert(pages.textureWidths[bg])
     local coverage=art.slices and art.slices.edge or art.control
     assert(coverage:GetLeft()<=list.x*factor,'visible background must cover the relocated preset list')
     if advanced then
      assert(bg==right and normal:GetWidth()==original.normalWidth and normalArt:GetWidth()==original.normalArtWidth,
       'opening advanced stats must restore the normal background before extending the replacement')
      assert(math.abs(right:GetNamedChild('Right'):GetRight()-original.rightEdge)<.01,'native right edge moved')
     else
      assert(bg==normal and right:GetWidth()==original.rightWidth and rightArt:GetWidth()==original.rightArtWidth,
       'closing advanced stats must release the shared right background')
     end
     assert(ZO_SharedTreeUnderlay:GetWidth()==original.treeWidth,'advanced stats must not extend the Skills-only tree layer')
     assert(ZO_StatsPanel:GetLeft()==original.statsLeft,'character controls must not move')
    end
    pages:Mount('skills');pages:SetBackgroundExpanded('skills',true);pages:Unmount('skills')
    assert(normal:GetWidth()==original.normalWidth and normalArt:GetWidth()==original.normalArtWidth)
    assert(right:GetWidth()==original.rightWidth and rightArt:GetWidth()==original.rightArtWidth,
     'leaving stats with its advanced panel open must restore both backgrounds')
   end)
  end
 end,
 apply_identity_restored_with_same_group_for_owned_phases=function()
  G.With(1920,1080,1,function(f)
   local kw=load();local scenes,strip,apply,groups,others=native(f);local _,s=setup(kw);local p=kw.PageAdapters.New(_G)
   for _,page in ipairs({'skills','stats'})do
    scenes[page]:Fire(SCENE_SHOWN);p:Mount(page,s)
    local domain=page=='skills'and'skills'or'attributes';local descriptor=apply[page];local callback=descriptor.callback
    for _,phase in ipairs({'editor','entry','dispatching','waiting','unknown','recovery'})do
     s.owners={[domain]={token=7,phase=phase,page=page,possibleSent=true}};p:RefreshOwnership();assert(not strip.current[descriptor.keybind])
     p:RefreshOwnership();s.owners={};p:RefreshOwnership();assert(strip.current[descriptor.keybind]==descriptor)
     assert(descriptor.keybindButtonGroupDescriptor==groups[page] and strip.effectiveAlignment=='RIGHT' and descriptor.callback==callback)
    end
    assert(strip.current[others[1].keybind]==others[1] and strip.current[others[2].keybind]==others[2])
   end
  end)
 end,
 apply_different_descriptor_and_inactive_group_are_never_overwritten=function()
  G.With(1920,1080,1,function(f)
   local kw=load();local scenes,strip,apply,groups=native(f);local _,s=setup(kw);local p=kw.PageAdapters.New(_G)
   scenes.skills:Fire(SCENE_SHOWN);p:Mount('skills',s);local d=apply.skills;local foreign={keybind=d.keybind,callback=function()end}
   strip.current[d.keybind]=foreign;s.owners={skills={token=1,phase='editor'}};p:RefreshOwnership();assert(strip.current[d.keybind]==foreign and strip.removes==0)
   strip.current[d.keybind]=d;p:RefreshOwnership();strip.groups[groups.skills]=nil;s.owners={};p:RefreshOwnership();assert(not strip.current[d.keybind] and strip.adds==0)
   strip.groups[groups.skills]=true;strip.current[d.keybind]=foreign;p:RefreshOwnership();assert(strip.current[d.keybind]==foreign and strip.adds==0)
  end)
 end,
 apply_restore_rechecks_owner_group_and_identity_after_add_callbacks=function()
  for _,mutation in ipairs({'owner','group','identity'})do
   G.With(1920,1080,1,function(f)
    local kw=load();local scenes,strip,apply,groups=native(f);local _,s=setup(kw);local p=kw.PageAdapters.New(_G)
    scenes.skills:Fire(SCENE_SHOWN);p:Mount('skills',s);local d=apply.skills
    s.owners={skills={token=1,phase='waiting'}};p:RefreshOwnership();s.owners={}
    local foreign={keybind=d.keybind}
    strip.onAdd=function()
     if mutation=='owner'then s.owners={skills={token=2,phase='entry'}}
     elseif mutation=='group'then strip.groups[groups.skills]=nil
     else strip.current[d.keybind]=foreign end
    end
    p:RefreshOwnership();assert(strip.updates==0,'updated Apply after ownership/group/identity changed')
    if mutation=='identity'then assert(strip.current[d.keybind]==foreign)else assert(not strip.current[d.keybind],'orphan/reowned Apply remains native-actionable')end
   end)
  end
 end,
 apply_normal_userdata_and_native_show_orders_preserve_descriptor=function()
  G.With(1920,1080,1,function(f)
   local kw=load();local scenes,strip,apply,groups=native(f);local _,s=setup(kw);local p=kw.PageAdapters.New(_G)
   local d=apply.skills;d.ethereal=nil;strip.current[d.keybind]=Fake.Control({keybindButtonDescriptor=d})
   s.owners={skills={token=1,phase='entry'}};scenes.skills:Fire(SCENE_SHOWN);p:Mount('skills',s);assert(not strip.current[d.keybind])
   s.owners={};p:RefreshOwnership();assert(type(strip.current[d.keybind])=='userdata' and strip:Descriptor(d.keybind)==d and d.keybindButtonGroupDescriptor==groups.skills)
   scenes.skills:Fire(SCENE_HIDDEN);strip.groups[groups.skills]=nil;strip.current[d.keybind]=nil;p:Unmount('skills')
   s.owners={skills={token=2,phase='unknown'}};scenes.skills:Fire(SCENE_SHOWING);p:Mount('skills',s);p:RefreshOwnership();assert(not strip.current[d.keybind])
   strip.groups[groups.skills]=true;d.keybindButtonGroupDescriptor=groups.skills;strip.current[d.keybind]=Fake.Control({keybindButtonDescriptor=d})
   scenes.skills:Fire(SCENE_SHOWN);p:RefreshOwnership();assert(not strip.current[d.keybind],'stock AddGroup revived owned Apply')
  end)
 end,
 modern_scene_lifecycle_does_not_pause_and_bank_tab_restores_only_inventory=function()
  G.With(1920,1080,1,function(f)
   local kw=load();local scenes=native(f);local repo,s,inv=setup(kw);local pages=kw.PageAdapters.New(_G)
   local fragment={callbacks={}};function fragment:RegisterCallback(_,cb)self.callbacks[#self.callbacks+1]=cb end;function fragment:IsShowing()return true end
   f:Put('INVENTORY_FRAGMENT',fragment)
   s.view.state='applying';s.Pause=function()error('UI duplicated Session native lifecycle')end
   local ui=kw.UI.New(repo,s,{Hide=function()end},inv,{pages=pages,captureActual=function()return {equipment=inv:Capture(false).worn}end})
   local width=ZO_SharedWideLeftPanelBackground:GetWidth();scenes.inventory:Fire(SCENE_SHOWN)
   f:Put('SCENE_FRAGMENT_HIDDEN','fragment-hidden');fragment.callbacks[1](nil,SCENE_FRAGMENT_HIDDEN)
   assert(not ui.visible and ZO_SharedWideLeftPanelBackground:GetWidth()==width)
   scenes.stats:Fire(SCENE_SHOWN);fragment.callbacks[1](nil,SCENE_FRAGMENT_HIDDEN);assert(ui.visible and pages.active=='stats')
  end)
 end,
 all_included_parts_match_one_actual_revision_without_inventory_recapture=function()
  local kw=load();local repo,s,inv=setup(kw)
  save(repo,{name='Skills',abilities={skills={['1:active:2']={kind='active',purchased=true,morph=1}}}})
  save(repo,{name='Bars',abilities={bars={front={[1]={kind='empty'}}}}})
  save(repo,{name='Stats',attributes={health=0,magicka=0,stamina=0}})
  local eq=inv:Capture(false);local captures=0;inv.Capture=function()error('duplicate inventory capture')end
  local actual={equipment=eq.worn,equipmentState=eq,budgets={skills=1,attributes=0},catalogueRevision=4,
   abilities={skills={['1:active:2']={kind='active',purchased=true,morph=1}},bars={front={[1]={kind='skill',skillKey='1:active:2',expectedMorph=1}}}},attributes={health=0,magicka=0,stamina=0}}
  local ui=kw.UI.New(repo,s,nil,inv,{captureActual=function()captures=captures+1;return actual,{available=true,revision=4}end})
  local model=ui:Refresh();assert(captures==1 and model.rows[1].matches and not model.rows[2].matches and model.rows[3].matches)
  actual.abilities.skills['1:active:2'].morph=2;actual.attributes.health=1;model=ui:Refresh()
  assert(captures==2 and not model.rows[1].matches and not model.rows[3].matches)
 end,
 native_keybind_current_stack_is_used_and_suspended_native_group_untouched=function()
  G.With(1920,1080,1,function(f)
   local kw=load();local scenes,strip,apply,groups=native(f);local _,s=setup(kw);local p=kw.PageAdapters.New(_G)
   local top=3;function strip:GetTopKeybindStateIndex()return top end
   local has,remove,add,update=strip.HasKeybindButtonGroup,strip.RemoveKeybindButton,strip.AddKeybindButton,strip.UpdateKeybindButton
   strip.HasKeybindButtonGroup=function(self,g,index)assert(index==top,'queried suspended state');return has(self,g)end
   strip.RemoveKeybindButton=function(self,d,index)assert(index==top,'removed suspended state');return remove(self,d)end
   strip.AddKeybindButton=function(self,d,index)assert(index==top,'added to suspended state');return add(self,d)end
   strip.UpdateKeybindButton=function(self,d,index)assert(index==top,'updated suspended state');return update(self,d)end
   s.owners={skills={token=1,phase='editor'}};scenes.skills:Fire(SCENE_SHOWN);p:Mount('skills',s);assert(not strip.current[apply.skills.keybind])
   s.owners={};p:RefreshOwnership();assert(strip.current[apply.skills.keybind]==apply.skills)
   strip.groups[groups.skills]=nil;local modal={keybind=apply.skills.keybind};strip.current[modal.keybind]=modal
   s.owners={skills={token=2,phase='unknown'}};p:RefreshOwnership();assert(strip.current[modal.keybind]==modal)
   for _,stage in ipairs({'onAdd','onUpdate'})do
    top=3;strip.groups[groups.skills]=true;local d=apply.skills;d.keybindButtonGroupDescriptor=groups.skills;strip.current[d.keybind]=d
    strip.onAdd=nil;strip.onUpdate=nil;s.owners={skills={token=3,phase='waiting'}};p:RefreshOwnership();s.owners={}
    local before=strip.updates
    strip[stage]=function()top=4;strip.current[d.keybind]=modal end
    p:RefreshOwnership();assert(strip.current[d.keybind]==modal,'overwrote new current stack')
    assert(strip.updates==before+(stage=='onUpdate'and 1 or 0),'updated a suspended descriptor after stack change')
   end

  end)
 end,
 background_identity_replacement_restores_original_control_without_touching_replacement=function()
  G.With(1920,1080,1,function(f)
   local kw=load();local scenes=native(f);local p=kw.PageAdapters.New(_G);local original=ZO_SharedStatsBackground;local width=original:GetWidth()
   scenes.stats:Fire(SCENE_SHOWN);p:Mount('stats');p:SetBackgroundExpanded('stats',true);assert(original:GetWidth()>width)
   local replacement=f:Control('ReplacementStatsBackground',nil,nil,800,750);f:Put('ZO_SharedStatsBackground',replacement)
   p:Unmount('stats');assert(original:GetWidth()==width and replacement:GetWidth()==800)
  end)
 end,
 save_apply_buttons_remain_present_while_busy=function()
  G.With(1920,1080,1,function(f)
   local kw=load();local scenes=native(f);local repo,s,inv=setup(kw);local pages=kw.PageAdapters.New(_G)
   s.view={state='editing',isEditor=true,component='attributes',page='stats',selected={},selection={attributes=true},missing={},attributesEnabled=true,name='Stats',draft={attributes={health=1,magicka=0,stamina=0}}}
   local ui=kw.UI.New(repo,s,{Hide=function()end},inv,{pages=pages,captureActual=function()return {equipment=inv:Capture(false).worn,attributes={health=0,magicka=0,stamina=0}}end})
   scenes.stats:Fire(SCENE_SHOWN)
   for _,state in ipairs({'editing','applying','restoring','recovery'})do
    s.view.state=state;ui:Refresh();assert(not ui.saveButton.hidden and not ui.saveAndApplyButton.hidden and not ui.cancelButton.hidden)
    assert(ui.saveButton.enabled==(state=='editing') and ui.saveAndApplyButton.enabled==(state=='editing'))
    assert(not ui.attributesCheck.hidden);assert(ui.attributesCheck:GetWidth()==20,'checkbox icon stretched to row width');G.Contained(ui.attributesCheck.label,ui.editor);G.Contained(ui.saveAndApplyButton,ui.content);G.Disjoint(ui.saveButton,ui.saveAndApplyButton)
   end
   s.view.state='editing';ui:Refresh();ui.attributesCheck.toggle(nil,false);assert(s.calls[#s.calls][1]=='SetAttributesEnabled' and s.calls[#s.calls][2]==false)
   ui.saveAndApplyButton.handlers.OnClicked();assert(s.calls[#s.calls][1]=='SaveAndApply')
  end)
 end,
 geometry_hidden_stats_recovers_when_advanced_closes_without_refresh=function()
  G.With(1280,720,1,function(f)
   local kw=load();local scenes=native(f);local repo,s,inv=setup(kw);local pages=kw.PageAdapters.New(_G)
   local width=ZO_SharedStatsBackground:GetWidth()
   -- Native Stats645 + advanced295 leaves insufficient room for the list.
   ZO_AdvancedStatsPanel:SetHidden(false)
   local captures=0
   local ui=kw.UI.New(repo,s,{Hide=function()end},inv,{pages=pages,captureActual=function()captures=captures+1;return {equipment=inv:Capture(false).worn}end})
   -- Narrow further so advanced has <120 available list units, while without
   -- advanced the native Stats panel still leaves >300 list units.
   GuiRoot.fixture.width=1040;scenes.stats:Fire(SCENE_SHOWN)
   assert(ui.content.hidden and ZO_SharedStatsBackground:GetWidth()==width and pages.active=='stats')
   local before=captures;ZO_AdvancedStatsPanel:SetHidden(true)
   ui.root.handlers.OnUpdate(nil,1)
   assert(captures==before,'geometry retry unexpectedly captured actual state')
   assert(not ui.content.hidden,'newly available active-page bounds did not restore content')
   assert(ZO_SharedStatsBackground:GetWidth()>width,'native background did not follow recovered layout')
   G.Contained(ui.root,GuiRoot);G.Disjoint(ui.root,ZO_StatsPanel)
  end)
 end,
 geometry_retry_never_wakes_inactive_gamepad_tab_or_stale_page=function()
  G.With(1040,720,1,function(f)
   local kw=load();local scenes=native(f);local repo,s,inv=setup(kw);local pages=kw.PageAdapters.New(_G)
   ZO_AdvancedStatsPanel:SetHidden(false)
   local ui=kw.UI.New(repo,s,{Hide=function()end},inv,{pages=pages,captureActual=function()return {equipment=inv:Capture(false).worn}end})
   local width=ZO_SharedStatsBackground:GetWidth();scenes.stats:Fire(SCENE_SHOWN);assert(ui.content.hidden)
   ZO_AdvancedStatsPanel:SetHidden(true);pages:Unmount('stats');ui.root.handlers.OnUpdate(nil,.5)
   assert(ui.content.hidden and ZO_SharedStatsBackground:GetWidth()==width,'retry woke unmounted active-page seam')
   pages:Mount('stats',s);f:Put('IsInGamepadPreferredMode',function()return true end)
   ui.root.handlers.OnUpdate(nil,1);assert(ui.content.hidden and ZO_SharedStatsBackground:GetWidth()==width,'retry woke gamepad-hidden content')
   f:Put('IsInGamepadPreferredMode',function()return false end)
   scenes.stats:Fire(SCENE_HIDDEN);ui.root.handlers.OnUpdate(nil,2)
   assert(ui.content.hidden and ZO_SharedStatsBackground:GetWidth()==width,'retry woke inactive page')
   GuiRoot.fixture.width=1280;scenes.skills:Fire(SCENE_SHOWN);local skillWidth=ZO_SharedRightBackground:GetWidth()
   scenes.stats:Fire(SCENE_HIDDEN);ui.root.handlers.OnUpdate(nil,3)
   assert(ui.page=='skills' and pages.active=='skills' and ui.visible and not ui.content.hidden and ZO_SharedRightBackground:GetWidth()==skillWidth)
   scenes.inventory:Fire(SCENE_SHOWN);ui:OnSceneHidden('inventory');ui.root.handlers.OnUpdate(nil,4)
   assert(not ui.visible and ui.content.hidden,'retry woke non-items inventory tab')
  end)
 end,
 stale_scene_hide_cannot_hide_new_active_page=function()
  G.With(1920,1080,1,function(f)
   local kw=load();local scenes=native(f);local repo,s,inv=setup(kw);local pages=kw.PageAdapters.New(_G)
   local ui=kw.UI.New(repo,s,{Hide=function()end},inv,{pages=pages,captureActual=function()return {equipment=inv:Capture(false).worn}end})
   scenes.inventory:Fire(SCENE_SHOWN);scenes.skills:Fire(SCENE_SHOWN);local width=ZO_SharedRightBackground:GetWidth()
   scenes.inventory:Fire(SCENE_HIDDEN);assert(ui.visible and not ui.content.hidden and pages.active=='skills' and ZO_SharedRightBackground:GetWidth()==width)
  end)
 end,
 recovery_menu_callbacks_cannot_consume_replaced_key=function()
  local kw=load();local repo,s,inv=setup(kw);local ui=kw.UI.New(repo,s,nil,inv)
  s.view={state='recovery',isEditor=true,selected={},missing={},recoveryKey='old',recovery={actions={'remaining'}}}
  local choice=ui:RecoveryActions()[1];s.view.recoveryKey='replacement';choice.run()
  assert(#s.calls==0 and ui.lastProblem.code=='recoveryChanged')
 end,
 recovery_choices_are_inspected_only_when_user_opens_the_menu=function()
  local kw=load();local repo,s,inv=setup(kw);local ui=kw.UI.New(repo,s,nil,inv);local reads=0
  s.view={state='recovery',isEditor=true,selected={},missing={},recovery={needsInspection=true}}
  function s:GetRecoveryView()
   reads=reads+1;self.view.recoveryKey='current';self.view.recovery={actions={'remaining'}};return self:GetView()
  end
  for _=1,7 do ui:Refresh()end
  assert(reads==0,'drawing the recovery panel performs native preflight')
  local choices=ui:RecoveryActions();assert(reads==1 and #choices==1)
  for _=1,7 do ui:Refresh()end
  choices[1].run()
  assert(reads==1 and s.calls[1][1]=='Recover' and s.calls[1][3]=='current')
 end,
 recovery_candidates_use_current_key_and_leave_legacy_modal_three_choices=function()
  local kw=load();local repo,s,inv=setup(kw);local ui=kw.UI.New(repo,s,nil,inv)
  s.view={state='recovery',isEditor=true,selected={},missing={},recoveryKey='key-A',recovery={actions={'confirmActualTarget','acceptCurrent','remaining','relinquishUnsent'}}}
  local choices=ui:RecoveryActions();assert(#choices==4);choices[1].run();assert(s.calls[1][1]=='Recover' and s.calls[1][2]=='confirmActualTarget' and s.calls[1][3]=='key-A')
  assert(#kw.Dialogs.CloseEditor(function()end,function()end,function()end).choices==3)
 end,
}
