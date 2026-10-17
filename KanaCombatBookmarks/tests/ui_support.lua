local T = dofile('KanaCombatBookmarks/tests/support.lua')
return function()
    local a = T.api()
    for i,name in ipairs({'TOPLEFT','TOPRIGHT','BOTTOMLEFT','BOTTOMRIGHT','TOP','BOTTOM','LEFT','RIGHT','CENTER','CT_LABEL','CT_CONTROL','CT_BUTTON','CT_BACKDROP','CT_TEXTURE','CT_SCROLL','DL_BACKGROUND','DL_CONTROLS','DL_OVERLAY','TEXT_ALIGN_CENTER','TEXT_WRAP_MODE_ELLIPSIS','TEXT_ALIGN_LEFT','EVENT_REASON_HARDWARE'}) do a[name]=i end
    a.visible = 20
    a.pending={}
    a.zo_callLater=function(fn)a.pending[#a.pending+1]=fn end
    function a:flush()local q=self.pending;self.pending={};for _,fn in ipairs(q)do fn()end end
    a.GetString = function(id) return id == 'font' and 'font' or '14' end
    a.SI_COMBAT_METRICS_STD_FONT='font'; a.SI_COMBAT_METRICS_FONT_SIZE='size'; a.SI_COMBAT_METRICS_FONT_SIZE_SMALL='size'
    local C={}; C.__index=C
    local all={}
    local function new(name,parent)
        local c=setmetatable({name=name,parent=parent,children={},order={},handlers={},anchors={},width=500,height=200,messages={},total=0,position=0},C)
        if name then all[name]=c end
        if parent then parent.order[#parent.order+1]=c end
        return c
    end
    local function child(parent,key)
        local c=new(parent.name..key,parent); parent.children[key]=c; return c
    end
    function C:GetNamedChild(key) return self.children[key] end
    function C:GetParent() return self.parent end
    function C:GetName() return self.name end
    function C:GetNumChildren() return #self.order end
    function C:GetChild(i) return self.order[i] end
    function C:SetHandler(k,v) self.handlers[k]=v end
    function C:GetHandler(k) return self.handlers[k] end
    function C:SetHidden(v) self.hidden=v end
    function C:IsHidden() return self.hidden or (self.parent and self.parent:IsHidden()) or false end
    function C:SetMouseEnabled(v) self.mouse=v end
    function C:SetAlpha(v) self.alpha=v end
    function C:GetAlpha() return self.alpha or 1 end
    function C:SetFont(v) self.font=v end
    function C:SetColor(...) self.color={...} end
    function C:SetCenterColor(...) self.centerColor={...} end
    function C:SetEdgeColor(...) self.edgeColor={...} end
    function C:SetEdgeTexture(...) self.edgeTexture={...} end
    function C:SetDrawLayer(v) self.drawLayer=v end
    function C:SetDrawLevel(v) self.drawLevel=v end
    function C:SetMaxLineCount(v) self.maxLines=v end
    function C:SetWrapMode(v) self.wrapMode=v end
    function C:SetHorizontalAlignment(v) self.horizontalAlignment=v end
    function C:SetVerticalAlignment(v) self.verticalAlignment=v end
    function C:SetAnchorFill(relative)
        self:ClearAnchors();self:SetAnchor(a.TOPLEFT,relative,a.TOPLEFT);self:SetAnchor(a.BOTTOMRIGHT,relative,a.BOTTOMRIGHT)
    end
    function C:SetWidth(v) self.width=v end
    function C:SetHeight(v) self.height=v end
    function C:SetDimensions(w,h) self.width,self.height=w,h end
    function C:GetWidth() return self.width end
    function C:GetHeight() if self.name and self.name:match('CombatLogWindowBuffer$') then return a.visible*14 end;if self.name and self.name:match('CombatLogWindow$') then return self.parent.height-28 end;return self.height end
    function C:SetResizeToFitDescendents(v) self.resizeToFit=v end
    function C:GetFontHeight() return tonumber((self.font or ''):match('|([%d.]+)|')) or 14 end
    function C:SetText(v) self.text=v end
    function C:GetText() return self.text end
    function C:GetStringWidth(text) return #(text or '')*4*self:GetFontHeight()/14 end
    function C:GetTextWidth() return self:GetStringWidth(self.text) end
    function C:GetTextHeight()
        local lines=(self.text or ''):find('wrapped',1,true) and (self.width<300 and 4 or 3) or 1
        if (self.text or ''):find('\n') then lines=lines+1 end
        return lines*self:GetFontHeight()
    end
    function C:SelectAll() self.selected=true end
    function C:TakeFocus() self.focused=true end
    function C:ClearAnchors() self.anchors={} end
    function C:SetAnchor(point,relative,to,x,y)
        local anchor={true,point,relative,to,x or 0,y or 0}
        for i,v in ipairs(self.anchors) do if v[2]==point then self.anchors[i]=anchor;return end end
        self.anchors[#self.anchors+1]=anchor
    end
    function C:GetAnchor(i) local v=self.anchors[i+1]; if v then return (table.unpack or unpack)(v) end;return false end
    function C:Clear() self.messages={};self.total=0;self.position=0 end
    function C:SetMaxHistoryLines(n) self.maxHistory=n end
    function C:GetMaxHistoryLines() return self.maxHistory end
    function C:AddMessage(text,r,g,b)
        if a.rejectWhitespace and not text:find('%S') then return end
        -- Native history counts messages, not the visual rows of wrapped text.
        local lines=1
        self.messages[#self.messages+1]={text=text,before=self.total,after=self.total+lines,color={r,g,b}}
        self.total=self.total+lines
    end
    function C:GetNumHistoryLines() return self.total end
    function C:GetNumVisibleLines()
        if a.emptyVisibleZero and self.total==0 then return 0 end
        return a.visible
    end
    function C:GetScrollPosition() return self.position end
    function C:SetScrollPosition(v) assert(v==math.floor(v),'native scroll offset must be an integer');self.position=v end
    function C:SetMinMax(min,max) self.min,self.max=min,max end
    function C:GetMinMax() return self.min or 0,self.max or 0 end
    function C:SetValue(v) self.value=v end
    function C:GetValue() return self.value or 0 end
    function C:SetThumbTextureHeight(v) self.thumb=v end
    a.WINDOW_MANAGER={CreateControl=function(_,name,parent,kind) local c=new(name,parent);c.controlType=kind;return c end,
        CreateControlFromVirtual=function(_,name,parent,template)
            assert(template=='ZO_ScrollContainer');local c=new(name,parent);c.template=template
            local viewport=child(c,'Scroll');local content=child(viewport,'Child');c.children.ScrollChild=content;return c
        end}
    a.ZO_Scroll_UpdateScrollBar=function(c) c.extent=math.max(0,c:GetNamedChild('ScrollChild').height-c.height) end
    a.ZO_Scroll_OnMouseWheel=function(c,delta) c.offset=math.max(0,math.min(c.extent or 0,(c.offset or 0)-delta*30)) end
    a.ZO_Scroll_ScrollAbsoluteInstantly=function(c,offset) c.offset=offset end
    a.GetControl=function(c,name)return c:GetNamedChild(name)end
    a.ZO_PreHookHandler=function(c,name,fn)
        local old=c:GetHandler(name);c:SetHandler(name,function(...)fn(...);if old then return old(...)end end)
    end
    local report=new('CombatMetrics_Report')
    a.CombatMetrics_Report=report
    report.Update=function()end
    local panel=new('CombatMetrics_Report_MainPanelCombatLog',report)
    a.CombatMetrics_Report_MainPanelCombatLog=panel
    local header=child(panel,'Header');local pages=child(header,'PageButtonRow')
    panel.children.HeaderPageButtonRow=pages
    function pages:Update(page,max) self.page,self.max=page,max end
    for _,key in ipairs({'PageLeft','Page1','Page2','Page3','Page4','Page5','PageRight'}) do
        local c=child(pages,key)
        c.func=key=='PageLeft' and -1 or 1
        c.value=tonumber(key:match('%d'))
        c:SetHandler('OnMouseUp',function()a.nativeNavigation=(a.nativeNavigation or 0)+1 end)
    end
    local window=child(panel,'Window');local buffer=child(window,'Buffer');local slider=child(window,'Slider')
    local copy=child(panel,'CopyPasteBox');copy.hidden=true
    child(panel,'Sep')
    local copyButton=child(header,'CopyPaste');panel.children.HeaderFilterButtonRowCopyPaste=copyButton
    copyButton:SetHandler('OnMouseUp',function() a.CMX.db.FightReport.CLSelection.CopyPaste=not a.CMX.db.FightReport.CLSelection.CopyPaste;window:SetHidden(a.CMX.db.FightReport.CLSelection.CopyPaste);copy:SetHidden(not a.CMX.db.FightReport.CLSelection.CopyPaste);panel:Update() end)
    for _,c in ipairs({window,copy}) do c:SetAnchor(a.TOPLEFT,panel,a.TOPLEFT,0,28);c:SetAnchor(a.BOTTOMRIGHT,panel,a.BOTTOMRIGHT,-4,-4) end
    buffer:SetHandler('OnMouseWheel',function(_,delta)buffer.position=buffer.position+delta;slider:SetValue(buffer.total-buffer.position)end)
    function panel:Update() a.nativeUpdates=(a.nativeUpdates or 0)+1 end
    a.CMX.GenerateSelectionStats=function(_,_,s)return s end
    a.CMX.GetAbilityStats=function()return {a.fight,{}}end
    a.CMX.GetCombatLogString=function(_,line) return line.text or ('event '..line[2]),{1,1,1}end
    a.CMX.db.FightReport={scale=1,CLSelection={[4]=true}}
    local adapter={selections={unit={},ability={},buff={},resource={}},GetViewedFight=function()return a.fight end}
    a.adapter=adapter
    a.controls={report=report,panel=panel,pages=pages,window=window,buffer=buffer,slider=slider,copy=copy}
    return a
end
