-- src/ui/forge.lua
-- FORGE-PX — moteur pixel-art PREMIUM « nightmare forge » de l'UI The Pit. PORT FIDÈLE de la source
-- canonique docs/pixel-art/forge-px.js (kit authored par Kévin dans claude.ai/design). Biseaux laiton
-- DURS et propres (distance-au-bord, ZÉRO bruit) + couche body-horror (yeux injectés de sang, veines,
-- panneaux qui respirent). À PORTER ICI seulement ; l'intégration dans Frame.draw est la phase A→G suivante.
--
-- ── ARCHITECTURE DU PORT (le Buf JS -> LÖVE) ───────────────────────────────────────────────────────
-- Le JS écrit dans un Uint8ClampedArray (set/blend/add) puis putImageData -> canvas nearest ×4. On porte :
--   · Buf = tampon FFI `uint8_t[w*h*4]` (mêmes set/blend/add, mêmes maths en OCTETS 0..255, bit-fidèle).
--   · flush() : ffi.copy(tampon -> pointeur de l'ImageData) PUIS Image:replacePixels(imageData). On alloue
--     l'ImageData + l'Image UNE FOIS par taille (cache) ; chaque frame on ne RÉÉCRIT que les pixels. Jamais
--     de newImage/newQuad par frame. L'appelant blitte l'Image à scale ENTIER PX=4 nearest (coords planchées).
-- Réf API (love2d.org/wiki, vérifié) : ImageData RGBA8 = 4 octets R,G,B,A ; Image:replacePixels(imageData)
--   (>=11.0) ; Data:getFFIPointer (préféré à getPointer, ARM64) ; Canvas:newImageData (readback du glyphe).
--
-- ── TEXTE ───────────────────────────────────────────────────────────────────────────────────────────
-- Le JS rasterise Courier en masque de pixels. On rasterise la police du projet (Silkscreen / Theme.ui)
-- dans un Canvas UNE FOIS, on relit l'alpha (Canvas:newImageData), on en fait un masque {w,h,pix}. text()
-- blitte ces masques DANS le tampon (ombre + glow additif accent + teinte) -> alignement ×4 parfait (pas
-- d'overlay GPU séparé).
--
-- ── HEADLESS (mock LÖVE) ─────────────────────────────────────────────────────────────────────────────
-- Tout appel love.graphics/love.image/Canvas est pcall-gardé + feature-probe (real() ). Sous le mock (pas
-- de getFFIPointer, pas de Canvas readback) : le kit NO-OP proprement (pas de bake, masques vides, draw()
-- retourne nil). check.sh headless reste vert, la scène se construit/update/draw sans crash. Golden inchangé
-- (RENDER pur). DÉTERMINISME : RNG mulberry32 SEEDÉ porté du JS (zéro math.random global).

local Theme = require("src.ui.theme")

local Forge = {}

-- PX = taille d'un pixel d'art À L'ÉCRAN (scale entier nearest). DÉFAUT 2 pour MATCHER la DENSITÉ des
-- créatures : un sprite primgen est dessiné en 64 art-px puis posé en WORLD_FIT 0.5 dans le monde 320×180,
-- lui-même blité ×4 -> 1 art-px de créature = 0.5×4 = 2 px écran. À PX=2, l'UI a la MÊME granularité (des
-- pixels FINS, pas les gros blocs de PX=4). Les composants sont donc AUTORISÉS à porter PLUS d'art-pixels
-- (cadres plus épais en art-px, yeux plus détaillés) pour la même empreinte écran. Le tuner peut surcharger
-- le PX d'affichage (Forge.blit(img, x, y, px)) sans re-baker (la texture est la même, seul le scale change).
local PX = 2
Forge.PX = PX

local floor, min, max, abs = math.floor, math.min, math.max, math.abs
local sin, cos, sqrt = math.sin, math.cos, math.sqrt
local function hypot(a, b) return sqrt(a * a + b * b) end

-- ── FFI (LuaJIT — disponible dans LÖVE ET sous luajit headless). Gardé : si absent, pas de bake. ──
local ffi_ok, ffi = pcall(require, "ffi")

-- ─────────────────────────────── maths (port direct du JS) ───────────────────────────────
-- mulberry32 : RNG déterministe seedé (zéro RNG global) — port bit-à-bit via le module `bit` (LuaJIT).
local bit_ok, bit = pcall(require, "bit")
local function mulberry32(a)
  if not bit_ok then -- repli pur-Lua (déterministe) si bit absent : LCG simple, suffisant pour le cosmétique
    local s = a % 2147483647; if s <= 0 then s = s + 2147483646 end
    return function() s = (s * 16807) % 2147483647; return s / 2147483647 end
  end
  local tobit, bxor, band, rshift = bit.tobit, bit.bxor, bit.band, bit.rshift
  local imul = function(x, y) -- Math.imul 32-bit
    local xl = band(x, 0xffff); local xh = band(rshift(x, 16), 0xffff)
    local yl = band(y, 0xffff)
    return tobit(xl * y + tobit(xh * yl) * 65536)
  end
  local st = tobit(a)
  return function()
    st = tobit(st + 0x6D2B79F5)
    local t = imul(bxor(st, rshift(st, 15)), bit.bor(1, st))
    t = bxor(tobit(t + imul(bxor(t, rshift(t, 7)), bit.bor(61, t))), t)
    local u = bxor(t, rshift(t, 14))
    -- >>> 0 (unsigned) / 2^32
    local uu = u < 0 and (u + 4294967296) or u
    return uu / 4294967296
  end
end

local function clamp(v) return v < 0 and 0 or (v > 1 and 1 or v) end
local function mix(a, b, t)
  return { a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t, a[3] + (b[3] - a[3]) * t }
end
local function hexRgb(h)
  if type(h) == "table" then return h end
  h = h:gsub("#", "")
  return { tonumber(h:sub(1, 2), 16), tonumber(h:sub(3, 4), 16), tonumber(h:sub(5, 6), 16) }
end
local function pulse(t, s) return clamp(0.5 + 0.3 * sin(t * 1.6 + s) + 0.16 * sin(t * 0.73 + s * 2.1)) end
local function elerp(a, b, k) return a + (b - a) * k end
Forge.clamp, Forge.elerp, Forge.pulse = clamp, elerp, pulse

-- ─────────────────────── palettes (franches, dark fantasy — port direct) ───────────────────────
local PLATE = { top = hexRgb("#191222"), bot = hexRgb("#0a0612"), vig = hexRgb("#040108") }
local METAL = { outline = hexRgb("#080503"), deep = hexRgb("#34250f"), mid = hexRgb("#6a5022"),
                base = hexRgb("#9c7a36"), hi = hexRgb("#d8b65e"), spec = hexRgb("#f6e6a4") }
local SCLERA = { pale = hexRgb("#d8cfb6"), shade = hexRgb("#9c917a"), vein = hexRgb("#9c2222") }
local PUPIL = hexRgb("#070409")
local BLOOD = { d1 = hexRgb("#1c060c"), d2 = hexRgb("#5a1018"), d3 = hexRgb("#9c2020"), hot = hexRgb("#e8483c") }

local ACCENTS = {
  gold   = { dark = hexRgb("#7a5e24"), mid = hexRgb("#c49a3e"), bright = hexRgb("#f2d98a") },
  blood  = { dark = hexRgb("#5a1414"), mid = hexRgb("#c03a30"), bright = hexRgb("#ff6a52") },
  bile   = { dark = hexRgb("#2c440e"), mid = hexRgb("#6f9e26"), bright = hexRgb("#aee048") },
  violet = { dark = hexRgb("#3a1e54"), mid = hexRgb("#7a44b4"), bright = hexRgb("#cf9cff") },
}
local ACC = ACCENTS.gold
function Forge.setAccent(n) if ACCENTS[n] then ACC = ACCENTS[n] end end
Forge.ACCENTS = ACCENTS

local LIQ = {
  blood   = { dark = hexRgb("#2a060a"), mid = hexRgb("#8c1c20"), bright = hexRgb("#ec5040") },
  mana    = { dark = hexRgb("#0a1428"), mid = hexRgb("#22508e"), bright = hexRgb("#5ea0f0") },
  essence = { dark = hexRgb("#180a30"), mid = hexRgb("#4e2488"), bright = hexRgb("#bc8cf4") },
}
Forge.LIQ = LIQ
local FAM = {
  flesh  = { c = hexRgb("#cc5a44"), d = hexRgb("#3a1410"), shape = "bar" },
  order  = { c = hexRgb("#dcb85c"), d = hexRgb("#4a3814"), shape = "cross" },
  bone   = { c = hexRgb("#d0c098"), d = hexRgb("#473a2c"), shape = "diamond" },
  arcane = { c = hexRgb("#c47cae"), d = hexRgb("#33182c"), shape = "star" },
  abyss  = { c = hexRgb("#b86a8e"), d = hexRgb("#2a1220"), shape = "disc" },
}
local AFFL = {
  burn   = { c = hexRgb("#f0903a"), bmp = { "001000", "001100", "011110", "111110", "011100" } },
  poison = { c = hexRgb("#8fd06a"), bmp = { "001000", "011100", "111110", "111110", "011100" } },
  bleed  = { c = hexRgb("#e8483c"), bmp = { "001000", "011100", "111110", "110110", "011100" } },
}
Forge.FAM, Forge.AFFL = FAM, AFFL

-- ─────────────────────────────── Buf (tampon FFI octets) ───────────────────────────────
-- Détection « vrai LÖVE » : ImageData réelle avec getFFIPointer + Image:replacePixels. Sous le mock -> false.
local _real = nil
local function real()
  if _real ~= nil then return _real end
  _real = false
  if ffi_ok and love and love.image and love.image.newImageData and love.graphics and love.graphics.newImage then
    local okd, d = pcall(love.image.newImageData, 2, 2)
    if okd and d and d.getFFIPointer then
      local okp = pcall(function() return d:getFFIPointer() end)
      if okp then
        local oki, img = pcall(love.graphics.newImage, d)
        if oki and img and img.replacePixels then _real = true end
      end
    end
  end
  return _real
end
Forge.real = real

local Buf = {}
Buf.__index = Buf
-- Tampon = cdata uint8_t[w*h*4] (RGBA), aligné sur ImageData RGBA8. Si FFI absent -> table de fallback no-op
-- (la scène headless ne crashe pas ; rien n'est lu de toute façon).
function Forge.newBuf(w, h)
  local self = setmetatable({ w = w, h = h }, Buf)
  if ffi_ok then
    self.d = ffi.new("uint8_t[?]", w * h * 4)
  else
    self.d = nil
  end
  return self
end
function Buf:clear()
  if self.d then ffi.fill(self.d, self.w * self.h * 4, 0) end
end
function Buf:set(x, y, c, a)
  if not self.d then return end
  x = floor(x); y = floor(y)
  if x < 0 or y < 0 or x >= self.w or y >= self.h then return end
  local i = (y * self.w + x) * 4
  local d = self.d
  d[i] = c[1]; d[i + 1] = c[2]; d[i + 2] = c[3]
  d[i + 3] = (a == nil) and 255 or (a * 255)
end
function Buf:blend(x, y, c, a)
  if not self.d then return end
  x = floor(x); y = floor(y)
  if x < 0 or y < 0 or x >= self.w or y >= self.h then return end
  local i = (y * self.w + x) * 4
  local d = self.d
  local ba = d[i + 3] / 255
  local na = a + ba * (1 - a)
  if na <= 0 then return end
  for k = 0, 2 do d[i + k] = (c[k + 1] * a + d[i + k] * ba * (1 - a)) / na end
  d[i + 3] = na * 255
end
function Buf:add(x, y, c, k)
  if not self.d then return end
  x = floor(x); y = floor(y)
  if x < 0 or y < 0 or x >= self.w or y >= self.h then return end
  local i = (y * self.w + x) * 4
  local d = self.d
  if d[i + 3] == 0 then d[i + 3] = 255 end
  d[i] = min(255, d[i] + c[1] * k); d[i + 1] = min(255, d[i + 1] + c[2] * k); d[i + 2] = min(255, d[i + 2] + c[3] * k)
end

-- ─────────────────────────────── texte basse-réso (Silkscreen) ───────────────────────────────
-- Cache des masques : key "size|txt" -> { w, h, pix = {{x,y},...} }. Bake via Canvas + readback alpha.
local _tc = {}
local function textMask(txt, size)
  size = size or 9
  local key = size .. "|" .. txt
  if _tc[key] then return _tc[key] end
  local empty = { w = 1, h = 1, pix = {} }
  if not real() then _tc[key] = empty; return empty end
  -- Police du projet à `size` px (mémoïsée par Theme). On rend en blanc sur un Canvas, on relit l'alpha.
  local font = Theme.ui(size)
  if not font then _tc[key] = empty; return empty end
  local okW, fw = pcall(function() return font:getWidth(txt) end)
  local okH, fh = pcall(function() return font:getHeight() end)
  if not (okW and okH) or fw <= 0 or fh <= 0 then _tc[key] = empty; return empty end
  local cw, ch = fw + 2, fh + 2
  local okC, cv = pcall(love.graphics.newCanvas, cw, ch)
  if not okC or not cv then _tc[key] = empty; return empty end
  pcall(cv.setFilter, cv, "nearest", "nearest") -- pas d'AA au readback : Silkscreen reste net (pixel-font)
  local ok = pcall(function()
    local prev = love.graphics.getCanvas()
    love.graphics.setCanvas(cv)
    love.graphics.clear(0, 0, 0, 0)
    love.graphics.setColor(1, 1, 1, 1)
    local pf = love.graphics.getFont()
    love.graphics.setFont(font)
    love.graphics.print(txt, 1, 1)
    if pf then love.graphics.setFont(pf) end
    love.graphics.setCanvas(prev)
  end)
  if not ok then _tc[key] = empty; return empty end
  local okI, id = pcall(function() return cv:newImageData() end)
  if not okI or not id then _tc[key] = empty; return empty end
  -- scan alpha > seuil -> liste de pixels, recadrée (bbox) comme le JS.
  local pix, mnx, mxx, mny, mxy = {}, 1e9, -1e9, 1e9, -1e9
  for y = 0, ch - 1 do
    for x = 0, cw - 1 do
      local okp, _, _, _, a = pcall(function() return id:getPixel(x, y) end)
      if okp and a and a > 0.47 then
        pix[#pix + 1] = { x, y }
        if x < mnx then mnx = x end; if x > mxx then mxx = x end
        if y < mny then mny = y end; if y > mxy then mxy = y end
      end
    end
  end
  if #pix == 0 then _tc[key] = empty; return empty end
  local rel = {}
  for i = 1, #pix do rel[i] = { pix[i][1] - mnx, pix[i][2] - mny } end
  local m = { w = (mxx - mnx + 1), h = (mxy - mny + 1), pix = rel }
  _tc[key] = m
  return m
end
Forge.measure = function(txt, size) return textMask(txt, size or 9).w end

-- text() : pose un masque de glyphes (crisp, Silkscreen, readback nearest) dans le tampon. o = { size,
--   left, shadow, glow }. Centré par défaut. Coords planchées (net, aligné sur la grille d'art).
local function text(buf, txt, ax, y, color, o)
  o = o or {}
  local m = textMask(txt, o.size or 9)
  local ox = o.left and floor(ax) or floor(ax - m.w / 2)
  y = floor(y)
  local pix = m.pix
  if o.shadow then
    for i = 1, #pix do local p = pix[i]; buf:set(ox + p[1] + 1, y + p[2] + 1, o.shadow) end
  end
  if o.glow and o.glow > 0.02 then
    local gk = o.glow * 0.5
    for i = 1, #pix do
      local p = pix[i]
      buf:add(ox + p[1] - 1, y + p[2], ACC.mid, gk)
      buf:add(ox + p[1] + 1, y + p[2], ACC.mid, gk)
      buf:add(ox + p[1], y + p[2] - 1, ACC.mid, gk)
    end
  end
  local lit = o.glow and o.glow > 0.02
  for i = 1, #pix do
    local p = pix[i]
    local c = lit and mix(color, ACC.bright, clamp(o.glow)) or color
    buf:set(ox + p[1], y + p[2], c)
  end
  return m.w
end
Forge.text = text

-- ── bitmaps ──
local function blit(buf, bmp, x, y, color)
  for r = 1, #bmp do
    local row = bmp[r]
    for c = 1, #row do
      if row:sub(c, c) == "1" then buf:set(x + c - 1, y + r - 1, color) end
    end
  end
end

-- ════════════════════════════ PRIMITIVES NETTES ════════════════════════════
local function plate(buf, x0, y0, x1, y1, press, disabled)
  press = press or 0
  local top, bot = PLATE.top, PLATE.bot
  for y = y0, y1 do
    for x = x0, x1 do
      local vy = (y - y0) / max(1, y1 - y0)
      local col = mix(top, bot, vy)
      local ed = min(x - x0, x1 - x, y - y0, y1 - y)
      if ed < 2 then col = mix(col, PLATE.vig, 0.5 * (2 - ed) / 2) end
      if (y % 2) == 0 then col = mix(col, { 0, 0, 0 }, 0.10) end
      -- TRAME diagonale légère (densité « créature » sur la face, pas un aplat) : une case sur deux le long
      -- d'une diagonale s'assombrit d'un cran -> micro-grain structuré (≠ bruit), comme l'ombrage des sprites.
      if ((x + y) % 4) == 0 then col = mix(col, PLATE.vig, 0.16) end
      if press > 0 then col = mix(col, PLATE.vig, press * 0.22) end
      if disabled then col = mix(col, { 28, 26, 32 }, 0.42) end
      buf:set(x, y, col)
    end
  end
end
Forge.plate = plate

local function frame(buf, x0, y0, x1, y1, o)
  o = o or {}
  local th = o.t or 3
  local M = o.metal or METAL
  local AC = o.accentCol or ACC -- liseré : accent LOCAL ({dark,mid,bright}) prioritaire sur l'accent global
  for y = y0, y1 do
    for x = x0, x1 do
      local dT, dB, dL, dR = y - y0, y1 - y, x - x0, x1 - x
      local dm = min(dT, dB, dL, dR)
      if dm < th then
        local lit = (dm == dT or dm == dL)
        local col
        if dm == 0 then
          col = M.outline
        elseif dm == th - 1 then
          col = o.accent and mix(AC.dark, AC.bright, lit and 0.75 or 0.28) or (lit and M.base or M.deep)
        else
          col = lit and mix(M.hi, M.base, (dm - 1) / max(1, th - 2))
            or mix(M.deep, M.mid, (dm - 1) / max(1, th - 2))
          -- TRAME de surface (comme ditherRing des créatures) : 1 case sur 2 du biseau bascule vers le ton
          -- voisin -> le métal a la MÊME densité de micro-variation que la chair/armure des monstres
          -- (≠ aplat propre). Damier (x+y) % 2, hors liseré accent/outline.
          if ((x + y) % 2) == 0 then
            col = lit and mix(col, M.base, 0.5) or mix(col, M.deep, 0.45)
          end
        end
        if o.disabled then col = mix(col, { 44, 42, 38 }, 0.55) end
        buf:set(x, y, col)
      end
    end
  end
  if not o.disabled then buf:set(x0 + 1, y0 + 1, M.spec) end
end
Forge.frame = frame

-- ── PATINE CAUCHEMARDESQUE du métal (FIX craft) : grit DÉLIBÉRÉ, ciselé, SEEDÉ — comme une part de
-- créature, jamais du bruit aléatoire (≠ stone) ni géométrique propre. Posée APRÈS frame() sur l'anneau
-- de métal (dm<th). Détails : (1) PIQÛRES de corrosion (creux sombres épars), (2) FISSURES capillaires
-- (courtes entailles diagonales dans le deep), (3) ÉBRÉCHURES asymétriques du liseré extérieur (le bord
-- mangé), (4) intrusion ORGANIQUE rare (éclat d'os OU bosse de chair sombre sur UN flanc). Déterministe
-- (mulberry32(seed)) -> identique au lancement, et headless = no-op (buf:set garde-fou).
local function frameWeather(buf, x0, y0, x1, y1, th, seed, M, disabled)
  M = M or METAL
  local rnd = mulberry32(floor((seed or 7) * 2654435761) % 2147483647)
  local W, H = x1 - x0 + 1, y1 - y0 + 1
  local perim = 2 * (W + H)
  local function onRing(px, py) -- vrai si (px,py) est sur l'anneau de métal (pas sur la face/le vide)
    if px < x0 or px > x1 or py < y0 or py > y1 then return false end
    local dm = min(px - x0, x1 - px, py - y0, y1 - py)
    return dm < th
  end
  -- (1) PIQÛRES de corrosion : ~1 / 14 px de périmètre, posées sur l'anneau (creux 1px deep/outline).
  local nPits = max(2, floor(perim / 14))
  for _ = 1, nPits do
    local r = rnd()
    -- choisit un point sur l'un des 4 bords, à une profondeur dm aléatoire dans le métal.
    local edge = floor(rnd() * 4)
    local d = 1 + floor(rnd() * max(1, th - 1)) -- profondeur dans le bevel
    local px, py
    if edge == 0 then px = x0 + floor(rnd() * W); py = y0 + d        -- haut
    elseif edge == 1 then px = x0 + floor(rnd() * W); py = y1 - d     -- bas
    elseif edge == 2 then px = x0 + d; py = y0 + floor(rnd() * H)     -- gauche
    else px = x1 - d; py = y0 + floor(rnd() * H) end                  -- droite
    if onRing(px, py) then
      buf:set(px, py, r < 0.5 and M.deep or M.outline)
      if r < 0.22 then buf:set(px + (rnd() < 0.5 and 1 or -1), py, M.deep) end -- piqûre 2px parfois
    end
  end
  -- (2) FISSURES capillaires : 1-2 courtes entailles dans le métal (deep), orientation seedée.
  local nCr = 1 + floor(rnd() * 2)
  for _ = 1, nCr do
    local edge = floor(rnd() * 4)
    local len = 2 + floor(rnd() * 3)
    local px, py, dirx, diry
    if edge < 2 then
      px = x0 + 2 + floor(rnd() * max(1, W - 4)); py = (edge == 0) and (y0 + 1) or (y1 - 1)
      dirx = (rnd() < 0.5 and 1 or -1); diry = (edge == 0) and 1 or -1
    else
      py = y0 + 2 + floor(rnd() * max(1, H - 4)); px = (edge == 2) and (x0 + 1) or (x1 - 1)
      diry = (rnd() < 0.5 and 1 or -1); dirx = (edge == 2) and 1 or -1
    end
    -- on ne trace QUE sur l'anneau (la fissure court le long du métal, ne traverse pas la face).
    local cx, cy = px, py
    for _ = 0, len do
      if onRing(cx, cy) then buf:set(cx, cy, M.deep) end
      cx = cx + dirx; cy = cy + (rnd() < 0.55 and diry or 0)
    end
  end
  -- (3) ÉBRÉCHURES du liseré : on MANGE asymétriquement 2-4 px du contour extérieur (remplacés par le
  -- vide/face -> le bord paraît cassé). On les met d'UN côté de préférence (usure dirigée).
  local nNick = 2 + floor(rnd() * 3)
  local sidePref = floor(rnd() * 4)
  for _ = 1, nNick do
    local edge = (rnd() < 0.6) and sidePref or floor(rnd() * 4)
    local px, py
    if edge == 0 then px = x0 + 2 + floor(rnd() * max(1, W - 4)); py = y0
    elseif edge == 1 then px = x0 + 2 + floor(rnd() * max(1, W - 4)); py = y1
    elseif edge == 2 then px = x0; py = y0 + 2 + floor(rnd() * max(1, H - 4))
    else px = x1; py = y0 + 2 + floor(rnd() * max(1, H - 4)) end
    -- l'ébréchure : 1px du contour devient deep (creux), + le pixel juste à l'intérieur s'assombrit.
    buf:set(px, py, M.deep)
    if edge == 0 then buf:set(px, py + 1, M.deep) elseif edge == 1 then buf:set(px, py - 1, M.deep)
    elseif edge == 2 then buf:set(px + 1, py, M.deep) else buf:set(px - 1, py, M.deep) end
  end
  -- (4) INTRUSION ORGANIQUE (rare, ~40%) : sur UN flanc, soit un éclat d'OS (bone clair, 2-3px), soit une
  -- BOSSE de chair sombre (deep + un point sang). C'est le « vivant-adjacent » du grimdark (≠ métal pur).
  if not disabled and rnd() < 0.4 then
    local edge = floor(rnd() * 4)
    local t2 = 0.25 + rnd() * 0.5
    local px, py
    if edge == 0 then px = x0 + floor(W * t2); py = y0 + 1
    elseif edge == 1 then px = x0 + floor(W * t2); py = y1 - 1
    elseif edge == 2 then px = x0 + 1; py = y0 + floor(H * t2)
    else px = x1 - 1; py = y0 + floor(H * t2) end
    if rnd() < 0.5 then -- éclat d'OS qui perce le métal
      buf:set(px, py, M.spec); buf:set(px, py + (edge == 1 and -1 or 1), hexRgb("#cfc6b4"))
    else -- bosse de CHAIR (sombre) + une perle de sang
      buf:set(px, py, hexRgb("#2a0e0e")); buf:set(px + (rnd() < 0.5 and 1 or -1), py, BLOOD.d2)
    end
  end
end
Forge.frameWeather = frameWeather

local function rivet(buf, x, y, M)
  M = M or METAL
  buf:set(x, y, M.base); buf:set(x + 1, y, M.deep); buf:set(x, y + 1, M.deep)
  buf:set(x + 1, y + 1, M.outline); buf:set(x, y, M.spec)
end

local function dropShadow(buf, W, yb, press)
  press = press or 0
  for dy = 0, 1 do
    for x = 2, W - 3 do
      local edge = abs(x - W / 2) / (W / 2)
      buf:blend(x, yb + dy, { 0, 0, 0 }, (0.55 - dy * 0.22) * (1 - edge * 0.5) * (1 - press * 0.6))
    end
  end
end

local function diamond(buf, cx, cy, r, fill, edge, spec)
  for y = -r, r do
    for x = -r, r do
      local m = abs(x) + abs(y)
      if m <= r then buf:set(floor(cx + x + 0.5), floor(cy + y + 0.5), m >= r - 0.5 and edge or fill) end
    end
  end
  if spec then buf:set(floor(cx - r * 0.3 + 0.5), floor(cy - r * 0.3 + 0.5), spec) end
end
Forge.diamond = diamond

-- ════════════════════════════ ŒIL CAUCHEMARDESQUE ════════════════════════════
local function drawEye(buf, cx, cy, r, open, glow, t, seed, opts)
  opts = opts or {}
  local squash = opts.squash or 0.62
  local gaze = opts.gaze
  local pupil = opts.pupil or "slit"
  local blood = opts.blood or 0
  local bt = (t * 0.6 + seed * 2.3) % 6.0
  local blink = bt > 5.6 and (1 - abs(bt - 5.8) / 0.2) or 0
  local op = clamp(open * (1 - clamp(blink)))
  -- PLUS OUVERT = PLUS ROND : quand l'œil s'ouvre (op->1), le squash remonte vers ~0.92 (paupières
  -- grandes ouvertes, œil rond et LISIBLE). Fermé/en cours de fermeture, il garde son squash de repos.
  local sqOpen = squash + (0.92 - squash) * op
  local ry = r * sqOpen * op
  if ry < 0.6 then
    -- ŒIL FERMÉ (repos) : une COUTURE de paupière nette — fente sombre + ourlet clair en dessous (la
    -- lèvre qui prend la lumière) -> lecture « œil clos dans la plaque », PAS un trou vide.
    for x = -r, r do
      local fx, fy = floor(cx + x + 0.5), floor(cy + 0.5)
      buf:set(fx, fy, mix(METAL.deep, { 0, 0, 0 }, 0.55))           -- fente sombre
      if abs(x) < r - 0.5 then buf:set(fx, fy + 1, mix(METAL.mid, METAL.deep, 0.5)) end -- ourlet inférieur (lèvre)
    end
    -- petits coins de la couture (légère courbure : les commissures retombent).
    buf:set(floor(cx - r + 0.5), floor(cy - 0.5 + 0.5), mix(METAL.deep, { 0, 0, 0 }, 0.4))
    buf:set(floor(cx + r + 0.5), floor(cy - 0.5 + 0.5), mix(METAL.deep, { 0, 0, 0 }, 0.4))
    return
  end
  local ex, ey
  -- sclère : PLUS BLANCHE et plus lumineuse (lecture « œil » nette). Le cœur tend vers le blanc pur, le
  -- bord garde une ombre douce (volume). Falloff RÉDUIT -> davantage de sclère claire visible.
  local SCLERA_WHITE = { 244, 240, 230 }
  for y = -math.ceil(ry), math.ceil(ry) do
    for xx = -math.ceil(r), math.ceil(r) do
      ex = xx / r; ey = y / ry
      if ex * ex + ey * ey <= 1 then
        local fall = clamp(abs(ex) * 0.38 + abs(ey) * 0.42)        -- falloff plus doux qu'avant
        local base = mix(SCLERA_WHITE, SCLERA.shade, fall)
        if fall < 0.3 then base = mix(base, { 255, 255, 255 }, (0.3 - fall) * 0.8) end -- cœur quasi blanc
        if blood > 0 then base = mix(base, BLOOD.d3, blood * 0.14) end
        buf:set(floor(cx + xx + 0.5), floor(cy + y + 0.5), base)
      end
    end
  end
  -- veines
  local nv = 2 + floor(blood * 3 + 0.5)
  local rnd = mulberry32(floor(seed * 101))
  for _ = 1, nv do
    local a = rnd() * 6.28
    local vx, vy = cx + cos(a) * r * 0.96, cy + sin(a) * ry * 0.96
    for _ = 1, math.ceil(r * 0.6) do
      ex = (vx - cx) / r; ey = (vy - cy) / ry
      if ex * ex + ey * ey <= 1 then buf:blend(floor(vx + 0.5), floor(vy + 0.5), SCLERA.vein, 0.42 + blood * 0.3) end
      vx = vx + (cx - vx) * 0.18 + (rnd() - 0.5) * 0.4
      vy = vy + (cy - vy) * 0.18
    end
  end
  -- iris + pupille
  local gx, gy = 0, 0
  if gaze then
    local dx, dy = gaze[1] - cx, gaze[2] - cy
    local dl = hypot(dx, dy); if dl == 0 then dl = 1 end
    local mo = r * 0.32
    gx = dx / dl * mo; gy = dy / dl * mo * sqOpen
  else
    gx = sin(t * 0.5 + seed) * r * 0.22; gy = cos(t * 0.4 + seed * 1.3) * ry * 0.4
  end
  -- iris un peu plus PETIT (0.48 au lieu de 0.52) -> plus de BLANC visible autour (lecture « œil » accrue).
  local ir = max(2, floor(r * 0.48 + 0.5))
  for y = -ir, ir do
    for xx = -ir, ir do
      local d = hypot(xx, y)
      if d <= ir then
        local ax, ay = gx + xx, gy + y
        if (ax / r) * (ax / r) + (ay / ry) * (ay / ry) <= 1 then
          local dd = d / ir
          local col = mix(mix(ACC.mid, ACC.bright, glow), ACC.dark, dd)
          local isP
          if pupil == "slit" then
            isP = abs(xx) < ir * 0.30 * (1 - 0.32 * abs(y) / ir)
          else
            isP = dd < 0.46
          end
          if isP then col = PUPIL elseif dd > 0.84 then col = mix(col, { 0, 0, 0 }, 0.5) end
          buf:set(floor(cx + ax + 0.5), floor(cy + ay + 0.5), col)
        end
      end
    end
  end
  buf:set(floor(cx + gx - ir * 0.3 + 0.5), floor(cy + gy - ir * 0.3 + 0.5), { 255, 255, 255 })
  -- PAUPIÈRES : arcs haut/bas qui BORNENT l'œil (lecture « œil », pas une bille). Pour les GROS yeux
  -- (r>=5) la paupière a 2 px d'épaisseur -> ourlet net (haut = ombre légère, bas = ombre marquée).
  local thick = (r >= 5)
  for xx = -r, r do
    ex = xx / r
    if abs(ex) <= 1 then
      local lh = sqrt(max(0, 1 - ex * ex)) * ry
      buf:set(floor(cx + xx + 0.5), floor(cy - lh + 0.5), mix(METAL.deep, { 0, 0, 0 }, 0.45))
      buf:set(floor(cx + xx + 0.5), floor(cy + lh + 0.5), mix(METAL.deep, { 0, 0, 0 }, 0.6))
      if thick then
        buf:set(floor(cx + xx + 0.5), floor(cy - lh + 1.5), mix(METAL.deep, METAL.mid, 0.3)) -- ourlet sup (lèvre éclairée)
        buf:set(floor(cx + xx + 0.5), floor(cy + lh - 0.5), mix(METAL.deep, { 0, 0, 0 }, 0.35))
      end
    end
  end
end
Forge.drawEye = drawEye

-- ════════════════════════════ BOUTON + nuée d'yeux ════════════════════════════
local DROP, TH = 2, 3
Forge.DROP, Forge.TH = DROP, TH

-- genEyes : place une PETITE NUÉE d'yeux GROS et LISIBLES (sclère+iris+pupille+paupières reconnaissables),
-- ÉPARPILLÉS de façon ASYMÉTRIQUE dans les GOUTTIÈRES de part et d'autre du label centré — JAMAIS sur le
-- texte (keep-out strict du masque de glyphes). Tailles et phases de regard VARIÉES -> « petit essaim qui
-- observe », pas une paire symétrique. Déterministe (seed). On essaie de poser N yeux (3..5) par rejection
-- sampling dans les deux gouttières, sans chevauchement entre eux ni avec la zone du label.
-- genEyes(W, hslab, seed, label, size, opts?) : opts = { frameTh, pad, eyeR }.
--   frameTh : épaisseur de cadre (marge hors-cadre). pad : marge interne SUPPLÉMENTAIRE (gouttière/label).
--   eyeR    : rayon d'œil de RÉFÉRENCE (le tuner) ; les yeux varient autour (0.6..1.1 × eyeR). nil => auto.
-- Rétro-compat : si `opts` est un NOMBRE, on le lit comme frameTh (ancienne signature).
local function genEyes(W, hslab, seed, label, size, opts)
  if type(opts) == "number" then opts = { frameTh = opts } end
  opts = opts or {}
  local rnd = mulberry32(floor(seed * 9301 + 7))
  local m = textMask(label, size or 9)
  local lw, lhh = m.w, m.h
  local cy = hslab / 2
  local pad = opts.pad or 0
  local lx0 = floor(W / 2 - lw / 2) - pad -- bord gauche du label (+ padding) = keep-out
  local lx1 = floor(W / 2 + lw / 2) + pad -- bord droit du label (+ padding)
  local ly0 = floor(cy - lhh / 2) - 1     -- keep-out vertical du label
  local ly1 = floor(cy + lhh / 2) + 1
  local inner = (opts.frameTh or TH) + 1 + pad -- marge intérieure (cadre + padding)
  local gutterL = lx0 - inner          -- largeur dispo à gauche du label
  local gutterR = (W - 1 - inner) - lx1 -- largeur dispo à droite
  local rByH = floor((hslab - 2) / 2)  -- rayon max admis par la HAUTEUR (l'œil tient verticalement)
  -- rayon de référence : forcé (tuner) borné par la dalle, sinon auto. Les yeux VARIENT autour.
  local rRef = opts.eyeR and max(3, min(opts.eyeR, rByH)) or max(4, min(8, rByH))

  -- une gouttière = { x0, x1, cy } (bande verticale libre à côté du label). On y pose des yeux par essais.
  local function fillGutter(gx0, gx1, eyes, want)
    local placed = 0
    local tries = 0
    while placed < want and tries < want * 30 do
      tries = tries + 1
      -- ESSAIM HÉTÉROGÈNE : 1er œil de la gouttière = GROS (proche de eyeR), les suivants plus petits ->
      -- une grosse prunelle + des satellites, qui PACKENT dans la gouttière (verticale + horizontale).
      local big = (placed == 0)
      local rv = big and rRef * (0.85 + rnd() * 0.25) or rRef * (0.42 + rnd() * 0.45)
      local r = max(3, floor(min(rv, rByH, (gx1 - gx0) / 2 - 0.5) + 0.5))
      if r >= 3 and (gx1 - gx0) >= r * 2 then
        local ex = gx0 + r + rnd() * max(0, (gx1 - gx0) - 2 * r)
        -- jitter vertical (essaim épars), mais l'œil reste DANS la dalle.
        local ey = cy + (rnd() - 0.5) * (hslab - 2 * r - 2)
        ey = max(r + 1, min(hslab - r - 1, ey))
        -- keep-out label (jamais sur le texte) + pas de chevauchement avec un œil déjà posé.
        local hitsLabel = (ex + r > lx0 - 1 and ex - r < lx1 + 1 and ey + r > ly0 - 1 and ey - r < ly1 + 1)
        local overlap = false
        if not hitsLabel then
          for j = 1, #eyes do
            if hypot(ex - eyes[j].ex, ey - eyes[j].ey) < (r + eyes[j].r) * 1.05 then overlap = true; break end
          end
        end
        if (not hitsLabel) and (not overlap) then
          local a = rnd()
          eyes[#eyes + 1] = {
            ex = ex, ey = ey, r = r,
            squash = 0.72 + rnd() * 0.14,         -- assez ouvert (paupières larges, lecture « œil »)
            pupil = (rnd() < 0.72) and "slit" or "round",
            blood = 0.45 + rnd() * 0.45,
            phase = a * 10,                        -- regard désynchronisé entre yeux
          }
          placed = placed + 1
        end
      end
    end
    return placed
  end

  local eyes = {}
  -- RÉPARTITION ASYMÉTRIQUE : un total de 3..5, déséquilibré entre gauche et droite (ex. 2|3 ou 3|1).
  local total = 3 + floor(rnd() * 3)        -- 3..5
  local leftWant = 1 + floor(rnd() * (total - 1)) -- 1..total-1 -> jamais symétrique strict
  local rightWant = total - leftWant
  -- gouttières exploitables (assez larges pour ≥1 œil de rayon 3).
  if gutterL >= 7 then fillGutter(inner, lx0 - 1, eyes, leftWant) end
  if gutterR >= 7 then fillGutter(lx1 + 1, W - 1 - inner, eyes, rightWant) end
  -- repli : si le label mange tout (aucune gouttière), un seul gros œil centré en haut, hors texte.
  if #eyes == 0 then
    local r = max(3, min(rRef, rByH))
    eyes[#eyes + 1] = { ex = W / 2, ey = max(r + 1, ly0 - r - 1 >= r + 1 and ly0 - r - 1 or (r + 1)),
      r = r, squash = 0.78, pupil = "slit", blood = 0.6, phase = rnd() * 10 }
  end
  return eyes
end
Forge.genEyes = genEyes

-- drawButton(... opts?) : opts.frameTh = épaisseur de cadre (défaut TH=3). Un cadre PLUS FIN (2) laisse
-- plus d'intérieur -> de la place pour de GROS yeux lisibles + un texte qui respire (retour user).
local function drawButton(buf, W, H, press, eyeOpen, glow, seed, label, disabled, eyes, gaze, size, t, opts)
  size = size or 9
  local fth = (opts and opts.frameTh) or TH
  local hslab = H - DROP
  local slabY = floor(press * DROP + 0.5)
  dropShadow(buf, W, hslab, press)
  local x0, y0, x1, y1 = 0, slabY, W - 1, slabY + hslab - 1
  plate(buf, x0 + fth, y0 + fth, x1 - fth, y1 - fth, press, disabled)
  if (not disabled) and eyes and eyeOpen > 0.02 then
    for i = 1, #eyes do
      local e = eyes[i]
      local g = gaze and { gaze[1], gaze[2] } or nil
      drawEye(buf, floor(e.ex + 0.5), floor(slabY + e.ey + 0.5), e.r, eyeOpen, glow, t, seed + e.phase,
        { squash = e.squash, pupil = e.pupil, blood = e.blood, gaze = g })
    end
  end
  frame(buf, x0, y0, x1, y1, { t = fth, accent = not disabled, disabled = disabled })
  -- PATINE cauchemardesque sur le cadre (grit ciselé seedé) : sauf si opts.weather == false.
  if not (opts and opts.weather == false) then
    frameWeather(buf, x0, y0, x1, y1, fth, seed + 13, METAL, disabled)
  end
  local ri = max(2, fth)
  rivet(buf, x0 + ri, y0 + ri, METAL); rivet(buf, x1 - ri - 1, y0 + ri, METAL)
  rivet(buf, x0 + ri, y1 - ri - 1, METAL); rivet(buf, x1 - ri - 1, y1 - ri - 1, METAL)
  if disabled then
    for dx = x0 + 6, x1 - 7, 3 do
      buf:set(dx, y0 + 1, hexRgb("#2a200f")); buf:set(dx, y1 - 1, hexRgb("#2a200f"))
    end
  end
  -- Label centré sur la VRAIE hauteur du masque (net, pas une estimation) -> texte qui RESPIRE au centre.
  -- DISABLED : laiton TERNE mais LISIBLE (#a4895a) + ombre marquée — JAMAIS l'ancien #5a5040 illisible qui
  -- faisait passer le bouton pour une « boîte vide cassée » (le label de COMBAT au repos d'un début de run).
  local lh = textMask(label, size).h
  text(buf, label, W / 2, slabY + floor((hslab - lh) / 2 + 0.5),
    disabled and hexRgb("#a4895a") or hexRgb("#f0d68e"),
    { size = size, glow = disabled and 0 or glow * 0.6, shadow = hexRgb("#0e0a04") })
end
Forge.drawButton = drawButton

local function drawEcoBtn(buf, W, H, press, glow, seed, label, cost, disabled, t)
  local hslab = H - DROP
  local slabY = floor(press * DROP + 0.5)
  dropShadow(buf, W, hslab, press)
  local x0, y0, x1, y1 = 0, slabY, W - 1, slabY + hslab - 1
  plate(buf, x0 + 2, y0 + 2, x1 - 2, y1 - 2, press, disabled)
  frame(buf, x0, y0, x1, y1, { t = 2, accent = not disabled, disabled = disabled })
  frameWeather(buf, x0, y0, x1, y1, 2, seed + 5, METAL, disabled) -- patine
  rivet(buf, x0 + 2, y0 + 2, METAL); rivet(buf, x0 + 2, y1 - 3, METAL)
  local lh = textMask(label, 8).h
  local cy = slabY + floor((hslab - lh) / 2 + 0.5) -- centré sur la vraie hauteur du masque (respire)
  text(buf, label, (W - (cost ~= nil and 10 or 0)) / 2, cy,
    disabled and hexRgb("#a4895a") or hexRgb("#e8cd84"),
    { size = 8, glow = disabled and 0 or glow * 0.5, shadow = hexRgb("#0e0a04") })
  if cost ~= nil then
    local gx, gy = x1 - 7, slabY + hslab / 2
    diamond(buf, gx, gy, 2, disabled and ACC.dark or ACC.bright, ACC.dark, (not disabled) and { 255, 255, 255 } or nil)
    text(buf, tostring(cost), gx - 7, gy - 3, disabled and hexRgb("#a4895a") or hexRgb("#e8dcc0"),
      { left = true, size = 8 })
  end
end
Forge.drawEcoBtn = drawEcoBtn

local function drawIconBtn(buf, W, H, press, glow, seed, kind, t)
  local hslab = H - DROP
  local slabY = floor(press * DROP + 0.5)
  dropShadow(buf, W, hslab, press)
  local x0, y0, x1, y1 = 0, slabY, W - 1, slabY + hslab - 1
  plate(buf, x0 + 2, y0 + 2, x1 - 2, y1 - 2, press, false)
  frame(buf, x0, y0, x1, y1, { t = 2, accent = true })
  frameWeather(buf, x0, y0, x1, y1, 2, seed + 9, METAL, false) -- patine
  rivet(buf, x0 + 2, y0 + 2, METAL); rivet(buf, x1 - 3, y0 + 2, METAL)
  rivet(buf, x0 + 2, y1 - 3, METAL); rivet(buf, x1 - 3, y1 - 3, METAL)
  local cx, cy = floor(W / 2 + 0.5), floor(slabY + hslab / 2 + 0.5)
  local col = mix(METAL.hi, ACC.bright, glow * 0.7)
  local r = floor(hslab * 0.26 + 0.5)
  if kind == "sigil" then
    local amp = 0.4 + glow * 1.2 + press * 0.6
    for s = 0, 4 do
      local a = s / 5 * 6.28 - 1.57
      local ax = floor(cx + cos(a) * r + sin(t * 3 + s) * amp + 0.5)
      local ay = floor(cy + sin(a) * r + cos(t * 3 + s) * amp + 0.5)
      for rr = 0, r - 1 do
        buf:set(floor(cx + (ax - cx) * rr / r + 0.5), floor(cy + (ay - cy) * rr / r + 0.5), col)
      end
    end
    buf:set(cx, cy, ACC.bright)
  elseif kind == "left" or kind == "right" then
    local dir = kind == "left" and -1 or 1
    for k = -r, r do
      local xx = floor(cx - dir * r * 0.4 + dir * abs(k) * 0.8 + 0.5)
      buf:set(xx, cy + k, col)
      buf:set(xx - dir, cy + k, mix(col, METAL.outline, 0.4))
    end
  elseif kind == "gear" then
    blit(buf, { "010010", "111111", "110011", "110011", "111111", "010010" }, cx - 3, cy - 3, col)
  end
end
Forge.drawIconBtn = drawIconBtn

-- ════════════════════════════ ORBE + nageuse ════════════════════════════
local function drawOrb(buf, W, H, level, liq, seed, t)
  local cx, cy = W / 2 - 0.5, H / 2 - 0.5
  local Rc = min(W, H) / 2 - 0.5
  local rIn = Rc - 2
  local surfB = cy + rIn - 2 * clamp(level) * rIn
  local function sAt(x) return surfB + sin(x * 0.5 + t * 2.0) * 1.0 + sin(x * 0.21 - t * 1.3) * 0.6 end
  for y = floor(cy - rIn), math.ceil(cy + rIn) do
    for x = floor(cx - rIn), math.ceil(cx + rIn) do
      local dx, dy = x - cx, y - cy
      local d = sqrt(dx * dx + dy * dy)
      if d <= rIn + 0.4 then
        local nx, ny = dx / rIn, dy / rIn
        local sph = clamp(0.5 + (-nx * 0.5 - ny * 0.6) * 0.55)
        local edge = 1 - (clamp(d / rIn)) ^ 3 * 0.6
        local surf = sAt(x)
        local col
        if y >= surf then
          local depth = clamp((y - surf) / (rIn * 2))
          col = mix(liq.bright, liq.dark, clamp(0.1 + depth * 1.2))
          col = mix(col, liq.mid, 0.3)
          col = mix(mix(col, { 0, 0, 0 }, 0.42 * (1 - sph)), col, 0.55)
          col = { col[1] * edge, col[2] * edge, col[3] * edge }
          if y < surf + 1.2 then col = mix(col, liq.bright, 0.7) end
        else
          col = mix(hexRgb("#0a0712"), hexRgb("#1a1430"), sph)
          col = { col[1] * edge, col[2] * edge, col[3] * edge }
        end
        buf:set(x, y, col)
      end
    end
  end
  -- nageuse
  local ct = ((t * 0.07 + seed * 0.37) % 1)
  if ct < 0.5 then
    local prog = ct / 0.5
    local hx = cx - rIn - 3 + prog * (2 * rIn + 6)
    local hy = cy + rIn * 0.2 + sin(t * 1.3 + seed) * rIn * 0.2
    for sg = 0, 8 do
      local bx = hx - sg * 1.3
      local by = hy + sin(t * 2.2 - sg * 0.55) * 2.0
      local br = max(0.6, 1.7 - sg * 0.12)
      for oy = -math.ceil(br), math.ceil(br) do
        for ox = -math.ceil(br), math.ceil(br) do
          if ox * ox + oy * oy <= br * br then
            local XX, YY = floor(bx + ox + 0.5), floor(by + oy + 0.5)
            if hypot(XX - cx, YY - cy) <= rIn - 1 and YY >= sAt(XX) then buf:blend(XX, YY, { 4, 2, 6 }, 0.6) end
          end
        end
      end
    end
    local ehx, ehy = floor(hx + 0.5), floor(hy + 0.5)
    if ehy >= sAt(ehx) and hypot(ehx - cx, ehy - cy) < rIn - 1 then
      buf:set(ehx, ehy, ACC.bright); buf:add(ehx, ehy, ACC.bright, 0.8)
    end
  end
  -- reflet
  local sx, sy = cx - rIn * 0.36, cy - rIn * 0.4
  local sa, sb = rIn * 0.4, rIn * 0.24
  for y = floor(sy - sb), math.ceil(sy + sb) do
    for x = floor(sx - sa), math.ceil(sx + sa) do
      local exx, eyy = (x - sx) / sa, (y - sy) / sb
      local e = exx * exx + eyy * eyy
      if e <= 1 then buf:add(x, y, { 255, 255, 255 }, (1 - e) * 0.32) end
    end
  end
  -- anneau métal
  local rOut, rInr = Rc, Rc - 2
  for y = floor(cy - Rc - 1), math.ceil(cy + Rc + 1) do
    for x = floor(cx - Rc - 1), math.ceil(cx + Rc + 1) do
      local dx2, dy2 = x - cx, y - cy
      local d2 = sqrt(dx2 * dx2 + dy2 * dy2)
      if d2 >= rInr - 0.5 and d2 <= rOut + 0.5 then
        local lit = (-dx2 / d2 * 0.4 - dy2 / d2 * 0.55)
        local col2 = (d2 >= rOut - 0.5 or d2 <= rInr + 0.5) and METAL.outline
          or (lit > 0 and mix(METAL.mid, METAL.hi, lit) or mix(METAL.deep, METAL.mid, -lit))
        buf:set(x, y, col2)
      end
    end
  end
  rivet(buf, floor(cx - 1 + 0.5), floor(cy - Rc + 1 + 0.5), METAL)
  rivet(buf, floor(cx - 1 + 0.5), floor(cy + Rc - 2 + 0.5), METAL)
  rivet(buf, floor(cx - Rc + 1 + 0.5), floor(cy - 1 + 0.5), METAL)
  rivet(buf, floor(cx + Rc - 2 + 0.5), floor(cy - 1 + 0.5), METAL)
end
Forge.drawOrb = drawOrb

-- ════════════════════════════ JAUGE DE VIE ════════════════════════════
local function drawGauge(buf, W, H, val, segs, t)
  segs = segs or {}
  local barH = 8
  local x0, y0, x1, y1 = 2, 2, W - 3, barH - 3
  local innerW = x1 - x0 + 1
  local deep = hexRgb("#070409")
  for y = y0, y1 do
    for x = x0, x1 do
      buf:set(x, y, mix(hexRgb("#0a0712"), hexRgb("#181226"), ((x + y) % 2) * 0.3))
    end
  end
  local low = val < 0.25
  local breath = sin(t * 2) * 0.5
  local spasm = low and sin(t * 9) * 1.2 or 0
  local fwf = innerW * clamp(val) + breath + spasm
  local p = low and (0.55 + 0.45 * sin(t * 7)) or 1
  local acc = LIQ.blood
  for y2 = y0, y1 do
    local frontX = x0 + fwf + sin(y2 * 0.9 + t * 3) * 0.8
    for x2 = x0, x1 do
      if x2 > frontX then break end
      local col = mix(acc.dark, acc.mid, 0.4 + ((x2 + y2) % 2) * 0.18)
      local ff = (frontX - x2) / innerW
      local sa = 0
      for k = 1, #segs do
        if ff < sa + segs[k].frac and ff >= sa then col = mix(segs[k].color, col, 0.3) end
        sa = sa + segs[k].frac
      end
      if y2 < y0 + 1 then col = mix(col, acc.bright, 0.5)
      elseif y2 > y1 - 1 then col = mix(col, deep, 0.45) end
      if low then col = mix(col, acc.bright, (p - 0.55) * 0.5) end
      buf:set(x2, y2, col)
    end
    local fx = floor(frontX + 0.5)
    if fx >= x0 and fx <= x1 then
      buf:set(fx, y2, mix(acc.bright, acc.mid, 0.2)); buf:add(fx + 1, y2, acc.mid, 0.5 * p)
    end
  end
  frame(buf, 0, 0, W - 1, barH - 1, { t = 2 })
  if low then
    for b = 0, 1 do
      local dx = floor((sin(t * 2 + b) * 0.5 + 0.5) * (W - 6) + 0.5) + 3
      buf:blend(dx, barH + (floor(t * 4 + b * 3) % 4), BLOOD.hot, 0.5)
    end
  end
  local ix = 1
  for s = 1, #segs do
    if segs[s].bmp then blit(buf, segs[s].bmp, ix, barH + 1, segs[s].color); ix = ix + 7 end
  end
end
Forge.drawGauge = drawGauge

-- ════════════════════════════ CADRE 9-SLICE + veines + œil ════════════════════════════
local function veins(buf, x0, y0, x1, y1, seed, t)
  local starts = { { x0 + 3, y0 + 3, 0.8 }, { x1 - 3, y0 + 3, 2.4 }, { x0 + 3, y1 - 3, 5.5 }, { x1 - 3, y1 - 3, 3.9 } }
  for s = 0, 3 do
    local rnd = mulberry32(floor(seed * 7 + s * 131))
    local len = floor((5 + rnd() * 5) * (0.7 + 0.3 * pulse(t, seed + s)) + 0.5)
    local x, y, dir = starts[s + 1][1], starts[s + 1][2], starts[s + 1][3]
    for i = 0, len - 1 do
      buf:blend(floor(x + 0.5), floor(y + 0.5), BLOOD.d2, 0.7)
      if i % 3 == 1 then buf:add(floor(x + 0.5), floor(y + 0.5), BLOOD.d3, 0.4 * pulse(t, seed + s + i)) end
      dir = dir + (rnd() - 0.5) * 0.7
      local nx, ny = min(x - x0, x1 - x), min(y - y0, y1 - y)
      if min(nx, ny) > 5 then
        dir = dir + (nx < ny and (x < (x0 + x1) / 2 and 0.4 or -0.4) or (y < (y0 + y1) / 2 and 0.4 or -0.4))
      end
      x = x + cos(dir); y = y + sin(dir)
      if x < x0 + 1 or x > x1 - 1 or y < y0 + 1 or y > y1 - 1 then break end
    end
  end
end

local function drawPanel(buf, W, H, t, title)
  local B = 3
  plate(buf, B, B, W - B - 1, H - B - 1, 0, false)
  for y = B + 1, H - B - 2 do
    for x = B + 1, W - B - 2 do
      local m = sin(x * 0.5 + t * 0.6) + sin(y * 0.6 - t * 0.5)
      if m > 1.4 then buf:blend(x, y, { 6, 4, 12 }, 0.18 * (m - 1.4)) end
    end
  end
  veins(buf, B, B, W - B - 1, H - B - 1, 77, t)
  local ec = ((t * 0.09 + 0.3) % 1)
  local eo = ec < 0.16 and sin(ec / 0.16 * math.pi) or 0
  if eo > 0.01 then drawEye(buf, floor(W * 0.66 + 0.5), floor(H * 0.56 + 0.5), 6, clamp(eo), 0.5, t, 909, { blood = 0.6, squash = 0.7 }) end
  frame(buf, 0, 0, W - 1, H - 1, { t = B, accent = true })
  rivet(buf, B, B, METAL); rivet(buf, W - B - 1, B, METAL); rivet(buf, B, H - B - 1, METAL); rivet(buf, W - B - 1, H - B - 1, METAL)
  if title then
    text(buf, title, W / 2, 4, hexRgb("#e8cd84"), { glow = 0.4 + 0.14 * pulse(t, 2), shadow = hexRgb("#1a1206"), size = 9 })
  end
end
Forge.drawPanel = drawPanel

local function drawTooltip(buf, W, H, t, lines)
  local B = 2
  plate(buf, B, B, W - B - 1, H - B - 1, 0, false)
  veins(buf, B, B, W - B - 1, H - B - 1, 42, t)
  frame(buf, 0, 0, W - 1, H - 1, { t = B, accent = true })
  rivet(buf, B, B, METAL); rivet(buf, W - B - 1, B, METAL); rivet(buf, B, H - B - 1, METAL); rivet(buf, W - B - 1, H - B - 1, METAL)
  local y = 4
  for i = 1, #lines do
    local ln = lines[i]
    text(buf, ln.txt, 5, y, ln.gold and hexRgb("#e8cd84") or (ln.color or hexRgb("#b8a98c")),
      { left = true, glow = ln.gold and 0.3 or 0, size = ln.size or 8, shadow = hexRgb("#120c06") })
    y = y + (ln.gap or 9)
  end
end
Forge.drawTooltip = drawTooltip

-- ════════════════════════════ FOND de CARTE TCG (fiche monstre F1) ════════════════════════════
-- cardPanel(buf, W, H, t, opts) : FOND seul d'une fiche au survol (plaque qui RESPIRE + veines + cadre
-- patiné + rivets). Le CONTENU (portrait, chips, stats, prose) est dessiné PAR-DESSUS par la scène en
-- overlay (Layout + Chip) -> on garde la matière forge ici, la lisibilité TCG là-haut. opts :
--   accentCol : triple {dark,mid,bright} (teinte de rareté) ; nil = liseré métal sobre.
--   rich      : R4-R5 -> cadre PLUS épais (B=4) + œil qui guette qui s'ouvre/se ferme (héros « rayonnant »).
--   seed      : graine de la patine/veines (stable par unité -> craquelures fixes).
local function cardPanel(buf, W, H, t, opts)
  opts = opts or {}
  local rich = opts.rich and true or false
  local B = rich and 4 or 3
  local seed = opts.seed or 51
  plate(buf, B, B, W - B - 1, H - B - 1, 0, false)
  -- RESPIRATION de la plaque (mêmes ondes que drawPanel) : la matière vit, sans bruit.
  for y = B + 1, H - B - 2 do
    for x = B + 1, W - B - 2 do
      local m = sin(x * 0.5 + t * 0.6) + sin(y * 0.6 - t * 0.5)
      if m > 1.4 then buf:blend(x, y, { 6, 4, 12 }, 0.16 * (m - 1.4)) end
    end
  end
  veins(buf, B, B, W - B - 1, H - B - 1, seed, t)
  -- ŒIL qui guette (héros uniquement) : s'ouvre puis se referme en cycle, bas-droite, hors du contenu lourd.
  if rich then
    local ec = ((t * 0.07 + (seed % 7) * 0.13) % 1)
    local eo = ec < 0.18 and sin(ec / 0.18 * math.pi) or 0
    if eo > 0.01 then
      drawEye(buf, floor(W * 0.86 + 0.5), floor(H * 0.9 + 0.5), 5, clamp(eo), 0.5, t, seed + 3, { blood = 0.6, squash = 0.7 })
    end
  end
  frame(buf, 0, 0, W - 1, H - 1, { t = B, accent = true, accentCol = opts.accentCol })
  if rich then frameWeather(buf, 0, 0, W - 1, H - 1, B, seed + 11, METAL, false) end
  rivet(buf, B, B, METAL); rivet(buf, W - B - 1, B, METAL)
  rivet(buf, B, H - B - 1, METAL); rivet(buf, W - B - 1, H - B - 1, METAL)
end
Forge.cardPanel = cardPanel

-- uiCard(id, x, y, w, h, opts) : pont STATEFUL (caché par id) pour le FOND de la fiche monstre. La plaque
-- RESPIRE -> on re-bake chaque frame (1 seul widget par carte visible ; la fiche au survol est unique).
-- opts = { accentCol?, rich?, seed?, px?, t? }. Headless-safe (render/blit pcall-gardés).
Forge._cardCache = {}
function Forge.uiCard(id, x, y, w, h, opts)
  opts = opts or {}
  local px = opts.px or PX
  local aw, ah = max(1, floor(w / px)), max(1, floor(h / px))
  local e = Forge._cardCache[id]
  if not e or e.aw ~= aw or e.ah ~= ah then
    e = { widget = Forge.newWidget(aw, ah), aw = aw, ah = ah }
    Forge._cardCache[id] = e
  end
  local t = opts.t or Forge._uiClock
  e.image = Forge.render(e.widget, function(b, W, H, tt)
    cardPanel(b, W, H, tt, { accentCol = opts.accentCol, rich = opts.rich, seed = opts.seed })
  end, t)
  Forge.blit(e.image, x, y, px)
  return true
end

local function drawBanner(buf, W, H, word, kind, t)
  local col = kind == "defeat" and hexRgb("#c43830") or hexRgb("#dcb85c")
  local glo = kind == "defeat" and BLOOD.hot or ACC.bright
  local my = floor(H / 2 + 0.5)
  for ry = -1, 1, 2 do
    local yy = my + ry * (H / 2 - 2)
    for x = 3, W - 4 do
      local a = 1 - abs(x - W / 2) / (W / 2 - 3)
      buf:set(x, yy, mix(METAL.outline, METAL.hi, 0.55 * a))
    end
  end
  text(buf, word, W / 2, my - 5, mix(col, glo, 0.25 * (0.7 + 0.3 * sin(t * 3))), { size = 13, shadow = METAL.outline })
end
Forge.drawBanner = drawBanner

-- ════════════════════════════ CARTE DE RELIQUE ════════════════════════════
local function drawRelicCard(buf, W, H, state, relic, t)
  local sel = state == "selected"
  local hov = state == "hover"
  local B = 3
  plate(buf, B, B, W - B - 1, H - B - 1, sel and -0.15 or 0, false)
  veins(buf, B, B, W - B - 1, H - B - 1, 33, t)
  frame(buf, 0, 0, W - 1, H - 1, { t = B, accent = sel or hov })
  rivet(buf, B, B, METAL); rivet(buf, W - B - 1, B, METAL); rivet(buf, B, H - B - 1, METAL); rivet(buf, W - B - 1, H - B - 1, METAL)
  local f = FAM[relic.fam]
  local cx, y = W / 2, 9
  local g = sel and (0.6 + 0.4 * pulse(t, 1)) or (hov and 0.4 or 0.2)
  diamond(buf, cx, y + 6, 7, mix(f.d, f.c, 0.45), mix(f.c, ACC.bright, g * 0.6), { 255, 255, 255 })
  drawEye(buf, cx, y + 7, 5, g, g, t, 5, { blood = 0.5, squash = 0.72 })
  y = y + 16
  text(buf, relic.name:upper(), cx, y, hexRgb("#e8cd84"), { glow = sel and 0.6 or 0.3, size = 9, shadow = hexRgb("#1a1206") })
  y = y + 10
  for x = 6, W - 7 do
    local a = 1 - abs(x - cx) / ((W - 12) / 2)
    buf:set(x, y, mix(METAL.outline, METAL.hi, 0.5 * a))
  end
  diamond(buf, cx, y, 2, ACC.bright, ACC.dark)
  y = y + 5
  text(buf, relic.effect, cx, y, hexRgb("#d9bd6a"), { size = 8 })
  y = y + 10
  text(buf, relic.flavor, cx, y, hexRgb("#8a7d66"), { size = 8 })
end
Forge.drawRelicCard = drawRelicCard

-- ════════════════════════════ ATOMES ════════════════════════════
local function drawTypePip(buf, W, H, fam, t)
  local f = FAM[fam]
  local r = floor(min(W, H) / 2) - 1
  local cx, cy = floor(W / 2 + 0.5), floor(H / 2 + 0.5)
  local c, e = f.c, mix(f.c, { 0, 0, 0 }, 0.45)
  if f.shape == "bar" then
    for y = -1, 1 do for x = -r, r do buf:set(cx + x, cy + y, abs(x) > r - 1 and e or c) end end
  elseif f.shape == "cross" then
    for k = -r, r do
      buf:set(cx + k, cy, abs(k) > r - 1 and e or c)
      buf:set(cx, cy + k, abs(k) > r - 1 and e or c)
      buf:set(cx + k, cy - 1, c); buf:set(cx + 1, cy + k, c)
    end
  elseif f.shape == "diamond" then
    diamond(buf, cx, cy, r, c, e, { 255, 255, 255 })
  elseif f.shape == "star" then
    for s = 0, 4 do
      local a = s / 5 * 6.28 - 1.57
      for rr = 0, r do buf:set(floor(cx + cos(a) * rr + 0.5), floor(cy + sin(a) * rr + 0.5), rr > r - 1 and e or c) end
    end
    buf:set(cx, cy, c)
  else
    for yy = -r, r do for xx = -r, r do local d = hypot(xx, yy); if d <= r then buf:set(cx + xx, cy + yy, d > r - 1 and e or c) end end end
  end
  buf:add(cx - 1, cy - 1, { 255, 255, 255 }, 0.3)
end
Forge.drawTypePip = drawTypePip

local function drawLevelPips(buf, W, H, n, t)
  for i = 0, n - 1 do
    diamond(buf, 3 + i * 5, H / 2, 2, mix(ACC.mid, ACC.bright, 0.5 + 0.5 * pulse(t, i)), ACC.dark, { 255, 255, 255 })
  end
end
Forge.drawLevelPips = drawLevelPips

local function drawGem(buf, W, H, on, t)
  local cx, cy = W / 2 - 0.5, H / 2 - 0.5
  local Rc = min(W, H) / 2 - 0.5
  for y = floor(cy - Rc), math.ceil(cy + Rc) do
    for x = floor(cx - Rc), math.ceil(cx + Rc) do
      local dx, dy = x - cx, y - cy
      local d = hypot(dx, dy)
      if d >= Rc - 2 and d <= Rc + 0.4 then
        local lit = (-dx / d * 0.4 - dy / d * 0.5)
        buf:set(x, y, (d > Rc - 0.5 or d < Rc - 1.5) and METAL.outline
          or (lit > 0 and mix(METAL.mid, METAL.hi, lit) or METAL.deep))
      end
    end
  end
  local r = Rc - 3
  local g = on and (0.55 + 0.45 * pulse(t, 2)) or 0
  for y2 = -r, r do
    for x2 = -r, r do
      local m = abs(x2) + abs(y2)
      if m <= r then
        local c
        if on then
          c = m >= r - 0.5 and mix(ACC.dark, ACC.mid, 0.5) or mix(ACC.mid, ACC.bright, g * (1 - m / r))
        else
          c = m >= r - 0.5 and hexRgb("#2a200f") or hexRgb("#120c08")
        end
        buf:set(floor(cx + x2 + 0.5), floor(cy + y2 + 0.5), c)
      end
    end
  end
  if on then
    buf:add(floor(cx - r * 0.3 + 0.5), floor(cy - r * 0.3 + 0.5), { 255, 255, 255 }, 0.6)
    buf:add(floor(cx + 0.5), floor(cy + 0.5), ACC.bright, g * 0.5)
  end
end
Forge.drawGem = drawGem

local function drawDivider(buf, W, H, t)
  local my = floor(H / 2)
  for x = 0, W - 1 do
    local a = 1 - abs(x - W / 2) / (W / 2)
    buf:set(x, my, mix(METAL.outline, METAL.hi, 0.55 * a))
    buf:set(x, my + 1, mix(METAL.outline, METAL.base, 0.4 * a))
  end
  local trav = ((t * 0.32) % 1.4 - 0.2) * W
  for dx = -4, 4 do
    local X = floor(trav + dx + 0.5)
    local f = max(0, 1 - abs(dx) / 4)
    if X > 0 and X < W then buf:add(X, my, ACC.bright, f * 0.7); buf:add(X, my + 1, ACC.mid, f * 0.4) end
  end
  diamond(buf, floor(W / 2), my, 2, mix(METAL.base, METAL.hi, 0.5 + 0.3 * pulse(t, 1)), METAL.outline, ACC.bright)
end
Forge.drawDivider = drawDivider

local function drawEyeRing(buf, W, H, open, glow, t, seed)
  local cx, cy = W / 2 - 0.5, H / 2 - 0.5
  local Rc = min(W, H) / 2 - 0.5
  for y = floor(cy - Rc), math.ceil(cy + Rc) do
    for x = floor(cx - Rc), math.ceil(cx + Rc) do
      local dx, dy = x - cx, y - cy
      local d = hypot(dx, dy)
      if d >= Rc - 2 and d <= Rc + 0.4 then
        local lit = (-dx / d * 0.4 - dy / d * 0.5)
        buf:set(x, y, (d > Rc - 0.5 or d < Rc - 1.5) and METAL.outline
          or (lit > 0 and mix(METAL.mid, METAL.hi, lit) or METAL.deep))
      end
    end
  end
  drawEye(buf, cx, cy, Rc - 3, open, glow, t, seed, { blood = 0.6, squash = 0.8 })
end
Forge.drawEyeRing = drawEyeRing

-- ════════════════════════════ WIDGET (cache Image+ImageData par taille) ════════════════════════════
-- Forge.newWidget(aw, ah) -> { buf, image, imageData, aw, ah }. Alloué UNE FOIS. Headless -> pas de bake
-- (image/imageData nil), le widget existe quand même (la scène ne crashe pas).
function Forge.newWidget(aw, ah)
  aw, ah = max(1, floor(aw)), max(1, floor(ah))
  local w = { aw = aw, ah = ah, buf = Forge.newBuf(aw, ah) }
  if real() then
    local okd, id = pcall(love.image.newImageData, aw, ah)
    if okd and id then
      w.imageData = id
      local oki, img = pcall(love.graphics.newImage, id)
      if oki and img then pcall(img.setFilter, img, "nearest", "nearest"); w.image = img end
    end
  end
  return w
end

-- Forge.render(widget, drawFn, t) : clear le tampon, exécute drawFn(buf, aw, ah, t), copie le tampon dans
-- l'ImageData (ffi.copy via getFFIPointer) puis replacePixels -> Image à jour. Retourne l'Image (ou nil
-- headless). drawFn DOIT écrire dans le tampon octets (set/blend/add). 100% pcall-gardé.
function Forge.render(w, drawFn, t)
  if not w then return nil end
  local buf = w.buf
  if buf then buf:clear() end
  drawFn(buf, w.aw, w.ah, t or 0)
  if not (real() and w.imageData and w.image and buf and buf.d) then return w.image end
  local ok = pcall(function()
    local ptr = w.imageData:getFFIPointer()
    ffi.copy(ffi.cast("uint8_t*", ptr), buf.d, w.aw * w.ah * 4)
    w.image:replacePixels(w.imageData)
  end)
  if not ok then return w.image end
  return w.image
end

-- Forge.blit(image, x, y, px?) : dessine l'Image du widget à (x,y) en ESPACE DESIGN, scale ENTIER (px ou
-- PX par défaut) nearest, coords planchées (net). px permet au TUNER de comparer 2/3/4 sans re-baker.
-- No-op headless (image nil). Restaure la couleur blanche.
function Forge.blit(image, x, y, px)
  if not image then return end
  local g = love.graphics
  if not (g and g.draw) then return end
  px = px or PX
  g.setColor(1, 1, 1, 1)
  pcall(g.draw, image, floor(x), floor(y), 0, px, px)
  g.setColor(1, 1, 1, 1)
end

-- Forge.diamondAt(cx, cy, r, color, edge?) : un DIAMANT forge dessiné DIRECTEMENT (love.graphics, pas un
-- tampon) — pour les décorations d'overlay (pips de niveau, etc.) en ESPACE DESIGN. color = {r,g,b} 0..1
-- (Theme.c). Centre clair + bord sombre, petit spec. No-op headless / pcall-gardé.
function Forge.diamondAt(cx, cy, r, color, edge)
  local g = love.graphics
  if not (g and g.rectangle) then return end
  cx, cy, r = floor(cx), floor(cy), max(1, floor(r))
  local cr, cg, cb = color[1], color[2], color[3]
  local er, eg, eb = (edge or color)[1] * 0.45, (edge or color)[2] * 0.45, (edge or color)[3] * 0.45
  for y = -r, r do
    local m = r - abs(y)
    for x = -m, m do
      local onEdge = (abs(x) + abs(y) >= r)
      if onEdge then g.setColor(er, eg, eb, 1) else g.setColor(cr, cg, cb, 1) end
      pcall(g.rectangle, "fill", cx + x, cy + y, 1, 1)
    end
  end
  g.setColor(1, 1, 1, 1) -- spec
  pcall(g.rectangle, "fill", cx - 1, cy - 1, 1, 1)
  g.setColor(1, 1, 1, 1)
end

-- easing d'interaction (port de easeBtn / easeSmall du JS).
-- ⚠️ PIÈGE LUA vs JS : la scène stocke st.hover / st.active en NOMBRES (0/1). En Lua, 0 est VRAI (seuls
-- nil/false sont faux) -> `st.hover and 0.55 or 0` donnait 0.55 même au repos => le bouton se croyait
-- TOUJOURS survolé (rest ≈ hover, « le survol ne fait rien »). On teste donc explicitement > 0 (accepte
-- aussi bien un booléen qu'un nombre via `truthy`).
local function on(v) return v and v ~= 0 and v ~= false end
function Forge.easeBtn(st)
  local pg = on(st.active) and 0.95 or (on(st.hover) and 0.55 or 0)
  local pp = on(st.active) and 1 or 0
  local po = on(st.hover) and 1 or 0
  st.glow = elerp(st.glow or 0, pg, 0.22)
  st.press = elerp(st.press or 0, pp, 0.3)
  st.eyeOpen = elerp(st.eyeOpen or 0, po, 0.16)
end
function Forge.easeSmall(st)
  local pg = on(st.active) and 0.95 or (on(st.hover) and 0.55 or 0)
  local pp = on(st.active) and 1 or 0
  st.glow = elerp(st.glow or 0, pg, 0.22)
  st.press = elerp(st.press or 0, pp, 0.3)
end

-- ════════════════════════════ PONT BOUTON (uiButton) — pour les scènes ════════════════════════════
-- Les widgets Forge sont STATEFUL (Image cachée + état d'interaction lissé + nuée d'yeux seedée), à la
-- différence du Draw.button immédiat. uiButton encapsule tout ce cycle de vie derrière un `id` STABLE :
-- l'Image, l'état (hover/active/glow/press/eyeOpen) et les yeux SURVIVENT entre les frames. La SCÈNE garde
-- son propre hit-test/clic ; ce pont ne fait que DESSINER. PERF : on ne RE-BAKE (buffer->replacePixels) que
-- si le widget ANIME (hover/easing en cours) ou si label/taille/disabled a changé ; sinon on blitte l'Image
-- cachée telle quelle. Headless-safe (render/blit pcall-gardés ; pas de bake sous le mock).
--
-- Forge.uiButton(id, x, y, w, h, label, opts) :
--   id       : clé stable de cache (ex. "build.combat", "build.reroll").
--   x,y,w,h  : rect en ESPACE DESIGN (w,h = px écran ; on en dérive l'art = w/px × h/px).
--   label    : texte du bouton.
--   opts     : {
--     hover, active   : booléens calculés par la scène (truthy).
--     disabled        : grise + désactive l'effet.
--     mouse = {mx,my} : curseur en ESPACE DESIGN -> converti en art-local pour le gaze des yeux (tone cta).
--     tone            : "cta" (gros bouton-œil) | "eco" (petit + diamant de coût) | "icon" (carré sigil/…).
--     cost            : valeur de coût (tone eco) ; icon = `kind` ("sigil"/"left"/"right"/"gear").
--     seed            : graine de la nuée (défaut dérivée de l'id).
--     px              : densité d'affichage (défaut Forge.PX=2).
--     fontSz, pad, eyeR, frameTh : surcharges de taille (défaut = valeurs validées).
--     t               : horloge (secondes) pour l'animation (défaut interne auto-incrémentée).
--   }
-- Retourne true (dessiné) — la scène gère le clic elle-même.
Forge._btnCache = {}
Forge._uiClock = 0
local function strhash(s)
  local h = 2166136261
  for i = 1, #s do h = (h * 16777619 + s:byte(i)) % 4294967296 end
  return h
end
function Forge.uiButton(id, x, y, w, h, label, opts)
  opts = opts or {}
  local px = opts.px or PX
  local tone = opts.tone or "cta"
  local disabled = opts.disabled and true or false
  local aw, ah = max(1, floor(w / px)), max(1, floor(h / px))
  local seed = opts.seed or (strhash(id) % 9973)
  local fontSz = opts.fontSz or 8
  local frameTh = opts.frameTh or 2
  local pad = opts.pad or 5
  local eyeR = opts.eyeR or 8

  -- entrée de cache (par id). On la (ré)initialise si elle n'existe pas ou si la GÉOMÉTRIE/label/état change.
  local e = Forge._btnCache[id]
  local cfgKey = tone .. "|" .. aw .. "x" .. ah .. "|" .. tostring(label) .. "|" .. tostring(disabled)
    .. "|" .. fontSz .. "|" .. eyeR .. "|" .. pad .. "|" .. tostring(opts.cost)
  if not e or e.aw ~= aw or e.ah ~= ah then
    e = { st = { hover = 0, active = 0, glow = 0, press = 0, eyeOpen = 0 },
      widget = Forge.newWidget(aw, ah), aw = aw, ah = ah }
    Forge._btnCache[id] = e
  end
  local configChanged = (e.cfgKey ~= cfgKey)
  if configChanged then
    e.cfgKey = cfgKey
    if tone == "cta" and not disabled then
      e.eyes = Forge.genEyes(aw, ah - DROP, seed, label or "", fontSz, { frameTh = frameTh, pad = pad, eyeR = eyeR })
    else
      e.eyes = nil
    end
    e.dirty = true
  end

  -- état d'interaction : on l'EASE vers hover/active. disabled -> tout retombe à 0.
  local st = e.st
  st.hover = (not disabled) and (opts.hover and 1 or 0) or 0
  st.active = (not disabled) and (opts.active and 1 or 0) or 0
  local before = st.glow + st.press + (st.eyeOpen or 0)
  if tone == "cta" then Forge.easeBtn(st) else Forge.easeSmall(st) end
  local after = st.glow + st.press + (st.eyeOpen or 0)
  local animating = math.abs(after - before) > 0.0008 or st.glow > 0.001 or st.press > 0.001 or (st.eyeOpen or 0) > 0.001

  -- horloge : opts.t (secondes) ou auto. L'animation des yeux/glint dépend de t -> on re-bake tant qu'on anime.
  local t = opts.t or Forge._uiClock

  -- gaze : curseur design -> art-local de CE bouton (les yeux suivent la souris).
  local gz = nil
  if tone == "cta" and not disabled and opts.mouse and (st.eyeOpen or 0) > 0.05 then
    gz = { (opts.mouse.mx - x) / px, (opts.mouse.my - y) / px }
  end

  -- RE-BAKE seulement si nécessaire (anime / config changée / 1re fois), sinon on garde l'Image cachée.
  if e.dirty or animating or not e.image then
    local drawFn
    if tone == "eco" then
      drawFn = function(b, W, H, tt)
        Forge.drawEcoBtn(b, W, H, st.press, st.glow, seed, label or "", opts.cost, disabled, tt)
      end
    elseif tone == "icon" then
      drawFn = function(b, W, H, tt)
        Forge.drawIconBtn(b, W, H, st.press, st.glow, seed, opts.cost or "sigil", tt)
      end
    else -- cta
      drawFn = function(b, W, H, tt)
        Forge.drawButton(b, W, H, st.press, st.eyeOpen, st.glow, seed, label or "", disabled, e.eyes, gz, fontSz, tt,
          { frameTh = frameTh })
      end
    end
    e.image = Forge.render(e.widget, drawFn, t)
    e.dirty = false
  end
  Forge.blit(e.image, x, y, px)
  return true
end

-- Avance l'horloge interne des uiButton (à appeler 1×/frame depuis une scène, en SECONDES). Optionnel si
-- la scène passe opts.t elle-même. Idempotent / sans danger headless.
function Forge.uiTick(dtSeconds) Forge._uiClock = Forge._uiClock + (dtSeconds or 0) end

-- ════════════════════════════ SOCKET (case forge, fond transparent) ════════════════════════════
-- Une « socket » = un CADRE de métal PATINÉ à fond TRANSPARENT (le rig dessiné dessous transparaît). Sert
-- aux 9 cases du plateau : la signature forge (frame + frameWeather) borde la créature SANS la masquer.
-- accentCol = triple {dark,mid,bright} du liseré (état : or survol / sang voisin / vert drop / nil sobre).
-- Forge.accentFrom(rgb255) construit un triple à partir d'une couleur de base (Theme.c en floats 0..1).
function Forge.accentFrom(rgb)
  -- rgb peut être en floats 0..1 (Theme.c) ou en octets ; on normalise en OCTETS (le kit travaille en 0..255).
  local r, g, b = rgb[1], rgb[2], rgb[3]
  if r <= 1 and g <= 1 and b <= 1 then r, g, b = r * 255, g * 255, b * 255 end
  local mid = { r, g, b }
  return {
    dark   = { r * 0.5, g * 0.5, b * 0.5 },
    mid    = mid,
    bright = { r + (255 - r) * 0.45, g + (255 - g) * 0.45, b + (255 - b) * 0.45 },
  }
end

-- socket(buf, W, H, opts) : opts = { accentCol?, frameTh=3, seed, weather=true }. Dessine UNIQUEMENT le
-- cadre patiné (centre laissé transparent). accentCol nil -> liseré métal sobre ; sinon liseré teinté.
local function socket(buf, W, H, opts)
  opts = opts or {}
  local fth = opts.frameTh or 3
  local x0, y0, x1, y1 = 0, 0, W - 1, H - 1
  frame(buf, x0, y0, x1, y1, { t = fth, accent = (opts.accentCol ~= nil), accentCol = opts.accentCol })
  if opts.weather ~= false then frameWeather(buf, x0, y0, x1, y1, fth, opts.seed or 7, METAL, false) end
  -- 4 rivets aux coins (cohérent avec les boutons).
  local ri = max(2, fth)
  rivet(buf, x0 + ri, y0 + ri, METAL); rivet(buf, x1 - ri - 1, y0 + ri, METAL)
  rivet(buf, x0 + ri, y1 - ri - 1, METAL); rivet(buf, x1 - ri - 1, y1 - ri - 1, METAL)
end
Forge.socket = socket

-- uiPlate(id, x, y, w, h, opts) : FOND de plaque forge PLEINE (matière + trame, SANS cadre) — caché par id.
-- opts = { px?, press?, disabled? }. Sert de FOND de carte de boutique (derrière la créature), pour que la
-- carte lise comme une dalle dense et remplie (≠ cadre creux). Re-bake seulement si la taille/l'état change.
Forge._plateCache = {}
function Forge.uiPlate(id, x, y, w, h, opts)
  opts = opts or {}
  local px = opts.px or PX
  local aw, ah = max(1, floor(w / px)), max(1, floor(h / px))
  local disabled = opts.disabled and true or false
  local e = Forge._plateCache[id]
  if not e or e.aw ~= aw or e.ah ~= ah then
    e = { widget = Forge.newWidget(aw, ah), aw = aw, ah = ah }
    Forge._plateCache[id] = e
  end
  local cfg = tostring(disabled)
  if e.cfg ~= cfg or not e.image then
    e.cfg = cfg
    e.image = Forge.render(e.widget, function(b, W, H, _) plate(b, 0, 0, W - 1, H - 1, 0, disabled) end, 0)
  end
  Forge.blit(e.image, x, y, px)
  return true
end

-- uiSocket(id, x, y, w, h, opts) : pont CACHÉ (par id) pour les cases. opts = { accentCol?, px?, seed?,
-- frameTh?, weather? }. Re-bake seulement si l'accent/la taille change (les cases ne s'animent pas).
-- Headless-safe. La scène garde son hit-test ; ce pont ne fait que dessiner le SOCLE (fond transparent).
Forge._sockCache = {}
function Forge.uiSocket(id, x, y, w, h, opts)
  opts = opts or {}
  local px = opts.px or PX
  local aw, ah = max(1, floor(w / px)), max(1, floor(h / px))
  local accentCol = opts.accentCol
  -- clé de couleur d'accent (pour détecter un changement d'état -> re-bake).
  local ak = accentCol and (floor(accentCol.mid[1]) .. "," .. floor(accentCol.mid[2]) .. "," .. floor(accentCol.mid[3])) or "none"
  local e = Forge._sockCache[id]
  if not e or e.aw ~= aw or e.ah ~= ah then
    e = { widget = Forge.newWidget(aw, ah), aw = aw, ah = ah }
    Forge._sockCache[id] = e
  end
  local cfg = ak .. "|" .. tostring(opts.frameTh) .. "|" .. tostring(opts.weather)
  if e.cfg ~= cfg or not e.image then
    e.cfg = cfg
    e.image = Forge.render(e.widget, function(b, W, H, _)
      socket(b, W, H, { accentCol = accentCol, frameTh = opts.frameTh or 3, seed = opts.seed, weather = opts.weather })
    end, 0)
  end
  Forge.blit(e.image, x, y, px)
  return true
end

return Forge
