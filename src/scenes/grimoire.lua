-- src/scenes/grimoire.lua
-- LE GRIMOIRE — codex/COLLECTION persistant, à DEUX ONGLETS : RELIQUES + BESTIAIRE. Une entrée RENCONTRÉE
-- (relique inscrite : Grimoire.isKnown ; créature vue : Bestiary.isSeen) s'y dévoile à vie au niveau du compte
-- (méta-progression). Les non rencontrées restent voilées (« ??? ») — sauf MODE DEV full-unlock (read-time).
-- Tri cyclable (reliques : catégorie/tier/nom ; créatures : type/rang/nom).
--
-- CHROME = KIT PROPRE (.dc.html / design-system) : la scène ne dessine plus ses panneaux/rangs/onglets À LA
-- MAIN. Elle compose les ATOMES du kit (Panel/Button/Slot/Dividers/Badge) pour rester cohérente avec le reste
-- du jeu (build/menu/designsystem) :
--   • onglets RELIQUES/BESTIAIRE = Button.draw (secondary, état actif) + compteur Space Mono ;
--   • puce de tri = Button.draw (secondary, cyclable) ;
--   • liste scrollable = Panel backing + vignette en Slot.draw (icône RelicGen / rig Rig.draw RESEATÉ dans la
--     case propre) + nom Cinzel + méta Space Mono ; clip Draw.scissor + molette + thumb laiton ;
--   • détail = Panel.draw (accent de rareté en bestiaire) + Dividers + Badge.rarity ; noms Cinzel, prose/flavor
--     Spectral, valeurs Space Mono ;
--   • retour = Button.ghost « [esc] back ».
-- On RÉUTILISE les appels d'art (RelicGen.cached pour les reliques, Rig.draw pour les créatures, Rarity
-- glow/frame + l'échelle des 5 rangs) — on les RÉASSOIT seulement dans des cadres propres.
--
-- Couche RENDER (love.graphics) en ESPACE DESIGN 1280x720. daChrome=true. [esc]/[g] -> retour menu (main).

local Theme = require("src.ui.theme")
local Draw = require("src.ui.draw")
local Panel = require("src.ui.panel")      -- surface propre (dégradé + liseré iron + éclat)
local Button = require("src.ui.button")    -- onglets / tri (secondary)
local Nav = require("src.ui.nav")          -- bouton retour homogène (règle de navigation)
local Slot = require("src.ui.slot")        -- cadre de vignette (case propre) pour icône/rig
local Dividers = require("src.ui.dividers") -- séparateurs laiton/sang/texte propres
local Badge = require("src.ui.badge")      -- échelle de rareté R1..R5 propre (bestiaire)
local Feel = require("src.ui.feel")        -- JUICE : survol des onglets/tri/back (glow/lift)
local Ambient = require("src.fx.ambient")
local Relics = require("src.data.relics")
local Grimoire = require("src.core.grimoire")
local Bestiary = require("src.core.bestiary")
local RelicGen = require("src.gen.relicgen")
local Rig = require("src.core.rig")
local Creatures = require("src.data.creatures")
local Units = require("src.data.units")
local CreatureGen = require("src.gen.creaturegen")
local Rarity = require("src.gen.rarity")
local T = require("src.core.i18n").t

local C = Theme.c

local Screen = {}
Screen.__index = Screen

-- Catégorie de chaque relique (A stats · B amplis · C paliers · D défensives · E transformatives) — métadonnée
-- d'affichage/tri (cf. docs/research/relics-design.md). En dur ici : la data de jeu ne porte que tier.
local RELIC_CAT = {
  bloodstone = "A", carapace = "A", aegis = "A", whetstone = "A",
  kings_bowl = "B", ember_heart = "B", weeping_nail = "B", grave_cap = "B",
  famines_math = "C", hollow_choir = "C", feeding_frenzy = "C",
  thornguard = "D", sacred_shield = "D", second_breath = "D",
  forked_tongue = "E", everburn = "E", open_wounds = "E", plague_communion = "E",
}
local CAT_LABEL = { A = "STATS", B = "AFFLICTION", C = "PAYOFF", D = "DEFENSE", E = "TRANSFORM" }

