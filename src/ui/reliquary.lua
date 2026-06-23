-- src/ui/reliquary.lua
-- LA BANDE GRAVÉE DU RELIQUAIRE — la bordure d'écran en PIERRE INCISÉE (veines + sang), portée du
-- renderer du designer (pit-forge.js `_engrave`). C'est l'ENROBAGE signature : un cadre de pierre noire
-- gravée qui CEINT tout l'écran. À NE PAS confondre avec le biseau de laiton de `Frame` (qui borde un
-- widget) : ici c'est de la pierre gris-violacé creusée de veines de sang, le cadre du jeu entier.
--
-- TECHNIQUE : baké UNE FOIS par taille en ImageData (`setPixel`), filtré NEAREST, dessiné ×PX (gros pixels
-- nets, cohérent avec le monde ×4). Seule la BANDE (T px d'épaisseur) est calculée ; l'intérieur reste
-- TRANSPARENT (alpha 0) -> le contenu de la scène se dessine par-dessus. RENDER pur (cosmétique) — hors
-- firewall SIM. Headless-safe : tout le bake est pcall-gardé ; si love.image/love.math manquent (mock), la
-- bande devient un no-op silencieux (la scène se garde, aucun crash).
--
-- Réf algo : docs/pixel-art/design-system-spec.md §4 + docs/pixel-art/pit-forge.js.

local Reliquary = {}

local PX = 4 -- un pixel d'art -> PX pixels d'espace design (cohérent avec le rendu monde ×4)

-- Palette (octets du designer -> floats 0..1). Pierre gris-violacé + sang incisé.
local function rgb(r, g, b) return { r / 255, g / 255, b / 255 } end
local IRON   = rgb(3, 2, 7)     -- liseré extérieur
local STONE0 = rgb(13, 10, 18)  -- pierre de base
local STONE1 = rgb(22, 17, 30)  -- grain clair
local STONE2 = rgb(6, 4, 11)    -- grain sombre
local LIP    = rgb(60, 50, 68)  -- lèvre intérieure
local LIPH   = rgb(96, 82, 108) -- éclat de lèvre (16 %)
local SHAD   = rgb(2, 1, 5)     -- ombre intérieure
local TR     = rgb(1, 0, 3)     -- canal gravé (veine non-sanglante)
local BD     = rgb(36, 9, 9)    -- sang profond
local BL     = rgb(82, 22, 17)  -- sang mi-teinte
local BM     = rgb(146, 46, 33) -- sang chaud
local BH     = rgb(206, 78, 56) -- sang vif

local function setPx(id, x, y, c) id:setPixel(x, y, c[1], c[2], c[3], 1) end

-- Une arête : 4 « ruisseaux » sinusoïdaux de veines incisées (occ[] = première veine gagne).
-- mapXY(t, depth) -> (x, y) sur la face de cette arête (top/bottom/left/right). len = longueur de l'arête.
local function edgeVeins(id, rng, occ, W, H, T, len, mapXY)
  local K = 4
  for k = 0, K - 1 do
    local base = 1.6 + (T - 4.8) * (K > 1 and (k / (K - 1)) or 0) -- profondeurs réparties
    local amp = 0.9 + rng:random() * 1.6
    local freq = 0.085 + rng:random() * 0.13
    local phase = rng:random() * 6.2832
    local blood = rng:random() < 0.5
    for t = 0, len - 1 do
      local u = base + amp * math.sin(t * freq + phase) + 0.5 * math.sin(t * freq * 0.43 + phase * 1.7)
      if u < 1 then u = 1 elseif u > T - 3 then u = T - 3 end
      local ui = math.floor(u + 0.5)
      local x, y = mapXY(t, ui, W, H)
      local idx = y * W + x
      if x >= 0 and x < W and y >= 0 and y < H and not occ[idx] then
        occ[idx] = true
        local c
        if blood then
          local r = rng:random()
          c = (r < 0.06) and BH or (r < 0.30 and BM or BL)
        else
          c = TR
        end
        setPx(id, x, y, c)
        -- pixel adjacent +1 en profondeur (ourlet sombre)
        local x2, y2 = mapXY(t, ui + 1, W, H)
        if x2 >= 0 and x2 < W and y2 >= 0 and y2 < H then setPx(id, x2, y2, blood and BD or BL) end
        -- coulure vers l'intérieur (6 %)
        if rng:random() < 0.06 then
          local dl = 1 + math.floor(rng:random() * 3)
          for d = 1, dl do
            local xd, yd = mapXY(t, ui + 1 + d, W, H)
            if xd >= 0 and xd < W and yd >= 0 and yd < H and not occ[yd * W + xd] then setPx(id, xd, yd, BL) end
          end
        end
      end
    end
  end
end

-- Perle de coin : losange 5×5 (SHAD -> BM -> BH) + 3px de coulure vers l'intérieur.
local function cornerBead(id, rng, W, H, cx, cy, ix, iy)
  for dy = -2, 2 do
    for dx = -2, 2 do
      local m = math.abs(dx) + math.abs(dy)
      if m <= 2 then
        local x, y = cx + dx, cy + dy
        if x >= 0 and x < W and y >= 0 and y < H then
          setPx(id, x, y, m == 2 and SHAD or (m == 1 and BM or BH))
        end
      end
    end
  end
  for d = 1, 3 do
    local x, y = cx + ix * (2 + d), cy + iy * (2 + d)
    if x >= 0 and x < W and y >= 0 and y < H then setPx(id, x, y, d == 1 and BM or BL) end
  end
end

-- Grave la bande (bordure T px) dans un ImageData W×H d'art. Intérieur laissé transparent.
local function engrave(id, W, H, T, seed)
  local rng = love.math.newRandomGenerator(seed)
  -- 1) Bande de pierre (4 bords) : profondeur depuis le bord -> liseré / lèvre / ombre / grain bruité.
  for y = 0, H - 1 do
    for x = 0, W - 1 do
      local dp = math.min(x, W - 1 - x, y, H - 1 - y)
      if dp < T then
        local c
        if dp == 0 then
          c = IRON
        elseif dp == T - 1 then
          c = SHAD
        elseif dp == 1 then
          c = (rng:random() < 0.16) and LIPH or LIP
        else
          local n = (x * 7 + y * 13) % 13
          c = (n < 2) and STONE2 or (n > 10 and STONE1 or STONE0)
        end
        setPx(id, x, y, c)
      end
    end
  end
  -- 2) Veines incisées sur les 4 arêtes (occ partagé : une veine ne réécrit pas une autre).
  local occ = {}
  edgeVeins(id, rng, occ, W, H, T, W, function(t, u) return t, u end)               -- haut
  edgeVeins(id, rng, occ, W, H, T, W, function(t, u, w, h) return t, h - 1 - u end) -- bas
  edgeVeins(id, rng, occ, W, H, T, H, function(t, u) return u, t end)               -- gauche
  edgeVeins(id, rng, occ, W, H, T, H, function(t, u, w) return w - 1 - u, t end)    -- droite
  -- 3) Perles de sang aux 4 coins.
  local Tc = math.max(3, math.floor(T / 2))
  cornerBead(id, rng, W, H, Tc, Tc, 1, 1)
  cornerBead(id, rng, W, H, W - 1 - Tc, Tc, -1, 1)
  cornerBead(id, rng, W, H, Tc, H - 1 - Tc, 1, -1)
  cornerBead(id, rng, W, H, W - 1 - Tc, H - 1 - Tc, -1, -1)
