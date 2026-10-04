-- Native set authoring: restricted expressions and independent set references.
local SetEditor={}; SetEditor.__index=SetEditor; KanaEffects.SetEditor=SetEditor
local I,P=KanaEffects.Inspector,KanaEffects.Picker; local serial=0
local function copy(v) return P.Copy(v) end
local function getNode(root,path)
    local node=root
    for _,index in ipairs(path) do
        if not node then return end
        if node.op=='not' then if index~=1 then return end; node=node.arg
        elseif node.args then node=node.args[index] else return end
    end
    return node
end
local function replaceNode(set,path,node)
    if #path==0 then set.predicate=node; return true end
    local parentPath=copy(path); local index=table.remove(parentPath); local parent=getNode(set.predicate,parentPath)
    if not parent then return false end
    if parent.op=='not' then parent.arg=node or {op='or',args={}}
    elseif parent.args then if node then parent.args[index]=node else table.remove(parent.args,index) end else return false end
    return true
end
local function empty(kind)
    if kind=='and' or kind=='or' then return {op=kind,args={}} end
    if kind=='not' then return {op='not',arg={op='or',args={}}} end
    return {op='facet',field='kind',values={'buff','debuff','unknown'}}
end
function SetEditor.New(editor,session,picker,catalog,store,api)
    serial=serial+1; return setmetatable({editor=editor,session=session,picker=picker,catalog=catalog,store=store,api=api,labels=I.Labels(api),name='KanaEffectsSets'..serial,tab='code',nodePath={},source='player',expressionBuffers={},nameBuffers={}},SetEditor)
end
function SetEditor:IsOpen() return self.open==true end
function SetEditor:GetSet(id) local p=self.session:ReadDraft(); return p and I.Find(p.sets,id or self.selected) end
local function expression(set,sets) return KanaEffects.Rules.SetExpression(set,sets) end
local function diagnosticMessage(diag)
    local first=diag and diag[1]; return first and (first.message or first.code) or 'Неверное правило.'
end
function SetEditor:Put(set)
    local ok,diag=self.editor:Apply({type='set.put',set=set})
    if ok then
        self:RebaseReferences(self.session:ReadDraft())
        self.expressionBuffers[set.id]=nil; self.nameBuffers[set.id]=nil; self:Refresh()
    end
    return ok,diag
end
function SetEditor:RebaseReferences(draft)
    if not draft then return end
    local names={}
    for _,set in ipairs(draft.sets) do
        names[set.id]=set.name; local old=self.setNames and self.setNames[set.id]
        if old and old~=set.name then
            for id,source in pairs(self.expressionBuffers) do self.expressionBuffers[id]=KanaEffects.Rules.RewriteReferences(source,old,set.name,set.id) end
            if self.nameBuffers[set.id]==old then self.nameBuffers[set.id]=set.name end
        end
    end
    for id in pairs(self.expressionBuffers) do if not names[id] then self.expressionBuffers[id]=nil end end
    for id in pairs(self.nameBuffers) do if not names[id] then self.nameBuffers[id]=nil end end
    for id in pairs(self.panelRenameWarnings or {}) do if not names[id] then self.panelRenameWarnings[id]=nil end end
    self.setNames=names
    local panels={}
    for _,w in ipairs(draft.widgets) do
        panels[w.id]=w.name; local old=self.panelNames and self.panelNames[w.id]
        if old and old~=w.name then
            for id,source in pairs(self.expressionBuffers) do
                local rewritten=KanaEffects.Rules.RewritePanelReferences(source,old,w.name)
                self.expressionBuffers[id]=rewritten
                if rewritten==source and not KanaEffects.Rules.ParseExpression(source) and source:find('on_panel',1,true) and source:find(old,1,true) then
                    self.panelRenameWarnings=self.panelRenameWarnings or {}; self.panelRenameWarnings[id]=self.labels.renameUnfinishedHint
                end
            end
        end
    end
    self.panelNames=panels
end
function SetEditor:ValidateExpression(source,id)
    local p=self.session:ReadDraft(); local set=p and I.Find(p.sets,id or self.selected)
    if not set then return false,'Набор не найден.' end
    -- Exact generated legacy code is a no-op, including ASTs beyond authoring budgets.
    if source==expression(set,p.sets) then if self.form then self.form:Message('') end; return true end
    local parsed,message=KanaEffects.Rules.ParseExpression(source)
    if parsed then
        local candidate=copy(p.sets); local changed=I.Find(candidate,set.id)
        changed.predicate={op='expression',source=source}; changed.includeSets={}; changed.excludeSets={}
        local compiled,diag=KanaEffects.Rules.Compile(candidate,p.longThreshold,p.widgets,p.hidden)
        if not compiled then message=diagnosticMessage(diag) end
    end
    if self.panelRenameWarnings and self.panelRenameWarnings[set.id] then
        if parsed then self.panelRenameWarnings[set.id]=nil else message=(message or '')..'\n'..self.panelRenameWarnings[set.id] end
    end
    if self.form then self.form:Message(message or '') end
    return parsed~=nil and message==nil,message
