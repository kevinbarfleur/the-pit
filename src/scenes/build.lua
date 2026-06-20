-- src/scenes/build.lua
-- Phase de BUILD (le cœur de la boucle) : on compose son équipe sur le plateau-graphe en ACHETANT
-- des unités à la BOUTIQUE, puis on lance le combat. Composantes :
--   · le plateau 3×3 (sigil échangeable avec [s] ; slots débloqués en montant de NIVEAU) ;
--   · une BOUTIQUE (bas) : 5 offres aléatoires + prix ; on DRAG une offre sur une case (paie l'or) ;
--   · boutons REROLL (re-tire la boutique) et NIVEAU (débloque le slot suivant) ;
--   · réarrangement par drag case→case (déplacer/échanger) ; drag hors-plateau = VENTE (remboursement) ;
--   · une INFOBULLE au survol (stats + passif) d'une case occupée ou d'une offre ;
--   · un HUD de run (or/vies/victoires/round/niveau/streak) ;
--   · un bouton COMBAT -> assemble l'équipe (gauche) + une équipe IA (droite) et bascule vers la
--     scène de combat via host.goto("combat", payload). Le résultat revient par host.finishCombat.
--
-- La méta de RUN (host.run, src/run/state.lua) porte l'économie. SANS run (tests/sim), la scène
-- reste utilisable en « sandbox » : placeId/buildComp marchent directement, la boutique est inerte.
--
-- Souris (vérifié sur love2d.org/wiki) : coordonnées reçues déjà converties en espace virtuel par
-- main.lua. love.mousepressed/released(x,y,button) avec button==1 pour le clic gauche.
--
-- Interface scène : update / drawWorld / drawOverlay(view) / keypressed / mouse*.

local Board = require("src.board.board")
local Shapes = require("src.board.shapes")
local Rig = require("src.core.rig")
local Creatures = require("src.data.creatures")
local Units = require("src.data.units")
local Encounters = require("src.data.encounters")
local Place = require("src.combat.place")
local Run = require("src.run.state")
local T = require("src.core.i18n").t

local Build = {}
Build.__index = Build

local SPACING = 26
local BOARD_OY = 60

function Build.new(palette, vw, vh, host)
  local self = setmetatable({
    vw = vw, vh = vh, t = 0, palette = palette, host = host,
    titleKey = "scene.build",
    hintKey = "ui.hint_build",
    shapeIdx = 1,
    board = Board.new("carre"),
    slotRigs = {},     -- [slot] = { id, char } : unités posées
    previewRigs = {},  -- [id] = char idle (aperçu boutique)
    drag = nil,        -- { id, char, fromSlot? | fromShop? }
    mx = -100, my = -100,
    combatCount = 0,
  }, Build)
  self:computeLayout()
  self:computeShop()
  for _, id in ipairs(Units.pool) do
    local c = self:newRig(id); c.x, c.y = 0, 0
    self.previewRigs[id] = c
  end
  self.button = { x = vw - 98, y = 150, w = 92, h = 26 } -- COMBAT
  self.rerollBtn = { x = 172, y = 149, w = 44, h = 12 }
  self.levelBtn = { x = 172, y = 163, w = 44, h = 12 }
  if self.host.run then self:syncSlots() end
  return self
end

function Build:newRig(id)
  local c = Rig.new(Creatures[id], self.palette)
  c.facing = 1
  return c
end

-- Centre la forme courante dans la moitié haute du canvas.
function Build:computeLayout()
  local cells = self.board.shape.cells
  local minx, maxx, miny, maxy = math.huge, -math.huge, math.huge, -math.huge
  for _, c in ipairs(cells) do
    minx = math.min(minx, c.x); maxx = math.max(maxx, c.x)
    miny = math.min(miny, c.y); maxy = math.max(maxy, c.y)
  end
  local mx, my = (minx + maxx) / 2, (miny + maxy) / 2
  local ox, oy = self.vw / 2, BOARD_OY
  self.pos = {}
  for i, c in ipairs(cells) do
    self.pos[i] = {
      x = math.floor(ox + (c.x - mx) * SPACING + 0.5),
      y = math.floor(oy + (c.y - my) * SPACING + 0.5),
    }
  end
end

-- Emplacements (rects) des cartes de boutique : positions FIXES, le contenu vit dans host.run.shop.
function Build:computeShop()
  self.shopSlots = {}
  local cw, ch, gap, x0, y0 = 31, 28, 2, 5, 149
  for i = 1, Run.SHOP_SIZE do
    self.shopSlots[i] = { x = x0 + (i - 1) * (cw + gap), y = y0, w = cw, h = ch }
  end
end

-- Aligne les slots débloqués du plateau sur le niveau de la run (ne fait que CROÎTRE au fil du run).
function Build:syncSlots()
  if self.host.run then self.board:unlock(self.host.run.slots) end
end

-- ── Hit-tests (espace virtuel) ──
local function inRect(px, py, r) return px >= r.x and px <= r.x + r.w and py >= r.y and py <= r.y + r.h end

function Build:slotAt(px, py)
  local best, bestD
  for i = 1, 9 do
    if self.board.slots[i].unlocked then
      local p = self.pos[i]
      local dx, dy = px - p.x, py - p.y
      local d = dx * dx + dy * dy
      if d <= 14 * 14 and (not bestD or d < bestD) then best, bestD = i, d end
    end
  end
  return best
end

-- Indice de l'offre de boutique sous le curseur (nil hors boutique / sans run).
function Build:shopAt(px, py)
  local run = self.host.run
  if not run then return nil end
  for i, r in ipairs(self.shopSlots) do
    if run.shop[i] and inRect(px, py, r) then return i end
  end
  return nil
end

function Build:placedCount()
  local n = 0
  for i = 1, 9 do if self.slotRigs[i] then n = n + 1 end end
  return n
end

-- Pose un id sur un slot (aussi appelé par les tests/sim, sans souris ni économie).
function Build:placeId(slot, id)
  if not (self.board.slots[slot] and self.board.slots[slot].unlocked) then return false end
  self.slotRigs[slot] = { id = id, char = self:newRig(id) }
  self.board.slots[slot].unit = id
  return true
end

-- ── Entrées ──
function Build:keypressed(key)
  if key == "s" then -- swap de sigil (libre pour l'instant ; via reliques plus tard, cf. étape #3)
    self.shapeIdx = self.shapeIdx % #Shapes.order + 1
    self.board:setShape(Shapes.order[self.shapeIdx])
    self:computeLayout()
  end
end

function Build:mousemoved(vx, vy)
  self.mx, self.my = vx, vy
end

function Build:mousepressed(vx, vy, button)
  if button ~= 1 then return end
  self.mx, self.my = vx, vy
  if inRect(vx, vy, self.button) then self:startCombat(); return end
  local run = self.host.run
  if run then
    if inRect(vx, vy, self.rerollBtn) then run:reroll(); return end
    if inRect(vx, vy, self.levelBtn) then if run:levelUp() then self:syncSlots() end; return end
    local oi = self:shopAt(vx, vy)
    if oi then -- prend une offre achetable (consommée seulement au lâcher sur une case valide)
      local o = run.shop[oi]
      if o and not o.sold and run.gold >= o.cost then
        self.drag = { id = o.id, char = self:newRig(o.id), fromShop = oi }
      end
      return
    end
  end
  local si = self:slotAt(vx, vy)
  if si and self.slotRigs[si] then -- ramasse une unité déjà posée (réarrangement / vente)
    self.drag = { id = self.slotRigs[si].id, char = self.slotRigs[si].char, fromSlot = si }
    self.slotRigs[si] = nil
    self.board.slots[si].unit = nil
  end
end

function Build:mousereleased(vx, vy, button)
  if button ~= 1 or not self.drag then return end
  local d = self.drag
  self.drag = nil
  local run = self.host.run
  local si = self:slotAt(vx, vy)

  if d.fromShop then
    -- ACHAT : seulement sur une case débloquée et VIDE. L'or n'est débité qu'ici (placement garanti).
    if si and self.board.slots[si].unlocked and not self.slotRigs[si] then
      local id = run and run:buy(d.fromShop)
      if id then
        self.slotRigs[si] = { id = id, char = d.char }
        self.board.slots[si].unit = id
      end
    end
    return
  end

  -- Depuis un slot (l'origine a été vidée au pickup).
  if si and self.board.slots[si].unlocked then
    local occ = self.slotRigs[si]
    if occ and d.fromSlot and si ~= d.fromSlot then -- SWAP : l'occupant repart vers l'origine
      self.slotRigs[d.fromSlot] = occ
      self.board.slots[d.fromSlot].unit = occ.id
    end
    self.slotRigs[si] = { id = d.id, char = d.char }
    self.board.slots[si].unit = d.id
  else
    -- Lâché HORS d'un slot : VENTE (remboursement) si on a une run ; sinon l'unité disparaît (sandbox).
    if run and d.fromSlot then run:sell(d.id) end
  end
end

-- ── Lancement du combat ──
-- Escalade : l'adversaire monte en danger avec le round (IA de seed jusqu'aux snapshots, étape #4).
function Build:pickEncounter()
  local round = (self.host.run and self.host.run.round) or (self.combatCount + 1)
  local idx = math.min(#Encounters, math.floor((round - 1) / 2) + 1)
  return Encounters[idx]
end

-- Assemble la compo posée pour un CÔTÉ (side=-1 gauche / +1 droite), auras d'adjacence résolues.
-- buildLeftComp = buildComp(-1). La sim d'équilibrage utilise les deux côtés (matchups symétriques).
function Build:buildComp(side)
  side = side or -1
  local facing = (side < 0) and 1 or -1
  local placed = {}
  for i = 1, 9 do
    if self.slotRigs[i] then
      local c = self.board.shape.cells[i]
      placed[#placed + 1] = { slot = i, id = self.slotRigs[i].id, col = c.x, row = c.y }
    end
  end
  if #placed == 0 then return {} end

  -- Auras d'adjacence (ex. Rempart) résolues AVANT le combat : état DÉRIVÉ du graphe du plateau.
  -- On lit les descripteurs combat_start/shield_aura (data) — plus aucun `kind` codé en dur.
  -- Changer de sigil re-cible automatiquement via board:neighbors (zéro code par sigil).
  local shield = {}
  for _, p in ipairs(placed) do
    for _, e in ipairs(Units[p.id].effects or {}) do
      if e.trigger == "combat_start" and e.op == "shield_aura" and e.target == "neighbors" then
        for _, nb in ipairs(self.board:neighbors(p.slot)) do
          if self.slotRigs[nb] then shield[nb] = (shield[nb] or 0) + (e.params.value or 0) end
        end
      end
    end
  end

  local maxCol, rowRef = Place.bounds(placed)
  local comp = {}
  for _, p in ipairs(placed) do
    local u = Units[p.id]
    local x, y = Place.pos(p.col, p.row, side, maxCol, rowRef)
    -- depth (0 = front) + row dérivés de la forme -> exposition portée par le sigil (ciblage déterministe).
    comp[#comp + 1] = { id = p.id, slot = p.slot, hp = u.hp, dmg = u.dmg, cd = u.cd,
      depth = maxCol - p.col, row = p.row,
      shield = shield[p.slot] or 0, x = x, y = y, facing = facing }
  end
  return comp
end

function Build:buildLeftComp()
  return self:buildComp(-1)
end

function Build:buildRightComp(enc)
  local maxCol, rowRef = Place.bounds(enc.units)
  local comp = {}
  for _, e in ipairs(enc.units) do
    local u = Units[e.id]
    local x, y = Place.pos(e.col, e.row, 1, maxCol, rowRef)
    comp[#comp + 1] = { id = e.id, hp = u.hp, dmg = u.dmg, cd = u.cd,
      depth = maxCol - e.col, row = e.row,
      shield = 0, x = x, y = y, facing = -1 }
  end
  return comp
end

function Build:startCombat()
  local left = self:buildLeftComp()
  if #left == 0 then return end -- il faut au moins une unité posée
  local enc = self:pickEncounter()
  self.combatCount = self.combatCount + 1
  -- Seed choisi ICI (couche scène) : il fait partie du snapshot/replay. Tiré du RNG seedé du run
  -- (rejouabilité), avec repli sur le RNG global hors-run (tests). La SIM ne lira que ce seed.
  local seed = (self.host.run and self.host.run:nextCombatSeed()) or love.math.random(1, 2147483647)
  self.host.goto("combat",
    { left = left, right = self:buildRightComp(enc), enemyKey = enc.key, seed = seed })
end

-- ── Update ──
function Build:update(frameDt)
  self.t = self.t + frameDt
  if self.host.run and self.board.activeCount ~= self.host.run.slots then self:syncSlots() end
  for i, sr in pairs(self.slotRigs) do
    local p = self.pos[i]
    sr.char.x, sr.char.y = p.x, p.y + 9
    Rig.update(sr.char, self.t, frameDt)
  end
  for _, c in pairs(self.previewRigs) do Rig.update(c, self.t, frameDt) end
  if self.drag then
    self.drag.char.x, self.drag.char.y = self.mx, self.my + 9
    Rig.update(self.drag.char, self.t, frameDt)
  end
end

-- ── Rendu monde (canvas virtuel) ──
function Build:drawWorld()
  local b = self.board
  local hover = self:slotAt(self.mx, self.my)
  local dropTarget = self.drag and hover
  local nbset = {}
  if hover then for _, j in ipairs(b:neighbors(hover)) do nbset[j] = true end end

  -- Arêtes du graphe.
  love.graphics.setLineStyle("rough")
  love.graphics.setLineWidth(1)
  for _, e in ipairs(b.shape.edges) do
    local a, c = e[1], e[2]
    if b.slots[a].unlocked and b.slots[c].unlocked then
      local pa, pc = self.pos[a], self.pos[c]
      if a == hover or c == hover then love.graphics.setColor(0.63, 0.16, 0.14, 0.9)
      else love.graphics.setColor(0.28, 0.24, 0.32, 0.7) end
      love.graphics.line(pa.x, pa.y, pc.x, pc.y)
    end
  end
  love.graphics.setColor(1, 1, 1, 1)

  -- Cases.
  for i = 1, 9 do
    local p, slot = self.pos[i], b.slots[i]
    if not slot.unlocked then
      love.graphics.setColor(0.09, 0.07, 0.11, 0.85)
      love.graphics.rectangle("fill", p.x - 10, p.y - 10, 20, 20)
      love.graphics.setColor(0.20, 0.16, 0.22, 1)
      love.graphics.rectangle("line", p.x - 10, p.y - 10, 20, 20)
    else
      love.graphics.setColor(0.06, 0.05, 0.08, 0.55)
      love.graphics.rectangle("fill", p.x - 11, p.y - 11, 22, 22)
      if i == dropTarget then love.graphics.setColor(0.42, 0.78, 0.40, 1)
      elseif i == hover then love.graphics.setColor(0.85, 0.74, 0.32, 1)
      elseif nbset[i] then love.graphics.setColor(0.63, 0.16, 0.14, 1)
      else love.graphics.setColor(0.32, 0.28, 0.36, 1) end
      love.graphics.rectangle("line", p.x - 11, p.y - 11, 22, 22)
    end
  end
  love.graphics.setColor(1, 1, 1, 1)

  -- Unités posées.
  for i, sr in pairs(self.slotRigs) do
    if b.slots[i].unlocked then Rig.draw(sr.char) end
  end

  -- Panneau boutique (bas).
  love.graphics.setColor(0.05, 0.04, 0.07, 0.88)
  love.graphics.rectangle("fill", 0, 146, self.vw, self.vh - 146)
  love.graphics.setColor(0.20, 0.16, 0.22, 1)
  love.graphics.line(0, 146, self.vw, 146)

  local run = self.host.run
  if run then
    for i, rect in ipairs(self.shopSlots) do
      local o = run.shop[i]
      if o then
        local affordable = (not o.sold) and run.gold >= o.cost
        if o.sold then love.graphics.setColor(0.05, 0.04, 0.06, 1)
        elseif inRect(self.mx, self.my, rect) and affordable then love.graphics.setColor(0.17, 0.13, 0.10, 1)
        else love.graphics.setColor(0.10, 0.08, 0.12, 1) end
        love.graphics.rectangle("fill", rect.x, rect.y, rect.w, rect.h)
        love.graphics.setColor(affordable and 0.42 or 0.22, affordable and 0.32 or 0.18, 0.22, 1)
        love.graphics.rectangle("line", rect.x, rect.y, rect.w, rect.h)
        if not o.sold then
          local c = self.previewRigs[o.id]
          if c then
            love.graphics.push()
            love.graphics.translate(rect.x + rect.w / 2, rect.y + rect.h - 4)
            love.graphics.scale(0.7, 0.7)
            c.x, c.y, c.facing = 0, 0, 1
            Rig.draw(c)
            love.graphics.pop()
          end
        end
      end
    end
    love.graphics.setColor(1, 1, 1, 1)

    -- Boutons REROLL / NIVEAU (libellés en overlay, résolution native).
    local function dbtn(rect, hot, enabled)
      if not enabled then love.graphics.setColor(0.10, 0.09, 0.11, 0.9)
      elseif hot then love.graphics.setColor(0.30, 0.22, 0.12, 1)
      else love.graphics.setColor(0.18, 0.14, 0.10, 1) end
      love.graphics.rectangle("fill", rect.x, rect.y, rect.w, rect.h)
      love.graphics.setColor(enabled and 0.45 or 0.22, 0.34, 0.24, 1)
      love.graphics.rectangle("line", rect.x, rect.y, rect.w, rect.h)
    end
    dbtn(self.rerollBtn, inRect(self.mx, self.my, self.rerollBtn), run:canReroll())
    dbtn(self.levelBtn, inRect(self.mx, self.my, self.levelBtn), run:canLevel())
    love.graphics.setColor(1, 1, 1, 1)
  end

  -- Bouton COMBAT.
  local enabled = self:placedCount() > 0
  local btn = self.button
  local over = inRect(self.mx, self.my, btn)
  if not enabled then love.graphics.setColor(0.12, 0.10, 0.12, 0.9)
  elseif over then love.graphics.setColor(0.55, 0.16, 0.14, 1)
  else love.graphics.setColor(0.34, 0.10, 0.10, 1) end
  love.graphics.rectangle("fill", btn.x, btn.y, btn.w, btn.h)
  love.graphics.setColor(enabled and 0.75 or 0.30, 0.20, 0.18, 1)
  love.graphics.rectangle("line", btn.x, btn.y, btn.w, btn.h)
  love.graphics.setColor(1, 1, 1, 1)

  -- Unité en cours de drag (au-dessus de tout).
  if self.drag then Rig.draw(self.drag.char) end
end

-- ── Overlay (résolution native, texte net) ──
function Build:drawOverlay(view)
  local function project(x, y) return view.ox + x * view.scale, view.oy + y * view.scale end
  local b = self.board
  local run = self.host.run

  -- Titre du sigil.
  local tx, ty = project(self.vw / 2, 8)
  local nm = b.shape.name
  love.graphics.setColor(0.78, 0.72, 0.60, 0.95)
  love.graphics.printf(T("shape." .. nm .. ".label"):upper() .. "  -  " .. T("shape." .. nm .. ".archetype"),
    tx - 200, ty, 400, "center")

  -- HUD de run (ou repli sandbox).
  if run then
    love.graphics.setColor(0.82, 0.76, 0.50, 1)
    love.graphics.printf(T("ui.hud", {
      gold = run.gold, lives = run.lives, maxlives = Run.START_LIVES, wins = run.wins,
      target = Run.WIN_TARGET, round = run.round, level = run.level, slots = run.slots, maxslots = Run.MAX_SLOTS }),
      tx - 300, ty + 16, 600, "center")
    if run.winStreak >= 2 or run.lossStreak >= 2 then
      local won = run.winStreak >= 2
      love.graphics.setColor(won and 0.50 or 0.66, won and 0.60 or 0.28, 0.28, 0.95)
      love.graphics.printf(
        won and T("ui.win_streak", { n = run.winStreak }) or T("ui.loss_streak", { n = run.lossStreak }),
        tx - 200, ty + 30, 400, "center")
    end
  else
    love.graphics.setColor(0.50, 0.42, 0.38, 0.9)
    love.graphics.printf(T("ui.placed_count", { placed = self:placedCount(), active = b.activeCount }),
      tx - 200, ty + 16, 400, "center")
  end

  -- Prix des offres de boutique + libellés des boutons (projetés depuis l'espace virtuel).
  if run then
    love.graphics.setColor(0.86, 0.78, 0.42, 1)
    for i, rect in ipairs(self.shopSlots) do
      local o = run.shop[i]
      if o and not o.sold then
        local px, py = project(rect.x + rect.w / 2, rect.y + 1)
        love.graphics.printf(T("ui.cost", { n = o.cost }), px - 40, py, 80, "center")
      end
    end
    local rx, ry = project(self.rerollBtn.x + self.rerollBtn.w / 2, self.rerollBtn.y + 1)
    love.graphics.setColor(run:canReroll() and 0.82 or 0.40, 0.70, 0.55, 1)
    love.graphics.printf(T("ui.reroll", { n = Run.REROLL_COST }), rx - 90, ry, 180, "center")
    local lx, ly = project(self.levelBtn.x + self.levelBtn.w / 2, self.levelBtn.y + 1)
    if run.level < Run.MAX_LEVEL then
      love.graphics.setColor(run:canLevel() and 0.82 or 0.40, 0.70, 0.55, 1)
      love.graphics.printf(T("ui.level_up", { n = run:levelCost() }), lx - 90, ly, 180, "center")
    else
      love.graphics.setColor(0.45, 0.42, 0.38, 1)
      love.graphics.printf(T("ui.level_max"), lx - 90, ly, 180, "center")
    end
  end

  -- Label bouton COMBAT.
  local bx, by = project(self.button.x + self.button.w / 2, self.button.y + 5)
  love.graphics.setColor(self:placedCount() > 0 and 0.92 or 0.45, 0.82, 0.74, 1)
  love.graphics.printf(T("ui.fight"), bx - 100, by, 200, "center")
  love.graphics.setColor(1, 1, 1, 1)

  -- Infobulle : survol d'une offre de boutique ou d'une case occupée.
  local id
  local oi = self:shopAt(self.mx, self.my)
  if oi then id = run.shop[oi].id
  else
    local si = self:slotAt(self.mx, self.my)
    if si and self.slotRigs[si] then id = self.slotRigs[si].id end
  end
  if id then self:drawTooltip(view, id) end
end

function Build:drawTooltip(view, id)
  local U = Units[id]
  local font = love.graphics.getFont()
  local lh = font:getHeight() + 3
  local bw = 196
  local px = view.ox + self.mx * view.scale + 14
  local py = view.oy + self.my * view.scale + 6
  local sw, sh = love.graphics.getDimensions()
  if px + bw > sw then px = px - bw - 28 end
  local bh = lh * 5 + 8
  if py + bh > sh then py = sh - bh - 4 end

  love.graphics.setColor(0.04, 0.03, 0.05, 0.95)
  love.graphics.rectangle("fill", px, py, bw, bh)
  love.graphics.setColor(0.40, 0.34, 0.42, 1)
  love.graphics.rectangle("line", px, py, bw, bh)

  local x, y = px + 6, py + 4
  love.graphics.setColor(0.82, 0.76, 0.62, 1)
  love.graphics.print(T("ui.unit_header", { name = T("unit." .. id .. ".name"), type = T("type." .. U.type) }), x, y)
  love.graphics.setColor(0.62, 0.58, 0.52, 1)
  love.graphics.print(T("ui.unit_stats", { hp = U.hp, dmg = U.dmg, cd = U.cd }), x, y + lh)
  love.graphics.setColor(0.70, 0.56, 0.30, 1)
  love.graphics.print(T("unit." .. id .. ".passive_name"), x, y + lh * 2)
  love.graphics.setColor(0.58, 0.54, 0.50, 1)
  love.graphics.printf(T("unit." .. id .. ".passive_desc"), x, y + lh * 3, bw - 12, "left")
  love.graphics.setColor(1, 1, 1, 1)
end

return Build
