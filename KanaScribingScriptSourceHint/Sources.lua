KanaScribingScriptSourceHint = KanaScribingScriptSourceHint or {}
local A = KanaScribingScriptSourceHint
local S = {}
A.Sources = S

-- Script IDs from Character Knowledge 3.1.4 / API 101051. Exceptions must
-- precede slot classification: these pages are not in the daily reward pool.
S.special = {
    [5] = 'quest', [24] = 'quest', [64] = 'quest',
    [18] = 'quest', [32] = 'quest', [44] = 'quest', [48] = 'quest',
    [1] = 'guild', [16] = 'guild', [20] = 'guild',
    [25] = 'guild', [34] = 'guild', [41] = 'guild',
    [50] = 'guild', [59] = 'guild', [60] = 'guild', [31] = 'class',
}
S.bySlot = {
    [1] = {'delve', 'mages', 'worthy'},
    [2] = {'boss', 'fighters', 'cyrodiil'},
    [3] = {'event', 'undaunted', 'imperial', 'dungeon'},
}
S.names = {
    delve = 'Логово в DLC-зоне', mages = 'Гильдия магов',
    worthy = 'Награды достойным (PvP)', boss = 'Дейлик на мирового босса',
    fighters = 'Гильдия бойцов', cyrodiil = 'Дейлики Сиродила',
    event = 'Дейлик на мировое событие', undaunted = 'Болгрул: дейлик в логове',
    imperial = 'Дейлики районов Имперского города', dungeon = 'Случайное ежедневное подземелье',
}
S.details = {
    delve = {
        icon = '/esoui/art/mappins/mapkey_solo_dungeon.dds',
        description = 'Выполните ежедневное задание в логове DLC-зоны и откройте наградной контейнер.',
        location = 'У распорядителей ежедневных заданий в DLC-зонах. Например, Дитум-Джас (Deetum-Jas) в Лейавине, Черный Лес.',
    },
    mages = {
        icon = '/esoui/art/icons/mapkey/mapkey_magesguild.dds',
        description = 'Найдите реликвию Шеогората в указанном открытом подземелье и откройте награду за задание.',
        location = 'Альвур Барен (Alvur Baren) в Гильдии магов Элден-Рута, Вэйреста или Морнхолда. Требуется вступить в гильдию.',
    },
    worthy = {
        icon = '/esoui/art/icons/mapkey/mapkey_avatown.dds',
        description = 'Зарабатывайте очки альянса в PvP и открывайте контейнеры «Награды достойным» из почты.',
        location = 'Сиродил или поля сражений. Отдельное задание брать не нужно: контейнер приходит по почте за заработанные очки альянса.',
    },
    boss = {
        icon = '/esoui/art/icons/mapkey/mapkey_groupboss.dds',
        description = 'Выполните ежедневное задание на мирового босса DLC-зоны и откройте наградной контейнер.',
        location = 'У распорядителей ежедневных заданий в DLC-зонах. Например, Бритта Силан (Britta Silanus) в Лейавине, Черный Лес.',
    },
    fighters = {
        icon = '/esoui/art/icons/mapkey/mapkey_fightersguild.dds',
        description = 'Уничтожьте три темных якоря в указанной зоне и откройте награду за задание.',
        location = 'Кардея Галл (Cardea Gallus) в Гильдии бойцов Элден-Рута, Вэйреста или Морнхолда. Требуется вступить в гильдию.',
    },
    cyrodiil = {
        icon = '/esoui/art/icons/mapkey/mapkey_avatown.dds',
        description = 'Выполните ежедневное задание поселения или доски поручений Сиродила и откройте наградной контейнер.',
        location = 'Доски поручений на базах альянса; жители Брумы, Властаруса, Кропсфорда, Чейдинхола и Коррола. Вход через меню войны альянсов.',
    },
    event = {
        icon = '/esoui/art/icons/mapkey/mapkey_dynamic_world_event.dds',
        description = 'Выполните ежедневное задание на мировое событие DLC-зоны и откройте наградной контейнер.',
        location = 'У распорядителей событий в DLC-зонах. Например, друидка Айшабе (Druid Aishabeh) в Вастире, Гален: задание на вулканический разлом.',
    },
    undaunted = {
        icon = '/esoui/art/icons/mapkey/mapkey_undaunted.dds',
        description = 'Выполните задание Болгрула в логове базовой игры и откройте наградной контейнер. Это отдельное задание от обетов.',
        location = 'Болгрул (Bolgrul) в анклаве Неустрашимых рядом с Элден-Рутом, Вэйрестом или Морнхолдом. Требуется вступить в Неустрашимые.',
    },
    imperial = {
        icon = '/esoui/art/mappins/ava_imperialcity_neutral.dds',
        description = 'Выполните ежедневное задание одного из шести районов Имперского города и откройте наградной контейнер.',
        location = 'Войдите в Имперский город через меню войны альянсов. На базе альянса поднимитесь по лестнице в район: поручитель стоит на безопасной площадке наверху.',
    },
}
local empty = {}
function S.ForScript(id, slot)
    if not id or id < 1 or id > 70 or id == 11 or id == 21 or id == 43 or S.special[id] then return empty end
    return S.bySlot[slot] or empty
