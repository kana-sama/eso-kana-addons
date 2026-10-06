-- Behavioral simulation, not an ESO rendering test.
-- lua tests/compact_native_chat.lua CompactNativeChat.lua /path/to/zo_hook.lua
local module, hooks = assert(arg[1]), assert(arg[2])
unpack = table.unpack or unpack
dofile(hooks)
EVENT_PLAYER_ACTIVATED=1; EVENT_GLOBAL_MOUSE_UP=2
MOUSE_BUTTON_INDEX_LEFT=1; MOUSE_BUTTON_INDEX_RIGHT=2
TOPLEFT=1; TOPRIGHT=2; BOTTOMLEFT=3; BOTTOMRIGHT=4
CT_BACKDROP=1; CT_CONTROL=2; DT_LOW=1; DT_HIGH=3; DL_BACKGROUND=0
local function session(enabled)
    local events, created = {}, {}
    EVENT_MANAGER={RegisterForEvent=function(_,_,e,f) events[e]=f end,
        UnregisterForEvent=function(_,_,e) events[e]=nil end}
    ZO_SavedVars={NewAccountWide=function() return {compactNativeChat=enabled} end}
    local methods={}
    local function control(parent)
        local c=setmetatable({parent=parent,children={},handlers={},left=100,top=200,width=400,height=250}, {__index=methods})
        if parent then table.insert(parent.children,c) end
        return c
    end
    function methods:SetHandler(event,fn,namespace) self.handlers[event..(namespace or '')]=fn end
    function methods:GetHandler(event) return self.handlers[event] end
    function methods:Fire(event,...)
        for key,fn in pairs(self.handlers) do if key:sub(1,#event)==event then fn(self,...) end end
    end
    function methods:GetParent() return self.parent end
    function methods:GetNumChildren() return #self.children end
    function methods:GetChild(i) return self.children[i] end
    function methods:SetHidden(v) self.hidden=v end
    function methods:SetMouseEnabled(v) self.mouse=v end
    function methods:SetAlpha(v) self.alpha=v end
    function methods:SetMovable(v) self.movable=v end
    function methods:ClearAnchors() end
    function methods:SetAnchor(_,_,_,x,y) self.left=x; self.top=y end
    function methods:SetAnchorFill(target) self.fill=target end
    function methods:SetDimensions(w,h) self.width=w; self.height=h end
    function methods:SetWidth(w) self.width=w end
    function methods:SetHeight(h) self.height=h end
    function methods:GetLeft() return self.left end
    function methods:GetTop() return self.top end
    function methods:GetWidth() return self.width end
    function methods:GetHeight() return self.height end
    function methods:ShowFadedLines() self.reveals=(self.reveals or 0)+1 end
    for _,name in ipairs({'SetDrawTier','SetDrawLayer','SetCenterColor','SetEdgeColor','SetEdgeTexture','SetDimensionConstraints','SetResizeHandleSize'}) do methods[name]=function() end end
    WINDOW_MANAGER={CreateControl=function(_,name,parent) local c=control(parent); created[name]=c; return c end}
    GuiRoot=control()
    local root=control(GuiRoot)
    local content=control(root)
    local tab=control(root)
    local decoration=control(root)
    local entry=control(root); ZO_ChatWindowTextEntry=entry
    local buffer=control(content)
    local c={control=root,windowContainer=content,windows={{tab=tab,buffer=buffer}},currentBuffer=buffer,
        system={minContainerWidth=300,minContainerHeight=170,maxContainerWidth=550,maxContainerHeight=380},locked=true,saves=0}
    function c:IsLocked() return self.locked end
    function c:SaveSettings() self.saves=self.saves+1 end
    function c:ShowContextMenu(index) self.menu=index end
    function c:FadeIn() error('native container fade must be suppressed') end
    function c:FadeOut() error('native container fade must be suppressed') end
    function c:PerformLayout() content.fill=nil; decoration:SetHidden(false) end
    function c:SetAsPrimary() end
    function c:UpdateInteractivity() buffer:SetMouseEnabled(false) end
    function c:UpdateScrollVisibility() end
    CHAT_SYSTEM={primaryContainer=c,IsMinimized=function() return true end,Maximize=function(self) self.maximized=true end}
    AetherChat={Messenger={UndockNativeChatEntry=function() entry.parent=root; entry:SetHidden(false) end}}
    local x,y,hover=250,300,false
    GetUIMousePosition=function() return x,y end
    MouseIsOver=function() return hover end
    ZO_ChatSystem_OnMouseWheel=function(_,delta) c.scroll=(c.scroll or 0)+delta end
    dofile(module); events[EVENT_PLAYER_ACTIVATED]()
    if not enabled then assert(not next(created)); assert(not next(root.handlers)); return end
    assert(CHAT_SYSTEM.maximized)
    assert(content.fill==root and decoration.hidden and tab.hidden and entry.hidden)
    decoration:SetHidden(false); assert(decoration.hidden)
    entry.parent=control(); entry:SetHidden(false); assert(not entry.hidden,'AetherChat input was hidden')
    AetherChat.Messenger.UndockNativeChatEntry(); assert(entry.hidden)
    c:PerformLayout(); c:UpdateInteractivity(); assert(content.fill==root and buffer.mouse)
    local bg=created.KanaAetherChat_CompactNativeChatBackground
    hover=true; root:Fire('OnUpdate'); assert(not bg.hidden and buffer.reveals==1)
    hover=false; root:Fire('OnUpdate'); assert(bg.hidden)
    c:FadeIn(); c:FadeOut(); assert(root.alpha==1)
    buffer:Fire('OnMouseUp',2,true); assert(c.menu==1)
    buffer:Fire('OnMouseWheel',1); assert(c.scroll==-1)
    buffer:Fire('OnMouseDown',1); x=x+30; y=y+40; root:Fire('OnUpdate')
    assert(root.left==100 and root.top==200,'locked chat moved')
    c.locked=false; root:Fire('OnUpdate')
    buffer:Fire('OnMouseDown',1); x=x+30; y=y+40; root:Fire('OnUpdate'); events[EVENT_GLOBAL_MOUSE_UP]()
    assert(root.left==130 and root.top==240 and c.saves==1)
    -- Route clicks through actual chat surfaces, not synthetic edge controls.
    x=root.left+2; y=root.top+100
    buffer:Fire('OnMouseDown',1); x=1000; root:Fire('OnUpdate'); events[EVENT_GLOBAL_MOUSE_UP]()
    assert(root.width==300 and root.left==230,'minimum resize must preserve opposite edge')
    x=root.left+100; y=root.top+root.height-2
    content:Fire('OnMouseDown',1); y=1000; root:Fire('OnUpdate'); events[EVENT_GLOBAL_MOUSE_UP]()
    assert(root.height==380,'maximum height exceeded')
    c.locked=true; root:Fire('OnUpdate')
    local saves=c.saves
    x=root.left+root.width-2; y=root.top+root.height-2
    buffer:Fire('OnMouseDown',1); y=0; root:Fire('OnUpdate'); events[EVENT_GLOBAL_MOUSE_UP]()
    assert(root.height==380 and c.saves==saves,'locked chat resized')
    c.locked=false
    for _,surface in ipairs({root,content,buffer}) do
        for _,edge in ipairs({'left','right','top','bottom','top-left','top-right','bottom-left','bottom-right'}) do
            root.left=100; root.top=200; root.width=400; root.height=250
            local left=edge:find('left',1,true); local right=edge:find('right',1,true)
            local top=edge:find('top',1,true); local bottom=edge:find('bottom',1,true)
            x=left and 102 or right and 498 or 300
            y=top and 202 or bottom and 448 or 325
            surface:Fire('OnMouseDown',1); x=x+20; y=y+20
            root:Fire('OnUpdate'); events[EVENT_GLOBAL_MOUSE_UP]()
            assert(root.width==(left and 380 or right and 420 or 400),edge..' width')
            assert(root.height==(top and 230 or bottom and 270 or 250),edge..' height')
            assert(root.left==(left and 120 or 100),edge..' left')
            assert(root.top==(top and 220 or 200),edge..' top')
        end
    end
end
session(false); print('PASS disabled mode leaves native UI untouched')
session(true); print('PASS hover, menu, scrolling, locked/unlocked drag, all edges and corners on each chat surface, shared input')
