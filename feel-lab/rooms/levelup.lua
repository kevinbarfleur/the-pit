-- feel-lab/rooms/levelup.lua
-- ATELIER LEVEL-UP / FUSION — le « ta-ta-ta-TAAA ». Arène board/banc/shop pour montrer la CONVERGENCE depuis
-- les 3 origines (plateau, banc, et carte BOUTIQUE avec aspiration), un sélecteur de STYLE (3 propositions
-- comparables) et 4 scénarios. Réutilise lib/levelup (moteur), lib/particles, lib/juice (shake global via main),
-- lib/sfx (échelle montante grimdark). Géométrie inspirée du vrai jeu (board centré / banc / shop en bas).

local Draw    = require("src.ui.draw")
local Theme   = require("src.ui.theme")
local Button  = require("src.ui.button")
local Slot    = require("src.ui.slot")
local Feel    = require("lib.feel")
local B       = require("lib.behavior")
local Juice   = require("lib.juice")
local P       = require("lib.particles")
local LU      = require("lib.levelup")

local Room = {}
Room.__index = Room
local c = Theme.c
local W, H = 1280, 720
local MONCOL = c.rot   -- un « brood sac » violet (créature canon)

local function rrect(x, y, w, h, r, fill, border, bw)
  if fill then Draw.setColor(fill); love.graphics.rectangle("fill", x, y, w, h, r, r) end
  if border then
    Draw.setColor(border)
    love.graphics.setLineWidth(bw or 2)
    love.graphics.rectangle("line", x, y, w, h, r, r)
    love.graphics.setLineWidth(1)
  end
end

-- géométrie (espace design)
local boardCX = { 548, 640, 732 }
local boardCY = { 248, 340, 432 }
local benchCX = { 520, 600, 680, 760 }
local benchCY = 506
local shopCX  = { 400, 520, 640, 760, 880 }
local shopCY  = 604

local STYLES = {
  { id = "burst", name = "Burst", note = "Convergence + Burst — le plus sûr : âmes en arc staggerées, gros burst final." },
  { id = "orbit", name = "Orbit", note = "Orbite + Implosion — grimdark : la spirale se resserre puis implose en un beat." },
  { id = "slam",  name = "Slam",  note = "Stagger Slam — le plus punchy : micro-hitstop à chaque arrivée. TA. TA. TA." },
}

function Room.new(app)
  local self = setmetatable({ app = app, mx = -1, my = -1, click = nil, t = 0,
    style = "burst", anim = LU.new(), survivor = { x = boardCX[2], y = boardCY[2] }, targetLevel = 1 }, Room)
  return self
end
function Room:enter() self.title = "Level-Up / Fusion" end

function Room:update(dt)
  self.t = self.t + (dt or 0)
  local ts = Juice.timeScale()      -- gèle l'anim pendant le hitstop (le « TAAA » tient)
  self.anim:update((dt or 0) * ts)
  P.update((dt or 0) * ts)
  for _, s in ipairs(STYLES) do
    Feel.hover("lu.style." .. s.id, B.hit(self:styleRect(s.id), self.mx, self.my))
  end
  for _, s in ipairs({ "board3", "bench", "shop", "cascade" }) do
    Feel.hover("lu.scenario." .. s, B.hit(self:scenarioRect(s), self.mx, self.my))
  end
end

function Room:input(r)
  return { over = B.hit(r, self.mx, self.my), down = false,
           clicked = self.click and B.hit(r, self.click.x, self.click.y) or false }
end

function Room:styleRect(id)
  for i, s in ipairs(STYLES) do
    if s.id == id then return { x = 40 + (i - 1) * 168, y = 106, w = 156, h = 40 } end
  end
  return { x = 0, y = 0, w = 0, h = 0 }
end

function Room:scenarioRect(id)
  local scen = { board3 = 1, bench = 2, shop = 3, cascade = 4 }
  local i = scen[id] or 1
  local bw, gap = 224, 16
  local sx = W / 2 - (bw * 4 + gap * 3) / 2
  return { x = sx + (i - 1) * (bw + gap), y = 158, w = bw, h = 42 }
end

-- lance un scénario (arrange les copies + déclenche la fusion)
function Room:scenario(name)
  P.clear()
  self.targetLevel = 1
  self.replay = name
  local sv = { x = boardCX[2], y = boardCY[2] }
  self.survivor = sv
  local function play(sources, toLevel, big)
    self.anim:play({ sources = sources, target = sv, color = MONCOL, toLevel = toLevel,
      style = self.style, big = big, onLevel = function(lv) self.targetLevel = lv end })
  end
  if name == "board3" then
    play({ { x = boardCX[1], y = boardCY[2], kind = "board" }, { x = boardCX[3], y = boardCY[2], kind = "board" } }, 2, false)
  elseif name == "bench" then
    play({ { x = boardCX[1], y = boardCY[2], kind = "board" }, { x = benchCX[1], y = benchCY, kind = "bench" } }, 2, false)
  elseif name == "shop" then
    play({ { x = boardCX[1], y = boardCY[2], kind = "board" }, { x = shopCX[1], y = shopCY, kind = "shop" } }, 2, false)
  elseif name == "cascade" then
    play({ { x = boardCX[1], y = boardCY[1], kind = "board" }, { x = boardCX[3], y = boardCY[1], kind = "board" } }, 2, false)
    play({ { x = boardCX[1], y = boardCY[3], kind = "board" }, { x = boardCX[3], y = boardCY[3], kind = "board" } }, 3, true) -- escalade
  end
