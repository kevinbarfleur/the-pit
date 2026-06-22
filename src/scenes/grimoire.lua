-- src/scenes/grimoire.lua
-- LE GRIMOIRE — codex/COLLECTION persistant, désormais à DEUX ONGLETS : RELIQUES + BESTIAIRE. Une entrée
-- RENCONTRÉE (relique inscrite : Grimoire.isKnown ; créature vue : Bestiary.isSeen) s'y dévoile à vie au
-- niveau du compte (méta-progression). Les non rencontrées restent voilées (« ??? ») — sauf MODE DEV
-- full-unlock (read-time). Tri cyclable (reliques : catégorie/tier/nom ; créatures : type/rang/nom).
--
-- Couche RENDER (love.graphics) en ESPACE DESIGN 1280x720 : liste scrollable (clip Draw.scissor + molette)
-- à gauche, détail à droite. Vignettes : icône bakée (RelicGen) pour les reliques, rig (Rig.draw scalé)
-- pour les créatures — construits une fois (mémoïsé par le host), refresh() relit l'état connu/vu.
-- daChrome=true. [esc]/[g] -> retour menu (géré par main).

local Theme = require("src.ui.theme")
local Draw = require("src.ui.draw")
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

-- Teinte d'accent par type de créature (réutilise la convention galerie).
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

