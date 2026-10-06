local T=dofile('KanaStatSources/tests/support.lua')
local K=T.load({'Core','Stats','Critical','Table'})
local function fixture()
    local a=dofile('KanaStatSources/tests/fixtures/controls.lua')()
    return K.Table.New(a,a.InformationTooltip),a
end
return {
 refresh_does_not_measure_clipped_visible_description=function()
    local v=fixture()
    local b={available=true,total=12000,rows={{name='Base value',value=12000}}}
    local bounds={width=1200,height=800,title='Maximum Stamina',description=string.rep('Native description ',6)}
    v:Render(b,'en',bounds)
    local width,height,descriptionHeight,rowY=v.width,v.height,v.description.height,v.rows[1].y
    -- A visible native label can report the layout of its constrained/truncated
    -- box. Model one missing line after a delayed update; the actual text still
    -- requires the original height measured outside that visible box.
    v.description.GetTextHeight=function()return descriptionHeight-18 end
    v.description.GetTextDimensions=function()return width,descriptionHeight-18 end
    bounds.keepLayout=true
    for _=1,5 do
        v:Render(b,'en',bounds)
        T.eq(v.width,width);T.eq(v.height,height)
        T.eq(v.description.height,descriptionHeight);T.eq(v.rows[1].y,rowY)
    end
 end,
 measurement_uses_ui_units_at_non_default_global_scale=function()
    for _,scale in ipairs({0.64,1,1.5})do
        local v,a=fixture();a.GetUIGlobalScale=function()return scale end
        v:Render({available=true,total=12000,rows={{name='A fairly long native item name',value=12000}}},'en',{width=1800,height=900,title='Maximum Stamina'})
        -- GetStringWidth is a scaled native width; GetTextDimensions is in UI
        -- units. The setter must get the latter, without applying UI scale twice.
        local expected=28+24+30*8+5*8+1
        T.eq(v.width,expected)
    end
 end,
 stats_refresh_does_not_rewrite_unchanged_description=function()
    local v=fixture()
    local b={available=true,total=12000,rows={{name='Base value',value=12000}}}
    local bounds={width=1200,height=800,title='Maximum Stamina',description='Native description'}
    v:Render(b,'en',bounds)
    local writes=0;local setText=v.description.SetText
    v.description.SetText=function(label,text)writes=writes+1;setText(label,text)end
    b.total=12001;b.rows[1].value=12001;bounds.keepLayout=true
    v:Render(b,'en',bounds)
    T.eq(writes,0);T.eq(v.rows[1].labels[2].text,'12001')
 end,
 changed_description_gets_full_new_height_without_resizing_outer_block=function()
    local v=fixture()
    local b={available=true,total=12000,rows={{name='Base value',value=12000}}}
    local bounds={width=1200,height=800,title='Maximum Stamina',description='Short description'}
    v:Render(b,'en',bounds);local width,height=v.width,v.height
    v.description.GetTextHeight=function()return 18 end
    v.description.GetTextDimensions=function()return width,18 end
    bounds.description=string.rep('Updated description ',6);bounds.keepLayout=true
    v:Render(b,'en',bounds)
    T.eq(v.width,width);T.eq(v.height,height);T.eq(v.description.height>18,true)
    T.eq(v.rows[1].y>=v.description.height+10,true)
    v:Scroll(-10000);T.eq(v.offset+v.bodyHeight,v.contentHeight)
 end,
}
