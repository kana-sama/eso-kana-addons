-- Contextual native forms. No layout padding, native globals or draft internals.
local Inspector={}; Inspector.__index=Inspector; KanaEffects.Inspector=Inspector
local P=KanaEffects.Picker; local serial=0
local function label(api,parent,name,font) local c=api.controls.CreateControl(name,parent,api.constants.CT_LABEL); c:SetFont(font or 'ZoFontGame'); c:SetColor(unpack(P.NativeColors(api).normal)); return c end
Inspector.Label=label
local function find(list,id) for _,v in ipairs(list or {}) do if v.id==id then return v end end end
local function contains(list,value) for _,v in ipairs(list or {}) do if v==value then return true end end; return false end
local function labels(api)
    local language=api and (api.language or (api.GetCVar and api.GetCVar('language.2'))) or 'ru'
    return (KanaEffects.Localization[language] or KanaEffects.Localization.ru).editor
end
Inspector.Labels=labels; Inspector.Find=find; Inspector.Contains=contains
-- Reusable bounded native form rows; every callback has a form generation.
local Form={}; Form.__index=Form; Inspector.Form=Form
function Form.New(api,name,title,width,height,escape)
    if not api or not api.controls.CreateControlFromVirtual or not api.ComboBox then return nil end
    local self=setmetatable({api=api,name=name,width=width,height=height,rows={},generation=0,escape=escape,labels=labels(api)},Form)
    self.root=api.controls.CreateTopLevelWindow(name); self.root:SetHidden(true); self.root:SetMouseEnabled(true); self.root:SetDrawTier(api.constants.DT_HIGH)
    self.root:SetClampedToScreen(true); self.root:SetMovable(true)
    self.fill=P.PanelFill(api,self.root,name..'Fill')
    self.background=api.controls.CreateControlFromVirtual(name..'Background',self.root,'ZO_DefaultBackdrop'); self.background:SetHidden(true)
    self.title=label(api,self.root,name..'Title','ZoFontWinH2'); self.title:SetText(title); self.title:SetMouseEnabled(true); self.title:SetMaxLineCount(1); self.title:SetWrapMode(api.constants.TEXT_WRAP_MODE_ELLIPSIS)
    self.title:SetHandler('OnMouseDown',function(_,button) if button==1 then self.root:StartMoving() end end)
    self.title:SetHandler('OnMouseUp',function(_,button) if button==1 then self.root:StopMovingOrResizing(); self.x,self.y=self.root:GetLeft(),self.root:GetTop() end end)
    self.scroll=api.controls.CreateControlFromVirtual(name..'Scroll',self.root,'ZO_ScrollContainer')
    self.content=self.scroll:GetNamedChild('Scroll'):GetNamedChild('Child'); self.content:SetResizeToFitDescendents(false)
    self.headerMeasure=label(api,self.root,name..'HeaderMeasure','ZoFontWinH2'); self.headerMeasure:SetHidden(true)
    self.buttonMeasure=label(api,self.root,name..'ButtonMeasure','ZoFontGameBold'); self.buttonMeasure:SetHidden(true)
    self.title:SetColor(unpack(P.NativeColors(api).selected))
    self.close=api.controls.CreateControlFromVirtual(name..'Close',self.root,'ZO_CloseButton')
    self.close:SetHandler('OnClicked',function() if self.onClose then self.onClose() end end)
    self.notice=label(api,self.root,name..'Notice','ZoFontGameSmall'); self.notice:SetColor(unpack(P.NativeColors(api).normal))
    self.error=label(api,self.root,name..'Error','ZoFontGameSmall'); self.error:SetColor(unpack(P.NativeColors(api).error)); self.error:SetMaxLineCount(3)
    self:Place(); return self
end
function Form:Place(x,y)
    local vw,vh=self.api.controls.GuiRoot:GetDimensions(); local width=math.min(self.width,math.max(1,vw-24)); local height=math.min(self.height,math.max(1,vh-24))
    x=x or self.x or math.max(12,vw-width-24); y=y or self.y or 100
    self.x,self.y=math.max(0,math.min(x,vw-width)),math.max(0,math.min(y,vh-height)); self.actualWidth,self.actualHeight=width,height
    P.Anchor(self.api,self.root,self.api.controls.GuiRoot,self.x,self.y,width,height); P.Anchor(self.api,self.background,self.root,0,0,width,height); P.Anchor(self.api,self.fill,self.root,0,0,width,height)
    P.Anchor(self.api,self.close,self.root,math.max(0,width-36),18,20,20)
    self:_PlaceBody()
    if self.yRow then self:End() end
end
function Form:_PlaceBody()
    local width,height=self.actualWidth,self.actualHeight
    local function messageHeight(control)
        if control:GetText()=='' then control:SetHidden(true); return 0 end
        control:SetHidden(false); control:SetDimensions(width-36,120)
        local _,measured=control:GetTextDimensions(); return math.max(24,math.min(120,measured+4))
    end
    local noticeHeight,errorHeight=messageHeight(self.notice),messageHeight(self.error)
    local navHeight=self:_PlaceTabs(); local top=54+navHeight+(noticeHeight>0 and noticeHeight+12 or 0)
    local bottom=18+(errorHeight>0 and errorHeight+8 or 0)
    P.Anchor(self.api,self.notice,self.root,18,54+navHeight,width-36,noticeHeight)
    P.Anchor(self.api,self.scroll,self.root,18,top,width-36,math.max(1,height-top-bottom))
    P.Anchor(self.api,self.error,self.root,18,height-18-errorHeight,width-36,errorHeight)
end
function Form:_PlaceTabs()
    local nav=self.navigation; local width=self.actualWidth
    local available=math.max(1,width-72)
    self.headerMeasure:SetDimensions(0,0); self.headerMeasure:SetText(self.title:GetText())
    local titleWidth=self.headerMeasure:GetTextDimensions()
    local count=nav and nav.visible and #nav.order or 0
    local tabWidth=count>0 and count*32+(count-1)*4 or 0
    local inline=count>0 and titleWidth+12+tabWidth<=available
    P.Anchor(self.api,self.title,self.root,18,12,math.min(titleWidth,available),32)
    if count==0 then return 0 end
    local x,y=inline and 18+titleWidth+12 or 18,inline and 12 or 54
    local start=x
    for _,id in ipairs(nav.order) do
        if not inline and x>start and x+32>width-18 then x=start; y=y+36 end
        P.Anchor(self.api,nav.buttons[id],self.root,x,y,32,32); x=x+36
    end
    return inline and 0 or y-54+40
