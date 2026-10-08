local Fake=dofile(ROOT..'/tests/support/fake_eso.lua')
local G=dofile(ROOT..'/tests/support/geometry_controls.lua')
local function load(f)
 local k=Fake.Load({'Core.lua','Slots.lua','lang/en.lua','AppearanceAdapter.lua','BuildDescription.lua','PageAdapters.lua','SelectionOverlay.lua','SummaryView.lua'})
 f:Put('COLLECTIBLE_CATEGORY_TYPE_COSTUME',1);f:Put('COLLECTIBLE_CATEGORY_TYPE_HAT',2)
 f:Put('GetCollectibleName',function(id)return 'Collectible '..id end)
 f:Put('GetCollectibleIcon',function(id)return 'icon'..id end)
 return k
end
return {
 appearance_checkboxes_are_left_of_native_applied_icon_even_when_hidden=function()
  G.With(1920,1080,1,function(f)
   local k=load(f);local nodes={}
   for i,types in ipairs({{[1]=true},{[2]=true},{[1]=true,[2]=true},{[999]=true}})do
    local c=f:Control('Category'..i,GuiRoot,CT_LABEL,220,26);c:SetAnchor(TOPLEFT,GuiRoot,TOPLEFT,600,100+i*30)
    local status=f:Control('Applied'..i,c,CT_TEXTURE,24,24);status:SetAnchor(RIGHT,c,LEFT,-3,0);c.children.StatusIcon=status
    status:SetHidden(i==2)
    nodes[i]={control=c,data={GetCollectibleCategoryTypesInCategory=function()return types end}}
   end
   f:Put('COLLECTIONS_BOOK',{categoryNodeLookupData=nodes})
   local pages=k.PageAdapters.New(_G);local entries=pages:GetSelectionIcons('collectionsBook');assert(#entries==2)
   local toggles={}
   for _,entry in ipairs(entries)do
    local overlay=k.SelectionOverlay.New(entry.parent,entry.resolveKey,function(domain,key,value)toggles[#toggles+1]={domain,key,value}end)
    overlay:Bind(entry.icon,entry.resolveKey,entry.placement);overlay:Refresh()
    assert(not overlay.control:IsHidden())
    assert(overlay.control:GetRight()==entry.icon:GetLeft()-4)
    assert(math.abs((overlay.control:GetTop()+overlay.control:GetBottom())-(entry.icon:GetTop()+entry.icon:GetBottom()))<.01)
    overlay.control.handlers.OnClicked(overlay.control,1);overlay:Destroy()
   end
   assert(#toggles==2 and toggles[1][1]=='appearance')
   nodes[1].control:SetHidden(true);assert(#pages:GetSelectionIcons('collectionsBook')==1)
  end)
 end,
 appearance_description_only_contains_saved_categories_including_empty=function()
  G.With(1920,1080,1,function(f)
   local k=load(f);local desc=k.BuildDescription.Build({appearance={[1]=101,[2]=0}})
   assert(#desc.appearance==2 and desc.appearance[1].id==101 and desc.appearance[2].name=='No hat')
   assert(not k.BuildDescription.Build({attributes={health=64,magicka=0,stamina=0}}).appearance)
   assert(#k.BuildDescription.Build({appearance={[2]=0}}).appearance==1)
  end)
 end,
 appearance_grid_wraps_cards_and_keeps_them_read_only=function()
  G.With(1920,1080,1,function(f)
   local k=load(f)
   local create=WINDOW_MANAGER.CreateControlFromVirtual
   WINDOW_MANAGER.CreateControlFromVirtual=function(wm,name,parent,template)
    if template~='KanaWardrobeAppearanceTile'then return create(wm,name,parent,template)end
    local c=f:Control(name,parent,CT_CONTROL)
    for _,child in ipairs({'Title','Icon','Highlight','Status'})do c.children[child]=f:Control(name..child,c,child=='Title' and CT_LABEL or CT_TEXTURE)end
    return c
   end
   local tooltip={};function tooltip:GetOwner()return self.owner end
   function tooltip:SetCollectible(id)self.collectible=id end
   f:Put('ItemTooltip',tooltip);f:Put('InitializeTooltip',function(t,owner)t.owner=owner end)
   f:Put('ClearTooltip',function(t)t.owner=nil end);f:Put('ClearTooltipImmediately',nil)
   local root=f:Control('Info',GuiRoot,CT_CONTROL,405,600)
   local view=k.SummaryView.New(root,'AppearanceInfo',root)
   local entries={{id=101,name='Costume',icon='a'},{id=0,name='No hat'},{id=301,name='Skin',icon='b'}}
   local data={metrics={},sets={},rows={},details={},specials={},description={appearance=entries}}
   view:Layout(data,405,'en')
   local tiles=view.appearanceTiles
   assert(#tiles==3 and tiles[1]:GetTop()==tiles[2]:GetTop())
   assert(tiles[3]:GetTop()>tiles[1]:GetBottom() and tiles[2]:GetRight()<root:GetRight())
   assert(tiles[2]:GetNamedChild('Icon'):IsHidden() and tiles[2]:GetNamedChild('Title'):GetText()=='No hat')
   assert(not tiles[1]:GetHandler('OnMouseUp') and not tiles[1]:GetHandler('OnDragStart'))
   tiles[1].handlers.OnMouseEnter();assert(tooltip.collectible==101 and tooltip.owner==tiles[1])
   view:Hide();assert(tooltip.owner==nil)
   view:Layout({metrics={},sets={},rows={},details={},specials={}},405,'en')
   for _,card in ipairs(tiles)do assert(card:IsHidden())end
  end)
 end,
}
