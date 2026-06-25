-- src/render/relic_anim.lua
-- RENDU ANIMÉ DES RELIQUES — port Lua/LÖVE de drawRelic() (docs/generation/generateur-reliques.html).
-- Couche RENDER (love.graphics autorisé) — hors firewall SIM. HEADLESS-SAFE : no-op sans SpriteBatch (mock).
--
-- ── PRINCIPE (calqué sur src/render/critter.lua) ─────────────────────────────────────────────────────
-- La grille COLORÉE 40×40 (RelicGen.view(id).g) est re-dessinée à CHAQUE frame avec une DÉFORMATION PAR
-- PIXEL propre à l'anim (beat/pulse/sway/flick/chatter/drift/coinspin/dig/echo) via UN SpriteBatch (1×1
-- blanc baké une fois, teinté par-cellule -> UN seul draw call par relique). Les COUCHES OVERLAY (flammes,
-- gouttes, spores, étincelles, halos…) sont des particules CHEAP (4-10 quads) dessinées en immédiat
-- (love.graphics.rectangle), comme les `blk()` du HTML. On NE fait JAMAIS du fillRect par-pixel/frame.
--
-- On dessine en ESPACE GRILLE (unités 0..40) : le caller pose le transform (push/translate(x,y)/scale) ; le
-- batch ajoute chaque pixel à (px,py) taille 1×1 (léger sur-dessin pour couvrir les trous de déplacement),
-- et `blk(gx,gy,s,col,al)` = rectangle("fill",gx,gy,s,s). Pixel-perfect : le scale est posé par le caller.
--
-- ── API ──────────────────────────────────────────────────────────────────────────────────────────────
--   RelicAnim.draw(view, id, x, y, scale, t [, palette])
--     view    : canvas virtuel courant (compat de signature ; non lu — on dessine dans le transform du caller)
--     id      : id de relique (RelicGen.view(id) fournit la grille + les métadonnées d'anim)
--     x, y    : coin haut-gauche en ESPACE DESIGN où poser le sprite 40×40 (×scale)
--     scale   : échelle entière conseillée (net) ; floats acceptés
--     t       : horloge en SECONDES (les fréquences sont celles du proto, en rad/s)
--     palette : ACCEPTÉ pour compat d'appel (ignoré : la relique porte sa palette)
--   RelicAnim.clear() : réinitialise les SpriteBatch cachés (changement de contexte LÖVE / tests).
--
--   Réf API (vérifiée via love-api 11.5) : love.graphics.newSpriteBatch(image, max, "stream") ;
--   SpriteBatch:add(x,y,r,sx,sy) -> id ; SpriteBatch:setColor(r,g,b,a) (prochains add) ; SpriteBatch:clear().

local RelicGen = require("src.gen.relicgen")

local RelicAnim = {}

local sin, cos, abs, floor, min, max = math.sin, math.cos, math.abs, math.floor, math.min, math.max

local CELL = 1.32 -- léger sur-dessin de chaque cellule (couvre les trous quand les pixels se déplacent)

-- 1×1 blanc baké une fois (teinté par-cellule via SpriteBatch:setColor) — comme critter.lua.
local PIXEL
local function pixel()
  if PIXEL then return PIXEL end
  local idata = love.image.newImageData(1, 1)
  idata:setPixel(0, 0, 1, 1, 1, 1)
  PIXEL = love.graphics.newImage(idata)
  if PIXEL.setFilter then PIXEL:setFilter("nearest", "nearest") end
  return PIXEL
end

-- has(anim, tag) : l'anim contient-elle ce tag ? (la liste est courte -> boucle linéaire, pas de set.)
local function has(A, tag)
  for i = 1, #A do if A[i] == tag then return true end end
  return false
end

-- _h2(x,y) : bruit pseudo-aléatoire déterministe (port de _h2 du HTML : fract(sin(...)·43758.5453)).
local function _h2(x, y)
  local n = sin(x * 12.9898 + y * 78.233) * 43758.5453
  return n - floor(n)
end

-- État RENDER mémoïsé par id : la grille (cells {x,y,r,g,b}) + le batch + les métadonnées d'anim.
local cache = {}
local function info(id)
  local c = cache[id]
  if c then return c end
  local view = RelicGen.view(id)
  if not view or not view.g then return nil end
  local g = view.g
  local cells, n = {}, 0
  for y = 0, g.h - 1 do
    local row = y * g.w
    for x = 0, g.w - 1 do
      local col = g.data[row + x + 1]
      if col then n = n + 1; cells[n] = { x, y, col[1], col[2], col[3] } end
    end
  end
  c = { cells = cells, view = view, anim = view.anim, pal = view.pal }
  cache[id] = c
  return c
end

-- Remplit le SpriteBatch en ESPACE GRILLE selon l'anim, à l'instant t. Port fidèle du bloc per-pixel de
-- drawRelic (bs/sxMul/digDY/sway/drift/flick/chatter/echo). Le batch contient le CORPS déformé.
local function fillBatch(c, t)
  if not c.batch then c.batch = love.graphics.newSpriteBatch(pixel(), #c.cells + 4, "stream") end
  local A, cx, cy = c.anim, 20, 20
  local b = c.batch
  b:clear()

  -- facteurs globaux (port).
  local bs = 1
  if has(A, "beat") then bs = bs + 0.05 * sin(t * 3.2) end
  if has(A, "pulse") then bs = bs + 0.03 * sin(t * 2.0) end
  local sxMul = has(A, "coinspin") and (0.5 + 0.5 * abs(cos(t * 1.8))) or 1
  local digDY = has(A, "dig") and max(0, sin(t * 3)) * 3 or 0

  -- ECHO : pré-passe — fantôme décalé (faible alpha) AVANT le corps (port : dessiné en premier).
  if has(A, "echo") then
    local ex = sin(t * 3) * 3.2
    local ea = 0.26 * (0.5 + 0.5 * cos(t * 3))
    for i = 1, #c.cells do
      local cell = c.cells[i]
      b:setColor(cell[3], cell[4], cell[5], ea)
      b:add(cell[1] + ex, cell[2], 0, CELL, CELL)
    end
  end

  -- bruit de cliquetis (chatter) : translation entière commune par micro-pas (port _h2 ((t*16)|0)).
  local ti = floor(t * 16)
  local ch = has(A, "chatter") and (_h2(ti, 3) - 0.5) * 0.9 or 0
  local chy = has(A, "chatter") and (_h2(7, ti) - 0.5) * 0.9 or 0

  -- corps déformé.
  local off = (CELL - 1) * 0.5
  for i = 1, #c.cells do
    local cell = c.cells[i]
    local xx, yy = cell[1], cell[2]
    local px = cx + (xx - cx) * bs * sxMul
    local py = cy + (yy - cy) * bs + digDY
    if has(A, "sway") then px = px + sin(t * 2.2 + yy * 0.3) * 1.3 * max(0, (yy - 6) / 26) end
    if has(A, "drift") then px = px + sin(t * 1.6 + yy * 0.25) * 0.9; py = py + sin(t * 1.3 + xx * 0.1) * 0.5 end
    if has(A, "flick") and yy < 15 then px = px + sin(t * 9 + yy * 0.4) * 1.8 * ((15 - yy) / 9) end
    px = px + ch; py = py + chy
    b:setColor(cell[3], cell[4], cell[5], 1)
    b:add(px - off, py - off, 0, CELL, CELL)
  end
  b:setColor(1, 1, 1, 1)
end

-- blk(gx,gy,s,col,al) : un quad plein en ESPACE GRILLE (port de blk() du HTML). col = {r,g,b}.
local G -- love.graphics courant (posé en draw)
local function blk(gx, gy, s, col, al)
  if al == nil then al = 1 elseif al < 0 then al = 0 elseif al > 1 then al = 1 end
  G.setColor(col[1], col[2], col[3], al)
  G.rectangle("fill", floor(gx), floor(gy), max(1, floor(s + 0.5)), max(1, floor(s + 0.5)))
end

-- Couches OVERLAY (port fidèle des `if(has(A,'…'))` de drawRelic). Particules cheap en immédiat.
local DARK1 = { 0x10 / 255, 0x0a / 255, 0x14 / 255 } -- '#100a14'
local WHITE = { 1, 1, 1 }
local STRIKE = { 0x7d / 255, 0x14 / 255, 0x26 / 255 } -- '#7d1426'
local SEALA = { 0xff / 255, 0x72 / 255, 0x83 / 255 }  -- '#ff7283'
local SEALB = { 0x2a / 255, 0x18 / 255, 0x40 / 255 }  -- '#2a1840'
local DIGC = { 0x3a / 255, 0x20 / 255, 0x14 / 255 }   -- '#3a2014'
local MISTC = { 0x8a / 255, 0x90 / 255, 0xa4 / 255 }  -- '#8a90a4'

local function overlays(c, t)
  local A, p = c.anim, c.pal
  local v = c.view
  local cx, cy = 20, 20

  if has(A, "flicker") then
    local fp = v.flamePal or p
    for i = 0, 3 do
      local jx = sin(t * 12 + i * 1.7) * 2.2 * (1 - i * 0.18)
      local jy = -abs(sin(t * 9 + i)) * 2
      blk(cx + jx + (i - 1.5) * 1.5, v.flameTop + jy + i * 0.6, (i < 2) and 2 or 1, (i % 2 == 1) and fp.accent or fp.hi, 0.9)
    end
    local ey = (t * 8) % 14
    blk(cx + sin(t * 3) * 3, v.flameBase - ey, 1, fp.accent, 1 - ey / 14)
  end

  if has(A, "drip") then
    local dpp = v.dropPal
    local d = (t * 9) % 18
    local a = (d < 2) and d / 2 or ((d > 14) and (18 - d) / 4 or 1)
    blk(v.dripX, v.dripY + d, (d < 2) and 1 or 2, dpp.accent, a)
    blk(v.dripX, v.dripY + d - 1, 1, dpp.hi, a * 0.8)
    blk(v.dripX, v.dripY, 1, dpp.accent, 0.6 + 0.4 * sin(t * 5))
  end

  if has(A, "spore") then
    for i = 0, 5 do
      local ph = (t * 0.6 + i * 0.6) % 1
      blk(20 + sin(i * 2 + t) * 9, 18 - ph * 16, 1, p.accent, (1 - ph) * 0.7)
    end
  end

  if has(A, "spark") then
    local sph = (t * 2.2) % 1
    if sph < 0.3 then
      for i = 0, 3 do
        local ds = sph / 0.3 * (4 + i * 2)
        blk(24 + ds, 18 - ds * 0.6 - i, 1, (i % 2 == 1) and p.accent or p.hi, 1 - sph / 0.3)
      end
    end
  end

  if has(A, "blink") then
    for xx = -2, 2 do for yy = -2, 2 do if xx * xx + yy * yy <= 4 then blk(cx + xx, cy + yy, 1, p.accent, 1) end end end
    local gz = floor(sin(t * 0.9) * 2 + 0.5)
    local gy = floor(sin(t * 0.6) * 1 + 0.5)
    blk(cx + gz - 1, cy + gy - 1, 2, DARK1, 1)
    blk(cx + gz - 1, cy + gy - 1, 1, WHITE, 0.9)
    local bl = sin(t * 0.7)
    if bl > 0.93 then
      for xx = -12, 12 do for yy = -7, 7 do if (xx * xx) / 169 + (yy * yy) / 49 <= 1 then blk(cx + xx, cy + yy, 1, p.sh, 1) end end end
    end
  end

  if has(A, "harden") then
    local hh = 0.5 + 0.5 * sin(t * 1.6)
    for k = -2, 2 do
      local rxp = 20 + k * 5
      for yy = -8, 2 do if (rxp - 20) * (rxp - 20) / 169 + (yy * yy) / 121 <= 1 then blk(rxp, 21 + yy, 1, p.hi, hh * 0.4) end end
    end
  end

  if has(A, "brew") then
    local lq = v.liquid or p
    for i = 0, 4 do
      local ph = (t * 0.7 + i * 0.37) % 1
      local bx = 14 + _h2(i, 2) * 12
      local by = 29 - ph * 7
      if ph < 0.85 then blk(bx, by, 1, (i % 2 == 1) and lq.accent or lq.hi, (1 - ph) * 0.85) end
      if ph > 0.8 and ph < 0.95 then blk(bx - 1, 22, 1, lq.hi, 0.6); blk(bx + 1, 22, 1, lq.hi, 0.6) end
    end
  end

  if has(A, "chant") then
    for k = 0, 2 do
      local mx = 10 + k * 10
      local cl = 0.5 + 0.5 * sin(t * 3 + k * 2.1)
      local amt = floor(cl * 4 + 0.5)
      for i = 0, amt - 1 do
        for xx = -2, 2 do blk(mx + xx, cy - 5 + i, 1, p.sh, 1); blk(mx + xx, cy + 5 - i, 1, p.sh, 1) end
      end
      if cl < 0.18 then blk(mx, cy - 9 - floor((0.18 - cl) * 10 + 0.5), 1, p.hi, 0.5) end
    end
  end

  if has(A, "bristle") then
    for i = -2, 2 do
      local tx = 20 + i * 5
      local pb = sin(t * 4 + i * 1.3)
      if pb > 0.5 then blk(tx, 5, 1, p.accent, (pb - 0.5) * 2); blk(tx, 4, 1, p.accent, (pb - 0.5) * 1.5) end
    end
  end

  if has(A, "barrier") then
    local seg = 10
    for i = 0, seg - 1 do
      local an = t * 1.5 + i / seg * 6.283
      blk(20 + cos(an) * 13, 20 + sin(an) * 12.4, 1, p.accent, 0.5 + 0.3 * sin(an * 2))
    end
    local fb = (t * 0.7) % 1
    if fb < 0.12 then
      for i = 0, seg * 2 - 1 do
        local an = i / (seg * 2) * 6.283
        blk(20 + cos(an) * 13, 20 + sin(an) * 12.4, 1, p.hi, (0.12 - fb) / 0.12)
      end
    end
  end

  if has(A, "ward") then
    local pw = 0.4 + 0.6 * (0.5 + 0.5 * sin(t * 3))
    local wp = { { 22, 12 }, { 21, 15 }, { 20, 18 }, { 19, 22 }, { 20, 25 }, { 22, 29 }, { 18, 24 }, { 16, 25 } }
    for i = 1, #wp do blk(wp[i][1], wp[i][2], 1, p.accent, pw) end
    local wsx = (t * 1.3) % 1
    if wsx < 0.4 then blk(19 + sin(t * 9) * 2, 22 - wsx * 6, 1, p.hi, (0.4 - wsx) / 0.4) end
  end

  if has(A, "waveflow") then
    for k = 0, 1 do
      local yp = ((t * 0.5) + k * 0.5) % 1
      local wy = 28 - yp * 16
      for xx = -6, 6 do blk(20 + xx, wy + floor(sin(xx * 0.6 + t * 3) * 1.2 + 0.5), 1, p.hi, (1 - abs(yp - 0.5) * 1.4) * 0.7) end
    end
  end

  if has(A, "strike") then
    local nL = 7
    local pr = (t * 0.55) % 1
    local act = floor(pr * nL)
    for i = 0, min(act, nL - 1) do
      local ly = floor(cy + (i - 3) * 2.6 + 0.5)
      local fr = (i < act) and 1 or (pr * nL - act)
      local x1 = floor(13 + fr * 12 + 0.5)
      for xx = 13, x1 do blk(xx, ly, 1, STRIKE, 0.9) end
    end
  end

  if has(A, "sealpulse") then
    local sp2 = 0.55 + 0.45 * sin(t * 4)
    blk(20, 21, 2, SEALA, sp2 * 0.5)
    for i = 0, 3 do
      local ph = (t * 0.5 + i * 0.25) % 1
      blk(20 + sin(i * 2 + t * 2) * (1 + ph * 3), 14 - ph * 10, 1, SEALB, (1 - ph) * 0.6)
    end
  end

  if has(A, "pageflip") then
    local pp = (t * 0.6) % 1
    local lf = (pp < 0.5) and pp * 2 or (1 - pp) * 2
    local s2 = floor(lf * 6 + 0.5)
    for i = 0, s2 - 1 do blk(28 - i, 10 + i, 1, p.hi, 0.9); blk(28 - i, 11 + i, 1, p.base, 0.7) end
  end

  if has(A, "coinpop") then
    for i = 0, 2 do
      local ph = (t * 0.8 + i * 0.5) % 1
      local bx = 16 + i * 4
      local by = 8 + ph * 13
      if ph < 0.9 then blk(bx, by, 2, p.hi, 1); blk(bx + 1, by, 1, p.accent, 0.9) else blk(bx, 22, 1, p.accent, 0.7) end
    end
  end

  if has(A, "coinspin") then
    local sxMul = 0.5 + 0.5 * abs(cos(t * 1.8))
    if sxMul > 0.88 then blk(20 + sin(t * 1.8) * 8, 20, 1, p.accent, 0.9) end
  end

  if has(A, "dig") then
    local ht = sin(t * 3)
    if ht > 0.7 then
      for i = 0, 3 do
        local ag = -0.3 - i * 0.45
        local sp = (ht - 0.7) / 0.3
        blk(20 + cos(ag) * sp * 8, 33 - abs(sin(ag)) * sp * 6, 1, DIGC, 1 - sp * 0.5)
      end
    end
  end

  if has(A, "mist") then
    for i = 0, 5 do
      local ph = (t * 0.4 + i * 0.5) % 1
      blk(10 + i * 4 + sin(t + i) * 2, 33 - ph * 18, 1, MISTC, (1 - ph) * 0.4)
    end
  end

  if has(A, "lure") then
    local gpL = v.glowPal or p
    for i = 0, 4 do
      local ph = (t * 0.6 + i * 0.4) % 1
      local an = i / 5 * 6.283
      local rr = 10 * (1 - ph)
      blk(20 + cos(an) * rr, 21 + sin(an) * rr, 1, gpL.accent, (ph < 0.9) and 0.3 + ph * 0.5 or 0)
    end
  end
end

-- DESSINE la relique ANIMÉE `id`, coin haut-gauche (x,y) en espace design, à `scale`, à l'instant t (secondes).
function RelicAnim.draw(view, id, x, y, scale, t, _palette)
  if not (love.graphics and love.graphics.newSpriteBatch and love.graphics.newImage) then return end
  local c = info(id)
  if not c or #c.cells == 0 then return end
  t = t or 0
  scale = scale or 1
  fillBatch(c, t)
  G = love.graphics
  G.push()
  G.translate(x, y)
  G.scale(scale, scale)
  -- corps (1 draw call) puis overlays (immédiat, en espace grille). L'alpha global = 1 (per-cellule géré).
  G.setColor(1, 1, 1, 1)
  G.draw(c.batch, 0, 0)
  overlays(c, t)
  G.pop()
  G.setColor(1, 1, 1, 1)
end

-- Réinitialise les SpriteBatch cachés (et le pixel). Les `view` (data pure) restent côté RelicGen.
function RelicAnim.clear() cache = {}; PIXEL = nil end

return RelicAnim
