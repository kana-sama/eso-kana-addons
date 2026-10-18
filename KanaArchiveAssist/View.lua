local K=KanaArchiveAssist
local V={};K.View=V
local colors={positive={.557,.796,.529,1},negative={.882,.541,.494,1},neutral={.875,.769,.435,1}}
local unpack=unpack or table.unpack
function V.MarkerLayout(grade)
 local out={};local n=math.max(1,math.abs(grade));local height=grade==0 and 3 or 11+(n-1)*7
 for i=1,n do out[i]={width=24,y=(32-height)/2+(i-1)*7,height=grade==0 and 3 or 11}end;return out
end
function V.Plural(n,one,few,many)
 local a,b=n%10,n%100;if a==1 and b~=11 then return one elseif a>=2 and a<=4 and (b<12 or b>14)then return few else return many end
end
local function label(api,parent,text,font)
 local c=api.WINDOW_MANAGER:CreateControl(nil,parent,api.CT_LABEL);c:SetFont(font or 'ZoFontGame');c:SetText(text or '');c:SetColor(.87,.85,.79,1);return c
end
V.Label=label
function V.New(api)
 return setmetatable({api=api,marks={},generation=0},{__index=V})
end
function V:HideTooltip()
 self.generation=self.generation+1;if self.tooltip then self.tooltip:SetHidden(true)end
end
function V:Hide()
 self:HideTooltip();for _,mark in pairs(self.marks)do mark:SetHidden(true);mark:SetMouseEnabled(false)end
 self.selector=nil
end
function V:CreateMark(buff)
 local a=self.api;local mark=a.WINDOW_MANAGER:CreateControl(nil,buff,a.CT_CONTROL)
 mark:SetDimensions(32,32);mark:SetDrawTier(a.DT_HIGH);mark:SetDrawLayer(a.DL_OVERLAY);mark:SetDrawLevel(8)
 mark:SetExcludeFromResizeToFitExtents(true);mark.textures={}
 for i=1,3 do local t=a.WINDOW_MANAGER:CreateControl(nil,mark,a.CT_TEXTURE);t:SetMouseEnabled(false);t:SetDrawLayer(a.DL_OVERLAY);t:SetDrawLevel(8);mark.textures[i]=t end
 mark:SetHandler('OnMouseEnter',function()
  self:HideTooltip();local token=self.generation
  a.zo_callLater(function()if token==self.generation and not mark:IsHidden()and mark.stats then self:ShowTooltip(mark)end end,150)
 end)
 mark:SetHandler('OnMouseExit',function()self:HideTooltip()end)
 self.marks[buff]=mark;return mark
end
function V:Show(selector,offer,prediction,profileName,stats)
 self:Hide();self.selector,self.offer,self.profileName,self.stats=selector,offer,profileName,stats
 for _,buff in ipairs(selector.buffControls or {})do
  local item=prediction.byId[buff.abilityId];local grade=item and item.grade
  if grade~=nil then
   local mark=self.marks[buff]or self:CreateMark(buff);mark.grade=grade;mark.stats=stats and stats.byId[buff.abilityId];mark.abilityId=buff.abilityId
   mark:SetHidden(false);mark:SetMouseEnabled(mark.stats~=nil and mark.stats.total>0)
   local color=grade>0 and colors.positive or grade<0 and colors.negative or colors.neutral
   local layout=V.MarkerLayout(grade)
   for i,t in ipairs(mark.textures)do
    t:SetHidden(not layout[i])
    if layout[i]then
     t:ClearAnchors();t:SetAnchor(self.api.TOP,mark,self.api.TOP,0,layout[i].y)
     t:SetDimensions(grade==0 and 24 or 27,layout[i].height)
     t:SetTexture('eso-kana-addons/KanaArchiveAssist/Textures/'..(grade==0 and 'equal' or grade>0 and 'chevron-up' or 'chevron-down')..'.dds')
     t:SetTextureCoords(0,(grade==0 and 24 or 27)/32,0,layout[i].height/16);t:SetColor(unpack(color))
    end
   end
  end
 end
 self:Layout()
end
function V:Layout()
 local a=self.api
 for buff,mark in pairs(self.marks)do
  if not mark:IsHidden()then local icon=buff.iconTexture or buff:GetNamedChild('Icon');mark:ClearAnchors();mark:SetAnchor(a.LEFT,icon,a.RIGHT,6,0)end
 end
 self:HideTooltip()
