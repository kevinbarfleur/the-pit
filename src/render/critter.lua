-- src/render/critter.lua
-- RENDU VIVANT des créatures — port du prototype HTML (`blit`/`disp`). Au lieu de transformer un sprite BAKÉ
-- figé, on re-dessine la GRILLE 64×64 à CHAQUE frame avec un déplacement PAR PIXEL propre à la famille
-- (respiration, balancement planté aux pieds, lévitation, ailes qui battent, tentacules, ondulation) + un
-- overlay des YEUX (clignement + saccade de pupille). Rendu en CADRE NATIF : échelle UNIFORME (cadre→boîte),
-- donc les tailles RELATIVES et le placement vertical des créatures sont CONSERVÉS (contrairement au fit-
-- silhouette qui zoome tout le monde pareil). Ombre au sol pour ancrer la baseline (les flottants la laissent
-- au sol → lecture de lévitation).
--
-- Couche RENDER (love.graphics) — hors firewall SIM. HEADLESS-SAFE : no-op sans SpriteBatch (mock LÖVE).
-- DÉTERMINISTE PAR ID : grille via CreatureGen.cachedLive (MÊME résolution famille/arch/palette/seed que la
-- version bakée → visuel identique). `t` = horloge en SECONDES (fréquences = celles du proto, en rad/s).

local CreatureGen = require("src.gen.creaturegen")
local Units = require("src.data.units")
local Creatures = require("src.data.creatures")

local Critter = {}
local sin, cos, floor, abs, max = math.sin, math.cos, math.floor, math.abs, math.max

local CELL = 1.3 -- léger sur-dessin de chaque cellule (couvre les trous quand les pixels se déplacent)

