-- src/ui/relic_card.lua
-- MOLÉCULE « carte de relique » (design-system §2.13) — la fiche d'une relique, en deux états de mystère.
-- ENTIÈREMENT PROPRE (zéro Forge / zéro œil baké / zéro métal gritty) : composée d'ATOMES propres —
-- Panel (fond carte en dégradé + liseré iron), Badge.diamond (la gemme-losange, teintée famille, SANS œil),
-- Dividers (filets), Chip (l'affliction), et les voix typographiques via Draw (Cinzel/Spectral/Space Mono).
--   • identified : bande d'en-tête (voile radial sang) + gemme losange (teinte de famille) + NOM gravé
--     (Cinzel) + badge « INKED » (Space Mono or) ; corps = « KNOWN EFFECT » + effet (prose Spectral, les
--     VALEURS du texte en Space Mono `bloodL`) + flavor (Spectral italique).
--   • cryptic    : TEINTE VIOLETTE (rot), gemme HACHURÉE + « ? » central, nom « ? ? ? », badge « CRYPTIC »,
--     corps = « EFFECT UNKNOWN · REVEALS IN USE » + prose énigmatique (Spectral italique).
--   • selected   : identifiée + LISERÉ doré d'accent (la carte « rayonne » — offre 1-parmi-3).
--
-- ── CONTRAT (signature publique INCHANGÉE) ──────────────────────────────────────────────────────────
-- RENDER pur (love.graphics), espace DESIGN 1280×720 (sous Draw.begin). HEADLESS-SAFE : tous les atomes
-- no-op proprement sous le mock (love.graphics stubé). Ne touche AUCUNE couche SIM.
--
-- RelicCard.draw(x, y, w, h, opts) :
--   opts = {
--     state   = "identified" | "cryptic" | "selected"   (défaut "identified" ; "selected" => identifiée + lueur)
--     name    = nom de la relique (déjà résolu i18n)     -- ignoré en cryptic (affiche "? ? ?")
--     effect  = texte d'effet (déjà résolu i18n)          -- en cryptic, sert de prose énigmatique (Spectral it.)
--     flavor  = lore (déjà résolu i18n)
--     fam     = "flesh"|"order"|"bone"|"arcane"|"abyss"   (teinte de la gemme ; défaut "bone")
--     affKey  = clé d'affliction (poison/bleed/burn/rot/shock) -> chip sous le nom (optionnel, identifiée)
--     status  = "NEW"|"INKED"|"SEALED"|"CRYPTIC"           (badge d'état ; auto-déduit si absent)
--     id, t, mouse = (acceptés pour compat ; ignorés — la carte propre est statique, pas de bake animé)
--   }
-- Retourne (ix, iy, iw, ih) = la zone intérieure utile (sous le liseré), pour composer au-dessus si besoin.

local Theme = require("src.ui.theme")
local Draw = require("src.ui.draw")
local Panel = require("src.ui.panel")
local Badge = require("src.ui.badge")
local Dividers = require("src.ui.dividers")
local Chip = require("src.ui.chip")
local C = Theme.c

local RelicCard = {}

local floor, max, abs = math.floor, math.max, math.abs

-- ── ÉCHELLE D'ESPACEMENT (8pt) — un seul barème pour faire RESPIRER la carte (jamais un littéral au pif) ──
local PAD_X = 14       -- marge latérale du corps
local PAD_TOP = 12     -- air sous le cadre, avant la gemme
local PAD_BOTTOM = 12  -- air sous le flavor, avant le bord bas (le flavor ne touche JAMAIS le liseré)
local GAP_SM = 8       -- petit interbloc
local GAP_MD = 12      -- interbloc moyen (gemme->nom, divider->corps)
local SEP_AIR = 8      -- air AU-DESSUS et EN DESSOUS d'un séparateur (respiration des filets)

-- Hauteur d'une police (fallback 12 headless / si nil).
local function fh(font, d) return (font and font.getHeight and font:getHeight()) or d or 12 end

-- Nombre de lignes d'un texte wrappé à `limit` (Font:getWrap -> width, lines[]). Mock = 1 ligne ; vrai
-- LÖVE = compte réel -> la MESURE suit le contenu (le flavor sur 2 lignes agrandit bien la carte).
local function wrapLines(font, str, limit)
  if not (font and font.getWrap and str and str ~= "") then return 0 end
  local _, lines = font:getWrap(str, limit)
  return max(1, #lines)
end

local function hasDigit(word)
  for i = 1, #word do
    local b = word:byte(i)
    if b >= 48 and b <= 57 then return true end -- '0'..'9'
  end
  return false
end

-- HAUTEUR de l'effet rendu par _drawEffect : MÊME wrap manuel par MOT (prose vs valeurs chiffrées en Space
-- Mono, plus large) -> la MESURE et le DESSIN comptent IDENTIQUEMENT les lignes (le flavor ne peut pas
-- chevaucher un effet qui aurait wrappé une ligne de plus). 0 si vide / pas de police.
local function effectHeight(effect, limit)
  if not effect or effect == "" then return 0 end
  local proseF = Theme.body(14) or Theme.bodyLight(14)
  local valF = Theme.value(14) or Theme.label(14)
  if not proseF then return 0 end
  local lineH = proseF:getHeight()
  local spaceW = proseF:getWidth(" ")
  local cx, lines = 0, 1
  for word in (effect .. " "):gmatch("(.-) ") do
    if word ~= "" then
      local f = hasDigit(word) and valF or proseF
      local ww = f:getWidth(word)
      if cx > 0 and cx + ww > limit then cx = 0; lines = lines + 1 end
      cx = cx + ww + spaceW
    end
  end
  return lines * lineH
end

-- ── LAYOUT MESURÉ (source unique pour measure ET draw) ───────────────────────────────────────────────
-- Calcule, pour une largeur `w` et des options, toutes les ancres verticales RELATIVES au coin haut de la
-- carte + la hauteur TOTALE requise. Le header est dérivé de la GEMME + du NOM (pas d'un ratio de `h` :
-- on casse la dépendance circulaire) ; le corps mesure le wrap de l'effet/prose ET du flavor. Résultat :
-- la carte CONTIENT tout son contenu + marge basse — aucun texte ne passe sous la bordure.
local function layoutCard(w, opts)
  opts = opts or {}
  local cryptic = (opts.state == "cryptic")
  local bodyW = floor(w - 2) - 2 * PAD_X
  if bodyW < 8 then bodyW = 8 end

  -- gemme : rayon dérivé de la LARGEUR seule (indépendant de h).
  local gr = max(8, floor(w * 0.14 + 0.5))
  local nameF = Theme.heading(17) or Theme.subhead(17)

  -- HEADER : pad top + gemme (diam) + air + nom + air bas (avant le filet de séparation).
  local gemCy = PAD_TOP + gr
  local nameY = gemCy + gr + GAP_SM
  local headH = nameY + fh(nameF, 16) + GAP_MD
  -- (le filet brass de fin de bande se pose à divY = headH - 1)

  -- CORPS : démarre sous le header, avec un peu d'air.
  local cy = headH + GAP_MD

  if cryptic then
    local kf = Theme.labelSmall(9) or Theme.label(9)
    cy = cy + fh(kf, 11) + GAP_SM
    local pf = Theme.flavor(13) or Theme.bodyItalic(13)
    local prose = opts.effect or "Its purpose hides beneath the surface."
    cy = cy + wrapLines(pf, prose, bodyW) * fh(pf, 14)
  else
    if opts.affKey then
      cy = cy + 16 + GAP_SM -- chip d'affliction (h=16) + air
    end
    local kf = Theme.labelSmall(9) or Theme.label(9)
    cy = cy + fh(kf, 11) + GAP_SM -- sublabel « KNOWN EFFECT »
    cy = cy + effectHeight(opts.effect or "", bodyW) -- même wrap par-mot que _drawEffect
  end

  -- FLAVOR : filet de séparation (avec air dessus/dessous) + lignes wrappées + marge basse.
  local flavorTop, flavY, flavLines = nil, nil, 0
  if opts.flavor and opts.flavor ~= "" then
    local ff = Theme.flavor(12) or Theme.bodyItalic(12)
    flavLines = wrapLines(ff, opts.flavor, bodyW)
    cy = cy + SEP_AIR        -- air AU-DESSUS du séparateur
    flavorTop = cy           -- y du filet iron
    cy = cy + SEP_AIR        -- air EN DESSOUS du séparateur, avant le texte
    flavY = cy
    cy = cy + flavLines * fh(ff, 14)
  end

  local totalH = cy + PAD_BOTTOM
  return {
    bodyW = bodyW, gr = gr, gemCy = gemCy, nameY = nameY, headH = headH,
    bodyTop = headH + GAP_MD, flavorTop = flavorTop, flavY = flavY, flavLines = flavLines,
    totalH = totalH,
  }
end

-- HAUTEUR requise pour contenir tout le contenu (le caller dimensionne la carte avec ça : aucun spill).
function RelicCard.measure(w, opts)
  return layoutCard(floor(w), opts).totalH
end

-- Garde-fou love.graphics (no-op headless) pour les tracés directs (voile radial, hachures).
local function g() return love and love.graphics or nil end

-- Voile radial coloré derrière l'en-tête (le « background:radial-gradient(...) » du §2.13). On approxime
-- par des bandes additives décroissantes depuis un centre haut. col = {r,g,b} floats. alpha = intensité crête.
local function radialVeil(x, y, w, h, col, alpha)
  local gr = g(); if not (gr and gr.setBlendMode) then return end
  local cx, cyp = x + w / 2, y + h * 0.34
  local maxd = math.sqrt((w * 0.5) ^ 2 + (h * 0.6) ^ 2)
  gr.setBlendMode("add")
  -- échantillonnage grossier en tuiles 2×2 (peu coûteux, assez doux à cette échelle).
  for yy = 0, h - 1, 2 do
    for xx = 0, w - 1, 2 do
      local dx, dy = (x + xx) - cx, (y + yy) - cyp
      local d = math.sqrt(dx * dx + dy * dy) / maxd
      local a = max(0, 1 - d * 1.3)
      if a > 0.02 then
        gr.setColor(col[1], col[2], col[3], a * alpha)
        gr.rectangle("fill", x + xx, y + yy, 2, 2)
      end
    end
  end
  gr.setBlendMode("alpha")
  gr.setColor(1, 1, 1, 1)
end

-- Gemme CRYPTIQUE : un losange (Manhattan) hachuré violet sombre + arête `rot` (la trame de mystère du
-- §2.13 « repeating-linear-gradient » dans un carré tourné 45°). cx,cy = centre ; r = demi-diagonale.
local function crypticGem(cx, cy, r)
  local gr = g(); if not gr then return end
  cx, cy = floor(cx + 0.5), floor(cy + 0.5)
  for dy = -r, r do
    for dx = -r, r do
      local m = abs(dx) + abs(dy)
      if m <= r then
        local onEdge = (m >= r - 0.9)
        if onEdge then
          gr.setColor(C.rot[1], C.rot[2], C.rot[3], 1)
        elseif ((dx + dy) % 4 == 0) then
          gr.setColor(C.rot[1] * 0.5, C.rot[2] * 0.5, C.rot[3] * 0.5, 1) -- brin de hachure
        else
          gr.setColor(C.stone850[1], C.stone850[2], C.stone850[3], 1)    -- creux sombre
        end
        gr.rectangle("fill", cx + dx, cy + dy, 1, 1)
      end
    end
  end
  gr.setColor(1, 1, 1, 1)
end

-- ── DRAW (composition d'atomes propres) ─────────────────────────────────────────────────────────────
-- DÉBORDEMENT MAÎTRISÉ : la mise en page verticale vient du LAYOUT MESURÉ (layoutCard) — header dérivé de la
-- gemme+nom, corps mesuré (wrap de l'effet ET du flavor). Le flavor est ancré sur la pile MESURÉE (pas sur
-- le bord bas) avec un séparateur qui RESPIRE -> aucun texte ne passe sous la bordure. Si `h` < hauteur
-- requise, on dessine quand même (le caller doit passer h>=measure ; le design-system le fait).
function RelicCard.draw(x, y, w, h, opts)
  opts = opts or {}
  x, y, w, h = floor(x), floor(y), floor(w), floor(h)
  local state = opts.state or "identified"
  local cryptic = (state == "cryptic")
  local selected = (state == "selected")

  local L = layoutCard(w, opts)

  -- 1) FOND de carte : Panel propre (dégradé sombre + liseré iron + éclat haut). Cryptique = base un poil
  --    plus froide (stone850→stone900) ; identifiée/sélectionnée = stone800→stone900. Accent doré si selected.
  local fill1 = cryptic and C.stone850 or C.stone800
  Panel.draw(x, y, w, h, {
    fill1 = fill1, fill2 = C.stone900,
    accent = selected and C.gold or nil,
  })
  local ix, iy = x + 1, y + 1
  local iw, ih = w - 2, h - 2

  -- 2) BANDE D'EN-TÊTE (hauteur MESURÉE) : voile radial (sang / rot) + gemme + nom + badge d'état + filet bas.
  local headH = L.headH
  local veilCol = cryptic and C.rot or C.blood
  radialVeil(ix, iy, iw, headH, veilCol, cryptic and 0.14 or 0.16)

  local cx = x + w / 2
  local gy = y + L.gemCy
  local gr = L.gr

  if cryptic then
    crypticGem(cx, gy, gr)
  else
    -- gemme de FAMILLE : losange teinté (Badge.diamond — atome propre, fill/edge/spec en couleurs Theme).
    local ty = Theme.type(opts.fam or "bone")
    -- éclat plus vif si sélectionnée (la gemme « rayonne »).
    local spec = selected and C.brassS or { 1, 1, 1, 1 }
    Badge.diamond(cx, gy, gr, ty.color, ty.dark, spec)
    -- petit losange intérieur clair (le « cœur » de la gemme, §2.13 inner gem).
    Badge.diamond(cx, gy, max(2, floor(gr * 0.32 + 0.5)),
      selected and C.bloodL or { ty.color[1], ty.color[2], ty.color[3], 1 }, ty.color, nil)
  end

  -- filet bas de la bande (Dividers.brass : repère où commence le corps).
  local divY = y + headH - 1
  Dividers.brass(cx, divY, iw - 8)

  -- 3) OVERLAYS TYPOGRAPHIQUES (no-op headless via Draw -> love.graphics absent sous le mock).
  if love and love.graphics and love.graphics.print then
    -- ── badge d'état (Space Mono caps, coin haut-droit) ──
    local status = opts.status or (cryptic and "CRYPTIC" or (selected and "NEW" or "INKED"))
    do
      local sf = Theme.label(9) or Theme.value(9)
      local stCol = cryptic and C.rot or (status == "NEW" and C.ctaText or C.gold)
      local sw = (sf and Draw.textWidth and Draw.textWidth(status, sf)) or 0
      Draw.textTrackedL(status, x + w - 10 - sw, y + 9, stCol, sf, 1.4)
    end

    -- ── NOM (Cinzel 700 ; cryptique = « ? ? ? » sourdine, large interlettrage) ── (ancre mesurée)
    local nameY = y + L.nameY
    local nf = Theme.heading(17) or Theme.subhead(17)
    local nameStr = cryptic and "? ? ?" or (opts.name or "RELIC")
    local nameCol = cryptic and C.ink3 or C.ink
    Draw.textTrackedC(nameStr, cx, nameY, nameCol, nf, cryptic and 3 or 1)

    -- ── corps (sous la bande d'en-tête) : sublabel + effet/prose ── (ancres mesurées, espacement 8pt)
    local bodyX = floor(ix + PAD_X)
    local bodyW = L.bodyW
    local cursorY = y + L.bodyTop

    local bodyBottom = cursorY -- bas RÉEL du corps (effet/prose) — sert de plancher au flavor.
    if cryptic then
      -- sublabel énigmatique (text-divider) + prose (Spectral italique).
      local kf = Theme.labelSmall(9) or Theme.label(9)
      Draw.textTrackedL("EFFECT UNKNOWN · REVEALS IN USE", bodyX, cursorY, C.ink4, kf, 1.4)
      cursorY = cursorY + fh(kf, 11) + GAP_SM
      local pf = Theme.flavor(13) or Theme.bodyItalic(13)
      local prose = opts.effect or "Its purpose hides beneath the surface."
      bodyBottom = cursorY + Draw.textWrap(prose, bodyX, cursorY, bodyW, C.ink3, pf, "left")
    else
      -- chip d'AFFLICTION (foyer de la relique) : front-load du mot-clé via le registre unique (Chip).
      if opts.affKey then
        local cf = Theme.label(9) or Theme.value(9)
        local cw = Chip.width({ key = opts.affKey, font = cf, h = 16 })
        Chip.draw(floor(cx - cw / 2), cursorY, { key = opts.affKey, font = cf, h = 16 })
        cursorY = cursorY + 16 + GAP_SM
      end
      -- sublabel « KNOWN EFFECT » (Space Mono, ink4, tracké).
      local kf = Theme.labelSmall(9) or Theme.label(9)
      Draw.textTrackedL("KNOWN EFFECT", bodyX, cursorY, C.ink4, kf, 1.4)
      cursorY = cursorY + fh(kf, 11) + GAP_SM
      -- texte d'effet : Spectral ink, valeurs (tokens chiffrés) en Space Mono `bloodL`. (hauteur RÉELLE)
      bodyBottom = cursorY + RelicCard._drawEffect(opts.effect or "", bodyX, cursorY, bodyW)
    end

    -- ── flavor (Spectral italique, ink3) ── ancré sur la PILE MESURÉE (jamais sous la bordure) : filet de
    --    séparation iron qui RESPIRE (air dessus/dessous), puis le bloc wrappé, puis la marge basse (PAD_BOTTOM).
    --    On prend le MAX(mesuré, bas réel du corps + air) -> robuste si le wrap manuel diffère de getWrap.
    if opts.flavor and opts.flavor ~= "" and L.flavY then
      local ff = Theme.flavor(12) or Theme.bodyItalic(12)
      local sepY = max(y + L.flavorTop, bodyBottom + SEP_AIR)
      Draw.rect(bodyX, sepY, bodyW, 1, C.iron) -- « height:1px background:iron » du §2.13
      Draw.textWrap(opts.flavor, bodyX, sepY + SEP_AIR, bodyW, C.ink3, ff, "left")
    end
    Draw.reset()
  end

  return ix, iy, iw, ih
end

-- _drawEffect : pose le texte d'effet en Spectral `ink2`, mais chaque MOT qui contient un CHIFFRE (« +15% »,
-- « 2 », « 40 » ...) est rendu en Space Mono 700 `bloodL` (les valeurs « ressortent »). Découpe par ESPACES
-- (jamais par octet -> les multi-octets restent intacts) ; wrap manuel borné à `limit` (IDENTIQUE à
-- effectHeight ci-dessus -> mesure = dessin). Retourne la hauteur dessinée.
function RelicCard._drawEffect(effect, x, y, limit)
  if not (love and love.graphics and love.graphics.print) or effect == "" then return 0 end
  local proseF = Theme.body(14) or Theme.bodyLight(14)
  local valF = Theme.value(14) or Theme.label(14)
  if not proseF then return 0 end
  local lineH = proseF:getHeight()
  local spaceW = proseF:getWidth(" ")
  local cx, cy = x, y
  -- itère les mots séparés par espace (préserve UTF-8 : on ne coupe qu'aux espaces ASCII).
  for word in (effect .. " "):gmatch("(.-) ") do
    if word ~= "" then
      local isVal = hasDigit(word)
      local f = isVal and valF or proseF
      local col = isVal and C.bloodL or C.ink2
      love.graphics.setFont(f)
      local ww = f:getWidth(word)
      if cx > x and (cx + ww) > (x + limit) then -- wrap : passe à la ligne suivante
        cx = x; cy = cy + lineH
      end
      Draw.setColor(col)
      love.graphics.print(word, floor(cx + 0.5), floor(cy + 0.5))
      cx = cx + ww + spaceW
    end
  end
  Draw.reset()
  return (cy - y) + lineH
end

return RelicCard
