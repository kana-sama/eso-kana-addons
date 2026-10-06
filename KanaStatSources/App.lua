local K=KanaStatSources
local A={};K.App=A
local Instance={};Instance.__index=Instance
function A.New(api,saved)return setmetatable({api=api,saved=saved,collector=K.Snapshot.New(api)},Instance)end
function Instance:Explain(snapshot)
    local contributions,diagnostics={},{}
    for _,category in ipairs({'Base','Equipment','Skills','Champion','Effects'})do
        local ok,c,d=pcall(K.Sources[category].Build,snapshot)
        if ok then for _,r in ipairs(c or {})do contributions[#contributions+1]=r end;for _,r in ipairs(d or {})do diagnostics[#diagnostics+1]=r end
        else diagnostics[#diagnostics+1]={category=category:lower(),reason=tostring(c)}end
    end
    -- An active effect can be the manifestation of a learned passive. Prefer
    -- that current effect for the same ability/stat, preserving independent IDs.
    local effectStats={}
    for _,c in ipairs(contributions)do
        local source=c.source
        if source and source.kind=='effect' then effectStats[source.id]=effectStats[source.id] or {};effectStats[source.id][c.stat]=true end
    end
    local unique={}
    for _,c in ipairs(contributions)do
        local source=c.source
        if source and source.kind=='skill' and effectStats[source.id] and effectStats[source.id][c.stat] then diagnostics[#diagnostics+1]=K.Core.Diagnostic(c,'represented by the active effect of this ability')
        else unique[#unique+1]=c end
    end
    return K.Model.Build(snapshot,unique,diagnostics,K.Rules.Policies),unique,diagnostics
end
function Instance:GetBreakdown(key)
    local snapshot=self.collector:Capture(false)
    local breakdowns=self:Explain(snapshot)
    self.lastSnapshot=snapshot;self.lastBreakdowns=breakdowns
    return breakdowns[key],snapshot.meta.language
end
function Instance:Invalidate(category)
    self.collector:Invalidate(category)
    if self.bridge and self.bridge.active and not self.refreshQueued then
        self.refreshQueued=true;local name=K.name..':refresh';local events=self.api.EVENT_MANAGER
        events:RegisterForUpdate(name,100,function()
            events:UnregisterForUpdate(name);self.refreshQueued=false
            if self.bridge.active then self.bridge:Refresh()end
        end)
    end
end
function Instance:Dump()
    local api=self.api;local saved,reason=K.Dump.Storage(api)
    if not saved then if api.d then api.d(K.name..': '..reason)end;return nil,reason end
    self.saved=saved;self.collector:Invalidate('all')
    local snapshot=self.collector:Capture(true);local breakdowns,c,d=self:Explain(snapshot)
    for _,v in ipairs((self.bridge or {}).diagnostics or {})do d[#d+1]=v end
    local report=K.Dump.Build(snapshot,breakdowns,c,d)
    local id=K.Dump.Append(saved,report)
    if api.d then api.d(K.name..': '..K.Stats.Text(snapshot.meta.language,'dump')..' #'..id..' · live/SavedVariables/KanaStatSources.lua · '..K.Stats.Text(snapshot.meta.language,'disk'))end
    return id
end
function Instance:Start()
    if self.started then return end;self.started=true
    local api=self.api;local events=api.EVENT_MANAGER
    api.SLASH_COMMANDS['/kanastats']=function(argument)
        if (argument or ''):match('^[ \t]*dump[ \t]*$')then self:Dump()
        elseif api.d then api.d('/kanastats dump — '..(api.GetCVar('language.2')=='ru' and 'сохранить данные персонажа и источники характеристик' or 'save character data and stat sources'))end
    end
    self.bridge=K.Tooltip.Install(api,function(key)return self:GetBreakdown(key)end)
    local function register(name,category,callback,playerFilter)
        if api[name] then
            local registration=K.name..':'..name
            events:RegisterForEvent(registration,api[name],callback or function()self:Invalidate(category)end)
            if playerFilter and events.AddFilterForEvent and api.REGISTER_FILTER_UNIT_TAG then events:AddFilterForEvent(registration,api[name],api.REGISTER_FILTER_UNIT_TAG,'player')end
        end
    end
    register('EVENT_STATS_UPDATED','stats',function(_,tag)if tag=='player'then self:Invalidate('stats')end end,true)
    register('EVENT_EFFECT_CHANGED','effects',function(_,_,_,_,tag)if tag=='player'then self:Invalidate('effects')end end,true)
    register('EVENT_LEVEL_UPDATE','all',function(_,tag)if tag=='player'then self:Invalidate('all')end end,true)
    for _,name in ipairs({'EVENT_INVENTORY_SINGLE_SLOT_UPDATE','EVENT_INVENTORY_FULL_UPDATE','EVENT_ACTIVE_WEAPON_PAIR_CHANGED'})do register(name,'equipment')end
    for _,name in ipairs({'EVENT_ATTRIBUTE_UPGRADE_UPDATED','EVENT_CHAMPION_PURCHASE_RESULT','EVENT_CHAMPION_POINT_GAINED','EVENT_SKILLS_FULL_UPDATE','EVENT_SKILL_POINTS_CHANGED','EVENT_SKILL_RANK_UPDATE','EVENT_ABILITY_PROGRESSION_RANK_UPDATE','EVENT_SKILL_LINE_ADDED','EVENT_HOTBAR_SLOT_UPDATED','EVENT_ACTION_SLOTS_ALL_HOTBARS_UPDATED'})do register(name,'build')end
    register('EVENT_PLAYER_ACTIVATED','all')
    register('EVENT_PLAYER_DEACTIVATED',nil,function()self.bridge:Clear();self.collector:Invalidate('all')end)
end
function A.Load(api)
    api.EVENT_MANAGER:RegisterForEvent(K.name,api.EVENT_ADD_ON_LOADED,function(_,name)
        if name~=K.name then return end
        api.EVENT_MANAGER:UnregisterForEvent(K.name,api.EVENT_ADD_ON_LOADED)
        K.instance=A.New(api,K.Dump.Storage(api));K.instance:Start()
    end)
end
if EVENT_MANAGER and EVENT_ADD_ON_LOADED then A.Load(_G)end
