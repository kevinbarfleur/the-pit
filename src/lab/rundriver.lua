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
  local run = Run.new(seed or 0, { economy = opts.economy })
  local host = { goto = STUB_GOTO, run = run } -- le Build lit host.run (slots, pickEncounter)
  local build = Build.new(opts.palette or Palette, 320, 180, host)
  if opts.sigil then build.board:setShape(opts.sigil); build:computeLayout() end
  return setmetatable({
    run = run, build = build, host = host, opts = opts,
    tickCap = opts.tickCap or 8000,
    hpMult = opts.hpMult, -- bouton global de PV (forwardé à Match.run dans fight) ; nil -> constante Arena.HP_MULT
    relicsKnown = opts.relicsKnown or false, -- reliques pré-connues au Grimoire ? (le driver n'a pas d'IO)
    opponentFn = opts.opponent,              -- (driver) -> compo droite ; défaut PvE escaladante
    over = nil, pendingRelics = nil, lastResult = nil,
    metrics = {
      buys = 0, buyGold = 0,
      sells = 0, sellGold = 0,
      benchSells = 0, benchSellGold = 0,
      boardSells = 0, boardSellGold = 0,
      pairBuys = 0, mergeBuys = 0,
      rerolls = 0, rerollGold = 0,
      xpBuys = 0, xpGold = 0,
      slotAccepts = 0, slotDeclines = 0, slotDeclineGold = 0,
      commanderAccepts = 0, commanderDeclines = 0, commanderDeclineGold = 0,
      relicPicks = 0,
    },
  }, Rundriver)
end

local METRIC_KEYS = {
  "buys", "buyGold", "sells", "sellGold",
  "benchSells", "benchSellGold", "boardSells", "boardSellGold",
  "pairBuys", "mergeBuys",
  "rerolls", "rerollGold", "xpBuys", "xpGold",
  "slotAccepts", "slotDeclines", "slotDeclineGold",
  "commanderAccepts", "commanderDeclines", "commanderDeclineGold",
  "relicPicks",
}

function Rundriver:_metric(key, n)
  self.metrics[key] = (self.metrics[key] or 0) + (n or 1)
end

function Rundriver:metricSnapshot()
  local out = {}
  for _, k in ipairs(METRIC_KEYS) do out[k] = self.metrics[k] or 0 end
  return out
end

local function metricDelta(after, before)
  local out = {}
  for _, k in ipairs(METRIC_KEYS) do out[k] = (after[k] or 0) - (before[k] or 0) end
  return out
end

function Rundriver.shopFullCost(shop)
  local cost = 0
  for _, o in ipairs(shop or {}) do
    if o and not o.sold then cost = cost + (o.cost or 0) end
  end
  return cost
end

-- ── Lecture : état sérialisable (sert au log de trajectoire ET au get_state du MCP) ──
function Rundriver:state()
  local board = {}
  for i = 1, 9 do
    local sr = self.build.slotRigs[i]
    board[i] = { slot = i, unlocked = self.build.board.slots[i].unlocked,
      id = sr and sr.id or nil, level = sr and (sr.level or 1) or nil }
  end
  local bench = {}
  local benchUsed = 0
  for i = 1, #(self.build.benchSlots or {}) do
    local sr = self.build.bench[i]
    if sr then benchUsed = benchUsed + 1 end
    bench[i] = { slot = i, id = sr and sr.id or nil, level = sr and (sr.level or 1) or nil }
  end
  local shop = {}
  for i, o in ipairs(self.run.shop) do shop[i] = { id = o.id, cost = o.cost, sold = o.sold } end
  return {
    round = self.run.round, gold = self.run.gold, lives = self.run.lives,
    wins = self.run.wins, losses = self.run.losses, slots = self.run.slots,
    shopTier = self.run.shopTier, shopXp = self.run.shopXp, xpToNext = self.run:xpToNext(),
    economy = self.run.economy and self.run.economy.id or "baseline",
    rerollCost = self.run:currentRerollCost(), buyXpCost = self.run:currentBuyXpCost(),
    pendingSlotGrant = self.run.pendingSlotGrant, slotGrantsResolved = self.run.slotGrantsResolved,
    sigil = self.build.board.shape.name, winStreak = self.run.winStreak, lossStreak = self.run.lossStreak,
    shop = shop, board = board, relics = #self.run.relics, placed = self.build:placedCount(),
    bench = bench, benchUsed = benchUsed, benchFree = #(self.build.benchSlots or {}) - benchUsed,
    pendingRelics = self.pendingRelics, over = self.over,
  }
end

function Rundriver:firstEmptySlot()
  for i = 1, 9 do
    if self.build.board.slots[i].unlocked and not self.build.slotRigs[i] then return i end
  end
  return nil
