from pathlib import Path
from lupa import LuaRuntime
lua = LuaRuntime(unpack_returned_tuples=True)
g = lua.globals()
g.zo_strlower = lambda s: s.lower()
lua.execute('''
SLASH_COMMANDS = {}
messages = {}
function d(text) table.insert(messages, text) end
function zo_strformat(_, text) return text end
local books = {
    {"Книга", true, 11}, {"Книга о море", true, 12},
    {"Записка", true, 13}, {"Записка", true, 14},
    {"Секрет", false, 15}, {"100% знаний", true, 16},
}
function GetLoreBookIndicesFromBookId(id)
    if id >= 11 and id <= 16 then return 1, 1, id - 10 end
end
function GetNumLoreCategories() return 1 end
function GetLoreCategoryInfo() return "Библиотека", 1 end
function GetLoreCollectionInfo() return "Сборник", "", 6, #books end
function GetLoreBookInfo(c, l, i)
    local b = books[i]
    return b[1], "icon", b[2], b[3]
end
function ReadLoreBook(c, l, i) return "Текст " .. i, 1, true end
function GetLoreBookOverrideImageFromBookId(id) return "image" .. id end
LORE_READER = {Show = function(self, ...) opened = {...} end}
''')
source = Path(__file__).parents[1] / 'KanaReadBook.lua'
if source.exists():
    lua.execute(source.read_text())
assert g.SLASH_COMMANDS['/readbook'] is not None, '/readbook is not registered'

def run(query):
    lua.execute('opened = nil; messages = {}')
    g.SLASH_COMMANDS['/readbook'](query)
    return g.opened, list(g.messages.values())

opened, _ = run('  КНИГА  ')
assert opened[1] == 'Книга' and opened[2] == 'Текст 1' and opened[5] == 'image11'
opened, _ = run('о море')
assert opened[1] == 'Книга о море'
opened, messages = run('Записка')
assert opened is None and any('#13' in m for m in messages) and any('#14' in m for m in messages)
opened, _ = run('#14')
assert opened[2] == 'Текст 4'
for query in ('Секрет', '#15', '#999', 'Нет такой книги', '', '  '):
    opened, messages = run(query)
    assert opened is None and messages, query
opened, _ = run('100%')
assert opened[1] == '100% знаний'
opened, _ = run('"Книга"')
assert opened[1] == 'Книга'
print('PASS: exact/partial title, Cyrillic case, whitespace/quotes, duplicates, ID, unknown/unlearned books, empty input, literal pattern characters')

# A real ESO result: collection has totalBooks=0 but direct book lookup works.
lua.execute('''
local original = GetLoreCollectionInfo
function GetLoreCollectionInfo(c, l) return "", "", 0, 0, true end
function GetLoreBookIndicesFromBookId(id)
    if id >= 11 and id <= 16 then return 1, 1, id - 10 end
end
''')
opened, _ = run('#14')
assert opened is not None and opened[2] == 'Текст 4', 'ID must work when collection count is hidden'
lua.execute('''
function LoreBooks_GetNewLoreCollectionInfo(c, l) return "Сборник", "", 5, 6, false end
''')
opened, _ = run('"Книга о море"')
assert opened is not None and opened[2] == 'Текст 2', 'Title must use LoreBooks count for hidden collection'
for query in ('Секрет', '#15', '#999'):
    opened, messages = run(query)
    assert opened is None and messages, query
print('PASS: hidden collection count, direct ID without LoreBooks, title with LoreBooks fallback, unknown/unlearned exclusions')
