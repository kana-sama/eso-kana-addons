KanaCombatBookmarks = KanaCombatBookmarks or {}
local Names = {}
KanaCombatBookmarks.Names = Names

-- Selected Russian translations from dariusk/corpora (CC0), plus common phenomena.
-- https://github.com/dariusk/corpora/tree/master/data/mythology
local pool = {
    "Кракен",
    "Феникс",
    "Химера",
    "Мантикора",
    "Минотавр",
    "Гидра",
    "Циклоп",
    "Грифон",
    "Гарпия",
    "Гаргулья",
    "Гиппогриф",
    "Джинн",
    "Дракон",
    "Голем",
    "Гремлин",
    "Единорог",
    "Лепрекон",
    "Лич",
    "Мумия",
    "Пегас",
    "Полтергейст",
    "Сфинкс",
    "Валькирия",
    "Вампир",
    "Вендиго",
    "Виверна",
    "Йети",
    "Чупакабра",
    "Оборотень",
    "Кентавр",
    "Арахна",
    "Харибда",
    "Армагеддон",
    "Рагнарёк",
    "Апокалипсис",
    "Катаклизм",
    "Супернова",
    "Затмение",
    "Сингулярность",
    "Квазар",
    "Метеорит",
    "Ураган",
    "Торнадо",
    "Цунами",
    "Лавина",
    "Извержение",
    "Гейзер",
    "Молния",
}

function Names.New(randomInt, existingEntries)
    local self = {randomInt = randomInt or math.random, used = {}, cycle = 1, bag = {}}
    for _, entry in ipairs(existingEntries or {}) do self.used[entry.name] = true end
    return setmetatable(self, {__index = Names})
end

function Names:Next()
    while true do
        if #self.bag == 0 then
            for i, name in ipairs(pool) do
                self.bag[i] = self.cycle == 1 and name or (name .. ' · ' .. self.cycle)
            end
            for i = #self.bag, 2, -1 do
                local j = self.randomInt(i)
                self.bag[i], self.bag[j] = self.bag[j], self.bag[i]
            end
            self.cycle = self.cycle + 1
        end
        local name = table.remove(self.bag)
        if not self.used[name] then
            self.used[name] = true
            return name
        end
    end
end
