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

local Theme = require("src.ui.theme")
local Draw = require("src.ui.draw")
local Ambient = require("src.fx.ambient")
local Units = require("src.data.units")
local Shapes = require("src.board.shapes")
local Compositions = require("src.data.compositions")
local Compbuild = require("src.lab.compbuild")
local Compcost = require("src.lab.compcost")
local Match = require("src.combat.match")
local T = require("src.core.i18n").t

local Playground = {}
Playground.__index = Playground

local SIM_N = 200          -- nb de matchs par batch SIM
local SIM_PER_FRAME = 10   -- matchs joués par frame (étalé -> pas de gel)

-- Mise en page (espace design 1280x720).
local LIST_X, LIST_Y, LIST_W, ROW_H, ROW_GAP = 28, 122, 300, 46, 6
local LIST_STEP = ROW_H + ROW_GAP               -- 52 px par ligne
local LIST_VIEW_H = 396                          -- hauteur du CONTENEUR scrollable (alignee sur les panneaux)
local LIST_VISIBLE = math.floor(LIST_VIEW_H / LIST_STEP) -- lignes entierement visibles (7)
local AX, BX, PANEL_Y, PANEL_W, PANEL_H = 356, 818, 122, 408, 396
local BTN_Y, BTN_H = 540, 54

function Playground.new(palette, vw, vh, host)
  local self = setmetatable({
    palette = palette, vw = vw, vh = vh, host = host,
    daChrome = true, titleKey = "pg.title", hintKey = "ui.hint_playground",
    t = 0, ambient = Ambient.new(3),
    scenarios = Compositions.scenarios,
    sel = 0, hover = nil, scroll = 0,
    compA = nil, compB = nil, costA = nil, costB = nil,
    result = nil, sim = nil,
  }, Playground)
  self:select(1)
  return self
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
  self.cB = Compositions.byId[sc.b]
  self.compA = Compbuild.toComp(self.cA, -1)
  self.compB = Compbuild.toComp(self.cB, 1)
  self.costA = Compcost.of(self.cA)
  self.costB = Compcost.of(self.cB)
  self.result, self.sim = nil, nil
end

function Playground:startWatch()
  if not (self.compA and self.compB) then return end
  local sc = self.scenarios[self.sel]
  local pg = self
  self.host.goto("combat", {
    left = self.compA, right = self.compB, seed = sc.seed, enemyKey = "exhibition",
    onFinish = function(win)
      pg.result = { kind = "watch", win = win }
      pg.host.goto("playground")
    end,
  })
end

function Playground:startSim()
  if not (self.compA and self.compB) or self.sim then return end
  local sc = self.scenarios[self.sel]
  self.sim = { n = SIM_N, done = 0, wins = 0, decided = 0, seed = sc.seed }
  self.result = nil
end

function Playground:update(dt)
  self.t = self.t + (dt or 1)
  self.ambient:update(dt)
  if self.sim then
    local s, k = self.sim, 0
    while s.done < s.n and k < SIM_PER_FRAME do
      local res = Match.run(self.compA, self.compB, s.seed + s.done, {})
      if res.win then s.wins = s.wins + 1 end
      if res.decided then s.decided = s.decided + 1 end
      s.done = s.done + 1; k = k + 1
    end
    if s.done >= s.n then
      self.result = { kind = "sim", n = s.n, wins = s.wins, decided = s.decided }
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

function Playground:drawComp(comp, resolved, cost, px, py, pw, ph, won)
  local c = Theme.c
  Draw.rect(px, py, pw, ph, c.panelDeep, won and c.ecoBorder or c.hair, won and 2 or 1)

  -- Titre : archétype — variant (Silkscreen, fonctionnel lisible).
  local titleStr = T("pg.archetype." .. comp.archetype) .. "  -  " .. T("pg.variant." .. comp.variant)
  Draw.textC(titleStr, px + pw / 2, py + 12, c.title, Theme.uiBold(14))
  Draw.textC(T("shape." .. comp.sigil .. ".label"), px + pw / 2, py + 34, c.faint, Theme.ui(9))

  -- Grille du sigil : cases vides en points ténus, unités en pips colorés par type + nom.
  local shape = Shapes[comp.sigil]
  local gx, gy, gw, gh = px + 54, py + 64, pw - 108, ph - 184
  local minX, maxX, minY, maxY = shapeBounds(shape)
  local function cellPx(cell)
    local rx = (maxX > minX) and (cell.x - minX) / (maxX - minX) or 0.5
    local ry = (maxY > minY) and (cell.y - minY) / (maxY - minY) or 0.5
    return gx + rx * gw, gy + ry * gh
  end
  for _, cell in ipairs(shape.cells) do
    local cx, cy = cellPx(cell)
    Draw.setColor(c.edgeIdle); love.graphics.circle("fill", cx, cy, 2)
  end
  local used = {}
  for _, u in ipairs(comp.units) do used[u.slot] = u end
  for _, u in ipairs(comp.units) do
    local cell = shape.cells[u.slot]
    local cx, cy = cellPx(cell)
    local ut = Units[u.id]
    Draw.pip(ut and ut.type or "bone", cx, cy, 9)
    Draw.textC(T("unit." .. u.id .. ".name"), cx, cy + 12, c.muted, Theme.ui(7))
    if (u.level or 1) > 1 then -- pips de niveau (or)
      for p = 1, (u.level - 1) do
        Draw.setColor(c.goldBright); love.graphics.circle("fill", cx - 6 + p * 6, cy - 13, 1.6)
      end
    end
  end

  -- Investissement : barre de score + or (le contexte qui rend le win% lisible).
  local iy = py + ph - 56
  Draw.text(T("pg.invest"), px + 18, iy, c.faint, Theme.ui(9))
  Draw.bar(px + 18, iy + 14, pw - 36, 8, cost.score, c.gold, c.ecoBg, c.ecoBorder)
  Draw.textR(T("pg.gold", { n = cost.gold }), px + pw - 18, iy + 26, c.muted, Theme.ui(9))