-- Teinte d'accent par type de créature (réutilise la convention galerie) — sert au liseré du portrait.
local TYPE_COL = {
  flesh = { 0.66, 0.53, 0.45 }, order = { 0.77, 0.63, 0.29 }, bone = { 0.66, 0.57, 0.44 },
  arcane = { 0.55, 0.40, 0.66 }, abyss = { 0.62, 0.24, 0.16 },
}

-- Modes de tri cyclables par onglet.
local SORTS = {
  relics = { "category", "tier", "name" },
  bestiary = { "type", "rank", "name" },
}
local SORT_LABEL = { category = "CATEGORY", tier = "TIER", name = "NAME", type = "TYPE", rank = "RANK" }

-- Mise en page (espace design). On garde l'inset/colonnes pour préserver les hit-tests + le clip de la liste.
local TITLE_Y = 30
local TAB_Y, TAB_W, TAB_H = 84, 168, 32
local SORT_Y, SORT_W, SORT_H = 124, 200, 26
local LIST_X, LIST_Y, LIST_W = 32, 158, 396
local LIST_BOTTOM = 690
local ROW_H, ROW_GAP = 48, 6
local DET_X, DET_Y, DET_W, DET_H = 452, 158, 796, 532

local function listViewH() return LIST_BOTTOM - LIST_Y end
local function ptIn(px, py, x, y, w, h) return px >= x and px <= x + w and py >= y and py <= y + h end

