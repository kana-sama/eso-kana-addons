local T=KAATest;T.load('Config');local V=T.load('View')
local function stats(total,selected,runs)return {byId={[1]={total=total,selected=selected,runs=runs,weighted=total,pairs={},knownVisions=0,knownStacks=0,currentVisions=0},[2]={total=total,selected=total-selected,runs=runs,weighted=total,pairs={},knownVisions=0,knownStacks=0,currentVisions=0}},knownOptions=2,optionCount=2}end
T.test('seven marker layouts preserve width thickness and position',function()
 for g=-3,3 do local layout=V.MarkerLayout(g);T.eq(#layout,g==0 and 1 or math.abs(g));for _,p in ipairs(layout)do T.eq(p.width,24);assert(p.y>=0 and p.y<=32)end end
end)
T.test('Russian counts retain singular plural forms',function()
 T.eq(V.Plural(1,'выбор','выбора','выборов'),'выбор');T.eq(V.Plural(21,'выбор','выбора','выборов'),'выбор');T.eq(V.Plural(11,'выбор','выбора','выборов'),'выборов')
end)
T.test('real view owns conditional hit regions and leaves native anchors alone',function()
 local a=T.api();local v=V.New(a);local selector=a.ENDLESS_DUNGEON_BUFF_SELECTOR_KEYBOARD;local offer={options={1,2},buffType=0,context={visions={}}};local pred={byId={[1]={grade=2},[2]={grade=-2}}}
 v:Show(selector,offer,pred,'default',nil);local mark=v.marks[selector.buffControls[1]];assert(not mark:IsHidden());assert(not mark.mouse);assert(not selector.buffControls[1].anchor)
 v:Show(selector,offer,pred,'default',stats(12,7,5));assert(mark.mouse)
 mark.handlers.OnMouseEnter();v:Hide();for _,fn in ipairs(a.later)do fn()end;assert(not v.tooltip or v.tooltip:IsHidden())
end)
T.test('tooltip does not allocate new native controls on every hover',function()
 local a=T.api();local created=0;local original=a.WINDOW_MANAGER.CreateControl
 a.WINDOW_MANAGER.CreateControl=function(...)created=created+1;return original(...)end
 local v=V.New(a);local s=a.ENDLESS_DUNGEON_BUFF_SELECTOR_KEYBOARD;v:Show(s,{options={1,2},context={visions={}}},{byId={[1]={grade=1},[2]={grade=-1}}},'default',stats(2,1,1))
 local mark=v.marks[s.buffControls[1]];v:ShowTooltip(mark);local before=created;v:HideTooltip();v:ShowTooltip(mark);T.eq(created,before)
end)
for _,first in ipairs({'profile','tooltip'})do
 T.test('profile and tooltip backdrops avoid existing native child names with '..first..' opened first',function()
  local P=T.load('Profiles');T.load('History');local W=T.load('ProfileWindow');local a=T.api()
  -- An unnamed backdrop from another addon already owns the global MungeOverlay.
  a.WINDOW_MANAGER:CreateControlFromVirtual(nil,a.GuiRoot,'ZO_DefaultBackdrop')
  local w=W.New(a,P.New({},'EU','one'),function()end);local v=V.New(a);local s=a.ENDLESS_DUNGEON_BUFF_SELECTOR_KEYBOARD
  v:Show(s,{options={1,2},context={visions={}}},{byId={[1]={grade=1},[2]={grade=-1}}},'default',stats(2,1,1))
  local function hover()
   v.marks[s.buffControls[1]].handlers.OnMouseEnter();local delayed=table.remove(a.later,1);delayed()
  end
  if first=='profile'then w:Open();hover()else hover();w:Open()end
  assert(not w.root:IsHidden());assert(not v.tooltip:IsHidden());assert(#v.tipChildren>0)
  w:Close();v:HideTooltip();w:Open();hover();assert(not v.tooltip:IsHidden())
 end)
end
T.test('custom textures use repository-relative ESO resource root',function()
 local a=T.api();local v=V.New(a);local s=a.ENDLESS_DUNGEON_BUFF_SELECTOR_KEYBOARD
 v:Show(s,{options={1,2},context={visions={}}},{byId={[1]={grade=1},[2]={grade=-1}}},'default',nil)
 T.eq(v.marks[s.buffControls[1]].textures[1].texture,'eso-kana-addons/KanaArchiveAssist/Textures/chevron-up.dds')
end)
T.test('all marker DDS files have compatible dimensions and crop without stretching the glyph',function()
 local a=T.api();local v=V.New(a);local s=a.ENDLESS_DUNGEON_BUFF_SELECTOR_KEYBOARD
 for _,grade in ipairs({-1,0,1})do
  v:Show(s,{options={1,2},context={visions={}}},{byId={[1]={grade=grade}}},'default',nil)
  local texture=v.marks[s.buffControls[1]].textures[1];local path=texture.texture:gsub('^eso%-kana%-addons/','')
  local file=assert(io.open(path,'rb'));local data=file:read('*a');file:close()
  local function u32(at)local x,y,z,w=data:byte(at+1,at+4);return x+y*256+z*65536+w*16777216 end
  T.eq(data:sub(1,4),'DDS ');local width,height=u32(16),u32(12)
  assert(width%4==0 and height%4==0,'ESO cannot load marker DDS dimensions '..width..'x'..height)
  T.eq(u32(76),32);T.eq(u32(80),65);T.eq(u32(84),0);T.eq(u32(88),32)
  T.eq(u32(92),16711680);T.eq(u32(96),65280);T.eq(u32(100),255);T.eq(u32(104),4278190080)
  T.eq(#data,128+width*height*4)
  local uv=assert(texture.textureCoords,'padded marker needs explicit texture coordinates')
  T.near((uv[2]-uv[1])*width,texture:GetWidth());T.near((uv[4]-uv[3])*height,texture:GetHeight())
  local visible=0
  for y=0,height-1 do for x=0,width-1 do
   local alpha=data:byte(128+(y*width+x)*4+4)
   if x>=texture:GetWidth()or y>=texture:GetHeight()then T.eq(alpha,0)elseif alpha>0 then visible=visible+1 end
  end end
  assert(visible>0,'marker glyph must not be fully transparent')
 end
end)
T.test('general history gives a factual tooltip even without an exact context match',function()
 local a=T.api();local v=V.New(a);local s=a.ENDLESS_DUNGEON_BUFF_SELECTOR_KEYBOARD
 local stats={byId={[1]={total=3,selected=2,runs=2,weighted=3,pairs={[2]={total=2,chosen=1,otherChosen=0}},knownVisions=0,knownStacks=0,currentVisions=1}},knownOptions=1,optionCount=2}
 v:Show(s,{options={1,2},context={visions={{9,1}}}},{byId={[1]={grade=1},[2]={}}},'default',stats)
 local mark=v.marks[s.buffControls[1]];assert(mark.mouse);v:ShowTooltip(mark)
 local text='';for _,c in ipairs(v.tipChildren)do if not c:IsHidden()then text=text..'\n'..c:GetText()end end
 assert(text:find('2 из 3',1,true));assert(text:find('67%',1,true));assert(text:find('0 из 1',1,true));assert(text:find('1 : 0',1,true))
 assert(text:find('Другие варианты без истории',1,true));assert(not v.marks[s.buffControls[2]])
end)
T.test('hovering a different tooltip section resets pooled label alignment and widths',function()
 local a=T.api();local v=V.New(a);local s=a.ENDLESS_DUNGEON_BUFF_SELECTOR_KEYBOARD
 local data=stats(12,7,3);data.byId[2].preliminary=true
 v:Show(s,{options={1,2},context={visions={}}},{byId={[1]={grade=2},[2]={grade=-1}}},'default',data)
 v:ShowTooltip(v.marks[s.buffControls[1]]);v:ShowTooltip(v.marks[s.buffControls[2]])
 for _,c in ipairs(v.tipChildren)do if not c:IsHidden()then
  if c:GetText()=='Выбран'or c:GetText()=='Разные забеги'then T.eq(c.align,a.TEXT_ALIGN_LEFT)end
  if c:GetText()=='3'then assert(c:GetWidth()<200)end
 end end
end)
