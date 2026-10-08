local KW=KanaWardrobe
local A={};KW.AppearanceAdapter=A
local I={};I.__index=I
A.Order={'COSTUME','HAT','HAIR','FACIAL_HAIR_HORNS','FACIAL_ACCESSORY','PIERCING_JEWELRY','HEAD_MARKING','BODY_MARKING','SKIN','POLYMORPH','PERSONALITY'}
function A.Categories(api)
 api=api or _G;local rows={}
 for _,key in ipairs(A.Order)do
  local category=api['COLLECTIBLE_CATEGORY_TYPE_'..key]
  if category~=nil then rows[#rows+1]={category=category,key=key,name=KW.Text('APPEARANCE_'..key),emptyName=KW.Text('APPEARANCE_NONE_'..key)}end
 end
 return rows
end
function A.New(api)
 local self=setmetatable({api=api or _G,categories={}},I)
 self.order=A.Categories(self.api)
 for _,row in ipairs(self.order)do self.categories[row.category]=row end
 return self
end
function I:Describe(category,id)
 local row=self.categories[category]
 local name=id and id>0 and self.api.GetCollectibleName and self.api.GetCollectibleName(id)
 if name and self.api.zo_strformat and self.api.SI_COLLECTIBLE_NAME_FORMATTER then name=self.api.zo_strformat(self.api.SI_COLLECTIBLE_NAME_FORMATTER,name)end
 return {category=category,id=id,categoryName=row and row.name or KW.Text('APPEARANCE'),
  name=name or row and row.emptyName or KW.Text('OP_EMPTY'),
  icon=id and id>0 and self.api.GetCollectibleIcon and self.api.GetCollectibleIcon(id) or nil}
end
function I:Capture()
 local api=self.api
 if type(api.GetActiveCollectibleByType)~='function' or type(api.UseCollectible)~='function'then return nil,KW.Problem('appearanceUnavailable')end
 local result={}
 for _,row in ipairs(self.order)do result[row.category]=api.GetActiveCollectibleByType(row.category,api.GAMEPLAY_ACTOR_CATEGORY_PLAYER)end
 return result
end
function I:Validate(category,id)
 local api=self.api;local details=self:Describe(category,id)
 if not self.categories[category]then return nil,KW.Problem('appearanceCategoryUnavailable',details)end
 if id~=0 then
  if api.GetCollectibleCategoryType(id)~=category then return nil,KW.Problem('appearanceWrongCategory',details)end
  if not api.IsCollectibleUnlocked(id)then return nil,KW.Problem('appearanceLocked',details)end
 end
 return true
end
function I:Prepare(actual,wanted)
 if not actual then return nil,KW.Problem('appearanceUnavailable')end
 local changes={}
 for category,id in pairs(wanted)do
  local ok,problem=self:Validate(category,id);if not ok then return nil,problem end
 end
 for _,row in ipairs(self.order)do
  local id=wanted[row.category]
  if id~=nil and actual[row.category]~=id then
   changes[#changes+1]={category=row.category,before=actual[row.category],target=id,
    details={categoryName=row.name,beforeName=self:Describe(row.category,actual[row.category]).name,targetName=self:Describe(row.category,id).name}}
  end
 end
 return {target=KW.Copy(wanted),changes=changes}
end
function I:Request(category,id)
 local api=self.api
 local ok,problem=self:Validate(category,id);if not ok then return nil,problem end
 local actual;actual,problem=self:Capture();if not actual then return nil,problem end
 if actual[category]==id then return true end
 -- UseCollectible toggles the current collectible off. Never replay a finished
 -- request, and resolve the current ID again when clearing a category.
 local useId=id==0 and actual[category] or id
 if not useId or useId==0 then return nil,KW.Problem('appearanceUnavailable')end
 local remaining=api.GetCollectibleCooldownAndDuration and api.GetCollectibleCooldownAndDuration(useId) or 0
 if remaining>0 then return nil,KW.Problem('appearanceCooldown',{remainingMs=remaining})end
 -- Usability and temporary blocking are separate native checks. A usable
 -- collectible can still be blocked by the shared appearance cooldown.
 local reason=api.GetCollectibleBlockReason and api.GetCollectibleBlockReason(useId,api.GAMEPLAY_ACTOR_CATEGORY_PLAYER)
 local cooling=api.COLLECTIBLE_USAGE_BLOCK_REASON_ON_COOLDOWN~=nil and reason==api.COLLECTIBLE_USAGE_BLOCK_REASON_ON_COOLDOWN
 local blocked=reason~=nil and api.COLLECTIBLE_USAGE_BLOCK_REASON_NOT_BLOCKED~=nil and reason~=api.COLLECTIBLE_USAGE_BLOCK_REASON_NOT_BLOCKED
 if cooling or blocked or api.IsCollectibleUsable and not api.IsCollectibleUsable(useId,api.GAMEPLAY_ACTOR_CATEGORY_PLAYER)then
  local details=self:Describe(category,useId)
  details.reason=reason
  if details.reason and api.GetString then details.reasonText=api.GetString('SI_COLLECTIBLEUSAGEBLOCKREASON',details.reason)end
  if cooling then
   return nil,KW.Problem('appearanceCooldown',details)
  end
  return nil,KW.Problem('appearanceBlocked',details)
 end
 api.UseCollectible(useId,api.GAMEPLAY_ACTOR_CATEGORY_PLAYER)
 return true
end
