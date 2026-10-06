local T=dofile('KanaStatSources/tests/support.lua')
local K=T.load()
return {
    signed_unknown=function()
        local b=K.Model.Build(T.snapshot({maxHealth=100}),{T.flat('known','maxHealth',120)},{},{})
        T.eq(b.maxHealth.unknown,-20);T.eq(T.sumRows(b.maxHealth),100)
    end,
    duplicate_source_not_counted=function()
        local c=T.flat('gear','maxHealth',10)
        local b=K.Model.Build(T.snapshot({maxHealth=100}),{c,c},{},{})
        T.eq(b.maxHealth.explained,10);T.eq(b.maxHealth.unknown,90)
    end,
    shared_percent_base_and_sequential_groups=function()
        local cs={T.flat('base','maxHealth',12000),T.percent('a','maxHealth',10,'resources'),T.percent('b','maxHealth',20,'resources'),T.percent('c','maxHealth',5,'next')}
        local p={maxHealth={groups={{id='resources',scope={'flat'},requireBase=true},{id='next',scope={'subtotal'},requireBase=true}}}}
        local b=K.Model.Build(T.snapshot({maxHealth=16380}),cs,{},p).maxHealth
        T.eq(b.explained,16380);T.eq(b.unknown,0);T.eq(T.sumRows(b),16380)
        T.eq(cs[2].amount,10)
    end,
    no_guess_for_unknown_percent_policy=function()
        local b=K.Model.Build(T.snapshot({maxHealth=150}),{T.flat('base','maxHealth',100),T.percent('bonus','maxHealth',50,'missing')},{},{}).maxHealth
        T.eq(b.explained,100);T.eq(b.unknown,50);T.eq(#b.diagnostics,1)
    end,
    rounding_reconciles_visible_rows=function()
        local b=K.Model.Build(T.snapshot({maxHealth=11}),{T.flat('a','maxHealth',5.6),T.flat('b','maxHealth',5.6)},{},{}).maxHealth
        T.eq(b.unknown,-1);T.eq(T.sumRows(b),11);T.near(b.rawUnknown,-0.2)
    end,
    invalid_values_are_diagnostic=function()
        local b=K.Model.Build(T.snapshot({maxHealth=10}),{T.flat('nan','maxHealth',0/0),T.flat('inf','maxHealth',math.huge)},{},{}).maxHealth
        T.eq(b.explained,0);T.eq(b.unknown,10);T.eq(#b.diagnostics,2)
    end,
    preview_is_separate=function()
        local s=T.snapshot({maxHealth=100});s.preview.maxHealth=20
        local b=K.Model.Build(s,{T.flat('base','maxHealth',100)},{},{}).maxHealth
        T.eq(b.total,100);T.eq(b.preview.total,120);T.eq(T.sumRows(b),100)
    end,
    inconsistent_snapshot_does_not_mix_sources=function()
        local s=T.snapshot({maxHealth=100});s.consistent=false
        local b=K.Model.Build(s,{T.flat('old','maxHealth',80)},{},{}).maxHealth
        T.eq(b.explained,0);T.eq(b.unknown,100)
    end,
    missing_total_is_not_zero=function()
        local b=K.Model.Build(T.snapshot({}),{},{},{})
        T.eq(b.maxHealth.total,nil);T.eq(b.maxHealth.available,false)
    end,
    effective_native_values_are_not_scaled_twice=function()
        local c=T.flat('attribute','maxHealth',100,'attributes');c.operation='effectiveFlat'
        local cs={T.flat('base','maxHealth',1000),c,T.percent('bonus','maxHealth',10,'resources')}
        local b=K.Model.Build(T.snapshot({maxHealth=1200}),cs,{}, {maxHealth={groups={{id='resources',scope={'flat'},requireBase=true}}}}).maxHealth
        T.eq(b.explained,1200)
    end,
}
