local K=KanaArchiveAssist
local B={};K.ChoiceButton=B
function B.New(api,capture)
 return setmetatable({api=api,capture=capture},{__index=B})
end
function B:Layout()
 if not self.control or self.control:IsHidden()then return end
 local a=self.api;local width=math.max(0,math.min(self.preferredWidth,a.GuiRoot:GetWidth()-64))
 if width~=self.width then self.width=width;self.control:SetWidth(width);self.check.label:SetWidth(math.max(0,width-28))end
 local bottom=64;local strip=a.ZO_KeybindStripControl
 if strip and not strip:IsHidden()then bottom=math.max(bottom,(a.GuiRoot:GetBottom()-strip:GetTop())/self.control:GetScale()+16)end
 if bottom~=self.bottom then
  self.bottom=bottom;self.control:ClearAnchors();self.control:SetAnchor(a.BOTTOMRIGHT,a.GuiRoot,a.BOTTOMRIGHT,-32,-bottom)
 end
end
function B:Refresh(offer)
 self.offer=offer
 if not offer or not self.capture.offer or self.capture.offer.offerId~=offer.offerId or self.capture.pending then
  self.offerId=nil;if self.control then self.control:SetHidden(true);self.root:SetHidden(true)end;return
 end
 local a=self.api
 if not self.control then
  -- A control attached directly to GuiRoot has no window to render it.
  self.root=a.WINDOW_MANAGER:CreateTopLevelWindow('KanaArchiveAssistChoiceOverlay')
  self.root:SetAnchorFill(a.GuiRoot);self.root:SetDrawTier(a.DT_HIGH);self.root:SetMouseEnabled(false);self.root:SetHidden(true)
  local b=a.WINDOW_MANAGER:CreateControl('KanaArchiveAssistChoiceRow',self.root,a.CT_CONTROL);self.control=b
  b:SetDimensions(300,32);b:SetMouseEnabled(false);b:SetExcludeFromResizeToFitExtents(true)
  b:SetDrawTier(a.DT_HIGH)
  local check=a.WINDOW_MANAGER:CreateControlFromVirtual('KanaArchiveAssistIncludeChoice',b,'ZO_CheckButton');self.check=check
  check:SetDimensions(20,20);check:SetAnchor(a.LEFT,b,a.LEFT,0,0);check:SetMouseEnabled(true)
  a.ZO_CheckButton_SetLabelText(check,'учитывать выбор')
  check.label:SetFont('ZoFontGame');check.label:ClearAnchors();check.label:SetAnchor(a.LEFT,check,a.RIGHT,8,0)
  self.preferredWidth=28+check.label:GetTextWidth()
  a.ZO_CheckButton_SetToggleFunction(check,function(_,checked)
   self.capture:SetExcluded(self.offerId,not checked);self:Refresh(self.offer)
  end)
  b:SetHandler('OnUpdate',function()self:Layout()end)
 end
 self.offerId=offer.offerId
 a.ZO_CheckButton_SetCheckState(self.check,not self.capture:IsExcluded(offer.offerId))
 self.root:SetHidden(false);self.control:SetHidden(false);self:Layout()
end
