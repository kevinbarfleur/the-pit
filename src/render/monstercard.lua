-- src/render/monstercard.lua
-- FICHE « carte de monstre » (TCG) flottante : plaque forge qui respire + portrait + identité + value-tags
-- (HP/DMG/CD) + capacités (afflictions appliquées + passif + description lisible) + flavor. EXTRAITE de
-- src/scenes/build.lua (Build:drawTooltip et ses helpers drawCardPortrait/drawCardStats/drawDescLine) pour
-- être réutilisable hors du build — d'abord La Chronique (survol d'un nom -> carte près du curseur).
--
-- TOUT est PARAMÉTRÉ (view, palette, id, ancre curseur, horloge t) au lieu de self.* : aucun couplage à la
-- scène. Le placement (suit le curseur, rebond sur les bords) est interne. Couche RENDER (love.graphics).
--
-- PORTRAIT : silhouette mesurée via MiniRig (cache + bounds déterministes, identiques à l'ancien
-- Build:rigBounds — même algo/probe). Le CHAR dessiné est paramétrable (opts.rig) : le build passe son rig
-- d'aperçu ANIMÉ (le portrait respire, comme avant) ; sans opts.rig on prend le mini-rig FIGÉ (chronique).
-- Les BOUNDS restent ceux de MiniRig dans les deux cas (l'oscillation idle ne change pas l'enveloppe de fit).

local Draw = require("src.ui.draw")
local Theme = require("src.ui.theme")
local Forge = require("src.ui.forge")
local Layout = require("src.ui.layout")
local Keywords = require("src.ui.keywords")
local Chip = require("src.ui.chip")
local Rarity = require("src.gen.rarity")
local Units = require("src.data.units")
local I18n = require("src.core.i18n")
local MiniRig = require("src.render.minirig")
local Rig = require("src.core.rig")
local T = I18n.t

local MonsterCard = {}

-- ── Helpers PURS (transposés depuis build.lua, identiques) ──────────────────────────────────────────

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

-- Rang de rareté -> teinte d'accent du cadre forge (Forge attend des octets 0..255 ; Rarity.frame = floats).
local function rarityAccent(rank)
  return Forge.accentFrom(Rarity.frame(rank or 1))
end

-- Fond LAVÉ vers la couleur de rareté (cf. drawTooltip) : la fiche « lit » sa rareté par sa matière.
local function rarityTint(rank)
  return Forge.tintFrom(Rarity.frame(rank or 1), 0.16)
end

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

-- ── Sous-rendus (transposés ; self.* -> paramètres) ─────────────────────────────────────────────────

-- LIGNE de description en colorant les VALEURS dans la couleur de l'affliction `aff` + 1re valeur préfixée
-- de l'icône de l'affliction. Sans affliction -> ligne unie (chemin neutre). PUR-RENDER.
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