end
function V:ShowTooltip(mark)
 local a=self.api;local stats=mark.stats;if not stats then return end
 local name=function(id)return a.zo_strformat(a.SI_ABILITY_NAME,a.GetAbilityName(id))end
 if not self.tooltip then
  self.tooltip=a.WINDOW_MANAGER:CreateTopLevelWindow('KanaArchiveAssistTooltip');self.tooltip:SetDrawTier(a.DT_HIGH);self.tooltip:SetDrawLevel(20);self.tooltip:SetMouseEnabled(false)
  local bg=a.WINDOW_MANAGER:CreateControlFromVirtual('KanaArchiveAssistTooltipBackdrop',self.tooltip,'ZO_DefaultBackdrop');bg:SetAnchorFill();self.tipChildren={}
 end
 local tip=self.tooltip
 for _,c in ipairs(self.tipChildren)do c:SetHidden(true)end
 local used=0
 local width=math.min(380,a.GuiRoot:GetWidth()-32);tip:SetWidth(width)
 local function tipLabel(text,font)
  used=used+1;local c=self.tipChildren[used]
  if not c then c=label(a,tip,text,font);self.tipChildren[used]=c end
  c:ClearAnchors();c:SetHidden(false);c:SetText(text);c:SetFont(font);c:SetColor(.87,.85,.79,1);c:SetWidth(width-36);c:SetHorizontalAlignment(a.TEXT_ALIGN_LEFT);return c
 end
 local function line(text,font,y,color)
  local c=tipLabel(text,font);c:SetAnchor(a.TOPLEFT,tip,a.TOPLEFT,18,y);c:SetWidth(width-36);if color then c:SetColor(unpack(color))end
  return c
 end
 local y=16
 y=y+line(name(mark.abilityId),'ZoFontWinH3',y,{1,.96,.86,1}):GetTextHeight()+4
 if stats.archiveOnly then
  y=y+line('Архивная статистика: нет выборов в текущем окне обучения.','ZoFontGameSmall',y,{.78,.71,.53,1}):GetTextHeight()+8
 elseif stats.preliminary then
  y=y+line('Предварительная оценка','ZoFontGameSmall',y,{.78,.71,.53,1}):GetTextHeight()+8
 end
 local function fact(title,value)
  local c=line(title,'ZoFontGame',y);c:SetWidth((width-44)*.48)
  local valueLabel=tipLabel(value,'ZoFontGame');valueLabel:SetAnchor(a.TOPRIGHT,tip,a.TOPRIGHT,-18,y);valueLabel:SetWidth((width-44)*.52);valueLabel:SetHorizontalAlignment(a.TEXT_ALIGN_RIGHT)
  y=y+math.max(c:GetTextHeight(),valueLabel:GetTextHeight())+6
 end
 fact('Выбран',stats.selected..' из '..stats.total..' · '..math.floor(stats.selected/stats.total*100+.5)..'%')
 fact('Разные забеги',tostring(stats.runs))
 if not stats.archiveOnly and self.stats.knownOptions==1 then
  y=y+8+line('Другие варианты без истории текущей модели. Метка показывает общую склонность к этому перку.','ZoFontGameSmall',y+8,{.69,.69,.64,1}):GetTextHeight()
 elseif not stats.archiveOnly and self.stats.knownOptions<self.stats.optionCount then
  y=y+8+line('Сравнение изученных вариантов: '..self.stats.knownOptions..' из '..self.stats.optionCount..'.','ZoFontGameSmall',y+8,{.69,.69,.64,1}):GetTextHeight()
 end
 local paired=false
 for _,id in ipairs(self.offer.options)do if id~=mark.abilityId and stats.pairs[id]then paired=true end end
 if paired then
  y=y+12;y=y+line('Прямые встречи','ZoFontWinH4',y):GetTextHeight()+6
  for _,id in ipairs(self.offer.options)do
   local p=stats.pairs[id]
   if id~=mark.abilityId and p then
    local title=line(name(id),'ZoFontGame',y);title:SetWidth(width-130)
    local value=tipLabel(p.chosen..' : '..p.otherChosen,'ZoFontGame');value:SetAnchor(a.TOPRIGHT,tip,a.TOPRIGHT,-18,y);value:SetWidth(80);value:SetHorizontalAlignment(a.TEXT_ALIGN_RIGHT)
    y=y+math.max(title:GetTextHeight(),value:GetTextHeight())+6
   end
  end
  y=y+line('Выбор этого перка : выбор соперника. Выбор третьего не учитывается.','ZoFontGameSmall',y,{.65,.65,.61,1}):GetTextHeight()+6
 end
 y=y+10
 if stats.currentVisions>0 then
  y=y+line('Видения встречались с этим перком с таким или большим числом стаков: '..stats.knownStacks..' из '..stats.currentVisions..'.','ZoFontGameSmall',y,{.69,.69,.64,1}):GetTextHeight()+8
 end
 if self.stats.exact then
  y=y+line('Точная ситуация: '..self.stats.exact.total..' '..V.Plural(self.stats.exact.total,'выбор','выбора','выборов')..'.','ZoFontGameSmall',y,{.69,.69,.64,1}):GetTextHeight()+8
 end
 y=y+line('История обучения · «'..self.profileName..'»','ZoFontGameSmall',y,{.65,.65,.61,1}):GetTextHeight()+16
 tip:SetHeight(y);tip:ClearAnchors()
 local scale=tip:GetScale();local left=(mark:GetLeft()+16)/scale-width/2;left=math.max(8,math.min(left,a.GuiRoot:GetWidth()/scale-width-8))
 local top=self.selector.control:GetTop()/scale-y-12
 if top<8 then
  left=self.selector.control:GetRight()/scale+12
  if left+width>a.GuiRoot:GetWidth()/scale-8 then left=math.max(8,self.selector.control:GetLeft()/scale-width-12)end
  top=math.max(8,math.min(mark:GetTop()/scale,a.GuiRoot:GetHeight()/scale-y-8))
 end
 tip:SetAnchor(a.TOPLEFT,a.GuiRoot,a.TOPLEFT,left,top);tip:SetHidden(false);tip:BringWindowToTop()
end
function V:AnnounceProfile(name)
 self.api.d(K.displayName..': профиль «'..name..'» · /kaa')
end
function V:ReportUnavailable(_,_,reason)
 local text={insufficient_history='для этих перков ещё нет истории выбора.',calculating='модель ещё рассчитывается.',numerical_failure='расчёт не завершён; подсказки скрыты.',not_converged='обучение модели ещё не сошлось.'}
 self.api.d(K.displayName..': '..(text[reason]or 'пока недостаточно данных для подсказки.'))
end
