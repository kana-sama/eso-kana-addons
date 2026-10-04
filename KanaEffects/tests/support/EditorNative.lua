-- Recording native boundary only. All Session/Rules/Runtime behavior stays real.
TestSupport.EditorNative={}
function TestSupport.EditorNative.New()
    local api=TestSupport.NativeRecording.New(); api.language='ru'; api.constants.DT_HIGH=3; api.constants.SCENE_SHOWING='showing'; api.constants.ZO_COMBOBOX_SUPPRESS_UPDATE=2
    api.ContextMenu=function(control,items) api.contextMenu={owner=control,items=items}; return true end
    api.GetContextMenu=function() return api.contextMenu end
    local create=api.controls.CreateControl; local top=api.controls.CreateTopLevelWindow
    local function extend(c)
        function c:SetClampedToScreen(v) self.clamped=v end
        function c:SetMovable(v) self.movable=v end
        function c:StartMoving() self.moving=true end
        function c:StopMovingOrResizing() self.moving=false end
        function c:SetEnabled(v) self.enabled=v end
        function c:GetName() return self.name end
        function c:GetLeft() return (self.anchor and self.anchor.x or 0)+(self.parent and self.parent:GetLeft() or 0) end
        function c:GetTop() return (self.anchor and self.anchor.y or 0)+(self.parent and self.parent:GetTop() or 0) end
        function c:GetDimensions() return self.width or 0,self.height or 0 end
        function c:GetText() return self.text or '' end
        function c:GetTextDimensions() return #(self.text or '')*7,18 end
        function c:SetMaxInputChars(v) self.maxChars=v end
        function c:SetEditEnabled(v) self.editEnabled=v end
        function c:SetMultiLine(v) self.multiLine=v end
        function c:SetNewLineEnabled(v) self.newLine=v end
        function c:SetSelectAllOnFocus(v) self.selectAll=v end
        function c:SetResizeToFitDescendents(v) self.resizeFit=v end
        function c:SetDrawTier(v) self.tier=v end
        function c:BringWindowToTop() api.topSequence=(api.topSequence or 0)+1; self.topSequence=api.topSequence; api.topWindow=self end
        function c:TakeFocus() self.focus=true end
        function c:HasFocus() return self.focus==true end
        function c:LoseFocus() local had=self.focus; self.focus=false; if had and self.handlers.OnFocusLost then self.handlers.OnFocusLost(self) end end
        function c:GetNamedChild(key) return self.children and self.children[key] end
        return c
    end
    api.controls.CreateControl=function(...) return extend(create(...)) end
    api.controls.CreateTopLevelWindow=function(...) return extend(top(...)) end
    api.controls.CreateControlFromVirtual=function(name,parent,template)
        local c=api.controls.CreateControl(name,parent,template); c.template=template
        -- ESO ButtonControl exposes SetText, but only its Label has GetText.
        if template=='ZO_DefaultTextButton' or template=='ZO_DefaultButton' or template=='ZO_ButtonBehaviorClickSound' or template=='ZO_CloseButton' or template=='ZO_CheckButton_Text' or template=='ZO_PlusButton' or template=='ZO_MinusButton' then c.GetText=nil end
        if template=='ZO_CheckButton_Text' then c.checkedText='ON'; c.uncheckedText='OFF' end
        if template=='ZO_ScrollContainer' then
            c.children={}; local scroll=api.controls.CreateControl(name..'Scroll',c,'scroll'); c.children.Scroll=scroll
            scroll.children={Child=api.controls.CreateControl(name..'ScrollChild',scroll,'control')}
        end
        return c
    end
    api.ComboBox=function(c)
        local combo={items={}}
        function combo:SetSelectedItem(text) self.selectedText=text end
        function combo:SetSortsItems(v) self.sort=v end
        function combo:SetEnabled(v) self.enabled=v end
        function combo:ClearItems() self.items={} end
        function combo:IsDropdownVisible() return self.visible==true end
        function combo:HideDropdown() self.visible=false end
        function combo:CreateItemEntry(title,callback) return {name=title,callback=callback} end
        function combo:AddItem(entry,suppress) TestSupport.Assert.Equal(suppress,2); self.items[#self.items+1]=entry end
        function combo:SelectItem(entry,ignore) self.selected=entry; if not ignore then entry.callback() end end
        c.combo=combo; return combo
    end
    api.CheckButton={SetLabelText=function(c,t) c.label=t end,SetCheckState=function(c,v) c.checked=v; if c.checkedText then c:SetText(v and c.checkedText or c.uncheckedText) end end,SetToggleFunction=function(c,fn) c.toggle=fn end,IsChecked=function(c) return c.checked end}
    api.Scroll={UpdateScrollBar=function(c) c.scrollUpdates=(c.scrollUpdates or 0)+1 end}
    api.layers={}; api.PushActionLayerByName=function(name) api.layers[name]=true end; api.RemoveActionLayerByName=function(name) api.layers[name]=nil end
    api.messages={}; api.LocalMessage=function(t) api.messages[#api.messages+1]=t end
    api.hudEditorScene={callbacks={}}
    function api.hudEditorScene:RegisterCallback(event,fn) self.callbacks[fn]=event end
    function api.hudEditorScene:UnregisterCallback(event,fn) self.callbacks[fn]=nil end
    return api
end