end

function Playground:drawOverlay(view)
  local c = Theme.c
  Draw.begin(view)

  -- En-tête (titre gothique en CASSE DE TITRE, comme le Grimoire).
  Draw.text(T("pg.title"), LIST_X, 24, c.title, Theme.display(40))
  Draw.text(T("pg.subtitle"), LIST_X + 2, 78, c.faint, Theme.ui(9))

  -- Liste des scénarios : CONTENEUR scrollable (clip au viewport -> aucun débordement hors-fenêtre).
  Draw.scissor(view, LIST_X - 4, LIST_Y - 2, LIST_W + 10, LIST_VIEW_H + 4)
  for i, sc in ipairs(self.scenarios) do
    local r = self:rowRect(i)
    if r.y + r.h > LIST_Y - 2 and r.y < LIST_Y + LIST_VIEW_H then -- saute les lignes hors-champ
      local on = (self.sel == i)
      Draw.rect(r.x, r.y, r.w, r.h, on and c.panel or c.panelDeep, on and c.ecoBorder or c.line, 1)
      Draw.text(T("scenario." .. sc.id .. ".label"), r.x + 12, r.y + 7, on and c.title or c.body, Theme.ui(11))
      local a, b = Compositions.byId[sc.a], Compositions.byId[sc.b]
      Draw.text(T("pg.archetype." .. a.archetype) .. "  vs  " .. T("pg.archetype." .. b.archetype),
        r.x + 12, r.y + 26, c.faint, Theme.ui(8))
    end
  end
  Draw.noScissor()
  -- Barre de défilement (apparaît seulement quand la liste dépasse le conteneur).
  local maxS = self:maxScroll()
  if maxS > 0 then
    local tx = LIST_X + LIST_W + 6
    Draw.rect(tx, LIST_Y, 3, LIST_VIEW_H, c.line)
    local thumbH = math.max(24, LIST_VIEW_H * LIST_VISIBLE / #self.scenarios)
    Draw.rect(tx, LIST_Y + (LIST_VIEW_H - thumbH) * (self.scroll / maxS), 3, thumbH, c.ecoBorder)
  end
  Draw.text(T("pg.trials", { n = #self.scenarios }), LIST_X, LIST_Y + LIST_VIEW_H + 8, c.ghost, Theme.ui(8))

  -- Aperçus A (gauche) / B (droite) + "Vs".
  local watched = self.result and self.result.kind == "watch"
  self:drawComp(self.cA, self.compA, self.costA, AX, PANEL_Y, PANEL_W, PANEL_H, watched and self.result.win)
  self:drawComp(self.cB, self.compB, self.costB, BX, PANEL_Y, PANEL_W, PANEL_H, watched and (self.result.win == false))
  Draw.textC(T("pg.vs"), (AX + PANEL_W + BX) / 2, PANEL_Y + PANEL_H / 2 - 24, c.bloodBright, Theme.display(34))

  -- Boutons WATCH / SIM + lecture du résultat (contextualisée par l'investissement).
  self:drawButton(AX, BTN_Y, 200, BTN_H, T("pg.watch"), c.bloodDeep, c.blood, c.ctaText)
  if self.sim then
    self:drawButton(AX + 216, BTN_Y, 200, BTN_H, T("pg.simming", { done = self.sim.done, n = self.sim.n }),
      c.ecoBgHot, c.ecoBorder, c.muted)
    Draw.bar(AX + 216, BTN_Y + BTN_H - 5, 200, 4, self.sim.done / self.sim.n, c.gold, c.ecoBg, nil)
  else
    self:drawButton(AX + 216, BTN_Y, 200, BTN_H, T("pg.sim", { n = SIM_N }), c.ecoBg, c.ecoBorder, c.body)
  end
  self:drawResult(c)

  -- Pied.
  Draw.text(T("ui.hint_playground"), LIST_X, 694, c.ghost, Theme.ui(9))
  Draw.finish()
end

function Playground:drawButton(x, y, w, h, label, fill, border, text)
  Draw.button(x, y, w, h, label, Theme.uiBold(15), { fill = fill, border = border, text = text, bw = 2 })
end

function Playground:drawResult(c)
  local rx, ry = BX, BTN_Y
  if not self.result then
    Draw.textC(T("pg.idle"), rx + PANEL_W / 2, ry + 18, c.fainter, Theme.ui(10))
    return
  end
  if self.result.kind == "watch" then
    local who = self.result.win and T("result.left") or T("result.right")
    Draw.textC(who, rx + PANEL_W / 2, ry + 10, self.result.win and c.gold or c.bloodBright, Theme.uiBold(16))
    Draw.textC(T("pg.watched"), rx + PANEL_W / 2, ry + 34, c.faint, Theme.ui(9))
  else
    local pct = self.result.wins / self.result.n * 100
    local dpct = self.result.decided / self.result.n * 100
    Draw.textC(T("pg.winrate", { pct = string.format("%.0f", pct), n = self.result.n }),
      rx + PANEL_W / 2, ry + 8, c.title, Theme.uiBold(15))
    Draw.textC(T("pg.decided", { pct = string.format("%.0f", dpct) }), rx + PANEL_W / 2, ry + 30, c.faint, Theme.ui(9))
    -- contexte : delta d'investissement (rappelle que le win% se lit en regard du coût).
    local dScore = (self.costA.score - self.costB.score)
    Draw.textC(T("pg.invest_delta", { d = string.format("%+.2f", dScore) }),
      rx + PANEL_W / 2, ry + 44, c.muted, Theme.ui(9))
  end
end

-- ── Défilement de la liste (conteneur scrollable : molette/clavier, contenu borné au viewport) ──
function Playground:maxScroll() return math.max(0, #self.scenarios - LIST_VISIBLE) end

function Playground:clampScroll()
  local m = self:maxScroll()
  if self.scroll < 0 then self.scroll = 0 elseif self.scroll > m then self.scroll = m end
end

-- Garde la ligne `i` dans le viewport (auto-scroll quand la sélection sort par le haut/bas).
function Playground:ensureVisible(i)
  if i - 1 < self.scroll then self.scroll = i - 1
  elseif i - 1 >= self.scroll + LIST_VISIBLE then self.scroll = i - LIST_VISIBLE end
  self:clampScroll()
end

function Playground:wheelmoved(_, dy)
  self.scroll = self.scroll - (dy or 0)
  self:clampScroll()
end

-- ── Géométrie + souris (rowRect tient compte du scroll) ──
function Playground:rowRect(i)
  return { x = LIST_X, y = LIST_Y + (i - 1 - self.scroll) * LIST_STEP, w = LIST_W, h = ROW_H }
end
local function ptIn(x, y, r) return x >= r.x and x <= r.x + r.w and y >= r.y and y <= r.y + r.h end
-- Le clic/survol n'est valide que DANS le conteneur (une ligne scrollée hors-champ n'est pas cliquable).
local function inList(dx, dy) return dx >= LIST_X and dx <= LIST_X + LIST_W and dy >= LIST_Y and dy <= LIST_Y + LIST_VIEW_H end

function Playground:mousemoved(vx, vy)
  local dx, dy = vx * 4, vy * 4
  self.hover = nil
  if not inList(dx, dy) then return end
  for i = 1, #self.scenarios do if ptIn(dx, dy, self:rowRect(i)) then self.hover = i; return end end
end

function Playground:mousepressed(vx, vy, button)
  if button ~= 1 then return end
  local dx, dy = vx * 4, vy * 4
  if inList(dx, dy) then -- clic dans le conteneur : sélectionne une ligne (bornée au viewport)
    for i = 1, #self.scenarios do
      if ptIn(dx, dy, self:rowRect(i)) then self:select(i); break end
    end
    return
  end
  if ptIn(dx, dy, { x = AX, y = BTN_Y, w = 200, h = BTN_H }) then self:startWatch(); return end
  if ptIn(dx, dy, { x = AX + 216, y = BTN_Y, w = 200, h = BTN_H }) then self:startSim(); return end
end

function Playground:keypressed(key)
  if key == "up" then self:select((self.sel - 2) % #self.scenarios + 1)
  elseif key == "down" then self:select(self.sel % #self.scenarios + 1)
  elseif key == "pageup" then self.scroll = self.scroll - LIST_VISIBLE; self:clampScroll()
  elseif key == "pagedown" then self.scroll = self.scroll + LIST_VISIBLE; self:clampScroll()
  elseif key == "return" or key == "kpenter" or key == "w" then self:startWatch()
  elseif key == "s" then self:startSim() end
end

return Playground
