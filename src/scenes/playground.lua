-- src/scenes/playground.lua
-- THE PROVING GROUND (Pilier A du banc d'essai) : choisir un SCÉNARIO (équipe A vs équipe B figées),
-- VOIR les deux compositions sur leur sigil AVANT de lancer, puis :
--   · WATCH  -> rejoue le match dans la vraie scène de combat (spectateur), retour ici (onFinish).
--   · SIM xN -> batch headless (runMatch ×N, seeds variés) étalé sur les frames -> win% + part décidée.
--
-- PRINCIPE (cf. l'user) : « le win% seul ne veut rien dire ». Chaque compo affiche son SCORE
-- D'INVESTISSEMENT (compcost) à côté de son aperçu -> le win% se lit TOUJOURS en regard du coût.
-- Counters designés (poison/rot > tank…) = attendus, pas des bugs.
--
-- Couche RENDER/scène (DA) : atmosphère en pre-pass (drawBack), UI native en overlay (drawOverlay) en
-- ESPACE DESIGN 1280x720. Aucun monde pixel (les compos sont dessinées en PIPS de type). daChrome=true.
--
-- CHROME = KIT PROPRE (.dc.html / design-system) : aligné sur build/grimoire/designsystem. Plus de
-- panneaux/boutons dessinés à la main -> on réutilise les ATOMES : Panel (surfaces A/B), Button (WATCH
-- primary + SIM eco, avec Feel), Dividers (en-têtes de section), Draw.bar (barres d'investissement/SIM).
-- Le texte passe par les voix Theme (Cinzel titres / Spectral prose / Space Mono labels & valeurs).

local Theme = require("src.ui.theme")
local Draw = require("src.ui.draw")
local Panel = require("src.ui.panel")       -- surface propre (dégradé + liseré iron + éclat) : A/B + scénarios
local Button = require("src.ui.button")     -- boutons propres : primary (WATCH) / eco (SIM)
local Nav = require("src.ui.nav")            -- bouton retour homogène (règle de navigation)
local Dividers = require("src.ui.dividers")  -- séparateurs laiton/sang (en-têtes de blocs)
local Feel = require("src.ui.feel")          -- JUICE : survol (glow/lift) + press (squash/flash)
local Ambient = require("src.fx.ambient")
local Units = require("src.data.units")
local Shapes = require("src.board.shapes")
local Board = require("src.board.board") -- Board.shapeName : résout l'affichage des sigils (en PAUSE -> carré)
local Compositions = require("src.data.compositions")
local Compbuild = require("src.lab.compbuild")
local Compcost = require("src.lab.compcost")
local Match = require("src.combat.match")
local Bossrush = require("src.lab.bossrush")
local Abominations = require("src.data.abominations")
local T = require("src.core.i18n").t
local C = Theme.c

local Playground = {}
Playground.__index = Playground

-- Hit-test point-dans-rect (espace design). Module-local (déclaré tôt : update() s'en sert pour le survol
-- des boutons WATCH/SIM, avant les hit-tests souris plus bas).
local function inRect(x, y, r) return x >= r.x and x <= r.x + r.w and y >= r.y and y <= r.y + r.h end

local SIM_N = 200          -- nb de matchs par batch SIM
local SIM_PER_FRAME = 10   -- matchs joués par frame (étalé -> pas de gel)

-- Mise en page (espace design 1280x720).
local LIST_X, LIST_W, ROW_H, ROW_GAP = 28, 300, 46, 6
local LIST_STEP = ROW_H + ROW_GAP               -- 52 px par ligne
local LIST_BOTTOM = 518                          -- bas du conteneur scrollable (aligne sur le bas des panneaux : PANEL_Y+PANEL_H)
local FILTER_Y, CHIP_H, CHIP_PAD, CHIP_GAP = 92, 20, 9, 5 -- filtre : chips cliquables (archetypes + tags), wrap multi-rangs
local AX, BX, PANEL_Y, PANEL_W, PANEL_H = 356, 818, 122, 408, 396
local BTN_W, BTN_GAP = 200, 16
local BTN_Y, BTN_H = 540, 54
-- listY / listViewH / listVisible sont CALCULES (layoutChips) : la liste commence sous la derniere rangee de
-- chips et garde son bas aligne sur LIST_BOTTOM -> le filtre peut occuper 1, 2 ou 3 rangs sans chevauchement.

local function isBossScenario(sc)
  return sc and (sc.kind == "bossrush" or sc.boss ~= nil)
end

local function bossName(key)
  if not key then return T("bossrush.no_boss") end
  return T("bossrush.abomination." .. tostring(key) .. ".name")
end

local function colorFromAccent(hex, fallback)
  if type(hex) ~= "string" then return fallback end
  local raw = hex:match("^#?([%da-fA-F][%da-fA-F][%da-fA-F][%da-fA-F][%da-fA-F][%da-fA-F])$")
  if not raw then return fallback end
  local n = tonumber(raw, 16)
  if not n then return fallback end
  return Theme.hex(n)
end

local function effectColor(op)
  if op == "burn" or op == "spread_burn_on_death" then return C.burn end
  if op == "poison" then return C.poison end
  if op == "bleed" then return C.bleed end
  if op == "rot" then return C.rot end
  if op == "shock" then return C.shock end
  if op == "regen" or op == "lifesteal" then return C.regen end
  if op == "thorns" or op == "execute" or op == "percent_hp_strike" then return C.bloodL end
  if op == "grant_vuln" then return C.ember end
  if op == "grant_team" then return C.gold end
  if op == "summon" then return C.brassS end
  return C.ink3
end

local function opLabel(op)
  local key = "bossrush.op." .. tostring(op or "attack")
  local v = T(key)
  if v ~= key then return v end
  return string.upper(tostring(op or "attack"):gsub("_", " "))
end

local function primaryThreat(spec)
  if not spec then return T("bossrush.op.attack"), C.ink3 end
  if spec.taunt then return T("bossrush.op.taunt"), C.gold end
  if (spec.shield or 0) > 0 then return T("bossrush.op.shield"), C.shield end
  if (spec.dmgReduce or 0) > 0 then return T("bossrush.op.armor"), C.steel end
  for _, e in ipairs(spec.effects or {}) do
    if e and e.op then return opLabel(e.op), effectColor(e.op) end
  end
  return T("bossrush.op.attack"), C.ink3
end

local function drawThreatTag(x, y, label, color, w)
  w = w or math.max(78, Theme.labelSmall(9):getWidth(label) + 22)
  Draw.rect(x, y, w, 22, { C.stone900[1], C.stone900[2], C.stone900[3], 0.72 }, color, 1)
  Draw.rect(x, y, 3, 22, color)
  Draw.textC(label, x + w / 2 + 2, y + 5, color, Theme.labelSmall(9))
  return w
end

function Playground.new(palette, vw, vh, host)
  local self = setmetatable({
    palette = palette, vw = vw, vh = vh, host = host,
    daChrome = true, titleKey = "pg.title", hintKey = "ui.hint_playground",
    t = 0, ambient = Ambient.new(3),
    allScenarios = Compositions.scenarios, -- master (immuable)
    scenarios = Compositions.scenarios,    -- VUE courante (= master filtre par categorie ; toutes les fonctions liste s'en servent)
    filter = "all",
    sel = 0, hover = nil, scroll = 0,
    mx = -100, my = -100,
    compA = nil, compB = nil, costA = nil, costB = nil,
    result = nil, sim = nil,
  }, Playground)
  self:buildChips() -- chips presentes (archetypes + tags) dans les scenarios
  self:layoutChips() -- positions des chips (wrap) + geometrie de la liste sous le filtre
  self:select(1)
  Feel.reset() -- repart au repos (survol/press vierges) en (re)entrant dans la scène
  return self
end

-- ── Filtre (chips). DEUX facettes en selection unique : ARCHETYPE (famille de combat, A ou B) et TAG
-- (theme transversal : transmission, combo croise, vitrine VFX...). La VUE est self.scenarios (= master
-- filtre) -> toute la logique liste (select/scroll/souris/clavier) marche telle quelle. Cle composite
-- "all" | "arch:<x>" | "tag:<x>" -> aucune ambiguite famille/theme. ──
function Playground:buildChips()
  local present, tagSeen = {}, {}
  for _, sc in ipairs(self.allScenarios) do
    local a, b = Compositions.byId[sc.a], Compositions.byId[sc.b]
    if a then present[a.archetype] = true end
    if b and not isBossScenario(sc) then present[b.archetype] = true end
    if sc.tags then for _, tg in ipairs(sc.tags) do tagSeen[tg] = true end end
  end
  self.chips = { { key = "all", label = T("pg.filter.all") } }
  for _, arch in ipairs(Compositions.archetypes) do -- familles, dans l'ordre canonique
    if present[arch] then self.chips[#self.chips + 1] = { key = "arch:" .. arch, kind = "arch", label = T("pg.archetype." .. arch) } end
  end
  for _, tg in ipairs(Compositions.tags or {}) do -- themes, dans l'ordre canonique (ceux presents)
    if tagSeen[tg] then self.chips[#self.chips + 1] = { key = "tag:" .. tg, kind = "tag", label = T("pg.tag." .. tg) } end
  end
end

-- Place les chips en rangs qui s'enroulent dans LIST_W, PUIS positionne la liste juste dessous.
function Playground:layoutChips()
  local font = Theme.label(10) -- Space Mono (voix inscrite) : libellés courts de filtre
  self.chipRects = {}
  local x, y = LIST_X, FILTER_Y
  for _, ch in ipairs(self.chips) do
    local w = (font and font:getWidth(ch.label) or #ch.label * 6) + CHIP_PAD * 2
    if x > LIST_X and x + w > LIST_X + LIST_W then x = LIST_X; y = y + CHIP_H + CHIP_GAP end
    self.chipRects[#self.chipRects + 1] = { key = ch.key, kind = ch.kind, label = ch.label, x = x, y = y, w = w, h = CHIP_H }
    x = x + w + CHIP_GAP
  end
  -- La liste commence sous la derniere rangee de chips ; son bas reste aligne sur les panneaux.
  self.listY = y + CHIP_H + 16
  self.listViewH = math.max(LIST_STEP, LIST_BOTTOM - self.listY)
  self.listVisible = math.max(1, math.floor(self.listViewH / LIST_STEP))
end

-- Filtre la vue. "all" -> master ; "arch:<x>" -> A ou B a cet archetype ; "tag:<x>" -> le scenario porte
-- ce tag. Re-selectionne le 1er.
function Playground:rebuildView()
  if self.filter == "all" then
    self.scenarios = self.allScenarios
  else
    local kind, val = self.filter:match("^(%a+):(.+)$")
    local v = {}
    for _, sc in ipairs(self.allScenarios) do
      local keep = false
      if kind == "arch" then
        local a, b = Compositions.byId[sc.a], Compositions.byId[sc.b]
        keep = (a and a.archetype == val) or (b and not isBossScenario(sc) and b.archetype == val)
      elseif kind == "tag" and sc.tags then
        for _, tg in ipairs(sc.tags) do if tg == val then keep = true; break end end
      end
      if keep then v[#v + 1] = sc end
    end
    self.scenarios = v
  end
  self.scroll = 0
  self.sel = 0
  self:select(1)
end

function Playground:setFilter(cat)
  if cat == self.filter then return end
  self.filter = cat
  self:rebuildView()
end

-- Sélectionne un scénario : matérialise les 2 compos (auras résolues) + leurs coûts. Réutilisées
-- ensuite par WATCH et SIM (l'arène ne mute pas les compos -> sûr sur N matchs).
function Playground:select(i)
  if i == self.sel then return end
  local sc = self.scenarios[i]
  if not sc then return end
  self.sel = i
  self:ensureVisible(i)
  self.cA = Compositions.byId[sc.a]
  self.cB = (not isBossScenario(sc)) and Compositions.byId[sc.b] or nil
  self.compA = Compbuild.toComp(self.cA, -1)
  self.boss = isBossScenario(sc) and Abominations.byKey[sc.boss] or nil
  if self.boss then self.compB = Bossrush.toComp(self.boss, 1)
  elseif self.cB then self.compB = Compbuild.toComp(self.cB, 1)
  else self.compB = nil end
  self.costA = Compcost.of(self.cA)
  self.costB = self.cB and Compcost.of(self.cB) or nil
  self.result, self.sim = nil, nil
end

-- INSPECT-then-fight : ouvre le BUILD VERROUILLÉ (compo A posée, hover/auras/fiche actifs) ; son bouton FIGHT
-- lance le combat A vs B, dont onFinish rend la main ICI (résultat WATCH). cf. main.lua host.goto("inspect").
function Playground:startWatch()
  local sc = self.scenarios[self.sel]
  if not (sc and self.compA) then return end
  if isBossScenario(sc) then
    if not self.boss then return end
    local pg = self
    self.host.goto("bossrush", {
      left = self.compA,
      bossKey = sc.boss,
      seed = sc.seed,
      source = "playground",
      onFinish = function(result)
        pg.result = { kind = "boss_watch", result = result }
        pg.host.goto("playground")
      end,
    })
    return
  end
  if not self.compB then return end
  local pg = self
  self.host.goto("inspect", {
    composition = self.cA, -- compo BRUTE (sigil + units/slots/levels) à poser pour l'inspection
    fight = {
      left = self.compA, right = self.compB, seed = sc.seed, enemyKey = "exhibition",
      onFinish = function(win)
        pg.result = { kind = "watch", win = win }
        pg.host.goto("playground")
      end,
    },
  })
end

function Playground:startSim()
  if not self.compA or self.sim then return end
  local sc = self.scenarios[self.sel]
  if not sc then return end
  if isBossScenario(sc) then
    if not self.boss then return end
    self.sim = {
      kind = "bossrush",
      n = SIM_N,
      done = 0,
      seed = sc.seed,
      score = 0,
      clears = 0,
      fullWindows = 0,
      survived = 0,
      bossKills = 0,
    }
  elseif self.compB then
    self.sim = { kind = "match", n = SIM_N, done = 0, wins = 0, decided = 0, seed = sc.seed }
  else
    return
  end
  self.result = nil
end

-- Rects (espace design) des deux boutons (WATCH primary | SIM eco) — source unique pour rendu ET hit-test.
function Playground:watchRect() return { x = AX, y = BTN_Y, w = BTN_W, h = BTN_H } end
function Playground:simRect() return { x = AX + BTN_W + BTN_GAP, y = BTN_Y, w = BTN_W, h = BTN_H } end

function Playground:update(dt)
  self.t = self.t + (dt or 1)
  self.ambient:update(dt)
  Feel.update(dt) -- avance survol/press (RENDER pur ; aucune action différée ici)
  local wr, sr = self:watchRect(), self:simRect()
  Feel.hover("pg.watch", inRect(self.mx, self.my, wr))
  Feel.hover("pg.sim", (not self.sim) and inRect(self.mx, self.my, sr) or false)
  if self.sim then
    local s, k = self.sim, 0
    while s.done < s.n and k < SIM_PER_FRAME do
      if s.kind == "bossrush" then
        local sc = self.scenarios[self.sel]
        local res = Bossrush.run(self.compA, sc and sc.boss, s.seed + s.done, { scoreTicks = 8 * 60, tickCap = 60 * 60 })
        s.score = s.score + (res.boss_score_damage or 0)
        if res.cleared_blockers then s.clears = s.clears + 1 end
        if res.survived_score_window then s.fullWindows = s.fullWindows + 1 end
        if res.survived then s.survived = s.survived + 1 end
        if res.boss_killed then s.bossKills = s.bossKills + 1 end
      else
        local res = Match.run(self.compA, self.compB, s.seed + s.done, {})
        if res.win then s.wins = s.wins + 1 end
        if res.decided then s.decided = s.decided + 1 end
      end
      s.done = s.done + 1; k = k + 1
    end
    if s.done >= s.n then
      if s.kind == "bossrush" then
        self.result = {
          kind = "boss_sim",
          n = s.n,
          avgScore = s.score / math.max(1, s.n),
          clears = s.clears,
          fullWindows = s.fullWindows,
          survived = s.survived,
          bossKills = s.bossKills,
        }
      else
        self.result = { kind = "sim", n = s.n, wins = s.wins, decided = s.decided }
      end
      self.sim = nil
    end
  end
end

function Playground:drawBack(view)
  Draw.begin(view)
  self.ambient:draw("build") -- atmosphère calme (on inspecte, on ne se bat pas)
  Draw.finish()
end

function Playground:drawWorld() end -- aucun monde pixel (compos dessinées en pips, espace design)

-- ── Aperçu d'une composition sur son sigil (pips de type + niveau + investissement) ──
local function shapeBounds(shape)
  local minX, maxX, minY, maxY = math.huge, -math.huge, math.huge, -math.huge
  for _, c in ipairs(shape.cells) do
    if c.x < minX then minX = c.x end; if c.x > maxX then maxX = c.x end
    if c.y < minY then minY = c.y end; if c.y > maxY then maxY = c.y end
  end
  return minX, maxX, minY, maxY
end

-- Carte d'aperçu d'une compo : SURFACE PROPRE (Panel.draw : dégradé + liseré iron + éclat) — accent doré
-- quand ce côté a remporté un WATCH (le liseré héros de la rareté). Le contenu (titre Cinzel, sigil en pips,
-- barre d'investissement Space Mono) se pose à l'intérieur du rect renvoyé par Panel.
function Playground:drawComp(comp, resolved, cost, px, py, pw, ph, won)
  local ix, iy, iw = Panel.draw(px, py, pw, ph, { accent = won and C.gold or nil })

  -- Titre : archétype — variant (Cinzel gravée, la voix des noms) + sigil (Space Mono, inscrite).
  local titleStr = T("pg.archetype." .. comp.archetype) .. "  -  " .. T("pg.variant." .. comp.variant)
  Draw.textC(titleStr, ix + iw / 2, iy + 12, C.ink, Theme.subhead(16))
  Draw.textC(T("shape." .. Board.shapeName(comp.sigil) .. ".label"), ix + iw / 2, iy + 34, C.ink4, Theme.label(10))

  -- Grille du sigil : cases vides en points ténus, unités en pips colorés par type + nom. (Sigils en PAUSE -> carré.)
  local shape = Shapes[Board.shapeName(comp.sigil)]
  local gx, gy, gw, gh = px + 54, py + 64, pw - 108, ph - 184
  local minX, maxX, minY, maxY = shapeBounds(shape)
  local function cellPx(cell)
    local rx = (maxX > minX) and (cell.x - minX) / (maxX - minX) or 0.5
    local ry = (maxY > minY) and (cell.y - minY) / (maxY - minY) or 0.5
    return gx + rx * gw, gy + ry * gh
  end
  for _, cell in ipairs(shape.cells) do
    local cx, cy = cellPx(cell)
    Draw.setColor(C.edgeIdle); love.graphics.circle("fill", cx, cy, 2)
  end
  local used = {}
  for _, u in ipairs(comp.units) do used[u.slot] = u end
  for _, u in ipairs(comp.units) do
    local cell = shape.cells[u.slot]
    local cx, cy = cellPx(cell)
    local ut = Units[u.id]
    Draw.pip(ut and ut.type or "bone", cx, cy, 9)
    Draw.textC(T("unit." .. u.id .. ".name"), cx, cy + 12, C.ink3, Theme.label(8))
    if (u.level or 1) > 1 then -- pips de niveau (or)
      for p = 1, (u.level - 1) do
        Draw.setColor(C.brassS); love.graphics.circle("fill", cx - 6 + p * 6, cy - 13, 1.6)
      end
    end
  end

  -- Investissement : séparateur de bloc + barre de score + or (le contexte qui rend le win% lisible).
  local iyv = py + ph - 60
  Dividers.text(px + pw / 2, iyv, pw - 36, T("pg.invest"))
  Draw.bar(px + 18, iyv + 22, pw - 36, 8, cost.score, C.gold, C.ecoBg, C.brass)
  Draw.textR(T("pg.gold", { n = cost.gold }), px + pw - 18, iyv + 34, C.ink3, Theme.label(10))
end

function Playground:drawBossPreview(abom, px, py, pw, ph, won)
  local accent = colorFromAccent(abom and abom.accent, C.bloodL)
  local ix, iy, iw, ih = Panel.draw(px, py, pw, ph, { accent = won and C.gold or accent })

  Draw.textC(bossName(abom and abom.key), ix + iw / 2, iy + 12, C.ink, Theme.subhead(17))
  local family = string.upper(tostring((abom and abom.theme) or "-"))
  Draw.textC(T("bossrush.family", { family = family }), ix + iw / 2, iy + 35, C.ink4, Theme.label(10))

  local boss = abom and abom.boss or nil
  local bx, by, bw, bh = ix + 22, iy + 64, iw - 44, 82
  Draw.rect(bx, by, bw, bh, { C.stone900[1], C.stone900[2], C.stone900[3], 0.70 }, C.iron, 1)
  Draw.rect(bx, by, 4, bh, accent)
  Draw.textTrackedL(T("bossrush.boss_role"), bx + 16, by + 12, accent, Theme.labelSmall(9), 1.1)
  Draw.text(T("pg.boss_stats", {
    hp = tostring(boss and boss.hp or "-"),
    dmg = tostring(boss and boss.dmg or "-"),
    cd = string.format("%.1fs", ((boss and boss.cd or 0) / 60)),
  }), bx + 16, by + 36, C.ink, Theme.value(13))
  local label, col = primaryThreat(boss)
  drawThreatTag(bx + bw - 112, by + 31, label, col, 92)

  Dividers.text(ix + iw / 2, iy + 174, iw - 42, T("pg.boss_generals"))
  local gy = iy + 198
  for i = 1, 3 do
    local spec = abom and abom.generals and abom.generals[i] or nil
    local glabel, gcol = primaryThreat(spec)
    local y = gy + (i - 1) * 38
    Draw.rect(ix + 22, y, iw - 44, 30, { C.stone900[1], C.stone900[2], C.stone900[3], 0.50 }, C.brassD, 1)
    Draw.rect(ix + 22, y, 4, 30, gcol)
    Draw.textTrackedL(T("bossrush.general_n", { n = i }), ix + 36, y + 7, C.ink3, Theme.labelSmall(8), 1.0)
    drawThreatTag(ix + iw - 132, y + 4, glabel, gcol, 94)
  end

  local hy = py + ph - 82
  Dividers.text(px + pw / 2, hy, pw - 36, T("pg.boss_rule"))
  Draw.textWrap(T("pg.boss_preview_hint"), px + 22, hy + 22, pw - 44, C.ink3, Theme.body(11), "center")
end

function Playground:drawOverlay(view)
  Draw.begin(view)

  -- En-tête (titre gothique cérémonial, comme le Grimoire) + sous-titre Spectral lisible.
  Draw.text(T("pg.title"), LIST_X, 24, C.ink, Theme.display(40))
  Draw.text(T("pg.subtitle"), LIST_X + 2, 78, C.ink3, Theme.body(13))

  -- Filtre : rang(s) de chips cliquables (surfaces propres). Famille active = liseré d'or ; thème (tag)
  -- actif = liseré de sang (lecture « familles | thèmes »). Inactif = pierre + liseré iron net.
  for _, ch in ipairs(self.chipRects) do
    local on = (self.filter == ch.key)
    local accent = (ch.kind == "tag") and C.blood or C.gold
    if on then
      Panel.draw(ch.x, ch.y, ch.w, ch.h, { fill1 = C.stone700, fill2 = C.stone800, border = accent, accent = accent })
    else
      Panel.draw(ch.x, ch.y, ch.w, ch.h, { fill1 = C.stone850, fill2 = C.stone900, border = C.iron, hi = false })
    end
    Draw.textC(ch.label, ch.x + ch.w / 2, ch.y + (ch.h - 11) / 2, on and accent or C.ink3, Theme.label(10))
  end

  -- Liste des scénarios : CONTENEUR scrollable (clip au viewport -> aucun débordement hors-fenêtre).
  local listY, listViewH = self.listY, self.listViewH
  Draw.scissor(view, LIST_X - 4, listY - 2, LIST_W + 12, listViewH + 4)
  for i, sc in ipairs(self.scenarios) do
    local r = self:rowRect(i)
    if r.y + r.h > listY - 2 and r.y < listY + listViewH then -- saute les lignes hors-champ
      local on = (self.sel == i)
      local hov = (self.hover == i)
      -- ligne = SURFACE PROPRE (Panel) : sélection bordée d'or (héros) ; survol bordé de laiton ; sinon iron.
      Panel.draw(r.x, r.y, r.w, r.h, {
        fill1 = on and C.stone700 or C.stone850, fill2 = C.stone900,
        border = on and C.gold or (hov and C.brass or C.iron),
        accent = on and C.gold or nil, hi = on,
      })
      Draw.text(T("scenario." .. sc.id .. ".label"), r.x + 14, r.y + 8, on and C.ink or C.ink2, Theme.subhead(14))
      local a, b = Compositions.byId[sc.a], Compositions.byId[sc.b]
      local right = isBossScenario(sc) and bossName(sc.boss) or T("pg.archetype." .. b.archetype)
      Draw.text(T("pg.archetype." .. a.archetype) .. "  vs  " .. right,
        r.x + 14, r.y + 27, isBossScenario(sc) and C.bloodL or C.ink4, Theme.label(9))
    end
  end
  Draw.noScissor()
  -- Barre de défilement (apparaît seulement quand la liste dépasse le conteneur).
  local maxS = self:maxScroll()
  if maxS > 0 then
    local tx = LIST_X + LIST_W + 6
    Draw.rect(tx, listY, 3, listViewH, C.stone900)
    local thumbH = math.max(24, listViewH * self.listVisible / #self.scenarios)
    Draw.rect(tx, listY + (listViewH - thumbH) * (self.scroll / maxS), 3, thumbH, C.brass)
  end
  Draw.text(T("pg.trials", { n = #self.scenarios }), LIST_X, listY + listViewH + 8, C.ink5, Theme.label(9))

  -- Aperçus A (gauche) / B (droite) + "Vs".
  local watched = self.result and self.result.kind == "watch"
  local bossWatched = self.result and self.result.kind == "boss_watch"
  self:drawComp(self.cA, self.compA, self.costA, AX, PANEL_Y, PANEL_W, PANEL_H, watched and self.result.win)
  if self.boss then
    local killed = bossWatched and self.result.result and self.result.result.boss_killed
    self:drawBossPreview(self.boss, BX, PANEL_Y, PANEL_W, PANEL_H, killed)
  else
    self:drawComp(self.cB, self.compB, self.costB, BX, PANEL_Y, PANEL_W, PANEL_H, watched and (self.result.win == false))
  end
  Draw.textC(T("pg.vs"), (AX + PANEL_W + BX) / 2, PANEL_Y + PANEL_H / 2 - 24, C.bloodL, Theme.display(34))

  -- Boutons WATCH / SIM + lecture du résultat (contextualisée par l'investissement).
  self:drawButtons()
  self:drawResult()

  -- retour = bouton homogène « ‹ MENU » (règle de nav). Fini la ligne « [up/down]... [esc] menu » en pied :
  -- up/down/enter/s restent des accélérateurs silencieux (sélection aussi possible à la souris).
  self.backRect = Nav.back(view, T("pg.back"), { mx = self.mx, my = self.my, id = "pg.back" })
  Draw.finish()
end

-- Boutons du banc d'essai (ATOMES PROPRES) : WATCH = primary (l'action héros, sang + yeux) ; SIM = eco
-- (compact, voix terne). Pendant un batch, SIM bascule en secondary désactivé + barre de progression.
function Playground:drawButtons()
  local wr, sr = self:watchRect(), self:simRect()
  Button.draw(wr.x, wr.y, wr.w, wr.h, "primary", T("pg.watch"),
    { hover = inRect(self.mx, self.my, wr), feel = Feel.state("pg.watch"), id = "pg.watch",
      mouse = { mx = self.mx, my = self.my }, t = self.t })
  if self.sim then
    Button.draw(sr.x, sr.y, sr.w, sr.h, "secondary", T("pg.simming", { done = self.sim.done, n = self.sim.n }),
      { disabled = true })
    Draw.bar(sr.x + 2, sr.y + sr.h - 6, sr.w - 4, 4, self.sim.done / self.sim.n, C.gold, C.ecoBg, nil)
  else
    Button.draw(sr.x, sr.y, sr.w, sr.h, "eco", T("pg.sim", { n = SIM_N }),
      { hover = inRect(self.mx, self.my, sr), feel = Feel.state("pg.sim") })
  end
end

function Playground:drawResult()
  local rx, ry = BX, BTN_Y
  if not self.result then
    Draw.textC(T("pg.idle"), rx + PANEL_W / 2, ry + 18, C.ink4, Theme.label(10))
    return
  end
  if self.result.kind == "watch" then
    local who = self.result.win and T("result.left") or T("result.right")
    Draw.textC(who, rx + PANEL_W / 2, ry + 8, self.result.win and C.gold or C.bloodL, Theme.heading(16))
    Draw.textC(T("pg.watched"), rx + PANEL_W / 2, ry + 32, C.ink4, Theme.label(9))
  elseif self.result.kind == "boss_watch" then
    local r = self.result.result or {}
    Draw.textC(T("pg.boss_score", { score = tostring(math.floor((r.boss_score_damage or 0) + 0.5)) }),
      rx + PANEL_W / 2, ry + 4, C.gold, Theme.value(15))
    Draw.textC(T(r.boss_killed and "pg.boss_slain" or "pg.boss_measured"),
      rx + PANEL_W / 2, ry + 28, r.boss_killed and C.bloodL or C.ink4, Theme.label(9))
  elseif self.result.kind == "boss_sim" then
    local r = self.result
    local clearPct = r.clears / r.n * 100
    local windowPct = r.fullWindows / r.n * 100
    Draw.textC(T("pg.boss_avg_score", { score = tostring(math.floor((r.avgScore or 0) + 0.5)), n = r.n }),
      rx + PANEL_W / 2, ry + 4, C.ink, Theme.value(15))
    Draw.textC(T("pg.boss_sim_line", {
      clear = string.format("%.0f", clearPct),
      window = string.format("%.0f", windowPct),
    }), rx + PANEL_W / 2, ry + 28, C.ink4, Theme.label(9))
  else
    local pct = self.result.wins / self.result.n * 100
    local dpct = self.result.decided / self.result.n * 100
    Draw.textC(T("pg.winrate", { pct = string.format("%.0f", pct), n = self.result.n }),
      rx + PANEL_W / 2, ry + 6, C.ink, Theme.value(15))
    Draw.textC(T("pg.decided", { pct = string.format("%.0f", dpct) }), rx + PANEL_W / 2, ry + 28, C.ink4, Theme.label(9))
    -- contexte : delta d'investissement (rappelle que le win% se lit en regard du coût).
    local dScore = (self.costA.score - self.costB.score)
    Draw.textC(T("pg.invest_delta", { d = string.format("%+.2f", dScore) }),
      rx + PANEL_W / 2, ry + 42, C.ink3, Theme.label(9))
  end
end

-- ── Défilement de la liste (conteneur scrollable : molette/clavier, contenu borné au viewport) ──
function Playground:maxScroll() return math.max(0, #self.scenarios - self.listVisible) end

function Playground:clampScroll()
  local m = self:maxScroll()
  if self.scroll < 0 then self.scroll = 0 elseif self.scroll > m then self.scroll = m end
end

-- Garde la ligne `i` dans le viewport (auto-scroll quand la sélection sort par le haut/bas).
function Playground:ensureVisible(i)
  if i - 1 < self.scroll then self.scroll = i - 1
  elseif i - 1 >= self.scroll + self.listVisible then self.scroll = i - self.listVisible end
  self:clampScroll()
end

function Playground:wheelmoved(_, dy)
  self.scroll = self.scroll - (dy or 0)
  self:clampScroll()
end

-- ── Géométrie + souris (rowRect tient compte du scroll) ──
function Playground:rowRect(i)
  return { x = LIST_X, y = self.listY + (i - 1 - self.scroll) * LIST_STEP, w = LIST_W, h = ROW_H }
end
local ptIn = inRect
-- Le clic/survol n'est valide que DANS le conteneur (une ligne scrollée hors-champ n'est pas cliquable).
function Playground:inList(dx, dy) return dx >= LIST_X and dx <= LIST_X + LIST_W and dy >= self.listY and dy <= self.listY + self.listViewH end

function Playground:mousemoved(vx, vy)
  local dx, dy = vx * 4, vy * 4
  self.mx, self.my = dx, dy
  self.hover = nil
  if not self:inList(dx, dy) then return end
  for i = 1, #self.scenarios do if ptIn(dx, dy, self:rowRect(i)) then self.hover = i; return end end
end

function Playground:mousepressed(vx, vy, button)
  if button ~= 1 then return end
  local dx, dy = vx * 4, vy * 4
  self.mx, self.my = dx, dy
  if Nav.hit(self.backRect, dx, dy) then Feel.press("pg.back", function() self.host.goto("menu") end); return end -- ⭐ différé
  for _, ch in ipairs(self.chipRects) do -- clic sur une chip de filtre
    if ptIn(dx, dy, ch) then self:setFilter(ch.key); return end
  end
  if self:inList(dx, dy) then -- clic dans le conteneur : sélectionne une ligne (bornée au viewport)
    for i = 1, #self.scenarios do
      if ptIn(dx, dy, self:rowRect(i)) then self:select(i); break end
    end
    return
  end
  -- WATCH : ⭐ DIFFÉRÉE (bascule de scène -> press visible AVANT, ~160 ms). SIM : in-scène (le batch tourne
  -- DANS la scène, le press s'affiche déjà) -> reste IMMÉDIAT. Pas de mousereleased dans cette scène.
  if ptIn(dx, dy, self:watchRect()) then Feel.press("pg.watch", function() self:startWatch() end); return end
  if ptIn(dx, dy, self:simRect()) then Feel.press("pg.sim"); self:startSim(); return end
end

function Playground:keypressed(key)
  if key == "up" then self:select((self.sel - 2) % #self.scenarios + 1)
  elseif key == "down" then self:select(self.sel % #self.scenarios + 1)
  elseif key == "pageup" then self.scroll = self.scroll - self.listVisible; self:clampScroll()
  elseif key == "pagedown" then self.scroll = self.scroll + self.listVisible; self:clampScroll()
  elseif key == "return" or key == "kpenter" or key == "w" then self:startWatch()
  elseif key == "s" then self:startSim() end
end

return Playground
