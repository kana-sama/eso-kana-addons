local KW=KanaWardrobe
KW.SoftPanel={}

-- A single translucent rectangle, bounded by the window itself.
function KW.SoftPanel.New(parent,name)
 local tile=WINDOW_MANAGER:CreateControl(name,parent,CT_TEXTURE)
 -- Reuse only the constant dark center (alpha 210/255), excluding the feather.
 tile:SetTexture("eso-kana-addons/KanaWardrobe/assets/panel_feather.dds")
 tile:SetTextureCoords(.375,.625,.375,.625)
 tile:SetColor(1,1,1,1)
 tile:SetDrawLayer(DL_BACKGROUND);tile:SetMouseEnabled(false)
 local surface={tiles={tile}}
 function surface:Layout(width,height)
  tile:ClearAnchors();tile:SetAnchor(TOPLEFT,parent,TOPLEFT,0,0)
  tile:SetDimensions(width,height)
 end
 function surface:SetHidden(hidden)
  tile:SetHidden(hidden)
 end
 return surface
end
