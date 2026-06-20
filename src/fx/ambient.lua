-- src/fx/ambient.lua
-- Couche ATMOSPHÉRIQUE partagée (DA "The Pit"), dessinée en ESPACE DESIGN 1280x720, en NATIF, derrière
-- le monde pixel (pre-pass `scene:drawBack`). On descend un puits : gueule rouge pulsante en bas, voûte
-- de stalactites, braises montantes, poussière, vignette. Les glows sont LISSES (texture radiale bakée
-- une fois, filtre linéaire) -> rendu fidèle au prototype, sans pixelliser les dégradés.
--
-- Couche RENDER (love.graphics) hors firewall SIM. RNG purement COSMÉTIQUE seedé (love.math) -> texture
-- stable entre lancements, mais sans aucune incidence sur la simulation. Modes :
--   "menu"/"combat" = atmosphère complète ; "build"/"grimoire" = dégradé calme (focalise le plateau).

local Theme = require("src.ui.theme")

local Ambient = {}
Ambient.__index = Ambient

local W, H = 1280, 720

-- ─────────────────────────── Textures bakées (partagées, 1 seule fois) ───────────────────────────
local glowImg, vignImg
local function ensureBaked()
  if glowImg or not (love and love.image and love.graphics) then return end
  -- Glow radial : blanc opaque au centre -> transparent au bord (falloff doux). Teinté à l'usage.
  local g = love.image.newImageData(64, 64)
  g:mapPixel(function(x, y)
    local dx, dy = (x - 31.5) / 31.5, (y - 31.5) / 31.5
    local d = math.sqrt(dx * dx + dy * dy)
    local a = math.max(0, 1 - d)
    return 1, 1, 1, a * a
  end)
  glowImg = love.graphics.newImage(g)
  glowImg:setFilter("linear", "linear")

  -- Vignette : transparent au centre -> sombre aux bords (assombrit le cadre).
  local v = love.image.newImageData(64, 64)
  v:mapPixel(function(x, y)
    local dx, dy = (x - 31.5) / 31.5, (y - 31.5) / 31.5
    local d = math.min(1, math.sqrt(dx * dx + dy * dy))
    local a = d * d * d -- concentré sur les bords
    return 0, 0, 0, a
  end)
  vignImg = love.graphics.newImage(v)
  vignImg:setFilter("linear", "linear")
end

-- Glow doux centré en (cx,cy), demi-tailles (rx,ry), teinté `color` à l'alpha `a`.
local function drawGlow(cx, cy, rx, ry, color, a)
  if not glowImg then return end
  love.graphics.setColor(color[1], color[2], color[3], a)
  love.graphics.draw(glowImg, cx, cy, 0, (rx * 2) / 64, (ry * 2) / 64, 32, 32)
end

-- ─────────────────────────────────── Construction ───────────────────────────────────
function Ambient.new(seed)
  local self = setmetatable({ t = 0 }, Ambient)
  ensureBaked()
  local rng = (love and love.math and love.math.newRandomGenerator)
      and love.math.newRandomGenerator(seed or 1337) or nil
  local function r() return rng and rng:random() or 0.5 end

  -- Stalactites (voûte) : triangles sombres pointant vers le bas, depuis y=0.
  self.stals = {}
  for i = 1, 14 do
    local w = (6 + r() * 12) * 4
    self.stals[i] = { x = r() * W, w = w, h = (8 + r() * 22) * 4 }
  end
  -- Poussière en suspension (chute lente, wrap).
  self.dust = {}
  for i = 1, 34 do
    self.dust[i] = { x = r() * W, y0 = r() * H, sp = 8 + r() * 22, ph = r() * 6.28, size = (r() > 0.7) and 2 or 1 }
  end
  -- Braises montantes (depuis la moitié basse).
  self.embers = {}
  for i = 1, 16 do
    self.embers[i] = { x = r() * W, base = 420 + r() * 220, ph = r() * 6.28, sp = 0.4 + r() * 0.5, rise = 180 + r() * 120 }
  end
  return self
end

function Ambient:update(dt)
  self.t = self.t + (dt or 1)
end

-- ─────────────────────────────────── Rendu ───────────────────────────────────
-- mode : "menu"/"combat" = complet ; "build"/"grimoire" = dégradé calme. Dessine en coords design 0..1280/0..720.
function Ambient:draw(mode)
  local c = Theme.c
  local t = self.t
  local full = (mode == "menu" or mode == "combat" or mode == "relic" or mode == "runover")

  -- Base : fond plein + glow chaud diffus en haut (la lueur lointaine du seuil).
  if full then
    love.graphics.setColor(c.void[1], c.void[2], c.void[3], 1)
    love.graphics.rectangle("fill", 0, 0, W, H)
    drawGlow(W * 0.5, -30, 720, 460, c.bgEmber, 0.5)
  else -- build / grimoire : dégradé radial sobre
    love.graphics.setColor(c.bgPit[1], c.bgPit[2], c.bgPit[3], 1)
    love.graphics.rectangle("fill", 0, 0, W, H)
    drawGlow(W * 0.5, 90, 820, 560, c.bgWarm, 0.6)
  end

  if full then
    -- Gueule du puits : grand halo rouge pulsant en bas-centre (élément signature).
    local pulse = 0.34 + 0.10 * math.sin(t * 0.04)
    drawGlow(W * 0.5, H - 6, 380, 260, c.blood, pulse)
    drawGlow(W * 0.5, H + 24, 210, 160, c.bloodBright, pulse * 0.7)

    -- Stalactites.
    love.graphics.setColor(c.void[1], c.void[2], c.void[3], 1)
    for _, s in ipairs(self.stals) do
      love.graphics.polygon("fill", s.x, 0, s.x + s.w, 0, s.x + s.w * 0.5, s.h)
    end

    -- Braises montantes.
    for _, e in ipairs(self.embers) do
      local prog = ((t * e.sp * 0.02) + e.ph) % 1
      local y = e.base - prog * e.rise
      local a = math.sin(prog * 3.14159) * 0.8
      love.graphics.setColor(c.ember[1], c.ember[2], c.ember[3], a)
      love.graphics.rectangle("fill", e.x, y, 3, 3)
    end
  end

  -- Poussière (toujours présente, discrète).
  for _, d in ipairs(self.dust) do
    local y = (d.y0 + t * d.sp * 0.06) % H
    local x = d.x + math.sin(t * 0.02 + d.ph) * 3
    local a = (full and 0.5 or 0.32) * (0.6 + 0.4 * math.sin(t * 0.02 + d.ph))
    love.graphics.setColor(0.42, 0.35, 0.38, a)
    love.graphics.rectangle("fill", math.floor(x), math.floor(y), d.size, d.size)
  end

  -- Vignette : assombrit les bords (cadre).
  if vignImg then
    love.graphics.setColor(1, 1, 1, full and 0.9 or 0.7)
    love.graphics.draw(vignImg, 0, 0, 0, W / 64, H / 64)
  end

  love.graphics.setColor(1, 1, 1, 1)
end

return Ambient
