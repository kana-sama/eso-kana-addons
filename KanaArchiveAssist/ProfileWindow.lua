local K=KanaArchiveAssist;local W={};K.ProfileWindow=W
local unpack=unpack or table.unpack
local normal={.87,.85,.79,1};local quiet={.69,.68,.61,1};local gold={.84,.79,.55,1};local red={.95,.55,.45,1}
local reasons={
 timeout='Подтверждение не пришло за 30 секунд. Запись не добавлена.',
 invalid_offer='Не удалось распознать предложение способностей.',
 offer_missing='Предложение не было захвачено до подтверждения выбора.',
 invalid_selection='Выбранная способность отсутствует в захваченном предложении.',
 mismatched_result='Ответ игры не совпал с выбранной способностью или её стаками.',
 restored_result='Игра сообщила восстановление эффектов, а не новый выбор.',
 offer_replaced='Новое предложение появилось до подтверждения предыдущего.',
 interrupted='Подтверждение прервано сменой режима или выходом.',
 history_rejected='Запись не прошла проверку истории.',
}
local states={
 idle={'Ожидает нового выбора','История обновляется после подтверждения игры.'},
 offered={'Предложение получено','Выбери способность. История обновится после ответа игры.'},
 excluded_offer={'Этот выбор не учитывается','На экране выбора снята галочка «учитывать выбор».'},
 pending={'Ожидает подтверждения игры','Новый выбор ещё не добавлен в историю.'},
 recorded={'Последний выбор учтён','История обновлена. Ожидаю нового выбора.'},
 excluded={'Последний выбор исключён','Выбор пропущен по снятой галочке. Следующий учитывается автоматически.'},
 failed={'Выбор не удалось учесть','Запись не добавлена в историю.'},
 gamepad={'Учёт недоступен в режиме геймпада','Используй клавиатуру и мышь для записи новых выборов.'},
 inactive={'Просмотр профиля','Новые выборы учитываются в активном профиле.'},
}
function W.New(api,profiles,onChange,stateProvider)
 return setmetatable({api=api,profiles=profiles,onChange=onChange,stateProvider=stateProvider,mode='view',entries={}},{__index=W})
end
function W:Close()
 self.name:LoseFocus();self.combo:HideDropdown()
 if self.api.SCENE_MANAGER then self.api.SCENE_MANAGER:HideTopLevel(self.root)else self.root:SetHidden(true)end
