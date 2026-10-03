local A, M = KanaInfoBar, KanaInfoBar.Model
A.name='KanaInfoBar'
A.modules, A.ids, A.widths = {}, {}, {}
-- ZO_SavedVars recursively fills numeric table keys from defaults on every load.
-- A populated first row would reinsert moved widgets and steal them from later
-- rows during normalization. Normalize seeds the initial layout from ids instead.
A.defaults={shown=true,anchor='BOTTOMRIGHT',scale=1,gap=12,rowGap=4,gridMode=false,
    rows={},enabled={}}
A.configKeys={'rows','enabled','anchor','x','y','shown','scale','gap','rowGap','gridMode'}

-- Extension point: call after this addon loads, before or after player activation.
function A:RegisterWidget(module)
    assert(type(module)=='table' and type(module.id)=='string' and type(module.read)=='function',
        'KanaInfoBar: widget requires id and read()')
    assert(not self.modules[module.id],'KanaInfoBar: duplicate widget '..module.id)
    module.name=module.name or module.id
    module.sample=module.sample or '999'
    self.modules[module.id]=module
    self.ids[#self.ids+1]=module.id
    if self.sv then
        M.Normalize(self.sv,self.ids)
        if self.edit then M.Normalize(self.edit.config,self.ids) end
        self:Refresh(true)
    end
end

function A:Config() return self.edit and self.edit.config or self.sv end

function A:Initialize()
    self.sv=ZO_SavedVars:NewAccountWide('KanaInfoBarSaved',1,nil,M.Copy(self.defaults))
    M.Normalize(self.sv,self.ids)
    self.sv.scale=math.max(.75,math.min(1.5,tonumber(self.sv.scale) or 1))
    self.sv.gap=math.max(4,math.min(24,tonumber(self.sv.gap) or 12))
    self.sv.rowGap=math.max(0,math.min(16,tonumber(self.sv.rowGap) or 4))
    if type(self.sv.x)~='number' or type(self.sv.y)~='number' then
        self.sv.x,self.sv.y=GuiRoot:GetWidth()-24,GuiRoot:GetHeight()-64
    end
    self:InitializeProviders()
    self:InitializeInventoryAction()
    self:CreatePanel()
    self:InitializeSettings()
    SLASH_COMMANDS['/kanainfobar']=function(args)
        if args and args:lower():match('^%s*edit%s*$') then self:OpenEditor() else self:OpenSettings() end
    end
    EVENT_MANAGER:RegisterForUpdate(self.name,250,function() self:Refresh() end)
    EVENT_MANAGER:RegisterForEvent(self.name,EVENT_PLAYER_ACTIVATED,function() self:Refresh(true) end)
    EVENT_MANAGER:RegisterForEvent(self.name,EVENT_SCREEN_RESIZED,function()
        self.sv.x=math.max(0,math.min(GuiRoot:GetWidth(),self.sv.x))
        self.sv.y=math.max(0,math.min(GuiRoot:GetHeight(),self.sv.y))
        self:Refresh(true)
    end)
    self:Refresh(true)
end

EVENT_MANAGER:RegisterForEvent(A.name,EVENT_ADD_ON_LOADED,function(_,name)
    if name~=A.name then return end
    EVENT_MANAGER:UnregisterForEvent(A.name,EVENT_ADD_ON_LOADED)
    A:Initialize()
end)