end

local function haveGraphics()
  return love and love.image and love.graphics and love.image.newImageData and love.math
    and love.math.newRandomGenerator
end

Reliquary._cache = {} -- [key] = Image | false (échec/headless)

-- Bake mémoïsé (par taille d'art + épaisseur). Renvoie une Image NEAREST, ou nil (headless / échec).
local function bakeImage(aw, ah, T, seed)
  if not haveGraphics() then return nil end
  local ok, img = pcall(function()
    local id = love.image.newImageData(aw, ah)
    engrave(id, aw, ah, T, seed)
    local image = love.graphics.newImage(id)
    if image.setFilter then image:setFilter("nearest", "nearest") end
    return image
  end)
  if ok then return img end
  return nil
end

-- Dessine la bande gravée pour couvrir le rect (x,y,w,h) en ESPACE DESIGN. Baké à la résolution d'art
-- (w/PX × h/PX), épaisseur opts.ft px d'art (def 10 ; le doc designer = 10, l'écran build = 8), dessiné ×PX.
-- L'intérieur est transparent : le contenu de la scène se dessine ensuite, à l'intérieur de l'inset().
function Reliquary.draw(x, y, w, h, opts)
  opts = opts or {}
  local T = opts.ft or 10
  local aw = math.max(2 * T + 2, math.floor(w / PX + 0.5))
  local ah = math.max(2 * T + 2, math.floor(h / PX + 0.5))
  local key = aw .. "_" .. ah .. "_" .. T
  local img = Reliquary._cache[key]
  if img == nil then
    img = bakeImage(aw, ah, T, aw * 131 + ah * 17 + T * 101 + 9) or false
    Reliquary._cache[key] = img
  end
  if not img or not (love and love.graphics) then return end
  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.draw(img, math.floor(x), math.floor(y), 0, PX, PX)
end

-- Inset utile : l'aire de contenu intérieure à la bande (pour ancrer le contenu dans le cadre).
-- pad = marge supplémentaire entre la pierre et le contenu (def 6 px d'art -> 6*PX design).
function Reliquary.inset(x, y, w, h, opts)
  opts = opts or {}
  local d = ((opts.ft or 10) + (opts.pad or 6)) * PX
  return x + d, y + d, w - 2 * d, h - 2 * d
end

Reliquary.PX = PX

return Reliquary
