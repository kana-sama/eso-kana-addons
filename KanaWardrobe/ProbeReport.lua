KanaWardrobe=KanaWardrobe or {}
local KW=KanaWardrobe
local R={};KW.ProbeReport=R
local id="KANA_WARDROBE_PROBE_REPORT"
local registered=false
-- Native multiline edits should never receive an entire build journal at once.
-- The limit is in bytes, so it also bounds glyph count for every language.
local PAGE_BYTES,PAGE_LINES=4096,48
function R.Pages(text)
    text=tostring(text or "");local pages={};local start=1
    while start<=#text do
        local last=math.min(#text,start+PAGE_BYTES-1)
        while last<#text and last>=start do
            local nextByte=text:byte(last+1)
            if nextByte<128 or nextByte>=192 then break end
            last=last-1
        end
        local cursor,lines,lastNewline=start,0,nil
        while cursor<=last do
            local newline=text:find("\n",cursor,true)
            if not newline or newline>last then break end
            lines=lines+1;lastNewline=newline;cursor=newline+1
            if lines==PAGE_LINES then last=newline;break end
        end
        if last<#text and lastNewline then last=lastNewline end
        pages[#pages+1]=text:sub(start,last);start=last+1
    end
    if #pages==0 then pages[1]=""end
    return pages
end
local function safe(data,callback)
    local ok,err=xpcall(callback,function(problem)
        return debug and debug.traceback and debug.traceback(tostring(problem),2) or tostring(problem)
    end)
    -- The diagnostic sink is independent of native UI, and must not leak a second error.
    if not ok and data and type(data.onError)=="function"then pcall(data.onError,err)end
end
local function releaseFocus(dialog)
    safe(dialog.data,function()dialog:GetNamedChild("Edit"):LoseFocus()end)
end
local function showPage(dialog,data,index,focus)
    data.page=math.max(1,math.min(index,#data.pages))
    local edit=dialog:GetNamedChild("Edit")
    edit:SetText(data.pages[data.page])
    dialog:GetNamedChild("Previous"):SetEnabled(data.page>1)
    dialog:GetNamedChild("Next"):SetEnabled(data.page<#data.pages)
    dialog:GetNamedChild("Page"):SetText(tostring(data.page).." / "..tostring(#data.pages))
    if focus then edit:TakeFocus();edit:SelectAll()end
end
function R.Show(text,onError)
    if not ZO_Dialogs_RegisterCustomDialog or not WINDOW_MANAGER then return end
    local data={text=tostring(text),onError=onError}
    safe(data,function()
    data.pages=R.Pages(data.text)
    if not registered then
        local control=WINDOW_MANAGER:CreateControlFromVirtual(id.."Control",GuiRoot,"KanaWardrobeProbeReportDialog")
        ZO_Dialogs_RegisterCustomDialog(id,{
            canQueue=true,customControl=control,
            title={text=function()return KW.Strings.PROBE_REPORT_TITLE or "Build probe report"end},
            setup=function(dialog,data)
                safe(data,function()
                    local width=math.min(900,math.max(240,GuiRoot:GetWidth()-48),GuiRoot:GetWidth())
                    local height=math.min(620,math.max(180,GuiRoot:GetHeight()-48),GuiRoot:GetHeight())
                    dialog:SetResizeToFitDescendents(false);dialog:SetDimensions(width,height)
                    dialog:GetNamedChild("Title"):SetWidth(math.max(1,width-64))
                    local edit=dialog:GetNamedChild("Edit")
                    edit:SetMaxInputChars(PAGE_BYTES)
                    edit:SetCopyEnabled(true)
                    for name,delta in pairs({Previous=-1,Next=1})do
                        local direction=delta
                        local button=dialog:GetNamedChild(name)
                        button:SetText(KW.Strings["REPORT_"..name:upper()] or name)
                        button:SetHandler("OnClicked",function()
                            safe(data,function()showPage(dialog,data,data.page+direction,true)end)
                        end)
                    end
                    showPage(dialog,data,1,false)
                    edit:SetHandler("OnEscape",function(self)
                        safe(data,function()self:LoseFocus();ZO_Dialogs_ReleaseDialog(id)end)
                    end)
                    -- Native setup runs while the dialog is hidden; hidden edits cannot focus.
                    edit:SetHandler("OnEffectivelyShown",function(self)
                        safe(data,function()self:TakeFocus();self:SelectAll()end)
                    end)
                    local close=dialog:GetNamedChild("Close")
                    close:ClearAnchors();close:SetAnchor(BOTTOMRIGHT,dialog,BOTTOMRIGHT,-32,-24)
                end)
            end,
            finishedCallback=releaseFocus,noChoiceCallback=releaseFocus,
            buttons={{control=control:GetNamedChild("Close"),keybind="DIALOG_NEGATIVE",
                text=function()return KW.Strings.CLOSE or "Close"end,callback=releaseFocus}},
        })
        registered=true
    end
    ZO_Dialogs_ShowDialog(id,data)
    end)
end