end
function W:Build()
 local a=self.api;local wm=a.WINDOW_MANAGER
 self.root=wm:CreateTopLevelWindow('KanaArchiveAssistProfiles');self.root:SetAnchor(a.CENTER,a.GuiRoot,a.CENTER);self.root:SetMouseEnabled(true);self.root:SetDrawTier(a.DT_HIGH)
 local bg=wm:CreateControlFromVirtual('KanaArchiveAssistProfilesBackdrop',self.root,'ZO_DefaultBackdrop');bg:SetAnchorFill()
 self.title=K.View.Label(a,self.root,'KanaArchiveAssist','ZoFontWinH2');self.title:SetAnchor(a.TOPLEFT,self.root,a.TOPLEFT,24,18)
 self.subtitle=K.View.Label(a,self.root,'Профили и история','ZoFontGameSmall');self.subtitle:SetAnchor(a.TOPLEFT,self.root,a.TOPLEFT,24,54);self.subtitle:SetColor(unpack(quiet))
 self.closeButton=wm:CreateControlFromVirtual(nil,self.root,'ZO_CloseButton');self.closeButton:ClearAnchors();self.closeButton:SetAnchor(a.TOPRIGHT,self.root,a.TOPRIGHT,-16,16);self.closeButton:SetHandler('OnClicked',function()self:Close()end)
 self.scroll=wm:CreateControlFromVirtual('KanaArchiveAssistProfileScroll',self.root,'ZO_ScrollContainer')
 self.viewport=self.scroll:GetNamedChild('Scroll');self.child=self.viewport:GetNamedChild('Child');self.child:SetResizeToFitDescendents(false)
 self.scroll:SetHandler('OnMouseWheel',function(_,delta)a.ZO_Scroll_OnMouseWheel(self.scroll,delta)end)
 local function label(parent,text,font)return K.View.Label(a,parent,text,font)end
 local function button(parent,text,fn)
  local b=wm:CreateControlFromVirtual(nil,parent,'ZO_DefaultTextButton');b:SetText(text);b:SetHeight(30);b:SetHandler('OnClicked',fn);return b
 end
 self.profileBlock=wm:CreateControl(nil,self.child,a.CT_CONTROL)
 self.profileLabel=label(self.profileBlock,'Профиль','ZoFontGameSmall')
 self.picker=wm:CreateControlFromVirtual('KanaArchiveAssistProfilePicker',self.profileBlock,'ZO_ComboBox');self.picker:SetHeight(34)
 self.combo=a.ZO_ComboBox_ObjectFromContainer(self.picker);self.combo:SetSortsItems(false)
 self.dropdown=wm:CreateControlFromVirtual('KanaArchiveAssistProfileOptions',a.GuiRoot,'ZO_ComboBoxDropdown_Keyboard_Template');self.combo:SetDropdownObject(self.dropdown.object)
 self.newProfile=button(self.profileBlock,'+ Новый',function()self:BeginEdit('create')end)
 self.renameButton=button(self.profileBlock,'Переименовать',function()self:BeginEdit('rename')end)
 self.active=label(self.profileBlock,'','ZoFontGameSmall');self.active:SetColor(unpack(gold))
 self.view=wm:CreateControl(nil,self.child,a.CT_CONTROL)
 self.total=label(self.view,'0','ZoFontWinH1');self.total:SetColor(1,.97,.90,1)
 self.totalCaption=label(self.view,'Учтено выборов','ZoFontGameBold')
 self.runCount=label(self.view,'','ZoFontGameSmall');self.runCount:SetHorizontalAlignment(a.TEXT_ALIGN_RIGHT)
 self.counts=label(self.view,'','ZoFontGameSmall')
 self.lastCaption=label(self.view,'Последний учтённый выбор','ZoFontGameSmall');self.lastCaption:SetColor(unpack(gold))
 self.lastIcon=wm:CreateControl(nil,self.view,a.CT_TEXTURE);self.lastIcon:SetDimensions(20,20);self.lastIcon:SetTexture('EsoUI/Art/Miscellaneous/check_icon_32.dds');self.lastIcon:SetColor(.65,.80,.50,1)
 self.lastName=label(self.view,'','ZoFontWinH3');self.lastName:SetColor(1,.97,.90,1)
 self.lastIndex=label(self.view,'','ZoFontGameSmall');self.lastIndex:SetHorizontalAlignment(a.TEXT_ALIGN_RIGHT)
 self.lastContext=label(self.view,'','ZoFontGameSmall');self.lastTime=label(self.view,'','ZoFontGameSmall');self.lastTime:SetColor(unpack(quiet))
 self.status=label(self.view,'','ZoFontWinH3');self.statusDetails=label(self.view,'','ZoFontGameSmall');self.statusDetails:SetColor(unpack(quiet))
 self.dividers={}
 for i=1,3 do local d=wm:CreateControl(nil,self.view,a.CT_TEXTURE);d:SetTexture('EsoUI/Art/CharacterWindow/characterWindow_leftSide_divider.dds');d:SetHeight(2);self.dividers[i]=d end
 self.form=wm:CreateControl(nil,self.child,a.CT_CONTROL)
 self.nameLabel=label(self.form,'Название профиля','ZoFontGame')
 self.editBg=wm:CreateControlFromVirtual(nil,self.form,'ZO_EditBackdrop');self.editBg:SetHeight(36)
 self.name=wm:CreateControlFromVirtual('KanaArchiveAssistProfileName',self.editBg,'ZO_DefaultEditForBackdrop');self.name:SetAnchorFill();self.name:SetMaxInputChars(80)
 self.name:SetHandler('OnEnter',function()self:SaveEdit()end)
 self.formHint=label(self.form,'','ZoFontGame');self.formHint:SetColor(unpack(quiet))
 self.error=label(self.form,'','ZoFontGameSmall');self.error:SetColor(unpack(red))
 self.useButton=button(self.root,'Использовать профиль',function()self:Use()end)
 self.saveButton=button(self.root,'Сохранить имя',function()self:SaveEdit()end)
 self.cancelButton=button(self.root,'Отмена',function()self:CancelEdit()end)
 self.actions={self.useButton,self.saveButton,self.cancelButton}
 self.root:SetHandler('OnKeyDown',function(_,key)if key==(a.KEY_ESCAPE or 27)then self:Close()end end)
 self.root:SetHandler('OnHide',function()self.combo:HideDropdown();self.name:LoseFocus()end)
 self.root:SetHandler('OnUpdate',function()
  if self.screenWidth~=a.GuiRoot:GetWidth()or self.screenHeight~=a.GuiRoot:GetHeight()or self.scale~=self.root:GetScale()then self:Layout()end
 end)
 if a.SCENE_MANAGER then a.SCENE_MANAGER:RegisterTopLevel(self.root,true)end
 self.root:SetHidden(true)
