local KW=KanaWardrobe
local D={};KW.Dialogs=D
local function text(key) return KW.Strings[key] or KW.Strings.UNKNOWN_PROBLEM end
function D.Plain(value) return tostring(value or ""):gsub("|","/") end
function D.Difference(row)
 local function label(key)return text('MISMATCH_'..key)end
 local function format(key,...)return string.format(label(key),...)end
 local function name(value,fallback)return D.Plain(value or fallback or label('SKILL'))end
 local expected,actual=row.expected,row.actual
 local function refName(ref,resolved)
  if not ref then return label('UNREADABLE')end
  if ref.kind=='empty'then return label('EMPTY')end
  return name(resolved,ref.kind=='item' and label('ITEM') or nil)
 end
 if row.domain=='attributes' and row.field then
  return format('VALUE',label(row.field),tostring(expected),actual~=nil and tostring(actual) or label('UNREADABLE'))
 elseif row.domain=='appearance' then
  return format('VALUE',name(row.name,text('APPEARANCE')),name(row.expectedName),name(row.actualName))
 elseif row.domain=='skills' and expected and expected.kind then
  local skill=name(row.name)
  if not actual then return format('MISSING',skill)end
  if expected.kind=='passive'then return format('RANK',skill,expected.rank,actual.rank or 0)end
  if expected.purchased==false then return format('REMOVE',name(row.actualName,skill))end
  if actual.purchased==false then return format('LEARN',name(row.expectedName,skill))end
  return format('MORPH',name(row.expectedName,skill),name(row.actualName,skill))
 elseif row.domain=='bars' and row.slot then
  local bar=row.bar and label(row.bar) or label(row.specialBar or 'SPECIAL_BAR')
  return format('BAR',bar,row.slot,refName(expected,row.expectedName),refName(actual,row.actualName))
 elseif row.domain=='equipment' and row.slot then
  local slot=D.SlotName(row.slot)
  if expected and actual and expected.kind=='item' and actual.kind=='item'
      and expected.uid~=actual.uid and row.expectedName and row.expectedName==row.actualName then
   return format('ITEM_COPY',slot,name(row.expectedName))
  end
  return format('VALUE',slot,refName(expected,row.expectedName),refName(actual,row.actualName))
 end
 return format('MISSING',label(row.domain or 'BUILD'))