end

function S.DailyForScript(id, slot)
    local sources = {}
    for _, source in ipairs(S.ForScript(id, slot)) do
        -- Random dungeon mail remains tracked, but is not one of the three
        -- daily source icons (zone, guild, PvP) requested for each script.
        if S.details[source] then sources[#sources + 1] = source end
    end
    return sources
end

local groups = {
    guild_mages = {[1] = 'mages'}, guild_fighters = {[2] = 'fighters'},
    guild_undaunted = {[3] = 'undaunted'}, worthy = {[1] = 'worthy'},
    cyrodiil = {[2] = 'cyrodiil'}, imperial = {[3] = 'imperial'},
    zone = {[1] = 'delve', [2] = 'boss', [3] = 'event'},
    dungeon = {[3] = 'dungeon'},
}
function S.SourceForLoot(group, id, slot)
    local source = groups[group] and groups[group][slot]
    if source then
        for _, candidate in ipairs(S.ForScript(id, slot)) do
            if source == candidate then return source end
        end
    end
end

-- Resolve exact localized coffer names from the client, never fuzzy-match
-- arbitrary world objects or infer a source from the last completed quest.
-- Zone coffers can share a name across delve/boss/event quests; the actual
-- script slot disambiguates them, including the two Gold Coast rewards.
S.coffers = {
    guild_mages = {96386, 203762, 203763, 203764, 203765, 203766, 203767,
        203768, 203769, 203770, 203771, 203772, 203773, 203774, 203775, 203776},
    guild_fighters = {96385, 203731, 203747, 203748, 203749, 203750, 203751,
        203752, 203753, 203754, 203755, 203757, 203758, 203759, 203760, 203761},
    guild_undaunted = {96387, 203777, 203778, 203779, 203780, 203781, 203782,
        203783, 203784, 203785, 203786, 203787, 203788, 203789, 203790, 203791},
    worthy = {134619, 145577, 181436, 184171, 190009, 194353, 204404, 210866,
        214239, 219651, 224367},
    cyrodiil = {119550, 119551, 119552, 119553, 119554, 199725, 199726,
        199727, 199728, 208129},
    imperial = {69413},
    zone = {71312, 74679, 74680, 77526, 77556, 94121, 94122, -- Wrothgar / Gold Coast
        126032, 126033, 133225, 138800, 141741, -- Vvardenfell / Clockwork / Summerset / Murkmire
        151620, 151623, 153853, 153854, 153864, -- Elsweyr / Senchal
        159621, 165575, 165576, 165577, 170223, 170224, 170225, -- Skyrim / Reach
        178407, 178408, 182936, 183008, -- Blackwood / Deadlands
        188136, 188137, 188138, 190948, 190949, 190952, -- High Isle / Galen
        197818, 197819, 197820, 204445, 204446, 204447, -- Necrom / revised coffers
        207980, 207981, 207982, 217731, 217732}, -- West Weald / Solstice
}

function S.ItemLink(id)
    return string.format('|H1:item:%d:1:1:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h', id)
end

function S.CofferNames(api)
    local names = {}
    for group, ids in pairs(S.coffers) do
        for _, id in ipairs(ids) do
            local link = S.ItemLink(id)
            local kind = api.GetItemLinkItemType(link)
            if kind == api.ITEMTYPE_CONTAINER or kind == api.ITEMTYPE_CONTAINER_STACKABLE then
                local name = api.GetItemLinkName(link)
                if name and name ~= '' then
                    local normalized = api.zo_strformat(api.SI_TOOLTIP_ITEM_NAME, name)
                    for _, key in ipairs({name, normalized}) do
                        -- A cross-source name collision is ambiguous, not a guess.
                        if names[key] and names[key] ~= group then names[key] = false
                        elseif names[key] == nil then names[key] = group end
                    end
                end
            end
        end
    end
    return names
end
