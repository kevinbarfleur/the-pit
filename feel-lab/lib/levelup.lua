-- feel-lab/lib/levelup.lua
-- MOTEUR D'ANIMATION DE LEVEL-UP / FUSION — le « ta-ta-ta-TAAA ». Multi-étapes, rythmé par le NOMBRE de
-- copies, avec cascade. RENDER pur (dt mural). S'appuie sur lib/particles (burst+anneau), lib/juice
-- (screen-shake trauma² + hitstop) et lib/sfx (échelle de pitch montante + impact final).
--
-- STRUCTURE (recherche §1) : anticipation -> convergence staggerée (ease-IN) -> impacts (« ta » par arrivée)
-- -> climax (« TAAA » : flash + onde de choc + burst + squash-stretch + shake + hitstop + pip pop) -> settle.
-- 3 STYLES comparables (recherche §propositions) :
--   "burst" — convergence en arc (Bézier) staggerée + gros burst final            (le plus sûr)
--   "orbit" — les âmes ORBITENT en spirale resserrée puis IMPLOSENT en un beat     (grimdark/vortex)
--   "slam"  — chaque arrivée a son micro-hitstop -> « TA. TA. TA. » très scandé     (le plus punchy)
--
-- spec = { sources = {{x,y,kind}...}, target = {x,y}, color = {r,g,b}, toLevel, style, big, onLevel(fn) }
--   sources.kind peut valoir "shop" -> la carte « s'aspire » (beat d'anticipation) avant que l'âme parte.
--   big = true -> climax PLEINE PUISSANCE (niveau 3 / cascade finale) : escalade façon TFT rank-up.
--
-- API : LU.new() · lu:play(spec) [enfile -> cascade] · lu:update(dt) · lu:draw() · lu:active()
--        · lu:targetScale() · lu:targetGlow() · lu:aspiration(i) [0..1 si la source i est une carte shop]

local P     = require("lib.particles")
local Juice = require("lib.juice")
local SFX   = require("lib.sfx")
local Theme = require("lib.theme")

local LU = {}
LU.__index = LU

-- timings (s)
local ANTICIP = 0.12
local CONV    = 0.30   -- vol d'une âme
local STAGGER = 0.13   -- espacement des départs (burst/slam)
local ORBIT   = 0.58   -- durée de la spirale (orbit)
local CLIMAX  = 0.42
local SETTLE  = 0.30
local ECHO_1  = 0.09
local ECHO_2  = 0.22
local GOLD = Theme.c.gold
local EMBER = Theme.c.ember
local BRASS = Theme.c.brassS

local function easeIn(e) return e * e end
local function easeOut(e) return 1 - (1 - e) * (1 - e) end
local function clamp01(v) return math.max(0, math.min(1, v or 0)) end
-- Bézier quadratique
local function bez(p0, c, p1, e)
  local u = 1 - e
  return u * u * p0 + 2 * u * e * c + e * e * p1
end

function LU.new()
  return setmetatable({ queue = {}, cur = nil, glow = 0, flash = 0, ts = 0, tsV = 0 }, LU)
end

function LU:active() return self.cur ~= nil or #self.queue > 0 end
function LU:targetScale() return 1 + self.ts end
function LU:targetGlow() return self.glow end

function LU:_start()
  local s = table.remove(self.queue, 1)
  if not s then self.cur = nil; return end
  local style = s.style or "burst"
  local tx, ty = s.target.x, s.target.y
  local souls = {}
  local n = #s.sources
  local climaxAt = ANTICIP
  local beats = {}
  for k, src in ipairs(s.sources) do
    local soul = { sx = src.x, sy = src.y, kind = src.kind }
    if style == "orbit" then
      soul.depart, soul.arrive = ANTICIP, ANTICIP + ORBIT
      soul.a0 = math.atan2(src.y - ty, src.x - tx)
      soul.r0 = math.sqrt((src.x - tx) ^ 2 + (src.y - ty) ^ 2)
    else
      -- shop : +un beat d'aspiration avant le départ
      local extra = (src.kind == "shop") and 0.10 or 0
      soul.depart = ANTICIP + (k - 1) * STAGGER + extra
      soul.arrive = soul.depart + CONV
      -- point de contrôle de l'arc : milieu décalé perpendiculairement (alterné) + vers le haut
      local mx, my = (src.x + tx) / 2, (src.y + ty) / 2
      local dx, dy = tx - src.x, ty - src.y
      local len = math.max(1, math.sqrt(dx * dx + dy * dy))
      local side = (k % 2 == 0) and 1 or -1
      soul.cx = mx + (-dy / len) * len * 0.18 * side
      soul.cy = my + (dx / len) * len * 0.18 * side - len * 0.10
    end
    if soul.arrive > climaxAt then climaxAt = soul.arrive end
    souls[k] = soul
  end
  -- beats rythmiques (« ta ») : pour burst/slam = à chaque arrivée ; pour orbit = N ticks réguliers
  if style == "orbit" then
    for j = 1, n do beats[j] = { t = ANTICIP + j * (ORBIT / n), fired = false } end
    climaxAt = ANTICIP + ORBIT
  else
    for k, soul in ipairs(souls) do beats[k] = { t = soul.arrive, fired = false } end
  end
  self.cur = {
    spec = s, style = style, t = 0, tx = tx, ty = ty, color = s.color or { 0.8, 0.7, 0.4 },
    souls = souls, beats = beats, climaxAt = climaxAt, climaxed = false,
    endAt = climaxAt + CLIMAX + SETTLE + 0.10, big = s.big, n = n,
  }
  SFX.ladder(true)  -- repart à la base de l'échelle pour la nouvelle montée