-- ── Profils de mouvement PAR FAMILLE (port direct de `PROF` du proto) ──
-- amplitudes en px de grille, fréquences en rad/s. eyes = { blink, dart } (dart absent -> 1.4 ; comme le proto).
local PROF_DEFAULT = { breathe = { 0.018, 1.8 }, eyes = { 0.9, 1.3 } }
local PROF = {
  -- amorphes / chair molle
  cauchemar   = { breathe = { 0.03, 1.6 }, eyes = { 0.8, 1.2 } },
  gelatine    = { breathe = { 0.05, 2.2 }, eyes = { 0.8, 1.2 } },
  larve       = { writhe = { 0.8, 2.8 }, breathe = { 0.04, 2.2 }, eyes = { 1.1 } },
  cocon       = { breathe = { 0.045, 1.4 }, eyes = { 0.6, 1.0 } },
  chimere     = { writhe = { 0.7, 2.6 }, breathe = { 0.03, 1.8 }, eyes = { 0.9, 1.5 } },
  -- marcheurs / bêtes
  bete        = { legs = { 0.7, 3.0 }, breathe = { 0.02, 2.0 }, eyes = { 0.9, 1.2 } },
  demon       = { sway = { 1.0, 1.8 }, breathe = { 0.02, 2.0 }, eyes = { 0.8, 1.3 } },
  colosse     = { legs = { 0.6, 2.4 }, breathe = { 0.025, 1.8 }, eyes = { 0.8, 1.1 } },
  canide      = { legs = { 0.55, 3.2 }, breathe = { 0.03, 2.6 }, eyes = { 1.0, 1.3 } },
  bandit      = { breathe = { 0.022, 2.0 }, sway = { 0.4, 1.4 }, eyes = { 1.0, 1.6 } },
  culte       = { sway = { 0.8, 1.6 }, breathe = { 0.02, 1.8 }, eyes = { 0.9 } },
  inquisiteur = { sway = { 0.6, 1.6 }, breathe = { 0.02, 1.7 }, eyes = { 0.8 } },
  templier    = { legs = { 0.35, 2.0 }, breathe = { 0.02, 1.7 }, eyes = { 0.8 } },
  wendigo     = { sway = { 0.7, 1.5 }, breathe = { 0.025, 1.6 }, eyes = { 0.8, 1.2 } },
  echassier   = { legs = { 0.6, 2.2 }, sway = { 0.7, 1.6 }, eyes = { 0.9, 1.3 } },
  -- os / minéral / mécanique (quasi statiques)
  mortvivant  = { legs = { 0.5, 3.2 }, writhe = { 0.3, 2.2 }, eyes = { 1.1 } },
  crane       = { breathe = { 0.015, 1.2 }, eyes = { 0.6, 1.6 } },
  cristal     = { breathe = { 0.02, 1.4 }, eyes = { 0.7, 1.0 } },
  golem       = { legs = { 0.4, 2.2 }, eyes = { 0.7 } },
  automate    = { legs = { 0.4, 2.6 }, eyes = { 0.5, 1.0 } },
  -- segmentés / nerveux
  insecte     = { legs = { 0.5, 4.2 }, writhe = { 0.4, 3.0 }, eyes = { 1.0 } },
  arachnide   = { legs = { 0.6, 3.6 }, breathe = { 0.025, 2.0 }, eyes = { 1.0 } },
  crustace    = { legs = { 0.5, 3.4 }, breathe = { 0.025, 2.0 }, eyes = { 0.9, 1.5 } },
  rongeur     = { breathe = { 0.045, 3.6 }, legs = { 0.4, 4.0 }, eyes = { 1.4 } },
  -- reptiles / vers / hydres / plantes (ondulation)
  reptile     = { sway = { 1.0, 1.8 }, breathe = { 0.02, 1.8 }, eyes = { 0.8, 1.4 } },
  annelide    = { sway = { 1.2, 2.0 }, breathe = { 0.025, 1.8 }, eyes = { 0.9 } },
  hydre       = { sway = { 1.1, 1.9 }, breathe = { 0.02, 1.7 }, eyes = { 0.9, 1.4 } },
  plante      = { sway = { 0.9, 1.6 }, breathe = { 0.035, 1.8 }, eyes = { 0.9, 1.3 } },
  spore       = { sway = { 0.7, 1.5 }, breathe = { 0.03, 1.6 }, eyes = { 0.9 } },
  -- FLOTTANTS : lévitation d'ensemble (bob) + signature
  oeil        = { bob = { 0.9, 1.5 }, breathe = { 0.02, 1.7 }, eyes = { 0.9, 1.5 } },
  ombre       = { bob = { 1.4, 1.4 }, breathe = { 0.04, 1.6 }, eyes = { 0.9, 1.8 } },
  spectre     = { bob = { 1.4, 1.5 }, sway = { 1.2, 1.2 }, eyes = { 0.8 } },
  aile        = { flap = { 0.22, 3.6, 0.06 }, bob = { 1.2, 1.8 }, eyes = { 0.9, 1.3 } },
  seraphin    = { flap = { 0.2, 3.0, 0.05 }, bob = { 1.2, 1.5 }, eyes = { 0.9, 1.6 } },
  griffon     = { legs = { 0.5, 2.8 }, flap = { 0.14, 3.2, 0.04 }, eyes = { 0.9, 1.2 } },
  meduse      = { bob = { 1.3, 1.6 }, tentacles = { 1.2, 2.0 }, breathe = { 0.04, 1.8 }, eyes = { 0.9 } },
  essaim      = { writhe = { 0.8, 3.2 }, bob = { 0.8, 1.6 }, eyes = { 1.2 } },
  abyssal     = { bob = { 1.0, 1.6 }, tentacles = { 1.0, 2.2 }, eyes = { 0.9, 1.5 } },
  cephalo     = { tentacles = { 1.3, 2.4 }, breathe = { 0.03, 1.8 }, eyes = { 0.9, 1.4 } },
  kraken      = { sway = { 1.2, 2.0 }, tentacles = { 1.3, 2.2 }, eyes = { 0.9, 1.4 } },
  pendu       = { bob = { 1.2, 1.3 }, sway = { 1.0, 1.1 }, eyes = { 0.8 } },
}

