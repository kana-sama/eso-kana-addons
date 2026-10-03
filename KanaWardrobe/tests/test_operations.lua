local Fake=dofile(ROOT..'/tests/support/fake_eso.lua')
local function setup(saved)
 local k=Fake.Load({'Core.lua'})
 for _,name in ipairs({'OperationJournal.lua','OperationExecutor.lua'})do
  local f=io.open(ROOT..'/'..name);if f then f:close();dofile(ROOT..'/'..name)end
 end
 assert(k.OperationExecutor,'stepwise executor is not implemented')
 local clock={time=0,timers={},serial=0}
 function clock:NowMs()return self.time end
 function clock:Schedule(delay,fn)self.serial=self.serial+1;self.timers[self.serial]={at=self.time+delay,fn=fn};return self.serial end
 function clock:Cancel(id)self.timers[id]=nil end
 function clock:Advance()
  local id;for key in pairs(self.timers)do if not id or key<id then id=key end end
  if id then local t=self.timers[id];self.timers[id]=nil;self.time=t.at;t.fn()end
 end
 local h={calls={},pending={}}
 function h:Run(step,op,report,done)
  self.calls[#self.calls+1]=step.kind
  if step.kind=='diff'then done({steps={{id='one',kind='equip'},{id='two',kind='verify'}}})
  else self.pending[#self.pending+1]={done=done,report=report}end
 end
 local f={k=k,saved=saved or {},clock=clock,h=h}
 f.x=k.OperationExecutor.New(f.saved,clock,h)
 function f:start()assert(self.x:Start({kind='apply',name='Test'}));assert(#self.h.calls==0);self.clock:Advance();self.clock:Advance()end
 return f
end
return {
 diff_visible_before_capture_and_success_clears_active=function()
  local f=setup();f:start();assert(f.x:GetView().steps[1].status=='done')
  f.h.pending[1].done({actual='equipped'});f.clock:Advance();f.h.pending[2].done({})
  assert(not f.saved.operation and not f.x:GetView())
 end,
 failure_retry_does_not_replay_confirmed_steps=function()
  local f=setup();f:start();f.h.pending[1].done(nil,f.k.Problem('requestTimeout',{uid='item'}))
  assert(f.x:GetView().status=='failed' and f.saved.operation.steps[2].problem.details.uid=='item')
  assert(f.x:Continue());f.clock:Advance();assert(#f.h.calls==3 and f.h.calls[3]=='equip')
  assert(#f.saved.operation.steps[2].attempts==2)
 end,
 pause_waits_for_submitted_step_and_hide_does_not_pause=function()
  local f=setup();f:start();f.x:SetVisible(false);assert(f.x:IsBusy())
  f.x:Pause();f.h.pending[1].done({});f.clock:Advance()
  assert(f.x:GetView().status=='paused' and #f.h.calls==2)
  assert(f.x:Continue());f.clock:Advance();assert(f.h.calls[3]=='verify')
 end,
 restart_fences_late_callback_and_recalculates=function()
  local f=setup();f:start();local old=f.h.pending[1].done
  old(nil,f.k.Problem('requestTimeout'));assert(f.x:Restart());f.clock:Advance();f.clock:Advance()
  old({});assert(f.saved.operation.steps[2].status=='running')
  assert(#f.saved.operationHistory==1 and f.h.calls[3]=='diff')
 end,
 reload_is_paused_and_retains_request_facts=function()
  local f=setup();f:start();f.h.pending[1].report({sent=true,uid='item'})
  local g=setup(f.k.Copy(f.saved));assert(#g.h.calls==0 and g.x:GetView().status=='paused')
  assert(g.saved.operation.steps[2].attempts[1].pending.uid=='item')
  assert(g.x:Continue());g.clock:Advance();assert(g.h.calls[1]=='equip')
 end,
 failed_attempt_retained_after_success=function()
  local f=setup();f:start();f.h.pending[1].done(nil,f.k.Problem('bad'));f.x:Continue();f.clock:Advance()
  f.h.pending[2].done({});f.clock:Advance();f.h.pending[3].done({})
  assert(not f.saved.operation and #f.saved.operationHistory==1)
  assert(f.saved.operationHistory[1].steps[2].attempts[1].problem.code=='bad')
 end,
 thrown_handler_becomes_error_and_new_selection_is_available=function()
  local f=setup();function f.h:Run()error('bad native call')end
  f.x:Start({kind='apply'});f.clock:Advance()
  assert(f.x:GetView().status=='failed' and not f.x:IsBusy())
  assert(f.x:Start({kind='apply',name='Another'}))
 end,
 double_click_cannot_start_second_dispatcher=function()
  local f=setup();f:start();local ok,p=f.x:Start({kind='apply'});assert(not ok and p.code=='operationBusy')
  assert(not f.x:Continue() and not f.x:Restart())
 end,
 invalid_saved_operation_keeps_raw_diagnostics_and_allows_new_start=function()
  local f=setup({operation={version=999}});assert(f.x:GetView().status=='failed')
  assert(f.x:Start({kind='apply'}));assert(#f.saved.operationHistory>=1)
 end,
 malformed_saved_steps_do_not_break_initialization=function()
  for _,steps in ipairs({{'broken'},{{kind='equip',attempts='broken'}}})do
   local f=setup({operation={version=1,intent={kind='apply'},steps=steps,index=1}})
   assert(f.x:GetView().status=='failed' and f.saved.invalidOperation)
   assert(f.x:Start({kind='apply'}))
  end
 end,
 unserializable_result_stops_visibly_and_allows_retry=function()
  local f=setup();f:start();local cycle={};cycle.self=cycle
  f.h.pending[1].done(cycle)
  assert(f.x:GetView().status=='failed' and f.saved.operation.steps[2].problem.code=='operationError')
  assert(f.x:Continue());f.clock:Advance();f.h.pending[2].done({actual=true})
  f.clock:Advance();f.h.pending[3].done({});assert(not f.x:GetView())
 end,
 report_prioritizes_failure_and_bounds_large_snapshots=function()
  local f=setup();local op={id=1,index=2,status='failed',intent={kind='apply',name='Test'},steps={
   {kind='diff',status='done'}, {kind='skills',status='failed',problem=f.k.Problem('operationError',{error='specific native failure'}),attempts={}}}}
  local huge={};for i=1,2000 do huge[i]=string.rep('large snapshot',100)end
  op.target=huge;op.steps[2].pending={actual=huge};local saved={operation=op}
  local report=f.k.OperationJournal.Report(saved)
  assert(#report<=24576,'report must not flatten an unbounded journal')
  assert(report:sub(1,1500):find('specific native failure',1,true),'failure must precede snapshots')
  assert(report:find('SavedVariables',1,true),'tell reader where full journal remains')
  assert(#op.target==2000 and #op.target[1]==#string.rep('large snapshot',100),'report must not mutate saved data')
 end,
 report_dialog_failure_preserves_original_operation=function()
  local f=setup();f:start();f.h.pending[1].done(nil,f.k.Problem('requestTimeout',{uid='ring'}))
  local original=f.saved.operation;local callback
  f.k.ProbeReport={Show=function(text,onError)
   assert(text:sub(1,1500):find('requestTimeout',1,true));callback=onError
  end}
  f.k.OperationJournal.ShowReport(f.saved);callback('deferred display failure')
  assert(f.saved.operationReportError=='deferred display failure' and f.saved.operation==original)
  f.k.ProbeReport.Show=function()error('synchronous display failure')end
  assert(pcall(f.k.OperationJournal.ShowReport,f.saved))
  assert(f.saved.operationReportError:find('synchronous display failure',1,true))
  assert(f.saved.operation.steps[2].problem.code=='requestTimeout')
 end,
 thrown_handler_retains_traceback=function()
  local f=setup();function f.h:Run()error('specific exception')end
  f.x:Start({kind='apply'});f.clock:Advance()
  local p=f.saved.operation.steps[1].problem
  assert(p.details.error:find('specific exception',1,true))
  assert(p.details.traceback and p.details.traceback:find('stack traceback',1,true))
 end,
 journal_rejects_runtime_handles=function()
  local f=setup();local ok=pcall(f.k.OperationJournal.Plain,{callback=function()end});assert(not ok)
 end,
}
