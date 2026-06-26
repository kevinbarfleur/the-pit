-- feel-lab/rooms/components.lua
-- « VRAIS COMPOSANTS » — la page Interaction REBÂTIE avec le CODE RÉEL de The Pit (duplication assumée,
-- demandée par l'user : « voir à quoi ça ressemble avant de l'intégrer pour de vrai »). Ici, AUCUN widget
-- du lab : on dessine avec les vrais modules importés tels quels depuis src/ —
--   • src.ui.button  → les 5 variantes propres + l'ŒIL cauchemardesque du CTA (Forge.uiCtaEyes au survol)
--   • src.ui.slot    → les CASES du plateau-graphe 3×3 (6 états) + l'arête de synergie (sang lumineux)
--   • src.ui.panel   → la SURFACE propre (dégradé + liseré iron)
-- pilotés par le VRAI Feel (lib.feel = même instance que main met à jour + hooks SFX déjà câblés) et le
-- son/juice procédural du lab (shake trauma² + hitstop + number-roll). Le drag-drop reprend le ressort
-- Balatro (lib.behavior) ET le SWAP (lâcher sur une case occupée échange les deux pièces).
--
-- ⚠ Le SEUL cosmétique réel non câblé ici : l'anneau de DISTORSION onirique PAR-BOX (src.render.postfx,
-- `markBox`). Sans instance PostFX active, `markBox` est un no-op pur (zéro fuite) ; l'imbriquer dans le
-- canvas global du lab est fragile. La surcouche cauchemardesque GLOBALE du lab ([F9]) couvre le grain
-- onirique d'ambiance. Tout le reste (œil, panneaux, cases, typographie 4 voix) est le rendu RÉEL.

local Draw   = require("src.ui.draw")     -- VRAI helper de rendu espace-design (net HiDPI)
local Theme  = require("src.ui.theme")    -- VRAIE palette + polices (Jacquard/Cinzel/Spectral/Space Mono)
local Button = require("src.ui.button")   -- VRAIS boutons : primary(œil)/secondary/eco/icon/ghost
local Panel  = require("src.ui.panel")    -- VRAIE surface
local Slot   = require("src.ui.slot")     -- VRAIE case du plateau (6 états + arête)
local Feel   = require("lib.feel")        -- VRAI juice (même instance que main pilote ; SFX y est branché)
local Juice  = require("lib.juice")       -- shake / hitstop / number-roll
local SFX    = require("lib.sfx")         -- son procédural (profil Oneiric grave par défaut)
local B      = require("lib.behavior")    -- ressort de drag « bouncy » (feel Balatro)

