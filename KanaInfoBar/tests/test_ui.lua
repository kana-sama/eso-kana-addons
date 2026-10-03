local H=dofile('KanaInfoBar/tests/ui_harness.lua')
local A=H.load()
local M=A.Model
assert(A.controls.messages:IsHidden() and A.controls.treasure:IsHidden())
assert(A.layout.height==32)
local originalX,originalY=A.sv.x,A.sv.y
A:OpenEditor()
assert(A.edit and not A.controls.messages:IsHidden(),'zero indicators appear in editor')
assert(A.controls.messages.nameLabel,'editor cards need names, including hidden metrics')
local initialRows=M.Copy(A.sv.rows)
local function drop(id,box)
    H.mouseX,H.mouseY=100,100
    A:BeginWidgetDrag(id)
    H.mouseX=A.root:GetLeft()+(box.x+box.width/2)*A:Config().scale
    H.mouseY=A.root:GetTop()+(box.y+box.height/2)*A:Config().scale
    A:UpdateDrag();A:EndWidgetDrag(true)
end
local last=A.dropZones[#A.dropZones]
drop('inventory',last)
assert(#A.edit.config.rows==2 and A.edit.config.rows[2][1]=='inventory','new row drop')
drop('messages',A.trayBounds)
assert(A.edit.config.enabled.messages==false and not A.controls.messages:IsHidden(),'disabled tray remains editable')
local target=A.dropZones[#A.dropZones]
drop('messages',target)
assert(A.edit.config.enabled.messages==true and A.edit.config.rows[3][1]=='messages','tray to new row')
local before=M.Copy(A.edit.config.rows)
A:BeginWidgetDrag('fps');H.mouseX=-100;H.mouseY=-100;A:EndWidgetDrag(true)
assert(#A.edit.config.rows==#before,'outside drop must not change rows')
local oldLeft,oldTop=A.root:GetLeft(),A.root:GetTop()
A:SetAnchorChoice('TOP')
assert(math.abs(A.root:GetLeft()-oldLeft)<.001 and math.abs(A.root:GetTop()-oldTop)<.001,'anchor change cannot teleport panel')
A:CloseEditor(false)
assert(A.sv.anchor=='BOTTOMRIGHT' and A.sv.x==originalX and A.sv.y==originalY)
assert(#A.sv.rows==1 and #A.sv.rows[1]==#initialRows[1],'cancel restores full snapshot')
A:OpenEditor();drop('fps',A.dropZones[#A.dropZones]);A:CloseEditor(true)
assert(#A.sv.rows==2 and A.sv.rows[2][1]=='fps','save row arrangement')
-- Clicking in edit mode must not call a widget action, even without movement.
local calls=0;A.modules.inventory.action=function() calls=calls+1 end
A:OpenEditor()
A.controls.inventory.handlers.OnMouseDown(nil,1)
A.controls.inventory.handlers.OnMouseUp(nil,1,true)
assert(calls==0)
A:CloseEditor(false)
A.controls.inventory.handlers.OnMouseUp(nil,1,true);assert(calls==1)
-- A scene change cancels uncommitted edits and clears full-screen drag capture.
A:OpenEditor();A:BeginWidgetDrag('dps')
A.fragment.callback(nil,SCENE_FRAGMENT_HIDING)
assert(not A.edit and not A.drag and A.capture:IsHidden())
A.sv.enabled.messages=false
A.sv.scale=1.25; A.sv.gap=19; A.sv.rowGap=9
A:OpenEditor()
assert(A.edit.config.enabled.messages==false and A.edit.config.scale==1.25,
    'editor must read non-default values through the saved-variable interface')
assert(A.edit.config.gap==19 and A.edit.config.rowGap==9)
A.edit.config.enabled.messages=true
A.edit.config.rows[1][1]='changed'
A:CloseEditor(false)
assert(A.sv.enabled.messages==false and A.sv.rows[1][1]=='dps',
    'editing a snapshot must not mutate the underlying saved settings')
A.sv.rows={{'fps','inventory'},{'ping','durability'},{'dps','messages','treasure'}}
A.sv.gridMode=true
A:Refresh(true)
assert(A.layout.slots.fps.x==A.layout.slots.ping.x and
    A.layout.slots.inventory.x==A.layout.slots.durability.x,
    'panel uses shared columns in grid mode')
A:OpenEditor()
assert(A.edit.config.gridMode==true,'editor draft includes grid mode')
A.edit.config.gridMode=false
A:CloseEditor(false)
assert(A.sv.gridMode==true,'cancel restores grid mode')
A:OpenEditor()
A.edit.config.gridMode=false
A:CloseEditor(true)
assert(A.sv.gridMode==false,'editor save persists grid mode')
-- Screenshot layout: an unavailable DPS in the third row must not leave a
-- full grouped-DPS-sized blank area before the second column.
A.sv.anchor='TOPLEFT';A.sv.gridMode=true;A.sv.gap=12
A.sv.rows={{'fps','ping'},{'durability','treasure','inventory'},{'dps'}}
A.modules.durability.read=function() return {text='61%',visible=true} end
A.modules.treasure.read=function() return {text='120g',visible=true} end
A.modules.inventory.read=function() return {text='25/179',visible=true} end
A.modules.ping.read=function() return {text='100',visible=true} end
A.modules.fps.read=function() return {text='60',visible=true} end
A.modules.dps.read=function() return {text='—',visible=true} end
A:Refresh(true)
assert(A.layout.slots.ping.x==A.currentWidths.fps+A.sv.gap,
    'empty DPS does not create excess space before second grid column')
print('PASS: UI state, drag targets, save/cancel, anchor preservation and scene cleanup')
