-- src/render/affliction_fx.lua
-- FEEDBACK VISUEL DES AFFLICTIONS (Partie 1 : effets PERSISTANTS sur l'entité). Couche RENDER pure :
-- lit `arena.units[].dots` / `.shield` en LECTURE SEULE, ne mute JAMAIS la SIM (firewall §4). Aucun
-- événement SIM, aucun risque golden. Possédé par ArenaDraw (1 instance/combat).
--
-- Principe : 1 descripteur par famille (logique MODULABLE — ajouter une affliction = +1 cas d'émission +
-- éventuellement +1 couleur). Particules hand-rolled (cohérent avec dmgNumbers/impacts/trail de
-- arena_draw) en ESPACE VIRTUEL (coords u.x,u.y = pieds ; corps vers le haut). UN seul shader : le
-- contour de bouclier (8-voisins sur un canvas off-screen ; ne traverse jamais le corps).
--
-- Discrétion : faible nombre de particules, alpha plafonné, jitter DÉTERMINISTE (suite de Weyl + phase
-- par unité), jamais love.math.random scintillant. Chiffres = placeholders calibrés (à tuner à l'œil).

local Theme = require("src.ui.theme")
local Rig = require("src.core.rig") -- pour aplatir le rig dans le canvas du contour de bouclier

local AfflictionFx = {}
AfflictionFx.__index = AfflictionFx

local C = Theme.c
local H = Theme.hex
local floor, sin, cos, min, max = math.floor, math.sin, math.cos, math.min, math.max

-- Éclaircir (f>1, vers blanc) / assombrir (f<1). Réutilise la logique de healthbar.shade sans coupler.
local function lit(c, f)
  if f <= 1 then return { c[1] * f, c[2] * f, c[3] * f } end
  local t = f - 1
  return { c[1] + (1 - c[1]) * t, c[2] + (1 - c[2]) * t, c[3] + (1 - c[3]) * t }
end

-- Palette de la VFX (réutilise Theme.c ; bleedDeep ajouté à theme.lua). Couleurs littérales = teintes
-- de matière sombre (spore brune, mouche violet-noir) absentes de la palette d'UI.
local COL = {
  flameHi   = H(0xf7d048),       -- pointe de flamme (jaune chaud, = hi de la barre de vie burn)
  flameMid  = C.burn,            -- corps de flamme (braise vive)
  flameLo   = C.ember,           -- base/fin de flamme (braise éteinte)
  blood     = C.bleed,           -- goutte vive
  bloodDeep = C.bleedDeep,       -- flaque / sang séché
  poison    = C.poison,          -- bulle de gaz
  poisonHi  = lit(C.poison, 1.4),-- reflet de bulle
  rot       = C.rot,             -- spore nécrotique (violet)
  rotBrown  = H(0x4a2c1a),       -- spore de chair pourrie (brun)
  fly       = H(0x281438),       -- mouche (violet-noir)
  shield    = C.shield,          -- contour de bouclier (cyan)
  shock     = C.shock,           -- étincelles de choc (jaune électrique)
}

local HALF_W = 5      -- demi-largeur de silhouette (~10px)
local PHI  = 0.6180339887  -- suite de Weyl (nombre d'or) : spread/jitter déterministe, stable
local PHI2 = 0.7548776662  -- 2e flux (nombre plastique) — décorrèle x/y
local PHI3 = 0.5698402909  -- 3e flux — vie/zone
-- CHOC : points répartis sur la silhouette où crépitent les éclairs en zigzag (tête, épaules, flancs, bas).
local SHOCK_ANCHORS = { { 0, -22 }, { -5, -17 }, { 5, -17 }, { -6, -10 }, { 6, -10 }, { -3, -4 }, { 3, -4 } }
local function fracv(x) return x - floor(x) end -- partie fractionnaire (scintillement déterministe par frame)

-- Canvas off-screen partagé pour le contour de bouclier (rig aplati). Marges = aucune fausse arête au bord.
local SC_W, SC_H = 36, 42
local FEET_X, FEET_Y = 18, 36 -- où atterrissent les pieds (u.x,u.y) dans le canvas

-- Shader de contour : un texel vide ADJACENT à du plein -> liseré ; un texel plein -> transparent
-- (return vec4(0)) => NE TRAVERSE JAMAIS le corps. Échantillonnage 8-voisins (Cyanilux). GLSL 1.20 (Texel
-- fonctionne dans toutes les versions, cf. wiki LÖVE) -> pas besoin de #pragma glsl3.
local OUTLINE_GLSL = [[
extern vec2 texel;       // 1/taille du canvas
extern vec3 lineColor;   // couleur du liseré
extern number pulse;     // opacité animée
vec4 effect(vec4 color, Image tex, vec2 tc, vec2 sc) {
  number a = Texel(tex, tc).a;
  if (a > 0.0) { return vec4(0.0); }            // intérieur : transparent
  number n = 0.0;
  n += Texel(tex, tc + vec2( texel.x, 0.0)).a;
  n += Texel(tex, tc + vec2(-texel.x, 0.0)).a;
  n += Texel(tex, tc + vec2(0.0,  texel.y)).a;
  n += Texel(tex, tc + vec2(0.0, -texel.y)).a;
  n += Texel(tex, tc + vec2( texel.x,  texel.y)).a;
  n += Texel(tex, tc + vec2(-texel.x, -texel.y)).a;
  n += Texel(tex, tc + vec2( texel.x, -texel.y)).a;
  n += Texel(tex, tc + vec2(-texel.x,  texel.y)).a;
  if (n > 0.0) { return vec4(lineColor, pulse); } // bord extérieur : contour
  return vec4(0.0);
}
]]

function AfflictionFx.new()
  local self = setmetatable({
    parts = {}, -- particules transitoires {x,y,vx,vy,ay,age,life,kind,phase,floorY,alt}
    flies = {}, -- [u] = { {ph,ph2,stutAcc,stutOff,fade}, ... } (persistant tant que rot)
    acc = {},   -- [u] = { burn, bleed, poison, rot } accumulateurs d'émission
    shockFlash = {}, -- [u] = { age, life } flash électrique bref à la décharge du choc
    n = 0,      -- compteur Weyl global
  }, AfflictionFx)
  -- Shader + canvas : créés une fois, gardés gracieusement (si GLSL/canvas indispo -> pas de contour, pas de crash).
  if love and love.graphics and love.graphics.newShader then
    local ok, sh = pcall(love.graphics.newShader, OUTLINE_GLSL)
    if ok then self.outlineShader = sh end
    local ok2, cv = pcall(love.graphics.newCanvas, SC_W, SC_H)
    if ok2 then
      self.shieldCanvas = cv
      pcall(cv.setFilter, cv, "nearest", "nearest")
      pcall(cv.setWrap, cv, "clampzero", "clampzero") -- hors-bord = transparent (pas de fausse arête)
    end
  end
  return self
end

function AfflictionFx:reset()
  self.parts = {}; self.flies = {}; self.acc = {}; self.shockFlash = {}; self.n = 0
end

-- CHOC : déclenché par le RENDER à la décharge (event "damage" cause="shock"). Étincelles radiales
-- « Super Saiyan » + flash électrique bref autour de l'unité (façon paralysie). Purement visuel.
function AfflictionFx:shockSpark(u)
  if not u then return end
  local cx, cy = u.x, u.y - 12
  for i = 1, 12 do
    local r, r2 = self:weyl()
    local ang = (i / 12) * 6.2832 + (r - 0.5) * 0.7
    local spd = 1.2 + r2 * 1.3
    self.parts[#self.parts + 1] = {
      kind = "spark", x = cx, y = cy,
      vx = cos(ang) * spd, vy = sin(ang) * spd, ay = 0,
      age = 0, life = 7 + r2 * 6,
    }
  end
  self.shockFlash[u] = { age = 0, life = 12, phase = (self:weyl()) * 6.2832 }
end

-- Phase stable par unité (sans toucher au rig) -> désynchronise glows/oscillations entre monstres.
local function unitPhase(u) return (u.depth or 0) * 1.7 + (u.row or 0) * 2.3 end

-- ── Émission (suite de Weyl pour un jitter déterministe et stable) ──────────────────────────────
function AfflictionFx:weyl()
  self.n = self.n + 1
  local n = self.n
  return (n * PHI) % 1, (n * PHI2) % 1, (n * PHI3) % 1
end

function AfflictionFx:spawnFlame(u)
  local r, r2, r3 = self:weyl()
  -- 3 zones : tête / torse / bas -> "lèche de flammes à divers endroits"
  local ey = (r3 < 0.34 and u.y - 22) or (r3 < 0.67 and u.y - 12) or (u.y - 4)
  self.parts[#self.parts + 1] = {
    kind = "flame", x = u.x + (r - 0.5) * 2 * HALF_W, y = ey,
    vx = (r2 - 0.5) * 0.5, vy = -(0.7 + r * 0.4), ay = -0.015,
    age = 0, life = 16 + r2 * 8, phase = r * 6.2832,
  }
end

function AfflictionFx:spawnBlood(u)
  local r, r2 = self:weyl()
  self.parts[#self.parts + 1] = {
    kind = "blood", x = u.x + (r < 0.5 and -HALF_W or HALF_W) + (r2 - 0.5) * 2,
    y = u.y - 4 - r2 * 10, vx = (r - 0.5) * 0.2, vy = 0.15, ay = 0.08,
    age = 0, life = 22 + r * 8, floorY = u.y,
  }
end

function AfflictionFx:spawnBubble(u)
  local r, r2 = self:weyl()
  self.parts[#self.parts + 1] = {
    kind = "bubble", x = u.x + (r - 0.5) * 2 * HALF_W, y = u.y - 2 - r2 * 18,
    vx = (r2 - 0.5) * 0.4, vy = -(0.4 + r * 0.3), ay = -0.01,
    age = 0, life = 16 + r * 8, phase = r2 * 6.2832,
  }
end

function AfflictionFx:spawnSpore(u)
  local r, r2, r3 = self:weyl()
  self.parts[#self.parts + 1] = {
    kind = "spore", x = u.x + (r - 0.5) * (2 * HALF_W + 4), y = u.y - 2 - r2 * 18,
    vx = (r3 - 0.5) * 0.4, vy = -0.15 + r * 0.25, ay = 0,
    age = 0, life = 24 + r2 * 12, alt = (r3 < 0.5),
  }
end

function AfflictionFx:ensureFlies(u)
  if self.flies[u] then return end
  local r = self:weyl()
  local list = {}
  local count = (r < 0.5) and 1 or 2
  for i = 1, count do
    local a, b = self:weyl()
    list[i] = { ph = a * 6.2832, ph2 = b * 6.2832, stutAcc = 0, stutOff = 0, fade = 0 }
  end
  self.flies[u] = list
end

-- ── Update : émission gated par accumulateur (pattern entier de tickDots) + intégration Euler ─────
function AfflictionFx:update(units, dt, t)
  for _, u in ipairs(units) do
    if u.alive then
      local d = u.dots
      local a = self.acc[u]
      if not a then a = { burn = 0, bleed = 0, poison = 0, rot = 0 }; self.acc[u] = a end

      if d.burn then
        local rate = (d.burn.dps and d.burn.dps >= 8) and 0.55 or 0.36 -- feu nettement plus dense (retour user)
        a.burn = a.burn + rate * dt
        while a.burn >= 1 do a.burn = a.burn - 1; self:spawnFlame(u) end
      end
      if d.bleed then
        a.bleed = a.bleed + 0.14 * dt -- saignement un peu plus intense (retour user)
        while a.bleed >= 1 do a.bleed = a.bleed - 1; self:spawnBlood(u) end
      end
      local stacks = d.poison and #d.poison or 0
      if stacks > 0 then
        a.poison = a.poison + (0.14 + 0.03 * min(stacks, 6)) * dt
        while a.poison >= 1 do a.poison = a.poison - 1; self:spawnBubble(u) end
      end
      if d.rot then
        a.rot = a.rot + 0.08 * dt
        while a.rot >= 1 do a.rot = a.rot - 1; self:spawnSpore(u) end
        self:ensureFlies(u)
      end
    end
  end

  -- Mouches : fade-in tant que rot, fade-out sinon ; stutter (vol saccadé) déterministe.
  for u, list in pairs(self.flies) do
    local hasRot = u.alive and u.dots.rot
    local anyAlive = false
    for _, f in ipairs(list) do
      f.fade = hasRot and min(1, f.fade + dt / 6) or max(0, f.fade - dt / 6)
      f.stutAcc = f.stutAcc + dt
      if f.stutAcc >= 5 then f.stutAcc = f.stutAcc - 5; local r = self:weyl(); f.stutOff = (r - 0.5) end
      if f.fade > 0 then anyAlive = true end
    end
    if not hasRot and not anyAlive then self.flies[u] = nil end
  end

  -- Flash électrique de choc (bref).
  for u, fl in pairs(self.shockFlash) do
    fl.age = fl.age + dt
    if fl.age >= fl.life then self.shockFlash[u] = nil end
  end

  -- Intégration des particules transitoires (backward swap-remove).
  local parts = self.parts
  for i = #parts, 1, -1 do
    local p = parts[i]
    p.age = p.age + dt
    p.x = p.x + p.vx * dt
    p.vy = p.vy + (p.ay or 0) * dt
    p.y = p.y + p.vy * dt
    if p.kind == "blood" and p.floorY and p.y >= p.floorY then
      p.kind = "splat"; p.y = p.floorY; p.vx = 0; p.vy = 0; p.age = 0; p.life = 8
    elseif p.age >= p.life then
      parts[i] = parts[#parts]; parts[#parts] = nil
    end
  end
end

-- ── Helpers de fondu ──────────────────────────────────────────────────────────────────────────
local function fadeIn(age, n) return min(1, age / n) end
local function tailOut(age, life, frac)
  local s = life * (1 - frac)
  if age < s then return 1 end
  return max(0, 1 - (age - s) / (life * frac))
end

-- ── Dessin matière (NON additif) : sang, flaque, bulles, spores, mouches. Espace virtuel. ───────
function AfflictionFx:drawBody(units, t)
  local g = love.graphics
  for _, p in ipairs(self.parts) do
    if p.kind == "blood" then
      g.setColor(COL.blood[1], COL.blood[2], COL.blood[3], 1)
      local h = (p.vy < 0.6) and 2 or 1 -- goutte allongée tant qu'elle perle, perle ronde en chute
      g.rectangle("fill", floor(p.x), floor(p.y), 1, h)
    elseif p.kind == "splat" then
      local al = 1 - p.age / p.life
      g.setColor(COL.bloodDeep[1], COL.bloodDeep[2], COL.bloodDeep[3], al)
      g.rectangle("fill", floor(p.x) - 1, floor(p.y), 2, 1)
    elseif p.kind == "bubble" then
      local f = p.age / p.life
      local al = fadeIn(p.age, 2) * 0.7 * (1 - max(0, (f - 0.85) / 0.15))
      local x, y = floor(p.x), floor(p.y)
      local r = (p.age > p.life - 3) and 2 or 1 -- "pop" : grossit sur les 3 dernières frames
      g.setColor(COL.poison[1], COL.poison[2], COL.poison[3], al)
      g.rectangle("fill", x, y - r, 1, 1); g.rectangle("fill", x, y + r, 1, 1)
      g.rectangle("fill", x - r, y, 1, 1); g.rectangle("fill", x + r, y, 1, 1)
      g.setColor(COL.poisonHi[1], COL.poisonHi[2], COL.poisonHi[3], al)
      g.rectangle("fill", x - 1, y - 1, 1, 1)
    elseif p.kind == "spore" then
      local al = fadeIn(p.age, 3) * tailOut(p.age, p.life, 0.4) * 0.5
      local col = p.alt and COL.rotBrown or COL.rot
      g.setColor(col[1], col[2], col[3], al)
      g.rectangle("fill", floor(p.x), floor(p.y), 1, 1)
    end
  end

  -- Mouches : orbite + zig-zag saccadé près de la tête/torse.
  t = t or 0
  for u, list in pairs(self.flies) do
    local cx, cy = u.x, u.y - 16
    for _, f in ipairs(list) do
      if f.fade > 0 then
        local x = cx + sin(t * 0.06 + f.ph + f.stutOff) * 4
        local y = cy + cos(t * 0.09 + f.ph2 + f.stutOff) * 3
        g.setColor(COL.fly[1], COL.fly[2], COL.fly[3], 0.9 * f.fade)
        g.rectangle("fill", floor(x), floor(y), 1, 1)
      end
    end
  end
  g.setColor(1, 1, 1, 1)
end

-- ── Dessin lumière (ADDITIF) : glow de chaleur + flammèches. Toujours suivi d'un reset alpha. ────
function AfflictionFx:drawGlow(units, t)
  local g = love.graphics
  t = t or 0
  local blend = g.setBlendMode -- tolérant : absent du mock headless -> blend normal (le stub ne rend rien)
  if blend then blend("add") end

  -- Glow de chaleur sous chaque unité en feu (faible, palpitant).
  for _, u in ipairs(units) do
    if u.alive and u.dots.burn then
      local al = 0.20 + 0.07 * sin(t * 0.12 + unitPhase(u))
      g.setColor(COL.flameMid[1], COL.flameMid[2], COL.flameMid[3], al)
      g.ellipse("fill", u.x, u.y - 11, 9, 12)
    end
  end

  -- Flammèches.
  for _, p in ipairs(self.parts) do
    if p.kind == "flame" then
      local f = p.age / p.life
      local col = (f < 0.3 and COL.flameHi) or (f < 0.7 and COL.flameMid) or COL.flameLo
      local al = fadeIn(p.age, 3) * tailOut(p.age, p.life, 0.4) * 0.9
      local h = (f < 0.65) and 2 or 1    -- flammes plus hautes (corps de feu visible)
      local w = (f < 0.3) and 2 or 1     -- base plus large (2×2) -> plus charnu
      local wob = sin(p.age * 0.4 + (p.phase or 0)) * 0.4
      g.setColor(col[1], col[2], col[3], al)
      g.rectangle("fill", floor(p.x + wob), floor(p.y), w, h)
    end
  end

  -- Choc : étincelles radiales (cœur blanc -> jaune) éjectées à la décharge.
  for _, p in ipairs(self.parts) do
    if p.kind == "spark" then
      local f = p.age / p.life
      local col = (f < 0.4) and { 1, 1, 1 } or COL.shock
      g.setColor(col[1], col[2], col[3], 1 - f)
      local s = (f < 0.4) and 2 or 1
      g.rectangle("fill", floor(p.x), floor(p.y), s, s)
    end
  end
  -- Choc : ÉCLAIRS en zigzag qui crépitent à plusieurs points de la silhouette (cœur blanc + halo jaune),
  -- scintillants (sous-ensemble d'ancres ré-tiré chaque frame) -> lecture « décharge électrique sur le corps ».
  local frame = floor((t or 0))
  g.setLineStyle("rough"); g.setLineWidth(1)
  for u, fl in pairs(self.shockFlash) do
    local al = 1 - fl.age / fl.life
    if al > 0.05 then
      for k, anc in ipairs(SHOCK_ANCHORS) do
        if fracv((frame + k) * PHI + (fl.phase or 0)) < 0.55 then
          local ax, ay = u.x + anc[1], u.y + anc[2]
          local dir = (anc[1] >= 0) and 1 or -1
          local hx, hy = fracv(frame * 0.754 + k * 0.31), fracv(frame * 0.317 + k * 0.62)
          local ox, oy = ax + dir * (2 + hx * 3), ay - 1 - hy * 3
          local mx, my = (ax + ox) / 2 + dir * 1.5, (ay + oy) / 2 + (hx - 0.5) * 3
          g.setColor(COL.shock[1], COL.shock[2], COL.shock[3], al * 0.85)
          g.line(ax, ay, mx, my, ox, oy) -- halo jaune (zigzag 2 segments)
          g.setColor(1, 1, 1, al)
          g.line(ax, ay, mx, my)         -- cœur blanc
        end
      end
    end
  end

  if blend then blend("alpha") end
  g.setColor(1, 1, 1, 1)
end

-- ── Contour de bouclier (LE shader) : rig aplati dans un canvas -> outline 8-voisins -> blit. ────
-- `rigs` = map [u] = char (possédée par ArenaDraw). Seules les unités shieldées paient le coût.
-- Aplatit le rig `c` dans le canvas partagé puis le redessine via le shader d'outline, en couleur/opacité
-- données. Mutualisé entre le contour de BOUCLIER (cyan, permanent) et le flash de CHOC (électrique, bref).
function AfflictionFx:_outline(g, sh, c, prev, lineColor, alpha)
  g.setCanvas(self.shieldCanvas)
  g.clear(0, 0, 0, 0)
  g.push(); g.translate(FEET_X - c.x, FEET_Y - c.y); Rig.draw(c); g.pop()
  g.setCanvas(prev)
  pcall(sh.send, sh, "lineColor", lineColor)
  pcall(sh.send, sh, "pulse", alpha)
  g.setShader(sh)
  g.setColor(1, 1, 1, 1)
  g.draw(self.shieldCanvas, floor(c.x - FEET_X + 0.5), floor(c.y - FEET_Y + 0.5))
  g.setShader()
end

function AfflictionFx:drawOutlines(units, rigs, t)
  if not (self.outlineShader and self.shieldCanvas) then return end
  local g, sh = love.graphics, self.outlineShader
  pcall(sh.send, sh, "texel", { 1 / SC_W, 1 / SC_H })
  local prev = g.getCanvas()

  -- BOUCLIER : contour cyan palpitant (permanent tant que shield > 0).
  local cyan = { COL.shield[1], COL.shield[2], COL.shield[3] }
  local pulse = 0.6 + 0.25 * sin((t or 0) * 0.09)
  for _, u in ipairs(units) do
    local c = rigs and rigs[u]
    if c and u.alive and (u.shield or 0) > 0 then self:_outline(g, sh, c, prev, cyan, pulse) end
  end

  -- CHOC : flash électrique sur le CONTOUR (le corps entier crépite), bref + scintillant (renforce les éclairs).
  local elec = { 1, 1, 0.5 }
  for u, fl in pairs(self.shockFlash) do
    local c = rigs and rigs[u]
    if c and u.alive then
      local a = (1 - fl.age / fl.life) * (0.5 + 0.5 * sin((t or 0) * 1.8 + (fl.phase or 0)))
      if a > 0.06 then self:_outline(g, sh, c, prev, elec, a) end
    end
  end

  g.setColor(1, 1, 1, 1)
end

return AfflictionFx