-- PORTRAIT : re-rend le rig de l'unité dans `region`, CLIPPÉ (Draw.scissor), halo de rareté additif derrière
-- (héros). `rigc` = char à dessiner (animé du build OU mini-rig figé) ; les bounds/scale viennent de MiniRig
-- (déterministes, identiques à l'ancien Build:rigBounds). `view` requis pour le clip ; nil = pas de clip.
local function drawCardPortrait(view, palette, id, rigc, region, rank, rarCol, rich)
  rigc = rigc or MiniRig.rig(id, palette)
  local divW = region.w - 12
  Draw.divider(region.x + region.w / 2, region.y + 1, divW, Theme.c.gold, 0.35)
  Draw.divider(region.x + region.w / 2, region.y + region.h - 1, divW, Theme.c.gold, 0.35)
  local cx = region.x + region.w / 2
  local bnd = MiniRig.bounds(id, palette)
  local s = MiniRig.fitScale(id, region.w, region.h, palette, 0.82, 3.5)
  local feet = region.y + region.h - 5
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
  -- CLIP : restaure le scissor parent au lieu de l'effacer (la carte peut elle-même vivre dans un clip).
  local px, py, pw, ph
  if love.graphics.getScissor then px, py, pw, ph = love.graphics.getScissor() end
  if view then Draw.scissor(view, region.x, region.y, region.w, region.h) end
  love.graphics.push()
  love.graphics.translate(math.floor(cx), math.floor(feet))
  love.graphics.scale(s, s)
  love.graphics.translate(0, -bnd.bot)
  rigc.x, rigc.y, rigc.facing = 0, 0, 1
  Rig.draw(rigc)
  love.graphics.pop()
  if view then
    if px then love.graphics.setScissor(px, py, pw, ph) else love.graphics.setScissor() end
  end
  love.graphics.setColor(1, 1, 1, 1)
end
MonsterCard.drawCardPortrait = drawCardPortrait

-- STATS = 3 valeurs FRAMELESS [HP] [DMG] [CD] : GRANDE valeur (police read) + mini label dessous, en rangée
-- ÉGALE (Layout.row), séparées par des points-diamants forge. Teintes : HP corps, DMG rouge, CD doré sobre.
local function drawCardStats(id, U, region, rarCol)
  local c = Theme.c
  local cols = Layout.row(region, { { flex = 1 }, { flex = 1 }, { flex = 1 } }, { gap = 4, align = "stretch" })
  local specs = {
    { key = T("ui.stat_hp"),  value = tostring(U.hp),                            vcol = c.body },
    { key = T("ui.stat_dmg"), value = tostring(U.dmg),                           vcol = c.dmg },
    { key = T("ui.stat_cd"),  value = string.format("%.1fs", (U.cd or 60) / 60), vcol = c.muted },
  }
  for k = 1, 3 do
    local col, s = cols[k], specs[k]
    local ccx = col.x + col.w / 2
    Forge.label(s.value, ccx, col.y + 11, 18, { s.vcol[1], s.vcol[2], s.vcol[3] }, { read = true, shadow = true })
    Draw.textC(s.key, ccx, col.y + col.h - 11, c.faint, Theme.ui(8))
    if k < 3 then
      Forge.diamondAt(col.x + col.w + 2, col.y + col.h / 2 - 2, 2, c.fainter)
    end
  end
end
MonsterCard.drawCardStats = drawCardStats

-- ── API publique ────────────────────────────────────────────────────────────────────────────────────
-- MonsterCard.draw(view, palette, id, anchorX, anchorY, t, opts)
--   view      : vue d'espace-design (clip du portrait). nil = pas de clip (la carte tient quand même).
--   palette   : palette des rigs (nil -> palette Wraeclast par défaut via MiniRig).
--   id        : id d'unité (clé Units / i18n).
--   anchorX/Y : position d'ANCRE en ESPACE DESIGN (typiquement le curseur). La carte suit + rebond bords.
--   t         : horloge d'animation (secondes) pour la respiration de la plaque forge.
--   opts.rig  : char à dessiner pour le portrait (build : rig d'aperçu animé). nil -> mini-rig figé.
-- Renvoie la boîte { x, y, w, h } posée (utile au caller).
function MonsterCard.draw(view, palette, id, anchorX, anchorY, t, opts)
  opts = opts or {}
  local U, c = Units[id], Theme.c
  if not U then return nil end
  local rank = U.rank or 1
  local rich = rank >= 4 -- héros R4-R5 : cadre plus riche + œil qui guette
  local rarCol = Rarity.frame(rank)

  -- ── 1) MESURE : hauteur dérivée du contenu (capacités + lignes de prose) -> jamais cramé. ──
  local fontDesc = Theme.read(13)
  local DESC_LINE = fontDesc:getHeight() + 3
  local W = 318
  local PAD = 14
  local contentW = W - PAD * 2
  local affl = Keywords.applied(U)
  local primAff = affl[1]
  local passiveName = T("unit." .. id .. ".passive_name")
  local passiveDesc = T("unit." .. id .. ".passive_desc")
  local _, descLines = fontDesc:getWrap(passiveDesc, contentW)
  local nDescLines = math.max(1, #descLines)
  local hasPassiveName = passiveName ~= ("unit." .. id .. ".passive_name")
  local flavorKey = "unit." .. id .. ".flavor"
  local hasFlavor = I18n.has(flavorKey)

  local GAPV = 7
  local PORTRAIT_H = 72
  local STATS_H = 34
  local h = PAD
  h = h + 22                    -- header
  h = h + GAPV + PORTRAIT_H     -- portrait
  h = h + GAPV + 18             -- identité
  h = h + GAPV + 8              -- divider
  h = h + GAPV + STATS_H        -- stats
  h = h + GAPV + 8              -- divider
  h = h + GAPV                  -- gap avant capacités
  if #affl > 0 then h = h + 22 end
  if hasPassiveName then h = h + 18 end
  h = h + 3 + nDescLines * DESC_LINE
  local fontFlav = Theme.lore(13)
  if hasFlavor then
    local _, fLines = fontFlav:getWrap(T(flavorKey), contentW)
    h = h + 10 + #fLines * (fontFlav:getHeight() + 1)
  end
  h = h + PAD

  -- ── 2) POSITION : suit l'ancre (curseur), rebond sur les bords (jamais hors écran). ──
  local x, y = anchorX + 18, anchorY + 10
  if x + W > Draw.W then x = anchorX - W - 18 end
  if x < 4 then x = 4 end
  if y + h > Draw.H then y = Draw.H - h - 6 end
  if y < 4 then y = 4 end
  x, y = math.floor(x), math.floor(y)

  -- ── 3) FOND forge (plaque qui respire + cadre patiné, accent + lavage de rareté, œil si héros). ──
  Forge.uiCard("monstercard." .. id, x, y, W, h,
    { px = 2, seed = 40 + (#id), accentCol = rarityAccent(rank), rich = rich, t = t or 0,
      tint = rarityTint(rank) })

  -- ── 4) CONTENU en colonne Layout (rythme régulier : gap = GAPV partout). ──
  local box = { x = x, y = y, w = W, h = h }
  local inner = Layout.inset(box, PAD)
  local rows = Layout.column(inner, {
    { size = 22 }, { size = PORTRAIT_H }, { size = 18 }, { size = 8 },
    { size = STATS_H }, { size = 8 }, { flex = 1 },
  }, { gap = GAPV, align = "stretch" })
  local rHead, rPort, rIdent, rDiv1, rStats, rDiv2, rAbil = rows[1], rows[2], rows[3], rows[4], rows[5], rows[6], rows[7]

  -- (a) HEADER : nom (gauche) + coût (pièce d'or + valeur read, droite).
  local fontName = Theme.uiBold(14)
  Draw.text(T("unit." .. id .. ".name"), rHead.x, rHead.y + 3, c.title, fontName)
  if U.cost then
    local costStr = tostring(U.cost)
    local cw = Theme.read(16):getWidth(costStr)
    local cmY = rHead.y + 11
    Forge.label(costStr, rHead.x + rHead.w, cmY, 16, { c.gold[1], c.gold[2], c.gold[3] },
      { read = true, right = true, shadow = true })
    Forge.coinAt(rHead.x + rHead.w - cw - 7, cmY, 4, c.goldBright)
  end

  -- (b) PORTRAIT : rig ajusté pour remplir, clippé. Halo de rareté pour les héros.
  drawCardPortrait(view, palette, id, opts.rig, rPort, rank, rarCol, rich)

  -- (c) IDENTITÉ : [ pip · TYPE · Famille ........ ◆◆ rareté ].
  local fontId = Theme.ui(10)
  local ix = rIdent.x
  local midI = math.floor(rIdent.y + rIdent.h / 2)
  Draw.pip(U.type, ix + 5, midI, 5)
  ix = ix + 14
  local tcol = Theme.type(U.type).color
  local typeStr = T("type." .. U.type):upper()
  Draw.text(typeStr, ix, midI - fontId:getHeight() / 2, tcol, fontId)
  ix = ix + fontId:getWidth(typeStr) + 8
  if U.family then
    local famStr = (U.family:gsub("^%l", string.upper))
    Draw.text(famStr, ix, midI - fontId:getHeight() / 2, c.muted, fontId)
  end
  local DSP = 8
  local rx0 = rIdent.x + rIdent.w - (rank * DSP) + 1
  for k = 1, rank do
    Forge.diamondAt(rx0 + (k - 1) * DSP, midI, 3, rarCol)
  end

  -- (d) divider forge.
  Draw.divider(rDiv1.x + rDiv1.w / 2, rDiv1.y + rDiv1.h / 2, rDiv1.w - 8, c.gold, 0.7)
  Forge.diamondAt(rDiv1.x + rDiv1.w / 2, rDiv1.y + rDiv1.h / 2, 2, c.goldBright)

  -- (e) STATS = value-tags HP/DMG/CD.
  drawCardStats(id, U, rStats, rarCol)

  -- (f) divider forge.
  Draw.divider(rDiv2.x + rDiv2.w / 2, rDiv2.y + rDiv2.h / 2, rDiv2.w - 8, c.gold, 0.7)
  Forge.diamondAt(rDiv2.x + rDiv2.w / 2, rDiv2.y + rDiv2.h / 2, 2, c.goldBright)

  -- (g) CAPACITÉS : value-chips d'affliction + nom de passif (or) + description lisible.
  local ay = rAbil.y
  if #affl > 0 then
    local fontChip = Theme.ui(9)
    local valBy = {}
    for _, e in ipairs(U.effects or {}) do
      local k = Keywords.opAffliction(e.op)
      if k and not valBy[k] then valBy[k] = afflValue(e.params) end
    end
    local cx = rAbil.x
    for _, k in ipairs(affl) do
      local w2 = Chip.draw(cx, ay, { key = k, value = valBy[k], font = fontChip, h = 18 })
      cx = cx + w2 + 5
      if cx > rAbil.x + rAbil.w - 30 then break end
    end
    ay = ay + 22
  end
  if hasPassiveName then
    Draw.text(passiveName, rAbil.x, ay, c.goldBright, Theme.uiBold(11))
    ay = ay + 18
  end
  ay = ay + 3
  for _, line in ipairs(descLines) do
    drawDescLine(line, rAbil.x, ay, fontDesc, c.body, primAff, contentW)
    ay = ay + DESC_LINE
  end

  -- (h) FLAVOR (italique IM Fell), détaché du bloc mécanique par un gap + divider doré discret.
  if hasFlavor then
    ay = ay + 4
    Draw.divider(rAbil.x + contentW / 2, ay, contentW - 20, c.gold, 0.3)
    ay = ay + 5
    Draw.textWrap(T(flavorKey), rAbil.x, ay, contentW, c.dim, fontFlav)
  end

  return box
end

return MonsterCard
