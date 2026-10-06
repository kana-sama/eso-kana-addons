local K=KanaStatSources
local D={};K.Dump=D
function D.Build(snapshot,breakdowns,contributions,diagnostics)
    local report,serialization=K.Core.CopySerializable({schemaVersion=K.schemaVersion,addonVersion=K.version,snapshot=snapshot,breakdowns=breakdowns,contributions=contributions,diagnostics=diagnostics})
    report.serializationDiagnostics=serialization
    local s=report.snapshot;s.categoryStatus=s.categoryStatus or {}
    for _,group in ipairs({'equipment','build','effects','advancedStats'}) do if not s.categoryStatus[group] then s.categoryStatus[group]='unavailable' end end
    for _,group in ipairs({'stats','attributes','equipment','sets','skills','champion','effects','bars','criticalSamples','advancedStats','errors','capabilities','context','meta','preview'}) do s[group]=s[group] or {} end
    return report
end
function D.Storage(api)
    local saved=api.KanaStatSourcesSaved
    if saved and saved.schemaVersion~=nil and saved.schemaVersion~=K.schemaVersion then return nil,'Unsupported SavedVariables schema: '..tostring(saved.schemaVersion) end
    if not saved then saved={};api.KanaStatSourcesSaved=saved end
    saved.schemaVersion=K.schemaVersion;saved.nextDumpId=saved.nextDumpId or 1;saved.dumps=saved.dumps or {}
    return saved
end
function D.Append(saved,report)
    if saved.schemaVersion~=K.schemaVersion then return nil,'Unsupported SavedVariables schema' end
    local record=K.Core.CopySerializable(report);record.id=saved.nextDumpId
    saved.nextDumpId=saved.nextDumpId+1;saved.dumps[#saved.dumps+1]=record
    while #saved.dumps>10 do table.remove(saved.dumps,1) end
    return record.id
end
