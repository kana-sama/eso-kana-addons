-- Semantic tags do not imply polarity, duration, caster or source origin.
-- food is the combined food/drink umbrella; drink is independently curated.
KanaEffects.CatalogData = KanaEffects.CatalogData or {}
local data = {apiVersion=101051, rows={}, abilities={}}
KanaEffects.CatalogData.Categories = data
local bandits = "Bandits:00d415ce95a63a3dc53977d81ca1a91a363e47b7:BUI_Buffs.lua:"
for rank, id in ipairs({"food","drink","xp","event","service","membership","cooldown","justice","skillExperience"}) do
    data.rows[#data.rows+1] = {id=id,rank=100+rank,provenance=bandits .. "1-24,267"}
end
local wardrobe = "WizardsWardrobe:6dc18bdc1504e0dfba642a98e63011687a9d7de6:Const:"
local function add(id, tags, alias, provenance)
    local categories = {}
    for _, tag in ipairs(tags) do categories[tag] = true end
    data.abilities[id] = {categories=categories, aliases=alias and {alias} or {},
        provenance=provenance, origin="unknown"}
end
-- Recipe labels are search aliases; native API/observations supply effect names.
add(61259,{"food"},"Garlic-and-Pepper Venison Steak",bandits .. "15;" .. wardrobe .. "109-111")
add(61218,{"food"},"Capon Tomato-Beet Casserole",bandits .. "22;" .. wardrobe .. "127-130")
add(68411,{"food"},"Crown Fortifying Meal",bandits .. "22;" .. wardrobe .. "107")
add(127596,{"food"},"Bewitched Sugar Skulls",bandits .. "22;" .. wardrobe .. "188")
add(84731,{"food","drink"},"Witchmother's Potent Brew",bandits .. "18;" .. wardrobe .. "164")
add(84735,{"food","drink"},"Purifying Bloody Mara",bandits .. "18;" .. wardrobe .. "165")
add(61335,{"food","drink"},"Port Hunding Pinot Noir",bandits .. "21;" .. wardrobe .. "140-142")
add(61350,{"food","drink"},"Senche-Tiger Single Malt",bandits .. "21;" .. wardrobe .. "149-152")
add(68416,{"food","drink"},"Crown Refreshing Drink",bandits .. "21;" .. wardrobe .. "108")
add(89957,{"food","drink"},"Dubious Camoran Throne",bandits .. "23;" .. wardrobe .. "179")
add(100498,{"food"},"Clockwork Citrus Filet",bandits .. "18;" .. wardrobe .. "183")
-- T14 audited active-buff union: 79 known members, plus two related auras.
-- These additional rows assert only the food/drink umbrella; fine drink tags
-- need independently verified item-type evidence, never stat/name heuristics.
add(61255,{"food"},"Sticky Pork and Radish Noodles",bandits .. "23;" .. wardrobe .. "121-123")
add(61257,{"food"},"Mistral Banana-Bunny Hash",bandits .. "18;" .. wardrobe .. "118-120")
add(61260,{"food"},"Firsthold Fruit and Cheese Plate",bandits .. "20;" .. wardrobe .. "112-114")
add(61261,{"food"},"Hearty Garlic Corn Chowder",bandits .. "19;" .. wardrobe .. "115-117")
add(61294,{"food"},"Chevre-Radish Salad with Pumpkin Seeds",bandits .. "17;" .. wardrobe .. "124-126")
add(61340,{"food"},"Wide-Eye Double Rye",bandits .. "21;" .. wardrobe .. "143-145")
add(61345,{"food"},"Honest Lassie Honey Tea",bandits .. "21;" .. wardrobe .. "146-148")
add(72816,{"food"},"Orzorga's Red Frothgar",bandits .. "15;" .. wardrobe .. "153")
add(72819,{"food"},"Orzorga's Tripe Trifle Pocket",bandits .. "15;" .. wardrobe .. "154")
add(72822,{"food"},"Orzorga's Blood Price Pie",bandits .. "15;" .. wardrobe .. "155")
add(72824,{"food"},"Orzorga's Smoked Bear Haunch",bandits .. "15;" .. wardrobe .. "156")
add(84678,{"food"},"Sweet Sanguine Apples",bandits .. "20;" .. wardrobe .. "157,177")
add(84681,{"food"},"Crisp and Crunchy Pumpkin Snack Skewer",bandits .. "17;" .. wardrobe .. "158")
add(84700,{"food"},"Bowl of \"Peeled Eyeballs\"",bandits .. "21;" .. wardrobe .. "159")
add(84704,{"food"},"Witchmother's Party Punch",bandits .. "21;" .. wardrobe .. "160")
add(84709,{"food"},"Crunchy Spider Skewer",bandits .. "20;" .. wardrobe .. "161")
add(84720,{"food"},"Ghastly Eye Bowl",bandits .. "20;" .. wardrobe .. "162")
add(84725,{"food"},"Frosted Brains",bandits .. "20;" .. wardrobe .. "163")
add(85484,{"food"},"Crown Crate Fortifying Meal",bandits .. "22;" .. wardrobe .. "166")
add(86559,{"food"},"Hissmir Fish-Eye Rye",bandits .. "21;" .. wardrobe .. "168")
add(86673,{"food"},"Lava Foot Soup-and-Saltrice",bandits .. "19;" .. wardrobe .. "169")
add(86746,{"food"},"Betnikh Twice-Spiked Ale",bandits .. "21;" .. wardrobe .. "171")
add(86749,{"food"},"Jagga-Drenched \"Mud Ball\"",bandits .. "23;" .. wardrobe .. "172")
add(89955,{"food"},"Candied Jester's Coins",bandits .. "17;" .. wardrobe .. "178")
add(89971,{"food"},"Jewels of Misrule",bandits .. "15;" .. wardrobe .. "180")
add(100488,{"food"},"Spring-Loaded Infusion",bandits .. "22;" .. wardrobe .. "182")
add(100502,{"food"},"Deregulated Mushroom Stew",bandits .. "21;" .. wardrobe .. "181")
add(107748,{"food"},"Artaeum Pickled Fish Bowl",bandits .. "18;" .. wardrobe .. "184")
add(107789,{"food"},"Artaeum Takeaway Broth",bandits .. "23;" .. wardrobe .. "185")
add(127531,{"food"},"Corrupting Bloody Mara",bandits .. "18;" .. wardrobe .. "186")
add(127572,{"food"},"Pack Leader's Bone Broth",bandits .. "23;" .. wardrobe .. "187")
add(61322,{"food"},"Kragenmoor Zinger Mazte",wardrobe .. "131-133")
add(61325,{"food"},"Heart's Day Rose Tea",wardrobe .. "134-136")
add(61328,{"food"},"Fredas Night Infusion",wardrobe .. "137-139")
add(85497,{"food"},"Crown Crate Refreshing Drink",wardrobe .. "167")
add(86677,{"food"},"Bergama Warning Fire",wardrobe .. "170")
add(86787,{"food"},"Rajhin's Sugar Claws",wardrobe .. "174")
add(86789,{"food"},"Alcaire Festival Sword-Pie",wardrobe .. "175")
add(86791,{"food"},"Snow Bear Glow-Wine",wardrobe .. "176")
add(148633,{"food"},"Sparkling Mudcrab Apple Cider",wardrobe .. "189")
for _, id in ipairs({17407,66124,66125,66551,72957,72960,72962}) do add(id,{"food"},nil,bandits .. "15") end
for _, id in ipairs({17577,72961}) do add(id,{"food"},nil,bandits .. "17") end
for _, id in ipairs({72959}) do add(id,{"food"},nil,bandits .. "18") end
for _, id in ipairs({66129,66130,68412}) do add(id,{"food"},nil,bandits .. "19") end
for _, id in ipairs({66127,66128,66568,68413}) do add(id,{"food"},nil,bandits .. "20") end
for _, id in ipairs({17614,61341,61344,66131,66132,66136,66137,66140,66141}) do add(id,{"food"},nil,bandits .. "21") end
for _, id in ipairs({17581}) do add(id,{"food"},nil,bandits .. "22") end
for _, id in ipairs({72956}) do add(id,{"food"},nil,bandits .. "23") end
-- Redundant food auras are membership facts, not a deduplication algorithm.
for _, id in ipairs({84732,84733}) do add(id,{"food"},"Witchmother's Potent Brew",
    "Srendarr:92769505d8431d938655ec59e1f9951d686d7f04:AuraData.lua:1379-1381") end
for _, id in ipairs({64210,66776,85502,85503,89683}) do add(id,{"xp"},nil,bandits .. "8;Reminderz:XPReminder.lua:9-19") end
for _, id in ipairs({91449,86075,96118}) do add(id,{"event"},nil,bandits .. "4,9") end
add(63601,{"service","membership"},"ESO Plus",bandits .. "267;Srendarr:92769505d8431d938655ec59e1f9951d686d7f04:1429-1432")
add(21676,{"service","cooldown"},"Recall cooldown",bandits .. "10")
add(21798,{"service","justice"},"Bounty timer",bandits .. "12")
add(147687,{"service","skillExperience"},"Alliance Skill Gain Boost",bandits .. "11")
