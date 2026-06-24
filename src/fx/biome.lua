-- src/fx/biome.lua
-- MOTEUR DE DÉCORS en couches du Pit — PORT FIDÈLE de la référence design `biome-engine.js`.
-- Rend un fond pixel-art 192×108 en 6 calques parallaxe (ordre : sky, far, mid, near, ground, fog)
-- + une nappe de particules. Chaque calque est PEINT UNE FOIS dans un buffer (ImageData) bakée en
-- Image, puis composée en boucle avec un décalage horizontal `ox = (t*speed) % W`, dessinée DEUX FOIS
-- (à -ox et W-ox) -> défilement tileable sans couture. Déterministe/seedé. 4 biomes (abysses/brasier/
-- ossuaire/floraison) : recettes (build/parts/speeds) + palettes portées telles quelles du JS.
--
-- Couche RENDER (fx) : love.graphics autorisé ici, MAIS la génération du décor est DÉTERMINISTE — RNG
-- SEEDÉ INJECTÉ (love.math.newRandomGenerator(seed)), jamais math.random global ni love.math.random
-- argless. Ordre des calques via la table ORDER + ipairs (jamais pairs pour de l'ordonné). Pur RENDER :
-- ne touche pas la SIM -> golden inchangé par construction.
--
-- FILTRE LINÉAIRE (PAS nearest) sur les Images bakées : le fond est destiné à être FLOU/adouci à
-- l'agrandissement (profondeur de champ), contrairement aux sprites.
--
-- HEADLESS-SAFE (calqué sur src/fx/ambient.lua) : si love.image/love.graphics/newImageData manquent
-- (mock LÖVE des tests), le bake est un NO-OP et draw ne fait RIEN — jamais de crash. Tout en pcall /
-- gardes `if love...`. Le module reste utilisable (update/déterminisme des particules) sans écran.

local Biome = {}
Biome.__index = Biome

local W, H = 192, 108

-- Biomes exposés (ordre stable, pour les menus/sélecteurs).
Biome.KEYS = { "abysses", "brasier", "ossuaire", "floraison" }

-- Ordre de composition des calques (du fond vers l'avant). ipairs -> déterministe.
local ORDER = { "sky", "far", "mid", "near", "ground", "fog" }

-- Matrice de Bayer 4×4 (dithering ordonné), portée telle quelle du JS (valeurs 0..15).
local BAYER = {
  { 0, 8, 2, 10 },
  { 12, 4, 14, 6 },
  { 3, 11, 1, 9 },
  { 15, 7, 13, 5 },
}
-- Accès Bayer en indices JS (0-based) : bayer(x,y) avec x,y entiers quelconques -> repli toroïdal 0..3.
local function bayer(x, y)
  return BAYER[(y % 4) + 1][(x % 4) + 1]
end

-- hex (0xRRGGBB) -> {r,g,b} floats 0..1 (CONVENTION PROJET : couleurs en floats, hex/255).
local function hex2rgb(hex)
  local r = math.floor(hex / 0x10000) % 0x100
  local g = math.floor(hex / 0x100) % 0x100
  local b = hex % 0x100
  return { r / 255, g / 255, b / 255 }
end

-- ─────────────────────────── Détection capacités graphiques (headless-safe) ───────────────────────────
local function canBake()
  return love and love.image and love.image.newImageData
      and love.graphics and love.graphics.newImage
end
local function canDraw()
  return love and love.graphics and love.graphics.draw and love.graphics.setColor
end

-- ─────────────────────────────────── Buffer de calque (Layer) ───────────────────────────────────
-- Un Layer enveloppe un ImageData 192×108. set(x,y,col) pose un pixel (CLIP aux bords, wrap NON — comme
-- le `set` du JS : les callers qui veulent le wrap horizontal font leur propre modulo avant d'appeler).
-- `col` = {r,g,b} (table de couleur déjà convertie). Le bake final n'est fait QU'UNE FOIS (commit).
local Layer = {}
Layer.__index = Layer

local function newLayer()
  -- pcall : sous mock LÖVE, newImageData peut renvoyer un stub sans setPixel réel -> on dégrade.
  local ok, data = pcall(love.image.newImageData, W, H)
  if not ok or not data then return nil end
  return setmetatable({ data = data }, Layer)
end

-- Pose un pixel si DANS les bornes (sinon ignore = clip, comme le JS). x,y peuvent être flottants/négatifs.
function Layer:set(x, y, col)
  x = math.floor(x); y = math.floor(y)
  if x < 0 or x >= W or y < 0 or y >= H then return end
  -- setPixel(x,y, r,g,b,a) — COULEURS EN FLOATS 0..1 (LÖVE 11.x). a=1 (opaque) : on peint en dur.
  pcall(self.data.setPixel, self.data, x, y, col[1], col[2], col[3], 1)
end

-- ─────────────────────────────────── Primitives de peinture (port JS) ───────────────────────────────────
-- Toutes prennent un Layer `L` + une fonction RNG `rnd` (retourne un float [0,1), seedée).

-- vgrad : dégradé vertical dithered Bayer sur [y0,y1). `ramp` = liste de {r,g,b}. Choix d'index par seuil.
local function vgrad(L, ramp, y0, y1)
  y0 = y0 or 0; y1 = y1 or H
  local n = #ramp
  for y = y0, y1 - 1 do
    local f = (y - y0) / (y1 - y0)
    local fi = f * (n - 1)
    local i0 = math.floor(fi)
    local fr = fi - i0
    for x = 0, W - 1 do
      local th = bayer(x, y) / 16
      local idx = i0 + (fr > th and 1 or 0)
      if idx > n - 1 then idx = n - 1 end
      L:set(x, y, ramp[idx + 1]) -- ramp 1-based en Lua
    end
  end
end

-- ridge : crête sinus multi-octave à la baseline `baseY`, amplitude `amp`. `fill`=remplit jusqu'en bas.
local function ridge(L, baseY, amp, color, rnd, oct, fill)
  oct = oct or 3
  local ph, fq, am = {}, {}, {}
  for o = 1, oct do
    ph[o] = rnd() * 6.283
    fq[o] = o          -- o = 1..oct (équivaut au o+1 du JS qui boucle de 0)
    am[o] = amp / o
  end
  for x = 0, W - 1 do
    local v = baseY
    for o = 1, oct do
      v = v + math.sin(x / W * 6.283 * fq[o] + ph[o]) * am[o]
    end
    local yy = math.floor(v + 0.5) -- Math.round
    if fill then
      for y = yy, H - 1 do L:set(x, y, color) end
    else
      L:set(x, yy, color)
      L:set(x, yy + 1, color)
    end
  end
end

-- feature : un relief unique (pilier/colonne d'os/tentacule/champignon/cristal/pic) ancré en x0,baseY.
-- `px(dx,dy)` peint à (x0+dx, dy) en WRAPPANT horizontalement (3 passes : centre + débord gauche/droite),
-- exactement comme le JS (le wrap est porté par la feature, pas par set).
local function feature(L, x0, baseY, size, color, kind, rnd)
  local function px(dx, dy)
    local x = x0 + dx
    L:set(x, dy, color)
    if x >= W then L:set(x - W, dy, color) end
    if x < 0 then L:set(x + W, dy, color) end
  end
  local dx, dy, ww
  if kind == "pillar" then
    local w = 1 + math.floor(size / 7)
    for yy = baseY - size, baseY do
      for d = -w, w do px(d, yy) end
    end
  elseif kind == "bonecol" then
    local bw = 1 + math.floor(size / 9)
    for yy = baseY - size, baseY do
      local b = (math.sin(yy * 0.55) > 0.55) and 1 or 0
      for d = -bw - b, bw + b do px(d, yy) end
    end
  elseif kind == "tentacle" then
    local sway = size * 0.22
    for dyi = 0, size do
      local t = dyi / size
      local cx = math.floor(math.sin(t * 3 + x0) * sway * (1 - t) + 0.5)
      ww = math.max(0, math.floor((1 - t) * size * 0.13 + 0.5))
      for d = -ww, ww do px(cx + d, baseY - dyi) end
    end
  elseif kind == "mushroom" then
    local st = math.max(1, math.floor(size * 0.11 + 0.5))
    -- pied
    local top = math.floor(size * 0.72)
    for dyi = 0, top do
      for d = -st, st do px(d, baseY - dyi) end
    end
    -- chapeau (demi-ellipse)
    local cr = math.floor(size * 0.52 + 0.5)
    local cy = baseY - math.floor(size * 0.72 + 0.5)
    local cyr = math.max(2, math.floor(cr * 0.62 + 0.5))
    for dyi = -cyr, 1 do
      for d = -cr, cr do
        if (d * d) / (cr * cr) + (dyi * dyi) / (cyr * cyr) <= 1.05 then px(d, cy + dyi) end
      end
    end
  elseif kind == "crystal" then
    for dyi = 0, size do
      ww = math.floor((1 - math.abs(dyi / size - 0.42) / 0.6) * size * 0.26 + 0.5)
      if ww < 0 then ww = 0 end
      for d = -ww, ww do px(d, baseY - dyi) end
    end
  elseif kind == "spike" then
    for dyi = 0, size do
      ww = math.floor((1 - dyi / size) * size * 0.3 + 0.5)
      for d = -ww, ww do px(d, baseY - dyi) end
    end
  end
  -- (dx/dy/ww déclarés pour rester proches du JS ; certains kinds n'en usent pas)
  local _ = dx; _ = dy
end

-- featuresRow : `count` features dispersées (x aléatoire, taille [minS,maxS], léger jitter vertical).
local function featuresRow(L, baseY, count, color, kind, rnd, minS, maxS)
  for _ = 1, count do
    local x = math.floor(rnd() * W)
    local s = minS + math.floor(rnd() * (maxS - minS + 1))
    feature(L, x, baseY + math.floor(rnd() * 3), s, color, kind, rnd)
  end
end

-- fog : nappe dithered atténuée aux bords (sur [y0,y1)), densité `density`. Port fidèle du seuil JS.
local function fog(L, y0, y1, color, density, rnd)
  local mid = (y0 + y1) / 2
  local half = (y1 - y0) / 2
  for y = y0, y1 - 1 do
    local edge = 1 - math.abs((y - mid) / half)
    if edge < 0 then edge = 0 end
    for x = 0, W - 1 do
      local th = (bayer(x, y) + ((x * 7 + y * 13) % 4)) / 20
      if th < density * edge then L:set(x, y, color) end
    end
  end
end

-- ground : sol (dégradé Bayer du haut `baseY` vers le bas) + grain de points sombres (ramp[0]).
local function ground(L, baseY, ramp, rnd)
  local n = #ramp
  for y = baseY, H - 1 do
    local f = (y - baseY) / (H - baseY)
    local idx = math.min(n - 1, math.floor(f * n))
    for x = 0, W - 1 do
      local th = bayer(x, y) / 16
      local ii = (th < 0.5) and idx or math.min(n - 1, idx + 1)
      L:set(x, y, ramp[ii + 1])
    end
  end
  local grain = math.floor(W * 0.7)
  for _ = 1, grain do
    L:set(math.floor(rnd() * W), baseY + math.floor(rnd() * (H - baseY)), ramp[1])
  end
end

-- rays : faisceaux obliques (lumière diffuse), `count` rais de pente `slope`, dithered + atténués en bas.
local function rays(L, color, rnd, slope, count)
  local top = math.floor(H * 0.78)
  for _ = 1, count do
    local x0 = rnd() * W
    local w = 4 + math.floor(rnd() * 7)
    for y = 0, top - 1 do
      local cx = x0 + y * slope
      for d = 0, w - 1 do
        local xx = math.floor(cx + d)
        local th = bayer(((xx % 4) + 4) % 4, y) / 16
        if th < 0.22 * (1 - y / top) then
          L:set(((xx % W) + W) % W, y, color)
        end
      end
    end
  end
end

-- cracks : fissures (marche aléatoire sinueuse) près de baseY, `count` fissures.
local function cracks(L, baseY, color, rnd, count)
  for _ = 1, count do
    local x = rnd() * W
    local y = baseY + (rnd() - 0.5) * 8
    local len = 8 + math.floor(rnd() * 22)
    local a = rnd() * 6.283
    for _ = 1, len do
      x = x + math.cos(a)
      y = y + math.sin(a) * 0.4
      a = a + (rnd() - 0.5) * 0.9
      L:set(((math.floor(x) % W) + W) % W, y, color)
      if rnd() < 0.3 then L:set(((math.floor(x) % W) + W) % W, y + 1, color) end
    end
  end
end

-- spikes : pics triangulaires (montants si dir=-1, depuis baseY), `count` pics de taille [minS,maxS].
local function spikes(L, count, baseY, color, rnd, dir, minS, maxS)
  for _ = 1, count do
    local x = math.floor(rnd() * W)
    local s = minS + math.floor(rnd() * (maxS - minS + 1))
    local w0 = math.max(1, math.floor(s * 0.22))
    for d = 0, s do
      local ww = math.floor((1 - d / s) * w0 + 0.5)
      for dx = -ww, ww do
        L:set(((x + dx) % W + W) % W, baseY + dir * d, color)
      end
    end
  end
end

-- particles : nappe de N particules {x,y,vx,vy,ph,tw,color,size}. `color` = {r,g,b} (déjà converti).
local function particles(n, y0, y1, rnd, opt)
  local a = {}
  for i = 1, n do
    a[i] = {
      x = rnd() * W,
      y = y0 + rnd() * (y1 - y0),
      vy = (opt.vy or 0) * (0.5 + rnd()),
      vx = (opt.vx or 0) * (rnd() - 0.5),
      ph = rnd() * 6.283,
      tw = opt.tw or 0,
      color = opt.color,
      size = opt.size or 1,
    }
  end
  return a
end

-- ─────────────────────────────────── Recettes de biomes (port JS) ───────────────────────────────────
-- Palettes converties en floats UNE FOIS (au chargement du module). `build` peint les 6 calques ; `parts`
-- construit la liste de particules ; `speeds` = vitesse de parallaxe par calque. `accent` = teinte signature.
-- IMPORTANT : la couleur passée à une primitive est une TABLE {r,g,b} (déjà convertie), pas un hex.

local function ramp(list)
  local out = {}
  for i, hex in ipairs(list) do out[i] = hex2rgb(hex) end
  return out
end

local BIOMES = {
  abysses = {
    accent = hex2rgb(0x5af0e0),
    pal = {
      sky = ramp({ 0x050f1b, 0x08182a, 0x0c2740, 0x103a58, 0x185468 }),
      far = hex2rgb(0x07121d), mid = hex2rgb(0x0c1e2e), near = hex2rgb(0x091820),
      gr = ramp({ 0x0a161f, 0x06101a, 0x03080f }),
      ray = hex2rgb(0x185468), fog = hex2rgb(0x0c2740),
    },
    build = function(self, L, rnd)
      local P = self.pal
      vgrad(L.sky, P.sky)
      rays(L.sky, P.ray, rnd, 0.55, 5)
      ridge(L.far, 76, 4, P.far, rnd, 3, true)
      featuresRow(L.far, 76, 7, P.far, "tentacle", rnd, 16, 34)
      featuresRow(L.far, 79, 4, P.far, "pillar", rnd, 18, 40)
      ridge(L.mid, 90, 5, P.mid, rnd, 3, true)
      featuresRow(L.mid, 90, 6, P.mid, "tentacle", rnd, 18, 42)
      featuresRow(L.mid, 92, 3, P.mid, "crystal", rnd, 12, 26)
      featuresRow(L.near, 108, 4, P.near, "tentacle", rnd, 30, 56)
      ground(L.ground, 99, P.gr, rnd)
      fog(L.fog, 66, 108, P.fog, 0.55, rnd)
    end,
    parts = function(self, rnd)
      local a = particles(46, 18, 108, rnd, { vy = -0.22, tw = 1, color = hex2rgb(0x9fd8e8), size = 1 })
      local b = particles(16, 30, 100, rnd, { vy = -0.5, tw = 1, color = hex2rgb(0x5af0e0), size = 1 })
      for i = 1, #b do a[#a + 1] = b[i] end
      return a
    end,
    speeds = { sky = 0, far = 1.5, mid = 4, near = 8, ground = 4, fog = 2.5 },
  },

  brasier = {
    accent = hex2rgb(0xff6a1a),
    pal = {
      sky = ramp({ 0x0a0606, 0x1a0a08, 0x30140e, 0x5e2410, 0x9a4014, 0xd66e1e }),
      far = hex2rgb(0x160a08), mid = hex2rgb(0x241008), near = hex2rgb(0x0e0707),
      gr = ramp({ 0xd66e1e, 0x9a4014, 0x5e2410 }),
      spark = hex2rgb(0xffd9a0), crack = hex2rgb(0xffb84a),
      fog1 = hex2rgb(0x9a4014), fog2 = hex2rgb(0x2a1109),
    },
    build = function(self, L, rnd)
      local P = self.pal
      vgrad(L.sky, P.sky)
      ridge(L.far, 80, 5, P.far, rnd, 2, true)
      spikes(L.far, 5, 80, P.far, rnd, -1, 18, 42)
      ridge(L.mid, 90, 4, P.mid, rnd, 2, true)
      spikes(L.mid, 4, 90, P.mid, rnd, -1, 12, 28)
      vgrad(L.ground, P.gr, 93, 108)
      for i = 0, W - 1 do
        if ((i * 5) % 8) < 2 then L.ground:set(i, 93, P.spark) end -- &7 = %8 (i positif)
      end
      cracks(L.ground, 99, P.crack, rnd, 9)
      spikes(L.near, 5, 106, P.mid, rnd, -1, 6, 16)
      fog(L.fog, 84, 97, P.fog1, 0.5, rnd)
      fog(L.fog, 28, 72, P.fog2, 0.32, rnd)
    end,
    parts = function(self, rnd)
      local a = particles(40, 30, 108, rnd, { vy = -0.4, tw = 1, color = hex2rgb(0xff8a3a), size = 1 })
      local b = particles(24, 6, 90, rnd, { vy = 0.25, vx = 0.3, tw = 0, color = hex2rgb(0x6e5a4c), size = 1 })
      for i = 1, #b do a[#a + 1] = b[i] end
      return a
    end,
    speeds = { sky = 0, far = 1.4, mid = 3.8, near = 7.5, ground = 4, fog = 2.2 },
  },

  ossuaire = {
    accent = hex2rgb(0x9af04a),
    pal = {
      sky = ramp({ 0x070907, 0x10130d, 0x1a2014, 0x28321c, 0x3a4a26 }),
      far = hex2rgb(0x0b0d09), mid = hex2rgb(0x14160f), near = hex2rgb(0x0d0e0a),
      gr = ramp({ 0x1a1812, 0x12100c, 0x0a0906 }),
      fog = hex2rgb(0x28321c),
    },
    build = function(self, L, rnd)
      local P = self.pal
      vgrad(L.sky, P.sky)
      ridge(L.far, 80, 3, P.far, rnd, 2, true)
      featuresRow(L.far, 80, 8, P.far, "bonecol", rnd, 26, 48)
      ridge(L.mid, 93, 4, P.mid, rnd, 2, true)
      featuresRow(L.mid, 93, 6, P.mid, "bonecol", rnd, 20, 40)
      featuresRow(L.mid, 94, 3, P.mid, "spike", rnd, 10, 22)
      featuresRow(L.near, 108, 3, P.near, "bonecol", rnd, 34, 56)
      ground(L.ground, 99, P.gr, rnd)
      fog(L.fog, 64, 108, P.fog, 0.5, rnd)
    end,
    parts = function(self, rnd)
      local a = particles(30, 10, 108, rnd, { vy = 0.12, tw = 0, color = hex2rgb(0xc8d0a0), size = 1 })
      local b = particles(14, 40, 100, rnd, { vy = -0.18, vx = 0.2, tw = 1, color = hex2rgb(0x9af04a), size = 1 })
      for i = 1, #b do a[#a + 1] = b[i] end
      return a
    end,
    speeds = { sky = 0, far = 1.2, mid = 3.5, near = 7, ground = 3.5, fog = 2 },
  },

  floraison = {
    accent = hex2rgb(0x5affc8),
    pal = {
      sky = ramp({ 0x0a0814, 0x141022, 0x231a36, 0x34284a, 0x48385e }),
      far = hex2rgb(0x0c0a16), mid = hex2rgb(0x191226), near = hex2rgb(0x110c1c),
      gr = ramp({ 0x1a1428, 0x120c1e, 0x0a0814 }),
      fog = hex2rgb(0x231a36),
    },
    build = function(self, L, rnd)
      local P = self.pal
      vgrad(L.sky, P.sky)
      ridge(L.far, 80, 4, P.far, rnd, 3, true)
      featuresRow(L.far, 80, 7, P.far, "mushroom", rnd, 22, 44)
      ridge(L.mid, 93, 4, P.mid, rnd, 2, true)
      featuresRow(L.mid, 93, 6, P.mid, "mushroom", rnd, 18, 36)
      featuresRow(L.mid, 94, 3, P.mid, "pillar", rnd, 10, 20)
      featuresRow(L.near, 108, 2, P.near, "mushroom", rnd, 38, 58)
      ground(L.ground, 99, P.gr, rnd)
      fog(L.fog, 60, 108, P.fog, 0.5, rnd)
    end,
    parts = function(self, rnd)
      local a = particles(50, 20, 108, rnd, { vy = -0.12, vx = 0.25, tw = 1, color = hex2rgb(0x5affc8), size = 1 })
      local b = particles(20, 30, 100, rnd, { vy = -0.08, vx = 0.4, tw = 1, color = hex2rgb(0xaaff5a), size = 1 })
      for i = 1, #b do a[#a + 1] = b[i] end
      return a
    end,
    speeds = { sky = 0, far = 1.3, mid = 3.6, near = 7, ground = 3.6, fog = 2 },
  },
}

-- ─────────────────────────────────── Construction d'une instance ───────────────────────────────────
-- Biome.new(key, seed) : key invalide -> "abysses". Bake les 6 calques en Image UNE FOIS (filtre linéaire),
-- construit la liste de particules. Déterministe par (key, seed) via RNG seedé injecté.
function Biome.new(key, seed)
  if not BIOMES[key] then key = "abysses" end
  local recipe = BIOMES[key]
  local self = setmetatable({
    key = key,
    seed = seed or 0,
    t = 0,
    recipe = recipe,
    speeds = recipe.speeds,
    accent = recipe.accent,
    images = {},   -- [layerName] = Image bakée (nil si headless / bake raté)
    particles = {},
  }, Biome)

  -- RNG seedé INJECTÉ : un seul générateur consommé dans l'ordre build -> parts (comme le JS), pour que
  -- (key, seed) -> décor + particules reproductibles. Headless : pas de love.math -> RNG nil, parts via
  -- un repli déterministe constant (0.5) ; le décor (images) n'est de toute façon pas baké sans graphics.
  local rng = (love and love.math and love.math.newRandomGenerator)
      and love.math.newRandomGenerator(self.seed) or nil
  local function rnd() return rng and rng:random() or 0.5 end

  -- 1) Bake des calques (seulement si capacités graphiques présentes). On peint dans des Layers, on
  --    consomme le RNG via build(), puis on bake chaque ImageData en Image (filtre LINÉAIRE) UNE FOIS.
  if canBake() then
    pcall(function()
      local layers = {}
      for _, name in ipairs(ORDER) do layers[name] = newLayer() end
      -- Si un Layer a échoué (stub), on saute le build pour éviter d'opérer sur du nil.
      local complete = true
      for _, name in ipairs(ORDER) do if not layers[name] then complete = false end end
      if complete then
        recipe.build(recipe, layers, rnd)
        for _, name in ipairs(ORDER) do
          local img = love.graphics.newImage(layers[name].data)
          -- LINÉAIRE (PAS nearest) : le fond doit s'adoucir à l'agrandissement (profondeur de champ).
          if img.setFilter then img:setFilter("linear", "linear") end
          self.images[name] = img
        end
      end
    end)
  end

  -- 2) Particules : construites dans tous les cas (pures données ; sert au déterminisme headless aussi).
  --    Le RNG continue d'être consommé APRÈS le build (ordre identique au JS).
  self.particles = recipe.parts(recipe, rnd)

  return self
end

-- ─────────────────────────────────── Mise à jour ───────────────────────────────────
-- Avance le temps de parallaxe + intègre les particules (wrap toroïdal comme le JS : x dans [0,W],
-- y dans [-1, H+1]). Pas de love.* ici -> sûr en headless (le déterminisme des particules est testable).
function Biome:update(dt)
  dt = dt or 0
  self.t = self.t + dt
  local step = dt * 60 -- le JS intègre en "frames @60" (vy*dt*60)
  for _, p in ipairs(self.particles) do
    p.y = p.y + p.vy * step
    p.x = p.x + p.vx * step
    -- wrap horizontal [0,W]
    if p.x < 0 then p.x = p.x + W elseif p.x >= W then p.x = p.x - W end
    -- wrap vertical [-1, H+1]
    if p.y < -1 then p.y = p.y + (H + 2) elseif p.y > H + 1 then p.y = p.y - (H + 2) end
  end
end

-- ─────────────────────────────────── Rendu ───────────────────────────────────
-- Compose les 6 calques (chacun à sa vitesse de parallaxe, dessiné 2× pour le wrap sans couture) ÉTIRÉS
-- pour remplir le rect (dx,dy,dw,dh) de l'espace de coordonnées COURANT, puis les particules par-dessus.
-- N'ouvre PAS de Draw.begin : dessine dans le transform courant (le caller fournit le rect, ex. 0,0,1280,720
-- en espace design). Headless : canDraw() faux -> NO-OP (jamais de crash).
function Biome:draw(dx, dy, dw, dh)
  if not canDraw() then return end
  dx = dx or 0; dy = dy or 0; dw = dw or W; dh = dh or H
  local sx = dw / W  -- échelle horizontale (étirement pour remplir le rect)
  local sy = dh / H  -- échelle verticale
  local t = self.t

  -- Calques : pour chacun, ox = (t*speed) % W (en pixels VIRTUELS), dessiné à -ox et W-ox -> tileable.
  -- L'offset horizontal est mis à l'échelle (×sx) puisque le rect d'arrivée est étiré.
  for _, name in ipairs(ORDER) do
    local img = self.images[name]
    if img then
      local speed = self.speeds[name] or 0
      local ox = 0
      if speed ~= 0 then ox = (t * speed) % W end
      love.graphics.setColor(1, 1, 1, 1)
      -- draw(image, x, y, r, sx, sy) : sx/sy = facteurs d'échelle (étirement de l'Image au rect).
      love.graphics.draw(img, dx + (-ox) * sx, dy, 0, sx, sy)
      love.graphics.draw(img, dx + (W - ox) * sx, dy, 0, sx, sy)
    end
  end

  -- Particules par-dessus : position virtuelle -> écran via (sx,sy) ; alpha scintillant (tw) ; carré `size`.
  for _, p in ipairs(self.particles) do
    local alpha = 1
    if p.tw and p.tw ~= 0 then
      alpha = 0.45 + 0.55 * math.sin(p.ph + t * 3)
    end
    if alpha >= 0.4 then
      local c = p.color
      love.graphics.setColor(c[1], c[2], c[3], alpha)
      local px = dx + p.x * sx
      local py = dy + p.y * sy
      love.graphics.rectangle("fill", px, py, p.size * sx, p.size * sy)
    end
  end

  love.graphics.setColor(1, 1, 1, 1)
end

return Biome
