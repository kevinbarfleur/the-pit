-- src/run/state.lua
-- ÉTAT DE RUN roguelite : la méta qui enrobe la boucle build -> combat -> build. Logique PURE :
-- aucun love.graphics/window/mouse — seulement love.math.newRandomGenerator (autorisé en couche SIM,
-- exactement comme arena.lua). Donc 100% testable headless (tests/run.lua) et DÉTERMINISTE : tout le
-- hasard (offres de boutique, seeds de combat) sort d'un RNG seedé -> un run rejouable à actions égales.
--
-- Modèle (cf. docs/research/gd-research-result.md §1.6-1.7, docs/research/combat-model-decision.md) :
--   · or FIXE par round (modèle SAP) : budget FRAIS chaque round (PAS de banque ni d'intérêt — V2).
--   · boutique : SHOP_SIZE offres aléatoires à acheter ; le reroll re-tire ; l'offre est consommée à
--     l'achat. Le PLACEMENT sur le plateau reste à la charge de la scène (couche UI) — ici, pure éco.
--   · leveling PAYANT (SAP/TFT) : monter de niveau débloque le slot suivant (START_SLOTS -> MAX_SLOTS).
--   · run : START_LIVES vies, WIN_TARGET victoires ; -1 vie par défaite ; +1 vie au début du round
--     LIFE_BACK_ROUND si on a déjà perdu une vie (filet anti-tilt SAP) ; fin : "win"/"lose".
--   · streaks : bonus d'or par série (victoires OU défaites = comeback), plafonné à STREAK_CAP.
--
-- ⚠️ Tous les CHIFFRES ci-dessous sont des PLACEHOLDERS d'équilibrage (à tuner via tools/sim.lua quand
-- les plateaux se rempliront) — la STRUCTURE est actée, pas les valeurs.

local Units = require("src.data.units")
local Relics = require("src.data.relics")

local RunState = {}
RunState.__index = RunState

-- ── Constantes d'équilibrage (tunables) ──
local GOLD_PER_ROUND  = 10
local REROLL_COST     = 1
local SHOP_SIZE       = 5
local START_LIVES     = 5
local WIN_TARGET      = 10
local START_SLOTS     = 3
local MAX_SLOTS       = 9
local LIFE_BACK_ROUND = 3      -- début de CE round : +1 vie si on a déjà perdu (filet SAP)
local STREAK_CAP      = 3      -- bonus d'or max par série
local SELL_REFUND_FRAC = 0.5   -- remboursement à la revente (< coût -> aucun exploit)
local DEFAULT_COST    = 3      -- coût si une unité n'en déclare pas