-- Déplacement PAR PIXEL (x,y) -> (dx,dy) en coords de grille. Port fidèle de `disp` du proto.
local function makeDisp(t, m, cx, cy, bodyR, bellyY, groundY, headSpan)
  return function(x, y)
    local dx, dy = 0, 0
    if m.bob then dy = dy + m.bob[1] * sin(t * m.bob[2]) end
    if m.breathe then
      local s = m.breathe[1] * sin(t * m.breathe[2]); dx = dx + (x - cx) * s; dy = dy + (y - cy) * s
    end
    if m.sway then
      local f = max(0, groundY - y) / headSpan; dx = dx + m.sway[1] * sin(t * m.sway[2] + y * 0.16) * f
    end
    if m.legs and y > cy then
      local side = (x < cx) and -1 or 1; dy = dy + m.legs[1] * sin(t * m.legs[2]) * side
    end
    if m.flap then
      local d = abs(x - cx)
      if d > bodyR * 0.9 then
        local wf = d - bodyR * 0.9
        dy = dy - wf * m.flap[1] * sin(t * m.flap[2])
        dx = dx + ((x < cx) and 1 or -1) * wf * (m.flap[3] or 0) * (0.5 + 0.5 * sin(t * m.flap[2]))
      end
    end
    if m.tentacles and y > bellyY then
      dx = dx + m.tentacles[1] * sin(t * m.tentacles[2] + y * 0.45 + x * 0.3)
    end
    if m.writhe then
      dx = dx + m.writhe[1] * sin(t * m.writhe[2] + y * 0.6)
      dy = dy + m.writhe[1] * 0.5 * cos(t * m.writhe[2] + x * 0.5)
    end
    return dx, dy
  end
end

-- 1×1 blanc bake une fois : teinté par cellule via SpriteBatch:setColor (un seul draw call par créature).
local PIXEL
local function pixel()
  if PIXEL then return PIXEL end
  local idata = love.image.newImageData(1, 1)
  idata:setPixel(0, 0, 1, 1, 1, 1)
  PIXEL = love.graphics.newImage(idata)
  PIXEL:setFilter("nearest", "nearest")
  return PIXEL
end

local function unpack3(cc) return (floor(cc / 65536) % 256) / 255, (floor(cc / 256) % 256) / 255, (cc % 256) / 255 end

-- Une créature dessinée-main (Creatures[id]) n'a pas de grille -> non rendable en vivant (le caller retombe sur Rig).
function Critter.has(id) return not (Creatures and Creatures[id]) end

-- Données de rendu mémoïsées par id : liste de cellules opaques {x,y,r,g,b}, yeux, anatomie, palette, profil, bounds.
local cache = {}
local function info(id)
  local c = cache[id]
  if c then return c end
  local spec = Units[id] or {}
  local ok, d = pcall(CreatureGen.cachedLive,
    { id = id, type = spec.type, family = spec.family, effects = spec.effects, rank = spec.rank })
  if not ok or not d or not d.grid then return nil end
  local data, W, H = d.grid, d.w, d.h
  local cells, n, minX, maxX = {}, 0, W, 0
  for y = 0, H - 1 do
    local row = y * W
    for x = 0, W - 1 do
      local cc = data[row + x]
      if cc then
        local r, g, b = unpack3(cc)
        n = n + 1; cells[n] = { x, y, r, g, b }
        if x < minX then minX = x end
        if x > maxX then maxX = x end
      end
    end
  end
  local A = d.A or {}
  local cx, cy, bodyR = 32, 34, 10
  if A.mass and A.mass[1] then cx, cy, bodyR = A.mass[1][1], A.mass[1][2], A.mass[1][3] end
  local bellyY = (A.belly and A.belly.y) or 42
  local groundY = 57
  local er, eg, eb = unpack3((d.p and d.p.eye) or 0xffffff)
  local or_, og, ob = unpack3((d.p and d.p.out) or 0x000000)
  local sr, sg, sb = unpack3((d.p and d.p.sh) or 0x444444)
  c = {
    cells = cells, eyes = d.eyes or {}, h = H,
    cx = cx, cy = cy, bodyR = bodyR, bellyY = bellyY, groundY = groundY,
    headSpan = max(1, groundY - (cy - bodyR - 6)),
    halfW = max(4, (maxX - minX) / 2),
    float = A.float and true or false,
    prof = PROF[d.family] or PROF_DEFAULT,
    eyeCol = { er, eg, eb }, outCol = { or_, og, ob }, shCol = { sr, sg, sb },
  }
  cache[id] = c
  return c
