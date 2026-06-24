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
local glowImg, vignImg, bakeTried
-- Bake tolérant : sous un LÖVE mock (headless) mapPixel/newImage peuvent manquer -> on dégrade
-- gracieusement (glowImg/vignImg restent nil, les draws sont gardés). Ambient ne crashe jamais.
local function ensureBaked()
  if bakeTried or not (love and love.image and love.graphics and love.graphics.newImage) then return end
  bakeTried = true
  pcall(function()
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
  end)
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

  -- ── P1 — PROFONDEUR (combat) : remplir le noir de SENS, le tout DÉTERMINISTE (même `r()` seedé) ──
  -- P1.1 — Architecture du PUITS derrière le camp ennemi : quelques piliers/trapèzes near-black qui montent
  -- du coin bas-droite et se fondent dans la vignette (« on devine des structures dans la fosse »). Stockés
  -- en data (sommets dérivés du seed) -> draw plat, aucun coût de génération par frame.
  self.pillars = {}
  for i = 1, 5 do
    local bx = W * (0.58 + r() * 0.36)              -- ancrés à droite (camp ennemi), jusqu'au bord
    local bw = (54 + r() * 64)                       -- largeur de base (assez large pour lire la masse)
    local h  = (260 + r() * 230)                     -- hauteur (montent dans la pénombre)
    local taper = 0.30 + r() * 0.28                  -- rétrécissement vers le haut (trapèze)
    self.pillars[i] = { bx = bx, bw = bw, h = h, taper = taper, lean = (r() - 0.5) * 26 }
  end

  -- P1.3 — Braises DENSES de la zone de combat : 2e banc concentré autour du centre (design x~640), plus
  -- chaud et plus serré que les braises de fond -> la confrontation « chauffe » au milieu du champ.
  self.cembers = {}
  for i = 1, 28 do
    self.cembers[i] = {
      x = W * 0.5 + (r() - 0.5) * 380,               -- resserrées sur le centre du champ
      base = 460 + r() * 150, ph = r() * 6.28,
      sp = 0.5 + r() * 0.6, rise = 130 + r() * 120, size = (r() > 0.55) and 2 or 1,
    }
  end

  -- P1.2 — Bande de BROUILLARD qui dérive en travers de la ligne de front (mi-hauteur = niveau des yeux,
  -- design y≈430..560). 3 nappes très basse-alpha qui glissent horizontalement (sin lent, déphasées).
  self.fog = {}
  for i = 1, 3 do
    self.fog[i] = { y = 440 + i * 38, rx = 340 + r() * 160, ry = 70 + r() * 40, ph = r() * 6.28, sp = 0.4 + r() * 0.5 }
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

    -- ── P1.1 — ARCHITECTURE DU PUITS (derrière le camp ennemi, à droite) : une « gorge » lointaine (halo +
    -- anneaux) DERRIÈRE laquelle se SILHOUETTENT des piliers near-black qui montent du bas-droite. L'ordre est
    -- la clé de la profondeur : on pose D'ABORD la lueur, PUIS les structures sombres par-dessus -> elles se
    -- découpent en contre-jour (sinon : du noir sur du noir = invisible). Tout calé côté ENNEMI (x ~0.70 W).
    local throatX, throatY = W * 0.70, 350
    -- Lueur de gouffre : nappe chaude diffuse (HAUTE -> rétro-éclaire les piliers) + anneaux de pierre
    -- concentriques (la structure du puits lointain) + cœur de braise. Plusieurs passes empilées = un vrai
    -- creux lumineux derrière l'ennemi (et non un simple disque plat).
    drawGlow(throatX, throatY, 320, 320, c.bgEmber, 0.55)
    drawGlow(throatX, throatY + 20, 200, 200, c.blood, 0.13)
    for ring = 4, 1, -1 do
      local rad = 60 + ring * 52
      drawGlow(throatX, throatY, rad, rad * 0.82, c.stone600, 0.05 + (4 - ring) * 0.025)
    end
    drawGlow(throatX, throatY, 56, 48, c.ember, 0.18) -- braise au fond de la gorge (cœur chaud)
    -- Piliers : trapèzes pleins near-black, SILHOUETTÉS sur la lueur ci-dessus (la base au sol, sommet rétréci,
    -- légère inclinaison). `stone900` (et non `void` pur) -> juste assez au-dessus du fond pour lire l'arête.
    love.graphics.setColor(c.stone900[1], c.stone900[2], c.stone900[3], 1)
    for _, p in ipairs(self.pillars) do
      local topY = H - p.h
      local halfB, halfT = p.bw * 0.5, p.bw * 0.5 * p.taper
      local cxB, cxT = p.bx, p.bx + p.lean
      love.graphics.polygon("fill",
        cxB - halfB, H, cxB + halfB, H, cxT + halfT, topY, cxT - halfT, topY)
    end
    -- Arête éclairée (à peine) : un fin liseré `stone600` sur le flanc gauche des piliers les détache du noir.
    love.graphics.setColor(c.stone600[1], c.stone600[2], c.stone600[3], 0.16)
    love.graphics.setLineWidth(1)
    for _, p in ipairs(self.pillars) do
      local topY = H - p.h
      love.graphics.line(p.bx - p.bw * 0.5, H, p.bx + p.lean - p.bw * 0.5 * p.taper, topY)
    end

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

    -- P1.3 — Braises DENSES de la zone de combat (2e banc, resserré sur le centre) : plus chaudes/vives ->
    -- la confrontation chauffe au milieu. Même intégration que les braises de fond, alpha un peu plus haut.
    for _, e in ipairs(self.cembers) do
      local prog = ((t * e.sp * 0.022) + e.ph) % 1
      local y = e.base - prog * e.rise
      local a = math.sin(prog * 3.14159) * 0.85
      love.graphics.setColor(c.ember[1], c.ember[2], c.ember[3], a)
      love.graphics.rectangle("fill", e.x, y, e.size, e.size)
      if a > 0.5 then -- cœur chaud sur les plus vives
        love.graphics.setColor(c.bloodBright[1], c.bloodBright[2], c.bloodBright[3], (a - 0.5) * 0.6)
        love.graphics.rectangle("fill", e.x, y, 1, 1)
      end
    end

    -- Brume CENTRALE (mi-hauteur = niveau des YEUX du combat) : un grand halo chaud diffus remplit le « noir
    -- mort » du milieu, là où les deux camps s'affrontent (le sol de fosse vit à design y~470). Gardé par
    -- `full` -> n'apparaît qu'en menu/combat (le mode calme build/grimoire reste focalisé sur le plateau).
    drawGlow(W * 0.5, 380, 520, 300, c.bgEmber, 0.22)
    -- Voile de sang plus sombre, plus serré : ancre la brume vers la gueule sans laver les sprites ni
    -- sur-saturer le bas du cadre (calé sur la retenue chaude du menu = la réf de DA).
    drawGlow(W * 0.5, 455, 360, 210, c.blood, 0.08)

    -- P1.2 — Bande de BROUILLARD qui DÉRIVE en travers de la ligne de front (mi-hauteur, y≈430..560). Nappes
    -- très basse-alpha (`bgWarm`/`stone700`) qui glissent horizontalement (sin lent, déphasées) -> de
    -- l'atmosphère AU NIVEAU DES YEUX du combat, sans laver les sprites (alpha plafonné ~0.06).
    for i, f in ipairs(self.fog) do
      local drift = math.sin(t * 0.01 * f.sp + f.ph) * 140 -- va-et-vient horizontal lent
      local col = (i % 2 == 0) and c.bgWarm or c.stone700
      drawGlow(W * 0.5 + drift, f.y, f.rx, f.ry, col, 0.07)
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
    -- 2e passe INTÉRIEURE (échelle plus serrée, recentrée) : la même texture agrandie mord plus loin dans
    -- les coins -> ils virent au noir total et l'œil est canalisé vers la ligne de front centrale (comme le
    -- menu). Réutilise vignImg ; origine au centre (32,32) pour rester centrée en agrandissant.
    if full then
      local s = 1.45 -- > 1 : l'anneau sombre de la vignette intrude davantage (coins plus noirs)
      love.graphics.setColor(1, 1, 1, 0.55)
      love.graphics.draw(vignImg, W / 2, H / 2, 0, (W / 64) * s, (H / 64) * s, 32, 32)
    end
  end

  love.graphics.setColor(1, 1, 1, 1)
end

return Ambient
