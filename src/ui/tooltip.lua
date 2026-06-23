-- src/ui/tooltip.lua
-- MOLÉCULE « infobulle / tooltip » (design-system §2.14) — un mini-panneau qui décrit une unité au survol :
-- NOM (Cinzel) + chip de famille à droite + BARRE DE STATS encastrée (Space Mono, labels ink3 / valeurs
-- ink) + nom de PASSIF (Space Mono or) + chip d'affliction + PROSE (Spectral). Une petite FLÈCHE pointe vers
-- l'élément survolé (gauche par défaut, comme la maquette : « left:-6px top:24px »).
--
-- ── ARCHI — ENTIÈREMENT PROPRE (zéro Forge / zéro œil baké / zéro métal gritty) ─────────────────────
-- Le fond est un Panel propre (dégradé sombre + liseré iron + éclat haut) ; la flèche est un triangle plein
-- net (love.graphics, bordé iron) qui déborde du bord choisi ; la barre de stats est un rect encastré
-- (stone900 + iron). Le contenu LISIBLE (nom, stats, passif, prose) est dessiné par les helpers Draw + Chip
-- (vraies voix typo). RENDER pur, espace DESIGN, HEADLESS-SAFE.
--
-- Tooltip.draw(x, y, opts) :   (signature publique INCHANGÉE)
--   x,y     coin haut-gauche du panneau en ESPACE DESIGN. La flèche déborde à GAUCHE (opts.arrow="left").
--   opts = {
--     name    = nom de l'unité (Cinzel)                  -- requis pour l'en-tête
--     fam     = "flesh"|... (chip de famille à droite ; via Theme.types)  -- optionnel
--     stats   = { {label="HP", value=70}, {label="DMG", value=6}, {label="CD", value="6s"} }  -- barre Space Mono
--     passive = nom du passif (Space Mono or)             -- optionnel
--     affKey  = clé d'affliction du passif (chip)         -- optionnel
--     prose   = description (Spectral ink2, wrap)         -- optionnel
--     w       = largeur (défaut 248, §2.14) ; h auto-mesurée si absente.
--     arrow   = "left"|"right"|"none" (défaut "left")
--     t, id   = acceptés pour compat ; ignorés (le tooltip propre est statique).
--   }
--   Retourne (x, y, w, h) = le rect réel occupé (h mesurée) pour le placement / clamp à l'écran.

local Theme = require("src.ui.theme")
local Draw = require("src.ui.draw")
local Panel = require("src.ui.panel")
local Chip = require("src.ui.chip")
local C = Theme.c

local Tooltip = {}

local floor, max, min = math.floor, math.max, math.min

local DEFAULT_W = 248 -- §2.14 : « Width: 248px »
local PAD = 14        -- §2.14 : « padding 13–14px 15px »
local ARROW = 10      -- §2.14 : « Arrow: 10×10px »

local function g() return love and love.graphics or nil end

-- Mesure la HAUTEUR nécessaire (pour dimensionner avant de dessiner). Reproduit la pile de l'overlay.
local function measureH(opts, innerW)
  local h = PAD
  -- en-tête (nom Cinzel)
  local nf = Theme.heading(15) or Theme.subhead(15)
  h = h + (nf and nf:getHeight() or 16) + 8
  -- barre de stats (encadré) : 1 ligne de valeurs + padding interne
  if opts.stats and #opts.stats > 0 then
    local sf = Theme.value(11) or Theme.label(11)
    h = h + (sf and sf:getHeight() or 12) + 14 + 8
  end
  -- nom de passif
  if opts.passive and opts.passive ~= "" then
    local pf = Theme.value(11) or Theme.label(11)
    h = h + (pf and pf:getHeight() or 12) + 6
  end
  -- chip d'affliction
  if opts.affKey then
    h = h + 18 + 4
  end
  -- prose (wrap)
  if opts.prose and opts.prose ~= "" then
    local prf = Theme.body(13) or Theme.bodyLight(13)
    if prf then
      local _, lines = prf:getWrap(opts.prose, innerW)
      h = h + #lines * prf:getHeight() + 4
    else
      h = h + 16
    end
  end
  return h + PAD
end

