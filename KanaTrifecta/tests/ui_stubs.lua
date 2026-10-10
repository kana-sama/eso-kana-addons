local S={controls={},fragments={}}
local M={}
function M:SetDimensions(w,h) self.w,self.h=w,h end
function M:SetWidth(w) self.w=w end
function M:SetHeight(h) self.h=h end
function M:GetWidth() return self.w or 320 end
function M:GetHeight() return self.h or 20 end
function M:GetName() return self.name end
function M:GetLeft() return 0 end
function M:GetTop() return 0 end
function M:GetRight() return 1000 end
function M:GetBottom() return 200 end
function M:SetAnchor(...) self.anchor={...} end
function M:AddControl(c) self.body=c;c.parent=self end
function M:GetResizeToFitPadding() return 24,24 end
function M:SetDimensionConstraints(...) self.constraints={...} end
function M:ClearAnchors() self.anchor=nil end
function M:SetAnchorFill() end
function M:SetHidden(v) self.hidden=v end
function M:IsHidden() return self.hidden end
function S.isHidden(control) return control:IsHidden() or (control.parent and S.isHidden(control.parent)) or false end
function M:SetText(t) self.text=t end
function M:GetTextHeight() return math.ceil(#(self.text or '')/math.max(1,math.floor((self.w or 300)/10)))*20 end
function M:GetTextWidth() return #(self.text or '')*10 end
function M:SetColor(...) self.color={...} end
function M:SetHandler(k,v) self.handlers[k]=v end
function M:GetHandler(k) return self.handlers[k] end
function M:GetNamedChild(k) self.children[k]=self.children[k] or S.control(self.name..k,self);return self.children[k] end
for _,k in ipairs({'SetFont','SetHorizontalAlignment','SetVerticalAlignment','SetMouseEnabled','SetTexture','SetNormalTexture',
'SetPressedTexture','SetMouseOverTexture','SetAlpha','SetEnabled','SetDrawTier','SetDrawLayer'}) do M[k]=function(self,v) self.values[k]=v end end
function S.control(name,parent)
 local c=setmetatable({name=name,parent=parent,handlers={},children={},values={}}, {__index=M});S.controls[name]=c;return c
end
function S.api()
 local a={GuiRoot=S.control('GuiRoot'),ZO_HUD_TRACKER_MAX_WIDTH=320,ZO_SCROLL_BAR_WIDTH=16,CT_CONTROL=1,CT_LABEL=2,CT_TEXTURE=3,CT_BUTTON=4,DT_LOW=1,
 INTERFACE_COLOR_TYPE_CON_COLORS=10,CON_APPROPRIATE=2,GetInterfaceColor=function(kind,con) assert(kind==10 and con==2);return 0.9,0.9,0,1 end,
 TOPLEFT=1,TOPRIGHT=2,BOTTOMRIGHT=3,BOTTOMLEFT=4,LEFT=5,RIGHT=6,CENTER=7,TEXT_ALIGN_LEFT=0,TEXT_ALIGN_RIGHT=1,TEXT_ALIGN_CENTER=2}
 a.GuiRoot:SetDimensions(1200,800)
 a.WINDOW_MANAGER={CreateControl=function(_,n,p) return S.control(n,p) end,CreateControlFromVirtual=function(_,n,p) return S.control(n,p) end,
 CreateTopLevelWindow=function(_,n) local c=S.control(n);c.isTopLevelWindow=true;return c end}
 a.ZO_SimpleSceneFragment={New=function(_,c) local f={control=c};S.fragments[#S.fragments+1]=f;return f end}
 a.HUD_SCENE={AddFragment=function() end};a.HUD_UI_SCENE=a.HUD_SCENE
 for _,k in ipairs({'ZO_NORMAL_TEXT','ZO_HINT_TEXT','ZO_SELECTED_TEXT','ZO_SUCCEEDED_TEXT','ZO_ERROR_COLOR'}) do a[k]={UnpackRGBA=function() return 1,1,1,1 end} end
 a.questTrackerControl=S.control('Quest')
 a.FOCUSED_QUEST_TRACKER={GetTrackerControl=function() return a.questTrackerControl end}
 return a
end
return S
