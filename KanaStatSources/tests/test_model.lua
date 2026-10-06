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
        T.eq(b.unknown,0);T.eq(T.sumRows(b),11);T.near(b.rawUnknown,-0.2)
        T.eq(b.rows[1].value,6);T.eq(b.rows[2].value,5)
    end,
    fractional_damage_percentages_round_as_one_sum=function()
        local cs={T.flat('base','weaponDamage',3148),T.percent('agility','weaponDamage',14,'additive'),T.percent('brutality','weaponDamage',20,'additive')}
        local b=K.Model.Build(T.snapshot({weaponDamage=4218}),cs,{},K.Rules.Policies).weaponDamage
        T.eq(b.unknown,0);T.eq(T.sumRows(b),4218);T.near(b.rawUnknown,-0.32)
        T.eq(b.rows[2].value,441);T.eq(b.rows[3].value,629)
        T.near(b.rows[2].rawValue,440.72);T.near(b.rows[3].rawValue,629.6)
    end,
    genuine_small_unknown_is_preserved=function()
        local b=K.Model.Build(T.snapshot({weaponDamage=4218}),{T.flat('base','weaponDamage',4219)}).weaponDamage
        T.eq(b.unknown,-1);T.eq(T.sumRows(b),4218)
    end,
    compensated_source_sum_keeps_exact_half_unit=function()
        local cs={}
        for i,value in ipairs({1000,1132,124,72.18,48.12,150,481.2})do cs[#cs+1]=T.flat(tostring(i),'weaponDamage',value)end
        local b=K.Model.Build(T.snapshot({weaponDamage=3008}),cs).weaponDamage
        T.eq(b.rawExplained,3007.5);T.eq(b.unknown,0);T.eq(T.sumRows(b),3008)
    end,
    values_truly_below_half_do_not_gain_rounding_tolerance=function()
        local b=K.Model.Build(T.snapshot({weaponDamage=3008}),{T.flat('base','weaponDamage',3007.49999999)}).weaponDamage
        T.eq(b.unknown,1);T.eq(b.explained,3007)
    end,
    zero_bonuses_do_not_produce_rows=function()
        local c={T.flat('base','physicalResistance',10812),T.flat('resolve','physicalResistance',0,'skills')}
        local b=K.Model.Build(T.snapshot({physicalResistance=10812}),c).physicalResistance
        T.eq(#b.rows,1);T.eq(b.rows[1].key,'base');T.eq(c[2].amount,0)
    end,
    rounded_zero_rows_are_removed_after_apportionment=function()
        local b=K.Model.Build(T.snapshot({maxHealth=1}),{T.flat('a','maxHealth',0.4),T.flat('b','maxHealth',0.4)}).maxHealth
        T.eq(b.unknown,0);T.eq(#b.rows,1);T.eq(b.rows[1].value,1);T.eq(T.sumRows(b),1)
    end,
    signed_fractional_rows_are_apportioned_deterministically=function()
        local c={T.flat('a','maxHealth',10.2),T.flat('b','maxHealth',-0.6),T.flat('c','maxHealth',-0.6)}
        local b=K.Model.Build(T.snapshot({maxHealth=9}),c).maxHealth
        T.eq(b.unknown,0);T.eq(b.rows[1].value,10);T.eq(b.rows[2].value,-1);T.eq(T.sumRows(b),9)
        local reordered=K.Model.Build(T.snapshot({maxHealth=9}),{c[3],c[2],c[1]}).maxHealth
        T.eq(reordered.rows[1].key,b.rows[1].key);T.eq(reordered.rows[2].key,b.rows[2].key)
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
        local c=T.flat('mundus','maxHealth',100,'mundus');c.operation='effectiveFlat'
        local cs={T.flat('base','maxHealth',1000),c,T.percent('bonus','maxHealth',10,'resources')}
        local b=K.Model.Build(T.snapshot({maxHealth=1200}),cs,{}, {maxHealth={groups={{id='resources',scope={'flat'},requireBase=true}}}}).maxHealth
        T.eq(b.explained,1200)
    end,
}
