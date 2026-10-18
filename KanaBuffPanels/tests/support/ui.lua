return function(h)
    for _,name in ipairs({'Panel','Hidden','Name','Create','Rename','Delete','Search','Show'}) do _G['KanaBuffPanels'..name]=nil end
    h.messages={};d=function(message) h.messages[#h.messages+1]=message end
    ZO_CreateStringId=function(key,value) _G[key]=key;h.strings=h.strings or {};h.strings[key]=value end
    h.menu={}
    ClearMenu=function() h.menu={} end
    AddCustomMenuItem=function(label,callback) h.menu[#h.menu+1]={label=label,callback=callback} end
    AddCustomSubMenuItem=function(label,entries) h.menu[#h.menu+1]={label=label,entries=entries} end
    ShowMenu=function(control) h.menuControl=control end
    CALLBACK_MANAGER={callbacks={}}
    function CALLBACK_MANAGER:RegisterCallback(event,fn)
        self.callbacks[event]=self.callbacks[event] or {};table.insert(self.callbacks[event],fn)
    end
    function CALLBACK_MANAGER:FireCallbacks(event,...)
        if event=='LAM-RefreshPanel' then h.settingsRefreshes=(h.settingsRefreshes or 0)+1 end
        for _,fn in ipairs(self.callbacks[event] or {}) do fn(...) end
    end
    LibAddonMenu2={}
    function LibAddonMenu2:RegisterAddonPanel(name,data) h.panelData=data;h.settingsPanel={name=name};return h.settingsPanel end
    function LibAddonMenu2:RegisterOptionControls(name,options) h.options=options end
    function h.materialize()
        for _,option in ipairs(h.options) do
            if option.reference then
                local c={data=option}
                function c:UpdateChoices(names,values) eq(#names,#values);self.names=names;self.values=values end
                _G[option.reference]=c
            end
        end
        CALLBACK_MANAGER:FireCallbacks('LAM-PanelControlsCreated',h.settingsPanel)
    end
    function h.option(reference)
        for _,o in ipairs(h.options) do if o.reference=='KanaBuffPanels'..reference then return o end end
        error('missing option '..reference)
    end
end