function Screen.new(palette, vw, vh, host)
  local self = setmetatable({
    vw = vw, vh = vh, t = 0, host = host, palette = palette,
    daChrome = true,
    titleKey = "scene.build", hintKey = "ui.empty",
    tab = "relics",
    sort = { relics = "category", bestiary = "type" },
    sel = 1, hover = nil, scroll = 0,
    mx = -100, my = -100, -- souris en ESPACE DESIGN (pour le survol des boutons)
    ambient = Ambient.new(5),
  }, Screen)
  Feel.reset() -- repart au repos (survol/press des onglets/tri vierges) en (re)entrant

  -- ENTRÉES RELIQUES (métadonnée seule ; l'icône bakée est tirée à la volée via RelicGen.cached).
  self.relicEntries = {}
  for _, id in ipairs(Relics.order) do
    self.relicEntries[#self.relicEntries + 1] = { id = id, cat = RELIC_CAT[id] or "Z", tier = Relics[id].tier or 1 }
  end

  -- ENTRÉES BESTIAIRE : un rig par unité, EXACTEMENT comme le combat (6 dédiées sinon génération procédurale).
  self.beastEntries = {}
  for _, id in ipairs(Units.order) do
    local spec = Units[id] or {}
    local handmade = Creatures[id] ~= nil
    local def = handmade and Creatures[id]
      or CreatureGen.cached({ id = id, type = spec.type, family = spec.family, effects = spec.effects, bodyplan = spec.bodyplan, rank = spec.rank })
    local char = Rig.new(def, palette); char.facing = 1
    self.beastEntries[#self.beastEntries + 1] = {
      id = id, char = char, type = spec.type or "flesh", rank = spec.rank, bodyplan = spec.bodyplan,
    }
  end

  self._tabRects = {}
  self:refresh()
  return self
end

-- (Re)lit l'état connu/vu (la persistance change entre deux ouvertures ; le toggle dev aussi) + (re)trie.
function Screen:refresh()
  self.knownRelics, self.seenBeasts = 0, 0
  for _, e in ipairs(self.relicEntries) do if Grimoire.isKnown(e.id) then self.knownRelics = self.knownRelics + 1 end end
  for _, e in ipairs(self.beastEntries) do if Bestiary.isSeen(e.id) then self.seenBeasts = self.seenBeasts + 1 end end
  self:rebuildRows()
end

-- Trie l'onglet courant -> self.rows (entrées + flag « révélé »). Inconnus regroupés EN FIN (tri stable).
function Screen:rebuildRows()
  local mode = self.sort[self.tab]
  local src, revealed
  if self.tab == "relics" then
    src = self.relicEntries
    revealed = function(e) return Grimoire.isKnown(e.id) end
  else
    src = self.beastEntries
    revealed = function(e) return Bestiary.isSeen(e.id) end
  end
  local rows = {}
  for _, e in ipairs(src) do rows[#rows + 1] = { e = e, on = revealed(e) } end

  -- Clé de tri : connus d'abord (les inconnus en bas), puis par le mode, puis nom (id) pour la stabilité.
  local function nameOf(e) return T("relic." .. e.id .. ".name") end
  local function beastName(e) return T("unit." .. e.id .. ".name") end
  local function key(row)
    local e = row.e
    if self.tab == "relics" then
      if mode == "tier" then return string.format("%d|%s|%s", e.tier, e.cat, e.id) end
      if mode == "name" then return nameOf(e) .. "|" .. e.id end
      return string.format("%s|%d|%s", e.cat, e.tier, e.id) -- category (défaut)
    else
      if mode == "rank" then return string.format("%d|%s|%s", e.rank or 1, e.type, e.id) end
      if mode == "name" then return beastName(e) .. "|" .. e.id end
      return string.format("%s|%d|%s", e.type, e.rank or 1, e.id) -- type (défaut)
    end
  end
  table.sort(rows, function(a, b)
    if a.on ~= b.on then return a.on end -- révélés en haut
    return key(a) < key(b)
  end)
  self.rows = rows
  self.sel = math.min(self.sel or 1, #rows)
  if self.sel < 1 then self.sel = 1 end
  self.scroll = 0
end

function Screen:contentH() return #self.rows * (ROW_H + ROW_GAP) end
function Screen:maxScroll() return math.max(0, self:contentH() - listViewH()) end

function Screen:update(frameDt)
  self.t = self.t + frameDt
  -- Survol des onglets/tri/back -> glow/lift animés (Feel, RENDER pur). Les rects sont posés en draw (1re frame
  -- déjà couverte par new()).
  Feel.update(frameDt)
  Feel.hover("grim.tab.relics", self._tabRects.relics and ptIn(self.mx, self.my, self._tabRects.relics.x, self._tabRects.relics.y, self._tabRects.relics.w, self._tabRects.relics.h) or false)
  Feel.hover("grim.tab.bestiary", self._tabRects.bestiary and ptIn(self.mx, self.my, self._tabRects.bestiary.x, self._tabRects.bestiary.y, self._tabRects.bestiary.w, self._tabRects.bestiary.h) or false)
  Feel.hover("grim.sort", self.sortRect and ptIn(self.mx, self.my, self.sortRect.x, self.sortRect.y, self.sortRect.w, self.sortRect.h) or false)
  Feel.hover("grim.back", self.backRect and ptIn(self.mx, self.my, self.backRect.x, self.backRect.y, self.backRect.w, self.backRect.h) or false)
  -- Anim idle des rigs du bestiaire (comme la galerie).
  for _, e in ipairs(self.beastEntries) do Rig.update(e.char, self.t, frameDt) end
end

function Screen:drawBack(view)
  Draw.begin(view)
  self.ambient:draw("grimoire")
  Draw.finish()
end

function Screen:drawWorld() end

-- Blit d'une icône bakée centrée sur (cx, cy) à scale entier (pixel-perfect, sans teinte).
local function drawIconC(baked, cx, cy, s)
  if not baked or not baked.image then return false end
  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.draw(baked.image, math.floor(cx - 8 * s), math.floor(cy - 8 * s), 0, s, s)
  return true
end

-- Dessine un rig à (cx, cyFeet) en espace design, scalé (le rig est nativement petit). cyFeet = ligne de pieds.
local function drawRigC(char, cx, cyFeet, s)
  love.graphics.push()
  love.graphics.translate(math.floor(cx), math.floor(cyFeet))
  love.graphics.scale(s, s)
  char.x, char.y, char.facing = 0, 0, 1
  Rig.draw(char)
  love.graphics.pop()
  love.graphics.setColor(1, 1, 1, 1)
end

function Screen:drawOverlay(view)
  Draw.begin(view)

  -- En-tête : titre Cinzel (voix gravée) — le « ? ? ? » reste Jacquard (display) pour les inconnus.
  Draw.text(T("grimoire.title"), LIST_X, TITLE_Y, C.ink, Theme.title(34))
  -- retour = bouton homogène « ‹ MENU » (règle de nav design-system). [esc]/[g] restent des accélérateurs.
  self.backRect = Nav.back(view, T("grimoire.back"), { mx = self.mx, my = self.my, id = "grim.back" })

  -- Onglets RELIQUES / BESTIAIRE = boutons propres (secondary), l'actif forcé en survol + un éclat doré ;
  -- compteur n/total en Space Mono (gold actif).
  self:drawTab("relics", T("grimoire.tab_relics"), LIST_X, self.knownRelics, #self.relicEntries)
  self:drawTab("bestiary", T("grimoire.tab_bestiary"), LIST_X + TAB_W + 12, self.seenBeasts, #self.beastEntries)

  -- Puce de TRI cyclable = bouton secondary compact.
  local sortStr = T("grimoire.sort", { mode = SORT_LABEL[self.sort[self.tab]] or "?" })
  self.sortRect = { x = LIST_X, y = SORT_Y, w = SORT_W, h = SORT_H }
  local sf = Feel.state("grim.sort")
  Button.draw(self.sortRect.x, self.sortRect.y, self.sortRect.w, self.sortRect.h, "secondary", sortStr,
    { hover = sf.hover > 0.5, feel = sf })

  -- Liste : Panel de fond (dégradé + liseré iron) sous la zone, puis lignes clippées.
  Panel.draw(LIST_X - 6, LIST_Y - 6, LIST_W + 14, listViewH() + 12, { fill = C.stone900 })
  Draw.scissor(view, LIST_X - 4, LIST_Y - 2, LIST_W + 12, listViewH() + 4)
  for i, row in ipairs(self.rows) do
    local y = LIST_Y + (i - 1) * (ROW_H + ROW_GAP) - self.scroll
    if y + ROW_H >= LIST_Y - 2 and y <= LIST_BOTTOM then self:drawRow(i, row, y) end
  end
  Draw.noScissor()

  -- Barre de défilement (thumb laiton, idiome design-system).
  local maxS = self:maxScroll()
  if maxS > 0 then
    local vh = listViewH()
    local thumbH = math.max(28, vh * vh / self:contentH())
    local ty = LIST_Y + (vh - thumbH) * (self.scroll / maxS)
    Draw.rect(LIST_X + LIST_W + 4, LIST_Y, 3, vh, C.stone900)
    Draw.rect(LIST_X + LIST_W + 4, ty, 3, thumbH, C.brass)
  end

  -- Détail (droite).
  self:drawDetail()
  Draw.finish()
end

-- Onglet = bouton SECONDARY. Actif -> forcé en état survol (le plus clair) + un éclat doré au-dessus ; inactif
-- -> état idle/survol selon Feel. Le compteur (n/total) est posé À DROITE en Space Mono (gold si actif).
function Screen:drawTab(id, label, x, n, total)
  local active = (self.tab == id)
  self._tabRects[id] = { x = x, y = TAB_Y, w = TAB_W, h = TAB_H }
  local fs = Feel.state("grim.tab." .. id)
  Button.draw(x, TAB_Y, TAB_W, TAB_H, "secondary", label, { hover = active or fs.hover > 0.5, feel = fs })
  if active then -- liseré doré (l'onglet retenu = héros léger), comme l'accent Panel
    Draw.rect(x, TAB_Y, TAB_W, TAB_H, nil, C.brass, 1)
  end
  -- compteur n/total à droite du bouton (Space Mono ; gold sur l'actif).
  Draw.textR(n .. "/" .. total, x + TAB_W - 10, TAB_Y + (TAB_H - 12) / 2 - 1,
    active and C.gold or C.ink4, Theme.labelSmall(10))
end

-- Une ligne de liste : vignette en CASE PROPRE (Slot) avec l'icône/rig reseaté (ou un « ? » Jacquard si voilé)
-- + nom Cinzel + méta Space Mono. Sélection -> Panel surligné (accent laiton) ; survol -> liseré laiton.
function Screen:drawRow(i, row, y)
  local e, on = row.e, row.on
  local sel, hov = (self.sel == i), (self.hover == i)

  -- Fond de ligne : Panel propre. Sélection = éclat haut + accent laiton ; survol = liseré laiton ; sinon plat.
  if sel then
    Panel.draw(LIST_X, y, LIST_W, ROW_H, { fill1 = C.stone800, fill2 = C.stone900, border = C.brass, accent = C.brassD })
  elseif hov then
    Panel.draw(LIST_X, y, LIST_W, ROW_H, { fill1 = C.stone850, fill2 = C.stone900, border = C.brassL, hi = false })
  else
    Panel.draw(LIST_X, y, LIST_W, ROW_H, { fill = C.stone850, border = C.iron, hi = false })
  end

  -- Vignette = CASE PROPRE Slot (38px) ; l'icône (relique) / le rig (créature) y est REASSIS, ou « ? » si voilé.
  local TH = ROW_H - 10
  local tx, ty = LIST_X + 5, y + 5
  Slot.draw(tx, ty, TH, on and "selected" or "locked",
    on and (self.tab == "bestiary" and { typePip = e.type }) or nil)
  local thumbCx, thumbCy = tx + TH / 2, ty + TH / 2
  if on then
    if self.tab == "relics" then
      drawIconC(RelicGen.cached(e.id, self.palette), thumbCx, thumbCy, 2)
    else
      drawRigC(e.char, thumbCx, ty + TH - 4, 1.5)
    end
  else
    Draw.textC("?", thumbCx, thumbCy - 11, C.lock, Theme.display(20))
  end

  -- Nom (Cinzel, voix gravée) + méta (Space Mono).
  local nameKey = (self.tab == "relics") and ("relic." .. e.id .. ".name") or ("unit." .. e.id .. ".name")
  local nx = tx + TH + 10
  Draw.text(on and T(nameKey) or T("grimoire.unknown"), nx, y + 9, on and C.ink or C.ink4, Theme.subhead(15))
  if on then
    local meta
    if self.tab == "relics" then meta = (CAT_LABEL[e.cat] or "?") .. "   T" .. e.tier
    else meta = T("type." .. e.type):upper() .. (e.rank and ("   R" .. e.rank) or "") end
    Draw.text(meta, nx, y + 29, C.ink4, Theme.labelSmall(9))
  else
    Draw.text(T(self.tab == "relics" and "grimoire.cryptic" or "grimoire.unseen"), nx, y + 29, C.ink5, Theme.labelSmall(9))
  end
end

function Screen:drawDetail()
  local row = self.rows[self.sel]
  -- Panneau de détail PROPRE. Accent de rareté (bestiaire révélé) -> liseré interne héros ; sinon nu.
  local accent
  if row and row.on and self.tab == "bestiary" and row.e.rank then
    local fr = Rarity.frame(row.e.rank)
    if fr then accent = { fr[1], fr[2], fr[3], 1 } end
  end
  local ix, iy, iw = Panel.draw(DET_X, DET_Y, DET_W, DET_H, { accent = accent })
  if not row then return end
  local e, on = row.e, row.on
  local cx = ix + iw / 2

  if self.tab == "relics" then
    -- Portrait : icône bakée reseatée dans une CASE PROPRE (Slot) centrée ; « ? » Jacquard si voilé.
    local PS = 96
    local px, py = math.floor(cx - PS / 2), DET_Y + 30
    Slot.draw(px, py, PS, on and "selected" or "locked")
    if on then
      drawIconC(RelicGen.cached(e.id, self.palette), cx, py + PS / 2, 5)
    else
      Draw.textC("?", cx, py + PS / 2 - 28, C.lock, Theme.display(56))
    end
    -- Nom (Cinzel title) + sous-titre catégorie/tier (Space Mono, gold).
    Draw.textC(on and T("relic." .. e.id .. ".name") or T("grimoire.unknown"), cx, py + PS + 14,
      on and C.ink or C.ink4, Theme.title(24))
    if on then
      Draw.textTrackedC(CAT_LABEL[e.cat] .. "   ·   TIER " .. e.tier, cx, py + PS + 48, C.gold, Theme.label(11), 1.5)
    end
    -- Séparateur de section PROPRE (le titre de bloc « KNOWN EFFECT »).
    Dividers.text(cx, DET_Y + 206, DET_W - 200, T("grimoire.effect_known"))
    if on then
      -- Effet = prose lisible (Spectral body) ; flavor = Spectral italique (loreRoman).
      Draw.textWrap(T("relic." .. e.id .. ".effect"), DET_X + 70, DET_Y + 240, DET_W - 140, C.ink, Theme.body(16), "center")
      Draw.textWrap(T("relic." .. e.id .. ".flavor"), DET_X + 70, DET_Y + 300, DET_W - 140, C.ink3, Theme.flavor(16), "center")
    else
      Draw.textWrap(T("grimoire.body_unknown"), DET_X + 70, DET_Y + 244, DET_W - 140, C.ink3, Theme.flavor(16), "center")
    end
  else
    -- Bestiaire.
    local col = TYPE_COL[e.type] or { 0.8, 0.8, 0.8 }
    -- Portrait : CASE PROPRE (Slot) ; glow de rareté additif puis le rig reseaté ; « ? » si voilé.
    local PS = 116
    local px, py = math.floor(cx - PS / 2), DET_Y + 24
    Slot.draw(px, py, PS, on and "selected" or "locked", on and { typePip = e.type } or nil)
    if on then
      if e.rank then
        local rar = Rarity.get(e.rank)
        if rar and rar.glow and rar.glow > 0 then
          love.graphics.setBlendMode("add")
          local g = Rarity.frame(e.rank)
          for k = 3, 1, -1 do
            love.graphics.setColor(g[1], g[2], g[3], rar.glow * 0.10 * k)
            love.graphics.circle("fill", cx, py + PS / 2, 40 * (k / 3))
          end
          love.graphics.setBlendMode("alpha"); love.graphics.setColor(1, 1, 1, 1)
        end
      end
      drawRigC(e.char, cx, py + PS - 8, 5)
    else
      Draw.textC("?", cx, py + PS / 2 - 28, C.lock, Theme.display(56))
    end
    -- Nom (Cinzel title) + type/rang (Space Mono dans la teinte de type).
    Draw.textC(on and T("unit." .. e.id .. ".name") or T("grimoire.unknown"), cx, py + PS + 12,
      on and C.ink or C.ink4, Theme.title(24))
    if on then
      local spec = Units[e.id] or {}
      Draw.textTrackedC(T("type." .. e.type):upper() .. (e.rank and ("   ·   RANK " .. e.rank .. "/5") or ""),
        cx, py + PS + 44, { col[1], col[2], col[3], 1 }, Theme.label(11), 1.5)
      -- Séparateur sang (cassure de section) + stats (Space Mono / valeurs).
      Dividers.blood(DET_X + 150, DET_Y + 200, DET_W - 300)
      Draw.textTrackedC(T("ui.unit_stats", { hp = spec.hp or 0, dmg = spec.dmg or 0, cd = spec.cd or 0 }),
        cx, DET_Y + 216, C.ink2, Theme.value(15), 1)
      -- Passif : nom Cinzel (heading) + prose Spectral.
      Draw.textC(T("unit." .. e.id .. ".passive_name"), cx, DET_Y + 246, C.gold, Theme.heading(15))
      Draw.textWrap(T("unit." .. e.id .. ".passive_desc"), DET_X + 70, DET_Y + 272, DET_W - 140, C.ink2, Theme.body(13), "center")

      -- PALIERS de rareté : l'échelle PROPRE Badge.rarity (R1..R5, le rang réel gildé) + la même bête aux 5
      -- rangs (échelle/glow croissants) RESEATÉE en cases propres, le rang réel surligné -> on lit le système
      -- de rareté directement sur la créature sélectionnée.
      local rk = e.rank or 1
      Dividers.text(cx, DET_Y + 326, DET_W - 240, T("grimoire.tiers"))
      Badge.rarity(cx - 180, DET_Y + 350, 360, rk, 5, 12)
      local ly = DET_Y + 408
      for k = 1, 5 do
        local rar = Rarity.get(k)
        local ccx = DET_X + DET_W * (k - 0.5) / 5
        local TS = 66
        local sx = math.floor(ccx - TS / 2)
        Slot.draw(sx, ly, TS, (k == rk) and "selected" or "empty")
        if rar.glow and rar.glow > 0 then
          local fr = Rarity.frame(k)
          love.graphics.setBlendMode("add")
          for j = 2, 1, -1 do
            love.graphics.setColor(fr[1], fr[2], fr[3], rar.glow * 0.12 * j)
            love.graphics.circle("fill", ccx, ly + TS / 2 - 6, 15 * (j / 2))
          end
          love.graphics.setBlendMode("alpha"); love.graphics.setColor(1, 1, 1, 1)
        end
        drawRigC(e.char, ccx, ly + TS - 8, 1.9 * (rar.scale or 1))
      end
    else
      Draw.textWrap(T("grimoire.beast_unknown"), DET_X + 70, DET_Y + 220, DET_W - 140, C.ink3, Theme.flavor(16), "center")
    end
  end
end

-- ── Entrées ──
function Screen:setTab(id)
  if self.tab == id then return end
  self.tab = id
  self.sel, self.scroll = 1, 0
  self:rebuildRows()
end

function Screen:cycleSort()
  local modes = SORTS[self.tab]
  local cur = self.sort[self.tab]
  local idx = 1
  for k, m in ipairs(modes) do if m == cur then idx = k end end
  self.sort[self.tab] = modes[idx % #modes + 1]
  self:rebuildRows()
end

function Screen:rowAt(dx, dy)
  if not ptIn(dx, dy, LIST_X, LIST_Y, LIST_W, listViewH()) then return nil end
  local rel = dy - LIST_Y + self.scroll
  local i = math.floor(rel / (ROW_H + ROW_GAP)) + 1
  if i >= 1 and i <= #self.rows then
    local within = rel - (i - 1) * (ROW_H + ROW_GAP)
    if within <= ROW_H then return i end
  end
  return nil
end

function Screen:mousemoved(vx, vy)
  self.mx, self.my = vx * 4, vy * 4
  self.hover = self:rowAt(self.mx, self.my)
end

function Screen:mousepressed(vx, vy, button)
  if button ~= 1 then return end
  local dx, dy = vx * 4, vy * 4
  self.mx, self.my = dx, dy
  if self.backRect and ptIn(dx, dy, self.backRect.x, self.backRect.y, self.backRect.w, self.backRect.h) then
    Feel.press("grim.back"); self.host.goto("menu"); return
  end
  if self._tabRects then
    for id, r in pairs(self._tabRects) do
      if ptIn(dx, dy, r.x, r.y, r.w, r.h) then Feel.press("grim.tab." .. id); self:setTab(id); return end
    end
  end
  if self.sortRect and ptIn(dx, dy, self.sortRect.x, self.sortRect.y, self.sortRect.w, self.sortRect.h) then
    Feel.press("grim.sort"); self:cycleSort(); return
  end
  local i = self:rowAt(dx, dy)
  if i then self.sel = i end
end

function Screen:wheelmoved(_, dy)
  self.scroll = self.scroll - (dy or 0) * 36
  local m = self:maxScroll()
  if self.scroll < 0 then self.scroll = 0 elseif self.scroll > m then self.scroll = m end
end

function Screen:keypressed(key)
  if key == "up" then self.sel = math.max(1, (self.sel or 1) - 1); self:ensureVisible()
  elseif key == "down" then self.sel = math.min(#self.rows, (self.sel or 1) + 1); self:ensureVisible()
  elseif key == "tab" or key == "left" or key == "right" then self:setTab(self.tab == "relics" and "bestiary" or "relics")
  elseif key == "s" then self:cycleSort()
  elseif key == "g" or key == "escape" then self.host.goto("menu") end
end

-- Garde la sélection dans le viewport (auto-scroll).
function Screen:ensureVisible()
  local top = (self.sel - 1) * (ROW_H + ROW_GAP)
  local bot = top + ROW_H
  if top < self.scroll then self.scroll = top
  elseif bot > self.scroll + listViewH() then self.scroll = bot - listViewH() end
end

return Screen