end

function Rundriver:firstEmptyBench()
  for i = 1, #(self.build.benchSlots or {}) do
    if not self.build.bench[i] then return i end
  end
  return nil
end

function Rundriver:hasBuySpace()
  return self:firstEmptySlot() ~= nil or self:firstEmptyBench() ~= nil
end

function Rundriver:offerPlayable(shopIndex)
  return self.build:offerPlayable(self.run.shop[shopIndex])
end

function Rundriver:copyCount(id, level)
  if not id then return 0 end
  level = level or 1
  local n = 0
  for i = 1, 9 do
    local sr = self.build.slotRigs[i]
    if sr and sr.id == id and (sr.level or 1) == level then n = n + 1 end
  end
  for i = 1, #(self.build.benchSlots or {}) do
    local sr = self.build.bench[i]
    if sr and sr.id == id and (sr.level or 1) == level then n = n + 1 end
  end
  return n
end

-- ── Actions joueur (toutes renvoient un résultat exploitable ; refus = false/nil, jamais d'exception) ──

-- Achète l'offre i. Sans `slot`, utilise le chemin joueur Build:autoBuy : 1re case board vide, sinon banc,
-- sinon fusion si tout est plein. Avec `slot`, force une pose plateau précise pour les tests/actions ciblées.
-- Dans tous les cas, l'or n'est débité que si le placement/fusion est garanti.
function Rundriver:buy(shopIndex, slot)
  local offer = self.run.shop[shopIndex]
  local cost = offer and offer.cost or 0
  if not offer or offer.sold then return false end
  local sameLevelCopies = self:copyCount(offer.id, 1)
  if slot == nil then
    local id = offer.id
    if not self.build:autoBuy(shopIndex) then return false end
    self:_metric("buys", 1)
    self:_metric("buyGold", cost)
    if sameLevelCopies >= 2 then self:_metric("mergeBuys", 1)
    elseif sameLevelCopies == 1 then self:_metric("pairBuys", 1) end
    return id
  end
  slot = slot or self:firstEmptySlot()
  if not slot then return false end
  local bs = self.build.board.slots[slot]
  if not (bs and bs.unlocked) or self.build.slotRigs[slot] then return false end
  local id = self.run:buy(shopIndex)
  if not id then return false end
  self:_metric("buys", 1)
  self:_metric("buyGold", cost)
  if sameLevelCopies >= 2 then self:_metric("mergeBuys", 1)
  elseif sameLevelCopies == 1 then self:_metric("pairBuys", 1) end
  self.build:placeId(slot, id, 1)
  self.build:checkMerges() -- 3 copies (même id+niveau) -> niveau+1 (cascade)
  return id
end

-- Vend l'unité d'un slot (remboursement) et vide la case.
function Rundriver:sell(slot)
  local sr = self.build.slotRigs[slot]
  if not sr then return false end
  local before = self.run.gold
  self.run:sell(sr.id)
  self:_metric("sells", 1)
  self:_metric("sellGold", self.run.gold - before)
  self:_metric("boardSells", 1)
  self:_metric("boardSellGold", self.run.gold - before)
  self.build.slotRigs[slot] = nil
  self.build.board.slots[slot].unit = nil
  return true
end

function Rundriver:sellBench(slot)
  local sr = self.build.bench[slot]
  if not sr then return false end
  local before = self.run.gold
  self.run:sell(sr.id)
  self:_metric("sells", 1)
  self:_metric("sellGold", self.run.gold - before)
  self:_metric("benchSells", 1)
  self:_metric("benchSellGold", self.run.gold - before)
  self.build.bench[slot] = nil
  return true
end

function Rundriver:reroll()
  local cost = self.run:currentRerollCost()
  local ok = self.run:reroll()
  if ok then
    self:_metric("rerolls", 1)
    self:_metric("rerollGold", cost)
  end
  return ok
end

function Rundriver:buyXp()
  local cost = self.run:currentBuyXpCost()
  local ok = self.run:buyXp()
  if ok then
    self:_metric("xpBuys", 1)
    self:_metric("xpGold", cost)
  end
  return ok
end

-- ── Grant d'emplacement timé (remplace l'ancien levelUp payant). À une offre en attente (run.pendingSlotGrant) :
--   acceptSlotGrant(cell) : +1 capacité + OUVRE une case (la `cell` choisie, ou la meilleure case vide = cluster
--                           central connexe). Renvoie l'index ouvert (placement libre côté UI/politique/MCP).
--   declineSlotGrant()    : refuse -> +or (jeu « tall »), capacité inchangée. ──
function Rundriver:acceptSlotGrant(cell)
  if not self.run:acceptSlotGrant() then return false end
  self:_metric("slotAccepts", 1)
  if not (cell and self.build.board:openCell(cell)) then
    self.build.board:ensureOpen(self.run.slots) -- défaut : ouvre la meilleure case vide (cluster central)
  end
  return true
