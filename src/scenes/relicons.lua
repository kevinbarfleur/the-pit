-- src/scenes/relicons.lua
-- CABINET DE RELIQUES (debug/revue visuelle) — « le musée de la damnation ».
-- Affiche TOUTES les icônes de RelicGen (src/gen/relicgen.lua), bakées par le VRAI pipeline
-- (Sprite.bake -> Image nearest), pour juger la lisibilité en petit ET en gros.
--   Accès : [r] depuis build (bascule, cf. main.lua). Survol = zoom ×6 + flavor + sens mécanique.
--
-- Couche RENDER/scène (love.graphics autorisé). Calqué sur src/scenes/gallery.lua (pas de Theme/Draw,
-- love.graphics direct + Background). Labels littéraux (anglais) -> ZÉRO clé i18n nouvelle (en.lua intact).
-- Blit en SCALE ENTIER, positions Math.floor : pixel-perfect, jamais de flou.

local Background = require("src.fx.background")
local RelicGen = require("src.gen.relicgen")
local Draw = require("src.ui.draw")               -- pour Draw.begin/finish (transform espace-design du cadre)
local ScreenFrame = require("src.ui.screenframe") -- ENROBAGE partagé : cadre de pierre gravée + onglet « RELIC ICONS »

local Relicons = {}
Relicons.__index = Relicons

-- Métadonnées d'affichage (NOM + sens mécanique court), en dur. Le mapping id->icône vit dans RelicGen ;
-- ici on ne porte que des libellés de revue. (Le vrai texte de jeu vivra côté i18n/relics, branché ailleurs.)
local META = {
  bloodstone     = { name = "BLOODSTONE",     mech = "+attack damage",        flavor = "A heart of compressed murder." },
  carapace       = { name = "CARAPACE",       mech = "+max health",           flavor = "Shed by something that outgrew its death." },
  whetstone      = { name = "WHETSTONE",      mech = "+attack speed",          flavor = "Honed on something that bled freely." },
  aegis          = { name = "AEGIS",          mech = "-damage taken",          flavor = "A votive shield, cracked but kept." },
  kings_bowl     = { name = "THE KINGS' BOWL",mech = "+poison damage",         flavor = "A dozen kings drank deep." },
  ember_heart    = { name = "EMBER HEART",    mech = "+burn damage",           flavor = "It beats once an hour, and the hour burns." },
  weeping_nail   = { name = "THE WEEPING NAIL",mech = "+bleed damage",         flavor = "It drips, and does not stop." },
  grave_cap      = { name = "GRAVE CAP",      mech = "+rot damage",            flavor = "It fruits on what we bury." },
  hollow_choir   = { name = "HOLLOW CHOIR",   mech = "afflictions pierce healing", flavor = "A bell that rings the empty." },
  famines_math   = { name = "FAMINE'S MATH",  mech = "few units hit harder",   flavor = "It weighs a bone against nothing." },
  feeding_frenzy = { name = "FEEDING FRENZY", mech = "snowball on each kill",  flavor = "Too many teeth, never enough." },
  sacred_shield  = { name = "SACRED SHIELD",  mech = "0.5s opening invuln",    flavor = "A false halo, flickering." },
  -- vagues 3-4
  second_breath    = { name = "SECOND BREATH",    mech = "survive one fatal blow (1 HP)", flavor = "One last grain of air." },
  thornguard       = { name = "THORNGUARD",       mech = "your units reflect when struck", flavor = "Cruel to wear, crueler to grip." },
  forked_tongue    = { name = "FORKED TONGUE",    mech = "shock chains to a 2nd enemy",   flavor = "It speaks twice, and lies both times." },
  everburn         = { name = "EVERBURN",         mech = "your burns never decay",        flavor = "It refuses the dark." },
  plague_communion = { name = "PLAGUE COMMUNION", mech = "multi-afflicted enemies suffer more", flavor = "Drink of many poisons at once." },
  open_wounds      = { name = "OPEN WOUNDS",      mech = "your bleeds never close",       flavor = "It will not knit." },
}

