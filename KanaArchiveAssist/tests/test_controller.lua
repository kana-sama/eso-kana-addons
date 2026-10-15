local T=KAATest
for _,n in ipairs({'Config','Profiles','History','RunCapture','ChoiceButton','Features','ChoiceModel','ContextSupport','Grades','View','ProfileWindow'})do T.load(n)end
local A=T.load('ESOAdapter');local C=T.load('Controller')
T.test('native scene opening captures the offer before its fragment unhides the control',function()
 local a=T.api();a.inside=true;a.started=true;local s=a.ENDLESS_DUNGEON_BUFF_SELECTOR_KEYBOARD
 local state='hidden';s.control:SetHidden(true)
 s.IsShowing=function()return state=='showing' or state=='shown'end
 s.RefreshBuffs=function()end;s.OnShowing=function(self)self:RefreshBuffs()end
 local p=KanaArchiveAssist.Profiles.New({},'EU','one');local c=C.Install(a,p)
 -- ZO_Scene fires SHOWING callbacks before refreshing its control fragments.
 state='showing';s:OnShowing()
 assert(c.offer,'opening scene must capture the offer while its control is still hidden')
 local button=c.choiceButton.control;assert(button and not button:IsHidden())
 s.control:SetHidden(false);state='shown'
 s.selectedBuffControl=s.buffControls[1];s:CommitChoice()
 a.ENDLESS_DUNGEON_MANAGER.callbacks.BuffStackCountChanged(0,1,1,0,false)
 T.eq(#p:GetActive().history,1);T.eq(s.commits,1)
 -- During HIDING the control can remain visible until the fade finishes.
 state='hiding';s:OnHiding();s:RefreshBuffs()
 assert(not c.offer);assert(button:IsHidden())
end)
T.test('adapter captures full offer before confirmation and ignores hovering',function()
 local a=T.api();a.inside=true;a.started=true;local p=KanaArchiveAssist.Profiles.New({},'EU','one');local rows={}
 local r=KanaArchiveAssist.RunCapture.New(function(o)rows[#rows+1]=o end,function()return 100 end)
 local adapter=A.Install(a,r,p,function()end);local selector=a.ENDLESS_DUNGEON_BUFF_SELECTOR_KEYBOARD
 selector:OnShowing();selector.selectedBuffControl=selector.buffControls[1];selector:CommitChoice();T.eq(selector.commits,1)
 selector:OnHiding();a.ENDLESS_DUNGEON_MANAGER.callbacks.BuffStackCountChanged(0,1,1,0,false)
 T.eq(#rows,1);T.eq(rows[1].selectedId,1);T.eq(#rows[1].options,2)
end)
T.test('restoring active run preserves identity and genuine completion creates next',function()
 local a=T.api();a.inside=true;a.started=true;local saved={};local p=KanaArchiveAssist.Profiles.New(saved,'EU','one')
 local function install()return A.Install(a,KanaArchiveAssist.RunCapture.New(function()end),p,function()end)end
 local adapter=install();local id=adapter:RunId();adapter:Initialized();T.eq(adapter:RunId(),id)
 adapter:Completed();adapter:Started();assert(adapter:RunId()~=id)
end)
T.test('controller registers only kaa and suppresses stale result after profile changes',function()
 local a=T.api();local p=KanaArchiveAssist.Profiles.New({},'EU','one');local view=KanaArchiveAssist.View.New(a)
 local controller=C.Install(a,p,nil,nil,view);assert(a.SLASH_COMMANDS['/kaa']);assert(not a.SLASH_COMMANDS['/kaa pause'])
 local o=T.observation(1,1);o.offerId='one';controller:OnOfferChanged(o)
 local token=controller.generation;p:Create('Other');controller:OnProfileChanged();assert(controller.generation>token);assert(not controller.currentPrediction)
 T.eq(#a.messages,2)
end)
T.test('completed choice ends offer lifecycle before identical later proposal',function()
 local a=T.api();a.inside=true;a.started=true;local time,stage=1000,1;a.GetTimeStamp=function()return time end;a.ENDLESS_DUNGEON_MANAGER.GetProgression=function()return stage,1,1 end
 local p=KanaArchiveAssist.Profiles.New({},'EU','one');local rows={};local r=KanaArchiveAssist.RunCapture.New(function(o)rows[#rows+1]=o end,function()return 100 end)
 local adapter=A.Install(a,r,p,function()end);local s=a.ENDLESS_DUNGEON_BUFF_SELECTOR_KEYBOARD;s:OnShowing();local first=adapter.offer.offerId;s.selectedBuffControl=s.buffControls[1];s:CommitChoice();s:OnHiding();a.ENDLESS_DUNGEON_MANAGER.callbacks.BuffStackCountChanged(0,1,1,0,false)
 time,stage=2000,3;s:OnShowing();assert(adapter.offer.offerId~=first);s:CommitChoice();a.ENDLESS_DUNGEON_MANAGER.callbacks.BuffStackCountChanged(0,1,1,0,false)
 T.eq(rows[2].timestamp,2000);T.eq(rows[2].context.stage,3)
end)
T.test('capture diagnostics are opt in and bounded',function()
 local a=T.api();local p=KanaArchiveAssist.Profiles.New({},'EU','one');local adapter=A.Install(a,KanaArchiveAssist.RunCapture.New(function()end),p,function()end)
 KanaArchiveAssist.captureTrace=nil;adapter:Trace('off');assert(not KanaArchiveAssist.captureTrace)
 KanaArchiveAssist.Config.debugCapture=true;for i=1,150 do adapter:Trace('test',i)end;KanaArchiveAssist.Config.debugCapture=false
 T.eq(#KanaArchiveAssist.captureTrace,128);T.eq(KanaArchiveAssist.captureTrace[128].args[1],150)
end)
T.test('failed evidence job reports failure without crashing the new grading path',function()
 local a=T.api();local p=KanaArchiveAssist.Profiles.New({},'EU','one');local controller=C.Install(a,p)
 local o=T.observation(2,2);o.offerId='test';controller.offer=o;controller.generation=1;controller.supportGeneration=1;controller.supportCacheKey='failure'
 controller.supportSnapshot={version=1,members={{}},dataset={}}
 controller.supportJob={Step=function()return true,nil,'numerical_failure'end}
 controller:Tick();assert(controller.currentPrediction);T.eq(controller.currentPrediction.byId[1].grade,nil)
 assert(a.messages[#a.messages]:find('расчёт не завершён',1,true))
end)

T.test('screen checkbox skips one choice despite an old pause and retains gained visions as context',function()
 local a=T.api();a.inside=true;a.started=true;a.GetAbilityEndlessDungeonBuffType=function()return 1 end
 local p=KanaArchiveAssist.Profiles.New({},'EU','one');p.character.learningEnabled=false
 local c=C.Install(a,p);local selector=a.ENDLESS_DUNGEON_BUFF_SELECTOR_KEYBOARD;selector:OnShowing()
 local button=c.choiceButton.control;assert(button and not button:IsHidden());local check=c.choiceButton.check;assert(check and check.checked)
 a.ZO_CheckButton_OnClicked(check);assert(not check.checked);T.eq(check.label:GetText(),'учитывать выбор')
 selector:RefreshBuffs();assert(c.capture:IsExcluded(c.offer.offerId))
 p:Create('Other');c:OnProfileChanged();assert(c.capture:IsExcluded(c.offer.offerId))
 selector.selectedBuffControl=selector.buffControls[1];selector:CommitChoice();assert(button:IsHidden());assert(c.choiceButton.root:IsHidden());T.eq(selector.commits,1)
 a.ENDLESS_DUNGEON_MANAGER.visions[1]=1;a.ENDLESS_DUNGEON_MANAGER.callbacks.BuffStackCountChanged(1,1,1,0,false)
 T.eq(#p:GetActive().history,0)
 selector:OnShowing();assert(not button:IsHidden());assert(check.checked)
 selector.selectedBuffControl=selector.buffControls[2];selector:CommitChoice();a.ENDLESS_DUNGEON_MANAGER.visions[2]=1
 a.ENDLESS_DUNGEON_MANAGER.callbacks.BuffStackCountChanged(1,2,1,0,false)
 local history=p:GetActive().history;T.eq(#history,1);T.eq(history[1].selectedId,2);T.eq(history[1].context.visions[1][1],1);T.eq(history[1].context.visions[1][2],1)
end)
T.test('include checkbox resets on reroll and never selects a perk itself',function()
 local a=T.api();a.inside=true;a.started=true;local p=KanaArchiveAssist.Profiles.New({},'EU','one');local c=C.Install(a,p)
 local s=a.ENDLESS_DUNGEON_BUFF_SELECTOR_KEYBOARD;s:OnShowing();local b=c.choiceButton.control
 local check=c.choiceButton.check;a.ZO_CheckButton_OnClicked(check);a.ZO_CheckButton_OnClicked(check);assert(check.checked);assert(not c.capture:IsExcluded(c.offer.offerId));T.eq(s.commits,nil)
 a.ZO_CheckButton_OnClicked(check);local old=c.offer.offerId;s:SetIsRerolling(true);assert(b:IsHidden());assert(not c.capture.offer)
 s:SetIsRerolling(false);s:OnShowing();assert(c.offer.offerId~=old);assert(not c.capture:IsExcluded(c.offer.offerId));assert(check.checked);assert(not b:IsHidden())
 s:OnHiding();assert(b:IsHidden());assert(c.choiceButton.root:IsHidden());a.ZO_CheckButton_OnClicked(check);assert(not c.capture:IsExcluded(c.capture.offer.offerId))
end)
T.test('profile state shows actual acknowledgements frozen ownership and persistent failures',function()
 local a=T.api();a.inside=true;a.started=true;local frame=100;a.GetFrameTimeSeconds=function()return frame end
 local saved={};local p=KanaArchiveAssist.Profiles.New(saved,'EU','one');local c=C.Install(a,p);local original=p:GetActive().id
 local s=a.ENDLESS_DUNGEON_BUFF_SELECTOR_KEYBOARD;s:OnShowing();T.eq(c:ProfileState(original).flow.state,'offered')
 s.selectedBuffControl=s.buffControls[1];s:CommitChoice();T.eq(c:ProfileState(original).flow.state,'pending');T.eq(c:ProfileState(original).summary.total,0)
 p:Create('Other');c:OnProfileChanged();a.ENDLESS_DUNGEON_MANAGER.callbacks.BuffStackCountChanged(0,1,1,0,false)
 local state=c:ProfileState(original);T.eq(state.summary.total,1);T.eq(state.summary.last.recordedAt,1000);T.eq(state.summary.last.recordedTime,'12:34:56');T.eq(state.flow.state,'recorded')
 T.eq(c:ProfileState(p:GetActive().id).summary.total,0)
 s:OnShowing();s:CommitChoice();frame=131;c:Tick();local failed=c:ProfileState(p:GetActive().id)
 T.eq(failed.flow.state,'failed');T.eq(failed.flow.reason,'timeout');T.eq(failed.summary.total,0)
 local restored=KanaArchiveAssist.Profiles.New(saved,'EU','one');local fresh=C.Install(T.api(),restored)
 T.eq(fresh:ProfileState(restored:GetActive().id).activity.reason,'timeout')
end)
T.test('missing or invalid offers are reported without interrupting native selection',function()
 local a=T.api();a.inside=true;local p=KanaArchiveAssist.Profiles.New({},'EU','one');local c=C.Install(a,p);local s=a.ENDLESS_DUNGEON_BUFF_SELECTOR_KEYBOARD
 s.selectedBuffControl=s.buffControls[1];s:CommitChoice();T.eq(s.commits,1);T.eq(c:ProfileState(p:GetActive().id).flow.reason,'offer_missing')
 a.GetEndlessDungeonBuffSelectorBucketTypeChoice=function()return 0 end;s:OnShowing()
 T.eq(c:ProfileState(p:GetActive().id).flow.reason,'invalid_offer');assert(not c.capture.offer)
 a.GetEndlessDungeonBuffSelectorBucketTypeChoice=function(bucket)return bucket<2 and bucket+1 or 0 end;s:OnShowing();s.selectedBuffControl.abilityId=99;s:CommitChoice()
 T.eq(c:ProfileState(p:GetActive().id).flow.reason,'invalid_selection');T.eq(#p:GetActive().history,0)
end)
T.test('open profile window follows confirmed and excluded choices without reopening',function()
 local a=T.api();a.inside=true;a.started=true;local p=KanaArchiveAssist.Profiles.New({},'EU','one');local c=C.Install(a,p)
 a.SLASH_COMMANDS['/kaa']();local w=c.window;local s=a.ENDLESS_DUNGEON_BUFF_SELECTOR_KEYBOARD
 T.eq(w.total:GetText(),'0');s:OnShowing();s.selectedBuffControl=s.buffControls[1];s:CommitChoice()
 T.eq(w.total:GetText(),'0');assert(w.status:GetText():find('подтверждения',1,true))
 a.ENDLESS_DUNGEON_MANAGER.callbacks.BuffStackCountChanged(0,1,1,0,false)
 T.eq(w.total:GetText(),'1');T.eq(w.runCount:GetText(),'+1 в этом ране');T.eq(w.lastName:GetText(),'Ability 1');assert(w.lastTime:GetText():find('12:34:56',1,true))
 assert(w.status:GetText():find('учтён',1,true))
 s:OnShowing();a.ZO_CheckButton_OnClicked(c.choiceButton.check);s:CommitChoice()
 a.ENDLESS_DUNGEON_MANAGER.callbacks.BuffStackCountChanged(0,1,1,0,false)
 T.eq(w.total:GetText(),'1');assert(w.status:GetText():find('исключён',1,true));T.eq(#p:GetActive().history,1)
end)