-- FLÈCHE propre : un triangle plein (fond du panneau) bordé iron, qui déborde du bord choisi à ~24px du haut
-- (« top:24px »). side ∈ "left"|"right". Dessiné en love.graphics direct (net, pas de bake).
local function arrowTri(x, y, w, h, side, ay)
  local gr = g(); if not (gr and gr.polygon) then return end
  ay = floor(min(h - ARROW, ay or 24))
  local fill = C.stone850
  local mid = ay + ARROW / 2
  if side == "left" then
    gr.setColor(fill[1], fill[2], fill[3], 1)
    gr.polygon("fill", x, ay, x, ay + ARROW, x - ARROW, mid)
    gr.setColor(C.iron[1], C.iron[2], C.iron[3], 1)
    gr.line(x, ay, x - ARROW, mid, x, ay + ARROW)
  elseif side == "right" then
    gr.setColor(fill[1], fill[2], fill[3], 1)
    gr.polygon("fill", x + w, ay, x + w, ay + ARROW, x + w + ARROW, mid)
    gr.setColor(C.iron[1], C.iron[2], C.iron[3], 1)
    gr.line(x + w, ay, x + w + ARROW, mid, x + w, ay + ARROW)
  end
  gr.setColor(1, 1, 1, 1)
end

function Tooltip.draw(x, y, opts)
  opts = opts or {}
  x, y = floor(x), floor(y)
  local w = floor(opts.w or DEFAULT_W)
  local arrow = opts.arrow or "left"
  local innerW = w - 2 * PAD
  local h = floor(opts.h or measureH(opts, innerW))

  -- 1) FOND : Panel propre (dégradé stone800→stone900 + liseré iron + éclat haut).
  Panel.draw(x, y, w, h, { fill1 = C.stone800, fill2 = C.stone900 })
  -- 2) FLÈCHE (triangle net débordant), si demandée.
  if arrow == "left" or arrow == "right" then arrowTri(x, y, w, h, arrow, 24) end

  -- 3) OVERLAYS LISIBLES (no-op headless via Draw / Chip).
  if love and love.graphics and love.graphics.print then
    local cursorY = y + PAD
    local bodyX = x + PAD
    local rightX = x + w - PAD

    -- ── en-tête : NOM (Cinzel) à gauche + chip de famille à droite ──
    local nf = Theme.heading(15) or Theme.subhead(15)
    Draw.text(opts.name or "", bodyX, cursorY, C.ink, nf)
    if opts.fam then
      local ty = Theme.type(opts.fam)
      local cf = Theme.label(10) or Theme.value(10)
      local famName = (opts.fam:gsub("^%l", string.upper))
      love.graphics.setFont(cf)
      local cw = Chip.width({ label = famName, color = ty.color, font = cf, icon = false })
      Chip.draw(floor(rightX - cw), cursorY, { label = famName, color = ty.color, font = cf, icon = false })
    end
    cursorY = cursorY + (nf and nf:getHeight() or 16) + 8

    -- ── barre de STATS (encadré sombre + valeurs Space Mono, labels ink3 / valeurs ink) ──
    if opts.stats and #opts.stats > 0 then
      local sf = Theme.value(11) or Theme.label(11)
      local barH = (sf and sf:getHeight() or 12) + 14
      Draw.rect(bodyX, cursorY, innerW, barH, C.stone900, C.iron, 1)
      if sf then
        love.graphics.setFont(sf)
        local n = #opts.stats
        local cellW = innerW / n
        local midY = cursorY + barH / 2
        for i = 1, n do
          local s = opts.stats[i]
          local ccx = bodyX + (i - 0.5) * cellW
          local lab = tostring(s.label or "")
          local val = tostring(s.value)
          local lw = sf:getWidth(lab .. " ")
          local vw = sf:getWidth(val)
          local total = lw + vw
          local sx = floor(ccx - total / 2)
          Draw.text(lab, sx, midY - sf:getHeight() / 2, C.ink3, sf)
          Draw.text(val, sx + lw, midY - sf:getHeight() / 2, C.ink, sf)
        end
      end
      cursorY = cursorY + barH + 8
    end

    -- ── nom de PASSIF (Space Mono OR) ──
    if opts.passive and opts.passive ~= "" then
      local pf = Theme.value(11) or Theme.label(11)
      Draw.text(opts.passive, bodyX, cursorY, C.gold, pf)
      cursorY = cursorY + (pf and pf:getHeight() or 12) + 6
    end

    -- ── chip d'AFFLICTION (le passif « se voit » : icône + nom + teinte) ──
    if opts.affKey then
      local cf = Theme.label(10) or Theme.value(10)
      Chip.draw(bodyX, cursorY, { key = opts.affKey, font = cf, h = 18 })
      cursorY = cursorY + 18 + 4
    end

    -- ── PROSE (Spectral ink2, wrap dans l'intérieur) ──
    if opts.prose and opts.prose ~= "" then
      local prf = Theme.body(13) or Theme.bodyLight(13)
      Draw.textWrap(opts.prose, bodyX, cursorY, innerW, C.ink2, prf, "left")
    end
    Draw.reset()
  end

  return x, y, w, h
end

return Tooltip
