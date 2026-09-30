-- screen.lua picks a category, then a difficulty bucket (e/m/h), then a random
-- word out of that bucket. A missing or empty bucket therefore does not fail at
-- load time -- it fails when a team happens to draw that category, in the middle
-- of a round. These tests read the whole list instead.
local DIR = debug.getinfo(1, "S").source:sub(2):match("(.*[/\\])") or "./"

package.path = DIR .. "?.lua;" .. package.path

describe("pictionary word list", function()
    local words

    setup(function()
        words = require("words")
    end)

    it("offers at least one language, each an array of categories", function()
        local languages = 0
        for lang, categories in pairs(words) do
            assert.is_string(lang)
            assert.is_table(categories)
            assert.is_true(#categories > 0, lang .. " has no category")
            languages = languages + 1
        end
        assert.is_true(languages > 0)
    end)

    it("gives every category an id, a name and the three buckets", function()
        for lang, categories in pairs(words) do
            for i, cat in ipairs(categories) do
                local where = lang .. " #" .. i
                assert.is_string(cat.id, where .. " has no id")
                assert.is_string(cat.name, where .. " has no name")
                assert.is_true(#cat.id > 0, where .. " has an empty id")
                assert.is_true(#cat.name > 0, where .. " has an empty name")
                assert.is_table(cat.words, where .. " has no word table")
                for _, bucket in ipairs({ "e", "m", "h" }) do
                    assert.is_table(cat.words[bucket],
                        where .. " (" .. cat.id .. ") has no '" .. bucket .. "' bucket")
                end
            end
        end
    end)

    it("leaves no difficulty bucket empty", function()
        -- "mixed" draws from all three, but a single-difficulty game draws from
        -- one: an empty bucket is a dead end for that setting alone.
        for lang, categories in pairs(words) do
            for _, cat in ipairs(categories) do
                for _, bucket in ipairs({ "e", "m", "h" }) do
                    assert.is_true(#cat.words[bucket] > 0,
                        lang .. "/" .. cat.id .. " bucket '" .. bucket .. "' is empty")
                end
            end
        end
    end)

    it("holds nothing but non-empty strings", function()
        for lang, categories in pairs(words) do
            for _, cat in ipairs(categories) do
                for _, bucket in ipairs({ "e", "m", "h" }) do
                    local list = cat.words[bucket]
                    local counted = 0
                    for _ in pairs(list) do counted = counted + 1 end
                    assert.are.equal(counted, #list,
                        lang .. "/" .. cat.id .. "/" .. bucket .. " has a hole")
                    for j, w in ipairs(list) do
                        local where = lang .. "/" .. cat.id .. "/" .. bucket .. " #" .. j
                        assert.is_string(w, where .. " is not a string")
                        assert.is_true(#w > 0, where .. " is empty")
                        assert.is_nil(w:find("^%s"), where .. " starts with a space: " .. w)
                        assert.is_nil(w:find("%s$"), where .. " ends with a space: " .. w)
                    end
                end
            end
        end
    end)

    it("gives every category a distinct id", function()
        for lang, categories in pairs(words) do
            local seen = {}
            for i, cat in ipairs(categories) do
                assert.is_nil(seen[cat.id],
                    lang .. " #" .. i .. " reuses the id " .. cat.id)
                seen[cat.id] = true
            end
        end
    end)

    it("never lists a word twice within one category", function()
        -- Categories overlap on purpose -- "Shark" belongs to both ocean and
        -- animals, and a player who picks either should get it. What is a real
        -- defect is the same word inside one category: it would be drawn at two
        -- different difficulties, or eat two slots of the same bucket.
        for lang, categories in pairs(words) do
            for _, cat in ipairs(categories) do
                local seen = {}
                for _, bucket in ipairs({ "e", "m", "h" }) do
                    for _, w in ipairs(cat.words[bucket]) do
                        local k = w:lower()
                        assert.is_nil(seen[k], lang .. "/" .. cat.id .. ": " .. w
                            .. " is in bucket '" .. bucket .. "' and already in '"
                            .. tostring(seen[k]) .. "'")
                        seen[k] = bucket
                    end
                end
            end
        end
    end)
end)