end

function Rundriver:declineSlotGrant()
  local before = self.run.gold
  local ok = self.run:declineSlotGrant()
  if ok then
    self:_metric("slotDeclines", 1)
    self:_metric("slotDeclineGold", self.run.gold - before)
  end
  return ok
end

function Rundriver:acceptCommanderGrant()
  local ok = self.run:acceptCommanderGrant()
  if ok then self:_metric("commanderAccepts", 1) end
  return ok
end

function Rundriver:declineCommanderGrant()
  local before = self.run.gold
  local ok = self.run:declineCommanderGrant()
  if ok then
    self:_metric("commanderDeclines", 1)
    self:_metric("commanderDeclineGold", self.run.gold - before)
  end
  return ok
end

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
  if require("src.board.board").SIGILS_PAUSED then return false end -- sigils en PAUSE -> action indisponible
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
  local res = Match.run(left, right, seed, { tickCap = self.tickCap, hpMult = self.hpMult })
  res.enemyKey = enemyKey
  self.lastResult = res

  self.run:resolve(res.win)
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
  if id then self.run:grantRelic(id) end
  self.pendingRelics = nil
  self.run:startRound()
  if id then self:_metric("relicPicks", 1) end
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
  local traj = { seed = seed, policy = policy.name, archetype = policy.archetype, rounds = {} }
  local guard = 0
  while not drv.over and guard < 300 do
    guard = guard + 1
    local before = drv:state()
    local shopFullCost = Rundriver.shopFullCost(before.shop)
    local desired = policy.desiredOffers and policy:desiredOffers(drv) or nil
    local desiredGoldBudget = desired and (desired.goldBudget or before.gold) or nil
    local metricBefore = drv:metricSnapshot()
    local decisions = policy:act(drv) -- la politique achète/place/reroll/level/reshape via l'API d'actions
    local afterBuild = drv:state()
    local commitment = policy.commitment and policy:commitment(drv) or nil
    if commitment and commitment.committed and not traj.archetypeCommitRound then
      traj.archetypeCommitRound = before.round
      traj.archetypeCommitment = commitment
    end
    local metricAfter = drv:metricSnapshot()
    local econ = metricDelta(metricAfter, metricBefore)
    if drv.build:placedCount() == 0 then traj.aborted = "empty_board"; break end
    local snap = drv:state()
    local fr = drv:fight()
    if fr.error then traj.aborted = fr.error; break end
    if fr.relicChoices then
      local pick = (policy.pickRelic and policy:pickRelic(drv, fr.relicChoices)) or 1
      drv:pickRelic(pick)
    end
    traj.rounds[#traj.rounds + 1] = {
      round = snap.round, gold = snap.gold, startGold = before.gold, buildGold = afterBuild.gold,
      shopTier = before.shopTier, shopFullCost = shopFullCost,
      couldAffordFullShop = before.gold >= shopFullCost,
      desiredOffers = desired and desired.visibleCount or nil,
      desiredOfferCost = desired and desired.visibleCost or nil,
      desiredPlacableOffers = desired and desired.count or nil,
      desiredPlacableCost = desired and desired.cost or nil,
      desiredGoldBudget = desiredGoldBudget,
      desiredSlotLimited = desired and desired.slotLimited or nil,
      desiredGoldAffordable = desired and ((desired.visibleCount or 0) == 0 or desiredGoldBudget >= (desired.visibleCost or 0)) or nil,
      desiredOffersAffordable = desired and ((desired.visibleCount or 0) == 0 or (desiredGoldBudget >= (desired.visibleCost or 0) and not desired.slotLimited)) or nil,
      slots = snap.slots, sigil = snap.sigil,
      placed = snap.placed, decisions = decisions,
      economy = econ, commitment = commitment,
      win = fr.result and fr.result.win, decided = fr.result and fr.result.decided,
      ticks = fr.result and fr.result.ticks, enemyKey = fr.result and fr.result.enemyKey,
    }
  end
  traj.result = drv.run:isOver() or "incomplete"
  traj.wins, traj.losses, traj.slots = drv.run.wins, drv.run.losses, drv.run.slots
  traj.finalBoard = drv:boardComp()
  traj.finalCost = drv:boardCost()
  traj.metrics = drv:metricSnapshot()
  traj.economy = drv.run.economy and drv.run.economy.id or "baseline"
  if policy.commitment then traj.finalCommitment = policy:commitment(drv) end
  return traj
end

return Rundriver