-- ── Emplacements de plateau = GRANTS TIMÉS (décision 2026-06, cf. the-pit-balance-diagnosis) ──
-- On NE PAYE PLUS pour débloquer un slot (le couplage or↔slot était un piège dégénéré : lever à chaque
-- round drainait l'or -> board vide -> mort 0-6). À la place, façon SAP (tier de boutique timé), chaque
-- joueur reçoit AUTOMATIQUEMENT un emplacement à des rounds prédéfinis. À chaque offre, il ACCEPTE (+1 slot,
-- à poser librement côté plateau) OU REFUSE (+SLOT_DECLINE_GOLD or, et renonce DÉFINITIVEMENT à ce slot).
-- Refuser = jouer « tall » (peu d'unités fortes/denses) plutôt que « wide » : un vrai axe build-dépendant.
-- L'or ne sert donc plus qu'aux UNITÉS + reroll. La capacité (slots) est découplée de l'économie.
local SLOT_GRANT_ROUNDS = { [2] = true, [3] = true, [4] = true, [5] = true, [6] = true, [7] = true }
local MAX_GRANTS        = MAX_SLOTS - START_SLOTS -- 6 offres au total (3 -> 9)
local SLOT_DECLINE_GOLD = 3      -- or reçu en refusant un slot (≈ le prix d'1 unité ; PLACEHOLDER tunable)

-- Pool d'unités achetables (ids). Défaut : le roster complet.
local POOL = Units.pool or Units.order

local function unitCost(id)
  local u = Units[id]
  return (u and u.cost) or DEFAULT_COST
end

-- Bonus d'or de série : streak 0-1 -> 0, 2 -> 1, 3 -> 2, 4+ -> STREAK_CAP. Victoires OU défaites.
local function streakBonus(self)
  local s = math.max(self.winStreak, self.lossStreak)
  return math.max(0, math.min(STREAK_CAP, s - 1))
end

-- ── Construction : démarre directement au round 1 (or distribué, boutique tirée) ──
function RunState.new(seed)
  seed = seed or 0
  local self = setmetatable({
    seed = seed,
    rng = love.math.newRandomGenerator(seed),
    gold = 0,
    lives = START_LIVES,
    wins = 0,
    losses = 0,
    round = 0,
    slots = START_SLOTS,           -- capacité du plateau (cases qu'on PEUT ouvrir) ; croît par grants timés
    pendingSlotGrant = false,      -- une offre de slot attend une décision (accepter/refuser) ce round
    slotGrantsResolved = 0,        -- nb d'offres déjà tranchées (accept OU refus) ; plafonné à MAX_GRANTS
    winStreak = 0,
    lossStreak = 0,
    shop = {},
    relics = {}, -- possédées : { { id } } (modèle LISIBLE : effet affiché ; collection Grimoire inscrite au grant)
  }, RunState)
  self:startRound()
  return self
end

-- (Re)tire la boutique : SHOP_SIZE offres aléatoires (doublons permis, comme SAP/TFT).
function RunState:roll()
  local shop = {}
  for i = 1, SHOP_SIZE do
    local id = POOL[self.rng:random(1, #POOL)]
    shop[i] = { id = id, cost = unitCost(id), sold = false }
  end
  self.shop = shop
end

-- Ouvre un nouveau round : or FRAIS (modèle SAP) + bonus de série, filet de vie, boutique re-tirée.
-- Le plateau (les unités posées) PERSISTE entre les rounds : seuls l'or et la boutique se renouvellent.
function RunState:startRound()
  self.round = self.round + 1
  -- Filet anti-tilt (SAP) : au début du round LIFE_BACK_ROUND, +1 vie si on a déjà perdu une vie.
  if self.round == LIFE_BACK_ROUND and self.lives < START_LIVES then
    self.lives = math.min(START_LIVES, self.lives + 1)
  end
  self.gold = GOLD_PER_ROUND + streakBonus(self)
  self:roll()
  -- Grant d'emplacement timé (façon tier SAP) : à un round prévu, tant qu'il reste des offres, on présente
  -- un slot à placer ou refuser. La capacité ne bouge PAS ici — c'est accept/declineSlotGrant qui tranche.
  if SLOT_GRANT_ROUNDS[self.round] and self.slotGrantsResolved < MAX_GRANTS then
    self.pendingSlotGrant = true
  end
end

-- ── EMPLACEMENTS DE PLATEAU (grants timés). Le RUN ne tient que la CAPACITÉ (combien de cases ouvrables)
-- et l'offre en attente ; QUELLE case s'ouvre est géré par le plateau/la scène (couche placement). ──

function RunState:canGrant() return self.pendingSlotGrant end

-- ACCEPTE l'offre : +1 capacité de slot (la scène ouvre ensuite la case choisie). Renonce à l'offre.
function RunState:acceptSlotGrant()
  if not self.pendingSlotGrant then return false end
  self.slots = math.min(MAX_SLOTS, self.slots + 1)
  self.pendingSlotGrant = false
  self.slotGrantsResolved = self.slotGrantsResolved + 1
  return true
end

-- REFUSE l'offre : +SLOT_DECLINE_GOLD or, capacité INCHANGÉE (slot renoncé définitivement = jeu « tall »).
function RunState:declineSlotGrant()
  if not self.pendingSlotGrant then return false end
  self.gold = self.gold + SLOT_DECLINE_GOLD
  self.pendingSlotGrant = false
  self.slotGrantsResolved = self.slotGrantsResolved + 1
  return true
end

-- Achète l'offre i : déduit l'or, consomme l'offre, renvoie l'id acheté (ou nil si invalide/trop cher).
-- La scène, elle, gère le placement sur un slot — l'achat ne touche QUE l'économie.
function RunState:buy(i)
  local offer = self.shop[i]
  if not offer or offer.sold then return nil end
  if self.gold < offer.cost then return nil end
  self.gold = self.gold - offer.cost
  offer.sold = true
  return offer.id
end

function RunState:canReroll() return self.gold >= REROLL_COST end

function RunState:reroll()
  if not self:canReroll() then return false end
  self.gold = self.gold - REROLL_COST
  self:roll()
  return true
end

-- Remboursement à la revente d'une unité posée (la scène retire l'unité du plateau).
function RunState:sellRefund(id) return math.max(1, math.floor(unitCost(id) * SELL_REFUND_FRAC)) end

function RunState:sell(id) self.gold = self.gold + self:sellRefund(id) end

-- Résout l'issue d'un combat. NE distribue PAS l'or (c'est startRound, au round suivant).
function RunState:resolve(win)
  if win then
    self.wins = self.wins + 1
    self.winStreak = self.winStreak + 1
    self.lossStreak = 0
  else
    self.losses = self.losses + 1
    self.lives = self.lives - 1
    self.lossStreak = self.lossStreak + 1
    self.winStreak = 0
  end
end

-- "win" (objectif atteint) / "lose" (plus de vie) / nil (le run continue).
function RunState:isOver()
  if self.wins >= WIN_TARGET then return "win" end
  if self.lives <= 0 then return "lose" end
  return nil
end

-- Seed du PROCHAIN combat, tiré du RNG seedé du run -> chaque combat est rejouable (snapshot/replay).
function RunState:nextCombatSeed() return self.rng:random(1, 2147483647) end

-- ── RELIQUES (chantier 2026-06, modèle LISIBLE — cf. docs/research/relics-design.md). Le RUN reste SIM-PUR :
-- il ne porte que la POSSESSION ({ id }). L'effet est affiché clairement (plus de candidats/identification).
-- La collection Grimoire (IO, cross-run) est inscrite par le HOST au GRANT (Grimoire.learn), hors SIM. ──

-- Tire un id de relique au hasard (seedé) parmi celles PAS encore possédées (nil si tout est pris).
function RunState:rollRelic()
  local avail = {}
  for _, id in ipairs(Relics.order) do
    local owned = false
    for _, r in ipairs(self.relics) do if r.id == id then owned = true; break end end
    if not owned then avail[#avail + 1] = id end
  end
  if #avail == 0 then return nil end
  return avail[self.rng:random(1, #avail)]
end

-- Tire jusqu'à n ids DISTINCTS de reliques NON possédées (seedé) : l'offre 1-parmi-n de l'écran de relique.
function RunState:rollRelicChoices(n)
  local avail = {}
  for _, id in ipairs(Relics.order) do
    local owned = false
    for _, r in ipairs(self.relics) do if r.id == id then owned = true; break end end
    if not owned then avail[#avail + 1] = id end
  end
  for i = #avail, 2, -1 do -- Fisher-Yates seedé (RNG du run) -> rejouable
    local j = self.rng:random(1, i)
    avail[i], avail[j] = avail[j], avail[i]
  end
  local out = {}
  for i = 1, math.min(n or 3, #avail) do out[i] = avail[i] end
  return out
end

-- Octroie une relique (modèle LISIBLE : on ne stocke que l'id ; l'effet est affiché). Le host inscrit
-- la relique au Grimoire (collection cross-run) au moment du grant. Args extra ignorés (compat appelants).
function RunState:grantRelic(id)
  if not Relics[id] then return false end
  for _, r in ipairs(self.relics) do if r.id == id then return false end end -- pas de doublon
  self.relics[#self.relics + 1] = { id = id }
  return true
end

-- Applique l'effet de chaque relique possédée à la compo du joueur (au build, avant combat).
function RunState:applyRelics(comp)
  for _, r in ipairs(self.relics) do Relics.apply(comp, Relics[r.id]) end
end

-- Constantes exposées (UI/tests) — lecture seule.
RunState.GOLD_PER_ROUND = GOLD_PER_ROUND
RunState.REROLL_COST = REROLL_COST
RunState.SHOP_SIZE = SHOP_SIZE
RunState.START_LIVES = START_LIVES
RunState.WIN_TARGET = WIN_TARGET
RunState.START_SLOTS = START_SLOTS
RunState.MAX_SLOTS = MAX_SLOTS
RunState.MAX_GRANTS = MAX_GRANTS
RunState.SLOT_DECLINE_GOLD = SLOT_DECLINE_GOLD

return RunState
