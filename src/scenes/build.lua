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
local CreatureGen = require("src.gen.creaturegen") -- visuel généré pour les unités sans rig dessiné main
local Encounters = require("src.data.encounters")
local Place = require("src.combat.place")
local Stats = require("src.effects.stats") -- caps du framework payoff (value bouclier ×3 à la lecture)
local Snapshot = require("src.net.snapshot")
local Snapstore = require("src.net.snapstore")
local Run = require("src.run.state")
local RelicGen = require("src.gen.relicgen") -- icones de reliques (rangee type Slay the Spire + hover)
local Theme = require("src.ui.theme")
local Draw = require("src.ui.draw")
local Ambient = require("src.fx.ambient")
local T = require("src.core.i18n").t

local Build = {}
Build.__index = Build

local SLOT_HALF = 40 -- demi-côté d'une case en espace DESIGN (80x80 ; centre = self.pos[i] ×4)

-- Rangée de RELIQUES possédées (style Slay the Spire) : icônes bakées au-dessus de la boutique, à GAUCHE
-- (bande design x22.. y512 — libre pour tous les sigils : board centré x536+ ou plat) ; survol -> infobulle.
local RELIC_ICON_SCALE = 2          -- icône 16x16 -> 32x32 design (scale entier -> net)
local RELIC_ICON_PX = 16 * RELIC_ICON_SCALE
local RELIC_CELL = 42               -- pas horizontal (icône + gap)
local RELIC_X0, RELIC_Y = 22, 512   -- ancrage design

local SPACING = 26
local BOARD_OY = 90 -- centre du plateau (virtuel) : ×4 = ~360 design, sous l'en-tête, au-dessus de la boutique
local BOARD_HALF_W = 128 -- demi-étendue MAX (virtuelle) des CENTRES de cases -> board centré, jamais hors zone
local BOARD_HALF_H = 44  -- (idem vertical) : un sigil étalé (croix/anneau/ligne) se resserre pour tenir ici
local MAX_LEVEL = 3
local LEVEL_MULT = { 1.0, 1.8, 3.0 } -- stats par niveau : 3 copies (même id+niveau) -> 1 unité niveau+1 (façon TFT)

-- ── Courbe de difficulté (cold-start) — TUNABLES (cf. the-pit-balance-diagnosis). Le board joueur croît de
-- façon PRÉVISIBLE (grants timés 3->9). L'ennemi suit : l'index d'encounter grimpe avec le round (taille),
-- puis au-delà de la table le plus gros gagne des NIVEAUX (bump) pour suivre les merges du joueur fin de run. ──
local ENEMY_LEVEL_START = 11 -- round où l'ennemi cold-start gagne des niveaux (APRÈS la table : pit_sovereign
local ENEMY_LEVEL_EVERY = 3  -- est déjà leveled ; le bump ne sert qu'aux runs très longues, pour ne pas plateau)