end
function W:Layout()
 local a=self.api;self.scale=self.root:GetScale();self.screenWidth=a.GuiRoot:GetWidth();self.screenHeight=a.GuiRoot:GetHeight()
 local width=math.max(320,math.min(600,self.screenWidth/self.scale-40));local content=width-72;local compact=width<520
 local editing=self.mode~='view';local inactive=self.selected~=self.profiles:GetActive().id
 local footer=editing and (compact and 96 or 60)or (inactive and 60 or 24)
 local function place(c,parent,x,y,w)
  c:ClearAnchors();c:SetAnchor(a.TOPLEFT,parent,a.TOPLEFT,x,y);if w then c:SetWidth(w)end
 end
 local function right(c,parent,y,w)
  c:ClearAnchors();c:SetAnchor(a.TOPRIGHT,parent,a.TOPRIGHT,0,y);c:SetWidth(w)
 end
 self.root:SetWidth(width);self.title:SetWidth(width-80);self.subtitle:SetWidth(width-48);self.child:SetWidth(content)
 self.profileBlock:SetHidden(editing);self.view:SetHidden(editing);self.form:SetHidden(not editing)
 self.useButton:SetHidden(editing or not inactive);self.saveButton:SetHidden(not editing);self.cancelButton:SetHidden(not editing)
 place(self.profileBlock,self.child,0,0,content);place(self.profileLabel,self.profileBlock,0,0,content)
 place(self.picker,self.profileBlock,0,26,content-120);right(self.newProfile,self.profileBlock,28,110)
 place(self.active,self.profileBlock,0,70,compact and content or content-166)
 local y=70+math.max(26,self.active:GetTextHeight())
 right(self.renameButton,self.profileBlock,compact and y+6 or 68,154);if compact then y=y+36 end
 self.profileBlock:SetHeight(y+14)
 place(self.view,self.child,0,self.profileBlock:GetHeight(),content)
 local function divider(index,at)
  local d=self.dividers[index];place(d,self.view,0,at,content);return at+18
 end
 y=divider(1,0);place(self.total,self.view,0,y,64);place(self.totalCaption,self.view,74,y+10,content-74-(compact and 0 or 154))
 right(self.runCount,self.view,compact and y+math.max(self.total:GetTextHeight(),self.totalCaption:GetTextHeight()+10)+8 or y+12,compact and content or 148)
 y=y+math.max(self.total:GetTextHeight(),self.totalCaption:GetTextHeight()+10)+10
 if compact then y=y+self.runCount:GetTextHeight()+8 end
 place(self.counts,self.view,0,y,content);y=y+self.counts:GetTextHeight()+16
 y=divider(2,y);place(self.lastCaption,self.view,0,y,content);y=y+self.lastCaption:GetTextHeight()+10
 place(self.lastIcon,self.view,0,y+3)
 place(self.lastName,self.view,28,y,content-28-(compact and 0 or 122))
 right(self.lastIndex,self.view,compact and y+self.lastName:GetTextHeight()+6 or y+2,compact and content or 114)
 y=y+self.lastName:GetTextHeight()+8;if compact then y=y+self.lastIndex:GetTextHeight()+6 end
 place(self.lastContext,self.view,28,y,content-28);y=y+self.lastContext:GetTextHeight()+8
 place(self.lastTime,self.view,28,y,content-28);y=y+self.lastTime:GetTextHeight()+16
 y=divider(3,y);place(self.status,self.view,0,y,content);y=y+self.status:GetTextHeight()+8
 place(self.statusDetails,self.view,0,y,content);y=y+self.statusDetails:GetTextHeight()+4;self.view:SetHeight(y)
 local body=self.profileBlock:GetHeight()+y
 place(self.form,self.child,0,0,content);place(self.nameLabel,self.form,0,0,content)
 local editY=self.nameLabel:GetTextHeight()+10;place(self.editBg,self.form,0,editY,content)
 place(self.formHint,self.form,0,editY+52,content);local errorY=editY+52+self.formHint:GetTextHeight()+14
 place(self.error,self.form,0,errorY,content);self.form:SetHeight(errorY+self.error:GetTextHeight()+8)
 if editing then body=self.form:GetHeight()end
 local height=math.min(math.max(360,84+body+footer),math.max(360,self.screenHeight/self.scale-60))
 self.root:SetHeight(height);self.scroll:ClearAnchors();self.scroll:SetAnchor(a.TOPLEFT,self.root,a.TOPLEFT,24,84);self.scroll:SetAnchor(a.BOTTOMRIGHT,self.root,a.BOTTOMRIGHT,-24,-footer)
 self.viewport:SetHeight(math.max(36,height-84-footer));self.child:SetHeight(body)
 self.combo:SetHeight(math.max(75,math.min(250,self.screenHeight/self.scale-200)))
 self.dropdown:SetDimensionConstraints(self.picker:GetWidth(),0,content,math.max(75,self.screenHeight/self.scale-48))
 self.useButton:ClearAnchors();self.useButton:SetAnchor(a.BOTTOMRIGHT,self.root,a.BOTTOMRIGHT,-24,-18);self.useButton:SetWidth(math.min(300,width-48))
 for i,b in ipairs({self.saveButton,self.cancelButton})do
  b:ClearAnchors();b:SetWidth(compact and width-48 or (i==1 and width-180 or 120))
  b:SetAnchor(a.BOTTOMRIGHT,self.root,a.BOTTOMRIGHT,i==1 and (compact and -24 or -156)or -24,compact and (i==1 and -56 or -18)or -18)
 end
