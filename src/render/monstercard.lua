-- src/render/monstercard.lua
-- FICHE « carte de monstre » (TCG) flottante : un Panel PROPRE (dégradé vertical + liseré iron + éclat
-- laiton) qui porte portrait + identité + stats encastrées + capacités (chips d'affliction + passif +
-- description lisible) + flavor. EXTRAITE de src/scenes/build.lua, réutilisée hors du build (d'abord La
-- Chronique : survol d'un nom -> carte près du curseur).
--
-- ── ARCHI — KIT PROPRE (design-system) : on calque la molécule Tooltip (src/ui/tooltip.lua) ────────────
-- Le fond est un Panel.draw (dégradé stone800→stone900 + liseré iron + éclat haut) ; la niche du portrait
-- est un Panel.niche (hachures + liseré) ; les sections sont titrées par Dividers.text (label inscrit entre
-- filets iron) ; les stats vivent dans une BARRE encastrée (Space Mono, labels ink3 / valeurs ink) comme le
-- tooltip ; le coût est un Badge.cost (losange laiton + Space Mono) ; la rareté est une rangée de
-- Badge.diamond. Plus AUCUN widget Forge (plaque gritty / œil baké / rivets / diamants forge). RENDER pur.
--
-- TOUT est PARAMÉTRÉ (view, palette, id, ancre curseur, horloge t) au lieu de self.* : aucun couplage à la
-- scène. Le placement (suit le curseur, rebond sur les bords) est interne. Couche RENDER (love.graphics).
--
-- PORTRAIT : silhouette mesurée via MiniRig (cache + bounds déterministes). Le CHAR dessiné est paramétrable
-- (opts.rig) : le build passe son rig d'aperçu ANIMÉ (le portrait respire, comme avant) ; sans opts.rig on
-- prend le mini-rig FIGÉ (chronique). Les BOUNDS restent ceux de MiniRig dans les deux cas (l'oscillation
-- idle ne change pas l'enveloppe de fit).
--
-- HAUTEUR DÉRIVÉE DU CONTENU (mesure AVANT dessin, jamais une constante devinée) : chaque bloc est mesuré
-- (Font:getWrap / getHeight) et la pile additionnée -> la carte CONTIENT tout son texte, jamais tronqué.

local Draw = require("src.ui.draw")
local Theme = require("src.ui.theme")
local Panel = require("src.ui.panel")
local Badge = require("src.ui.badge")
local Dividers = require("src.ui.dividers")
local Keywords = require("src.ui.keywords")
local Chip = require("src.ui.chip")
local Rarity = require("src.gen.rarity")
local Units = require("src.data.units")
local I18n = require("src.core.i18n")
local MiniRig = require("src.render.minirig")
local Critter = require("src.render.critter") -- rendu VIVANT : MÊME créature animée que le board (ailes/yeux/feu)
local Rig = require("src.core.rig")
local C = Theme.c
local T = I18n.t

local MonsterCard = {}

-- ── Constantes de mise en page (espace DESIGN, échelle 8pt) ─────────────────────────────────────────
local W = 248         -- largeur de carte (alignée sur le tooltip propre, §2.14)
local PAD = 14        -- marge intérieure
local GAP = 8         -- interbloc (8pt) : chaque bloc respire de la même quantité
local SECTION_GAP = 12 -- air supplémentaire AUTOUR d'un titre de section (groupe > intérieur)
local PORTRAIT_H = 76  -- hauteur de la niche du portrait
local STAT_PADV = 14   -- padding vertical interne de la barre de stats (cf. tooltip)
local CHIP_H = 18      -- hauteur d'un chip d'affliction

-- ── Helpers PURS (transposés depuis build.lua, signatures + comportement INCHANGÉS) ─────────────────

-- Valeur lisible d'un effet d'affliction (« 6 dps · 3s ») depuis ses params dps/dur (dur en FRAMES @60fps).
local function afflValue(params)
  if not params then return nil end
  local bits = {}
  local dps = params.dps or params.base
  if dps then bits[#bits + 1] = tostring(dps) .. " dps" end
  if params.dur then bits[#bits + 1] = string.format("%.0fs", params.dur / 60) end
  if #bits == 0 then return nil end
  return table.concat(bits, " ")
end
MonsterCard.afflValue = afflValue

-- TOKENISATION des valeurs inline (colorer les nombres d'une ligne dans la couleur de l'affliction de
-- l'unité, sans toucher l'i18n). Un mot est « valeur » s'il commence (ponctuation ouvrante retirée) par un
-- nombre éventuellement signé. PUR / testable headless.
local function tokenizeValues(line)
  local out = {}
  for word, sp in line:gmatch("(%S+)(%s*)") do
    local core = word:gsub("^[%(%[%{<\"']+", "")
    local isVal = core:match("^[%+%-]?%d") ~= nil
    out[#out + 1] = { text = word, sp = sp, value = isVal }
  end
  return out
end
MonsterCard.tokenizeValues = tokenizeValues

-- ── Sous-rendus (transposés ; restylés au kit propre, signatures conservées) ────────────────────────

-- LIGNE de description en colorant les VALEURS dans la couleur de l'affliction `aff` + 1re valeur préfixée
-- de l'icône de l'affliction. Sans affliction -> ligne unie (chemin neutre). PUR-RENDER. (Signature et
-- comportement INCHANGÉS — tests/ui.lua en dépend ; seules les couleurs/police d'appel changent au-dehors.)
local function drawDescLine(line, x, y, font, baseCol, aff, maxW)
  love.graphics.setFont(font)
  local affCol = aff and Keywords.get(aff)
  affCol = affCol and affCol.color or nil
  local icon = aff and Keywords.icon(aff) or nil
  if not affCol then
    Draw.text(line, x, y, baseCol, font)
    return
  end
  local cx, cy, fh = x, y, font:getHeight()
  local roomForIcon = (not maxW) or (font:getWidth(line) + (icon and (icon.w + 2) or 0) <= maxW)
  local iconUsed = false
  for _, tok in ipairs(tokenizeValues(line)) do
    if tok.value then
      if icon and roomForIcon and not iconUsed then
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(icon.image, math.floor(cx), math.floor(cy + fh / 2 - icon.h / 2), 0, 1, 1)
        cx = cx + icon.w + 2
        iconUsed = true
      end
      Draw.setColor(affCol)
    else
      Draw.setColor(baseCol)
    end
    love.graphics.print(tok.text, math.floor(cx), math.floor(cy))
    cx = cx + font:getWidth(tok.text)
    if tok.sp ~= "" then cx = cx + font:getWidth(tok.sp) end
  end
  love.graphics.setColor(1, 1, 1, 1)
end
MonsterCard.drawDescLine = drawDescLine

-- PORTRAIT : re-rend le rig de l'unité dans `region`, CLIPPÉ (Draw.scissor), DANS une niche propre
-- (Panel.niche : hachures + liseré iron). Halo de rareté additif derrière (héros R4-R5). `rigc` = char à
-- dessiner (animé du build OU mini-rig figé) ; les bounds/scale viennent de MiniRig (déterministes,
-- identiques à l'ancien Build:rigBounds). `view` requis pour le clip ; nil = pas de clip.
local function drawCardPortrait(view, palette, id, rigc, region, rank, rarCol, rich, t)
  local useCritter = Critter and Critter.has and Critter.has(id) -- créature VIVANTE générée (comme le board)
  -- 1) FOND propre : un simple panneau sombre + liseré, SANS hachure (retour user 2026-06 : « du moment qu'on
  -- voit la créature, c'est simple, c'est parfait » -> on retire l'ancien Panel.niche hachuré).
  Draw.rect(region.x, region.y, region.w, region.h, C.stone900, C.iron, 1)
  local cx = region.x + region.w / 2
  local feet = region.y + region.h - 5
  -- 2) halo de rareté (héros) : cercles additifs doux teintés du cadre de rang, DERRIÈRE la créature.
  if rich and love.graphics.setBlendMode and love.graphics.circle then
    local rar = Rarity.get(rank)
    if rar and rar.glow and rar.glow > 0 then
      love.graphics.setBlendMode("add")
      for k = 3, 1, -1 do
        love.graphics.setColor(rarCol[1], rarCol[2], rarCol[3], rar.glow * 0.10 * k)
        love.graphics.circle("fill", cx, region.y + region.h * 0.5, region.h * 0.42 * (k / 3))
      end
      love.graphics.setBlendMode("alpha"); love.graphics.setColor(1, 1, 1, 1)
    end
  end
  -- 3) CLIP + CRÉATURE. On dessine EXACTEMENT le rendu vivant du board : Critter (ailes/yeux/feu animés). Repli
  -- rig baké (créatures dessinées-main sans Critter). Restaure le scissor parent (la carte peut vivre dans un clip).
  local px, py, pw, ph
  if love.graphics.getScissor then px, py, pw, ph = love.graphics.getScissor() end
  if view then Draw.scissor(view, region.x, region.y, region.w, region.h) end
  if useCritter then
    Critter.drawAt(nil, id, math.floor(cx), math.floor(feet), region.h * 0.95 / 64, t or 0, 1)
  else
    rigc = rigc or MiniRig.rig(id, palette)
    local bnd = MiniRig.bounds(id, palette)
    local s = MiniRig.fitScale(id, region.w, region.h, palette, 0.82, 3.5)
    love.graphics.push()
    love.graphics.translate(math.floor(cx), math.floor(feet))
    love.graphics.scale(s, s)
    love.graphics.translate(0, -bnd.bot)
    rigc.x, rigc.y, rigc.facing = 0, 0, 1
    Rig.draw(rigc)
    love.graphics.pop()
  end
  if view then
    if px then love.graphics.setScissor(px, py, pw, ph) else love.graphics.setScissor() end
  end
  love.graphics.setColor(1, 1, 1, 1)
  -- 4) re-liseré iron par-dessus (la créature a pu mordre le bord).
  Draw.rect(region.x, region.y, region.w, region.h, nil, C.iron, 1)
end
MonsterCard.drawCardPortrait = drawCardPortrait

-- STATS = une BARRE encastrée (rect stone900 + liseré iron) portant 3 cellules [HP] [DMG] [CD] : label
-- Space Mono ink3 + valeur Space Mono teintée (HP encre, DMG sang, CD or terni). Calquée sur la barre de
-- stats du tooltip propre. `region` = boîte allouée (x,y,w,h). Renvoie la hauteur dessinée.
local function drawCardStats(id, U, region)
  local sf = Theme.value(11)
  local barH = (sf and sf:getHeight() or 12) + STAT_PADV
  Draw.rect(region.x, region.y, region.w, barH, C.stone900, C.iron, 1)
  local specs = {
    { lab = T("ui.stat_hp"),  val = tostring(U.hp),                            vcol = C.ink },
    { lab = T("ui.stat_dmg"), val = tostring(U.dmg),                           vcol = C.dmg },
    { lab = T("ui.stat_cd"),  val = string.format("%.1fs", (U.cd or 60) / 60), vcol = C.gold },
  }
  if sf and love.graphics and love.graphics.print then
    love.graphics.setFont(sf)
    local n = #specs
    local cellW = region.w / n
    local midY = region.y + barH / 2
    for i = 1, n do
      local s = specs[i]
      local ccx = region.x + (i - 0.5) * cellW
      local lw = sf:getWidth(s.lab .. " ")
      local vw = sf:getWidth(s.val)
      local sx = math.floor(ccx - (lw + vw) / 2)
      Draw.text(s.lab, sx, midY - sf:getHeight() / 2, C.ink3, sf)
      Draw.text(s.val, sx + lw, midY - sf:getHeight() / 2, s.vcol, sf)
    end
  end
  return barH
end
MonsterCard.drawCardStats = drawCardStats

-- ── API publique ────────────────────────────────────────────────────────────────────────────────────
-- MonsterCard.draw(view, palette, id, anchorX, anchorY, t, opts)
--   view      : vue d'espace-design (clip du portrait). nil = pas de clip (la carte tient quand même).
--   palette   : palette des rigs (nil -> palette Wraeclast par défaut via MiniRig).
--   id        : id d'unité (clé Units / i18n).
--   anchorX/Y : position d'ANCRE en ESPACE DESIGN (typiquement le curseur). La carte suit + rebond bords.
--   t         : horloge d'animation (secondes). ACCEPTÉE pour compat ; le Panel propre est statique.
--   opts.rig  : char à dessiner pour le portrait (build : rig d'aperçu animé). nil -> mini-rig figé.
-- Renvoie la boîte { x, y, w, h } posée (utile au caller). nil si l'id est inconnu.
function MonsterCard.draw(view, palette, id, anchorX, anchorY, t, opts)
  opts = opts or {}
  local U = Units[id]
  if not U then return nil end
  local rank = U.rank or 1
  local rich = rank >= 4 -- héros R4-R5 : halo de rareté derrière le portrait
  local rarCol = Rarity.frame(rank)
  local innerW = W - PAD * 2

  -- ── 1) POLICES + MESURE : hauteur dérivée du contenu (jamais une constante devinée). ──
  local nameFont = Theme.subhead(15) or Theme.heading(15) -- NOM = voix gravée (Cinzel)
  local idFont = Theme.label(10)                          -- TYPE/famille = voix inscrite (Space Mono)
  local statFont = Theme.value(11)
  local passFont = Theme.value(11)                        -- nom de passif = Space Mono or
  local descFont = Theme.body(13) or Theme.bodyLight(13)  -- description = prose Spectral LISIBLE
  local flavFont = Theme.flavor(13) or Theme.bodyItalic(13)
  local DESC_LINE = (descFont and descFont:getHeight() or 14) + 2

  local affl = Keywords.applied(U)
  local primAff = affl[1]
  local passiveName = T("unit." .. id .. ".passive_name")
  local passiveDesc = T("unit." .. id .. ".passive_desc")
  local hasPassiveName = passiveName ~= ("unit." .. id .. ".passive_name")
  local descLines = {}
  if descFont then local _w; _w, descLines = descFont:getWrap(passiveDesc, innerW) end
  local nDescLines = math.max(1, #descLines)
  local flavorKey = "unit." .. id .. ".flavor"
  local hasFlavor = I18n.has(flavorKey)

  -- mesure des hauteurs de bloc
  local hName = (nameFont and nameFont:getHeight()) or 16
  local hIdent = (idFont and idFont:getHeight()) or 12
  local hSection = 12 -- hauteur d'un Dividers.text (label inscrit 10px)
  local hStatBar = ((statFont and statFont:getHeight()) or 12) + STAT_PADV
  local hPassName = (passFont and passFont:getHeight()) or 12
  local hFlav = (flavFont and flavFont:getHeight() or 14)

  -- pile verticale (le même rythme qu'au dessin) -> hauteur totale CONTENUE.
  local h = PAD
  h = h + hName                                     -- en-tête (nom + coût)
  h = h + GAP + PORTRAIT_H                           -- portrait (niche)
  h = h + GAP + hIdent                               -- identité (pip · type · famille · rareté)
  h = h + SECTION_GAP + hSection + GAP + hStatBar    -- titre STATS + barre
  h = h + SECTION_GAP + hSection                     -- titre ABILITIES
  if #affl > 0 then h = h + GAP + CHIP_H end          -- rangée de chips
  if hasPassiveName then h = h + GAP + hPassName end  -- nom de passif
  h = h + GAP + nDescLines * DESC_LINE                -- description
  if hasFlavor and flavFont then
    local _, fLines = flavFont:getWrap(T(flavorKey), innerW)
    h = h + SECTION_GAP + #fLines * (hFlav + 1)
  end
  h = h + PAD

  -- ── 2) POSITION : suit l'ancre (curseur), rebond sur les bords (jamais hors écran). ──
  local x, y = anchorX + 18, anchorY + 10
  if x + W > Draw.W then x = anchorX - W - 18 end
  if x < 4 then x = 4 end
  if y + h > Draw.H then y = Draw.H - h - 6 end
  if y < 4 then y = 4 end
  x, y = math.floor(x), math.floor(y)

  -- ── 3) FOND : Panel propre (dégradé sombre + liseré iron + éclat haut ; accent de rareté pour héros). ──
  Panel.draw(x, y, W, h, {
    fill1 = C.stone800, fill2 = C.stone900,
    accent = rarCol, -- liseré interne TEINTÉ par le TIER pour TOUTES les raretés (la carte « respecte » la couleur de rang)
    solid = true, -- fiche flottante OPAQUE : nette, sans bave de distorsion ni bordure des cartes de derrière (retour user 2026-06)
  })

  -- ── 4) CONTENU : pile à curseur vertical (calque du tooltip), chaque bloc mesuré. ──
  local bodyX = x + PAD
  local rightX = x + W - PAD
  local cy = y + PAD

  -- (a) EN-TÊTE : nom (Cinzel, gauche) + coût (Badge.cost, droite, aligné sur la ligne du nom).
  Draw.text(T("unit." .. id .. ".name"), bodyX, cy, C.ink, nameFont)
  if U.cost then
    -- Badge.cost dessine [losange 5r][gap 4][valeur] à partir de x ; on le pose à droite via sa largeur
    -- mesurée (la fonction renvoie aussi sa largeur, mais on la veut AVANT pour caler le x à droite).
    local cf = Theme.value(15)
    local numW = (cf and cf:getWidth(tostring(U.cost))) or (#tostring(U.cost) * 9)
    local badgeW = 2 * 5 + 4 + numW
    Badge.cost(math.floor(rightX - badgeW), cy, U.cost, true)
  end
  cy = cy + hName + GAP

  -- (b) PORTRAIT : rig ajusté pour remplir la niche, clippé. Halo de rareté pour les héros.
  local portRegion = { x = bodyX, y = cy, w = innerW, h = PORTRAIT_H }
  drawCardPortrait(view, palette, id, opts.rig, portRegion, rank, rarCol, rich, t)
  cy = cy + PORTRAIT_H + GAP

  -- (c) IDENTITÉ : [ pastille de TIER · NOM DE CASTE (couleur de rang) ........ ◆◆ rareté ]. La famille
  -- (pip + mot) est RETIRÉE : aucune incidence mécanique (retour user 2026-06) -> la carte se lit par le TIER.
  local midI = math.floor(cy + hIdent / 2)
  local tierC = Rarity.tierColor(rank)
  if love.graphics and love.graphics.circle then
    love.graphics.setColor(tierC[1], tierC[2], tierC[3], 1); love.graphics.circle("fill", bodyX + 5, midI, 4)
    love.graphics.setColor(0, 0, 0, 0.5); love.graphics.circle("line", bodyX + 5, midI, 4.5)
    love.graphics.setColor(1, 1, 1, 1)
  end
  Draw.text(T(Rarity.tierNameKey(rank)), bodyX + 14, midI - hIdent / 2, Rarity.tierBright(rank), idFont)
  -- rangée de losanges de rareté (Badge.diamond), alignée à droite.
  local DSP = 8
  local rx0 = rightX - (rank * DSP) + 4
  for k = 1, rank do
    Badge.diamond(rx0 + (k - 1) * DSP, midI, 3, rarCol, C.brass, C.brassS)
  end
  cy = cy + hIdent + SECTION_GAP

  -- (d) titre de section STATS (label inscrit entre filets iron).
  Dividers.text(x + W / 2, cy, innerW, "STATS")
  cy = cy + hSection + GAP

  -- (e) STATS : barre encastrée HP/DMG/CD.
  local statH = drawCardStats(id, U, { x = bodyX, y = cy, w = innerW, h = hStatBar })
  cy = cy + statH + SECTION_GAP

  -- (f) titre de section ABILITIES.
  Dividers.text(x + W / 2, cy, innerW, "ABILITIES")
  cy = cy + hSection

  -- (g) CAPACITÉS : chips d'affliction (icône + nom + valeur) + nom de passif (or) + description lisible.
  if #affl > 0 then
    cy = cy + GAP
    local fontChip = Theme.label(9)
    local valBy = {}
    for _, e in ipairs(U.effects or {}) do
      local k = Keywords.opAffliction(e.op)
      if k and not valBy[k] then valBy[k] = afflValue(e.params) end
    end
    local chx = bodyX
    for _, k in ipairs(affl) do
      local w2 = Chip.draw(chx, cy, { key = k, value = valBy[k], font = fontChip, h = CHIP_H })
      chx = chx + w2 + 5
      if chx > bodyX + innerW - 24 then break end
    end
    cy = cy + CHIP_H
  end
  if hasPassiveName then
    cy = cy + GAP
    Draw.text(passiveName, bodyX, cy, C.gold, passFont)
    cy = cy + hPassName
  end
  cy = cy + GAP
  for _, line in ipairs(descLines) do
    drawDescLine(line, bodyX, cy, descFont, C.ink2, primAff, innerW)
    cy = cy + DESC_LINE
  end

  -- (h) FLAVOR (Spectral italique), détaché du bloc mécanique par un divider laiton discret.
  if hasFlavor and flavFont then
    cy = cy + SECTION_GAP - GAP
    Dividers.brass(x + W / 2, cy, innerW - 20)
    cy = cy + 6
    Draw.textWrap(T(flavorKey), bodyX, cy, innerW, C.ink3, flavFont)
  end
  Draw.reset()

  return { x = x, y = y, w = W, h = h }
end

return MonsterCard
