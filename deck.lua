-- Word draws for Draw & Guess.
--
-- The pool is what the current Language / Category / Difficulty settings
-- allow; draws go through the shared SeenHistory (one history per language),
-- so a word does not come back before every other word of that pool has been
-- drawn -- within a game and across games. Once the pool is used up, only its
-- words are forgotten: words seen under another category or difficulty stay
-- remembered.

local SeenHistory = require("seen_history")

local Deck = {}

-- Every word list of every language holds at most ~3000 words.
Deck.HISTORY_MAX = 3000

-- Pool of { word, cat } entries. A word listed in two categories ("Requin"
-- in both Animaux and Océan) is kept once, under its first category.
function Deck.buildPool(words, lang, category, difficulty)
    local lang_list = words[lang] or words.fr
    local diffs = (difficulty == nil or difficulty == "mixed") and { "e", "m", "h" }
        or { difficulty:sub(1, 1) }
    local pool, seen = {}, {}
    for _, cat in ipairs(lang_list) do
        if category == nil or category == "all" or cat.id == category then
            for _, d in ipairs(diffs) do
                for _, w in ipairs(cat.words[d] or {}) do
                    if not seen[w] then
                        seen[w] = true
                        pool[#pool + 1] = { word = w, cat = cat.name }
                    end
                end
            end
        end
    end
    return pool
end

function Deck.history(plugin, lang)
    return SeenHistory.open(plugin, "words_" .. lang, { max = Deck.HISTORY_MAX })
end

-- One entry of the current pool, preferring words not drawn yet.
function Deck.pick(plugin, words, lang, category, difficulty)
    local pool = Deck.buildPool(words, lang, category, difficulty)
    if #pool == 0 then return { word = "???", cat = "???" } end
    return Deck.history(plugin, lang):pick(pool) or pool[1]
end

return Deck