local Room = {}
Room.__index = Room
local c = Theme.c
local W, H = 1280, 720
local CELL = 60   -- côté d'une case du plateau ET d'un jeton (ils s'emboîtent au drop)
local LOCKED = 9  -- case verrouillée (démontre l'état "locked" ; refuse le drop)

-- Rects (espace DESIGN 1280×720) des boutons — partagés par draw ET input (layout statique = source unique).
local RECTS = {
  cta     = { x = 40,  y = 142, w = 330, h = 54 },
  reroll  = { x = 40,  y = 210, w = 160, h = 46 },
  level   = { x = 210, y = 210, w = 160, h = 46 },
  inspect = { x = 40,  y = 268, w = 160, h = 42 },
  soldout = { x = 210, y = 268, w = 160, h = 46 },
  ic1     = { x = 40,  y = 324, w = 40,  h = 40 },
  ic2     = { x = 88,  y = 324, w = 40,  h = 40 },
  ic3     = { x = 136, y = 324, w = 40,  h = 40 },
  ic4     = { x = 184, y = 324, w = 40,  h = 40 },
  strike  = { x = 40,  y = 380, w = 330, h = 46 },
  score   = { x = 40,  y = 442, w = 210, h = 48 },
  reset   = { x = 260, y = 444, w = 110, h = 44 },
}

-- jetons : 5 RARETÉS croissantes (le BORD de case prend la couleur de rareté = tierBorder, comme en build),
-- avec niveau (LVn) et marques d'affliction — pour montrer TOUS les leviers visuels d'une vraie case occupée.
local TOKENS = {
  { tierCol = c.ink3,   tierBorder = nil,    level = 1, aff = {} },                      -- commun
  { tierCol = c.poison, tierBorder = nil,    level = 2, aff = { "shock" } },             -- peu commun
  { tierCol = c.shield, tierBorder = c.shield, level = 1, aff = { "bleed" } },           -- rare (bord teinté)
  { tierCol = c.rot,    tierBorder = c.rot,  level = 3, aff = { "rot" } },               -- épique
  { tierCol = c.gold,   tierBorder = c.gold, tierGlow = true, level = 2, aff = { "poison", "burn" } }, -- légendaire (halo)
}

local function hit(r, mx, my)
  return mx >= r.x and mx <= r.x + r.w and my >= r.y and my <= r.y + r.h
end

function Room.new(app)
  local self = setmetatable({ app = app, mx = -1, my = -1, t = 0, score = 0, shown = 0, combo = 0 }, Room)
  Theme.load()  -- pré-chauffe les polices du VRAI Theme (instance distincte de lib.theme) — idempotent
  -- géométrie du bac à sable
  self.benchX0, self.benchY, self.benchStep = 700, 158, 68
  self.boardX0, self.boardY0, self.boardStep = 824, 288, 76
  -- plateau 3×3 (cases) + jetons
  self.cells = {}
  for i = 1, 9 do self.cells[i] = { token = nil } end
  self.tokens = {}
  for i, t in ipairs(TOKENS) do
    local hx, hy = self:homePos(i)
    self.tokens[i] = { home = i, tierCol = t.tierCol, tierBorder = t.tierBorder, tierGlow = t.tierGlow,
                       level = t.level, aff = t.aff, cell = nil, d = { px = hx, py = hy, gx = hx, gy = hy } }
  end
  -- pré-placement (montre 2 arêtes de synergie au repos / au screenshot) : centre + haut + gauche
  self:place(1, 5); self:place(2, 2); self:place(3, 4)
  self.dragging, self.dragFrom = nil, nil
  return self
end

function Room:enter() self.title = "Real Components" end

-- harnais de capture : "eyes" simule le survol du CTA pour montrer l'ŒIL ouvert (sinon clos au repos).
function Room:scenario(name)
  if name == "eyes" then
    local r = RECTS.cta
    self.mx, self.my = r.x + r.w / 2, r.y + r.h / 2
  end
end

-- ── géométrie ───────────────────────────────────────────────────────────────────────────────────────────
function Room:homePos(i) return self.benchX0 + (i - 1) * self.benchStep, self.benchY end
function Room:cellPos(idx)
  local col, row = (idx - 1) % 3, math.floor((idx - 1) / 3)
  return self.boardX0 + col * self.boardStep, self.boardY0 + row * self.boardStep
end
function Room:cellCenter(idx) local x, y = self:cellPos(idx); return x + CELL / 2, y + CELL / 2 end
function Room:restTarget(tk) if tk.cell then return self:cellPos(tk.cell) else return self:homePos(tk.home) end end
function Room:place(i, idx) self.tokens[i].cell = idx; self.cells[idx].token = i
  local x, y = self:cellPos(idx); local d = self.tokens[i].d; d.px, d.py, d.gx, d.gy = x, y, x, y end

-- adjacence orthogonale du plateau-graphe (mêmes arêtes que le vrai board carré).
local function adjacent(a, b)
  local ca, ra = (a - 1) % 3, math.floor((a - 1) / 3)
  local cb, rb = (b - 1) % 3, math.floor((b - 1) / 3)
  return math.abs(ca - cb) + math.abs(ra - rb) == 1
end

-- ── juice partagé (identiques aux démos du lab, ici déclenchés par de VRAIS boutons) ──────────────────────
function Room:strike() Juice.addTrauma(0.6); Juice.freeze(0.08); SFX.play("thud"); self.flash = 0.5 end
function Room:scorePlus()
  local add = 50 + math.floor((love and love.math.random() or math.random()) * 250)
  self.score = self.score + add; self.combo = self.combo + 1
  SFX.ladder(self.combo == 1); Juice.addTrauma(0.12); Juice.juice_up("cmp.score", 0.18)
end
function Room:resetScore() self.score, self.combo = 0, 0 end

function Room:update(dt)
  self.t = self.t + (dt or 0)
  -- ressort des jetons : la cible (gx,gy) suit la case/le banc, SAUF pour celui qu'on traîne (gx,gy = souris)
  for i, tk in ipairs(self.tokens) do
    if i ~= self.dragging then local tx, ty = self:restTarget(tk); tk.d.gx, tk.d.gy = tx, ty end
    B.dragApply(tk.d, dt)
  end
  -- survol des boutons (pose la cible Feel + tick de son au franchissement) — pilote lift/glow/yeux
  for _, id in ipairs({ "cta", "reroll", "level", "inspect", "ic1", "ic2", "ic3", "ic4", "strike", "score", "reset" }) do
    Feel.hover("cmp." .. id, hit(RECTS[id], self.mx, self.my))
  end
  -- number-roll vers la cible (ease)
  if math.abs(self.score - self.shown) > 0.5 then
    self.shown = self.shown + (self.score - self.shown) * math.min(1, (dt or 0) * 9)
  else self.shown = self.score end
end

-- ── quelle case le jeton traîné survole-t-il (centre dans la portée) ? ─────────────────────────────────────
function Room:hoverCell()
  if not self.dragging then return nil end
  local tk = self.tokens[self.dragging]
  local cx, cy = tk.d.px + CELL / 2, tk.d.py + CELL / 2
  local best, bestD
  for idx = 1, 9 do
    if idx ~= LOCKED then
      local ccx, ccy = self:cellCenter(idx)
      local dx, dy = ccx - cx, ccy - cy
      local dist = dx * dx + dy * dy
      if dist < (CELL * CELL) and (not bestD or dist < bestD) then best, bestD = idx, dist end
    end
  end
  return best
end

function Room:draw(view)
  Draw.begin(view)

  -- ── en-tête ─────────────────────────────────────────────────────────────────────────────────────────
  Draw.textTrackedL("REAL COMPONENTS", 40, 82, c.ink, Theme.title(20), 2)
  Draw.text("le vrai code de The Pit — boutons-œil · cases du plateau · surfaces", 320, 88, c.ink4, Theme.body(14))

  -- ════════════ COLONNE A — BOUTONS (vrais) ════════════
  Draw.textTrackedL("BUTTONS", 40, 116, c.gold, Theme.subhead(14), 2)
  -- primary CTA (œil) : les yeux s'ouvrent au survol et fixent la souris ; au clic ils se referment puis l'action part
  do
    local r = RECTS.cta
    Button.draw(r.x, r.y, r.w, r.h, "primary", "ENTER THE PIT", {
      hover = hit(r, self.mx, self.my), feel = Feel.state("cmp.cta"), id = "cmp.cta",
      mouse = { mx = self.mx, my = self.my }, t = self.t })
  end
  -- secondary + eco (coût or)
  do local r = RECTS.reroll
    Button.draw(r.x, r.y, r.w, r.h, "secondary", "REROLL", { hover = hit(r, self.mx, self.my), feel = Feel.state("cmp.reroll"), id = "cmp.reroll" }) end
  do local r = RECTS.level
    Button.draw(r.x, r.y, r.w, r.h, "eco", "LEVEL UP", { cost = 5, hover = hit(r, self.mx, self.my), feel = Feel.state("cmp.level"), id = "cmp.level" }) end
  -- ghost + secondary désactivé (comparer l'absence de juice)
  do local r = RECTS.inspect; Feel.hover("cmp.inspect", hit(r, self.mx, self.my))
    Button.ghost(r.x, r.y, r.w, r.h, "INSPECT", { hover = hit(r, self.mx, self.my) }) end
  do local r = RECTS.soldout
    Button.draw(r.x, r.y, r.w, r.h, "secondary", "SOLD OUT", { disabled = true }) end
  -- icônes (sigil/prev/next/gear)
  local kinds = { ic1 = "sigil", ic2 = "prev", ic3 = "next", ic4 = "gear" }
  for _, id in ipairs({ "ic1", "ic2", "ic3", "ic4" }) do
    local r = RECTS[id]
    Button.icon(r.x, r.y, r.w, kinds[id], { hover = hit(r, self.mx, self.my), pressed = Feel.pending("cmp." .. id) })
  end
  -- STRIKE (shake + hitstop) en secondary
  do local r = RECTS.strike
    Button.draw(r.x, r.y, r.w, r.h, "secondary", "STRIKE", { hover = hit(r, self.mx, self.my), feel = Feel.state("cmp.strike"), id = "cmp.strike" }) end
  -- + Score (eco) + Reset (ghost) + number-roll punché
  do local r = RECTS.score
    Button.draw(r.x, r.y, r.w, r.h, "eco", "+ SCORE", { hover = hit(r, self.mx, self.my), feel = Feel.state("cmp.score"), id = "cmp.score" }) end
  do local r = RECTS.reset; Feel.hover("cmp.reset", hit(r, self.mx, self.my))
    Button.ghost(r.x, r.y, r.w, r.h, "RESET", { hover = hit(r, self.mx, self.my) }) end
  local sc = Juice.scale("cmp.score")
  love.graphics.push(); love.graphics.translate(205, 528); love.graphics.scale(sc, sc)
  Draw.textC(string.format("%d", math.floor(self.shown + 0.5)), 0, -26, c.gold, Theme.display(46))
  love.graphics.pop()
  Draw.textC(self.combo > 0 and ("combo ×" .. self.combo) or "click to score", 205, 560, c.ink4, Theme.label(12))

  -- ════════════ COLONNE B — ÉTATS DE CASE + SURFACE ════════════
  Draw.textTrackedL("SLOT STATES", 410, 116, c.gold, Theme.subhead(14), 2)
  local states = {
    { "empty", "empty" }, { "selected", "occupied" }, { "neighbor", "synergy" },
    { "drop", "drop ok" }, { "locked", "locked" }, { "hover", "hover" },
  }
  for k, sd in ipairs(states) do
    local col, row = (k - 1) % 3, math.floor((k - 1) / 3)
    local x, y = 410 + col * 90, 150 + row * 104
    local opts = {}
    if sd[1] == "selected" then opts = { tierCol = c.poison, level = 2, affkeys = { "burn" } } end
    Slot.draw(x, y, 56, sd[1], opts)
    Draw.textC(sd[2], x + 28, y + 60, c.ink4, Theme.label(10))
  end
  -- SURFACE (vrai Panel) — montre la base « nette » + une niche à sprite
  Draw.textTrackedL("SURFACE", 410, 346, c.gold, Theme.subhead(14), 2)
  local ix, iy, iw = Panel.draw(410, 372, 280, 152)
  Draw.textTrackedL("MAW OF ASH", ix + 14, iy + 12, c.ember, Theme.title(15), 1)
  Draw.textWrap("On a kill, your team's afflictions refuse to decay. The Pit remembers every wound.",
    ix + 14, iy + 38, iw - 28, c.ink2, Theme.body(13))
  Panel.niche(ix + 14, iy + 100, 40, 40)
  Draw.text("a clean surface — grit comes from the global shader", ix + 62, iy + 112, c.ink5, Theme.flavor(13))

  -- ════════════ COLONNE C — DRAG & DROP (vraies cases, plateau 3×3) ════════════
  Draw.textTrackedL("DRAG & DROP", 700, 116, c.gold, Theme.subhead(14), 2)
  Draw.text("bench", 700, 138, c.ink5, Theme.label(11))
  Draw.text("board 3×3  ·  drag a piece in  ·  drop on an occupied cell to SWAP", 700, 266, c.ink5, Theme.label(11))
  -- banc : 5 cases vides (positions maison)
  for i = 1, #self.tokens do local x, y = self:homePos(i); Slot.draw(x, y, CELL, "empty", {}) end
  -- plateau : état de chaque case (drop/hover pendant le drag ; locked ; sinon empty — l'occupant est le jeton dessiné par-dessus)
  local hc = self:hoverCell()
  for idx = 1, 9 do
    local x, y = self:cellPos(idx)
    local state = "empty"
    if idx == LOCKED then state = "locked"
    elseif idx == hc then state = self.cells[idx].token and "hover" or "drop" end
    Slot.draw(x, y, CELL, state, {})
  end
  -- arêtes de synergie : sang lumineux entre cases occupées adjacentes
  for a = 1, 9 do
    if self.cells[a].token then
      for b = a + 1, 9 do
        if self.cells[b].token and adjacent(a, b) then
          local ax, ay = self:cellCenter(a); local bx, by = self:cellCenter(b)
          Slot.edge(ax, ay, bx, by, true, 2)
        end
      end
    end
  end
  -- jetons (le traîné en DERNIER = au-dessus)
  for i = 1, #self.tokens do if i ~= self.dragging then self:drawToken(self.tokens[i], false) end end
  if self.dragging then self:drawToken(self.tokens[self.dragging], true) end

  -- flash plein écran (STRIKE)
  if self.flash and self.flash > 0.01 then
    love.graphics.setColor(c.ember[1], c.ember[2], c.ember[3], 0.16 * self.flash)
    love.graphics.rectangle("fill", 0, 0, W, H)
    self.flash = self.flash * 0.86
  end

  Draw.finish()
end

-- une PIÈCE = une vraie case "selected" (occupée) avec sa rareté/niveau/afflictions, sous le transform de drag.
function Room:drawToken(tk, isDrag)
  local fx = B.dragFx(tk.d)
  local px, py = tk.d.px, tk.d.py
  local cx, cy = px + CELL / 2, py + CELL / 2
  if fx.shadow then
    love.graphics.setColor(0, 0, 0, 0.34)
    love.graphics.rectangle("fill", px + 5, py + (-fx.dy) + 9, CELL, CELL)
  end
  love.graphics.push()
  love.graphics.translate(cx, cy + fx.dy)
  love.graphics.rotate(fx.rot or 0)
  love.graphics.scale(fx.scale or 1, fx.scale or 1)
  love.graphics.translate(-cx, -cy)
  Slot.draw(px, py, CELL, "selected", {
    tierCol = tk.tierCol, tierBorder = tk.tierBorder, tierGlow = tk.tierGlow,
    level = tk.level, affkeys = tk.aff })
  love.graphics.pop()
  Draw.reset()
end

-- ── input ───────────────────────────────────────────────────────────────────────────────────────────────
function Room:tokenAt(mx, my)
  for i = #self.tokens, 1, -1 do
    local d = self.tokens[i].d
    if mx >= d.px and mx <= d.px + CELL and my >= d.py and my <= d.py + CELL then return i end
  end
end

function Room:mousepressed(mx, my, button)
  self.mx, self.my = mx, my
  if button ~= 1 then return end
  -- 1) boutons (actions différées via le VRAI Feel : le clic se SENT avant que l'écran réagisse)
  if hit(RECTS.cta, mx, my) then Feel.press("cmp.cta", function() self:strike() end, { delay = Feel.CTA_DELAY }); return end
  if hit(RECTS.reroll, mx, my) then Feel.press("cmp.reroll", function() self.app:toast("Rerolled.") end); return end
  if hit(RECTS.level, mx, my) then Feel.press("cmp.level", function() self:scorePlus() end); return end
  if hit(RECTS.inspect, mx, my) then Feel.press("cmp.inspect"); return end
  if hit(RECTS.strike, mx, my) then Feel.press("cmp.strike", function() self:strike() end); return end
  if hit(RECTS.score, mx, my) then Feel.press("cmp.score", function() self:scorePlus() end); return end
  if hit(RECTS.reset, mx, my) then Feel.press("cmp.reset", function() self:resetScore() end); return end
  for _, id in ipairs({ "ic1", "ic2", "ic3", "ic4" }) do
    if hit(RECTS[id], mx, my) then Feel.press("cmp." .. id); return end
  end
  -- 2) prise d'un jeton
  local i = self:tokenAt(mx, my)
  if i then
    local tk = self.tokens[i]
    self.dragFrom = { cell = tk.cell }       -- d'où il vient (case ou banc)
    if tk.cell then self.cells[tk.cell].token = nil end
    tk.cell = nil
    self.dragging = i
    B.dragBegin(tk.d, mx, my, mx - tk.d.px, my - tk.d.py)
    SFX.play("pickup")
  end
end

function Room:mousemoved(mx, my)
  self.mx, self.my = mx, my
  if self.dragging then B.dragMove(self.tokens[self.dragging].d, mx, my) end
end

function Room:mousereleased(mx, my)
  if not self.dragging then return end
  local i = self.dragging
  local tk = self.tokens[i]
  B.dragEnd(tk.d)
  local best = self:hoverCell()
  local from = self.dragFrom or { cell = nil }
  if best then
    local occ = self.cells[best].token
    if occ and occ ~= i then
      -- ⇄ SWAP : l'occupant prend la PROVENANCE du jeton déplacé (sa case d'origine, ou son banc s'il venait du banc)
      local b = self.tokens[occ]
      b.cell = from.cell
      if from.cell then self.cells[from.cell].token = occ end
      SFX.play("drop"); Juice.addTrauma(0.12)
    else
      SFX.play("drop"); Juice.addTrauma(0.08)
    end
    tk.cell = best; self.cells[best].token = i
  else
    -- hors plateau / sur la case verrouillée : retour à l'origine (le ressort de update s'en charge)
    tk.cell = from.cell
    if from.cell then self.cells[from.cell].token = i end
    SFX.play("drop", { pitch = 0.9 })
  end
  self.dragging, self.dragFrom = nil, nil
end

return Room