-- Teinte d'accent par « famille mécanique » (cadre/nom au survol) : la couleur EST un indice (cf. relicgen).
local ACCENT = {
  bloodstone = { 0.66, 0.32, 0.24 }, weeping_nail = { 0.66, 0.32, 0.24 }, -- sang
  ember_heart = { 0.80, 0.50, 0.28 },                                     -- braise
  kings_bowl = { 0.48, 0.54, 0.20 }, grave_cap = { 0.48, 0.54, 0.20 },    -- poison
  sacred_shield = { 0.77, 0.63, 0.29 }, hollow_choir = { 0.66, 0.57, 0.44 }, -- or / os
  carapace = { 0.42, 0.46, 0.26 }, whetstone = { 0.55, 0.53, 0.49 },       -- chitine / fer
  aegis = { 0.45, 0.52, 0.58 }, famines_math = { 0.55, 0.53, 0.49 },       -- acier / fer
  feeding_frenzy = { 0.66, 0.57, 0.44 },                                   -- os
  -- vagues 3-4
  second_breath = { 0.66, 0.57, 0.44 },                                    -- os (survie / dernier souffle)
  thornguard = { 0.55, 0.53, 0.49 },                                       -- fer (renvoi / défense)
  forked_tongue = { 0.80, 0.50, 0.28 }, everburn = { 0.80, 0.50, 0.28 },   -- braise (choc chain / burn)
  plague_communion = { 0.48, 0.54, 0.20 },                                 -- poison (afflictions)
  open_wounds = { 0.66, 0.32, 0.24 },                                      -- sang (bleed)
}

