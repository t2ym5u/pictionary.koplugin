local _dir = debug.getinfo(1, "S").source:sub(2):match("(.*[/\\])") or "./"
local function lrequire(name)
    local key = _dir .. name
    if not package.loaded[key] then
        package.loaded[key] = assert(loadfile(_dir .. name .. ".lua"))()
    end
    return package.loaded[key]
end

local Device          = require("device")
local Font            = require("ui/font")
local HorizontalGroup = require("ui/widget/horizontalgroup")
local HorizontalSpan  = require("ui/widget/horizontalspan")
local RenderText      = require("ui/rendertext")
local Size            = require("ui/size")
local TextBoxWidget   = require("ui/widget/textboxwidget")
local TextWidget      = require("ui/widget/textwidget")
local UIManager       = require("ui/uimanager")
local VerticalGroup   = require("ui/widget/verticalgroup")
local VerticalSpan    = require("ui/widget/verticalspan")
local _               = require("i18n")
local T               = require("ffi/util").template

local MenuHelper  = require("menu_helper")
local ScreenBase  = require("screen_base")
local Words       = lrequire("words")

local DeviceScreen = Device.screen

-- ---------------------------------------------------------------------------
-- Text sizing helpers
--
-- Font:getFace() scales its size by the screen DPI, so a size worked out from
-- pixel dimensions has to be divided back first, or every line comes out
-- about twice too big on a 300 dpi reader and runs off the screen edges.
-- ---------------------------------------------------------------------------

local DPI_SCALE = DeviceScreen:scaleBySize(1000) / 1000

local function pxFace(px)
    return Font:getFace("cfont", math.max(8, math.floor(px / DPI_SCALE)))
end

-- One line of text at up to `px` pixels, shrunk until it fits `max_w`.
local function fitLine(text, px, max_w)
    local face = pxFace(px)
    while px > 12 do
        local m = RenderText:sizeUtf8Text(0, max_w * 10, face, text, true, false)
        if m.x <= max_w then break end
        px   = math.floor(px * 0.9)
        face = pxFace(px)
    end
    return TextWidget:new{ text = text, face = face, max_width = max_w }
end

-- A paragraph wrapped to `width`, centred.
local function wrapText(text, face, width)
    return TextBoxWidget:new{ text = text, face = face, width = width, alignment = "center" }
end

local DEFAULT_NB_TEAMS = 2
local DEFAULT_DURATION  = 60
local DEFAULT_DIFF      = "mixed"
local DEFAULT_CAT       = "all"

local GAME_RULES_EN = _([[
Pictionary Party — Rules

Teams take turns. The current team's drawer receives the device, sees the word privately, then draws it on paper while teammates guess.

• Timer runs during drawing.
• No speaking, no gestures beyond drawing.
• ✓ Got it! = +1 point for the team.
• ✗ Missed = 0 points, next team plays.

First team to reach the agreed score wins!
]])

local GAME_RULES_FR = [[
Pictionary Party — Règles

Les équipes jouent à tour de rôle. Le dessinateur reçoit l'appareil, voit le mot en secret, puis le dessine sur papier pendant que ses coéquipiers devinent.

• Le minuteur tourne pendant le dessin.
• Pas de parole, pas de geste autre que le dessin.
• ✓ Trouvé ! = +1 point pour l'équipe.
• ✗ Raté = 0 point, à l'équipe suivante.

La première équipe au score convenu gagne !
]]

-- ---------------------------------------------------------------------------
-- PictionaryScreen
-- ---------------------------------------------------------------------------

local PictionaryScreen = ScreenBase:extend{}

function PictionaryScreen:init()
    self.lang       = self.plugin:getSetting("lang", "fr")
    self.duration   = self.plugin:getSetting("duration", DEFAULT_DURATION)
    self.difficulty = self.plugin:getSetting("difficulty", DEFAULT_DIFF)
    self.category   = self.plugin:getSetting("category", DEFAULT_CAT)
    local nb        = self.plugin:getSetting("nb_teams", DEFAULT_NB_TEAMS)

    self.teams = {}
    for i = 1, nb do
        self.teams[i] = {
            name  = self.plugin:getSetting("team_name_" .. i, T(_("Team %1"), i)),
            score = 0,
        }
    end
    self.current_team   = 1
    self.phase          = "ready"
    self.current_word   = ""
    self.time_remaining = self.duration

    ScreenBase.init(self)
