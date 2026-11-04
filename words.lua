-- Word lists for Draw & Guess, one file per language (words_<lang>.lua: an
-- array of categories, each with e=easy, m=medium, h=hard word arrays).
--
-- Words.fr / Words.en read their file on first access, not with the module,
-- and only one language is kept at a time (reading one drops the other).
-- Words.release() (the screen closing) drops it: it is quick to read again
-- and only needed while a game is open.

local _dir = debug.getinfo(1, "S").source:sub(2):match("(.*[/\\])") or "./"

local Words = {}

local api = {
    LANGUAGES = { "fr", "en" },
}
local IS_LANG = { fr = true, en = true }

-- Drops the loaded word list (called when the game screen closes).
function api.release()
    for lang in pairs(IS_LANG) do rawset(Words, lang, nil) end
end

-- The languages whose word list is loaded now (for the specs).
function api.loadedLanguages()
    local out = {}
    for _i, lang in ipairs(api.LANGUAGES) do
        if rawget(Words, lang) then out[#out + 1] = lang end
    end
    table.sort(out)
    return out
end

setmetatable(Words, {
    __index = function(t, key)
        if IS_LANG[key] then
            local list = assert(loadfile(_dir .. "words_" .. key .. ".lua"))()
            api.release()
            rawset(t, key, list)
            return list
        end
        return api[key]
    end,
})

return Words
