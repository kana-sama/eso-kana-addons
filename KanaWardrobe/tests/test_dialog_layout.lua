local Fake=dofile(ROOT.."/tests/support/fake_eso.lua")
local G=dofile(ROOT.."/tests/support/geometry_controls.lua")
return {
 dialog_choices_reflow_after_native_initialization=function()
  for _,factor in ipairs({.75,1,1.5})do G.With(1920,1080,factor,function(f)
   local kw=Fake.Load({"Core.lua","SoftPanel.lua","Slots.lua","lang/en.lua","Dialogs.lua"})
   local definitions={}
   local original=WINDOW_MANAGER.CreateControlFromVirtual
   WINDOW_MANAGER.CreateControlFromVirtual=function(wm,name,parent,template)
    if template~="KanaWardrobeChoiceDialog"then return original(wm,name,parent,template)end
    local dialog=f:Control(name,nil,CT_CONTROL,600,600)
    dialog:SetAnchor(TOPLEFT,GuiRoot,TOPLEFT,100,50)
    local body=f:Control(name.."Text",dialog,CT_LABEL,550)
    body:SetAnchor(TOPLEFT,dialog,TOPLEFT,25,60);body:SetFont("ZoFontGame");dialog.children.Text=body
    local previous
    for i=1,3 do
     local button=f:Control(name.."Choice"..i,dialog,CT_CONTROL,210,35);dialog.children["Choice"..i]=button
     -- XML anchors coexist with defaults from ZO_CustomDialogButton_OnInitialized
     -- (native zo_dialog.lua:1337-1370). setup runs after native initialization.
     button:SetAnchor(TOPLEFT,previous or body,BOTTOMLEFT,0,i==1 and 30 or 16)
     if previous then button:SetAnchor(TOPRIGHT,previous,TOPLEFT,-20,0)
     else button:SetAnchor(BOTTOMRIGHT,dialog,BOTTOMRIGHT,-25,-15)end
     previous=button
    end
    return dialog
   end
   f:Put("ZO_Dialogs_RegisterCustomDialog",function(id,definition)definitions[id]=definition end)
   f:Put("ZO_Dialogs_ShowDialog",function(id,data)
    local definition=definitions[id];local dialog=definition.customControl;dialog.data=data
    definition.setup(dialog,data)
   end)
   for cycle=1,2 do
    kw.Dialogs.CloseEditor(function()end,function()end,function()end)
    kw.Dialogs.Recovery({problem={code="unknown"}},function()end)
    for _,definition in pairs(definitions)do
     local dialog=definition.customControl;local body=dialog:GetNamedChild("Text")
     local prior=body
     for i=1,3 do
      local button=definition.buttons[i].control
      assert(button:GetNumAnchors()==1,"native and XML dialog anchors still conflict")
      assert(button:GetTop()>=prior:GetBottom()+8*factor,"dialog actions must have distinct vertical rows")
      G.Contained(button,dialog);G.Disjoint(button,body)
      prior=button
     end
     G.Disjoint(definition.buttons[1].control,definition.buttons[2].control)
     G.Disjoint(definition.buttons[2].control,definition.buttons[3].control)
    end
   end
  end)end
 end,
 recovery_endpoint_confirmation_is_two_choices_and_labels_unknown_outcome=function()
  local kw=Fake.Load({"Core.lua","lang/en.lua","Dialogs.lua"});local calls=0
  local dialog=kw.Dialogs.ConfirmRecoveryEndpoint("acceptCurrent",function()calls=calls+1 end)
  assert(#dialog.choices==2 and dialog.choices[1].label==kw.Strings.CANCEL and calls==0)
  assert(dialog.body and dialog.body~=kw.Strings.UNKNOWN_PROBLEM and dialog.body:lower():find("unknown",1,true))
  dialog.choices[2].callback();assert(calls==1)
 end,

}