end

-- DESSINE `id` dans la boîte (x,y,boxW,boxH) en ESPACE DESIGN, à l'échelle UNIFORME du cadre natif (les tailles
-- relatives sont conservées). t = secondes. facing : 1 = vers la droite, -1 = miroir. fill (0..~1.2) : remplissage
-- du cadre dans la hauteur de boîte (défaut 1.0). Pieds ancrés ~en bas de la boîte (via groundY du cadre).
function Critter.draw(view, id, x, y, boxW, boxH, t, facing, fill)
  if not (love.graphics and love.graphics.newSpriteBatch and love.graphics.newImage) then return end
  local c = info(id)
  if not c or #c.cells == 0 then return end
  t = t or 0
  facing = (facing == -1) and -1 or 1
  fill = fill or 1.0
  local scale = (boxH / c.h) * fill
  if not c.batch then c.batch = love.graphics.newSpriteBatch(pixel(), #c.cells, "stream") end
  local disp = makeDisp(t, c.prof, c.cx, c.cy, c.bodyR, c.bellyY, c.groundY, c.headSpan)

  local b = c.batch
  b:clear()
  local off = (CELL - 1) * 0.5
  for i = 1, #c.cells do
    local cell = c.cells[i]
    local dx, dy = disp(cell[1], cell[2])
    b:setColor(cell[3], cell[4], cell[5], 1)
    b:add(cell[1] + dx - off, cell[2] + dy - off, 0, CELL, CELL)
  end
  b:setColor(1, 1, 1, 1)

  love.graphics.push()
  if facing < 0 then
    love.graphics.translate(x + boxW * 0.5 + 32 * scale, y); love.graphics.scale(-scale, scale)
  else
    love.graphics.translate(x + boxW * 0.5 - 32 * scale, y); love.graphics.scale(scale, scale)
  end

  -- ombre au sol (subtile) ; les flottants la laissent en bas pendant qu'ils montent -> lecture de lévitation
  love.graphics.setColor(0, 0, 0, 0.22)
  love.graphics.ellipse("fill", 32, c.groundY + (c.float and 3 or 1), c.halfW * 1.05, c.float and 1.6 or 2.4)
  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.draw(b, 0, 0)

  -- yeux PAR-DESSUS : clignement (carré sombre) ou globe + saccade de pupille
  local e = c.prof.eyes
  if e and #c.eyes > 0 then
    local blink, dart = e[1] or 0.9, e[2] or 1.4
    for k = 1, #c.eyes do
      local ey = c.eyes[k]
      local ddx, ddy = disp(ey[1], ey[2])
      local qx, qy, r = ey[1] + ddx, ey[2] + ddy, ey[3]
      local ph = ey[1] * 1.3 + ey[2] * 0.7
      if sin(t * blink + ph) > 0.93 then
        love.graphics.setColor(c.shCol[1], c.shCol[2], c.shCol[3], 1)
        love.graphics.rectangle("fill", qx - r, qy - r, 2 * r + 1, 2 * r + 1)
      elseif r >= 2 then
        love.graphics.setColor(c.eyeCol[1], c.eyeCol[2], c.eyeCol[3], 1)
        local rr = r - 1
        love.graphics.rectangle("fill", qx - rr, qy - rr, 2 * rr + 1, 2 * rr + 1)
        local pdx, pdy = floor(sin(t * dart + ph) + 0.5), floor(cos(t * dart * 1.3 + ph) + 0.5)
        local pr = (r >= 3) and 1 or 0
        love.graphics.setColor(c.outCol[1], c.outCol[2], c.outCol[3], 1)
        love.graphics.rectangle("fill", qx + pdx - pr, qy + pdy - pr, 2 * pr + 1, 2 * pr + 1)
      end
    end
  end

  love.graphics.pop()
  love.graphics.setColor(1, 1, 1, 1)
end

-- Réinitialise le cache (changement de palette / tests). La grille live elle-même est cachée côté CreatureGen.
function Critter.clear() cache = {}; PIXEL = nil end

return Critter