end
function SetEditor:SetExpression(id,source)
    local set=self:GetSet(id); local p=self.session:ReadDraft(); if not set then return false end
    if source==expression(set,p.sets) then return true end
    local ok,message=self:ValidateExpression(source,id)
    if not ok then return false,{{code='invalid_expression',path='predicate.source',message=message}} end
    set.predicate={op='expression',source=source}; set.includeSets={}; set.excludeSets={}; return self:Put(set)
end
function SetEditor:CaptureFields()
    if not self.open or not self.form then return end
    for _,row in pairs(self.form.rows) do if row.generation==self.form.generation then
        if row.kind=='code' then self.expressionBuffers[self.selected]=row.input:GetText()
        elseif row.kind=='edit' and row.edit==self.nameInput then self.nameBuffers[self.selected]=row.input:GetText() end
    end end
end
function SetEditor:Candidate(id)
    local p=self.session:ReadDraft(); local set=p and I.Find(p.sets,id); if not set then return end
    local source=self.expressionBuffers[id] or expression(set,p.sets)
    local ok,message=self:ValidateExpression(source,id); if not ok then return nil,message end
    set.name=self.nameBuffers[id] or set.name
    if not set.name:find('%S') then return nil,'Укажите имя набора.' end
    local original=I.Find(p.sets,id)
    if source~=expression(original,p.sets) then set.predicate={op='expression',source=source}; set.includeSets={}; set.excludeSets={} end
    local candidate=copy(p); local previous=self:GetSet(id)
    for index,value in ipairs(candidate.sets) do if value.id==id then candidate.sets[index]=copy(set) end end
    if previous.name~=set.name then KanaEffects.Rules.RenameReferences(candidate,previous.name,set.name,set.id) end
    local valid,diag=KanaEffects.Rules.Compile(candidate.sets,candidate.longThreshold,candidate.widgets,candidate.hidden)
    if not valid then return nil,diagnosticMessage(diag) end
    return set
end
function SetEditor:ShowError(id,message)
    self.selected=id; if not self.open then self:Open() else self:Refresh() end
    if self.form then self.form:Message(message or 'Неверное правило.') end
end
function SetEditor:Check()
    self:CaptureFields(); local candidate,message=self:Candidate(self.selected)
    if not candidate then self:ShowError(self.selected,message); return false end
    if self.form then self.form:Message(''); self.form:Notice('Правило проверено. Сохранение применит его к текущему черновику.') end
    return true
end
function SetEditor:SaveSelected()
    self:CaptureFields(); local candidate,message=self:Candidate(self.selected)
    if not candidate then self:ShowError(self.selected,message); return false end
    local ok,diag=self:Put(candidate)
    if not ok then self:ShowError(self.selected,diagnosticMessage(diag)) end
    return ok,diag
end
-- Closed windows retain invalid text too. Only ending the outer transaction
-- discards buffers; outer Save captures all of them before commands refresh UI.
function SetEditor:GetPendingEdits()
    local p=self.session:ReadDraft(); if not p then return {} end
    self:CaptureFields(); local pending={}; local generation=self.editor.generation
    for _,set in ipairs(p.sets) do
        local id=set.id; local source=self.expressionBuffers[id]; local name=self.nameBuffers[id]
        if (source and source~=expression(set,p.sets)) or (name and name~=set.name) then
            local candidate,message=self:Candidate(id)
            if not candidate then self:ShowError(id,'Набор «'..set.name..'»: '..message); return nil end
            local names=copy(self.setNames or {}); local panels=copy(self.panelNames or {})
            pending[#pending+1]={value=candidate,callback=function(value)
                if not self.editor:IsOpen() or generation~=self.editor.generation then return false end
                local draft=self.session:ReadDraft()
                if not draft then return false end
                if value.predicate and value.predicate.op=='expression' then
                    for _,current in ipairs(draft.widgets) do local old=panels[current.id]; if old and old~=current.name then value.predicate.source=KanaEffects.Rules.RewritePanelReferences(value.predicate.source,old,current.name) end end
                    for _,current in ipairs(draft.sets) do
                        local old=names[current.id]
                        if old and old~=current.name then value.predicate.source=KanaEffects.Rules.RewriteReferences(value.predicate.source,old,current.name,current.id) end
                    end
                end
                return self:Put(value)
            end}
        end
    end
    return pending
