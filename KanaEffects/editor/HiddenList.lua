-- Reversible draft-only hiding. No buff cancellation/native effect mutations.
local HiddenList={}; HiddenList.__index=HiddenList; KanaEffects.HiddenList=HiddenList
local P=KanaEffects.Picker; local sequence=0
function HiddenList.New(catalog,session,picker,api)
    sequence=sequence+1
    local self=setmetatable({catalog=catalog,session=session,picker=picker,api=api,query='',generation=0,name='KanaEffectsHidden'..sequence,labels=P.Locale(api)},HiddenList)
    self.unsubscribe=session:Subscribe(function(draft) if not draft then self:Close() elseif self:IsOpen() then self:_Refresh() end end)
    return self
end
function HiddenList:IsOpen() return self.options~=nil end
function HiddenList:GetItems()
    local draft=self.session:ReadDraft(); local items={}; local normalize=self.api and self.api.NormalizeName or string.lower; local query=normalize(self.query)
    local catalogMatches={}
    if query~='' then
        local results,total=self.catalog:Search(self.query,{},0,1000)
        if total>#results then results=self.catalog:Search(self.query,{},0,total) end
        for _,item in ipairs(results) do catalogMatches[KanaEffects.Selectors.Key(item.selector)]=true end
    end
    for _,selector in ipairs(draft and draft.hidden or {}) do
        local meta=self.catalog:Resolve(selector); local name=meta.name~='' and meta.name or self.labels.unknown
        if selector.kind=='category' and selector.id=='food' then name=self.labels.anyFood end
        local identity=KanaEffects.Selectors.Key(selector)
        if query=='' or catalogMatches[identity] or string.find(normalize(name),query,1,true) or string.find(normalize(identity),query,1,true) then
            local row={selector=P.Copy(selector),name=name,icon=meta.icon,selectable=true,abilityIds=selector.kind=='ability' and {selector.id} or {},unitTags={}}
            items[#items+1]=row
        end
    end
    return items
end
function HiddenList:SetQuery(query) self.query=tostring(query or ''); self:_Refresh() end
function HiddenList:Restore(selector) return self.session:Apply({type='hidden.remove',selector=selector}) end
function HiddenList:RestoreAll() return self.session:Apply({type='hidden.clear'}) end
function HiddenList:_Refresh()
    if not self:IsOpen() then return end
    self.items=self:GetItems(); self.selected=#self.items>0 and math.min(self.selected or 1,#self.items) or nil
    if self.view then
        self.view:SetItems(self.items); self.view.restoreAll:SetEnabled(#(self.session:ReadDraft().hidden)>0)
        self.view.notice:SetText(#self.items==0 and (self.query=='' and self.labels.noHidden or self.labels.noResults) or '')
        self.view.notice:SetHidden(#self.items>0); self.view:SetDetail('')
    end
end
function HiddenList:OpenAdd()
    assert(not self.disposed,'Hidden library disposed')
    local generation=self.generation
    self.picker:Open({purpose='hidden',initiator=self.view and self.view.search,onEscape=self.options and self.options.onEscape,
        canRestoreFocus=function() return not self.disposed and self:IsOpen() end,
        onCancel=function() if self.generation==generation then self.adding=false end end,
        onChoose=function(selector)
            if not self.disposed and self.generation==generation and self.session:ReadDraft() then
                self.adding=false; return self.session:Apply({type='hidden.add',selector=selector})
            end
        end})
    self.adding=true
end
function HiddenList:Escape()
    if not self:IsOpen() then return false end
    if self.options.onEscape then self.options.onEscape() else self:Close() end; return true
end
function HiddenList:Open(options)
    assert(not self.disposed,'Hidden library disposed'); assert(self.session:ReadDraft(),'Begin editing first')
    self:Close(); self.options=options or {}; self.generation=self.generation+1; self.query=''
    if not self.view then
        self.view=P.CreatePanel(self.api,self.name,self.labels.hiddenTitle,{close=function() self:Close() end,search=function(q) self:SetQuery(q) end,
            enter=function() local item=self.items[self.selected or 0]; if item then self:Restore(item.selector) end end,escape=function() self:Escape() end,
            move=function(d) if self.items[(self.selected or 0)+d] then
                self.selected=(self.selected or 0)+d; self.api.ScrollList.RefreshVisible(self.view.list)
                if self.api.ScrollList.ScrollDataIntoView then self.api.ScrollList.ScrollDataIntoView(self.view.list,self.selected,nil,true) end
            end end,
            choose=function(item) for _,current in ipairs(self.items) do if current==item then self:Restore(item.selector); break end end end,
            inspect=function() end,
            describe=function() return self.labels.restore end,isSelected=function(item) return self.items[self.selected or 0]==item end,generation=function() return self.generation end})
        if self.view then
            self.view.add=P.Button(self.api,self.view.root,self.name..'Add',self.labels.hideEffect,function() self:OpenAdd() end)
            self.view.restoreAll=P.Button(self.api,self.view.root,self.name..'RestoreAll',self.labels.restoreAll,function() self:RestoreAll() end)
        end
    end
    if self.view then
        self.view:Place(self.options); self.view.search:SetText('',true); self.view.action:SetText(self.labels.restoreHint)
        self.view:BindInput()
        local generation=self.generation
        self.view.add:SetHandler('OnClicked',function() if generation==self.generation and self:IsOpen() then self:OpenAdd() end end)
        self.view.restoreAll:SetHandler('OnClicked',function() if generation==self.generation and self:IsOpen() then self:RestoreAll() end end)
        local y=self.view:ButtonRows({self.view.add,self.view.restoreAll},116); self.view:LayoutBody(y+6)
        self.view.root:SetHidden(false); self.view.root:BringWindowToTop(); self.view.search:TakeFocus()
    end
    self:_Refresh()
end
function HiddenList:Close()
    if not self:IsOpen() and not self.adding then return end
    local options=self.options; self.options=nil; self.generation=self.generation+1
    if self.adding then self.adding=false; self.picker:Close() end
    if self.view then self.view.search:LoseFocus(); self.view.root:SetHidden(true); self.view:SetItems({}) end
    if not self.disposed then P.RestoreFocus(options,self.api) end
end
function HiddenList:Dispose()
    if self.disposed then return end; self.disposed=true; self:Close(); self.unsubscribe()
    if self.view then self.view.search:SetHandler('OnTextChanged',nil); self.view.search:SetHandler('OnEscape',nil); self.view.search:SetHandler('OnEnter',nil); self.view.search:SetHandler('OnKeyDown',nil) end
end
