local KW=KanaWardrobe
local Draft={};KW.BuildDraft=Draft
local Instance={};Instance.__index=Instance
local pages={inventory='equipment',skills='abilities',stats='attributes'}
function Draft.Component(page)return pages[page or 'inventory']end
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