-- Mise en page (pixels virtuels). 6 colonnes × 3 rangées = 18 cases (toutes les vagues d'un coup).
-- La grille tient DANS l'inset du cadre de pierre gravée (ScreenFrame) : marge ~10px virtuels (= (8+2)×4
-- design /4) -> aire utile [10,310]×[10,170]. GX0=18 (18+6*48=306 ≤ 310) ; GY0=14 (14+3*50=164 ≤ 170) :
-- la grille ne passe jamais sous la pierre. Les hit-tests (cellAt) lisent les mêmes GX0/GY0 -> ils suivent.
local COLS, ROWS = 6, 3
local CELL_W, CELL_H = 48, 50
local GX0, GY0 = 18, 14
local ICON_SCALE = 2 -- 16×16 -> 32×32 dans la grille (lecture d'ensemble)

function Relicons.new(palette, vw, vh, host)
  local self = setmetatable({
    palette = palette, vw = vw, vh = vh, host = host, t = 0,
    daChrome = true, -- la scène porte sa propre chrome (banner + cadre ScreenFrame) -> pas de HUD générique sous la pierre
    titleKey = "scene.relicons", hintKey = "ui.hint_relicons",
    bg = Background.new(palette, vw, vh),
    icons = {},  -- { {id, baked}, ... } dans l'ordre de RelicGen.order
    hover = nil,
  }, Relicons)

  -- Bake chaque icône UNE fois (jamais par frame), via le vrai pipeline (mémoïsé par RelicGen.cached).
  for _, id in ipairs(RelicGen.order) do
    self.icons[#self.icons + 1] = { id = id, baked = RelicGen.cached(id, palette) }
  end
  return self
end

-- Centre (cx, cy) d'une case de grille.
local function cellCenter(localIdx)
  local i = localIdx - 1
  local c = i % COLS
  local r = math.floor(i / COLS)
  local cx = GX0 + c * CELL_W + math.floor(CELL_W / 2)
  local cy = GY0 + r * CELL_H + math.floor(CELL_H / 2)
  return cx, cy
end

function Relicons:update(frameDt)
  self.t = self.t + frameDt
  self.bg:update(frameDt, self.t)
end

-- Halo de focus additif derrière une icône (la signature « objet maudit qui luit faiblement »).
-- Doux, pulsant lentement ; alpha bas (discrétion -> sinon « surnaturel »). col = accent mécanique.
local function drawFocusGlow(cx, cy, col, a, phase, t)
  local pulse = 0.7 + 0.3 * math.sin(t * 0.04 + phase)
  love.graphics.setBlendMode("add")
  for i = 3, 1, -1 do
    love.graphics.setColor(col[1], col[2], col[3], a * 0.07 * i * pulse)
    love.graphics.circle("fill", cx, cy, (i / 3) * 13)
  end
  love.graphics.setBlendMode("alpha")
  love.graphics.setColor(1, 1, 1, 1)
end

-- Blit d'une icône bakée centrée sur (cx, cy) à un scale entier donné. Positions Math.floor (pixel-perfect).
local function drawIcon(baked, cx, cy, scale)
  if not baked or not baked.image then return end
  local ox = math.floor(cx - (baked.w * scale) / 2 + 0.5)
  local oy = math.floor(cy - (baked.h * scale) / 2 + 0.5)
  love.graphics.draw(baked.image, ox, oy, 0, scale, scale)
end

function Relicons:drawWorld()
  self.bg:draw()

  for gi, it in ipairs(self.icons) do
    local cx, cy = cellCenter(gi)
    local col = ACCENT[it.id] or { 0.6, 0.6, 0.6 }
    local hovered = (self.hover == gi)

    -- halo de focus (toujours, discret ; un peu plus fort au survol).
    drawFocusGlow(cx, cy - 4, col, hovered and 1.0 or 0.6, gi * 1.7, self.t)

    -- liseré de case : accent au survol, sinon trait sourd.
    if hovered then
      love.graphics.setColor(col[1], col[2], col[3], 0.85)
    else
      love.graphics.setColor(0.18, 0.15, 0.20, 0.35)
    end
    love.graphics.rectangle("line", cx - CELL_W / 2 + 2, cy - CELL_H / 2 + 2, CELL_W - 4, CELL_H - 8)
    love.graphics.setColor(1, 1, 1, 1)

    drawIcon(it.baked, cx, cy - 4, ICON_SCALE)
  end
end

function Relicons:drawOverlay(view)
  local sw, sh = love.graphics.getDimensions()
  -- INSET du texte natif DANS le cadre de pierre : marge = la même que la grille virtuelle (10px virtuels),
  -- convertie en pixels écran via `view` (scale + letterbox). Le HUD ne passe jamais sous la bande gravée.
  local m = 10 * (view.scale or 4)
  local ix0, iy0 = (view.ox or 0) + m, (view.oy or 0) + m
  local ix1, iy1 = sw - (view.ox or 0) - m, sh - (view.oy or 0) - m

  -- Bandeau (haut-droite, résolution native, DANS l'inset).
  love.graphics.setColor(0.62, 0.58, 0.50, 0.9)
  love.graphics.printf("RELIC CABINET  -  " .. #self.icons .. " cursed artifacts  -  [g] gallery  [r] back", ix0, iy0 + 2, ix1 - ix0, "right")

  -- Inspection de la relique survolée : ZOOM ×6 (juger le pixel art) + nom/flavor/sens mécanique.
  if self.hover and self.icons[self.hover] then
    local it = self.icons[self.hover]
    local m2 = META[it.id] or { name = it.id, mech = "", flavor = "" }
    local col = ACCENT[it.id] or { 0.8, 0.8, 0.8 }

    -- Zoom du sprite (bas-droite, DANS l'inset), scale ×6 natif. Blit de l'Image bakée à l'écran (nearest).
    local zScale = 6
    local zx = ix1 - it.baked.w * zScale
    local zy = iy1 - it.baked.h * zScale
    -- cadre + halo derrière le zoom.
    love.graphics.setColor(0.10, 0.08, 0.12, 0.85)
    love.graphics.rectangle("fill", zx - 6, zy - 6, it.baked.w * zScale + 12, it.baked.h * zScale + 12)
    love.graphics.setColor(col[1], col[2], col[3], 0.7)
    love.graphics.rectangle("line", zx - 6, zy - 6, it.baked.w * zScale + 12, it.baked.h * zScale + 12)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(it.baked.image, zx, zy, 0, zScale, zScale)

    -- Texte (bas-gauche, DANS l'inset).
    local x, y = ix0, iy1 - 64
    love.graphics.setColor(col[1], col[2], col[3], 1)
    love.graphics.print(m2.name, x, y)
    love.graphics.setColor(0.72, 0.68, 0.60, 0.95)
    love.graphics.print(m2.mech, x, y + 18)
    love.graphics.setColor(0.50, 0.46, 0.42, 0.9)
    love.graphics.print('"' .. m2.flavor .. '"', x, y + 34)
    love.graphics.setColor(0.36, 0.33, 0.30, 0.85)
    love.graphics.print("id: " .. it.id, x, y + 50)
    love.graphics.setColor(1, 1, 1, 1)
  end

  -- ENROBAGE partagé : cadre de pierre gravée + onglet « RELIC ICONS », posé EN DERNIER (espace design via
  -- Draw.begin) par-dessus le monde + le HUD. Intérieur transparent : la grille/HUD vivent dans l'inset.
  Draw.begin(view)
  ScreenFrame.draw("RELIC ICONS", { ft = ScreenFrame.FT })
  Draw.finish()
end

function Relicons:cellAt(vx, vy)
  local gx, gy = vx - GX0, vy - GY0
  if gx < 0 or gy < 0 then return nil end
  local c, r = math.floor(gx / CELL_W), math.floor(gy / CELL_H)
  if c < 0 or c >= COLS or r < 0 or r >= ROWS then return nil end
  local gi = r * COLS + c + 1
  if gi > #self.icons then return nil end
  return gi
end

function Relicons:mousemoved(vx, vy)
  self.hover = self:cellAt(vx, vy)
end

return Relicons
