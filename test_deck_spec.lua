-- Word draws go through the shared SeenHistory: no word comes back before
-- the whole pool (current category/difficulty) has been drawn, within a game
-- and across games (the history lives in the plugin settings).
local DIR = debug.getinfo(1, "S").source:sub(2):match("(.*[/\\])") or "./"
package.path = DIR .. "?.lua;" .. DIR .. "common/?.lua;" .. package.path

local function fakePlugin(store)
    store = store or {}
    return {
        store = store,
        getSetting  = function(_self, k, d) if store[k] == nil then return d end return store[k] end,
        saveSetting = function(_self, k, v) store[k] = v end,
    }
end

describe("pictionary deck", function()
    local Words, Deck

    setup(function()
        Words = require("words")
        Deck  = require("deck")
    end)

    it("builds the pool of the current category and difficulty", function()
        local pool = Deck.buildPool(Words, "fr", "animaux", "easy")
        assert.are.equal(#Words.fr[1].words.e, #pool)
        for _, e in ipairs(pool) do assert.are.equal("Animaux", e.cat) end
        local mixed = Deck.buildPool(Words, "en", "animals", "mixed")
        assert.are.equal(120, #mixed)
    end)

    it("lists each word once in the 'all categories' pool", function()
        for _, lang in ipairs({ "fr", "en" }) do
            local seen = {}
            for _, e in ipairs(Deck.buildPool(Words, lang, "all", "mixed")) do
                assert.is_nil(seen[e.word], lang .. ": " .. e.word .. " twice in the pool")
                seen[e.word] = true
            end
        end
    end)

    it("never repeats a word before the whole pool is drawn, across two sessions", function()
        local store = {}
        local pool_size = #Deck.buildPool(Words, "fr", "animaux", "easy")
        local drawn = {}
        -- session 1: a 20-word game
        local p1 = fakePlugin(store)
        for _ = 1, 20 do
            local w = Deck.pick(p1, Words, "fr", "animaux", "easy").word
            assert.is_nil(drawn[w], w .. " came back in session 1")
            drawn[w] = true
        end
        -- session 2: a new plugin instance reading the same settings
        local p2 = fakePlugin(store)
        for _ = 21, pool_size do
            local w = Deck.pick(p2, Words, "fr", "animaux", "easy").word
            assert.is_nil(drawn[w], w .. " came back in session 2")
            drawn[w] = true
        end
        -- pool used up: the next draw starts a new cycle instead of failing
        assert.is_string(Deck.pick(p2, Words, "fr", "animaux", "easy").word)
    end)

    it("keeps the history of other pools when one is used up", function()
        local p = fakePlugin()
        local other = Deck.pick(p, Words, "fr", "sports", "hard").word
        local n = #Deck.buildPool(Words, "fr", "animaux", "easy")
        for _ = 1, n + 1 do Deck.pick(p, Words, "fr", "animaux", "easy") end
        assert.is_true(Deck.history(p, "fr"):has(other))
    end)

    it("keeps one history per language", function()
        local store = {}
        Deck.pick(fakePlugin(store), Words, "fr", "all", "mixed")
        Deck.pick(fakePlugin(store), Words, "en", "all", "mixed")
        assert.are.equal(1, #store.seen_words_fr)
        assert.are.equal(1, #store.seen_words_en)
    end)
end)
