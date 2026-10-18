loadModule('Layout')
local Layout = KanaBuffPanels.Layout
local metrics = {width=40,height=40,labelHeight=20,gap=5}
function Tests.six_growth_combinations()
    local cases = {
        {1,1, {0,45,90}}, {1,2, {0,-45,-90}}, {1,3, {-45,0,45}},
        {2,1, {0,65,130}}, {2,2, {0,-65,-130}}, {2,3, {-75,-10,55}},
    }
    for _, case in ipairs(cases) do
        local r = Layout.Place(3,case[1],case[2],metrics)
        for i, expected in ipairs(case[3]) do
            near(r.centers[i][case[1]==1 and 'x' or 'y'], expected)
            if case[1]==2 then near(r.centers[i].x,0) end
        end
    end
end
function Tests.bounds_center_only_along_growth_axis_for_even_and_odd_counts()
    for _, count in ipairs({1,2,3,20}) do
        for axis=1,2 do
            local r = Layout.Place(count,axis,3,metrics)
            if axis==1 then near(r.bounds.x+r.bounds.width/2,0)
            else near(r.bounds.y+r.bounds.height/2,0) end
            for _,center in ipairs(r.centers) do near(center[axis==1 and 'y' or 'x'],0) end
        end
    end
    local r=Layout.Place(2,2,3,metrics)
    near(r.centers[1].y,-42.5);near(r.centers[2].y,22.5)
end
function Tests.empty_panel_is_selectable_without_fake_icons()
    local r=Layout.Place(0,1,1,metrics)
    eq(#r.centers,0);eq(r.bounds.width,130);eq(r.bounds.height,40)
end
function Tests.empty_preview_shows_orientation_and_keeps_growth_origin()
    for _,m in ipairs({metrics,{width=46,height=46,labelHeight=40,gap=5}}) do
        for axis=1,2 do for growth=1,3 do
            local empty=Layout.Place(0,axis,growth,m)
            local populated=Layout.Place(3,axis,growth,{width=m.width,height=m.height,labelHeight=m.labelHeight,gap=m.gap,hasDuration={false,false,false}})
            eq(#empty.centers,0)
            if axis==1 then assert(empty.bounds.width>empty.bounds.height)
            else assert(empty.bounds.height>empty.bounds.width) end
            for _,key in ipairs({'x','y','width','height'}) do near(empty.bounds[key],populated.bounds[key]) end
        end end
    end
end
function Tests.one_way_anchor_stays_on_first_icon()
    for axis=1,2 do for growth=1,2 do for _,count in ipairs({1,2,20}) do
        local r=Layout.Place(count,axis,growth,metrics)
        near(r.centers[1].x,0);near(r.centers[1].y,0)
    end end end
end
function Tests.tall_labels_change_spacing_without_mutating_metrics()
    local m={width=46,height=46,labelHeight=40,gap=5}
    local r=Layout.Place(2,2,1,m)
    near(r.centers[2].y,91);eq(r.bounds.height,177)
    eq(m.labelHeight,40);eq(metrics.height,40)
end
function Tests.permanent_effects_keep_native_gap_in_every_timer_position()
    for timerPosition=1,4 do for axis=1,2 do for growth=1,3 do
        local m={width=40,height=40,labelWidth=40,labelHeight=20,gap=5,timerPosition=timerPosition,hasDuration={false,false,false}}
        local r=Layout.Place(3,axis,growth,m)
        local coordinate=axis==1 and 'x' or 'y'
        near(math.abs(r.centers[2][coordinate]-r.centers[1][coordinate]),45)
        near(math.abs(r.centers[3][coordinate]-r.centers[2][coordinate]),45)
    end end end
end
function Tests.mixed_timer_rectangles_do_not_overlap_in_any_direction()
    for timerPosition=1,4 do for axis=1,2 do for growth=1,3 do
        local m={width=40,height=40,labelWidth=40,labelHeight=20,gap=5,timerPosition=timerPosition,hasDuration={false,true,false}}
        local r=Layout.Place(3,axis,growth,m);local boxes={}
        for i,c in ipairs(r.centers) do
            local box={left=c.x-20,right=c.x+20,top=c.y-20,bottom=c.y+20}
            if i==2 then
                if timerPosition==1 then box.bottom=box.bottom+20
                elseif timerPosition==2 then box.left=box.left-45
                elseif timerPosition==3 then box.right=box.right+45 end
            end
            boxes[i]=box
            assert(box.left>=r.bounds.x-.001 and box.right<=r.bounds.x+r.bounds.width+.001)
            assert(box.top>=r.bounds.y-.001 and box.bottom<=r.bounds.y+r.bounds.height+.001)
        end
        for i=2,3 do
            local a,b=boxes[i-1],boxes[i]
            local gap=axis==1 and math.max(b.left-a.right,a.left-b.right) or math.max(b.top-a.bottom,a.top-b.bottom)
            near(gap,5)
        end
        if growth==3 then
            if axis==1 then near(r.bounds.x+r.bounds.width/2,0)
            else near(r.bounds.y+r.bounds.height/2,0) end
        else near(r.centers[1].x,0);near(r.centers[1].y,0) end
    end end end
end
function Tests.timer_changes_never_move_icons_across_the_growth_axis()
    local configurations={{false,false,false},{false,true,false},{true,false,false,true},{false},{true}}
    for _,size in ipairs({40,46}) do for _,labelHeight in ipairs({20,60}) do
        for timerPosition=1,4 do for axis=1,2 do for growth=1,3 do
            for _,timers in ipairs(configurations) do
                local m={width=size,height=size,labelWidth=size,labelHeight=labelHeight,gap=5,
                    timerPosition=timerPosition,hasDuration=timers}
                local r=Layout.Place(#timers,axis,growth,m)
                for _,center in ipairs(r.centers) do near(center[axis==1 and 'y' or 'x'],0) end
            end
        end end end
    end end
end