end

-- ── rendu d'un jeton-monstre ────────────────────────────────────────────────────────────────────────────
local function gem(x, y, level, scale, glow, dim)
  scale = scale or 1
  love.graphics.push(); love.graphics.translate(x, y); love.graphics.scale(scale, scale); love.graphics.translate(-x, -y)
  if glow and glow > 0.01 then
    love.graphics.setBlendMode("add")
    love.graphics.setColor(c.gold[1], c.gold[2], c.gold[3], 0.35 * glow)
    love.graphics.circle("fill", x, y, 34)
    love.graphics.setBlendMode("alpha")
  end
  rrect(x - 30, y - 30, 60, 60, 8, c.stone800, (glow and glow > 0.3) and c.brassS or c.brass, 2)
  local a = dim and 0.5 or 1
  love.graphics.setColor(MONCOL[1], MONCOL[2], MONCOL[3], a)
  love.graphics.circle("fill", x, y, 17)
  love.graphics.setColor(1, 1, 1, 0.22 * a)
  love.graphics.circle("fill", x - 5, y - 6, 5)
  if level then
    Draw.textC("LV" .. level, x, y + 19, c.gold, Theme.label(11))
  end
  love.graphics.pop()
  Draw.reset()
end

local function slotPanel(x, y, s)
  Slot.draw(x - s / 2, y - s / 2, s, "empty", {})
end

function Room:draw(view)
  Draw.begin(view)

  -- ── contrôles ──────────────────────────────────────────────────────────────────────────────────────────
  Draw.textTrackedL("STYLE", 40, 88, c.ink4, Theme.label(11), 2)
  for i, s in ipairs(STYLES) do
    local r = self:styleRect(s.id)
    local sel = (self.style == s.id)
    Button.draw(r.x, r.y, r.w, r.h, sel and "primary" or "secondary", s.name, {
      hover = B.hit(r, self.mx, self.my), feel = Feel.state("lu.style." .. s.id), id = "lu.style." .. s.id,
    })
  end
  -- note du style courant
  for _, s in ipairs(STYLES) do if s.id == self.style then Draw.textR(s.note, W - 40, 116, c.ink3, Theme.flavor(13)) end end

  -- scénarios
  local scen = {
    { "board3", "3 on board" }, { "bench", "Board + Bench" }, { "shop", "From Shop" }, { "cascade", "Cascade 1->3" },
  }
  for i, s in ipairs(scen) do
    local r = self:scenarioRect(s[1])
    Button.draw(r.x, r.y, r.w, r.h, "secondary", s[2], {
      hover = B.hit(r, self.mx, self.my), feel = Feel.state("lu.scenario." .. s[1]), id = "lu.scenario." .. s[1],
    })
  end
  Draw.divider(W / 2, 214, W - 100, c.brass, 0.5)

  -- ── arène (board / bench / shop) ───────────────────────────────────────────────────────────────────────
  Draw.textTrackedL("BOARD", boardCX[1] - 96, boardCY[2] - 6, c.ink5, Theme.label(10), 2)
  Draw.textTrackedL("BENCH", benchCX[1] - 96, benchCY - 6, c.ink5, Theme.label(10), 2)
  Draw.textTrackedL("SHOP",  shopCX[1] - 96, shopCY - 6, c.ink5, Theme.label(10), 2)
  for r = 1, 3 do for col = 1, 3 do slotPanel(boardCX[col], boardCY[r], 80) end end
  for i = 1, 4 do slotPanel(benchCX[i], benchCY, 64) end
  for i = 1, 5 do
    rrect(shopCX[i] - 54, shopCY - 48, 108, 96, 7, { c.stone850[1], c.stone850[2], c.stone850[3], 0.7 }, c.brassD, 2)
  end

  -- sources courantes (copies pas encore aspirées ; carte shop qui réagit)
  local srcs = self.anim.sources and self.anim:sources()
  if srcs then
    for i, s in ipairs(srcs) do
      if s.visible then
        local sc = 1 + (s.asp or 0) * 0.28          -- aspiration de la carte shop
        gem(s.x, s.y, 1, sc, (s.asp or 0) * 0.6, false)
      end
    end
  end

  -- survivant (avec juice de la cible : anticipation/pulse/climax)
  gem(self.survivor.x, self.survivor.y, self.targetLevel, self.anim:targetScale(), self.anim:targetGlow(), false)

  -- âmes + flash, puis particules
  self.anim:draw()
  P.draw()

  if not self.anim:active() and self.t > 0.1 then
    Draw.textC("Pick a style, then a scenario. Watch the original level up.", W / 2, H - 60, c.ink5, Theme.flavor(14))
  end
  Draw.finish()
  self.click = nil
end

function Room:mousemoved(mx, my) self.mx, self.my = mx, my end
function Room:mousepressed(mx, my, button)
  self.mx, self.my = mx, my
  self.click = { x = mx, y = my }
  if button ~= 1 then return end
  for _, s in ipairs(STYLES) do
    if B.hit(self:styleRect(s.id), mx, my) then
      Feel.press("lu.style." .. s.id, function() self.style = s.id end, { delay = 0.08 })
      return
    end
  end
  for _, s in ipairs({ "board3", "bench", "shop", "cascade" }) do
    if B.hit(self:scenarioRect(s), mx, my) then
      Feel.press("lu.scenario." .. s, function() self:scenario(s) end, { delay = 0.08 })
      return
    end
  end
end

return Room