-- Mise en page (espace design).
local TITLE_Y = 30
local TAB_Y, TAB_W, TAB_H = 86, 168, 30
local SORT_Y = 126
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
    ambient = Ambient.new(5),
  }, Screen)

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
      or CreatureGen.cached({ id = id, type = spec.type, effects = spec.effects, bodyplan = spec.bodyplan, rank = spec.rank })
    local char = Rig.new(def, palette); char.facing = 1
    self.beastEntries[#self.beastEntries + 1] = {
      id = id, char = char, type = spec.type or "flesh", rank = spec.rank, bodyplan = spec.bodyplan,
    }
  end

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
  local c = Theme.c
  Draw.begin(view)

  -- En-tête + onglets.
  Draw.text(T("grimoire.title"), LIST_X, TITLE_Y, c.title, Theme.display(40))
  self:drawTab("relics", T("grimoire.tab_relics"), LIST_X, self.knownRelics, #self.relicEntries)
  self:drawTab("bestiary", T("grimoire.tab_bestiary"), LIST_X + TAB_W + 10, self.seenBeasts, #self.beastEntries)
  Draw.textR(T("grimoire.back"), Draw.W - 32, 40, c.ghost, Theme.ui(11))

  -- Puce de tri (cyclable).
  local sortStr = T("grimoire.sort", { mode = SORT_LABEL[self.sort[self.tab]] or "?" })
  self.sortRect = { x = LIST_X, y = SORT_Y, w = 200, h = 22 }
  local sr = self.sortRect
  Draw.rect(sr.x, sr.y, sr.w, sr.h, c.panelDeep, c.hair, 1)
  Draw.text(sortStr, sr.x + 10, sr.y + 5, c.faint, Theme.ui(10))

  -- Liste scrollable (clip au viewport -> aucun débordement hors conteneur).
  Draw.scissor(view, LIST_X - 4, LIST_Y - 2, LIST_W + 12, listViewH() + 4)
  for i, row in ipairs(self.rows) do
    local y = LIST_Y + (i - 1) * (ROW_H + ROW_GAP) - self.scroll
    if y + ROW_H >= LIST_Y - 2 and y <= LIST_BOTTOM then self:drawRow(i, row, y) end
  end
  Draw.noScissor()

  -- Barre de défilement (si nécessaire).
  local maxS = self:maxScroll()
  if maxS > 0 then
    local vh = listViewH()
    local thumbH = math.max(24, vh * vh / self:contentH())
    local ty = LIST_Y + (vh - thumbH) * (self.scroll / maxS)
    Draw.rect(LIST_X + LIST_W + 2, LIST_Y, 3, vh, c.panelDeep)
    Draw.rect(LIST_X + LIST_W + 2, ty, 3, thumbH, c.ecoBorder)
  end

  -- Détail (droite).
  self:drawDetail(c)
  Draw.finish()
end

function Screen:drawTab(id, label, x, n, total)
  local c = Theme.c
  local active = (self.tab == id)
  if not self._tabRects then self._tabRects = {} end
  self._tabRects[id] = { x = x, y = TAB_Y, w = TAB_W, h = TAB_H }
  Draw.rect(x, TAB_Y, TAB_W, TAB_H, active and c.panel or c.panelDeep, active and c.gold or c.line, active and 2 or 1)
  Draw.text(label, x + 12, TAB_Y + 5, active and c.title or c.muted, Theme.uiBold(13))
  Draw.textR(n .. "/" .. total, x + TAB_W - 10, TAB_Y + 8, active and c.goldBright or c.fainter, Theme.ui(10))
end

-- Une ligne de liste : vignette (icône/rig si révélé, sinon « ? ») + nom + méta. Sélection/survol surlignés.
function Screen:drawRow(i, row, y)
  local c = Theme.c
  local e, on = row.e, row.on
  local sel, hov = (self.sel == i), (self.hover == i)
  Draw.rect(LIST_X, y, LIST_W, ROW_H, sel and c.panel or c.panelDeep, sel and c.gold or (hov and c.ecoBorder or c.line), 1)
  local thumbCx = LIST_X + 28
  if on then
    if self.tab == "relics" then
      drawIconC(RelicGen.cached(e.id, self.palette), thumbCx, y + ROW_H / 2, 2)
    else
      drawRigC(e.char, thumbCx, y + ROW_H - 8, 1.6)
    end
  else
    Draw.textC("?", thumbCx, y + ROW_H / 2 - 9, c.lock, Theme.display(22))
  end
  -- Nom + méta.
  local nameKey = (self.tab == "relics") and ("relic." .. e.id .. ".name") or ("unit." .. e.id .. ".name")
  Draw.text(on and T(nameKey) or T("grimoire.unknown"), LIST_X + 56, y + 9, on and c.title or c.fainter, Theme.ui(12))
  if on then
    local meta
    if self.tab == "relics" then meta = (CAT_LABEL[e.cat] or "?") .. "   T" .. e.tier
    else meta = T("type." .. e.type):upper() .. (e.rank and ("   R" .. e.rank) or "") end
    Draw.text(meta, LIST_X + 56, y + 27, c.fainter, Theme.ui(9))
  else
    Draw.text(T(self.tab == "relics" and "grimoire.cryptic" or "grimoire.unseen"), LIST_X + 56, y + 27, c.ghost, Theme.ui(9))
  end
end

function Screen:drawDetail(c)
  Draw.rect(DET_X, DET_Y, DET_W, DET_H, c.panelDeep, c.hair, 1)
  local row = self.rows[self.sel]
  if not row then return end
  local e, on = row.e, row.on
  local cx = DET_X + DET_W / 2

  if self.tab == "relics" then
    local col = c.gold
    if on and drawIconC(RelicGen.cached(e.id, self.palette), cx, DET_Y + 78, 5) then else
      Draw.textC("?", cx, DET_Y + 60, c.lock, Theme.display(56))
    end
    Draw.textC(on and T("relic." .. e.id .. ".name") or T("grimoire.unknown"), cx, DET_Y + 128,
      on and c.title or c.fainter, Theme.uiBold(22))
    if on then
      Draw.textC(CAT_LABEL[e.cat] .. "  -  TIER " .. e.tier, cx, DET_Y + 156, col, Theme.ui(10))
    end
    Draw.divider(cx, DET_Y + 184, 300, c.fainter, 1)
    if on then
      Draw.textWrap(T("relic." .. e.id .. ".effect"), DET_X + 60, DET_Y + 206, DET_W - 120, c.goldBright, Theme.ui(14), "center")
      Draw.textWrap(T("relic." .. e.id .. ".flavor"), DET_X + 60, DET_Y + 260, DET_W - 120, c.dim, Theme.loreRoman(16), "center")
    else
      Draw.textWrap(T("grimoire.body_unknown"), DET_X + 60, DET_Y + 220, DET_W - 120, c.dim, Theme.loreRoman(16), "center")
    end
  else
    -- Bestiaire.
    local col = TYPE_COL[e.type] or { 0.8, 0.8, 0.8 }
    if on then
      if e.rank then
        local rar = Rarity.get(e.rank)
        if rar and rar.glow and rar.glow > 0 then
          love.graphics.setBlendMode("add")
          local g = Rarity.frame(e.rank)
          for k = 3, 1, -1 do
            love.graphics.setColor(g[1], g[2], g[3], rar.glow * 0.10 * k)
            love.graphics.circle("fill", cx, DET_Y + 90, 40 * (k / 3))
          end
          love.graphics.setBlendMode("alpha"); love.graphics.setColor(1, 1, 1, 1)
        end
      end
      drawRigC(e.char, cx, DET_Y + 120, 5)
    else
      Draw.textC("?", cx, DET_Y + 64, c.lock, Theme.display(56))
    end
    Draw.textC(on and T("unit." .. e.id .. ".name") or T("grimoire.unknown"), cx, DET_Y + 150,
      on and c.title or c.fainter, Theme.uiBold(22))
    if on then
      local spec = Units[e.id] or {}
      Draw.textC(T("type." .. e.type):upper() .. (e.rank and ("   -   RANK " .. e.rank .. "/5") or ""),
        cx, DET_Y + 178, { col[1], col[2], col[3], 1 }, Theme.ui(10))
      Draw.divider(cx, DET_Y + 204, 300, c.fainter, 1)
      Draw.textC(T("ui.unit_stats", { hp = spec.hp or 0, dmg = spec.dmg or 0, cd = spec.cd or 0 }),
        cx, DET_Y + 224, c.muted, Theme.ui(13))
      Draw.textC(T("unit." .. e.id .. ".passive_name"), cx, DET_Y + 254, c.goldBright, Theme.ui(12))
      Draw.textWrap(T("unit." .. e.id .. ".passive_desc"), DET_X + 60, DET_Y + 278, DET_W - 120, c.body, Theme.ui(12), "center")
      -- PALIERS : la même bête aux 5 rangs de rareté (échelle/glow/cadre/pips croissants). Le rang réel de
      -- l'unité est surligné -> on lit le système de rareté directement sur la créature sélectionnée.
      local ly = DET_Y + 452
      Draw.textC(T("grimoire.tiers"), cx, ly - 22, c.muted, Theme.uiBold(11))
      for k = 1, 5 do
        local rar = Rarity.get(k)
        local fr = Rarity.frame(k)
        local ccx = DET_X + DET_W * (k - 0.5) / 5
        local feet = ly + 48
        if rar.glow and rar.glow > 0 then
          love.graphics.setBlendMode("add")
          for j = 2, 1, -1 do
            love.graphics.setColor(fr[1], fr[2], fr[3], rar.glow * 0.12 * j)
            love.graphics.circle("fill", ccx, feet - 20, 15 * (j / 2))
          end
          love.graphics.setBlendMode("alpha"); love.graphics.setColor(1, 1, 1, 1)
        end
        love.graphics.setColor(fr[1], fr[2], fr[3], (k == (e.rank or 1)) and 0.95 or 0.4)
        love.graphics.rectangle("line", ccx - 26, ly - 6, 52, 66)
        love.graphics.setColor(1, 1, 1, 1)
        drawRigC(e.char, ccx, feet, 1.9 * (rar.scale or 1))
        love.graphics.setColor(fr[1], fr[2], fr[3], 0.95)
        for p = 1, k do love.graphics.rectangle("fill", ccx - 12 + (p - 1) * 5, ly + 54, 3, 3) end
        love.graphics.setColor(1, 1, 1, 1)
      end
    else
      Draw.textWrap(T("grimoire.beast_unknown"), DET_X + 60, DET_Y + 200, DET_W - 120, c.dim, Theme.loreRoman(16), "center")
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
  self.hover = self:rowAt(vx * 4, vy * 4)
end

function Screen:mousepressed(vx, vy, button)
  if button ~= 1 then return end
  local dx, dy = vx * 4, vy * 4
  if self._tabRects then
    for id, r in pairs(self._tabRects) do
      if ptIn(dx, dy, r.x, r.y, r.w, r.h) then self:setTab(id); return end
    end
  end
  if self.sortRect and ptIn(dx, dy, self.sortRect.x, self.sortRect.y, self.sortRect.w, self.sortRect.h) then
    self:cycleSort(); return
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