end
function W:ReadState()
 if self.stateProvider then return self.stateProvider(self.selected)end
 local p=self.profiles.world.profiles[self.selected];local run=self.profiles.character.run
 return {summary=K.History.New(p):GetSummary(run and not run.ended and run.id or nil),flow=p.activity or {state='idle'},active=p.id==self.profiles:GetActive().id}
end
function W:RefreshState(force)
 if not self.root or (self.root:IsHidden()and not force)then return end
 local a=self.api;local state=self:ReadState();local s=state.summary;local active=self.profiles:GetActive()
 self.active:SetText(state.active and 'Активен на этом персонаже' or 'Активен: '..active.name)
 self.total:SetText(tostring(s.total));self.runCount:SetText('+'..s.currentRun..' в этом ране')
 local v=s.byType[a.ENDLESS_DUNGEON_BUFF_TYPE_VERSE]or 0;local n=s.byType[a.ENDLESS_DUNGEON_BUFF_TYPE_VISION]or 0
 self.counts:SetText(v..' '..K.View.Plural(v,'строфа','строфы','строф')..'  ·  '..n..' '..K.View.Plural(n,'видение','видения','видений')..'  ·  '..s.runs..' '..K.View.Plural(s.runs,'ран','рана','ранов')..' с данными')
 local last=s.last;self.lastIcon:SetHidden(not last)
 if last then
  self.lastName:SetText(a.zo_strformat(a.SI_ABILITY_NAME,a.GetAbilityName(last.selectedId)));self.lastIndex:SetText('Запись № '..s.total)
  local parts={last.buffType==a.ENDLESS_DUNGEON_BUFF_TYPE_VISION and 'Видение' or 'Строфа'};local c=last.context
  local progression={};if c.arc then progression[#progression+1]='Арка '..c.arc end
  if c.cycle then progression[#progression+1]='цикл '..c.cycle end;if c.stage then progression[#progression+1]='этап '..c.stage end
  if #progression>0 then parts[#parts+1]=table.concat(progression,', ')end
  self.lastContext:SetText(table.concat(parts,'  ·  '))
  self.lastTime:SetText(last.recordedTime and ('Учтён: '..(last.recordedDate or '')..' '..last.recordedTime)or 'Для ранних записей время учёта не фиксировалось.')
 else
  self.lastName:SetText('Истории пока нет');self.lastIndex:SetText('');self.lastContext:SetText('Первый учтённый выбор начнёт обучение.');self.lastTime:SetText('')
 end
 local flow=state.flow or {state='idle'};local key=flow.state
 if not state.active and key~='pending'and key~='failed'then key='inactive'end
 local text=states[key]or states.idle;self.status:SetText(text[1]);local detail=key=='failed'and (reasons[flow.reason]or text[2])or text[2]
 if state.activity and state.activity.state=='failed'and key~='failed'then detail=detail..'\nПредыдущий выбор не учтён: '..(reasons[state.activity.reason]or states.failed[2])end
 if s.unavailable then self.status:SetText('История недоступна для обучения');detail='Профиль использует более новый формат. Его данные сохранены.'end
 self.statusDetails:SetText(detail);self.status:SetColor(unpack((key=='failed'or s.unavailable)and red or normal))
 self:Layout()
end
function W:Refresh()
 local active=self.profiles:GetActive();self.combo:ClearItems();self.entries={}
 for _,p in ipairs(self.profiles:List())do
  local entry=self.combo:CreateItemEntry(p.name..(p.id==active.id and ' · активен' or ''),function(_,_,item)self:Select(item.profileId)end)
  entry.profileId=p.id;self.entries[p.id]=entry;self.combo:AddItem(entry,self.api.ZO_COMBOBOX_SUPPRESS_UPDATE)
 end
 self.combo:UpdateItems();self:Select(self.selected or active.id)
end
function W:Select(id)
 local p=self.profiles.world.profiles[id];if not p then return end
 self.selected=id;self.combo:SelectItem(self.entries[id],true);self.combo:SetSelectedItemText(p.name);self:RefreshState(true)
end
function W:BeginEdit(mode)
 self.mode=mode;self.combo:HideDropdown();self.error:SetText('')
 self.subtitle:SetText(mode=='create'and 'Новый профиль' or 'Переименование профиля')
 self.name:SetText(mode=='create'and ''or self.profiles.world.profiles[self.selected].name)
 self.formHint:SetText(mode=='create'and 'Начнётся с пустой истории. После создания профиль станет активным.'or 'Накопленная история и предпочтения сохранятся.')
 self.saveButton:SetText(mode=='create'and 'Создать и использовать' or 'Сохранить имя');self:Layout();self.name:TakeFocus()
end
function W:CancelEdit()
 self.mode='view';self.name:LoseFocus();self.error:SetText('');self.subtitle:SetText('Профили и история');self:RefreshState(true)
end
function W:SaveEdit()
 local result,err
 if self.mode=='create'then result,err=self.profiles:Create(self.name:GetText())
 elseif self.mode=='rename'then result,err=self.profiles:Rename(self.selected,self.name:GetText())else return end
 if not result then self.error:SetText(err or 'Не удалось изменить профиль.');self:Layout();return end
 self.selected=result.id;self:CancelEdit();self:Refresh();self.onChange()
end
function W:Use()
 local result=self.profiles:Use(self.selected);if result then self:Refresh();self.onChange()end
end
function W:Open()
 if self.root and not self.root:IsHidden()then self.root:BringWindowToTop();return end
 if not self.root then self:Build()end
 self.mode='view';self.selected=self.profiles:GetActive().id;self.subtitle:SetText('Профили и история');self.error:SetText('');self:Refresh()
 if self.api.SCENE_MANAGER then self.api.SCENE_MANAGER:ShowTopLevel(self.root)else self.root:SetHidden(false)end
 self.root:BringWindowToTop()
end