function Build.new(palette, vw, vh, host)
  local self = setmetatable({
    vw = vw, vh = vh, t = 0, palette = palette, host = host,
    daChrome = true, -- la scène porte sa propre chrome DA (pas de HUD générique)
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
  self.declineBtn = { x = 172, y = 163, w = 44, h = 12 } -- REFUSER un grant de slot (+or) ; visible si offre en attente
  self.ambient = Ambient.new(3) -- fond calme (mode "build" : dégradé, pas de particules d'ambiance)
  if self.host.run then self:syncSlots() end
  return self
end

function Build:newRig(id)
  -- Visuel : rig dessiné MAIN (Creatures[id], les 6 vanille) sinon créature GÉNÉRÉE procéduralement
  -- (déterministe par id) — COHÉRENT avec le rendu de combat (arena_draw). Boutique = combat.
  local def = Creatures[id]
  if not def then
    local spec = Units[id] or {}
    def = CreatureGen.cached({ id = id, type = spec.type, effects = spec.effects, bodyplan = spec.bodyplan, rank = spec.rank })
  end
  local c = Rig.new(def, self.palette)
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
  -- SPACING ADAPTATIF : on resserre pour que TOUTE forme (3×3, croix/diamant 4×4, anneau, ligne 8×0) tienne
  -- dans la zone du board, centrée -> plus de débordement. Plafonné à SPACING (les petites ne gonflent pas).
  local sp = SPACING
  local extX, extY = maxx - minx, maxy - miny
  if extX > 0 then sp = math.min(sp, 2 * BOARD_HALF_W / extX) end
  if extY > 0 then sp = math.min(sp, 2 * BOARD_HALF_H / extY) end
  local ox, oy = self.vw / 2, BOARD_OY
  self.pos = {}
  for i, c in ipairs(cells) do
    self.pos[i] = {
      x = math.floor(ox + (c.x - mx) * sp + 0.5),
      y = math.floor(oy + (c.y - my) * sp + 0.5),
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

-- Rect (ESPACE DESIGN) de la i-ème relique possédée (rangée au-dessus de la boutique).
function Build:relicRowRect(i)
  return { x = RELIC_X0 + (i - 1) * RELIC_CELL, y = RELIC_Y, w = RELIC_ICON_PX, h = RELIC_ICON_PX }
end

-- Index de la relique survolée (souris en VIRTUEL -> testée ×4 contre les rects design), ou nil.
function Build:relicAt(vx, vy)
  local run = self.host.run
  if not run or #run.relics == 0 then return nil end
  local dx, dy = vx * 4, vy * 4
  for i = 1, #run.relics do
    local r = self:relicRowRect(i)
    if dx >= r.x and dx <= r.x + r.w and dy >= r.y and dy <= r.y + r.h then return i end
  end
  return nil
end

-- Réconcilie l'ensemble des cases OUVERTES à la capacité de la run (ne ferme JAMAIS). Les grants ouvrent
-- des cases PRÉCISES (placement libre via openCell) ; ceci ne sert que de rattrapage si la capacité dépasse
-- l'ouvert (départ, pilotage headless). NE réinitialise PAS en préfixe -> préserve le cluster central + les
-- choix de placement du joueur (décision grants timés 2026-06, cf. the-pit-balance-diagnosis).
function Build:syncSlots()
  if self.host.run then self.board:ensureOpen(self.host.run.slots) end
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

-- Case VERROUILLÉE (non ouverte) sous le curseur : cible de placement d'un grant de slot (placement libre).
function Build:lockedCellAt(px, py)
  local best, bestD
  for i = 1, 9 do
    if not self.board.slots[i].unlocked then
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
function Build:placeId(slot, id, level)
  if not (self.board.slots[slot] and self.board.slots[slot].unlocked) then return false end
  self.slotRigs[slot] = { id = id, level = level or 1, char = self:newRig(id) }
  self.board.slots[slot].unit = id
  return true
end

-- DUPLICATAS (étape gameplay #2) : 3 unités de MÊME id ET MÊME niveau fusionnent en une de niveau+1
-- (cap MAX_LEVEL). Stats + buffs d'adjacence scalent (LEVEL_MULT, appliqué dans buildComp). Cascade :
-- 3 niveau-2 -> 1 niveau-3. Appelé après un AJOUT de copie (achat). Scène (pas SIM) -> non critique au replay.
function Build:checkMerges()
  local merged = true
  while merged do
    merged = false
    local groups = {} -- [id\0level] = { slots... }, en ordre de slot (1->9) pour un résultat stable
    for i = 1, 9 do
      local sr = self.slotRigs[i]
      if sr and (sr.level or 1) < MAX_LEVEL then
        local key = sr.id .. "\0" .. (sr.level or 1)
        local g = groups[key]; if not g then g = {}; groups[key] = g end
        g[#g + 1] = i
      end
    end
    for _, slots in pairs(groups) do
      if #slots >= 3 then
        local keep = slots[1]
        local id, lvl = self.slotRigs[keep].id, (self.slotRigs[keep].level or 1) + 1
        for k = 2, 3 do -- consomme 2 copies
          self.slotRigs[slots[k]] = nil
          self.board.slots[slots[k]].unit = nil
        end
        self.slotRigs[keep] = { id = id, level = lvl, char = self:newRig(id) } -- promeut la 1re
        self.board.slots[keep].unit = id
        merged = true
        break -- re-scan (une promotion peut déclencher une nouvelle fusion)
      end
    end
  end
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
    -- Grant d'emplacement timé en attente : REFUSER (bouton -> +or) ou ACCEPTER (clic sur une case
    -- verrouillée -> ouvre CETTE case = placement libre, façon « pose ton slot où tu veux »).
    if run.pendingSlotGrant then
      if inRect(vx, vy, self.declineBtn) then run:declineSlotGrant(); return end
      local lc = self:lockedCellAt(vx, vy)
      if lc then if run:acceptSlotGrant() then self.board:openCell(lc) end; return end
    end
    local oi = self:shopAt(vx, vy)
    if oi then -- prend une offre achetable (consommée seulement au lâcher sur une case valide)
      local o = run.shop[oi]
      if o and not o.sold and run.gold >= o.cost then
        self.drag = { id = o.id, level = 1, char = self:newRig(o.id), fromShop = oi }
      end
      return
    end
  end
  local si = self:slotAt(vx, vy)
  if si and self.slotRigs[si] then -- ramasse une unité déjà posée (réarrangement / vente)
    self.drag = { id = self.slotRigs[si].id, level = self.slotRigs[si].level or 1, char = self.slotRigs[si].char, fromSlot = si }
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
        self.slotRigs[si] = { id = id, level = 1, char = d.char }
        self.board.slots[si].unit = id
        self:checkMerges() -- 3 copies (même id+niveau) -> fusion en niveau+1
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
    self.slotRigs[si] = { id = d.id, level = d.level or 1, char = d.char }
    self.board.slots[si].unit = d.id
  else
    -- Lâché HORS d'un slot : VENTE (remboursement) si on a une run ; sinon l'unité disparaît (sandbox).
    if run and d.fromSlot then run:sell(d.id) end
  end
end

-- ── Lancement du combat ──
-- Escalade : l'adversaire monte en danger avec le round (IA de seed jusqu'aux snapshots, étape #4).
-- Renvoie (encounter, levelBump) pour le round courant. Pacing `floor((round-1)/2)+1` (un palier tous les 2
-- rounds = le joueur garde une avance de taille pendant qu'il investit), mais NON CAPPÉ : avec 6 encounters il
-- atteint gorge_pack(r7)/drowned_legion(r9)/pit_sovereign(r11, leveled) au lieu de plafonner à brood(5) dès r5
-- (-> late trivial). Au-delà de la table, levelBump suit le board levelé du joueur. (cold-start ; les ghosts
-- de snapshots scalent d'eux-mêmes par tier.)
function Build:pickEncounter()
  local round = (self.host.run and self.host.run.round) or (self.combatCount + 1)
  local idx = math.max(1, math.min(#Encounters, math.floor((round - 1) / 2) + 1))
  local bump = (round >= ENEMY_LEVEL_START) and (1 + math.floor((round - ENEMY_LEVEL_START) / ENEMY_LEVEL_EVERY)) or 0
  return Encounters[idx], bump
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
      placed[#placed + 1] = { slot = i, id = self.slotRigs[i].id, col = c.x, row = c.y, level = self.slotRigs[i].level or 1 }
    end
  end
  if #placed == 0 then return {} end

  -- ── Auras d'adjacence résolues AVANT le combat : état DÉRIVÉ du graphe du sigil (board:neighbors),
  -- fidèle au pilier « la forme EST le graphe de synergies ». AUCUN op combat (comme shield_aura) : on
  -- lit le descripteur combat_start/aura_* (data) et on BAKE le bonus sur le voisin. Changer de sigil
  -- re-cible tout seul. shield_aura -> stat directe ; aura_* -> modifient les EFFETS du voisin (ci-dessous).
  -- NB : notre burn/poison sont en `dps` (pas en pct) -> aura_burn_dps/aura_poison_dps = +dps à plat. ──
  -- Framework PAYOFF : poison/burn AMPLIFIÉS par un `increased` baké sur le PORTEUR (lu par la pose ET le
  -- spread via Stats.resolve, cappé ×3) -> l'investissement se RESSENT partout. rot garde son `growth`
  -- (axe rampe = son identité ; son ampli passe quand même au spread via le `load`). cf. payoff-framework.md §4.
  local shield = {}
  local burnInc, poisonInc, rotGrowth, grantBleed = {}, {}, {}, {}
  for _, p in ipairs(placed) do
    local sm = LEVEL_MULT[p.level] or 1.0 -- l'aura scale avec le NIVEAU de la source (duplicatas) ; cap appliqué à la LECTURE
    for _, e in ipairs(Units[p.id].effects or {}) do
      if e.trigger == "combat_start" and e.target == "neighbors" then
        local op, pa = e.op, e.params or {}
        for _, nb in ipairs(self.board:neighbors(p.slot)) do
          if self.slotRigs[nb] then
            if op == "shield_aura" then shield[nb] = (shield[nb] or 0) + math.floor((pa.value or 0) * sm + 0.5)
            elseif op == "aura_burn_dps" then burnInc[nb] = (burnInc[nb] or 0) + (pa.inc or 0.5) * sm
            elseif op == "aura_poison_dps" then poisonInc[nb] = (poisonInc[nb] or 0) + (pa.inc or 0.5) * sm
            elseif op == "aura_rot_growth" then rotGrowth[nb] = (rotGrowth[nb] or 0) + math.floor((pa.bonus or 0) * sm + 0.5)
            elseif op == "aura_grant_bleed" then grantBleed[nb] = pa
            end
          end
        end
      end
    end
  end

  -- Matérialise les effets d'un voisin SOUS aura (rot growth + grant_bleed seulement ; poison/burn passent
  -- par poisonInc/burnInc sur l'unité). Sinon nil = base (golden-safe).
  local function auraEffects(id, slot)
    if not (rotGrowth[slot] or grantBleed[slot]) then return nil end
    local out = {}
    for _, e in ipairs(Units[id].effects or {}) do
      local pa = {}
      for k, v in pairs(e.params or {}) do pa[k] = v end
      if e.op == "rot" and rotGrowth[slot] then pa.growth = (pa.growth or 1) + rotGrowth[slot] end
      out[#out + 1] = { trigger = e.trigger, op = e.op, params = pa, target = e.target, condition = e.condition }
    end
    if grantBleed[slot] then
      local g = grantBleed[slot]
      out[#out + 1] = { trigger = "on_hit", op = "bleed",
        params = { dps = g.dps or 1, dur = g.dur or 180, slowPct = g.slowPct or 0 } }
    end
    return out
  end

  -- BOUCLIERS PÉRIODIQUES (framework payoff §3) : casters (shield_caster) + renforts (aura_shield adjacente).
  -- Renforts = 5 axes : valeur (valueInc) / cadence (cdr) / réflexion (reflect) / largeur (radius) / surcharge.
  local casters = {} -- [slot] = { value, cd, reflect, overcharge, targetSlots }
  for _, p in ipairs(placed) do
    local sm = LEVEL_MULT[p.level] or 1.0
    for _, e in ipairs(Units[p.id].effects or {}) do
      if e.trigger == "combat_start" and e.op == "shield_caster" then
        local pa = e.params or {}
        local tgt = {}
        for _, nb in ipairs(self.board:neighbors(p.slot)) do if self.slotRigs[nb] then tgt[#tgt + 1] = nb end end
        casters[p.slot] = { baseValue = (pa.value or 20) * sm, cd = pa.cd or 240, reflect = pa.reflect or 0,
          overcharge = pa.overcharge or false, valueInc = 0, cdr = 0, radius = false, targetSlots = tgt }
      end
    end
  end
  if next(casters) then
    for _, p in ipairs(placed) do -- renforts : aura_shield d'un voisin du caster
      for _, e in ipairs(Units[p.id].effects or {}) do
        if e.trigger == "combat_start" and e.op == "aura_shield" then
          local pa = e.params or {}
          for _, nb in ipairs(self.board:neighbors(p.slot)) do
            local c = casters[nb]
            if c then
              c.valueInc = c.valueInc + (pa.valueInc or 0)
              c.cdr = c.cdr + (pa.cdr or 0)
              if pa.reflect then c.reflect = math.max(c.reflect, pa.reflect) end
              if pa.overcharge then c.overcharge = true end
              if pa.radius then c.radius = true end
            end
          end
        end
      end
    end
    for slot, c in pairs(casters) do -- finalise + CAPS (value ×3 / cd plancher 2 s / reflect 0.60 / rayon 2)
      if c.radius then
        local seen = {}; for _, s in ipairs(c.targetSlots) do seen[s] = true end
        local extra = {}
        for _, s in ipairs(c.targetSlots) do
          for _, nb2 in ipairs(self.board:neighbors(s)) do
            if self.slotRigs[nb2] and nb2 ~= slot and not seen[nb2] then seen[nb2] = true; extra[#extra + 1] = nb2 end
          end
        end
        for _, s in ipairs(extra) do c.targetSlots[#c.targetSlots + 1] = s end
      end
      c.value = Stats.resolve(c.baseValue, c.valueInc > 0 and { Stats.increased(c.valueInc) } or nil,
        { max = c.baseValue * 3, round = "nearest" })
      c.cd = math.max(120, math.floor(c.cd * (1 - math.min(0.5, c.cdr))))
      c.reflect = math.min(0.6, c.reflect)
    end
  end

  local b = Place.bounds(placed)
  local comp = {}
  for _, p in ipairs(placed) do
    local u = Units[p.id]
    local x, y = Place.pos(p.col, p.row, side, b)
    -- depth (0 = front) + row dérivés de la forme -> exposition portée par le sigil (ciblage déterministe).
    local m = LEVEL_MULT[p.level] or 1.0 -- duplicatas : les stats scalent avec le niveau
    comp[#comp + 1] = { id = p.id, slot = p.slot, level = p.level,
      hp = math.floor(u.hp * m + 0.5), dmg = math.floor(u.dmg * m + 0.5), cd = u.cd,
      depth = b.maxC - p.col, row = p.row, effects = auraEffects(p.id, p.slot),
      shield = shield[p.slot] or 0, poisonInc = poisonInc[p.slot], burnInc = burnInc[p.slot],
      shieldCaster = casters[p.slot] and { value = casters[p.slot].value, cd = casters[p.slot].cd,
        reflect = casters[p.slot].reflect, overcharge = casters[p.slot].overcharge,
        targetSlots = casters[p.slot].targetSlots } or nil,
      x = x, y = y, facing = facing }
  end
  return comp
end

function Build:buildLeftComp()
  return self:buildComp(-1)
end

-- levelBump (défaut 0) : niveau d'escalade tardive ajouté à chaque unité (cf. pickEncounter). bump=0 + unités
-- sans `level` -> LEVEL_MULT[1]=1.0 = stats de base -> GOLDEN-SAFE (golden appelle buildRightComp sans bump).
function Build:buildRightComp(enc, levelBump)
  levelBump = levelBump or 0
  local b = Place.bounds(enc.units)
  local comp = {}
  for _, e in ipairs(enc.units) do
    local u = Units[e.id]
    local lvl = math.min(MAX_LEVEL, (e.level or 1) + levelBump)
    local m = LEVEL_MULT[lvl] or 1.0
    local x, y = Place.pos(e.col, e.row, 1, b)
    comp[#comp + 1] = { id = e.id, level = lvl,
      hp = math.floor(u.hp * m + 0.5), dmg = math.floor(u.dmg * m + 0.5), cd = u.cd,
      depth = b.maxC - e.col, row = e.row,
      shield = 0, x = x, y = y, facing = -1 }
  end
  return comp
end

-- Build LOGIQUE pour un SNAPSHOT (pilier #3) : {id, level, col, row} des unités posées. Position-indépendant
-- (les positions de combat sont re-dérivées par Snapshot.toComp via Place, par côté).
function Build:snapshotUnits()
  local out = {}
  for i = 1, 9 do
    local sr = self.slotRigs[i]
    if sr then
      local c = self.board.shape.cells[i]
      out[#out + 1] = { id = sr.id, level = sr.level or 1, col = c.x, row = c.y }
    end
  end
  return out
end

function Build:startCombat()
  local left = self:buildLeftComp()
  if #left == 0 then return end -- il faut au moins une unité posée
  if self.host.run then self.host.run:applyRelics(left) end -- reliques : effet RÉEL sur la compo joueur (build)
  local enc, bump = self:pickEncounter()
  self.combatCount = self.combatCount + 1
  -- Seed choisi ICI (couche scène) : il fait partie du snapshot/replay. Tiré du RNG seedé du run
  -- (rejouabilité), avec repli sur le RNG global hors-run (tests). La SIM ne lira que ce seed.
  local seed = (self.host.run and self.host.run:nextCombatSeed()) or love.math.random(1, 2147483647)
  -- SNAPSHOT ASYNC (pilier #3) : on SERT un adversaire depuis le pool (ghost d'un AUTRE build figé) ou,
  -- au cold-start, l'équipe IA (Encounter). Pick SEEDÉ par le seed de combat -> rejouable, sans consommer
  -- le RNG du run. Puis on fige NOTRE build dans le pool pour les adversaires FUTURS (jamais en direct).
  local version, tier = "0.7", (self.host.run and self.host.run.wins) or 0
  local right, oppMeta = Snapstore.serveComp(version, tier, 1,
    love.math.newRandomGenerator(seed), self:buildRightComp(enc, bump))
  Snapstore.save(Snapshot.capture(self:snapshotUnits(), Shapes.order[self.shapeIdx], seed,
    { version = version, tier = tier }))
  self.host.goto("combat",
    { left = left, right = right, enemyKey = enc.key, seed = seed, oppSource = oppMeta and oppMeta.source })
end

-- ── Update ──
function Build:update(frameDt)
  self.t = self.t + frameDt
  self.ambient:update(frameDt)
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

-- État d'interaction (survol/voisins/cible de drop/survol boutique), calculé une fois par frame et
-- partagé entre drawBack (fonds) et drawOverlay (bordures/texte). Coords souris en espace virtuel.
function Build:computeUi()
  local hover = self:slotAt(self.mx, self.my)
  local ui = { hover = hover, dropTarget = self.drag and hover or nil, nbset = {}, shopHover = self:shopAt(self.mx, self.my) }
  if hover then for _, j in ipairs(self.board:neighbors(hover)) do ui.nbset[j] = true end end
  self.uiState = ui -- champ distinct de la méthode (sinon self.uiState renverrait la méthode quand vide)
  return ui
end

-- ── Pre-pass natif (espace design) : atmosphère + arêtes + FONDS (cases / panneau / cartes) ──
-- Tout ce qui doit passer DERRIÈRE les rigs (dessinés ensuite dans le canvas virtuel). pos[i] virtuel ×4.
function Build:drawBack(view)
  local ui = self:computeUi()
  local b, run, c = self.board, self.host.run, Theme.c
  Draw.begin(view)
  self.ambient:draw("build")

  -- Arêtes du graphe de synergies (la forme EST le graphe).
  love.graphics.setLineStyle("rough")
  for _, e in ipairs(b.shape.edges) do
    local a, k = e[1], e[2]
    if b.slots[a].unlocked and b.slots[k].unlocked then
      local pa, pk = self.pos[a], self.pos[k]
      local active = (a == ui.hover or k == ui.hover or a == ui.dropTarget or k == ui.dropTarget)
      Draw.setColor(active and c.edgeActive or c.edgeIdle)
      love.graphics.setLineWidth(active and 4 or 3)
      love.graphics.line(pa.x * 4, pa.y * 4, pk.x * 4, pk.y * 4)
    end
  end
  love.graphics.setLineWidth(1)

  -- Fonds des cases (l'ÉTAT est porté par la bordure en overlay, pas par le fond).
  for i = 1, 9 do
    local p = self.pos[i]
    Draw.rect(p.x * 4 - SLOT_HALF, p.y * 4 - SLOT_HALF, SLOT_HALF * 2, SLOT_HALF * 2,
      b.slots[i].unlocked and c.slot or c.slotLocked)
  end

  -- Panneau boutique + fonds des cartes (derrière les rigs d'aperçu).
  Draw.rect(0, 556, Draw.W, 164, c.panel)
  Draw.setColor(c.line); love.graphics.setLineWidth(2); love.graphics.line(0, 557, Draw.W, 557); love.graphics.setLineWidth(1)
  if run then
    for i, rect in ipairs(self.shopSlots) do
      local o = run.shop[i]
      if o then
        local aff = (not o.sold) and run.gold >= o.cost
        local bg = o.sold and c.void or (aff and ((ui.shopHover == i) and c.cardHover or c.panel) or c.panelDeep)
        Draw.rect(rect.x * 4, rect.y * 4, rect.w * 4, rect.h * 4, bg)
      end
    end
  end

  Draw.finish()
end

-- ── Rendu monde (canvas virtuel, pixel-perfect) : UNIQUEMENT les rigs (unités/aperçus/drag) ──
function Build:drawWorld()
  local b = self.board
  for i, sr in pairs(self.slotRigs) do
    if b.slots[i].unlocked then Rig.draw(sr.char) end
  end
  local run = self.host.run
  if run then
    for i, rect in ipairs(self.shopSlots) do
      local o = run.shop[i]
      if o and not o.sold then
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
  if self.drag then Rig.draw(self.drag.char) end
  love.graphics.setColor(1, 1, 1, 1)
end

-- ── Overlay (espace design, texte net) : chrome + bordures de case + boutique + boutons + infobulle ──
function Build:drawOverlay(view)
  local b, run, c = self.board, self.host.run, Theme.c
  local ui = self.uiState or self:computeUi()
  Draw.begin(view)

  -- Chrome debug (haut-gauche) : court pour ne pas chevaucher la bannière centrée.
  Draw.text(T("ui.title") .. "  -  " .. T("scene.build"):upper(), 16, 14, c.faint, Theme.ui(11))
  Draw.text(T("ui.controls_build"), 16, 32, c.ghost, Theme.ui(9))

  -- Bannière de run (haut-centre) ou repli sandbox.
  if run then self:drawBanner(run)
  else Draw.textC(T("ui.placed_count", { placed = self:placedCount(), active = b.activeCount }), Draw.W / 2, 22, c.faint, Theme.ui(12)) end

  -- Sigil : gothique en CASSE DE TITRE (les capitales blackletter sont illisibles) + archétype.
  local nm = b.shape.name
  Draw.textC(T("shape." .. nm .. ".label"), Draw.W / 2, 70, c.title, Theme.display(36))
  Draw.textC(T("shape." .. nm .. ".archetype"):upper() .. "    " .. T("ui.reshape"), Draw.W / 2, 118, c.faint, Theme.ui(11))
  -- Prompt de grant d'emplacement (event timé) : pose un slot sur une case libre, ou refuse pour de l'or.
  if run and run.pendingSlotGrant then
    Draw.textC(T("ui.slot_grant"), Draw.W / 2, 134, c.gold, Theme.ui(12))
  end

  -- Cases : bordure d'état + décor (verrou / pip de type / pips de niveau / nom).
  local granting = run and run.pendingSlotGrant -- un slot à poser : les cases verrouillées deviennent des cibles
  for i = 1, 9 do
    local p, slot = self.pos[i], b.slots[i]
    local x, y = p.x * 4 - SLOT_HALF, p.y * 4 - SLOT_HALF
    local col
    if not slot.unlocked then col = granting and c.goldBright or c.slotEdgeLck
    elseif i == ui.dropTarget then col = c.drop
    elseif i == ui.hover then col = c.goldBright
    elseif ui.nbset[i] then col = c.blood
    else col = c.slotEdge end
    Draw.rect(x, y, SLOT_HALF * 2, SLOT_HALF * 2, nil, col, 2)
    if not slot.unlocked then
      Draw.textC("+", p.x * 4, p.y * 4 - 12, granting and c.gold or c.lock, Theme.ui(18))
    else
      local sr = self.slotRigs[i]
      if sr then
        Draw.pip(Units[sr.id].type, x + 13, y + 13, 5)
        local lvl = sr.level or 1
        for k = 1, (lvl > 1 and lvl or 0) do
          Draw.rect(x + SLOT_HALF * 2 - 12 - (lvl - k) * 11, y + 7, 7, 7, c.goldBright)
        end
        Draw.textC(T("unit." .. sr.id .. ".name"), p.x * 4, y + SLOT_HALF * 2 + 3, c.name, Theme.ui(9))
      end
    end
  end

  -- Boutique : label + cartes (bordure / coût / nom / SOLD) + boutons éco.
  if run then
    Draw.text(T("ui.offering"), 24, 566, c.faint, Theme.ui(10))
    for i, rect in ipairs(self.shopSlots) do
      local o = run.shop[i]
      if o then
        local x, y, w, h = rect.x * 4, rect.y * 4, rect.w * 4, rect.h * 4
        local aff = (not o.sold) and run.gold >= o.cost
        Draw.rect(x, y, w, h, nil, o.sold and c.line or (aff and c.gold or c.hair), 2)
        if o.sold then
          Draw.textC(T("ui.sold"), x + w / 2, y + h / 2 - 6, c.ghost, Theme.ui(10))
        else
          Draw.pip(Units[o.id].type, x + 11, y + 11, 4)
          Draw.textC(T("unit." .. o.id .. ".name"), x + w / 2, y + h - 36, c.name, Theme.ui(9))
          Draw.textR(T("ui.cost", { n = o.cost }), x + w - 8, y + h - 20, aff and c.gold or c.fainter, Theme.ui(11))
        end
      end
    end
    self:drawEcoButton(self.rerollBtn, T("ui.reroll", { n = Run.REROLL_COST }), run:canReroll())
    -- Bouton REFUSER : visible seulement quand un grant de slot attend (sinon les slots ne s'achètent plus).
    if run.pendingSlotGrant then
      self:drawEcoButton(self.declineBtn, T("ui.decline_slot", { n = Run.SLOT_DECLINE_GOLD }), true)
    end
  end

  -- Bouton COMBAT (gros CTA sang).
  local enabled = self:placedCount() > 0
  local r = self.button
  local over = inRect(self.mx, self.my, r)
  Draw.button(r.x * 4, r.y * 4, r.w * 4, r.h * 4, enabled and T("ui.fight") or T("ui.place_unit"), Theme.uiBold(13),
    { fill = enabled and (over and c.blood or c.bloodDeep) or c.panelDeep,
      border = enabled and c.blood or c.bloodEdge, text = enabled and c.ctaText or c.fainter })

  -- Rangée de reliques possédées (au-dessus de la boutique) + infobulles (relique prioritaire sur unité).
  self:drawRelicRow()
  local relIdx = run and self:relicAt(self.mx, self.my)
  if relIdx then
    self:drawRelicTooltip(run.relics[relIdx].id)
  else
    local id
    local oi = self:shopAt(self.mx, self.my)
    if oi then id = run.shop[oi].id
    else
      local si = self:slotAt(self.mx, self.my)
      if si and self.slotRigs[si] then id = self.slotRigs[si].id end
    end
    if id then self:drawTooltip(id) end
  end

  Draw.finish()
end

-- Bannière de run (deux tons : label éteint + valeur claire), centrée en haut.
function Build:drawBanner(run)
  local c = Theme.c
  local font = Theme.ui(13)
  local seg = {
    { T("ui.gold") .. " ", tostring(run.gold) },
    { T("ui.lives") .. " ", run.lives .. "/" .. Run.START_LIVES },
    { T("ui.wins") .. " ", run.wins .. "/" .. Run.WIN_TARGET },
    { T("ui.round") .. " ", tostring(run.round) },
    { T("ui.slots") .. " ", run.slots .. "/" .. Run.MAX_SLOTS },
  }
  love.graphics.setFont(font)
  local gap, total = 28, 0
  for _, s in ipairs(seg) do total = total + font:getWidth(s[1]) + font:getWidth(s[2]) end
  total = total + gap * (#seg - 1)
  local x = Draw.W / 2 - total / 2
  for _, s in ipairs(seg) do
    Draw.setColor(c.fainter); love.graphics.print(s[1], math.floor(x), 22); x = x + font:getWidth(s[1])
    Draw.setColor(c.title); love.graphics.print(s[2], math.floor(x), 22); x = x + font:getWidth(s[2]) + gap
  end
  if run.winStreak >= 2 or run.lossStreak >= 2 then
    local won = run.winStreak >= 2
    Draw.textC(won and T("ui.win_streak", { n = run.winStreak }) or T("ui.loss_streak", { n = run.lossStreak }),
      Draw.W / 2, 44, won and c.gold or c.blood, Theme.ui(11))
  end
end

-- Bouton d'économie (REROLL / LEVEL) : brun DA, état actif/désactivé + survol. rect en coords virtuelles.
function Build:drawEcoButton(rect, label, enabled)
  local c = Theme.c
  local hot = inRect(self.mx, self.my, rect)
  Draw.button(rect.x * 4, rect.y * 4, rect.w * 4, rect.h * 4, label, Theme.ui(11),
    { fill = not enabled and c.panelDeep or (hot and c.ecoBgHot or c.ecoBg),
      border = enabled and c.ecoBorder or c.hair, text = enabled and c.title or c.fainter })
end

-- Infobulle (espace design ; appelée sous Draw.begin de drawOverlay). Style DA : nom + type coloré,
-- stats éteintes, passif en or, description en lore italique. Position = curseur (mx,my) ×4.
function Build:drawTooltip(id)
  local U, c = Units[id], Theme.c
  local fontN, fontS, fontL = Theme.ui(12), Theme.ui(11), Theme.ui(11) -- desc en Silkscreen (lisible), pas en italique
  local w = 300
  local nameStr, descStr = T("unit." .. id .. ".name"), T("unit." .. id .. ".passive_desc")
  local _, lines = fontL:getWrap(descStr, w - 28)
  local h = 62 + math.max(1, #lines) * (fontL:getHeight() + 2) + 12
  local x, y = self.mx * 4 + 18, self.my * 4 + 10
  if x + w > Draw.W then x = x - w - 36 end
  if y + h > Draw.H then y = Draw.H - h - 8 end

  Draw.rect(x, y, w, h, { c.void[1], c.void[2], c.void[3], 0.96 }, c.hair, 1)
  local ix, iy = x + 14, y + 12
  Draw.text(nameStr, ix, iy, c.title, fontN)
  Draw.text("(" .. T("type." .. U.type) .. ")", ix + fontN:getWidth(nameStr) + 8, iy, Theme.type(U.type).color, fontN)
  Draw.text(T("ui.unit_stats", { hp = U.hp, dmg = U.dmg, cd = U.cd }), ix, iy + 20, c.muted, fontS)
  Draw.text(T("unit." .. id .. ".passive_name"), ix, iy + 40, c.goldBright, fontS)
  Draw.textWrap(descStr, ix, iy + 58, w - 28, c.body, fontL)
end

-- Rangée de reliques possédées : icônes bakées (le vrai artefact) + cadre, surbrillance au survol.
function Build:drawRelicRow()
  local run, c = self.host.run, Theme.c
  if not run or #run.relics == 0 then return end
  local hov = self:relicAt(self.mx, self.my)
  for i, rel in ipairs(run.relics) do
    local r = self:relicRowRect(i)
    local on = (hov == i)
    Draw.rect(r.x - 3, r.y - 3, r.w + 6, r.h + 6, c.panelDeep, on and c.gold or c.hair, on and 2 or 1)
    local baked = RelicGen.cached(rel.id, self.palette)
    if baked and baked.image then
      love.graphics.setColor(1, 1, 1, 1)
      love.graphics.draw(baked.image, r.x, r.y, 0, RELIC_ICON_SCALE, RELIC_ICON_SCALE)
    end
  end
  Draw.reset()
end

-- Infobulle de relique (survol de la rangée) : nom + effet clair (or) + flavor d'ambiance (lore). Style DA.
function Build:drawRelicTooltip(id)
  local c = Theme.c
  local fontN, fontE, fontF = Theme.uiBold(13), Theme.ui(11), Theme.loreRoman(13)
  local w = 320
  local effStr, flavStr = T("relic." .. id .. ".effect"), T("relic." .. id .. ".flavor")
  local _, eLines = fontE:getWrap(effStr, w - 28)
  local _, fLines = fontF:getWrap(flavStr, w - 28)
  local h = 30 + #eLines * (fontE:getHeight() + 2) + 8 + #fLines * (fontF:getHeight() + 1) + 14
  local x, y = self.mx * 4 + 18, self.my * 4 + 10
  if x + w > Draw.W then x = x - w - 36 end
  if y + h > Draw.H then y = Draw.H - h - 8 end
  Draw.rect(x, y, w, h, { c.void[1], c.void[2], c.void[3], 0.96 }, c.gold, 1)
  local ix, iy = x + 14, y + 12
  Draw.text(T("relic." .. id .. ".name"), ix, iy, c.title, fontN)
  iy = iy + 22
  iy = iy + Draw.textWrap(effStr, ix, iy, w - 28, c.goldBright, fontE) + 6
  Draw.textWrap(flavStr, ix, iy, w - 28, c.dim, fontF)
end

return Build
