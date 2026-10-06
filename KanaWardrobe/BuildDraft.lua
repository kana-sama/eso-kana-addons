local KW=KanaWardrobe
local Draft={};KW.BuildDraft=Draft
local Instance={};Instance.__index=Instance
local pages={inventory='equipment',skills='abilities',stats='attributes'}
local groups={equipment=true,skills=true,bars=true,attributes=true}
function Draft.Component(page)return pages[page or 'inventory']end
-- A saved bar can reference a morph whose talent checkbox is off. Opening the
-- editor prepares that morph locally; selection and the apply planner stay strict.
function Draft.AbilitiesForEditor(abilities,catalogue)
 local wanted=KW.Copy(abilities)
 for _,bar in ipairs({'front','back','werewolf'})do
  for slot=1,6 do
   local ref=wanted.bars and wanted.bars[bar] and wanted.bars[bar][slot]
   if ref and ref.kind=='skill' and not (wanted.skills and wanted.skills[ref.skillKey])then
    local record=catalogue and catalogue.byKey and catalogue.byKey[ref.skillKey]
    if record and record.kind=='active' and record.mutable then
     wanted.skills=wanted.skills or {}
     wanted.skills[ref.skillKey]={kind='active',purchased=true,morph=ref.expectedMorph}
    end
   end
  end
 end
 return wanted
end
function Draft.IncludedGroups(component,selection,preset,cleared)
 local function any(values)for _,value in pairs(values or {})do if value then return true end end;return false end
 local function bars(values)
  for _,bar in ipairs({'front','back','werewolf'})do if any(values and values[bar])then return true end end
  return false
 end
 preset=preset or {};cleared=cleared or {};selection=selection or {}
 local abilities=preset.abilities or {}
 local included={equipment=any(preset.equipment),skills=any(abilities.skills),bars=bars(abilities.bars),attributes=preset.attributes~=nil}
 for group in pairs(groups)do if cleared[group]then included[group]=false end end
 if component=='equipment'then included.equipment=any(selection.equipment)
 elseif component=='abilities'then included.skills=any(selection.skills);included.bars=bars(selection.bars)
 elseif component=='attributes'then included.attributes=selection.attributes==true end
 return included
end
-- Clearing another page only changes what is saved; it never mounts that page
-- or changes the character. The current page's checkboxes remain authoritative.
function Draft.PresetCandidate(preset,component,selected,cleared)
 local candidate=KW.Copy(preset or {});candidate.slots=nil
 cleared=cleared or {}
 if cleared.equipment then candidate.equipment=nil end
 if cleared.attributes then candidate.attributes=nil end
 if candidate.abilities then
  if cleared.skills then candidate.abilities.skills=nil end
  if cleared.bars then candidate.abilities.bars=nil end
  if (cleared.skills or cleared.bars) and not KW.BuildModel.HasParts({abilities=candidate.abilities})then candidate.abilities=nil end
 end
 candidate[component]=KW.Copy(selected and selected[component])
 return KW.BuildModel.Normalize(candidate)
end
function Draft.New(original,preset,page)
 local component=Draft.Component(page);if not component then return nil,KW.Problem('invalidEditorPage')end
 if not original[component] then return nil,KW.Problem('buildCapabilityUnavailable',{component=component})end
 local normalized,err=KW.BuildModel.Normalize({[component]=original[component]});if not normalized then return nil,err end
 local wanted=preset and preset[component];local build=KW.BuildModel.Merge(normalized,wanted and {[component]=wanted} or {})
 local self=setmetatable({component=component,page=page or 'inventory',original=KW.Copy(normalized),build=build,selection={equipment={},skills={},bars={front={},back={},werewolf={}},attributes=false}},Instance)
 local existing=preset and preset.id~=nil
 local seed=wanted or (not preset or not preset.id) and original[component]
 if seed then
  if component=='attributes'then self.selection.attributes=true
  elseif component=='equipment'then for key,ref in pairs(seed)do self.selection.equipment[key]=existing or ref.kind=='item' end
  else for key,state in pairs(seed.skills or {})do self.selection.skills[key]=existing or state.kind=='active' and state.purchased==true or state.kind=='passive' and state.rank>0 end;for _,bar in ipairs({'front','back','werewolf'})do for key,ref in pairs(seed.bars and seed.bars[bar] or {})do self.selection.bars[bar][key]=existing or bar~='werewolf' and ref.kind=='skill' end end end
 end
 return self
end
function Instance:SetValue(domain,key,value)
 if domain=='bars' and type(key)=='table'then domain,key=key.bar,key.slot end
 local build=KW.Copy(self.build)
 if domain==self.component and domain~='abilities'then
  if domain=='attributes' then build.attributes[key]=KW.Copy(value)else build.equipment[key]=KW.Copy(value)end
 elseif self.component=='abilities' and domain=='skills'then build.abilities.skills=build.abilities.skills or {};build.abilities.skills[key]=KW.Copy(value)
 elseif self.component=='abilities' and (domain=='front' or domain=='back' or domain=='werewolf')then build.abilities.bars=build.abilities.bars or {};build.abilities.bars[domain]=build.abilities.bars[domain]or {};build.abilities.bars[domain][key]=KW.Copy(value)
 else return nil,KW.Problem('editorDomainMismatch')end
 local normalized,err=KW.BuildModel.Normalize(build);if not normalized then return nil,err end
 self.build=normalized;return true
end
function Instance:SetSelected(domain,key,value)
 if domain=='bars' and type(key)=='table'then domain,key=key.bar,key.slot end
 if type(value)~='boolean'then return nil,KW.Problem('invalidSelection')end
 if self.component=='equipment' and domain=='equipment' and KW.Slots.IsSupported(key)then self.selection.equipment[key]=value
 elseif self.component=='abilities' and domain=='skills' and self.build.abilities.skills and self.build.abilities.skills[key]then self.selection.skills[key]=value
 elseif self.component=='abilities' and (domain=='front' or domain=='back' or domain=='werewolf')and type(key)=='number' and key>=1 and key<=6 and key%1==0 then self.selection.bars=self.selection.bars or {};self.selection.bars[domain]=self.selection.bars[domain]or {};self.selection.bars[domain][key]=value
 else return nil,KW.Problem('editorDomainMismatch')end
 return true
end
function Instance:SetAttributesEnabled(value)
 if self.component~='attributes' or type(value)~='boolean'then return nil,KW.Problem('editorDomainMismatch')end
 self.selection.attributes=value;return true
end
function Instance:ClearSelection(group)
 if not groups[group]then return nil,KW.Problem('invalidSelection')end
 if group=='attributes'then self.selection.attributes=false
 elseif group=='bars'then self.selection.bars={front={},back={},werewolf={}}
 else self.selection[group]={}end
 return true
end
function Instance:GetBuild()return KW.Copy(self.build)end
function Instance:GetSelection()return KW.Copy(self.selection)end
function Instance:GetPresetBuild()return KW.BuildModel.Select(self.build,self.selection)end
function Instance:Replace(value)
 local build,err=KW.BuildModel.Normalize({[self.component]=value});if not build then return nil,err end
 for _,entry in pairs(self.unresolved or {})do
  if entry.domain=='skills'then build.abilities.skills=build.abilities.skills or {};build.abilities.skills[entry.key]=KW.Copy(entry.ref)
  else build.abilities.bars=build.abilities.bars or {};build.abilities.bars[entry.domain]=build.abilities.bars[entry.domain]or {};build.abilities.bars[entry.domain][entry.key]=KW.Copy(entry.ref)end
 end
 self.build=build;return true
end
