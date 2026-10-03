local Fake=dofile(ROOT.."/tests/support/fake_eso.lua")
local tests={}
function tests.full_multiline_dialog_preserves_text_copy_focus_and_close_without_mutation()
 local k=Fake.Load({"Core.lua"});local definition,shown;local fields={};local edit={hidden=true,maxChars=128}
 function edit:SetText(t)assert(#t<=4096,"native edit received oversized report");self.text=t:sub(1,self.maxChars) end
 function edit:SetMaxInputChars(n)self.maxChars=n end
 function edit:SetCopyEnabled(v)self.copy=v end
 function edit:TakeFocus()self.focus=not self.hidden end
 function edit:SelectAll()self.selected=self.text end
 function edit:LoseFocus()self.focus=false end
 function edit:SetHandler(name,fn)self[name]=fn end
 local function button()return {SetText=function(self,t)self.text=t end,SetEnabled=function(self,v)self.enabled=v end,SetHidden=function(self,v)self.hidden=v end,SetHandler=function(self,k,v)self[k]=v end}end
 fields.Previous=button();fields.Next=button();fields.Page=button()
 local close={ClearAnchors=function()end,SetAnchor=function(self,...)self.anchor={...}end}
 fields.Edit=edit;fields.Close=close;fields.Title={SetWidth=function(self,w)self.width=w end}
 local control={GetNamedChild=function(_,n)return fields[n]end,SetResizeToFitDescendents=function(self,v)self.resize=v end,SetDimensions=function(self,w,h)self.width=w;self.height=h end}
 local old={WINDOW_MANAGER=WINDOW_MANAGER,GuiRoot=GuiRoot,ZO_Dialogs_RegisterCustomDialog=ZO_Dialogs_RegisterCustomDialog,ZO_Dialogs_ShowDialog=ZO_Dialogs_ShowDialog,ZO_Dialogs_ReleaseDialog=ZO_Dialogs_ReleaseDialog}
 WINDOW_MANAGER={CreateControlFromVirtual=function(_,_,parent,template)assert(parent==GuiRoot and template=="KanaWardrobeProbeReportDialog");return control end}
 GuiRoot={GetWidth=function()return 500 end,GetHeight=function()return 360 end}
 ZO_Dialogs_RegisterCustomDialog=function(_,d)definition=d end
 ZO_Dialogs_ShowDialog=function(_,data)shown=data;control.data=data;definition.setup(control,data);edit.hidden=false;if edit.OnEffectivelyShown then edit.OnEffectivelyShown(edit)end end
 ZO_Dialogs_ReleaseDialog=function()definition.finishedCallback(control)end
 dofile(ROOT.."/ProbeReport.lua")
 assert(not definition,"module load must not open/register UI")
 local text=string.rep("diagnostic | nil 123\n",10);k.ProbeReport.Show(text)
 assert(edit.text==text and edit.copy and edit.focus and edit.selected==text and shown.text==text)
 assert(definition.canQueue and definition.buttons[1].control==close and not definition.editBox)
 assert(control.resize==false and control.width<=500 and control.height<=360)
 definition.buttons[1].callback(control);assert(not edit.focus and shown.text==text)
 local full=string.rep("Строка отчёта | 123\n",1000)..string.rep("ю",6000)
 k.ProbeReport.Show(full)
 assert(edit.maxChars<=4096 and #edit.text<=4096 and fields.Previous.enabled==false and fields.Next.enabled)
 local parts={edit.text};local pages=0
 while fields.Next.enabled do
  fields.Next.OnClicked();pages=pages+1;assert(pages<100)
  assert(#edit.text<=4096 and utf8.len(edit.text) and edit.selected==edit.text)
  parts[#parts+1]=edit.text
 end
 assert(table.concat(parts)==full,"paging must preserve every byte of the report")
 assert(fields.Previous.enabled and not fields.Next.enabled)
 fields.Previous.OnClicked();assert(edit.text==parts[#parts-1] and fields.Next.enabled)
 assert(not edit.text:find("stack traceback",1,true))
 edit:TakeFocus();edit.OnEscape(edit);assert(not edit.focus)
 for name,value in pairs(old)do _G[name]=value end
 -- Nil originals do not appear in the table above.
 WINDOW_MANAGER=old.WINDOW_MANAGER;GuiRoot=old.GuiRoot;ZO_Dialogs_RegisterCustomDialog=old.ZO_Dialogs_RegisterCustomDialog;ZO_Dialogs_ShowDialog=old.ZO_Dialogs_ShowDialog;ZO_Dialogs_ReleaseDialog=old.ZO_Dialogs_ReleaseDialog
end
function tests.manifest_loads_report_before_core_without_ui_side_effects()
 local files={};for line in io.lines(ROOT.."/KanaWardrobe.txt")do if line:match("%.lua$")then files[#files+1]=line end end
 local k=Fake.Load(files);assert(k.ProbeReport and k.Core)
end
local function queuedFailure(stage,sinkThrows)
 local k=Fake.Load({"Core.lua"});local definition,queued;local edit={}
 local function noop()end
 edit.SetMaxInputChars=noop;edit.SetCopyEnabled=noop
 edit.SetText=function(self,text)if stage=="setup"then error("deferred setup failed")end;self.text=text end
 edit.TakeFocus=function()if stage=="shown"then error("deferred focus failed")end end
 edit.SelectAll=noop
 edit.LoseFocus=function()if stage=="close" or stage=="finished" or stage=="escape" or stage=="noChoice"then error("deferred release failed")end end
 edit.SetHandler=function(self,name,handler)self[name]=handler end
 local nav={SetText=noop,SetEnabled=noop,SetHidden=noop,SetHandler=noop};local fields={Previous=nav,Next=nav,Page=nav,Edit=edit,Close={ClearAnchors=noop,SetAnchor=noop},Title={SetWidth=noop}}
 local control={GetNamedChild=function(_,name)return fields[name]end,SetResizeToFitDescendents=noop,SetDimensions=noop}
 local globals={"WINDOW_MANAGER","GuiRoot","ZO_Dialogs_RegisterCustomDialog","ZO_Dialogs_ShowDialog","ZO_Dialogs_ReleaseDialog"};local old={}
 for _,name in ipairs(globals)do old[name]={_G[name]}end
 local original=string.rep("complete queued report\n",1000);local journal={phase="unknown"};local storage={latestReport=original,journal=journal};local errors=0
 WINDOW_MANAGER={CreateControlFromVirtual=function()return control end}
 GuiRoot={GetWidth=function()return 1000 end,GetHeight=function()return 800 end}
 ZO_Dialogs_RegisterCustomDialog=function(_,data)definition=data end
 ZO_Dialogs_ShowDialog=function(_,data)queued=data end
 ZO_Dialogs_ReleaseDialog=function()definition.finishedCallback(control)end
 local ok,err=pcall(function()
  dofile(ROOT.."/ProbeReport.lua")
  k.ProbeReport.Show(original,function(trace)
   errors=errors+1;if sinkThrows then error("error sink failed")end
   storage.latestReport=original.."\nReport display error:\n"..trace
  end)
  assert(queued and errors==0 and edit.text==nil,"Show must return before queued setup")
  control.data=queued
  local callback
  if stage=="setup"then callback=function()definition.setup(control,queued)end
  else
   definition.setup(control,queued)
   if stage=="shown"then callback=function()edit.OnEffectivelyShown(edit)end
   elseif stage=="close"then callback=function()definition.buttons[1].callback(control)end
   elseif stage=="finished"then callback=function()definition.finishedCallback(control)end
   elseif stage=="noChoice"then callback=function()definition.noChoiceCallback(control)end
   else callback=function()edit.OnEscape(edit)end end
  end
  assert(pcall(callback),"deferred callback leaked an exception")
  assert(errors==1 and storage.journal==journal and journal.phase=="unknown")
  if not sinkThrows then
   assert(storage.latestReport:sub(1,#original)==original)
   assert(storage.latestReport:find("deferred",1,true) and storage.latestReport:find("stack traceback",1,true))
  end
 end)
 for _,name in ipairs(globals)do _G[name]=old[name][1]end
 assert(ok,err)
end
function tests.queued_setup_error_persists_full_report_and_traceback()queuedFailure("setup")end
function tests.deferred_shown_focus_error_persists_full_report_and_traceback()queuedFailure("shown")end
function tests.deferred_close_release_error_persists_full_report_and_traceback()queuedFailure("close")end
function tests.deferred_finished_release_error_persists_full_report_and_traceback()queuedFailure("finished")end
function tests.deferred_escape_release_error_persists_full_report_and_traceback()queuedFailure("escape")end
function tests.deferred_no_choice_release_error_persists_full_report_and_traceback()queuedFailure("noChoice")end
function tests.broken_error_sink_cannot_leak_a_second_callback_exception()queuedFailure("shown",true)end
function tests.report_pages_bound_lines_and_do_not_split_utf8()
 local k=Fake.Load({"Core.lua","ProbeReport.lua"})
 local original=string.rep("\n",200)..string.rep("ж🙂",2000)
 local pages=k.ProbeReport.Pages(original)
 assert(#pages>2 and table.concat(pages)==original)
 for _,page in ipairs(pages)do
  local _,lines=page:gsub("\n","")
  assert(#page<=4096 and lines<=48 and utf8.len(page))
 end
 assert(#k.ProbeReport.Pages("")==1)
end
return tests
