local S={passed=0,failed=0}
function S.test(name,fn)
 local ok,err=pcall(fn)
 if ok then S.passed=S.passed+1 else S.failed=S.failed+1;print('FAIL: '..name..': '..tostring(err)) end
end
function S.eq(a,b) assert(a==b,tostring(a)..' ~= '..tostring(b)) end
function S.near(a,b,e) assert(math.abs(a-b)<=(e or 1e-8),tostring(a)..' ~= '..tostring(b)) end
function S.load(name)
 local f=io.open('KanaArchiveAssist/'..name..'.lua');assert(f,name..' not implemented');f:close();dofile('KanaArchiveAssist/'..name..'.lua')
 return KanaArchiveAssist[name]
end
function S.finish() print(string.format('%d passed, %d failed',S.passed,S.failed));os.exit(S.failed==0 and 0 or 1) end
function S.observation(id,run,selected,visions,options)
 return {schemaVersion=1,observationId=tostring(id),runId=tostring(run),profileId='p1',buffType=0,options=options or {1,2},selectedId=selected or 1,context={visions=visions or {}},timestamp=id}
end
function S.drain(job)
 for _=1,100000 do local done,result,reason=job:Step(math.huge);if done then return result,reason end end
 error('job did not finish')
end
function S.api()
 local api={TOPLEFT=1,TOPRIGHT=2,BOTTOMLEFT=3,BOTTOMRIGHT=4,TOP=5,BOTTOM=6,LEFT=7,RIGHT=8,CENTER=9,CT_CONTROL=1,CT_LABEL=2,CT_TEXTURE=3,CT_EDITBOX=4,DT_HIGH=5,DL_OVERLAY=6,TEXT_ALIGN_RIGHT=1,TEXT_ALIGN_LEFT=0,SI_ABILITY_NAME=1,CSA_CATEGORY_LARGE_TEXT=1,CENTER_SCREEN_ANNOUNCE_TYPE_SYSTEM_BROADCAST=1,ENDLESS_DUNGEON_BUFF_TYPE_VISION=1,EVENT_GAMEPAD_PREFERRED_MODE_CHANGED=1,EVENT_PLAYER_ACTIVATED=2,EVENT_ENDLESS_DUNGEON_STARTED=3,EVENT_ENDLESS_DUNGEON_INITIALIZED=4,EVENT_ENDLESS_DUNGEON_COMPLETED=5,EVENT_SCREEN_RESIZED=6,EVENT_INTERFACE_SETTING_CHANGED=7,ENDLESS_DUNGEON_BUFF_BUCKET_TYPE_ITERATION_BEGIN=0,ENDLESS_DUNGEON_BUFF_BUCKET_TYPE_ITERATION_END=2,SLASH_COMMANDS={},events={},updates={},later={},messages={}}
 local methods={}
 function api.control(name,parent)
  return setmetatable({name=name,parent=parent,width=140,height=140,scale=1,hidden=false,handlers={},children={}}, {__index=methods})
 end
 function methods:SetHidden(v)self.hidden=v end;function methods:IsHidden()return self.hidden end
 function methods:BringWindowToTop()self.raised=true end
 function methods:SetWidth(v)self.width=v end;function methods:SetHeight(v)self.height=v end
 function methods:SetDimensions(w,h)self.width=w;self.height=h end
 function methods:SetDimensionConstraints(...)self.constraints={...}end
 function methods:GetWidth()return self.width end;function methods:GetHeight()return self.height end
 function methods:GetDimensions()return self.width,self.height end
 function methods:GetScale()return self.scale end
 function methods:SetText(v)self.text=v end;function methods:GetText()return self.text or '' end
 function methods:GetTextWidth()return #self:GetText()*9 end
 function methods:GetTextHeight()return math.max(20,math.ceil(#self:GetText()/math.max(1,(self.width or 300)/9))*20)end
 function methods:GetLeft()return self.left or 200 end;function methods:GetRight()return self:GetLeft()+self.width end
 function methods:GetTop()return self.top or 300 end;function methods:GetBottom()return self:GetTop()+self.height end
 function methods:SetHandler(k,v)self.handlers[k]=v end
 function methods:SetAnchor(...)self.anchor={...};self.anchors=self.anchors or {};self.anchors[#self.anchors+1]=self.anchor end;function methods:ClearAnchors()self.anchor=nil;self.anchors={}end
 function methods:SetParent(p)self.parent=p end
 function methods:GetOwningWindow()
  local c=self;while c do if c.topLevel then return c end;c=c.parent end
 end
 function methods:SetAnchorFill()self.fill=true end;function methods:SetMouseEnabled(v)self.mouse=v end
 function methods:SetExcludeFromResizeToFitExtents(v)self.exclude=v end
 function methods:SetResizeToFitDescendents(v)self.resize=v end
 function methods:SetTexture(v)self.texture=v end;function methods:SetColor(...)self.color={...}end
 function methods:SetTextureCoords(...)self.textureCoords={...}end
 function methods:SetDrawTier(v)self.tier=v end;function methods:SetDrawLayer(v)self.layer=v end;function methods:SetDrawLevel(v)self.level=v end
 function methods:SetFont(v)self.font=v end;function methods:SetHorizontalAlignment(v)self.align=v end
 function methods:SetMaxInputChars(v)self.maxChars=v end;function methods:SetEditEnabled(v)self.editEnabled=v end
 function methods:TakeFocus()self.focus=true end;function methods:LoseFocus()self.focus=false end
 function methods:GetNamedChild(k)if not self.children[k]then self.children[k]=api.control(k,self)end;return self.children[k]end
 local backdropChildren={}
 api.WINDOW_MANAGER={CreateControl=function(_,n,p)return api.control(n,p)end,CreateTopLevelWindow=function(_,n)local c=api.control(n);c.topLevel=true;return c end,CreateControlFromVirtual=function(_,n,p,template)
  local c=api.control(n,p);c.template=template
  if template=='ZO_DefaultBackdrop'then
   local childName=(n or '')..'MungeOverlay';assert(not backdropChildren[childName],'Control already exists: '..childName)
   local child=api.control(childName,c);backdropChildren[childName]=child;c.children.MungeOverlay=child
  elseif template=='ZO_ComboBoxDropdown_Keyboard_Template'then
   assert(p==api.GuiRoot,'TopLevelControl must be parented to GuiRoot');c.topLevel=true;c.hidden=true;c.object={control=c}
  end
  return c
 end,BringWindowToTop=function(_,c)c.raised=true end}
 api.GuiRoot=api.control('GuiRoot');api.GuiRoot.width=1920;api.GuiRoot.height=1080
 api.LibAddonMenu2={}
 function api.LibAddonMenu2:RegisterAddonPanel(id,data)
  api.settingsPanel={id=id,data=data};return api.settingsPanel
 end
 function api.LibAddonMenu2:RegisterOptionControls(id,options)
  assert(api.settingsPanel.id==id)
  api.settingsOptions=options
  for _,data in ipairs(options)do
   if data.reference then
    local control={data=data}
    function control:UpdateValue()
     if data.type=='description' then self.text=data.text()
     elseif data.type=='editbox' then self.editbox:SetText(data.getFunc())
     elseif data.type=='dropdown' then self.value=data.getFunc() end
    end
    function control:UpdateChoices(choices,values)
     self.choices={};self.values={}
     for i=1,#choices do self.choices[i]=choices[i];self.values[i]=values[i]end
    end
    function control:UpdateDisabled()self.disabled=data.disabled()end
    if data.type=='editbox' then control.editbox=api.control('ProfileName') end
    api[data.reference]=control
    if data.type=='dropdown' then control:UpdateChoices(data.choices,data.choicesValues)end
    control:UpdateValue()
   end
  end
 end
 api.ENDLESS_DUNGEON_BUFF_TYPE_VERSE=0
 api.ZO_COMBOBOX_SUPPRESS_UPDATE=2
 api.GetTimeString=function()return '12:34:56'end;api.GetDateStringFromTimestamp=function()return '15.10.2026'end
 api.ZO_ComboBox_ObjectFromContainer=function(control)
  if control.combo then return control.combo end
  local combo={items={},container=control,scrollable=true}
  function combo:SetSortsItems(v)self.sorts=v end
  function combo:SetHeight(v)self.height=v end
  function combo:SetDropdownObject(v)self.dropdown=v end
  function combo:SetEnabled(v)self.enabled=v end
  function combo:SetSelectedItemText(v)self.selectedText=v end
  function combo:UpdateItems()end
  function combo:ClearItems()self.items={}end
  function combo:CreateItemEntry(name,callback)return {name=name,callback=callback}end
  function combo:AddItem(item)self.items[#self.items+1]=item end
  function combo:GetItems()return self.items end
  function combo:SelectItem(item,ignore)
   self.selected=item;if not ignore then item.callback(self,item.name,item)end
  end
  function combo:HideDropdown()self.dropdownHidden=true;if self.dropdown then self.dropdown.control:SetHidden(true)end end
  control.combo=combo;return combo
 end
 api.zo_strformat=function(_,s)return s end;api.GetAbilityName=function(id)return 'Ability '..id end
 api.zo_callLater=function(fn)api.later[#api.later+1]=fn end
 api.d=function(s)api.messages[#api.messages+1]=s end
 api.ZO_Scroll_OnMouseWheel=function(c,delta)c.delta=delta end
 api.ZO_CheckButton_SetChecked=function(c)c.checked=true end
 api.ZO_CheckButton_SetCheckState=function(c,v)c.checked=v end
 api.ZO_CheckButton_SetToggleFunction=function(c,f)c.toggleFunction=f end
 api.ZO_CheckButton_OnClicked=function(c)c.checked=not c.checked;if c.toggleFunction then c:toggleFunction(c.checked)end end
 api.ZO_CheckButton_SetLabelText=function(c,v)
  c.label=api.control('Label',c);c.label:SetText(v);c.label:SetMouseEnabled(true)
  c.label:SetHandler('OnMouseUp',function(_,_,upInside)if upInside then api.ZO_CheckButton_OnClicked(c)end end)
 end
 api.ZO_ScrollList_Commit=function()end
 api.CENTER_SCREEN_ANNOUNCE={CreateMessageParams=function()return {SetText=function(self,a,b)self.title=a;self.sub=b end,SetLifespanMS=function(self,v)self.life=v end,SetCSAType=function()end}end,AddMessageWithParams=function(_,p)api.announcement=p end}
 api.EVENT_MANAGER={RegisterForEvent=function(_,_,event,fn)api.events[event]=fn end,UnregisterForEvent=function()end,RegisterForUpdate=function(_,name,_,fn)api.updates[name]=fn end,UnregisterForUpdate=function(_,name)api.updates[name]=nil end}
 api.SecurePostHook=function(obj,name,fn)local original=obj[name]or function()end;obj[name]=function(self,...)local r=original(self,...);fn(self,...);return r end end
 api.ZO_PreHook=function(obj,name,fn)local original=obj[name]or function()end;obj[name]=function(self,...)if fn(self,...)then return end;return original(self,...)end end
 api.IsInGamepadPreferredMode=function()return api.gamepad or false end;api.IsInstanceEndlessDungeon=function()return api.inside or false end;api.IsEndlessDungeonStarted=function()return api.started or false end
 api.GetTimeStamp=function()return 1000 end;api.GetFrameTimeSeconds=function()return 100 end;api.GetGameTimeMilliseconds=function()return 100000 end
 api.GetEndlessDungeonBuffSelectorBucketTypeChoice=function(bucket)return ({1,2,0})[bucket+1]end
 api.GetAbilityEndlessDungeonBuffType=function()return 0 end
 api.ENDLESS_DUNGEON_MANAGER={callbacks={},visions={},RegisterCallback=function(self,k,v)self.callbacks[k]=v end,GetAbilityStackCountTable=function(self,t)return t==1 and self.visions or {}end,GetProgression=function()return 1,1,1 end}
 local selector={control=api.control('Selector'),buffControls={api.control('Buff1'),api.control('Buff2')},isRerolling=false}
 selector.IsShowing=function(self)return not self.control:IsHidden()end
 for i,b in ipairs(selector.buffControls)do b.abilityId=i;b.buffType=0;b.bucketType=i-1;b.iconTexture=b:GetNamedChild('Icon')end
 selector.CommitChoice=function(self)self.commits=(self.commits or 0)+1 end
 api.ENDLESS_DUNGEON_BUFF_SELECTOR_KEYBOARD=selector
 return api
end
return S
