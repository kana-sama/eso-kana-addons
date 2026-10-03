-- Curated game facts, not a copy of third-party tables/algorithms.
-- Candidate IDs/source lines and limitations: docs/catalog-sources.md.
KanaEffects.CatalogData = KanaEffects.CatalogData or {}
local data = {apiVersion=101051, rows={}, overrides={}}
KanaEffects.CatalogData.Families = data
local source = "Srendarr:92769505d8431d938655ec59e1f9951d686d7f04:AuraData.lua:"
local nativeSource = "ESOUI:6639eb2adecc0480557d9068579319919a0c3fe6:BuffType"
local function add(id, minorId, majorId, minorLine, majorLine, kind, rank, unconfirmedMajor)
    local levels = {}
    for _, level in ipairs({"minor", "major"}) do
        local abilityId = level == "minor" and minorId or majorId
        local line = level == "minor" and minorLine or majorLine
        local defined = abilityId ~= nil or (level == "major" and unconfirmedMajor == true)
        levels[level] = {nativeDefined=defined, catalogSupported=abilityId ~= nil,
            representativeId=abilityId, nativeConstant=defined and ("BUFF_TYPE_" .. string.upper(level) .. "_" .. string.upper(id)) or nil,
            provenance=line and (source .. line) or nativeSource}
    end
    data.rows[#data.rows+1] = {id=id, rank=rank, kind=kind, levels=levels, provenance=nativeSource}
end
-- Fixed UI ranks: common PvE support first, PvP-oriented debuffs last.
add("aegis",76618,93123,1767,2396,"buff",19)
add("berserk",61744,61745,1771,2406,"buff",4)
add("breach",61742,61743,1799,2434,"debuff",21)
add("brittle",145975,145977,1835,2470,"debuff",23)
add("brutality",61662,61665,1845,2477,"buff",3)
add("courage",121878,66902,1856,2528,"buff",2)
add("cowardice",46202,111354,1878,2540,"debuff",26)
add("defile",61726,61727,1895,2563,"debuff",27)
add("endurance",61704,61705,1919,2596,"buff",9)
add("enervation",47202,nil,1950,nil,"debuff",30)
add("evasion",61715,61716,1969,2621,"buff",14)
add("expedition",61735,61736,1978,2649,"buff",16)
add("force",61746,61747,1988,2706,"buff",6)
add("fortitude",61697,61698,2022,2727,"buff",8)
add("heroism",61708,61709,2038,2749,"buff",7)
add("intellect",61706,61707,2071,2769,"buff",10)
add("lifesteal",80020,nil,2091,nil,"debuff",24)
add("magickasteal",39100,nil,2104,nil,"debuff",25)
add("maim",61723,61725,2124,2794,"debuff",20)
add("mangle",61733,nil,2171,nil,"debuff",28,true)
add("mending",61710,61711,2183,2824,"buff",11)
add("protection",61721,61722,2203,2886,"buff",13)
add("resolve",61693,61694,2247,2927,"buff",1)
add("savagery",61666,61667,2271,2993,"buff",5)
add("slayer",76617,93109,2282,3036,"buff",18)
add("timidity",134149,nil,2290,nil,"debuff",29,true)
add("toughness",88490,nil,2301,nil,"buff",15)
add("uncertainty",47204,nil,2310,nil,"debuff",31)
add("vexation",260855,263406,2383,3121,"debuff",32)
add("vitality",61549,61275,2321,3087,"buff",12)
add("vulnerability",61782,106754,2339,3103,"debuff",22)
-- Our picker prioritization, not a native/PvE eligibility classification.
local pvpRare={cowardice=true,defile=true,enervation=true,mangle=true,timidity=true,uncertainty=true,vexation=true}
for _,family in ipairs(data.rows) do family.uiGroup=pvpRare[family.id] and "pvpRare" or "common" end
-- Narrow, source-backed U51 exception; deprecated types are never globally remapped.
for _, id in ipairs({21726,21729,21732,24160,24167,24171,24174,24177,24180,24184,24187,24195}) do
    data.overrides[id] = {familyId="savagery", level="major", provenance=source .. "296-313,2841-2854"}
end

-- R24: observed group buffs often lack a trusted caster. These exact Courage
-- members can be classified from the pinned source without inventing a caster
-- or matching localized names. Representatives/selector identity stay unchanged.
for _,membership in ipairs({
    {level="minor",firstLine=1857,ids={137348,147417,159310,159341,159352,159356,160394,175664,172721,176883,177885,187940,183579,186230,186235,214410,236475,259634,180949,217967}},
    {level="major",firstLine=2529,ids={109966,109994,110020,120015,172867,187904,221536,214431,249158,137295}},
}) do
    for index,id in ipairs(membership.ids) do
        data.overrides[id]={familyId="courage",level=membership.level,provenance=source .. (membership.firstLine+index-1)}
    end
end
