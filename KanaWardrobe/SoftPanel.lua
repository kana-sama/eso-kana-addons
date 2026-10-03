local KW=KanaWardrobe
KW.SoftPanel={}

-- Nine texture slices: the middle stretches, the feathered edges never do.
-- No image borders, clipping, input handlers or changes to native UI textures.
function KW.SoftPanel.New(parent,name)
 local surface={tiles={}}
 -- Store transparency in the DDS alpha channel, independently of vertex
 -- tint or control animation. Slice only the constant center when resizing.
 local uv={0,.25,.75,1}
 for row=1,3 do
  for col=1,3 do
   local tile=WINDOW_MANAGER:CreateControl(name..row..col,parent,CT_TEXTURE)
   tile:SetTexture("eso-kana-addons/KanaWardrobe/assets/panel_feather.dds")
   tile:SetTextureCoords(uv[col],uv[col+1],uv[row],uv[row+1])
   tile:SetColor(1,1,1,1)
   tile:SetDrawLayer(DL_BACKGROUND);tile:SetMouseEnabled(false)
   surface.tiles[#surface.tiles+1]=tile
  end
 end
 function surface:Layout(width,height)
  local inset=math.min(16,width/4)
  local xs={-16,inset,width-inset,width+16}
  local ys={-24,0,height,height+40}
  for row=1,3 do for col=1,3 do
   local tile=self.tiles[(row-1)*3+col]
   tile:ClearAnchors();tile:SetAnchor(TOPLEFT,parent,TOPLEFT,xs[col],ys[row])
   tile:SetDimensions(xs[col+1]-xs[col],ys[row+1]-ys[row])
  end end
 end
 function surface:SetHidden(hidden)
  for _,tile in ipairs(self.tiles)do tile:SetHidden(hidden)end
 end
 return surface
end
