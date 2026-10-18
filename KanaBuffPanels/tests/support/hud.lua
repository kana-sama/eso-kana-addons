-- Saved options, registration and callbacks model the public HUD boundary only.
return function(h, saved)
    saved=saved or {keyboard={},gamepad={}};h.hudSaved=saved
    ZO_HUD_EDITOR_OPTION_TYPES={ENUM=3};local manager={keyboard={},gamepad={},callbacks={},rebuilds=0}
    local function register(mode,control,name,config,options)
        local e={control=control,displayName=name,config=config,options=options,mode=mode}
        manager[mode][control:GetName()]=e
        function e:IsValid() return self.config.isValid() end
        function e:GetCustomOptions() return self.options end
        function e:GetCustomOptionValue(key)
            local record=saved[mode][control:GetName()] or {}
            if record[key]~=nil then return record[key] end
            for _,o in ipairs(options) do if o.key==key then return o.defaultValue end end
        end
        function e:SetCustomOptionValue(key,_,value)
            local old=self:GetCustomOptionValue(key)
            local record=saved[mode][control:GetName()] or {};saved[mode][control:GetName()]=record;record[key]=value
            for _,o in ipairs(options) do if o.key==key and value~=old then o.callback(self,nil,old,value) end end
        end
        function e:RevertOffsetModifications()
            local record=saved[mode][control:GetName()] or {}
            if record.x then control:ClearAnchors();control:SetAnchor(CENTER,GuiRoot,CENTER,record.x,record.y) end
        end
        return e
    end
    function manager:RegisterKeyboardElement(...) return register('keyboard',...) end
    function manager:RegisterGamepadElement(...) return register('gamepad',...) end
    function manager:RegisterCallback(event,fn) self.callbacks[event]=self.callbacks[event] or {};table.insert(self.callbacks[event],fn) end
    function manager:FireCallbacks(event) for _,fn in ipairs(self.callbacks[event] or {}) do fn() end end
    function manager:RebuildAllElements() self.rebuilds=self.rebuilds+1 end
    HUD_MANAGER=manager;return manager
end