end
function D.Problem(problem)
 if not problem then return "" end
 local known=(KW.Strings.PROBLEMS or {})[problem.code]
 local message=known or string.format(text("PROBLEM_UNRECOGNIZED"),D.Plain(problem.code))
 local details=problem.details or {}
 if problem.code=='operationMismatch' and details.differences and #details.differences>0 then
  local lines={}
  for _,row in ipairs(details.differences)do lines[#lines+1]=D.Difference(row)end
  lines[#lines+1]=text('MISMATCH_RETRY')
  return table.concat(lines,'\n')
 end
 if problem.code=='appearanceUnconfirmed'then
  message=string.format(text('APPEARANCE_MISMATCH'),D.Plain(details.categoryName),D.Plain(details.targetName),D.Plain(details.actualName))
 elseif problem.code:match('^appearance') and details.name then
  message=message..' '..D.Plain(details.categoryName)..': '..D.Plain(details.name)..'.'
 end
 if details.reasonText and details.reasonText~=''then message=message..' '..D.Plain(details.reasonText)end
 if problem.code=='requestTimeout' and details.items and #details.items>0 then
  local slots={}
  for _,item in ipairs(details.items)do slots[#slots+1]=D.SlotName(item.equipSlot)end
  message=string.format(text('EQUIPMENT_TIMEOUT_SLOTS'),table.concat(slots,', '))
  if details.reasonText and details.reasonText~=''then message=message..' '..D.Plain(details.reasonText)end
 end
 if problem.code=='nativeRespecRefused' and type(details.result)=='number' and type(GetString)=='function'then
  local ok,native=pcall(GetString,'SI_RESPECRESULT',details.result)
  if ok and type(native)=='string' and native~=''then message=native..' '..text('BUILD_RETRY_PRESET')end
 end
 if problem.code=='foreignSkillDraft' and details.nativeReasons then
  local reasons={}
  for _,reason in ipairs(details.nativeReasons)do reasons[#reasons+1]=text('SKILL_BLOCK_'..reason)end
  message=table.concat(reasons,' ')
  if details.nativeReportSaved then message=message..' '..text('SKILL_BLOCK_REPORT_SAVED')end
 end
 if problem.code=="equipmentOverride" then message=KW.Strings["BUILD_OVERRIDE_"..tostring(details.reason)] or message end
 if details.error then
  local reason=tostring(details.error):match("[^\r\n]+") or ""
  if #reason>512 then
   local last=512
   while reason:byte(last+1)>=128 and reason:byte(last+1)<192 do last=last-1 end
   reason=reason:sub(1,last).."…"
  end
  if reason~="" then message=message.."\n"..D.Plain(reason)end
 end
 if details.required and details.available then message=message.." "..string.format(text("BUILD_DEFICIT"),details.required,details.available,details.deficit or math.max(0,details.required-details.available)) end
 return message
end
function D.SlotName(slot)
 for index,id in ipairs(KW.Slots.Order) do if id==slot then return KW.Strings.SLOT_NAMES[index] end end
 return text("UNKNOWN_PROBLEM")
end
function D.MissingText(missing)
 local rows={}
 for _,slot in ipairs(KW.Slots.Order) do
  local ref=missing and missing[slot]
  if ref then rows[#rows+1]=D.SlotName(slot)..": "..(ref.link or text("UNKNOWN_PROBLEM")) end
 end
 return table.concat(rows,"\n")
end
function D.ExtrasText(plan)
 local lines={text("EXTRAS_HELP")}
 for _,extra in ipairs(plan.extras or {}) do
  if extra.type=="ability" then
   local before=extra.before.kind=="empty" and text("BUILD_EMPTY") or tostring(extra.before.expectedMorph or 0)
   local after=extra.target.kind=="empty" and text("BUILD_EMPTY") or tostring(extra.target.expectedMorph or 0)
   lines[#lines+1]=string.format(text("BUILD_ABILITY_EXTRA"),D.Plain(extra.name or extra.skillKey),D.Plain(extra.bar or extra.category),extra.slot,before,after)
  else
  local reason=text("REASON_"..tostring(extra.reason))
  if extra.toSlot then lines[#lines+1]=string.format(text("EXTRA_MOVE"),extra.link or "",D.SlotName(extra.fromSlot),D.SlotName(extra.toSlot),reason)
  else lines[#lines+1]=string.format(text("EXTRA_REMOVE"),extra.link or "",D.SlotName(extra.fromSlot),reason) end
  end
 end
 return table.concat(lines,"\n\n")
end
local registered={}
local function show(kind,title,body,choices,reject,edit)
 local id="KANA_WARDROBE_"..kind
 local data={title=title,body=body,choices=choices,safeFirst=true,active=true,id=id}
 data.reject=function()
  if not data.active then return end
  data.active=false
  if reject then reject()end
 end
 if not ZO_Dialogs_RegisterCustomDialog then return data end
 if not registered[id] then
  local definition={canQueue=true,title={text=function(dialog)return dialog.data.title end},
   mainText={text=function(dialog)return dialog.data.body end},
   noChoiceCallback=function(dialog)dialog.data.reject()end,
   buttons={}}
  if #choices>2 then
   definition.customControl=WINDOW_MANAGER:CreateControlFromVirtual(id.."Control",GuiRoot,"KanaWardrobeChoiceDialog")
   definition.setup=function(dialog,data)
    local above=dialog:GetNamedChild("Text");above:SetText(data.body)
    -- ZO_CustomDialogButton_OnInitialized installs bottom/horizontal anchors.
    -- Own the final layout after native initialization and keybind/text sizing.
    for index=1,#data.choices do
     local button=dialog:GetNamedChild("Choice"..index)
     button:ClearAnchors()
     button:SetAnchor(TOPRIGHT,above,BOTTOMRIGHT,0,index==1 and 24 or 12)
     above=button
    end
   end
  end
  for index=1,#choices do
   local i=index
   definition.buttons[i]={text=function(dialog)return dialog.data.choices[i].label end,
    -- Escape chooses the safe first option; destructive choices require clicking.
    keybind=i==1 and "DIALOG_NEGATIVE" or false,
    callback=function(dialog)
     if not dialog.data.active then return end
     dialog.data.active=false
     local callback=dialog.data.choices[i].callback
     if callback then callback(edit and ZO_Dialogs_GetEditBoxText(dialog) or nil) end
    end}
   if definition.customControl then definition.buttons[i].control=definition.customControl:GetNamedChild("Choice"..i) end
  end
  if edit then definition.editBox={maxInputCharacters=48} end
  ZO_Dialogs_RegisterCustomDialog(id,definition);registered[id]=true
 end
 ZO_Dialogs_ShowDialog(id,data,edit and {initialEditText=edit} or nil)
 return data
end
-- Retire by exact data identity, including entries queued behind another modal.
-- Invalidate first because native release synchronously invokes noChoiceCallback.
function D.Retire(data)
 if not data then return end
 data.active=false
 if ZO_Dialogs_ReleaseAllDialogsOfName then
  ZO_Dialogs_ReleaseAllDialogsOfName(data.id,function(candidate)return candidate==data end)
 end
end
function D.ConfirmExtras(plan,presetName,onAccept,onReject)
 return show("EXTRAS",string.format(text("EXTRAS_TITLE"),D.Plain(presetName)),D.ExtrasText(plan),{
  {label=text("CANCEL"),callback=onReject},{label=text("APPLY"),callback=onAccept}},onReject)
end
function D.ConfirmDelete(preset,onAccept)
 return show("DELETE",text("DELETE_TITLE"),string.format(text("DELETE_HELP"),D.Plain(preset.name)),{
  {label=text("CANCEL")},{label=text("DELETE"),callback=onAccept}})
end
function D.EditName(preset,onAccept)
 return show("NAME",text("NAME"),text("INVALID_NAME"),{{label=text("CANCEL")},{label=text("SAVE"),callback=onAccept}},nil,preset.name or "")
end
function D.CloseEditor(onSave,onCancel,onContinue,message)
 return show("CLOSE",text("CLOSE_EDITOR"),message or text("CLOSE_HELP"),{
  {label=text("CONTINUE"),callback=onContinue},{label=text("SAVE"),callback=onSave},{label=text("CANCEL"),callback=onCancel}},onContinue)
end
function D.ConfirmRestoreAvailable(missing,onAccept)
 return show("PARTIAL",text("RECOVERY"),text("RESTORE_MISSING_HELP").."\n\n"..D.MissingText(missing),{
  {label=text("CANCEL")},{label=text("RESTORE_AVAILABLE"),callback=onAccept}})
end
function D.ConfirmKeepCurrent(onAccept)
 return show("KEEP",text("RECOVERY"),text("KEEP_WARNING"),{{label=text("CANCEL")},{label=text("KEEP_CURRENT"),callback=onAccept}})
end
function D.Recovery(view,onAction)
 return show("RECOVERY",text("RECOVERY"),text("RECOVERY_HELP").."\n\n"..D.Problem(view.problem),{
  {label=text("CANCEL")},{label=text("RESTORE"),callback=function()onAction("restore")end},
  {label=text("KEEP_CURRENT"),callback=function()D.ConfirmKeepCurrent(function()onAction("keepCurrent")end)end}})
end
function D.ConfirmEditMissing(missing,onAccept)
 return show("EDIT_MISSING",text("MISSING_EDIT"),text("MISSING_EDIT_HELP").."\n\n"..D.MissingText(missing),{
  {label=text("CANCEL")},{label=text("EDIT"),callback=onAccept}})
end

function D.ConfirmRecoveryEndpoint(action,onAccept)
 return show("BUILD_ENDPOINT",text("RECOVERY_ACTIONS"),text("RECOVERY_ACCEPT_HELP"),{
  {label=text("CANCEL")},{label=text("RECOVER_"..action),callback=onAccept}})
end