end

function LU:play(spec)
  self.queue[#self.queue + 1] = spec
  if not self.cur then self:_start() end
end

-- ressort de scale de la cible (anticipation -> pulses -> climax -> settle)
local function tspring(self, dt)
  local k, d = 360, 22
  local a = -k * self.ts - d * self.tsV
  self.tsV = self.tsV + a * dt
  self.ts = self.ts + self.tsV * dt
end
function LU:_pulse(amt) self.tsV = self.tsV + amt * 22 end  -- impulsion (amt<0 = creux d'anticipation)

local function climaxEcho(self, c, phase)
  if phase == 1 then
    self:_pulse(c.big and 0.18 or 0.13)
    self.glow = 1
    Juice.addTrauma(c.big and 0.32 or 0.20)
    SFX.ladder(false)
    SFX.play("pop", { vol = c.big and 0.9 or 0.7, pitch = c.big and 0.86 or 0.92 })
    P.explosion("levelup_echo", c.tx, c.ty)
  else
    self:_pulse(c.big and 0.24 or 0.17)
    self.flash = math.max(self.flash, c.big and 0.72 or 0.52)
    self.glow = 1
    Juice.addTrauma(c.big and 0.42 or 0.28)
    Juice.freeze(c.big and 0.055 or 0.035)
    SFX.play("thud", { vol = c.big and 0.78 or 0.62, pitch = c.big and 0.76 or 0.84 })
    P.explosion(c.big and "levelup_peak" or "levelup_echo", c.tx, c.ty)
  end
end

function LU:update(dt)
  if not dt or dt <= 0 then dt = 0 end
  tspring(self, dt)
  self.flash = self.flash * math.exp(-dt / 0.08)
  if self.flash < 0.003 then self.flash = 0 end
  local c = self.cur
  if not c then
    self.glow = self.glow * math.exp(-dt / 0.25)
    return
  end
  c.t = c.t + dt
  -- anticipation : un seul creux au tout début
  if not c._dip and c.t > 0.001 then c._dip = true; self:_pulse(-(c.big and 0.14 or 0.10)) end

  -- beats rythmiques (« ta ») : pitch montant + petit shake + pulse + spark
  for _, b in ipairs(c.beats) do
    if not b.fired and c.t >= b.t then
      b.fired = true
      SFX.ladder(false)
      Juice.addTrauma(c.style == "slam" and 0.18 or 0.10)
      if c.style == "slam" then Juice.freeze(0.04) end
      self:_pulse(0.05)
      self.glow = math.min(1, self.glow + 0.28)
      -- « ta » : micro seal, assez visible pour rythmer sans voler le climax.
      P.burst(c.tx, c.ty, { type = "rune", count = 3, speed = { 45, 120 }, life = { 0.20, 0.36 }, drag = 3, spin = 8 })
      P.burst(c.tx, c.ty, { type = "spark", count = 4, speed = { 80, 180 }, life = { 0.14, 0.28 }, drag = 3 })
    end
  end

  -- climax (« TAAA »)
  if not c.climaxed and c.t >= c.climaxAt then
    c.climaxed = true
    local big = c.big
    self.flash = big and 0.9 or 0.6
    self:_pulse(big and 0.34 or 0.24)
    self.glow = 1
    Juice.addTrauma(big and 0.85 or 0.55)
    Juice.freeze(big and 0.12 or 0.08)
    SFX.play("success")
    SFX.play("thud", { vol = 0.8 })
    -- Explosion canonique du lab: elle démarre déjà très gros, puis deux échos montent encore le payoff.
    P.explosion(big and "levelup_big" or "levelup", c.tx, c.ty)
    if c.spec.onLevel then c.spec.onLevel(c.spec.toLevel) end
  end

  if c.climaxed and not c.echo1 and c.t >= c.climaxAt + ECHO_1 then
    c.echo1 = true
    climaxEcho(self, c, 1)
  end
  if c.climaxed and not c.echo2 and c.t >= c.climaxAt + ECHO_2 then
    c.echo2 = true
    climaxEcho(self, c, 2)
  end

  if c.t >= c.endAt then self:_start() end  -- fin -> enchaîne la cascade (ou s'arrête)
end

-- position courante d'une âme (nil si pas encore partie ou déjà absorbée)
function LU:_soulPos(c, soul)
  if c.t < soul.depart or c.t > soul.arrive + 0.001 then return nil end
  local lt = (c.t - soul.depart) / (soul.arrive - soul.depart)
  if c.style == "orbit" then
    local p = easeIn(lt)
    local ang = soul.a0 + 1.3 * math.pi * 2 * lt
    local r = soul.r0 * (1 - p)
    return c.tx + math.cos(ang) * r, c.ty + math.sin(ang) * r, lt
  else
    local e = easeIn(lt)
    return bez(soul.sx, soul.cx, c.tx, e), bez(soul.sy, soul.cy, c.ty, e), lt
  end
end

local function drawClimaxFlash(x, y, a, t)
  a = clamp01(a)
  if a <= 0.01 then return end
  local px = 4
  local r = 18 + (1 - a) * 52
  local core = 10 + a * 10
  love.graphics.setBlendMode("add")
  love.graphics.setColor(1, 0.92, 0.68, a * 0.72)
  love.graphics.polygon("fill", x, y - core, x + core, y, x, y + core, x - core, y)
  love.graphics.setColor(GOLD[1], GOLD[2], GOLD[3], a * 0.58)
  for i = 0, 15 do
    local ang = i / 16 * math.pi * 2 + t * 0.45
    local len = r * (0.50 + 0.50 * ((i % 4 == 0) and 1 or 0.58))
    local steps = (i % 2 == 0) and 5 or 3
    for s = 1, steps do
      local k = s / steps
      local bx = math.floor((x + math.cos(ang) * len * k) / px + 0.5) * px
      local by = math.floor((y + math.sin(ang) * len * k) / px + 0.5) * px
      local sz = math.max(px, math.floor((px * (2.9 - k * 1.5)) + 0.5))
      love.graphics.rectangle("fill", bx - sz / 2, by - sz / 2, sz, sz)
    end
  end
  love.graphics.setColor(EMBER[1], EMBER[2], EMBER[3], a * 0.32)
  for i = 0, 7 do
    local ang = i / 8 * math.pi * 2 - t * 0.70
    local bx = math.floor((x + math.cos(ang) * r * 0.36) / px + 0.5) * px
    local by = math.floor((y + math.sin(ang) * r * 0.36) / px + 0.5) * px
    love.graphics.rectangle("fill", bx - px, by - px, px * 2, px * 2)
  end
  love.graphics.setBlendMode("alpha")
end

-- sources de la fusion EN COURS (pour que la room dessine les jetons-copies + l'aspiration de la carte shop).
-- visible = la copie est encore là (pas encore partie en âme) ; asp = 0..1 si carte shop en aspiration.
function LU:sources()
  local c = self.cur; if not c then return nil end
  local out = {}
  for i, s in ipairs(c.souls) do
    out[i] = { x = s.sx, y = s.sy, kind = s.kind, visible = c.t < s.depart, asp = self:aspiration(i) }
  end
  return out
end

-- 0..1 si la source i est une carte shop en cours d'aspiration (pour que la room fasse réagir la carte)
function LU:aspiration(i)
  local c = self.cur; if not c then return 0 end
  local soul = c.souls[i]; if not soul or soul.kind ~= "shop" then return 0 end
  if c.t >= soul.depart then return 0 end
  local start = soul.depart - 0.10
  if c.t < start then return 0 end
  return math.min(1, (c.t - start) / 0.10)
end

function LU:draw()
  local c = self.cur
  if c then
    for _, soul in ipairs(c.souls) do
      local x, y, lt = self:_soulPos(c, soul)
      if x then
        -- traînée (un cran en arrière sur le chemin)
        local tx2, ty2 = self:_soulPos(c, { sx = soul.sx, sy = soul.sy, cx = soul.cx, cy = soul.cy,
          a0 = soul.a0, r0 = soul.r0, depart = soul.depart, arrive = soul.arrive })
        love.graphics.setBlendMode("add")
        for s = 1, 4 do
          local e = math.max(0, lt - s * 0.06)
          local px, py
          if c.style == "orbit" then
            local ang = soul.a0 + 1.3 * math.pi * 2 * e; local r = soul.r0 * (1 - easeIn(e))
            px, py = c.tx + math.cos(ang) * r, c.ty + math.sin(ang) * r
          else
            local ee = easeIn(e); px, py = bez(soul.sx, soul.cx, c.tx, ee), bez(soul.sy, soul.cy, c.ty, ee)
          end
          love.graphics.setColor(GOLD[1], GOLD[2], GOLD[3], 0.18 * (1 - s / 5))
          love.graphics.circle("fill", px, py, 4 - s * 0.6)
        end
        -- l'âme : noyau braise + halo or
        love.graphics.setColor(EMBER[1], EMBER[2], EMBER[3], 0.5)
        love.graphics.circle("fill", x, y, 7)
        love.graphics.setColor(GOLD[1], GOLD[2], GOLD[3], 1)
        love.graphics.circle("fill", x, y, 3.5)
        love.graphics.setColor(1, 1, 1, 0.9)
        love.graphics.circle("fill", x, y, 1.6)
        love.graphics.setBlendMode("alpha")
      end
    end
    -- flash local au climax : sceau/rayons pixelisés, jamais un disque lisse de placeholder.
    if self.flash > 0.01 then
      drawClimaxFlash(c.tx, c.ty, self.flash, c.t)
    end
  end
  love.graphics.setColor(1, 1, 1, 1)
end

return LU
