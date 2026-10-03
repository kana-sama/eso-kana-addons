-- Verified native primitives; no ESO globals outside EsoApi. See native-ui-reference.
local Controls = {}
KanaEffects.Controls = Controls
-- Stock HUD backgrounds occupy LOW/BACKGROUND at nonnegative levels. Keep
-- the whole aura stack below them, including temporarily dragged cells.
Controls.DrawLevels={root=-1000,background=-990,icon=-980,text=-970,border=-960}
Controls.DragDrawOffset=500
local serial = 0
local HANDLERS = {'OnMouseEnter','OnMouseExit','OnMouseDown','OnMouseUp','OnDragStart','OnReceiveDrag',
    'OnMoveStart','OnMoveStop','OnResizeStart','OnResizeStop','OnUpdate','OnRectChanged','OnEffectivelyHidden','OnEffectivelyShown'}
function Controls.New(api)
    serial=serial+1
    return setmetatable({api=api, owned={}, namespace='KanaEffectsTimers'..serial}, {__index=Controls})
end
function Controls:SetDrawOrder(c,role,raised)
    role=role or c._kanaOrderRole
    local level=assert(Controls.DrawLevels[role],'unknown aura draw role')
    c._kanaOrderRole=role; c._kanaOrderRaised=raised==true
    c:SetDrawTier(self.api.constants.DT_LOW)
    c:SetDrawLayer(self.api.constants.DL_BACKGROUND)
    c:SetDrawLevel(level+(raised and Controls.DragDrawOffset or 0))
end
function Controls:Create(kind, parent)
    assert(not self.disposed, 'controls disposed')
    local c = self.api.controls.CreateControl(nil,parent,self.api.constants['CT_'..string.upper(kind)])
    local role=kind=='label' and 'text' or kind=='texture' and 'icon' or kind=='backdrop' and 'background' or 'root'
    self:SetDrawOrder(c,role)
    c:SetMouseEnabled(false); self.owned[#self.owned+1]=c
    return c
end
function Controls:Rect(c, rect, relative)
    c:ClearAnchors(); c:SetAnchor(self.api.constants.TOPLEFT,relative or self.api.controls.GuiRoot,self.api.constants.TOPLEFT,rect.x,rect.y)
    c:SetDimensions(rect.width,rect.height)
end
function Controls:FontDescriptor(size, role)
    assert(role == 'timer' or role == 'name', 'unsupported font role')
    local font = assert(self.api.fonts and self.api.fonts[role=='timer' and 'gameBold' or 'game'], 'native game font unavailable')
    local face,_,option = font:GetFontInfo()
    return face .. '|' .. tostring(size) .. '|' .. (role=='timer' and 'outline' or option)
end
function Controls:MeasureText(text, descriptor)
    assert(not self.disposed, 'controls disposed')
    -- One native symbol and one hidden label, reused through FontObject:SetFont.
    -- No unbounded native symbols for historical fractional profile font sizes.
    if not self.measureFont then
        self.measureFont = assert(self.api.CreateFont,'native CreateFont unavailable')(self.namespace..'Font',descriptor)
        self.measureLabel=self:Create('label',self.api.controls.GuiRoot); self.measureLabel:SetHidden(true)
    end
    if self.measureDescriptor ~= descriptor then
        self.measureFont:SetFont(descriptor); self.measureLabel:SetFont(descriptor); self.measureDescriptor=descriptor
    end
    local width = assert(self.api.GetStringWidthScaled,'native font measure unavailable')(self.measureFont,text,1,self.api.constants.SPACE_INTERFACE)
    return width,self.measureLabel:GetFontHeight()
end
-- Read an exact stock font alias through a hidden owned Label; no guessed
-- stock pixel size and no mutation of the shared dynamic timer measurement.
function Controls:FontHeight(font)
    assert(not self.disposed, 'controls disposed')
    if not self.fontHeightLabel then self.fontHeightLabel=self:Create('label',self.api.controls.GuiRoot); self.fontHeightLabel:SetHidden(true) end
    self.fontHeightLabel:SetFont(font); return self.fontHeightLabel:GetFontHeight()
end
function Controls:Scale() return assert(self.api.GetUIGlobalScale,'native UI scale unavailable')() end
function Controls:SetTimerDriver(callback)
    if self.disposed then return end
    if self.driver == callback then return end
    local manager=assert(self.api.eventManager,'native event manager unavailable')
    if self.driver then manager:UnregisterForUpdate(self.namespace) end
    self.driver=callback; self.driverGeneration=(self.driverGeneration or 0)+1
    local generation=self.driverGeneration
    if callback then
        manager:RegisterForUpdate(self.namespace,100,function()
            if not self.disposed and self.driver == callback and self.driverGeneration == generation then callback(self.api.Now()) end
        end)
    end
end
function Controls:ObserveVisibility(c, callback)
    local subscribed=true
    c:SetHandler('OnEffectivelyHidden',function() if subscribed and not self.disposed then callback(false) end end)
    c:SetHandler('OnEffectivelyShown',function() if subscribed and not self.disposed then callback(true) end end)
    callback(not c:IsControlHidden())
    return function()
        if subscribed then subscribed=false; c:SetHandler('OnEffectivelyHidden',nil); c:SetHandler('OnEffectivelyShown',nil) end
    end
end
function Controls:Reset(c)
    if c._kanaOrderRaised then self:SetDrawOrder(c) end
    c:SetHidden(true); c:SetAlpha(1); c:SetMouseEnabled(false); c:ClearAnchors(); c:SetDimensions(0,0)
    for _,handler in ipairs(HANDLERS) do c:SetHandler(handler,nil) end
end
function Controls:Dispose()
    if self.disposed then return end
    self:SetTimerDriver(nil); self.disposed=true
    for _,c in ipairs(self.owned) do self:Reset(c) end
    self.owned={}
end
