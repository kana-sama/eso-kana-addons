-- Source-backed selectors only. Geometry uses native reference anchors and UI
-- units, never the mock canvas or the UI scale slider. This creates new defaults;
-- Storage owns preserving existing profiles without rewriting user choices.
local Presets={}; KanaEffects.Presets=Presets
local function facet(field,...) return {op='facet',field=field,values={...}} end
local function combine(op,...) return {op=op,args={...}} end
local function set(id,name,predicate,exclude)
    return {id=id,name=name,predicate=predicate,includeSets={},excludeSets=exclude or {}}
end
local function anchor(reference,px,py,rx,ry,x,y)
    return {relativeTo=reference,pointX=px,pointY=py,relativePointX=rx,relativePointY=ry,x=x,y=y}
end
local function widget(id,name,kind,unitTag,mode,icon,count,where,include,named)
    return {id=id,name=name,type=kind,unitTag=unitTag,
        layout={columns=6,rows=3,fixedAxis='columns',count=count,gap=6,absent='ghost',ghostAlpha=0.3},
        style={mode=mode,iconSize=icon,timerFontSize=14,nameFontSize=14,rowWidth=220},
        anchor=where,slots={},rules={includeSets={include},excludeSets={},named=named or 'any',mergePairs=true}}
end
-- Shared starter/editor semantics: categories may include named buffs; only
-- the uncategorized duration branch excludes named combat families.
function Presets.SupportPredicate(kinds,lifetimes,categories)
    return combine('and',{op='facet',field='kind',values=kinds or {'buff'}},combine('or',
        {op='facet',field='category',values=categories or {'food','xp','service'}},
        combine('and',facet('named',false),{op='facet',field='lifetime',values=lifetimes or {'long','permanent','toggle'}})))
end
function Presets.Build(catalog,viewportRect,fontMetrics)
    assert(catalog and catalog.ValidateSelector,'Presets requires the shared catalog')
    assert(viewportRect and viewportRect.width>0 and viewportRect.height>0,'Presets requires a native viewport')
    assert(fontMetrics and fontMetrics.MeasureText,'Presets requires native font metrics')
    local support=Presets.SupportPredicate()
    -- Short and long are the finite-duration facet buckets. Unknown polarity and
    -- unknown duration both remain eligible; a debuff never moves to support.
    local combat=combine('or',facet('lifetime','short','long','unknown'),facet('kind','debuff','unknown'))
    local p={schemaVersion=1,hidden={},longThreshold=60,editor={toolbarX=24,toolbarY=24},
        sets={set('support','Еда, опыт и долгие эффекты',support),set('combat','Боевые эффекты',combat,{'support'}),
            set('named','Именованные эффекты',facet('named',true)),set('all','Все эффекты',combine('and'))},widgets={}}
    p.widgets[1]=widget('named-widget','Именованные · игрок','table','player','over',36,6,
        anchor('actionBar',0.5,1,0.5,0,0,0),'named')
    p.widgets[2]=widget('combat-widget','Боевые · игрок','grid','player','under',32,8,
        anchor('actionBar',0.5,1,0.5,0,0,-24),'combat','exclude')
    p.widgets[3]=widget('support-widget','Еда и долгие','grid','player','list',28,1,
        anchor('screen',0,1,0,1,24,-math.min(140,viewportRect.height*0.2)),'support')
    p.widgets[4]=widget('target-widget','Эффекты цели','grid','reticleover','under',30,8,
        anchor('targetFrame',0.5,0,0.5,1,0,12),'all')
    -- Stock keyboard target TextArea starts7 below the bar; Caption is a
    -- second ZoFontGameShadow line with gap1 (unitframes.xml550-575).
    -- Adjacent veteran/rank icons extend40/32 UI units. Reserve that native
    -- extent plus snapshot/editor heading space and12 gap for NEW profiles.
    local target=p.widgets[4]; local targetMetrics=KanaEffects.Layout.Measure(target.style,fontMetrics)
    local captionHeight
    if fontMetrics.TargetCaptionHeight then captionHeight=fontMetrics:TargetCaptionHeight()
    else local _; _,captionHeight=fontMetrics:MeasureText('…',target.style.nameFontSize,'name') end
    local captionExtent=7+math.max(2*captionHeight+1,captionHeight/2+40/2,32-4)
    target.anchor.y=captionExtent+math.max(targetMetrics.snapshotLineHeight,28)+12
    -- Reserve exactly two ordinary combat rows with the same geometry engine
    -- used by Runtime. These local placeholders carry no effect identities and
    -- never become profile/Store/history entries. Only new defaults are placed;
    -- later growth and all saved user anchors remain user-controlled.
    local combat=p.widgets[2]; local reservation={}
    for i=1,combat.layout.count*2 do reservation[i]={} end
    local measured=KanaEffects.Layout.Measure(combat.style,fontMetrics)
    local reserved=KanaEffects.Layout.Place(combat,reservation,
        {x=0,y=0,width=0,height=0},viewportRect,measured)
    p.widgets[1].anchor.y=combat.anchor.y-reserved.rect.height-combat.layout.gap
    -- Deliberate PvE starter selection, not an exhaustive family list. Fixed
    -- slot addresses survive partial/version-incompatible catalogs as holes.
    -- Lifesteal is a native debuff despite its synthetic mock presentation.
    local families={'resolve','courage','brutality','savagery','force','heroism',
        'protection','vitality','mending','evasion','expedition','endurance',
        'intellect','fortitude','aegis','slayer','berserk','toughness'}
    for i,id in ipairs(families) do
        local selector={kind='family',id=id,level='pair'}
        if catalog:ValidateSelector(selector) then
            local row,column=math.floor((i-1)/6)+1,(i-1)%6+1
            p.widgets[1].slots[row]=p.widgets[1].slots[row] or {}
            p.widgets[1].slots[row][column]=selector
        end
    end
    return p
end
