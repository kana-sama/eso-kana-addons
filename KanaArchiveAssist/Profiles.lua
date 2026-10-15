local K=KanaArchiveAssist
local P={};K.Profiles=P
function P.New(saved,world,character,lower)
 saved.worlds=saved.worlds or {};saved.worlds[world]=saved.worlds[world] or {profiles={},characters={},nextId=1}
 local w=saved.worlds[world]
 local self=setmetatable({world=w,worldName=world,characterId=character,lower=lower or string.lower},{__index=P})
 if not w.defaultId or not w.profiles[w.defaultId] then
  local p=self:Make('default');w.defaultId=p.id
 end
 w.characters[character]=w.characters[character] or {activeId=w.defaultId}
 self.character=w.characters[character]
 self.character.learningEnabled=nil -- Retired persistent pause; exclusions belong to offers.
 if not w.profiles[self.character.activeId] then self.character.activeId=w.defaultId end
 return self
end
function P:Make(name)
 local id='p'..self.world.nextId;self.world.nextId=self.world.nextId+1
 local p={id=id,name=name,schemaVersion=1,seed=self.world.nextId*7919,history={}}
 self.world.profiles[id]=p;return p
end
function P:Name(name,except)
 if type(name)~='string' then return nil,'Введите имя профиля.' end
 name=name:match('^%s*(.-)%s*$')
 if name=='' or name:find('[|%c]') then return nil,'Имя пустое или содержит недопустимые символы.' end
 for id,p in pairs(self.world.profiles) do
  if id~=except and self.lower(p.name)==self.lower(name) then return nil,'Профиль с таким именем уже есть.' end
 end
 return name
end
function P:GetActive() return self.world.profiles[self.character.activeId] end
function P:List()
 local list={};for _,p in pairs(self.world.profiles)do list[#list+1]=p end
 table.sort(list,function(a,b)return self.lower(a.name)<self.lower(b.name) end);return list
end
function P:Create(name)
 local clean,err=self:Name(name);if not clean then return nil,err end
 local p=self:Make(clean);self.character.activeId=p.id;return p
end
function P:Rename(id,name)
 local p=self.world.profiles[id];if not p then return nil,'Профиль не найден.' end
 local clean,err=self:Name(name,id);if not clean then return nil,err end;p.name=clean;return p
end
function P:Use(id)
 if not self.world.profiles[id] then return nil,'Профиль не найден.' end
 self.character.activeId=id;return self:GetActive()
end
