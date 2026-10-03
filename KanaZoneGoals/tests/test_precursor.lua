dofile('Core.lua')
dofile('Providers.lua')
local K=KanaZoneGoals
GetAchievementInfo=function() return 'Precursor','',0,'icon' end
GetAchievementNumCriteria=function() return 14 end
local delivered={}
GetAchievementCriterion=function(_,index) return 'Part '..index,delivered[index] and 1 or 0,1 end
local held={}
GetItemLinkStacks=function(link)
    local id=tonumber(link:match('item:(%d+)'))
    return table.unpack(held[id] or {0,0,0,0,0,0})
end
for storage=1,6 do
    for index=1,14 do
        local counts={0,0,0,0,0,0};counts[storage]=2
        held={[129899+index]=counts}
        local goal=K.AchievementGoal(1958,'museums',{[index]=true})
        assert(goal.current==1 and goal.total==1,'held part must complete criterion, storage '..storage..' index '..index)
        assert(goal.criteria[1].current==1)
        local other=K.AchievementGoal(1958,'museums',{[index%14+1]=true})
        assert(other.current==0,'inventory must not complete another part')
    end
end
held={};delivered[1]=true
assert(K.AchievementGoal(1958,'museums',{[1]=true}).current==1,'delivered part remains complete without inventory')
delivered={}
assert(K.AchievementGoal(1958,'museums').current==0,'removing unsubmitted items must clear inventory completion')
held={[129900]={1,0,0,0,0,0}}
assert(K.AchievementGoal(123,'museums').current==0,'other achievements must be unaffected')
print('PASS precursor: all 14 parts/all storage returns/local criteria/delivered/removal/isolation')

-- Synthetic links may not match real item variants: slot IDs remain authoritative.
GetItemLinkStacks=function() return 0,0,0,0,0,0 end
BAG_BACKPACK=1; BAG_BANK=2; BAG_SUBSCRIBER_BANK=3; BAG_HOUSE_BANK_ONE=8
local bags={}
GetBagSize=function(bag) return 3 end
GetItemId=function(bag,slot) return bags[bag] and bags[bag][slot] or 0 end
for _,bag in ipairs({BAG_BACKPACK,BAG_BANK,BAG_SUBSCRIBER_BANK,BAG_HOUSE_BANK_ONE}) do
    for index=1,14 do
        bags={[bag]={[0]=129899+index}}
        local goal=K.AchievementGoal(1958,'museums',{[index]=true})
        assert(goal.current==1 and goal.criteria[1].current==1,'real slot must count when link query returns zero')
        assert(K.AchievementGoal(1958,'museums',{[index%14+1]=true}).current==0)
    end
end
bags={[BAG_BACKPACK]={[2]=129907}}
assert(K.AchievementGoal(1958,'museums',{[8]=true}).current==1,'left hand in last slot must count')
bags={}
assert(K.AchievementGoal(1958,'museums',{[8]=true}).current==0,'removed left hand must not remain cached')
print('PASS precursor actual slots: link miss/left hand/all parts/storage/slot zero/last slot/removal')
