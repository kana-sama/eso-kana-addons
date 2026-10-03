-- Use the real ESO library, not a simplified defaults/proxy mock:
-- lua KanaInfoBar/tests/test_savedvars.lua /path/to/zo_savedvars.lua
local H=dofile('KanaInfoBar/tests/ui_harness.lua')
assert(arg[1], 'Pass the path to ESO esoui/libraries/utility/zo_savedvars.lua')
function GetDisplayName() return '@layout-test' end
function ZO_ClearTable(t) for k in pairs(t) do t[k]=nil end end
dofile(arg[1])

local function saved() return KanaInfoBarSaved.Default['@layout-test']['$AccountWide'] end
local function load()
    KanaInfoBar=nil
    return H.load()
end
local function row(config,index,expected)
    assert(config.rows[index] and table.concat(config.rows[index],',')==expected,
        'row '..index..': expected '..expected..'; got '..(config.rows[index] and table.concat(config.rows[index],',') or '<missing>'))
end

-- Exact arrangement observed in the user's saved file, with a short first row.
KanaInfoBarSaved={Default={['@layout-test']={['$AccountWide']={version=1,
    rows={{'fps','ping','dps','inventory'},{'messages','treasure'}},
    enabled={messages=false,treasure=true},anchor='TOPLEFT',x=123,y=45,scale=1.25}}}}
for i=1,3 do
    local A=load()
    row(A.sv,1,'fps,ping,dps,inventory')
    row(A.sv,2,'messages,treasure,durability')
    assert(#A.sv.rows==2 and A.sv.enabled.messages==false)
    assert(A.sv.anchor=='TOPLEFT' and A.sv.x==123 and A.sv.y==45 and A.sv.scale==1.25)
    assert(A.sv.gridMode==false,'existing settings default to free layout')
    row(saved(),2,'messages,treasure,durability')
    -- Disk reload removes interface/metatable state; raw settings remain plain data.
    KanaInfoBarSaved=A.Model.Copy(KanaInfoBarSaved)
end

-- New installation creates defaults once; moving a widget and saving survives reload.
KanaInfoBarSaved={}
local A=load()
row(A.sv,1,'dps,messages,ping,fps,inventory,durability,treasure')
A.sv.gridMode=true
A:OpenEditor()
assert(A.edit.config.gridMode==true,'editor draft copies grid mode')
A.Model.Move(A.edit.config,'treasure',2,1,true)
A:CloseEditor(true)
KanaInfoBarSaved=A.Model.Copy(KanaInfoBarSaved)
A=load()
assert(A.sv.gridMode==true,'grid mode persists after reload')
row(A.sv,1,'dps,messages,ping,fps,inventory,durability')
row(A.sv,2,'treasure')

-- A one-widget first row and multiple rows must not be refilled from defaults.
A.sv.rows={{'fps'},{'ping','dps'},{'messages','inventory','treasure'}}
KanaInfoBarSaved=A.Model.Copy(KanaInfoBarSaved)
A=load()
row(A.sv,1,'fps');row(A.sv,2,'ping,dps');row(A.sv,3,'messages,inventory,treasure,durability')
print('PASS: real ESO SavedVars preserves two/three rows, disabled widgets, settings and editor save across reloads')