end
function Form:Tabs(value,choices,callback)
    self.navigation=self.navigation or {buttons={}}; local nav=self.navigation; nav.order={}; nav.visible=true
    for _,b in pairs(nav.buttons) do b:SetHidden(true) end
    local generation=self.generation
    for _,choice in ipairs(choices) do local id,title=choice[1],choice[2]; local b=nav.buttons[id]
        if not b then b=P.IconTab(self.api,self.root,self.name..'Tab'..id,id,title,function() end); nav.buttons[id]=b end
        b.kanaTitle=title; b:SetHidden(false); P.StyleTab(b,id==value); nav.order[#nav.order+1]=id
        b:SetHandler('OnMouseDown',function(_,button) if button==1 and self.open and generation==self.generation then self.suppressFocus=true end end)
        b:SetHandler('OnMouseUp',function(_,_,inside) if not inside then self.suppressFocus=false end end)
        b:SetHandler('OnClicked',function()
            if not self.open or generation~=self.generation then return end
            if self:CommitEdits() then callback(id) end
            self.suppressFocus=false
        end)
    end
    self:_PlaceBody()
end
function Form:Group(title)
    local row=self:_Row('group',48); row.label:SetFont('ZoFontWinH2'); row.label:SetText(title)
    if not row.line then row.line=self.api.controls.CreateControlFromVirtual(nil,row.root,'ZO_Options_Divider'); row.line:SetMouseEnabled(false) end
end
function Form:Segments(title,value,choices,callback)
    local row,key=self:_Row('segments'); row.label:SetText(title or ''); row.buttons=row.buttons or {}; row.options=choices
    local generation=self.generation
    for _,b in pairs(row.buttons) do b:SetHidden(true) end
    for index,choice in ipairs(choices) do local id=choice[1]; local b=row.buttons[index]
        if not b then b=P.Button(self.api,row.root,self.name..'Segment'..key..index,choice[2],function() end); row.buttons[index]=b end
        b:SetHidden(false); P.SetButtonText(b,choice[2]); P.StyleButton(b,'secondary',id==value)
        b:SetHandler('OnClicked',function() if self.open and generation==self.generation then callback(id) end end)
    end
end
function Form:Tiles(title,value,choices,callback,kind,axis)
    local row,key=self:_Row('tiles'); row.label:SetText(title or ''); row.buttons=row.buttons or {}; row.options=choices
    row.label:SetMaxLineCount(1); row.label:SetWrapMode(self.api.constants.TEXT_WRAP_MODE_ELLIPSIS)
    local generation=self.generation
    local styles={
        over={{23,0,24,24,'icon'},{29,10,12,4,'timer'}},
        under={{25,0,20,20,'icon'},{29,24,12,4,'timer'}},
        right={{14,2,24,24,'icon'},{44,12,12,4,'timer'}},
        list={{3,4,20,20,'icon'},{27,8,18,3,'name'},{27,16,14,3,'name'},{51,12,12,4,'timer'}},
    }
    local palette=P.NativeColors(self.api); local colors={icon=palette.normal,timer=palette.selected,name=palette.normal}
    for _,b in pairs(row.buttons) do b:SetHidden(true) end
    for index,choice in ipairs(choices) do
        local id=choice[1]; local b=row.buttons[index]
        if not b then
            b=P.SelectionButton(self.api,row.root,self.name..'Tile'..key..index); row.buttons[index]=b
            b.kanaCaption=label(self.api,b,nil,'ZoFontGameSmall'); b.kanaCaption:SetMouseEnabled(false)
            b.kanaCaption:SetHorizontalAlignment(self.api.constants.TEXT_ALIGN_CENTER)
            b.kanaCaption:SetMaxLineCount(1); b.kanaCaption:SetWrapMode(self.api.constants.TEXT_WRAP_MODE_ELLIPSIS)
            b.kanaDiagram={}
        end
        b:SetHidden(false); P.StyleSelectionButton(b,id==value,true); b.kanaCaption:SetText(choice[2]); b.kanaCaption:SetColor(unpack(id==value and palette.selected or palette.normal)); b.kanaTitle=choice[2]
        local shapes=styles[id]
        if kind=='flow' or kind=='alignment' then
            shapes={}; local vertical=kind=='flow' and id=='rows' or kind=='alignment' and axis=='rows'
            for n=0,2 do
                shapes[#shapes+1]=vertical and {23,2+n*9,7,7,'icon'} or {20+n*11,2,8,8,'icon'}
            end
            local offset=kind=='alignment' and (id=='center' and 1 or id=='end' and 2 or 0) or 0
            shapes[4]=vertical and {40,2+offset*9,7,7,'icon'} or {20+offset*11,17,8,8,'icon'}
        end
        b.kanaTileShapes=assert(shapes,'unsupported tile diagram: '..tostring(kind)..'/'..tostring(id))
        for _,part in ipairs(b.kanaDiagram) do part:SetHidden(true) end
        for n,shape in ipairs(shapes) do
            local part=b.kanaDiagram[n]
            if not part then part=self.api.controls.CreateControl(nil,b,self.api.constants.CT_TEXTURE); part:SetMouseEnabled(false); part:SetDrawLayer(self.api.constants.DL_OVERLAY); b.kanaDiagram[n]=part end
            part:SetColor(unpack(colors[shape[5]])); part:SetHidden(false)
        end
        b:SetHandler('OnClicked',function() if self.open and generation==self.generation then callback(id) end end)
    end
end
function Form:Number(value)
    local n=math.abs(value)<0.05 and 0 or value
    return (string.format('%.1f',n):gsub('%.0$',''))
end
function Form:Slot(title,icon,callback)
    local row,key=self:_Row('slot',42); row.label:SetText('')
    if not row.icon then row.icon=self.api.controls.CreateControl(self.name..'SlotIcon'..key,row.root,self.api.constants.CT_TEXTURE) end
    if not row.button then row.button=P.Button(self.api,row.root,self.name..'SlotButton'..key,title,function() end) end
    row.icon:SetTexture(icon or ''); P.SetButtonText(row.button,title)
    local generation=self.generation; row.button:SetHandler('OnClicked',function() if self.open and generation==self.generation then callback(row.button) end end)
end
function Form:Notice(text) self.notice:SetText(text or ''); self:_PlaceBody() end
function Form:Begin()
    self:CloseDropdown(); self.generation=self.generation+1; self.index=0; self.yRow=0; self.indent=0; self:Notice('')
    self:DiscardEdits()
    for _,row in pairs(self.rows) do row.root:SetHidden(true) end
end
function Form:_Row(kind,height)
    self.index=self.index+1; local key=self.index..kind; local row=self.rows[key]
    if not row then
        row={root=self.api.controls.CreateControl(self.name..'Row'..key,self.content,self.api.constants.CT_CONTROL)}; self.rows[key]=row
        row.label=kind=='group' and self.api.controls.CreateControlFromVirtual(self.name..'Label'..key,row.root,'ZO_Options_SectionTitleLabel')
            or label(self.api,row.root,self.name..'Label'..key,'ZoFontWinH4'); row.kind=kind
    end
    row.root:SetHidden(false); row.generation=self.generation; row.order=self.index; row.indent=self.indent or 0; row.minHeight=height or 36; row.apply=nil; row.edit=nil; row.callback=nil; row.enabled=true
    row.label:SetColor(unpack(P.NativeColors(self.api).highlight))
    P.Anchor(self.api,row.root,self.content,0,self.yRow,self.actualWidth-60,height or 36)
    P.Anchor(self.api,row.label,row.root,0,3,148,height or 36); self.yRow=self.yRow+(height or 36)+6
    return row,key
end
function Form:Text(text,height)
    local row=self:_Row('text',height or 24); row.label:SetFont('ZoFontGame'); row.label:SetText(text); row.label:SetColor(unpack(P.NativeColors(self.api).normal))
end
function Form:DocumentEntry(signature,description,example)
    local row,key=self:_Row('document'); row.label:SetText('')
    if not row.signature then
        row.signature=label(self.api,row.root,self.name..'Signature'..key,'ZoFontGameBold')
        row.description=label(self.api,row.root,self.name..'Description'..key,'ZoFontGame')
        row.exampleBackdrop=self.api.controls.CreateControlFromVirtual(self.name..'ExampleBackdrop'..key,row.root,'ZO_ThinBackdrop')
        row.exampleBackdrop:SetMouseEnabled(false)
        row.example=label(self.api,row.root,self.name..'Example'..key,'ZoFontGameSmall')
    end
    row.signature:SetColor(unpack(P.NativeColors(self.api).highlight)); row.signature:SetText(signature)
    row.description:SetText(description); row.example:SetText(example or '')
    row.hasExample=example~=nil and example~=''; row.example:SetHidden(not row.hasExample); row.exampleBackdrop:SetHidden(not row.hasExample)
    return row
end
function Form:Button(text,callback,role)
    local row,key=self:_Row('button'); row.label:SetText('')
    if not row.button then row.button=P.Button(self.api,row.root,self.name..'Button'..key,text,function() end) end
    local generation=self.generation
    P.Anchor(self.api,row.button,row.root,0,0,self.actualWidth-60,32); P.SetButtonText(row.button,text); P.StyleButton(row.button,role or 'secondary',false,true)
    row.button:SetHandler('OnClicked',function() if self.open and generation==self.generation then callback(row.button) end end)
    return row.button
end
function Form:Actions(actions)
    local row,key=self:_Row('actions',36); row.label:SetText(''); row.buttons=row.buttons or {}; row.options=actions
    local generation=self.generation
    for _,b in ipairs(row.buttons) do b:SetHidden(true) end
    for index,action in ipairs(actions) do
        local item=action; local b=row.buttons[index]
        if not b then b=P.Button(self.api,row.root,self.name..'Action'..key..index,item[1],function() end); row.buttons[index]=b end
        b:SetHidden(false); P.SetButtonText(b,item[1]); P.StyleButton(b,item[3] or 'secondary',false,true)
        b:SetHandler('OnClicked',function() if self.open and generation==self.generation then item[2](b) end end)
    end
    return row.buttons
end
function Form:Counter(title,value,callback,options)
    options=options or {}; local row,key=self:_Row('counter'); row.label:SetText(title)
    local scale,step=options.scale or 1,options.step or 1
    assert(type(scale)=='number' and scale>0 and scale<math.huge,'counter scale must be positive')
    assert(type(step)=='number' and step>0 and step<math.huge,'counter step must be positive')
    row.currentValue=value; row.enabled=options.enabled~=false
    if not row.minus then
        row.minus=self.api.controls.CreateControlFromVirtual(self.name..'Minus'..key,row.root,'ZO_MinusButton')
        row.plus=self.api.controls.CreateControlFromVirtual(self.name..'Plus'..key,row.root,'ZO_PlusButton')
        row.number=label(self.api,row.root,self.name..'Number'..key,'ZoFontWinH4'); row.number:SetHorizontalAlignment(self.api.constants.TEXT_ALIGN_CENTER)
    end
    local generation=self.generation
    local function present()
        row.number:SetText(self:Number(row.currentValue*scale))
        row.minus:SetEnabled(row.enabled and (options.min==nil or row.currentValue>options.min))
        row.plus:SetEnabled(row.enabled and (options.max==nil or row.currentValue<options.max))
        local color=P.NativeColors(self.api)[row.enabled and 'highlight' or 'disabled']
        row.label:SetColor(unpack(color)); row.number:SetColor(unpack(color))
    end
    local function change(direction)
        if not self.open or generation~=self.generation or not row.enabled then return end
        local nextValue=row.currentValue+direction*step/scale
        if options.min then nextValue=math.max(options.min,nextValue) end
        if options.max then nextValue=math.min(options.max,nextValue) end
        if nextValue==row.currentValue then return end
        if callback(nextValue)~=false and generation==self.generation then row.currentValue=nextValue; present() end
    end
    row.minus:SetHandler('OnClicked',function() change(-1) end); row.plus:SetHandler('OnClicked',function() change(1) end)
    present(); return row
end
function Form:Edit(title,value,callback,numeric,adjust,options)
    options=options or {}; local row,key=self:_Row('edit'); row.label:SetText(title); row.scale=options.scale or 1; row.sourceValue=value
    row.enabled=options.enabled~=false; row.label:SetColor(unpack(P.NativeColors(self.api)[row.enabled and 'highlight' or 'disabled']))
    row.value=numeric and self:Number(value*row.scale) or tostring(value)
    if not row.input then
        row.backdrop=self.api.controls.CreateControlFromVirtual(self.name..'EditBackdrop'..key,row.root,'ZO_SingleLineEditBackdrop_Keyboard')
        row.input=self.api.controls.CreateControlFromVirtual(self.name..'Edit'..key,row.backdrop,'ZO_DefaultEditForBackdrop')
        row.input:SetMaxInputChars(160); row.input:SetSelectAllOnFocus(true)
    end
    local generation=self.generation; row.edit=row.input; row.callback=callback; row.numeric=numeric
    row.input:SetEditEnabled(row.enabled)
    row.apply=function()
        if not self.open or generation~=self.generation or not row.enabled then return true end
        local raw=row.input:GetText(); if raw==row.value then return true end
        local v=raw; if numeric then v=tonumber(raw); if v then v=v/row.scale end end
        if v==nil or (numeric and (v~=v or math.abs(v)==math.huge)) then self:Message(self.labels.invalidNumber); return false end
        return callback(v)
    end
    row.input:SetHandler('OnKeyDown',adjust and function(edit,key,ctrl,alt,shift)
        if not self.open or generation~=self.generation or not row.enabled then return end
        local c=self.api.constants; local direction
        if key==c.KEY_UPARROW then direction=1 elseif key==c.KEY_DOWNARROW then direction=-1 else return end
        local value=edit:GetText()==row.value and row.sourceValue or tonumber(edit:GetText()); if value and edit:GetText()~=row.value then value=value/row.scale end
        if not value or value~=value or math.abs(value)==math.huge then self:Message(self.labels.invalidNumber); return end
        local accepted=adjust(value+direction*(shift and 10 or 1)/row.scale)
        -- Session refresh reuses this edit but discards old focus. Arrow repeats
        -- must still reach the current binding after the accepted command.
        if accepted~=false and self.open and row.generation==self.generation and row.edit==edit then edit:TakeFocus() end
    end or nil)
    if not row.unit then row.unit=label(self.api,row.root,self.name..'Unit'..key,'ZoFontGameSmall'); row.unit:SetColor(unpack(P.NativeColors(self.api).disabled)) end
    row.unit:SetText(options.unit or ''); row.unit:SetHidden(not options.unit)
    row.hasAction=options.action~=nil
    if row.hasAction then
        if not row.action then row.action=P.Button(self.api,row.root,self.name..'EditAction'..key,options.actionTitle or '',function() end) end
        row.action:SetHidden(false); P.SetButtonText(row.action,options.actionTitle or ''); P.StyleButton(row.action,'secondary',false,row.enabled)
        row.action:SetHandler('OnMouseDown',function() if self.open and generation==self.generation and row.enabled then self.suppressFocus=true end end)
        row.action:SetHandler('OnMouseUp',function(_,_,inside) if generation==self.generation and not inside then self.suppressFocus=false end end)
        row.action:SetHandler('OnClicked',function()
            if self.open and generation==self.generation and row.enabled then options.action(row.action) end
            self.suppressFocus=false
        end)
    elseif row.action then row.action:SetHidden(true) end
    row.input:SetText(row.value,true)
    P.Anchor(self.api,row.backdrop,row.root,152,0,math.max(1,self.actualWidth-212),34)
    row.input:SetHandler('OnEnter',function(edit)
        if generation~=self.generation then return end
        local ok=row.apply(); if ok then self.suppressFocus=true; edit:LoseFocus(); self.suppressFocus=false end
    end)
    row.input:SetHandler('OnFocusLost',function() if not self.suppressFocus and generation==self.generation then row.apply() end end)
    row.input:SetHandler('OnEscape',function(edit)
        if generation~=self.generation then return end
        self.suppressFocus=true; edit:SetText(row.value,true); edit:LoseFocus(); self.suppressFocus=false; self.escape()
    end)
    return row.input
end
-- Multiline rule input participates in the same staged Save transaction as
-- ordinary edits. Validation never changes the last accepted runtime preview.
function Form:Code(title,value,callback,options)
    options=options or {}; local row,key=self:_Row('code',188)
    row.label:SetText(title); row.value=options.savedValue or value; row.numeric=false; row.scale=1
    if not row.input then
        row.backdrop=self.api.controls.CreateControlFromVirtual(self.name..'CodeBackdrop'..key,row.root,'ZO_SingleLineEditBackdrop_Keyboard')
        row.input=self.api.controls.CreateControlFromVirtual(self.name..'Code'..key,row.backdrop,'ZO_DefaultEditForBackdrop')
        row.input:SetMultiLine(true); row.input:SetNewLineEnabled(true)
        row.input:SetMaxInputChars(16384); row.input:SetSelectAllOnFocus(false)
    end
    local generation=self.generation; row.edit=row.input; row.callback=callback; row.validate=options.validate
    -- A legacy AST may generate more text than a newly authored rule allows.
    -- Display it intact; the expression validator still limits actual edits.
    row.input:SetMaxInputChars(math.max(16384,#value))
    row.input:SetHandler('OnTextChanged',nil); row.input:SetText(value,true)
    row.apply=function()
        if not self.open or generation~=self.generation then return true end
        local raw=row.input:GetText(); if row.validate and not row.validate(raw) then return false end
        if raw==row.value then return true end
        return callback(raw)
    end
    row.input:SetHandler('OnTextChanged',function(edit)
        if self.suppressFocus or generation~=self.generation or not self.open then return end
        local raw=edit:GetText(); if options.onChange then options.onChange(raw) end
        if row.validate then row.validate(raw) end
    end)
    -- Return inserts a newline; committing belongs to focus loss or Save.
    row.input:SetHandler('OnEnter',nil)
    row.input:SetHandler('OnFocusLost',function() if not self.suppressFocus and generation==self.generation then row.apply() end end)
    row.input:SetHandler('OnEscape',function()
        if generation==self.generation then self.escape() end
    end)
    return row.input
end
function Form:Choice(title,value,choices,callback,options)
    local row,key=self:_Row('choice'); row.label:SetText(title)
    row.enabled=not options or options.enabled~=false
    row.label:SetColor(unpack(P.NativeColors(self.api)[row.enabled and 'highlight' or 'disabled']))
    if not row.container then row.container=self.api.controls.CreateControlFromVirtual(self.name..'Choice'..key,row.root,'ZO_ComboBox'); row.combo=self.api.ComboBox(row.container); row.combo:SetSortsItems(false) end
    P.Anchor(self.api,row.container,row.root,152,0,math.max(1,self.actualWidth-212),32); row.combo:ClearItems(); row.combo:SetEnabled(row.enabled)
    local generation=self.generation; row.choiceWidth=0
    for _,choice in ipairs(choices) do
        row.label:SetDimensions(10000,36); row.label:SetText(choice[2]); local measured=row.label:GetTextDimensions(); row.choiceWidth=math.max(row.choiceWidth,measured)
        local option=choice; local entry=row.combo:CreateItemEntry(option[2],function() if self.open and generation==self.generation and row.enabled then callback(option[1]) end end)
        row.combo:AddItem(entry,self.api.constants.ZO_COMBOBOX_SUPPRESS_UPDATE)
        if option[1]==value then row.combo:SelectItem(entry,true) end
    end
    row.label:SetText(title); return row.combo
end
function Form:Check(title,checked,callback,action,options)
    local row,key=self:_Row('check'); row.label:SetText(title); row.label:SetMouseEnabled(true)
    row.enabled=not options or options.enabled~=false; row.currentChecked=checked
    if not row.button then row.button=self.api.controls.CreateControlFromVirtual(self.name..'Check'..key,row.root,'ZO_CheckButton_Text') end
    row.button:SetFont('ZoFontWinH4'); row.button:SetHorizontalAlignment(self.api.constants.TEXT_ALIGN_RIGHT)
    local palette=P.NativeColors(self.api); row.label:SetColor(unpack(row.enabled and palette.highlight or palette.disabled))
    row.button:SetNormalFontColor(unpack(palette.normal)); row.button:SetPressedFontColor(unpack(palette.normal))
    row.button:SetMouseOverFontColor(unpack(palette.highlight)); row.button:SetDisabledFontColor(unpack(palette.disabled))
    self.api.CheckButton.SetCheckState(row.button,checked); row.button:SetEnabled(row.enabled)
    local generation=self.generation
    if action then
        if not row.action then row.action=P.Button(self.api,row.root,self.name..'CheckAction'..key,self.labels.edit,function() end) end
        row.action:SetHidden(false); P.StyleButton(row.action,'secondary',false,row.enabled)
        row.action:SetHandler('OnClicked',function() if self.open and generation==self.generation and row.enabled then action() end end)
    elseif row.action then row.action:SetHidden(true) end
    row.hasAction=action~=nil
    local function current() return self.open and generation==self.generation and row.enabled end
    local function apply(value)
        if not current() then return end
        local accepted=callback(value)
        if current() then
            if accepted~=false then row.currentChecked=value end
            self.api.CheckButton.SetCheckState(row.button,row.currentChecked)
        end
    end
    self.api.CheckButton.SetToggleFunction(row.button,function() apply(self.api.CheckButton.IsChecked(row.button)) end)
    row.button:SetHandler('OnClicked',function() apply(not row.currentChecked) end)
    row.label:SetHandler('OnMouseUp',function(_,button,inside)
        if current() and button==1 and inside then
            apply(not row.currentChecked)
        end
    end)
    return row.button
end
function Form:AnchorPoints(x,y,callback,title)
    local row,key=self:_Row('points',104); row.label:SetText(title or self.labels.anchor)
    if not row.frame then row.frame=self.api.controls.CreateControlFromVirtual(self.name..'PointsFrame'..key,row.root,'ZO_ThinBackdrop'); row.frame:SetMouseEnabled(false) end
    row.buttons=row.buttons or {}; local generation=self.generation
    for py=0,1,0.5 do for px=0,1,0.5 do
        local index=py*6+px*2+1; local bx,by=px,py; local b=row.buttons[index]
        if not b then b=P.SelectionButton(self.api,row.root,self.name..'Point'..key..index); row.buttons[index]=b end
        P.StyleSelectionButton(b,x==px and y==py,true)
        -- Native arrow texture avoids missing diagonal Unicode glyphs in ESO fonts.
        if not b.kanaDirection then
            b.kanaDirection=self.api.controls.CreateControl(nil,b,self.api.constants.CT_TEXTURE)
            b.kanaDirection:SetMouseEnabled(false)
            b.kanaDirection:SetDrawLayer(self.api.constants.DL_OVERLAY)
        end
        local center=px==0.5 and py==0.5
        b.kanaDirection:SetTexture(center and '' or 'EsoUI/Art/Buttons/scrollbox_uparrow_up.dds')
        local angles={{-math.pi/4,0,math.pi/4},{-math.pi/2,0,math.pi/2},{-3*math.pi/4,math.pi,3*math.pi/4}}
        b.kanaDirection:SetTextureRotation(-angles[py*2+1][px*2+1],0.5,0.5)
        b.kanaDirection:SetColor(unpack(P.NativeColors(self.api)[x==px and y==py and 'selected' or 'normal']))
        P.Anchor(self.api,b.kanaDirection,b,center and 12 or 7,center and 12 or 7,center and 6 or 16,center and 6 or 16)
        P.Anchor(self.api,b,row.root,152+px*68,py*68,30,30)
        b:SetHandler('OnClicked',function() if self.open and generation==self.generation then callback(bx,by) end end)
    end end
end
function Form:End()
    local fullWidth=math.max(1,self.actualWidth-60); local rows={}
    for _,row in pairs(self.rows) do if row.generation==self.generation then rows[#rows+1]=row end end
    table.sort(rows,function(a,b) return a.order<b.order end)
    local y=0
    for _,row in ipairs(rows) do
        local width=math.max(1,fullWidth-row.indent); local height=row.minHeight
        if row.kind=='edit' or row.kind=='choice' or row.kind=='points' or row.kind=='counter' or row.kind=='check' then
            -- Settings rows share one right control column. At compact widths
            -- every row stacks uniformly; long labels wrap without clipping.
            local controlWidth=math.min(220,math.max(110,math.floor(width*0.44)))
            local stacked=width<320
            local controlX=stacked and 0 or width-controlWidth
            if stacked then controlWidth=width end
            local labelWidth=stacked and width or math.max(1,controlX-16)
            row.label:SetDimensions(labelWidth,10000)
            local _,labelHeight=row.label:GetTextDimensions(); labelHeight=math.max(24,labelHeight)
            local labelY=stacked and 0 or 3
            local controlY=stacked and labelHeight+6 or math.max(0,(labelHeight-34)/2)
            if row.kind=='points' and row.label:GetText()=='' then controlY,labelHeight=0,0 end
            row.controlX=controlX
            P.Anchor(self.api,row.label,row.root,0,labelY,labelWidth,labelHeight)
            if row.backdrop then
                local unitWidth=row.unit and row.unit:GetText()~='' and 32 or 0
                local actionWidth=row.hasAction and math.min(100,math.max(70,controlWidth*0.48)) or 0
                P.Anchor(self.api,row.backdrop,row.root,controlX,controlY,math.max(1,controlWidth-unitWidth-actionWidth-(row.hasAction and 6 or 0)),34)
                if row.hasAction then P.Anchor(self.api,row.action,row.root,width-actionWidth,controlY,actionWidth,34) end
                if row.unit then P.Anchor(self.api,row.unit,row.root,width-unitWidth+4,controlY+5,math.max(1,unitWidth-4),24) end
            end
            if row.container then P.Anchor(self.api,row.container,row.root,controlX,controlY,controlWidth,32) end
            if row.kind=='points' then
                local x=width-110
                P.Anchor(self.api,row.frame,row.root,x,controlY,110,110)
                for py=0,1,0.5 do for px=0,1,0.5 do
                    P.Anchor(self.api,row.buttons[py*6+px*2+1],row.root,x+6+px*68,controlY+6+py*68,30,30)
                end end
                height=math.max(controlY+110,labelY+labelHeight)
            elseif row.kind=='counter' then
                row.number:SetDimensions(10000,28); local numberWidth=row.number:GetTextDimensions()
                local total=math.min(controlWidth,math.max(110,numberWidth+56)); local x=width-total
                P.Anchor(self.api,row.minus,row.root,x,controlY+6,22,22)
                P.Anchor(self.api,row.number,row.root,x+28,controlY+2,total-56,30)
                P.Anchor(self.api,row.plus,row.root,width-22,controlY+6,22,22)
                height=math.max(controlY+34,labelY+labelHeight)
            elseif row.kind=='check' then
                local toggleWidth=row.hasAction and math.max(1,controlWidth-94) or controlWidth
                P.Anchor(self.api,row.button,row.root,controlX,controlY,toggleWidth,32)
                if row.hasAction then P.Anchor(self.api,row.action,row.root,width-88,controlY,88,30) end
                height=math.max(controlY+34,labelY+labelHeight)
            else height=math.max(controlY+34,labelY+labelHeight) end
            row.stacked=stacked
        elseif row.kind=='code' then
            row.label:SetDimensions(width,10000); local _,labelHeight=row.label:GetTextDimensions()
            labelHeight=math.max(24,labelHeight)
            P.Anchor(self.api,row.label,row.root,0,0,width,labelHeight)
            P.Anchor(self.api,row.backdrop,row.root,0,labelHeight+4,width,156)
            height=labelHeight+164
        elseif row.kind=='document' then
            local function block(control,top,inset)
                local available=math.max(1,width-inset*2)
                control:SetDimensions(available,10000); local _,measured=control:GetTextDimensions()
                measured=math.max(22,measured)
                P.Anchor(self.api,control,row.root,inset,top,available,measured)
                return top+measured
            end
            local bottom=block(row.signature,0,0)
            bottom=block(row.description,bottom+4,0)
            if row.hasExample then
                local top=bottom+8; bottom=block(row.example,top+8,12)+8
                P.Anchor(self.api,row.exampleBackdrop,row.root,0,top,width,bottom-top)
            end
            height=bottom+8
        elseif row.kind=='text' then
            row.label:SetDimensions(width,10000); local _,measured=row.label:GetTextDimensions()
            height=math.max(height,measured+4); P.Anchor(self.api,row.label,row.root,0,0,width,height)
        elseif row.kind=='group' then
            row.label:SetDimensions(width,10000); local _,measured=row.label:GetTextDimensions(); height=20+math.max(26,measured)
            P.Anchor(self.api,row.line,row.root,0,8,width,4); P.Anchor(self.api,row.label,row.root,0,20,width,height-20)
        elseif row.kind=='tiles' then
            local top=row.label:GetText()~='' and 26 or 0; local count=#row.options
            local gap=math.min(6,width/math.max(1,count*4)); local tileWidth=math.max(0.1,(width-gap*(count-1))/math.max(1,count))
            P.Anchor(self.api,row.label,row.root,0,0,width,24)
            for index in ipairs(row.options) do
                local b=row.buttons[index]; P.Anchor(self.api,b,row.root,(index-1)*(tileWidth+gap),top,tileWidth,58)
                local scale=math.min(1,math.max(0.001,tileWidth-16)/70)
                for n,shape in ipairs(b.kanaTileShapes) do
                    P.Anchor(self.api,b.kanaDiagram[n],b,(tileWidth-70*scale)/2+shape[1]*scale,6+(28-28*scale)/2+shape[2]*scale,shape[3]*scale,shape[4]*scale)
                end
                P.Anchor(self.api,b.kanaCaption,b,2,38,math.max(0.1,tileWidth-4),18)
            end
            height=top+58
        elseif row.kind=='segments' then
            local y=row.label:GetText()~='' and 30 or 0; local x=0
            P.Anchor(self.api,row.label,row.root,0,0,width,26)
            for index,option in ipairs(row.options) do
                local b=row.buttons[index]; self.buttonMeasure:SetDimensions(0,0); self.buttonMeasure:SetText(option[2])
                local measured=self.buttonMeasure:GetTextDimensions()
                local bw=math.min(width,measured+24); if x>0 and x+bw>width then x=0; y=y+38 end
                P.Anchor(self.api,b,row.root,x,y,bw,32); x=x+bw+6
            end
            row.label:SetDimensions(width,26); height=y+34
        elseif row.kind=='slot' then
            P.Anchor(self.api,row.icon,row.root,0,4,34,34); P.Anchor(self.api,row.button,row.root,44,0,width-44,40)
        elseif row.kind=='actions' then
            local count=#row.options; local columns=math.max(1,math.min(count,math.floor((width+8)/118)))
            local buttonWidth=(width-8*(columns-1))/columns
            for index in ipairs(row.options) do
                P.Anchor(self.api,row.buttons[index],row.root,((index-1)%columns)*(buttonWidth+8),math.floor((index-1)/columns)*40,buttonWidth,32)
            end
            height=math.max(0,math.ceil(count/columns)*40-8)
        elseif row.kind=='button' then P.Anchor(self.api,row.button,row.root,0,0,width,32)
        end
        P.Anchor(self.api,row.root,self.content,row.indent,y,width,height); y=y+height+6
    end
    self.yRow=y; self.content:SetDimensions(fullWidth,math.max(1,y)); self:_PlaceBody()
    self.api.Scroll.UpdateScrollBar(self.scroll)
end
function Form:GetPendingEdits()
    local pending={}
    for _,row in pairs(self.rows) do if row.generation==self.generation and row.edit and row.callback and row.enabled~=false then
        local raw=row.edit:GetText()
        if row.validate and not row.validate(raw) then return nil end
        if raw~=row.value then
            local value=raw; if row.numeric then value=tonumber(raw); if value then value=value/row.scale end end
            if value==nil or (row.numeric and (value~=value or math.abs(value)==math.huge)) then self:Message(self.labels.invalidNumber); return nil end
            pending[#pending+1]={callback=row.callback,value=value,kind=row.kind}
        end
    end end
    return pending
end
function Form:CommitEdits()
    local pending=self:GetPendingEdits(); if not pending then return false end
    for _,edit in ipairs(pending) do if edit.callback(edit.value)==false then return false end end; return true
end
function Form:DiscardEdits()
    self.suppressFocus=true
    for _,row in pairs(self.rows) do if row.input then row.input:SetText(row.value or '',true); row.input:LoseFocus() end end
    self.suppressFocus=false
end
function Form:CloseDropdown()
    local handled=false
    for _,row in pairs(self.rows) do if row.combo and row.combo:IsDropdownVisible() then row.combo:HideDropdown(); handled=true end end
    return handled
end
function Form:Message(text) self.error:SetText(text or ''); self:_PlaceBody() end
function Form:Show()
    self.open=true; self:Place(); self.root:SetHidden(false)
    self.root:BringWindowToTop()
end
function Form:Hide() self.suppressFocus=false; self.open=false; self:CloseDropdown(); self:DiscardEdits(); self.generation=self.generation+1; self.root:StopMovingOrResizing(); self.root:SetHidden(true) end
function Form:Dispose()
    self:Hide(); if self.navigation then for _,b in pairs(self.navigation.buttons) do for _,event in ipairs({'OnClicked','OnMouseDown','OnMouseUp'}) do b:SetHandler(event,nil) end end end
    self.root:SetHandler('OnMouseUp',nil); self.title:SetHandler('OnMouseDown',nil); self.title:SetHandler('OnMouseUp',nil); self.close:SetHandler('OnClicked',nil)
    for _,row in pairs(self.rows) do
        row.label:SetHandler('OnMouseUp',nil); if row.action then for _,event in ipairs({'OnClicked','OnMouseDown','OnMouseUp'}) do row.action:SetHandler(event,nil) end end
        if row.input then for _,event in ipairs({'OnFocusLost','OnEnter','OnEscape','OnKeyDown'}) do row.input:SetHandler(event,nil) end end
        if row.button then row.button:SetHandler('OnClicked',nil); if row.kind=='check' then self.api.CheckButton.SetToggleFunction(row.button,nil) end end
        if row.combo then row.combo:ClearItems() end
        if row.minus then row.minus:SetHandler('OnClicked',nil); row.plus:SetHandler('OnClicked',nil) end
        for _,b in pairs(row.buttons or {}) do b:SetHandler('OnClicked',nil) end
    end
end
function Inspector.New(editor,session,anchors,api)
    serial=serial+1; return setmetatable({editor=editor,session=session,anchors=anchors,api=api,name='KanaEffectsInspector'..serial,labels=labels(api),tab='main',expressionBuffers={}},Inspector)
end
function Inspector:GetWidget() local draft=self.session:ReadDraft(); return draft and find(draft.widgets,self.widgetId) end
function Inspector:IsOpen() return self.open==true end
function Inspector:Fields()
    local w=self:GetWidget(); if not w then return {} end
    return {columns=w.type=='table',rows=w.type=='table',fixedAxis=w.type=='grid',count=w.type=='grid',gridRules=w.type=='grid',absent=w.type=='table',ghostAlpha=w.type=='table' and w.layout.absent=='ghost',rowWidth=w.style.mode=='list',nameFontSize=w.style.mode=='list'}
end
function Inspector:Set(path,value)
    local w=self:GetWidget(); if not w then return false end
    local parent,field=string.match(path,'^([^.]+)%.(.+)$'); local patch={}
    if parent then patch[parent]={[field]=value} else patch[path]=value end
    return self.editor:PatchWidget(w.id,patch)
end
function Inspector:SetAnchorPoint(x,y)
    local w=self:GetWidget(); local v=w and self.editor.runtime:GetView(w.id); if not v then return false end
    return self.editor:PatchWidget(w.id,{anchor=KanaEffects.Layout.Reanchor(w.anchor,v.layout.rect,x,y,self.anchors:GetReferenceRect(w.anchor.relativeTo))})
end
function Inspector:SetReference(reference)
    local w=self:GetWidget(); local view=w and self.editor.runtime:GetView(w.id); if not view then return false end
    return self.editor:PatchWidget(w.id,{anchor=KanaEffects.Layout.Rereference(w.anchor,view.layout.rect,reference,
        w.anchor.relativePointX,w.anchor.relativePointY,self.anchors:GetReferenceRect(reference))})
end
function Inspector:SetReferencePoint(x,y)
    local w=self:GetWidget(); local view=w and self.editor.runtime:GetView(w.id); if not view then return false end
    return self.editor:PatchWidget(w.id,{anchor=KanaEffects.Layout.Rereference(w.anchor,view.layout.rect,w.anchor.relativeTo,x,y,self.anchors:GetReferenceRect(w.anchor.relativeTo))})
end
function Inspector:ResetToScreen() return self:SetReference('screen') end
function Inspector:Center(axis)
    local w=self:GetWidget(); local v=w and self.editor.runtime:GetView(w.id); if not v then return false end
    return self.editor:PatchWidget(w.id,{anchor=KanaEffects.Layout.Center(w.anchor,v.layout.rect,self.anchors:GetReferenceRect(w.anchor.relativeTo),axis)})
end
function Inspector:ToggleSet(field,id)
    local w=self:GetWidget(); if not w then return false end; local list=P.Copy(w.rules[field]); local exists=false
    for i=#list,1,-1 do if list[i]==id then table.remove(list,i); exists=true end end; if not exists then list[#list+1]=id end
    local patch={[field]=list}
    if not exists then
        local other=field=='includeSets' and 'excludeSets' or 'includeSets'; patch[other]=P.Copy(w.rules[other])
        for i=#patch[other],1,-1 do if patch[other][i]==id then table.remove(patch[other],i) end end
    end
    return self.editor:PatchWidget(w.id,{rules=patch})
end
function Inspector:Open(id)
    if self.widgetId~=id then self.tab='main' end
    self.widgetId=id; self.open=true
    if not self.form then
        self.form=Form.New(self.api,self.name,self.labels.inspector,520,760,function() self.editor:RequestClose() end)
        if self.form then self.form.onClose=function() self:Close() end end
    end
    if self.form then self.form:Show() end; self:Refresh()
end
function Inspector:FirstFreeCell(widget)
    local occupied={}; local capacity=widget.layout.rows*widget.layout.columns
    for row,columns in pairs(widget.slots) do for column in pairs(columns) do
        if row<=widget.layout.rows and column<=widget.layout.columns then occupied[#occupied+1]=(row-1)*widget.layout.columns+column end
    end end
    table.sort(occupied); local nextCell=1
    for _,cell in ipairs(occupied) do if cell==nextCell then nextCell=nextCell+1 elseif cell>nextCell then break end end
    if nextCell>capacity then return end
    return math.floor((nextCell-1)/widget.layout.columns)+1,(nextCell-1)%widget.layout.columns+1
end
function Inspector:ChooseCell(row,column,initiator)
    local w=self:GetWidget()
    if not w or not row or not column or row%1~=0 or column%1~=0 or row<1 or column<1 or row>w.layout.rows or column>w.layout.columns then
        return self.editor:Report(false,{{code='invalid_number'}})
    end
    return self.editor:OpenSlot(w.id,row,column,initiator)
end
function Inspector:RebaseReferences(profile)
    local present={}; for _,w in ipairs(profile.widgets) do present[w.id]=true end
    for id in pairs(self.expressionBuffers) do if not present[id] then self.expressionBuffers[id]=nil end end
    local names={}
    for _,set in ipairs(profile.sets) do
        names[set.id]=set.name
        local old=self.setNames and self.setNames[set.id]
        if old and old~=set.name then
            for id,source in pairs(self.expressionBuffers) do self.expressionBuffers[id]=KanaEffects.Rules.RewriteReferences(source,old,set.name,set.id) end
        end
    end
    self.setNames=names
end
function Inspector:Expression(widget,profile)
    return KanaEffects.Rules.WidgetExpression(widget,profile.sets)
end
function Inspector:ValidateExpression(source,id)
    local p=self.session:ReadDraft(); local w=p and find(p.widgets,id or self.widgetId)
    if not w then return false end
    if source==self:Expression(w,p) then if self.form then self.form:Message('') end; return true end
    w.rules.expression=source
    local compiled,diagnostics=KanaEffects.Rules.Compile(p.sets,p.longThreshold,p.widgets)
    local message=not compiled and diagnostics and diagnostics[1] and diagnostics[1].message or ''
    if self.form then self.form:Message(message) end
    return compiled~=nil,message
end
function Inspector:SetExpression(id,source)
    local p=self.session:ReadDraft(); local w=p and find(p.widgets,id); if not w then return false end
    if source==self:Expression(w,p) then return true end
    local ok,message=self:ValidateExpression(source,id)
    if not ok then return false,{{code='invalid_expression',message=message}} end
    local accepted,diag=self.editor:PatchWidget(id,{rules={expression=source}})
    if accepted then self.expressionBuffers[id]=nil end
    return accepted,diag
end
function Inspector:CaptureExpression()
    if self.open and self.tab=='effects' and self.form and self:GetWidget() then
        for _,row in pairs(self.form.rows) do
            if row.generation==self.form.generation and row.kind=='code' then self.expressionBuffers[self.widgetId]=row.input:GetText() end
        end
    end
end
function Inspector:GetPendingEdits()
    self:CaptureExpression()
    local p=self.session:ReadDraft(); if not p then return {} end
    local pending={}
    if self.open and self.form then
        local visible=self.form:GetPendingEdits(); if not visible then return nil end
        for _,edit in ipairs(visible) do if edit.kind~='code' then pending[#pending+1]=edit end end
    end
    for _,w in ipairs(p.widgets) do
        local id=w.id; local source=self.expressionBuffers[id]
        if source and source~=self:Expression(w,p) then
            local ok,message=self:ValidateExpression(source,id)
            if not ok then self:Open(id); self.tab='effects'; self:Refresh(); self.form:Message(message); return nil end
            pending[#pending+1]={value=source,callback=function(value) return self:SetExpression(id,value) end}
        end
    end
    return pending
end
function Inspector:HasPendingChanges()
    local p=self.session:ReadDraft(); if not p then return false end
    for _,w in ipairs(p.widgets) do local source=self.expressionBuffers[w.id]; if source and source~=self:Expression(w,p) then return true end end
    return false
end
function Inspector:ResetDraft() self.expressionBuffers={}; self.setNames=nil; self.widgetId=nil; self.tab='main' end
function Inspector:Refresh()
    if not self:IsOpen() or not self.form then return end
    local w=self:GetWidget(); if not w then self:Close(); return end
    local f,l=self.form,self.labels
    self:RebaseReferences(self.session:ReadDraft())
    self.tab=({general='main',rules='effects',diagnostics='effects'})[self.tab] or self.tab
    f:Begin(); f.title:SetText(w.name)
    f:Tabs(self.tab,{{'main',l.mainTab},{'effects',l.effectsTab},{'layout',l.layoutTab},{'style',l.appearance},{'anchor',l.anchor}},function(tab) self.tab=tab; self:Refresh() end)
    local function edit(title,path,value,options)
        f:Edit(title,value,function(v) return self:Set(path,v) end,type(value)=='number',nil,options)
    end
    local function count(title,path,value,options)
        f:Counter(title,value,function(v) return self:Set(path,v) end,options)
    end
    local function choice(title,path,value,options) f:Choice(title,value,options,function(v) return self:Set(path,v) end) end
    local function tiles(title,path,value,options,kind,axis) f:Tiles(title,value,options,function(v) return self:Set(path,v) end,kind,axis) end
    if self.tab=='main' then
        edit(l.panelName,'name',w.name)
        choice(l.panelType,'type',w.type,{{'grid',l.grid},{'table',l.table}})
        f:Group(l.widgetActions)
        f:Button(l.duplicate,function() self.editor:DuplicateWidget(w.id) end)
        f:Button(l.deleteWidget,function() self.editor:DeleteWidget(w.id) end,'destructive')
    elseif self.tab=='effects' then
        local sources={{'player',l.sourcePlayer},{'reticleover',l.sourceTarget}}; local c=self.api and self.api.constants or {}
        if type(c.BOSS_RANK_ITERATION_BEGIN)=='number' and type(c.BOSS_RANK_ITERATION_END)=='number' then for i=c.BOSS_RANK_ITERATION_BEGIN,c.BOSS_RANK_ITERATION_END do sources[#sources+1]={'boss'..i,l.sourceBoss..' '..i} end end
        if not contains({'player','reticleover'},w.unitTag) then local found=false; for _,v in ipairs(sources) do if v[1]==w.unitTag then found=true end end; if not found then sources[#sources+1]={w.unitTag,w.unitTag} end end
        choice(l.source,'unitTag',w.unitTag,sources)
        if w.type=='grid' then
            local p=self.session:ReadDraft(); local original=self:Expression(w,p); local source=self.expressionBuffers[w.id] or original
            f:Code(l.expression,source,function(value) return self:SetExpression(w.id,value) end,{
                savedValue=original,onChange=function(value) self.expressionBuffers[w.id]=value end,
                validate=function(value) return self:ValidateExpression(value,w.id) end})
            f:Button(l.ruleDocumentation,function() self.editor.setEditor:OpenHelp() end)
        else
            f:Group(l.assignments); local assigned={}
            for row,columns in pairs(w.slots) do for column,selector in pairs(columns) do
                if row<=w.layout.rows and column<=w.layout.columns then assigned[#assigned+1]={row=row,column=column,selector=selector} end
            end end
            table.sort(assigned,function(a,b) if a.row==b.row then return a.column<b.column end; return a.row<b.row end)
            for _,item in ipairs(assigned) do local row,column=item.row,item.column; local meta=self.editor.catalog:Resolve(item.selector)
                f:Slot(row..' × '..column..'    '..(meta.name or l.unknown),meta.icon,function(control) self:ChooseCell(row,column,control) end)
            end
            if #assigned==0 then f:Text(l.noAssignments) end
            local row,column=self:FirstFreeCell(w)
            local add=f:Button(row and l.addEffect or l.noFreeCells,function(control) if row then self:ChooseCell(row,column,control) end end)
            P.StyleButton(add,'secondary',false,row~=nil)
            self:_Recovery(f,w)
        end
    elseif self.tab=='layout' then
        if w.type=='grid' then
            tiles(l.fillDirection,'layout.fixedAxis',w.layout.fixedAxis,{{'columns',l.byRows},{'rows',l.byColumns}},'flow')
            local align=KanaEffects.Layout.GridAlignment(w)
            tiles(l.alignment,'layout.align',align,{{'start',w.layout.fixedAxis=='columns' and l.alignLeft or l.alignTop},{'center',l.alignCenter},{'end',w.layout.fixedAxis=='columns' and l.alignRight or l.alignBottom}},'alignment',w.layout.fixedAxis)
            count(w.layout.fixedAxis=='columns' and l.iconsPerRow or l.iconsPerColumn,'layout.count',w.layout.count,{min=1,step=1})
        else
            count(l.columns,'layout.columns',w.layout.columns,{min=1,step=1}); count(l.rows,'layout.rows',w.layout.rows,{min=1,step=1})
            choice(l.absent,'layout.absent',w.layout.absent,{{'hidden',l.hidden},{'ghost',l.ghost}})
            count(l.opacity,'layout.ghostAlpha',w.layout.ghostAlpha,{min=0,max=1,scale=100,step=5,enabled=w.layout.absent=='ghost'})
        end
        count(l.gap,'layout.gap',w.layout.gap,{min=0,step=1})
        if w.type=='grid' then f:AnchorPoints(w.anchor.pointX,w.anchor.pointY,function(x,y) self:SetAnchorPoint(x,y) end,l.growthAnchor) end
    elseif self.tab=='style' then
        f:Group(l.style)
        tiles(nil,'style.mode',w.style.mode,{{'over',l.over},{'under',l.under},{'right',l.right},{'list',l.list}},'style')
        f:Group(l.dimensions)
        count(l.iconSize,'style.iconSize',w.style.iconSize,{min=1,step=1})
        count(l.timerFontSize,'style.timerFontSize',w.style.timerFontSize,{min=1,step=1})
        count(l.nameFontSize,'style.nameFontSize',w.style.nameFontSize,{min=1,step=1,enabled=w.style.mode=='list'})
        count(l.rowWidth,'style.rowWidth',w.style.rowWidth,{min=1,step=1,enabled=w.style.mode=='list'})
    elseif self.tab=='anchor' then
        f:Choice(l.reference,w.anchor.relativeTo,{{'screen',l.screen},{'actionBar',l.actionBar},{'resources',l.resources},{'targetFrame',l.targetFrame}},function(ref) self:SetReference(ref) end)
        f:AnchorPoints(w.anchor.relativePointX,w.anchor.relativePointY,function(x,y) self:SetReferencePoint(x,y) end,l.referencePoint)
        f:Group(l.offsets)
        for _,axis in ipairs({'x','y'}) do local field=axis; local function apply(v) return self:Set('anchor.'..field,v) end
            f:Edit(field=='x' and l.horizontal or l.vertical,w.anchor[field],apply,true,apply,{
                actionTitle=l.centerCoordinate,action=function() self:Center(field=='x' and 'horizontal' or 'vertical') end})
        end
        f:Button(l.resetScreen,function() self:ResetToScreen() end)
    end
    f:End(); f:Message(self.editor.message)
    if self.tab=='effects' and w.type=='grid' then self:ValidateExpression(self.expressionBuffers[w.id] or self:Expression(w,self.session:ReadDraft()),w.id) end
end
function Inspector:OutOfBounds(id)
    local draft=self.session:ReadDraft(); local w=draft and find(draft.widgets,id or self.widgetId); local result={}
    if not w or w.type~='table' then return result end
    for row,columns in pairs(w.slots) do for column,selector in pairs(columns) do
        if row>w.layout.rows or column>w.layout.columns then result[#result+1]={row=row,column=column,selector=P.Copy(selector)} end
    end end
    table.sort(result,function(a,b) if a.row==b.row then return a.column<b.column end; return a.row<b.row end); return result
end
function Inspector:RecoverSlot(id,row,column,toRow,toColumn)
    local draft=self.session:ReadDraft(); local w=draft and find(draft.widgets,id)
    if not w or w.type~='table' or type(toRow)~='number' or type(toColumn)~='number' or toRow<1 or toColumn<1 or toRow>w.layout.rows or toColumn>w.layout.columns or toRow%1~=0 or toColumn%1~=0 then
        return self.editor:Report(false,{{code='invalid_number'}})
    end
    return self.editor:Apply({type='slot.transfer',from={widgetId=id,row=row,column=column},to={widgetId=id,row=toRow,column=toColumn},copy=false})
end
function Inspector:ClearSlot(id,row,column) return self.editor:Apply({type='slot.clear',widgetId=id,row=row,column=column}) end
function Inspector:_Recovery(form,w)
    local list=self:OutOfBounds(w.id); if #list==0 then return end
    local l=self.labels; form:Text(l.outOfBounds..' ('..#list..')')
    local options={}; local selected
    for _,item in ipairs(list) do local key=item.row..':'..item.column
        options[#options+1]={key,item.row..' × '..item.column}; if self.recoveryKey==key then selected=item end
    end
    selected=selected or list[1]; self.recoveryKey=selected.row..':'..selected.column
    form:Choice(l.assignment,self.recoveryKey,options,function(key) self.recoveryKey=key; self:Refresh() end)
    local metadata=self.editor.catalog and self.editor.catalog:Resolve(selected.selector)
    form:Text(metadata and metadata.name or l.unknown)
    self.recoveryRow=self.recoveryRow or 1; self.recoveryColumn=self.recoveryColumn or 1
    local function destination(field,title)
        local function apply(value) self[field]=value; return true end
        local input=form:Edit(title,self[field],apply,true,function(value) apply(value); self:Refresh() end)
        return input
    end
    local rowInput=destination('recoveryRow',l.destinationRow); local columnInput=destination('recoveryColumn',l.destinationColumn)
    form:Button(l.recover,function()
        self:RecoverSlot(w.id,selected.row,selected.column,tonumber(rowInput:GetText()),tonumber(columnInput:GetText()))
    end)
    form:Button(l.editAssignment,function(control) self.editor:OpenSlot(w.id,selected.row,selected.column,control) end)
    form:Button(l.clearAssignment,function() self:ClearSlot(w.id,selected.row,selected.column) end)
end
function Inspector:Close() self:CaptureExpression(); self.open=false; if self.form then self.form:Hide() end end
function Inspector:Dispose() self:Close(); if self.form then self.form:Dispose() end end