end

-- ---------------------------------------------------------------------------
-- Word picking
-- ---------------------------------------------------------------------------

function PictionaryScreen:_pickWord()
    local lang_list = Words[self.lang] or Words.fr
    local pool = {}
    local diffs = self.difficulty == "mixed" and { "e", "m", "h" } or { self.difficulty:sub(1,1) }

    for _, cat in ipairs(lang_list) do
        if self.category == "all" or cat.id == self.category then
            for _, d in ipairs(diffs) do
                local wlist = cat.words[d]
                if wlist then
                    for _, w in ipairs(wlist) do
                        pool[#pool + 1] = { word = w, cat = cat.name }
                    end
                end
            end
        end
    end

    if #pool == 0 then
        return { word = "???", cat = "???" }
    end
    return pool[math.random(#pool)]
end

-- ---------------------------------------------------------------------------
-- Timer
-- ---------------------------------------------------------------------------

function PictionaryScreen:_startCountdown()
    self._tick_gen = (self._tick_gen or 0) + 1
    local gen = self._tick_gen
    UIManager:scheduleIn(1, function() self:_onTick(gen) end)
end

function PictionaryScreen:_stopCountdown()
    self._tick_gen = (self._tick_gen or 0) + 1
end

function PictionaryScreen:_onTick(gen)
    if gen ~= self._tick_gen then return end
    self.time_remaining = math.max(0, self.time_remaining - 1)
    if self.timer_widget then
        self.timer_widget:setText(self:_timerText())
        UIManager:setDirty(self, function() return "fast", self.dimen end)
    end
    if self.time_remaining > 0 then
        UIManager:scheduleIn(1, function() self:_onTick(gen) end)
    end
    -- At zero: timer stops, [✓]/[✗] buttons remain for manual resolution
end

function PictionaryScreen:_timerText()
    local m = math.floor(self.time_remaining / 60)
    local s = self.time_remaining % 60
    return string.format("%d:%02d", m, s)
end

-- ---------------------------------------------------------------------------
-- Actions
-- ---------------------------------------------------------------------------

function PictionaryScreen:onReveal()
    local entry         = self:_pickWord()
    self.current_word   = entry.word
    self.current_cat    = entry.cat
    self.time_remaining = self.duration
    self.phase          = "drawing"
    self:buildLayout()
    UIManager:setDirty(self, function() return "ui", self.dimen end)
    self:_startCountdown()
end

function PictionaryScreen:onResult(found)
    self:_stopCountdown()
    if found then
        self.teams[self.current_team].score = self.teams[self.current_team].score + 1
    end
    self.current_team = (self.current_team % #self.teams) + 1
    self.phase        = "ready"
    self:buildLayout()
    UIManager:setDirty(self, function() return "ui", self.dimen end)
end

-- New game: scores back to zero, first team to play.
function PictionaryScreen:onNewGame()
    self:_stopCountdown()
    for _i, t in ipairs(self.teams) do t.score = 0 end
    self.current_team = 1
    self.phase        = "ready"
    self:buildLayout()
    UIManager:setDirty(self, function() return "ui", self.dimen end)
end

-- ---------------------------------------------------------------------------
-- Settings menus
-- ---------------------------------------------------------------------------

function PictionaryScreen:_durationLabel(dur)
    return string.format("%d:%02d", math.floor(dur / 60), dur % 60)
end

function PictionaryScreen:openLangMenu()
    MenuHelper.openPickerMenu{
        title      = _("Language"),
        items      = { { id = "fr", text = "Français" }, { id = "en", text = "English" } },
        current_id = self.lang,
        parent     = self,
        on_select  = function(lang)
            self.lang = lang
            self.plugin:saveSetting("lang", lang)
            self:buildLayout()
            UIManager:setDirty(self, function() return "ui", self.dimen end)
        end,
    }
end

function PictionaryScreen:openTeamsMenu()
    local items = {}
    for n = 2, 6 do
        items[#items + 1] = { id = n, text = T(_("%1 teams"), n) }
    end
    MenuHelper.openPickerMenu{
        title      = _("Teams"),
        items      = items,
        current_id = #self.teams,
        parent     = self,
        on_select  = function(n)
            local old = #self.teams
            self.plugin:saveSetting("nb_teams", n)
            while #self.teams < n do
                local i = #self.teams + 1
                self.teams[i] = { name = T(_("Team %1"), i), score = 0 }
            end
            while #self.teams > n do
                table.remove(self.teams)
            end
            if self.current_team > #self.teams then self.current_team = 1 end
            self:buildLayout()
            UIManager:setDirty(self, function() return "ui", self.dimen end)
        end,
    }
end

function PictionaryScreen:openDurationMenu()
    local items = {}
    for _i, d in ipairs({ 45, 60, 90, 120 }) do
        items[#items + 1] = { id = d, text = self:_durationLabel(d) }
    end
    MenuHelper.openPickerMenu{
        title      = _("Timer"),
        items      = items,
        current_id = self.duration,
        parent     = self,
        on_select  = function(dur)
            self.duration = dur
            self.plugin:saveSetting("duration", dur)
        end,
    }
end

function PictionaryScreen:openCategoryMenu()
    local lang_list = Words[self.lang] or Words.fr
    local items   = { { id = "all", text = _("All categories") } }
    for _i, cat in ipairs(lang_list) do
        items[#items + 1] = { id = cat.id, text = cat.name }
    end
    MenuHelper.openPickerMenu{
        title      = _("Category"),
        items      = items,
        current_id = self.category,
        parent     = self,
        on_select  = function(cat)
            self.category = cat
            self.plugin:saveSetting("category", cat)
        end,
    }
end

function PictionaryScreen:openDifficultyMenu()
    local items = {}
    for _i, id in ipairs({ "mixed", "e", "m", "h" }) do
        items[#items + 1] = { id = id, text = self:_diffLabel(id) }
    end
    MenuHelper.openPickerMenu{
        title      = _("Difficulty"),
        items      = items,
        current_id = self.difficulty,
        parent     = self,
        on_select  = function(diff)
            self.difficulty = diff
            self.plugin:saveSetting("difficulty", diff)
        end,
    }
end

-- ---------------------------------------------------------------------------
-- Layout
-- ---------------------------------------------------------------------------

function PictionaryScreen:buildLayout()
    if self.phase == "ready" then
        self:_buildReadyLayout()
    else
        self:_buildDrawingLayout()
    end
    self[1] = self.layout
    self:updateStatus()
end

function PictionaryScreen:_titleBar()
    return self:buildTitleBar(_("Pictionary Party"), function()
        return {
            { text = _("New game"), callback = function() self:onNewGame() end },
            { text = T(_("Difficulty: %1"), self:_diffLabel()), callback = function() self:openDifficultyMenu() end },
            { text = T(_("Language: %1"), self.lang:upper()),   callback = function() self:openLangMenu() end },
            { text = T(_("Teams: %1"), #self.teams),            callback = function() self:openTeamsMenu() end },
            { text = T(_("Timer: %1"), self:_durationLabel(self.duration)),
              callback = function() self:openDurationMenu() end },
            { text = self.category == "all" and _("Category: All") or T(_("Category: %1"), self:_catLabel()),
              callback = function() self:openCategoryMenu() end },
            self:makeRulesButtonConfig(GAME_RULES_EN, GAME_RULES_FR),
        }
    end)
end

function PictionaryScreen:_buildReadyLayout()
    local team  = self.teams[self.current_team]

    local title_bar = self:_titleBar()
    local controls  = self:_buildControls({
        { text = _("Show the word"), callback = function() self:onReveal() end },
    })
    local bw, bh = self:getBoardBudget(title_bar, controls)
    local short  = math.min(bw, bh)
    local vs     = Size.span.vertical_large

    self.timer_widget = nil
    local content = VerticalGroup:new{
        align = "center",
        -- Team name (large)
        fitLine(team.name:upper(), short * 0.14, bw),
        VerticalSpan:new{ width = vs },
        -- Category / difficulty hint
        TextWidget:new{
            text      = self:joinStatus(self:_catLabel(), self:_diffLabel()),
            face      = Font:getFace("smallinfofont"),
            max_width = bw,
        },
        VerticalSpan:new{ width = vs * 4 },
        -- Instruction, wrapped: in French it is wider than a phone screen.
        wrapText(_("Pass the device to the drawer"),
            pxFace(short * 0.06), bw),
    }
    self:_placeLayout(title_bar, content, controls)
end

function PictionaryScreen:_buildDrawingLayout()
    local team  = self.teams[self.current_team]

    local title_bar = self:_titleBar()
    local controls  = self:_buildControls({
        { text = "✓  " .. _("Got it!"),
          callback = function() self:onResult(true) end },
        { text = "✗  " .. _("Missed"),
          callback = function() self:onResult(false) end },
    })
    local bw, bh = self:getBoardBudget(title_bar, controls)
    local short  = math.min(bw, bh)
    local vs3    = Size.span.vertical_large * 3

    -- Timer
    self.timer_widget = TextWidget:new{
        text = self:_timerText(),
        face = pxFace(short * 0.16),
    }

    local content = VerticalGroup:new{
        align = "center",
        -- Team indicator
        TextWidget:new{ text = team.name, face = Font:getFace("smallinfofont"), max_width = bw },
        VerticalSpan:new{ width = vs3 },
        -- Word: as big as the width allows
        fitLine(self.current_word, short * 0.2, bw),
        VerticalSpan:new{ width = vs3 },
        self.timer_widget,
    }
    self:_placeLayout(title_bar, content, controls)
end

-- Status line + action bar, built before the content so the content can be
-- sized from what they leave over (getBoardBudget).
function PictionaryScreen:_buildControls(rows)
    self.status_text:setMaxWidth(self:getControlsWidth())
    return VerticalGroup:new{
        align = "center",
        self.status_text,
        VerticalSpan:new{ width = Size.span.vertical_large },
        self:buildActionBar(rows),
    }
end

function PictionaryScreen:_placeLayout(title_bar, content, controls)
    if self:isLandscape() then
        self:buildLandscapeLayout(title_bar, HorizontalGroup:new{
            align = "center",
            content,
            HorizontalSpan:new{ width = self:getGutter() },
            controls,
        })
    else
        self:buildPortraitLayout(title_bar, content,
            VerticalGroup:new{ align = "center", controls, VerticalSpan:new{ width = self:getGutter() } })
    end
end

-- "Team 1: 3 · Team 2: 1"
function PictionaryScreen:_scoreStatus(list)
    local parts = {}
    for _i, t in ipairs(list) do
        parts[#parts + 1] = T(_("%1: %2"), t.name, t.score)
    end
    return self:joinStatus((table.unpack or unpack)(parts))
end

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

function PictionaryScreen:_catLabel()
    if self.category == "all" then
        return _("All categories")
    end
    local lang_list = Words[self.lang] or Words.fr
    for _, cat in ipairs(lang_list) do
        if cat.id == self.category then return cat.name end
    end
    return self.category
end

function PictionaryScreen:_diffLabel(id)
    local labels = { mixed = _("Mixed"), e = _("Easy"), m = _("Medium"), h = _("Hard") }
    return labels[id or self.difficulty] or labels.mixed
end

function PictionaryScreen:updateStatus(msg)
    if msg then ScreenBase.updateStatus(self, msg); return end
    ScreenBase.updateStatus(self, self:_scoreStatus(self.teams))
end

function PictionaryScreen:onClose()
    self:_stopCountdown()
    ScreenBase.onClose(self)
end

return PictionaryScreen