end
function SetEditor:HasPendingChanges()
    self:CaptureFields(); local p=self.session:ReadDraft(); if not p then return false end
    for _,set in ipairs(p.sets) do
        local source,name=self.expressionBuffers[set.id],self.nameBuffers[set.id]
        if (source and source~=expression(set,p.sets)) or (name and name~=set.name) then return true end
    end
    return false
end
function SetEditor:Rename(id,name) local set=self:GetSet(id); if not set then return false end; set.name=name; return self:Put(set) end
function SetEditor:Delete(id) self.selected=id; return self.editor:Apply({type='set.delete',setId=id}) end
function SetEditor:Create()
    local p=self.session:ReadDraft(); if not p then return false end; local id=self.editor:_NewId('set-',p.sets)
    local used={}; for _,set in ipairs(p.sets) do used[set.name]=true end
    local name=self.labels.newSet; local suffix=2
    while used[name] do name=self.labels.newSet..' '..suffix; suffix=suffix+1 end
    local ok,diag=self:Put({id=id,name=name,predicate={op='and',args={}},includeSets={},excludeSets={}})
    if ok then self.selected=id; self.nodePath={}; self:Refresh() end; return ok,diag
end
function SetEditor:ToggleReference(id,field,ref)
    local set=self:GetSet(id); if not set or (field~='includeSets' and field~='excludeSets') then return false end
    local exists=false; for i=#set[field],1,-1 do if set[field][i]==ref then table.remove(set[field],i); exists=true end end
    if not exists then set[field][#set[field]+1]=ref end; return self:Put(set)
end
function SetEditor:SplitWith(id,ref)
    local set=self:GetSet(id); if not set then return false end
    if not I.Contains(set.excludeSets,ref) then set.excludeSets[#set.excludeSets+1]=ref end; return self:Put(set)
end
function SetEditor:SetNode(id,path,node)
    local set=self:GetSet(id); if not set or not replaceNode(set,path,copy(node)) then return false end; return self:Put(set)
end
function SetEditor:SetOperation(id,path,op)
    local set=self:GetSet(id); if not set then return false end
    local old=getNode(set.predicate,path); local node
    if old and old.op==op then return true end
    if op=='and' or op=='or' then
        local children=old and (old.args or {old.op=='not' and old.arg or old}) or {}
        node={op=op,args=copy(children)}
    elseif op=='not' then node={op='not',arg=old and copy(old) or {op='or',args={}}}
    elseif op=='facet' then node=empty(op)
    else return false end
    return self:SetNode(id,path,node)
end
function SetEditor:AddCondition(id,path,kind,data)
    local set=self:GetSet(id); if not set then return false end
    local node=kind=='selector' and {op='selector',selector=copy(data)} or kind=='facet' and {op='facet',field=data.field,values=copy(data.values)} or empty(kind)
    local parent=getNode(set.predicate,path)
    if parent==nil and #path==0 then set.predicate=node
    elseif parent and parent.op=='not' and parent.arg and parent.arg.args then parent.arg.args[#parent.arg.args+1]=node
    elseif parent and parent.args then parent.args[#parent.args+1]=node
    else return false end
    return self:Put(set)
end
function SetEditor:RemoveCondition(id,path)
    local set=self:GetSet(id); if not set or not replaceNode(set,path,nil) then return false end; self.nodePath={}; return self:Put(set)
end
function SetEditor:ManualSelector(id,exclude,initiator,path)
    local generation=self.editor.generation; local function current() return self.editor.open and not self.editor.disposed and generation==self.editor.generation and self:GetSet(id)~=nil end
    self.picker:Open({purpose='set',initiator=initiator,onEscape=function() self.editor:RequestClose() end,canRestoreFocus=current,
        onChoose=function(selector)
            if not current() then return false end
            if path then return self:SetNode(id,path,{op='selector',selector=selector}) end
            local set=self:GetSet(id); local original=set.predicate or {op='or',args={}}; local manual={op='selector',selector=selector}
            set.predicate=exclude and {op='and',args={original,{op='not',arg=manual}}} or {op='or',args={original,manual}}
            self.tab='code'; self.nodePath={}; return self:Put(set)
        end})
end
local function simplePredicate(state)
    if state.support then
        local predicate=KanaEffects.Presets.SupportPredicate(copy(state.kind),copy(state.lifetime),copy(state.category))
        if state.named~='any' then predicate.args[#predicate.args+1]={op='facet',field='named',values={state.named=='only'}} end
        for _,field in ipairs({'origin','castBy'}) do if state[field] and #state[field]>0 then predicate.args[2].args[#predicate.args[2].args+1]={op='facet',field=field,values=copy(state[field])} end end
        return predicate
    end
    local args={}
    if state.kind then args[#args+1]={op='facet',field='kind',values=copy(state.kind)} end
    if state.named~='any' then args[#args+1]={op='facet',field='named',values={state.named=='only'}} end
    local any={}; for _,field in ipairs({'lifetime','category','origin','castBy'}) do if state[field] and #state[field]>0 then any[#any+1]={op='facet',field=field,values=copy(state[field])} end end
    if #any>0 then args[#args+1]={op='or',args=any} end
    return {op='and',args=args}
end
local function readSimple(predicate)
    if not predicate or predicate.op~='and' then return end
    local state={kind={'buff','debuff','unknown'},named='any',lifetime={},category={},origin={},castBy={}}; local seen={}
    for _,node in ipairs(predicate.args) do
        if node.op=='facet' and node.field=='kind' and not seen.kind then state.kind=copy(node.values); seen.kind=true
        elseif node.op=='facet' and node.field=='named' and #node.values==1 and not seen.named then state.named=node.values[1] and 'only' or 'exclude'; seen.named=true
        elseif node.op=='or' and not seen.any then
            seen.any=true; for _,child in ipairs(node.args) do
                if child.op=='and' and #child.args==2 and child.args[1].op=='facet' and child.args[1].field=='named' and #child.args[1].values==1 and child.args[1].values[1]==false and child.args[2].op=='facet' and child.args[2].field=='lifetime' and not seen.lifetime then
                    state.support=true; state.lifetime=copy(child.args[2].values); seen.lifetime=true
                elseif child.op~='facet' or not state[child.field] or child.field=='kind' or child.field=='named' or seen[child.field] then return end
                if child.op=='facet' then state[child.field]=copy(child.values); seen[child.field]=true end
            end
        else return end
    end
    return state
end
function SetEditor:SetSimple(id,field,value)
    local set=self:GetSet(id); local state=set and readSimple(set.predicate); if not state then return false end
    state[field]=copy(value); set.predicate=simplePredicate(state); return self:Put(set)
end
function SetEditor:Preset(id,preset)
    local set=self:GetSet(id); if not set then return false end
    if preset=='long' then set.predicate=KanaEffects.Presets.SupportPredicate(); self.nodePath={}; return self:Put(set) end
    local states={all={named='any'},named={named='only'},combat={named='any',lifetime={'short','long','toggle','unknown'}}}
    local state=states[preset]; if not state then return false end
    state=copy(state); state.kind={'buff','debuff','unknown'}; set.predicate=simplePredicate(state); self.nodePath={}; return self:Put(set)
end
function SetEditor:Statistics(id,tag,other)
    local p=self.session:ReadDraft(); local compiled=p and KanaEffects.Rules.Compile(p.sets,p.longThreshold,p.widgets,p.hidden); local provider=self.editor.provider or self.store
    local stats={observed=0,matched=0,overlap=0,provesUniversalDisjointness=false}
    if not compiled or not provider then return stats end
    for _,o in ipairs(provider:ReadUnit(tag or self.source)) do stats.observed=stats.observed+1; if compiled:Matches(id,o) then stats.matched=stats.matched+1; if other and compiled:Matches(other,o) then stats.overlap=stats.overlap+1 end end end
    return stats
end
-- Diagnostics read a bounded sample only when the user opens or refreshes it.
-- History deliberately has no duration, caster, polarity or live identity facts.
function SetEditor:DiagnosticObservations(tag,evidence)
    local result={}; self.diagnosticTotal=0
    if evidence=='recent' then
        local history=self.picker.history; local records=history and history.Export and history:Export() or {}
        for index=#records,1,-1 do local record=records[index]
            if record.unitTag==tag then
                self.diagnosticTotal=self.diagnosticTotal+1
                if #result<100 then result[#result+1]={abilityId=record.abilityId,artificialEffectId=record.artificialEffectId,
                    key='historical:'..KanaEffects.Selectors.Key(KanaEffects.Selectors.FromObservation(record))..':'..tag,
                    unit={tag=tag,generation=0},catalog=copy(record.catalog),kind='unknown',lifetime='unknown',castBy='unknown',
                    historical=true,lastSeen=record.lastSeen,lastSeenClock=record.lastSeenClock,provenance=record.provenance} end
            end
        end
    else
        local provider=self.editor.provider or self.store
        local now=self.editor.clock and self.editor.clock:Now() or 0
        local rows=provider and provider:Snapshot(tag,now).observations or {}
        for _,o in ipairs(rows) do
            if o.lifetime~='finite' or not o.endTime or o.endTime>now then
                self.diagnosticTotal=self.diagnosticTotal+1; if #result<250 then result[#result+1]=o end
            end
        end
    end
    return result
end
local function contextMatch(context,o,p,compiled)
    if context.kind=='set' then return compiled:Matches(context.id,o) end
    local widget=I.Find(p.widgets,context.id)
    return widget and widget.unitTag==o.unit.tag and KanaEffects.Projector.Decide(o,widget,p,compiled) or false
end
function SetEditor:ContextStatistics(context,tag,other,evidence)
    local p=self.session:ReadDraft(); local compiled=p and KanaEffects.Rules.Compile(p.sets,p.longThreshold,p.widgets,p.hidden)
    local stats={observed=0,matched=0,overlap=0,provesUniversalDisjointness=false,metadataOnly=evidence=='recent',cooccurrenceKnown=evidence~='recent'}
    if not compiled then return stats end
    for _,o in ipairs(self:DiagnosticObservations(tag,evidence)) do
        stats.observed=stats.observed+1
        if contextMatch(context,o,p,compiled) then stats.matched=stats.matched+1; if other and contextMatch(other,o,p,compiled) then stats.overlap=stats.overlap+1 end end
    end
    stats.total=self.diagnosticTotal; return stats
end
function SetEditor:WidgetReport(id,observation)
    local p=self.session:ReadDraft(); local widget=p and I.Find(p.widgets,id); local compiled=p and KanaEffects.Rules.Compile(p.sets,p.longThreshold,p.widgets,p.hidden)
    if not widget or not compiled then return end
    local decision=KanaEffects.Projector.Decide(observation,widget,p,compiled,true)
    if observation.unit.tag~=widget.unitTag then decision.admitted=false; decision.code='wrong_source' end
    local result={decision=decision,entries={},historical=observation.historical==true}
    -- Historical rows never invent current contributors, pairs or deadlines.
    if not result.historical and decision.admitted then
        local provider=self.editor.provider or self.store; local now=self.editor.clock and self.editor.clock:Now() or 0
        if observation.lifetime=='finite' and observation.endTime and observation.endTime<=now then decision.admitted=false; decision.code='expired'; return result end
        for _,entry in ipairs(KanaEffects.Projector.BuildWidget(widget,p,compiled,provider,self.catalog,now)) do
            for _,o in ipairs(entry.contributors) do if o.key==observation.key then result.entries[#result.entries+1]=entry; break end end
        end
    end
    return result
end
function SetEditor:ExplainWidget(id,o)
    local report=self:WidgetReport(id,o); if not report then return self.labels.invalidConfig end
    local d,l=report.decision,self.labels; local lines={l.routingCodes[d.code] or l.unknown}
    local p=self.session:ReadDraft()
    for _,field in ipairs({'includeSets','excludeSets'}) do for _,ref in ipairs(d[field] or {}) do
        local name=(I.Find(p.sets,ref.id) or {}).name or ref.id
        lines[#lines+1]=(field=='includeSets' and l.included or l.excluded)..' «'..name..'»: '..(ref.matched and '✓' or '—')
        lines[#lines+1]=self:Explain(ref.id,o)
    end end
    if d.globalHidden~=nil then lines[#lines+1]=l.globalHide..': '..(d.globalHidden and l.yes or l.no)..(d.globalHideBypassed and ' · '..l.tableBypass or '') end
    if d.namedPolicy then lines[#lines+1]=l.named..': '..(l[d.namedPolicy] or d.namedPolicy)..' · '..(d.namedAccepted and '✓' or '—') end
    for _,entry in ipairs(report.entries) do
        local contributors={}; for _,component in ipairs(entry.contributors) do
            contributors[#contributors+1]=KanaEffects.Selectors.Key(KanaEffects.Selectors.FromObservation(component))..' '..((component.catalog or {}).level or l.values[component.kind] or l.unknown)
        end
        lines[#lines+1]=(entry.pair and l.survivingPair or l.contributors)..': '..table.concat(contributors,', ')
    end
    if report.historical then lines[#lines+1]=l.historyUnknown end
    return table.concat(lines,'\n')
end
function SetEditor:DiagnosticRows(form,context,tag)
    local l,p=self.labels,self.session:ReadDraft(); self.evidence=self.evidence or 'active'
    form:Choice(l.evidence,self.evidence,{{'active',l.activeEvidence},{'recent',l.recentEvidence}},function(v) self.evidence=v; self.observationIndex=1; self:RefreshDiagnostic(context) end)
    local comparison={{'',l.noComparison}}; local contexts={}
    for _,set in ipairs(p.sets) do local key='set:'..set.id; contexts[key]={kind='set',id=set.id}; comparison[#comparison+1]={key,l.set..' · '..set.name} end
    for _,widget in ipairs(p.widgets) do if widget.unitTag==tag then local key='widget:'..widget.id; contexts[key]={kind='widget',id=widget.id}; comparison[#comparison+1]={key,l.general..' · '..widget.name} end end
    self.comparison=contexts[self.comparison] and self.comparison or ''
    form:Choice(l.compareWith,self.comparison,comparison,function(key) self.comparison=key; self:RefreshDiagnostic(context) end)
    form:Button(l.refreshStats,function() self:RefreshDiagnostic(context) end)
    local stats=self:ContextStatistics(context,tag,contexts[self.comparison],self.evidence)
    form:Text(string.format(l.stats,stats.matched,stats.observed)..' · '..string.format(l.sampleTotal,stats.total),42)
    if self.comparison~='' then form:Text(string.format(self.evidence=='recent' and l.metadataOverlap or l.overlap,stats.overlap),38) end
    form:Text(self.evidence=='recent' and l.historyUnknown or l.statsHint,self.evidence=='recent' and 100 or 55)
    local rows=self:DiagnosticObservations(tag,self.evidence); local choices={}
    for index,o in ipairs(rows) do choices[#choices+1]={index,((o.catalog or {}).name or l.unknown)..' · '..KanaEffects.Selectors.Key(KanaEffects.Selectors.FromObservation(o))} end
    if #choices>0 then
        self.observationIndex=math.min(self.observationIndex or 1,#rows)
        form:Choice(l.observation,self.observationIndex,choices,function(index) self.observationIndex=index; self:RefreshDiagnostic(context) end)
        local o=rows[self.observationIndex]
        if o.historical then form:Text(l.lastObservation..': '..tostring(o.lastSeen)..' · '..tostring(o.lastSeenClock)..'\n'..tostring(o.provenance),65) end
        local text=context.kind=='widget' and self:ExplainWidget(context.id,o) or self:Explain(context.id,o)
        -- Form content scrolls; do not clip a complete structured explanation.
        local _,lines=string.gsub(text,'\n','\n'); form:Text(text,math.max(80,(lines+1)*24))
    else form:Text(l.noObservations,45) end
end
function SetEditor:RefreshDiagnostic(context)
    if context.kind=='widget' then self.editor.inspector:Refresh() else self:Refresh() end
end
function SetEditor:Explain(id,observation)
    local p=self.session:ReadDraft(); local compiled=p and KanaEffects.Rules.Compile(p.sets,p.longThreshold,p.widgets,p.hidden); if not compiled then return self.labels.invalidConfig end
    local lines={}; local l=self.labels
    local function value(field,v)
        if field=='named' then return v==true and l.namedYes or v==false and l.namedNo or l.unknown end
        if field=='category' then
            if v==nil then return l.noMatchingCategory end
            return ((KanaEffects.Localization.ru or {}).categories or {})[v] or tostring(v)
        end
        return l.values[v] or tostring(v or l.unknown)
    end
    local function render(r,depth)
        local text=r.code=='expression' and r.label or l.reasonCodes[r.code] or l.condition
        if r.setId then text=text..' «'..(r.setName or (I.Find(p.sets,r.setId) or {}).name or r.setId)..'»' end
        if r.field then
            local wanted={}; for _,v in ipairs(r.values or {}) do wanted[#wanted+1]=value(r.field,v) end
            text=(l.facetNames[r.field] or r.field)..': '..value(r.field,r.actual)..'; '..l.expected..' '..table.concat(wanted,', ')
            if r.field=='lifetime' then text=text..'; '..l.fullDuration..' '..tostring(r.fullDuration or l.unknown)..'; '..l.threshold..' '..tostring(r.threshold) end
        elseif r.selector then local meta=self.catalog:Resolve(r.selector); text=text..': '..meta.name end
        lines[#lines+1]=string.rep('  ',depth)..(r.matched and '✓ ' or '— ')..text
        for _,child in ipairs(r.children) do render(child,depth+1) end
    end
    render(compiled:Explain(id,observation),0); return table.concat(lines,'\n')
end
function SetEditor:Open()
    if not self.session:ReadDraft() then return false end; self.open=true
    local p=self.session:ReadDraft(); if not I.Find(p.sets,self.selected) then self.selected=p.sets[1] and p.sets[1].id end
    if not self.form then self.form=I.Form.New(self.api,self.name,self.labels.sets,600,820,function() self.editor:RequestClose() end); if self.form then self.form.onClose=function() self:Close() end end end
    if self.form then self.form:Show(); self.form:Place(90,130) end; self:Refresh(); return true
end
-- Reused by the panel Effects page. Kept beside set authoring so every loader
-- receives the same documentation without another optional module dependency.
local RuleHelp={}; RuleHelp.__index=RuleHelp; KanaEffects.RuleHelp=RuleHelp
local HELP_SECTIONS={
    {title='Как устроено правило',entries={
        {'Выражение → boolean','Эффект показывается, когда выражение возвращает true. Пишите условие без return. Код не выполняет произвольный Lua.', 'is_buff() and total_duration() > 300'},
        {'and · or · not · ( )','Объединение, выбор и отрицание условий. Скобки задают порядок.', 'is_buff() and (is_named() or is_permanent())'},
        {'== · ~= · < · <= · > · >=','Сравнение значений одного типа. Доступны true, false, числа и строки в кавычках.', 'cast_by() == "self"'},
    }},
    {title='Повторное использование наборов',entries={
        {'element_of(name: string) → boolean','Проверяет правило именованного набора. Имя чувствительно к регистру. Неизвестные и неоднозначные имена, а также циклы запрещены.', 'element_of("Long buffs") and not is_debuff()'},
        {'element_of(name: string, stableId: string) → boolean','Расширенная форма для старых наборов с одинаковыми именами. Стабильный ID однозначно выбирает набор; имя должно совпадать с именем этого ID. При обычном редактировании достаточно уникального имени.'},
    }},
    {title='Другие панели',entries={
        {'on_panel(name: string) → boolean','Возвращает true, если эффект попадает в панель с этим уникальным именем для того же получателя по её правилу или явно назначенной ячейке. Для исключения используйте not on_panel("Имя панели"). Для автоматических панелей учитывает глобальное скрытие; явно назначенные ячейки обходят его. Не зависит от порядка панелей, наличия свободного места и геометрии. Имя чувствительно к регистру.', 'on_panel("Long buffs") and is_buff()'},
        {'Имена и предупреждения','Отсутствующая или неоднозначная панель даёт false с предупреждением. Циклы также дают false. Переименование используемой панели требует подтверждения и обновляет ссылки в правилах и несохранённом коде.'},
    }},
    {title='Тип и длительность',entries={
        {'is_buff() · is_debuff() · is_named() → boolean','Положительный, отрицательный или именованный эффект.', 'is_buff() and not is_named()'},
        {'is_permanent() · is_toggle() · is_unknown_duration() → boolean','Бессрочный, переключаемый эффект или эффект с неизвестной длительностью.', 'is_permanent() or is_toggle()'},
        {'total_duration() → number','Полная длительность в секундах, не оставшееся время. Бессрочные и переключаемые эффекты дают +∞. При неизвестной длительности любое сравнение даёт false.', 'total_duration() > 300 and not is_permanent()'},
    }},
    {title='Категории',entries={
        {'from_category(category, ...) → boolean','Принадлежность хотя бы одной категории. category(id: string, ...) — равнозначная форма со строковыми идентификаторами.', 'from_category(Category.Food, Category.exp)'},
        {'Category.Food · Category.Drink','Еда, включая напитки; только напитки.'},
        {'Category.exp · Category.system','Опыт; служебные эффекты.'},
        {'Category.Event · Category.Membership · Category.Cooldown','События; подписка; перезарядки.'},
        {'Category.Justice · Category.SkillExperience','Правосудие; опыт навыков.'},
    }},
    {title='Точные эффекты',entries={
        {'ability(id: number) · artificial(id: number) → boolean','Выбор по идентификатору обычного или искусственного эффекта.', 'ability(12345) or artificial(678)'},
        {'family(id: string, level: string) → boolean','Семейство именованных эффектов. level: "minor", "major" или "pair".', 'family("courage", "major")'},
    }},
    {title='Свойства и строковые значения',entries={
        {'kind() → string','"buff", "debuff", "unknown".'},
        {'lifetime() → string','"short", "long", "permanent", "toggle", "unknown". short/long используют сохранённый порог профиля; для явного порога пишите total_duration().'},
        {'origin() → string','"skill", "set", "enchant", "unknown".', 'origin() == "set"'},
        {'cast_by() → string','"self", "other", "unknown".', 'cast_by() == "self"'},
    }},
}
function RuleHelp.New(api,onEscape) serial=serial+1; return setmetatable({api=api,onEscape=onEscape,name='KanaEffectsRuleHelp'..serial,section=1},RuleHelp) end
function RuleHelp:IsOpen() return self.open==true end
function RuleHelp:Refresh()
    local f=self.form; if not f then return end
    f:Begin(); local sections={}
    for index,section in ipairs(HELP_SECTIONS) do sections[#sections+1]={index,section.title} end
    f:Choice('Раздел',self.section,sections,function(index) self.section=index; self:Refresh() end)
    local section=HELP_SECTIONS[self.section]; f:Group(section.title)
    for _,entry in ipairs(section.entries) do f:DocumentEntry(entry[1],entry[2],entry[3]) end
    f:End()
end
function RuleHelp:Open()
    if not self.form then
        self.form=I.Form.New(self.api,self.name,'Документация правил',700,820,function() self:Close() end)
        if not self.form then return false end
        self.form.onClose=function() self:Close() end
    end
    self.open=true; self.form:Show(); self:Refresh(); return true
end
function RuleHelp:Close() self.open=false; if self.form then self.form:Hide() end end
function RuleHelp:Dispose() self:Close(); if self.form then self.form:Dispose() end end
function SetEditor:OpenHelp()
    self:CaptureFields()
    if not self.help then self.help=RuleHelp.New(self.api,function() self.editor:RequestClose() end) end
    return self.help:Open()
end
function SetEditor:Refresh()
    if not self.open or not self.form then return end
    local f,l,p=self.form,self.labels,self.session:ReadDraft(); if not p then self:Close(); return end
    self:RebaseReferences(p)
    if not I.Find(p.sets,self.selected) then self.selected=p.sets[1] and p.sets[1].id; self.nodePath={} end
    f:Begin()
    local options={}; for _,set in ipairs(p.sets) do options[#options+1]={set.id,set.name} end
    local newOption={}; options[#options+1]={newOption,'Добавить новый...'}
    f:Choice(l.set,self.selected,options,function(id)
        self:CaptureFields()
        if id==newOption then self:Create() else self.selected=id; self.nodePath={}; self:Refresh() end
    end)
    local set=self:GetSet(); if not set then f:Text(l.noSets); f:End(); return end
    local generation=f.generation
    self.nameInput=f:Edit(l.setName or 'Название набора',self.nameBuffers[set.id] or set.name,function(name) self.nameBuffers[set.id]=name; return true end)
    self.nameInput:SetHandler('OnTextChanged',function(edit)
        if self.open and f.open and not f.suppressFocus and generation==f.generation then self.nameBuffers[set.id]=edit:GetText() end
    end)
    local original=expression(set,p.sets); local source=self.expressionBuffers[set.id] or original
    f:Code(l.expression or 'Правило',source,function(value) self.expressionBuffers[set.id]=value; return true end,{
        savedValue=original,onChange=function(value) self.expressionBuffers[set.id]=value end,
        validate=function(value) return self:ValidateExpression(value,set.id) end})
    f:Button('Документация',function() self:OpenHelp() end)
    f:Actions({{'Проверить',function() self:Check() end},{'Удалить',function() self:Delete(set.id) end,'destructive'},
        {'Сохранить',function() self:SaveSelected() end,'primary'}})
    f:End()
    if (not set.predicate or set.predicate.op~='expression') and not KanaEffects.Rules.ParseExpression(original) then
        f:Notice('Старое правило сохраняется без изменений. Для редактирования упростите код: не более 16384 байт, 1024 токенов и 48 уровней вложенности.')
    end
    self:ValidateExpression(source,set.id)
end
function SetEditor:ResetDraft()
    self.expressionBuffers={}; self.nameBuffers={}; self.setNames=nil; self.panelNames=nil; self.panelRenameWarnings=nil
    if self.help then self.help:Close() end
end
function SetEditor:Close() self:CaptureFields(); self.open=false; if self.form then self.form:Hide() end end
function SetEditor:Dispose() self:Close(); self:ResetDraft(); if self.form then self.form:Dispose() end; if self.help then self.help:Dispose() end end
