local Fake=dofile(ROOT..'/tests/support/fake_eso.lua')
local G=dofile(ROOT..'/tests/support/geometry_controls.lua')
local function create(fn)
 local k=Fake.Load({'Core.lua','Slots.lua','lang/en.lua','Dialogs.lua','OperationJournal.lua','OperationWindow.lua'})
 assert(k.OperationWindow,'operation window not implemented')
 G.With(1600,1000,1,function(f)
  function WINDOW_MANAGER:CreateTopLevelWindow(n)return f:Control(n,GuiRoot,CT_CONTROL)end
  local x={saved={},view={name='Test',status='failed',visible=true,index=2,steps={{kind='diff',status='done'},{kind='equip',status='failed',details={slot=EQUIP_SLOT_RING1,link='Ring'},problem=k.Problem('operationUnconfirmed',{uid='abc',elapsed=5000})}}}}
  function x:GetView()return self.view end
  function x:SetVisible(v)self.visible=v end
  function x:Pause()self.paused=true end
  function x:Continue()self.continued=true end
  function x:Restart()self.restarted=true end
  local w=k.OperationWindow.New(x,_G);fn(f,w,x,k)
 end)
end
return {
 appearance_wait_displays_remaining_cooldown_in_current_step=function()create(function(f,w,x)
  x.view.status='running';x.view.steps[2]={kind='appearance',status='running',details={beforeName='Old',targetName='New'},pending={phase='cooldown',remainingMs=2300}}
  w:Refresh(x.view)
  assert(w.rows[2].body:GetText():find('3 s',1,true) and w.rows[2].body:GetText():find('cooldown',1,true))
  x.view.status='paused';x.view.steps[2].status='pending';w:Refresh(x.view)
  assert(not w.rows[2].body:GetText():find('3 s',1,true),'paused timer must not display a stale countdown')
  x.view.status='running';x.view.steps[2].status='running'
  x.view.steps[2].pending={phase='waiting',sent=true};w:Refresh(x.view)
  assert(not w.rows[2].body:GetText():find('cooldown',1,true))
 end)end,
 native_button_api_allows_complete_window_layout=function()create(function(f,w,x)
  assert(w.report.GetText==nil,'fixture must not invent a ButtonControl getter')
  assert(w.report:GetLabelControl():GetText()=='Copy report')
  assert(w.root:GetWidth()>0 and w.root:GetHeight()>=300)
  G.Contained(w.bg,w.root);G.Contained(w.scroll,w.root);G.Contained(w.hint,w.root)
  assert(w.bg:GetWidth()==w.root:GetWidth() and w.bg:GetHeight()==w.root:GetHeight())
 end)end,
 active_row_follows_until_user_scrolls_and_resets_for_new_operation=function()create(function(f,w,x)
  x.view.id=1
  for i=3,30 do x.view.steps[i]={kind='verify',status='pending'}end
  x.view.index=20;w:Refresh(x.view)
  local count=w.scroll.followCalls;assert(count and w.scroll.followOffset>0)
  w:Refresh(x.view);assert(w.scroll.followCalls==count,'routine refresh restarted scroll animation')
  assert(w.scroll.onInteractWithScrollbarCallback,'must handle wheel, thumb and arrows through the native callback')
  w.scroll.onInteractWithScrollbarCallback();x.view.index=21;w:Refresh(x.view)
  assert(w.scroll.followCalls==count,'manual scroll must disable following')
  x.view.visible=false;w:Refresh(x.view);x.view.visible=true;w:Refresh(x.view)
  assert(w.scroll.followCalls==count,'hiding/reopening must preserve manual position')
  x.view.id=2;w:Refresh(x.view);assert(w.scroll.followCalls>count)
 end)end,
 tall_error_step_follows_its_heading_not_the_bottom=function()create(function(f,w,x)
  x.view.id=1;x.view.steps[2].kind='skills';x.view.steps[2].details={changes={}}
  for i=1,8 do x.view.steps[2].details.changes[i]={name=string.rep('Long name ',20),target={kind='passive',rank=2}}end
  w:Refresh(x.view)
  local row=w.rows[2];assert(row:GetHeight()>w.scroll:GetHeight())
  assert(math.abs(w.scroll.followOffset-(row:GetTop()-w.child:GetTop()))<1)
 end)end,
 status_marks_share_a_centered_heading_cell=function()create(function(f,w,x)
  for _,row in ipairs(w.rows)do
   assert(row.mark.align==TEXT_ALIGN_CENTER and row.mark.verticalAlign==TEXT_ALIGN_CENTER)
   local a,b=row.mark:Rect(),row.doneIcon:Rect()
   assert(math.abs((a.l+a.r)-(b.l+b.r))<.01 and math.abs((a.t+a.b)-(b.t+b.b))<.01)
  end
 end)end,
 native_dialog_layer_is_above_the_operation_window=function()create(function(f,w,x)
  assert(w.root.tier==DT_MEDIUM and w.root.level<ZO_MEDIUM_TIER_KEYBOARD_STANDARD_DIALOG)
 end)end,
 russian_footer_fits_and_wraps_on_narrow_screen=function()create(function(f,w,x,k)
  f:Put('GetCVar',function()return 'ru'end);dofile(ROOT..'/lang/ru.lua')
  w.pause:SetText(k.Text('OP_PAUSE'));w.resume:SetText(k.Text('OP_CONTINUE'))
  w.restart:SetText(k.Text('OP_RESTART'));w.report:SetText(k.Text('OP_REPORT'))
  for _,width in ipairs({1600,540})do
   f.width=width;w:Refresh(x.view)
   local buttons={w.pause,w.resume,w.restart,w.report}
   for i,b in ipairs(buttons)do
    G.Contained(b,w.root);assert(b:GetWidth()>=b:GetLabelControl():GetTextWidth()+16,'button clips localized text')
    for j=i+1,#buttons do G.Disjoint(b,buttons[j])end
   end
   G.Disjoint(w.scroll,w.pause);G.Disjoint(w.report,w.hint)
  end
 end)end,
 current_step_and_completed_count_do_not_rely_on_color=function()create(function(f,w,x)
  x.view.kind='apply';x.view.status='running';x.view.steps[2].status='running';x.view.steps[2].problem=nil
  w:Refresh(x.view)
  assert(w.rows[2].mark:GetText()~='2' and w.subtitle:GetText():find('1 / 2',1,true))
  assert(w.rows[2].highlight and not w.rows[2].highlight:IsHidden())
 end)end,
 buttons_hide_pause_continue_restart_are_distinct=function()create(function(f,w,x)
  w.close:GetHandler('OnClicked')();assert(x.visible==false and not x.paused)
  w.pause:GetHandler('OnClicked')();assert(x.paused)
  w.resume:GetHandler('OnClicked')();assert(x.continued)
  w.restart:GetHandler('OnClicked')();assert(x.restarted)
 end)end,
 failed_row_explains_reason_and_keeps_technical_facts_in_report=function()create(function(f,w,x,k)
  local body=w.rows[2].body:GetText()
  assert(body:find(k.Dialogs.Problem(x.view.steps[2].problem),1,true))
  assert(not body:find('abc',1,true) and not body:find('operationUnconfirmed',1,true))
  local report=k.OperationJournal.Report({operation=x.view})
  assert(report:find('abc',1,true) and report:find('5000',1,true) and report:find('operationUnconfirmed',1,true))
  assert(w.resume.enabled and w.restart.enabled and not w.pause.enabled)
 end)end,
 unexpected_error_displays_actual_reason_in_the_step=function()create(function(f,w,x,k)
  x.view.steps[2].problem=k.Problem('operationError',{error='Native call rejected: example',traceback='full private trace'})
  w:Refresh(x.view)
  local body=w.rows[2].body:GetText()
  assert(body:find('Native call rejected: example',1,true),'reason must not require opening a report')
  assert(not body:find('full private trace',1,true))
  x.view.steps[2].problem=k.Problem('futureUnknownError',{error='Detailed refusal'})
  w:Refresh(x.view);body=w.rows[2].body:GetText()
  assert(body:find('futureUnknownError',1,true) and body:find('Detailed refusal',1,true))
 end)end,
 full_backpack_has_an_actionable_error=function()create(function(f,w,x,k)
  x.view.steps[2].problem=k.Problem('bagFull');w:Refresh(x.view)
  assert(w.rows[2].body:GetText():find('backpack',1,true))
  assert(k.Dialogs.Problem(x.view.steps[2].problem)~=k.Strings.UNKNOWN_PROBLEM)
 end)end,
 success_clears_and_hides_window=function()create(function(f,w,x)
  x.view=nil;w:Refresh(nil);assert(w.root:IsHidden() and w.rows[2]:IsHidden())
 end)end,
 long_plan_scrolls_inside_bounded_window=function()create(function(f,w,x)
  for i=3,80 do x.view.steps[i]={kind='verify',status='pending'}end
  w:Refresh(x.view);assert(w.root:GetHeight()<=720 and w.child:GetHeight()>w.scroll:GetHeight())
  G.Contained(w.scroll,w.root);G.Contained(w.resume,w.root)
 end)end,
 paused_reload_can_reopen_without_work=function()create(function(f,w,x)
  x.view.visible=false;x.view.status='paused';w:Refresh(x.view);assert(w.root:IsHidden())
  x.view.visible=true;w:Refresh(x.view);assert(not w.root:IsHidden() and not x.continued)
 end)end,
}
