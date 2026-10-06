local K=KanaStatSources
local Table={};K.Table=Table
local View={};View.__index=View
function Table.New(api,tooltip)
    local v=setmetatable({api=api,tooltip=tooltip,rows={},headers={},offset=0},View)
    local function control(parent,kind)return api.WINDOW_MANAGER:CreateControl(nil,parent,kind)end
    v.control=control(tooltip,api.CT_CONTROL);v.control:SetHidden(true)
    v.body=control(v.control,api.CT_SCROLL);v.body:SetScrollBounding(api.SCROLL_BOUNDING_CONTAINED)
    v.content=control(v.body,api.CT_CONTROL)
    local function label(parent)
        local l=control(parent,api.CT_LABEL);l:SetFont('ZoFontGame');l:SetColor(0.9,0.9,0.9,1);return l
    end
    v.makeLabel=label
    for i=1,3 do v.headers[i]=label(v.control);v.headers[i]:SetColor(0.75,0.72,0.56,1) end
    v.footer=label(v.control)
    v.body:SetMouseEnabled(true)
    v.body:SetHandler('OnMouseWheel',function(_,delta)v:Scroll(delta)end)
    return v
end
function View:Clear()
    self.control:SetHidden(true);self.inserted=false;self.offset=0;self.body:SetVerticalScroll(0)
end
function View:Scroll(delta)
    self.offset=math.max(0,math.min(math.max(0,(self.contentHeight or 0)-(self.bodyHeight or 0)),self.offset-delta*36))
    self.body:SetVerticalScroll(self.offset)
end
function View:Render(b,language,bounds)
    bounds=bounds or {};local api=self.api
    local scale=bounds.scale or 1;if not K.Core.Finite(scale) or scale<=0 then scale=1 end
    local screenWidth=(bounds.width or api.GuiRoot:GetWidth())/scale
    local screenHeight=(bounds.height or api.GuiRoot:GetHeight())/scale
    local width=math.max(1,math.min(screenWidth-32,math.max(1,self.tooltip:GetWidth()-32)))
    local available=math.max(0,screenHeight-(bounds.nativeHeight or 0)-32)
    local widths={width*0.54,width*0.22,width*0.22};local xs={0,width*0.55,width*0.78}
    local headerHeight=18
    for i,key in ipairs({'source','bonus','value'}) do
        local l=self.headers[i];l:ClearAnchors();l:SetDimensions(widths[i],0);l:SetText(K.Stats.Text(language,key));headerHeight=math.max(headerHeight,l:GetTextHeight());l:SetAnchor(api.TOPLEFT,self.control,api.TOPLEFT,xs[i],0)
    end
    for i=1,3 do self.headers[i]:SetDimensions(widths[i],headerHeight)end
    local footer=K.Stats.Text(language,b.critical and 'rating' or 'total')..': '..(b.available and K.Stats.Number(b.total,language) or K.Stats.Text(language,'unavailable'))
    if b.critical then footer=footer..'\n'..K.Critical.Formula(b.critical,language) end
    if b.preview then footer=footer..'\n'..K.Stats.Text(language,'preview')..': +'..K.Stats.Number(b.preview.amount,language)..' → '..K.Stats.Number(b.preview.total,language) end
    self.footer:SetDimensions(width,0);self.footer:SetText(footer);self.footer:SetHidden(false)
    local footerHeight=self.footer:GetTextHeight()+4;local y=0
    for i,row in ipairs(b.rows or {}) do
        local r=self.rows[i]
        if not r then r={labels={self.makeLabel(self.content),self.makeLabel(self.content),self.makeLabel(self.content)}};self.rows[i]=r;r.labels[3]:SetHorizontalAlignment(api.TEXT_ALIGN_RIGHT)end
        local bonus='—'
        if row.amount~=nil then bonus=K.Stats.Number(row.amount,language,(row.operation=='percent' or row.operation=='criticalChance') and 2 or 0);if row.operation=='percent' or row.operation=='criticalChance' then bonus=bonus..'%'end end
        if row.operation=='percent' and K.Core.Finite(row.base) then bonus=bonus..' × '..K.Stats.Number(row.base,language)end
        local values={row.labelKey and K.Stats.Text(language,row.labelKey) or row.label or row.key,bonus,K.Stats.Number(row.value,language)}
        local h=18
        for col,l in ipairs(r.labels)do l:ClearAnchors();l:SetDimensions(widths[col],0);l:SetText(values[col]);l:SetHidden(false);h=math.max(h,l:GetTextHeight())end
        for col,l in ipairs(r.labels)do l:SetDimensions(widths[col],h);l:SetAnchor(api.TOPLEFT,self.content,api.TOPLEFT,xs[col],y)end
        r.y=y;r.height=h;y=y+h+3
    end
    for i=#(b.rows or {})+1,#self.rows do for _,l in ipairs(self.rows[i].labels)do l:SetHidden(true)end end
    self.contentHeight=y
    -- Reserve a positive viewport before fitting the complete block. A zero
    -- height scroll control cannot expose any source regardless of its offset.
    self.bodyHeight=math.max(math.min(y,24),math.min(y,available-headerHeight-footerHeight-8))
    if y>self.bodyHeight then
        self.footer:SetText(footer..'\n'..K.Stats.Text(language,'scroll'))
        footerHeight=self.footer:GetTextHeight()+4
        self.bodyHeight=math.max(math.min(y,24),math.min(y,available-headerHeight-footerHeight-8))
    end
    self.height=headerHeight+footerHeight+self.bodyHeight+8
    -- Even a tiny viewport keeps the footer within the remaining space.
    local fit=math.min(1,available/math.max(1,self.height));self.control:SetScale(fit)
    self.height=self.height*fit
    self.control:SetDimensions(width,headerHeight+footerHeight+self.bodyHeight+8)
    self.body:ClearAnchors();self.body:SetAnchor(api.TOPLEFT,self.control,api.TOPLEFT,0,headerHeight+4);self.body:SetDimensions(width,self.bodyHeight)
    self.content:ClearAnchors();self.content:SetAnchor(api.TOPLEFT,self.body,api.TOPLEFT);self.content:SetDimensions(width,y)
    self.footer:ClearAnchors();self.footer:SetDimensions(width,footerHeight);self.footer:SetAnchor(api.TOPLEFT,self.control,api.TOPLEFT,0,headerHeight+self.bodyHeight+8)
    self:Scroll(0);self.control:SetHidden(false)
    if not self.inserted then self.tooltip:AddVerticalPadding(3);self.tooltip:AddControl(self.control);self.control:ClearAnchors();self.control:SetAnchor(api.CENTER);self.inserted=true end
end
