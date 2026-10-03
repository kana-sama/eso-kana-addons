-- Run with: lua tests/regression.lua <addon.lua> <AetherChat directory> <esoui directory>
local addon, upstream, esoui = assert(arg[1]), assert(arg[2]), assert(arg[3])
unpack = table.unpack
local function read(path)
    local f = assert(io.open(path)); local s = f:read('*a'); f:close(); return s
end
local function nativeMethod(source, name, environment)
    local code = assert(source:match('(function ' .. name .. '%b()%s.-)\nend')) .. '\nend'
    assert(load(code, name, 't', environment))()
end
local failures = 0
local function test(name, run)
    local ok, err = pcall(function()
        local now, later, updates, events = 0, {}, {}, {}
        SLASH_COMMANDS = {}
        DT_HIGH = 2
        DL_BACKGROUND = 0
        DL_TEXT = 2
        SCENE_FRAGMENT_SHOWING = "showing"
        SCENE_FRAGMENT_SHOWN = "shown"
        EVENT_ADD_ON_LOADED = 1
        EVENT_MANAGER = {
            RegisterForEvent = function(_, n, _, f) events[n] = f end,
            UnregisterForEvent = function(_, n) events[n] = nil end,
            RegisterForUpdate = function(_, n, _, f) updates[n] = f end,
            UnregisterForUpdate = function(_, n) updates[n] = nil end,
        }
        GetGameTimeMilliseconds = function() return now end
        zo_callLater = function(f, delay) later[#later+1] = {f, now+delay} end
        local function tick(ms)
            for _ = 1, math.ceil(ms/16) do
                now = now + 16
                local snapshot = {}; for n,f in pairs(updates) do snapshot[n]=f end
                for n,f in pairs(snapshot) do if updates[n] == f then f() end end
                local pending = later; later = {}
                for _,entry in ipairs(pending) do
                    if entry[2] <= now then entry[1]() else later[#later+1]=entry end
                end
            end
        end
        local function control()
            return {hidden=false, alpha=1, handlers={},
                IsHidden=function(s) return s.hidden end,
                SetHidden=function(s,v) s.hidden=v end,
                GetAlpha=function(s) return s.alpha end,
                SetAlpha=function(s,v) s.alpha=v end,
                GetName=function() return "TestControl" end,
                GetDimensions=function() return 300,30 end,
                GetDrawTier=function(s) return s.tier or 0 end,
                SetDrawTier=function(s,v) s.tier=v end,
                GetDrawLayer=function(s) return s.layer or 1 end,
                SetDrawLayer=function(s,v) s.layer=v end,
                GetDrawLevel=function() return 1 end,
                GetParent=function() end,
                GetNamedChild=function() end,
                GetHandler=function(s,n) return s.handlers[n] end,
                SetHandler=function(s,n,f,namespace)
                    s.handlers[n..(namespace and ':'..namespace or '')]=f
                end,
                Fire=function(s,n)
                    if s.handlers[n] then s.handlers[n](s) end
                    for name,f in pairs(s.handlers) do
                        if name:sub(1,#n+1)==n..':' then f(s) end
                    end
                end}
        end
        local edit = control()
        edit.HasFocus = function(s) return s.focus end
        edit.TakeFocus = function(s)
            if not s.focus then s.focus=true; if s.handlers.OnFocusGained then s.handlers.OnFocusGained(s) end end
        end
        edit.LoseFocus = function(s) s.focus=false end
        edit.SetText=function(s,text) s.text=text; s:Fire('OnTextChanged') end
        edit.Clear = function(s) s:SetText('') end
        edit.GetText = function(s) return s.text or '' end
        ZO_ChatWindowTextEntryEditBox = edit
        ZO_ChatWindowTextEntry = control()
        local backdrop, label = control(), control()
        ZO_ChatWindowTextEntry.GetNamedChild=function(_,name)
            if name=='Edit' then return backdrop elseif name=='Label' then return label end
        end
        SCENE_MANAGER = {
            mode=false, scene='hud',
            GetCurrentSceneName=function(s) return s.scene end,
            IsShowing=function(s,n) return s.scene==n end,
            IsInUIMode=function(s) return s.mode end,
            IsLockedInUIMode=function() return false end,
            SetInUIMode=function(s,v) s.mode=v; s.scene=v and 'hudui' or 'hud'; return true end,
            OnChatInputStart=function() end, OnChatInputEnd=function() end,
            OnToggleGameMenuBinding=function(s) s.menu=true end,
        }
        ZO_Dialogs_IsShowingDialog = function() return false end
        local entry = {editControl=edit, open=false, alpha=.25}
        entry.FadeIn=function(s) s.alpha=1 end
        entry.FadeOut=function(s) s.alpha=.25 end
        entry.GetControl=function() return ZO_ChatWindowTextEntry end
        entry.IsOpen=function(s) return s.open end
        entry.GetText=function() return edit:GetText() end
        entry.AddCommandHistory=function() end
        local source=read(esoui..'/ingame/chatsystem/sharedchatsystem.lua'):gsub('\r','')
        local env=setmetatable({TextEntry=entry}, {__index=_G})
        nativeMethod(source, 'TextEntry:Open', env)
        nativeMethod(source, 'TextEntry:Close', env)
        CHAT_SYSTEM={textEntry=entry, currentChannel=1, commandPrefixes={}}
        CHAT_SYSTEM.CloseTextEntry=function(_,keep) entry:Close(keep) end
        CHAT_SYSTEM.StartTextEntry=function(_,text) entry:Open(text) end
        CHAT_SYSTEM.TextToSwitchData=function() return nil end
        CHAT_SYSTEM.ValidateChatChannel=function() return true end
        CHAT_SYSTEM.commandPrefixes[string.byte('/')]=function(text) CHAT_SYSTEM.executed=text end
        IsChatSystemAvailableForCurrentPlatform=function() return true end
        SendChatMessage=function(text) CHAT_SYSTEM.sent=text end
        ZO_Menu_SetLastCommandWasFromMenu=function() end
        nativeMethod(source, 'SharedChatSystem:SubmitTextEntry', setmetatable({SharedChatSystem=CHAT_SYSTEM},{__index=_G}))
        AetherChat={Settings={Get=function(_,default) return default end}}
        dofile(esoui..'/libraries/utility/zo_hook.lua')
        dofile(upstream..'/src/UI/Messenger.lua')
        local m=AetherChat.Messenger
        m.window=control(); m.window.hidden=true
        m.ScanAndDockExternalChatButtons=function() end
        m.DockNativeChatEntry=function() end
        m.OnFragmentShowing=function() end
        m.OnFragmentHidden=function() CHAT_SYSTEM:CloseTextEntry(true); edit:LoseFocus() end
        m.UndockNativeChatEntry=function() end
        -- Real HUD fragment Show skips OnShown when AetherChat already unhid it.
        local fragment={control=m.window, state="hidden", showDuration=200}
        fragment.GetState=function(s) return s.state end
        fragment.OnShown=function(s) s.state=SCENE_FRAGMENT_SHOWN end
        fragment.animation={IsPlaying=function() return false end,
            GetFirstAnimation=function() return {} end}
        fragment.GetAnimation=function(s) return s.animation end
        m.window.IsControlHidden=m.window.IsHidden
        local fragmentSource=read(esoui..'/libraries/zo_scene/zo_scenefragmenttemplates.lua'):gsub('\r','')
        nativeMethod(fragmentSource,'ZO_HUDFadeSceneFragment:Show',setmetatable({ZO_HUDFadeSceneFragment=fragment},{__index=_G}))
        fragment.Refresh=function(s)
            if m.isOpen then s.state=SCENE_FRAGMENT_SHOWING; s:Show()
            else s.state='hidden' end
        end
        m.fragment=fragment
        m.SetupHideHooks()
        edit:SetHandler('OnEscape',function() CHAT_SYSTEM:CloseTextEntry() end)
        local nativeSubmit=CHAT_SYSTEM.SubmitTextEntry
        edit:SetHandler('OnEnter',function() CHAT_SYSTEM:SubmitTextEntry() end)
        local nativeEnter=edit:GetHandler('OnEnter')
        dofile(addon)
        events.KanaAetherChat(nil,'KanaAetherChat')
        assert(CHAT_SYSTEM.SubmitTextEntry==nativeSubmit, 'protected submission path was replaced')
        assert(edit:GetHandler('OnEnter')==nativeEnter, 'native Enter handler was replaced')
        run(m, edit, entry, tick)
    end)
    print((ok and 'PASS ' or 'FAIL ')..name..(ok and '' or ': '..tostring(err)))
    if not ok then failures=failures+1 end
end

test('toggle closes instead of refocusing during fade-out', function(m,e,entry,tick)
    m.Toggle(); tick(400); m.Toggle(); tick(400)
    assert(not m.isOpen and m.window:IsHidden(), 'toggle reopened chat')
end)
test('close button survives late interaction and pending focus', function(m,e,entry,tick)
    m.Toggle(); m.Hide(true); m.RecordInteraction(); tick(400)
    assert(not m.isOpen and m.window:IsHidden(), 'close was cancelled')
end)
test('hotkey focuses after delayed visibility', function(m,e,entry,tick)
    local show=m.Show
    m.Show=function(...) show(...); m.window:SetHidden(true); zo_callLater(function() m.window:SetHidden(false) end,80) end
    m.Toggle(); tick(400)
    assert(e:HasFocus() and entry.alpha==1 and m.window:GetAlpha()==1, 'input remained inactive')
end)
test('slash command runs then closes chat', function(m,e,entry,tick)
    m.Toggle(); tick(400); e:SetText('/test'); e:Fire('OnEnter'); tick(400)
    assert(CHAT_SYSTEM.executed=='/test', 'command not executed')
    assert(not m.isOpen and m.window:IsHidden(), 'command left chat open')
end)
test('ordinary message keeps existing chat behavior', function(m,e,entry,tick)
    m.Toggle(); tick(400); e:SetText('hello'); e:Fire('OnEnter'); tick(400)
    assert(CHAT_SYSTEM.sent=='hello' and m.isOpen, 'normal message behavior changed')
end)
test('Escape preserves draft and releases owned cursor', function(m,e,entry,tick)
    m.Toggle(); tick(400); e.text='draft'; e.handlers.OnEscape(e); tick(400)
    assert(not m.isOpen and e.text=='draft' and not SCENE_MANAGER.mode)
end)
test('manual close also closes loot channel', function(m,e,entry,tick)
    for i=1,20 do
        local name=debug.getupvalue(m.StartFadeOut,i)
        if name=='activeChannelKey' then debug.setupvalue(m.StartFadeOut,i,'loot'); break end
    end
    m.Toggle(); tick(400); m.Hide(true); tick(400)
    assert(not m.isOpen and m.window:IsHidden(), 'loot window stayed open')
end)
test('rapid close and reopen focuses only the new opening', function(m,e,entry,tick)
    m.Toggle(); tick(32); m.Toggle(); m.Toggle(); tick(400)
    assert(m.isOpen and e:HasFocus() and entry.alpha==1)
    m.Toggle(); tick(400); assert(not m.isOpen and not e:HasFocus())
end)
test('preexisting cursor stays enabled after close', function(m,e,entry,tick)
    SCENE_MANAGER:SetInUIMode(true)
    m.Toggle(); tick(400); m.Hide(true); tick(400)
    assert(SCENE_MANAGER.mode and not m.isOpen)
end)
test('command outside AetherChat does not close an unrelated window', function(m,e,entry,tick)
    e:SetText('/test'); e:Fire('OnEnter'); tick(400)
    assert(CHAT_SYSTEM.executed=='/test' and m.window:IsHidden())
end)
test('docked input is above the window and native tier returns on undock', function(m,e,entry,tick)
    m.Toggle(); tick(400)
    assert(ZO_ChatWindowTextEntry:GetDrawTier()==DT_HIGH, 'input remains on backdrop tier')
    assert(e:GetDrawTier()==DT_HIGH and e:GetDrawLayer()==DL_TEXT, 'text is below elevated background')
    local bg=ZO_ChatWindowTextEntry:GetNamedChild('Edit')
    assert(bg:GetDrawTier()==DT_HIGH and bg:GetDrawLayer()==DL_BACKGROUND)

    m.UndockNativeChatEntry()
    assert(ZO_ChatWindowTextEntry:GetDrawTier()==0, 'native chat tier changed')
    assert(e:GetDrawTier()==0 and e:GetDrawLayer()==1, 'native edit drawing changed')
end)
test('already visible HUD fragment finishes showing', function(m,e,entry,tick)
    m.FocusChatInput(); tick(400)
    assert(m.fragment:GetState()==SCENE_FRAGMENT_SHOWN, 'fragment stuck showing')
    assert(e:HasFocus() and entry.alpha==1, 'input activation was blocked')
end)
test('autocomplete Enter does not close an open input', function(m,e,entry,tick)
    m.Toggle(); tick(400); e:SetText('/tes')
    e:SetHandler('OnEnter',function() e:SetText('/test') end)
    e:Fire('OnEnter'); tick(32)
    assert(m.isOpen and entry:IsOpen(), 'autocomplete closed chat')
end)
test('erasing a command does not leave a stale pending command', function(m,e,entry,tick)
    m.Toggle(); tick(400); e:SetText('/test'); e:SetText(''); tick(32)
    e:Fire('OnEnter'); tick(32)
    assert(m.isOpen, 'empty input treated as slash command')
end)
os.exit(failures==0 and 0 or 1)
