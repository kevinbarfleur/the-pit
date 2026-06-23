-- src/ui/dividers.lua
-- ATOMES DE JEU — DIVIDERS (design-system-spec.md §2.9) : trois séparateurs, du décoratif au structurel.
--   • brass(cx,y,w)        — filet en dégradé (transparent→laiton→transparent) + losange laiton central +
--                            lueur. Le séparateur ORNÉ (titres de section, pied de carte).
--   • blood(x,y,w)          — filet de sang 2px (blood-d) + lueur + ourlets iron haut/bas. La CASSURE de
--                            section (sobre, organique).
--   • text(cx,y,w,label)    — un label inscrit (Space Mono interlettré) ENTRE deux filets iron : le titre
--                            de bloc (« KNOWN EFFECT », « THE OFFERING »).
--
-- COUCHE RENDER PURE (love.graphics, espace design 1280×720, sous Draw.begin). On RÉUTILISE Draw.divider
-- (filet à profil triangulaire) pour le dégradé latéral, et Draw.textTrackedC pour le label (UTF-8-safe,
-- jamais de découpe par octet). Couleurs via Theme. HEADLESS-SAFE : love.graphics stubé -> no-op (golden neutre).
--
-- Réf : pit-forge.js drawDivider (diamant central + étincelle) ; nombres = §2.9.

local Theme = require("src.ui.theme")
local Draw = require("src.ui.draw")

local Dividers = {}

local C = Theme.c
local floor = math.floor

local function g() return love and love.graphics or nil end

-- Petit losange laiton plein (centre du brass divider). cx,cy = centre ; r = demi-diagonale ; lueur additive.
local function brassDiamond(cx, cy, r)
  local gr = g(); if not gr then return end
  cx, cy = floor(cx + 0.5), floor(cy + 0.5)
  for dy = -r, r do
    for dx = -r, r do
      local m = math.abs(dx) + math.abs(dy)
      if m <= r then
        local c = (m >= r - 0.9) and C.brass or C.brassL
        gr.setColor(c[1], c[2], c[3], 1)
        gr.rectangle("fill", cx + dx, cy + dy, 1, 1)
      end
    end
  end
  -- lueur douce de laiton (additive si dispo) — « box-shadow 0 0 6px » du spec.
  if gr.setBlendMode then
    gr.setBlendMode("add")
    gr.setColor(C.brassL[1], C.brassL[2], C.brassL[3], 0.35)
    gr.rectangle("fill", cx - r, cy - 1, r * 2, 2)
    gr.setBlendMode("alpha")
  end
  gr.setColor(1, 1, 1, 1)
end

-- ── BRASS DIAMOND DIVIDER (décoratif) — §2.9. Deux demi-filets en dégradé qui s'effacent vers le centre,
-- où trône un losange laiton lumineux. cx = centre horizontal, y = ligne, w = largeur totale. gap = espace
-- réservé au losange (def 16px). Renvoie y (commodité de chaînage vertical).
function Dividers.brass(cx, y, w, gap)
  gap = gap or 16
  local half = (w - gap) / 2
  -- demi-filet gauche : centre du segment = cx - gap/2 - half/2, profil triangulaire (Draw.divider).
  Draw.divider(cx - gap / 2 - half / 2, y, half, C.brass, 1)
  Draw.divider(cx + gap / 2 + half / 2, y, half, C.brass, 1)
  brassDiamond(cx, y + 0.5, 4) -- losange 8px centré sur la ligne
  return y
end

-- ── BLOOD DIVIDER (cassure de section) — §2.9. Filet de sang 2px (blood-d) + lueur + ourlets iron au-dessus
-- et en dessous. x,y = coin haut-gauche, w = largeur. Renvoie la hauteur dessinée (4px : ourlet+sang+ourlet).
function Dividers.blood(x, y, w)
  local gr = g()
  -- ourlet iron au-dessus
  Draw.rect(x, y, w, 1, C.iron)
  -- corps de sang 2px
  Draw.rect(x, y + 1, w, 2, C.bloodD)
  -- ourlet iron en dessous
  Draw.rect(x, y + 3, w, 1, C.iron)
  -- lueur de sang (additive) le long du filet — « 0 0 4px rgba(blood) ».
  if gr and gr.setBlendMode then
    gr.setBlendMode("add")
    gr.setColor(C.blood[1], C.blood[2], C.blood[3], 0.22)
    gr.rectangle("fill", x, y + 1, w, 2)
    gr.setBlendMode("alpha")
    gr.setColor(1, 1, 1, 1)
  end
  return 4
end

-- ── TEXT DIVIDER (titre de bloc) — §2.9. Un `label` inscrit (Space Mono interlettré, ink-4) centré, avec un
-- filet iron de chaque côté jusqu'aux bords. cx = centre, y = ligne de base du texte, w = largeur totale.
-- Renvoie la hauteur du label (pour chaîner). spacing = interlettrage (def 3px, « 0.3em » du spec).
function Dividers.text(cx, y, w, label, spacing)
  spacing = spacing or 3
  local fontPx = 10
  local font = Theme.label(fontPx)
  local fh = font and font:getHeight() or fontPx
  local midY = y + fh / 2
  -- largeur du label (interlettrage compris) pour réserver l'espace central. Mesure via la police (UTF-8-safe).
  local lw = 0
  if font then
    -- somme des largeurs de glyphes + interlettrage (cohérent avec Draw.textTrackedC).
    local n = 0
    for i = 1, #label do
      local b = string.byte(label, i)
      -- on ne compte que les octets de TÊTE (un caractère) pour rester UTF-8-safe sur la longueur.
      if b < 0x80 or b >= 0xC0 then n = n + 1 end
    end
    lw = font:getWidth(label) + spacing * math.max(0, n - 1)
  else
    lw = #label * 6
  end
  local pad = 10                 -- marge entre le label et chaque filet
  local sideW = (w - lw) / 2 - pad
  if sideW > 4 then
    Draw.rect(cx - lw / 2 - pad - sideW, midY, sideW, 1, C.iron)
    Draw.rect(cx + lw / 2 + pad, midY, sideW, 1, C.iron)
  end
  Draw.textTrackedC(label, cx, y, C.ink4, font, spacing)
  return fh
end

return Dividers
