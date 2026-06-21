-- src/lab/rundriver.lua
-- PILOTE DE RUN headless — la COLONNE VERTÉBRALE du banc d'essai (Piliers B et C).
-- Combine l'ÉTAT DE RUN réel (src/run/state, économie SIM-pure) + un vrai Build (plateau/placement/fusion/
-- buildComp aura-résolu) + le runner de match. Il REJOUE la méta-boucle du host (resolve -> observe ->
-- offre de relique -> startRound) SANS aucune IO Grimoire. Expose une API D'ACTIONS JOUEUR sérialisable :
--   state / buy / sell / reroll / acceptSlotGrant / declineSlotGrant / move / reshape / pickRelic / fight
-- que consomment AUSSI BIEN les politiques scriptées (Pilier B, tools/runsim) que les outils MCP (Pilier C).
--
-- ⚠️ RENDER-tainted (construit un Build = scène). HORS firewall SIM ; ne jamais le require depuis
-- src/combat|board|effects|run. Tout est SEEDÉ (RunState + nextCombatSeed) : (seed + suite d'actions)
-- -> partie 100% REJOUABLE. Tourne headless sous luajit + tests/mock_love (comme tools/sim.lua).

local Run = require("src.run.state")
local Build = require("src.scenes.build")
local Shapes = require("src.board.shapes")
local Match = require("src.combat.match")
local Compcost = require("src.lab.compcost")
local Palette = require("src.core.palette")

local Rundriver = {}
Rundriver.__index = Rundriver

local STUB_GOTO = function() end

function Rundriver.new(seed, opts)
  opts = opts or {}
  local run = Run.new(seed or 0)
  local host = { goto = STUB_GOTO, run = run } -- le Build lit host.run (slots, pickEncounter)
  local build = Build.new(opts.palette or Palette, 320, 180, host)
  if opts.sigil then build.board:setShape(opts.sigil); build:computeLayout() end
  return setmetatable({
    run = run, build = build, host = host, opts = opts,
    tickCap = opts.tickCap or 8000,
    relicsKnown = opts.relicsKnown or false, -- reliques pré-connues au Grimoire ? (le driver n'a pas d'IO)
    opponentFn = opts.opponent,              -- (driver) -> compo droite ; défaut PvE escaladante
    over = nil, pendingRelics = nil, lastResult = nil,
  }, Rundriver)
end

-- ── Lecture : état sérialisable (sert au log de trajectoire ET au get_state du MCP) ──
function Rundriver:state()
  local board = {}
  for i = 1, 9 do
    local sr = self.build.slotRigs[i]
    board[i] = { slot = i, unlocked = self.build.board.slots[i].unlocked,
      id = sr and sr.id or nil, level = sr and (sr.level or 1) or nil }
  end
  local shop = {}
  for i, o in ipairs(self.run.shop) do shop[i] = { id = o.id, cost = o.cost, sold = o.sold } end
  return {
    round = self.run.round, gold = self.run.gold, lives = self.run.lives,
    wins = self.run.wins, losses = self.run.losses, slots = self.run.slots,
    pendingSlotGrant = self.run.pendingSlotGrant, slotGrantsResolved = self.run.slotGrantsResolved,
    sigil = self.build.board.shape.name, winStreak = self.run.winStreak, lossStreak = self.run.lossStreak,
    shop = shop, board = board, relics = #self.run.relics, placed = self.build:placedCount(),
    pendingRelics = self.pendingRelics, over = self.over,
  }
end

function Rundriver:firstEmptySlot()
  for i = 1, 9 do
    if self.build.board.slots[i].unlocked and not self.build.slotRigs[i] then return i end
  end
  return nil
end

-- ── Actions joueur (toutes renvoient un résultat exploitable ; refus = false/nil, jamais d'exception) ──

-- Achète l'offre i et la pose sur `slot` (ou la 1re case vide). Mirroir EXACT de l'achat de build.lua :
-- l'or n'est débité que si le placement est garanti (case débloquée ET vide), puis fusion des duplicatas.
function Rundriver:buy(shopIndex, slot)
  slot = slot or self:firstEmptySlot()
  if not slot then return false end
  local bs = self.build.board.slots[slot]
  if not (bs and bs.unlocked) or self.build.slotRigs[slot] then return false end
  local id = self.run:buy(shopIndex)
  if not id then return false end
  self.build:placeId(slot, id, 1)
  self.build:checkMerges() -- 3 copies (même id+niveau) -> niveau+1 (cascade)
  return id
end

-- Vend l'unité d'un slot (remboursement) et vide la case.
function Rundriver:sell(slot)
  local sr = self.build.slotRigs[slot]
  if not sr then return false end
  self.run:sell(sr.id)
  self.build.slotRigs[slot] = nil
  self.build.board.slots[slot].unit = nil
  return true
end

function Rundriver:reroll() return self.run:reroll() end

-- ── Grant d'emplacement timé (remplace l'ancien levelUp payant). À une offre en attente (run.pendingSlotGrant) :
--   acceptSlotGrant(cell) : +1 capacité + OUVRE une case (la `cell` choisie, ou la meilleure case vide = cluster
--                           central connexe). Renvoie l'index ouvert (placement libre côté UI/politique/MCP).
--   declineSlotGrant()    : refuse -> +or (jeu « tall »), capacité inchangée. ──
function Rundriver:acceptSlotGrant(cell)
  if not self.run:acceptSlotGrant() then return false end
  if not (cell and self.build.board:openCell(cell)) then
    self.build.board:ensureOpen(self.run.slots) -- défaut : ouvre la meilleure case vide (cluster central)
  end
  return true
end

function Rundriver:declineSlotGrant() return self.run:declineSlotGrant() end

-- Déplace/échange une unité de `from` vers `to` (mirroir du drag case->case de build.lua).
function Rundriver:move(from, to)
  local d = self.build.slotRigs[from]
  if not d then return false end
  local bs = self.build.board.slots[to]
  if not (bs and bs.unlocked) then return false end
  local occ = self.build.slotRigs[to]
  self.build.slotRigs[to] = d; self.build.board.slots[to].unit = d.id
  if occ and from ~= to then
    self.build.slotRigs[from] = occ; self.build.board.slots[from].unit = occ.id
  elseif from ~= to then
    self.build.slotRigs[from] = nil; self.build.board.slots[from].unit = nil
  end
  return true
end

-- Reshape le plateau vers un sigil (la topologie/adjacence change ; les unités restent dans leurs slots).
function Rundriver:reshape(sigil)
  if not Shapes[sigil] then return false end
  self.build.board:setShape(sigil)
  self.build:computeLayout()
  return true
end

-- ── Adversaire : PvE escaladante (encounters par round) par défaut ; pluggable via opts.opponent ──
function Rundriver:opponent()
  if self.opponentFn then return self.opponentFn(self) end
  local enc, bump = self.build:pickEncounter()
  return self.build:buildRightComp(enc, bump), enc.key
end

-- ── Combat + avancement de la méta-boucle (mirroir de host.finishCombat, SANS IO Grimoire) ──
-- Renvoie { result, over?, relicChoices? }. Si relicChoices : le round N'EST PAS avancé -> il FAUT
-- appeler pickRelic ensuite (l'agent/la politique choisit). Sinon le round suivant est ouvert (startRound).
function Rundriver:fight()
  local left = self.build:buildLeftComp()
  if #left == 0 then return { error = "empty_board" } end
  self.run:applyRelics(left) -- reliques : effet RÉEL sur la compo joueur (comme au build)
  local right, enemyKey = self:opponent()
  local seed = self.run:nextCombatSeed()
  local res = Match.run(left, right, seed, { tickCap = self.tickCap })
  res.enemyKey = enemyKey
  self.lastResult = res

  self.run:resolve(res.win)
  self.run:observeRelics() -- avance l'observation des reliques cryptiques (le host inscrirait au Grimoire ; pas nous)
  self.over = self.run:isOver()
  if self.over then return { result = res, over = self.over } end

  -- Acquisition : tous les 3 victoires, offre 1-parmi-3 (le round attend le choix).
  if res.win and self.run.wins % 3 == 0 then
    local choices = self.run:rollRelicChoices(3)
    if #choices > 0 then self.pendingRelics = choices; return { result = res, relicChoices = choices } end
  end
  self.run:startRound()
  return { result = res }
end

-- Choisit une relique parmi l'offre en attente (index 1..n), l'octroie, puis ouvre le round suivant.
function Rundriver:pickRelic(choiceIndex)
  if not self.pendingRelics then return false end
  local id = self.pendingRelics[choiceIndex or 1]
  if id then self.run:grantRelic(id, self.relicsKnown) end
  self.pendingRelics = nil
  self.run:startRound()
  return id or false
end

-- ── Coût d'investissement du board courant (réutilise Compcost, comme une compo de catalogue) ──
function Rundriver:boardComp()
  local units = {}
  for i = 1, 9 do
    local sr = self.build.slotRigs[i]
    if sr then units[#units + 1] = { id = sr.id, slot = i, level = sr.level or 1 } end
  end
  return { sigil = self.build.board.shape.name, boardLevel = self.run.slots, units = units }
end

function Rundriver:boardCost() return Compcost.of(self:boardComp()) end

-- ── Run COMPLÈTE pilotée par une politique -> trajectoire (rounds + décisions + issue + investissement) ──
-- policy = { name, act(self, drv) -> décisions, pickRelic?(self, drv, choices) -> index }.
function Rundriver.run(seed, policy, opts)
  local drv = Rundriver.new(seed, opts)
  local traj = { seed = seed, policy = policy.name, rounds = {} }
  local guard = 0
  while not drv.over and guard < 300 do
    guard = guard + 1
    local decisions = policy:act(drv) -- la politique achète/place/reroll/level/reshape via l'API d'actions
    if drv.build:placedCount() == 0 then traj.aborted = "empty_board"; break end
    local snap = drv:state()
    local fr = drv:fight()
    if fr.error then traj.aborted = fr.error; break end
    if fr.relicChoices then
      local pick = (policy.pickRelic and policy:pickRelic(drv, fr.relicChoices)) or 1
      drv:pickRelic(pick)
    end
    traj.rounds[#traj.rounds + 1] = {
      round = snap.round, gold = snap.gold, slots = snap.slots, sigil = snap.sigil,
      placed = snap.placed, decisions = decisions,
      win = fr.result and fr.result.win, decided = fr.result and fr.result.decided,
      ticks = fr.result and fr.result.ticks, enemyKey = fr.result and fr.result.enemyKey,
    }
  end
  traj.result = drv.run:isOver() or "incomplete"
  traj.wins, traj.losses, traj.slots = drv.run.wins, drv.run.losses, drv.run.slots
  traj.finalBoard = drv:boardComp()
  traj.finalCost = drv:boardCost()
  return traj
end

return Rundriver
