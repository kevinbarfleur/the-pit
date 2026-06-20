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
local START_LEVEL     = 1
local MAX_LEVEL       = START_LEVEL + (MAX_SLOTS - START_SLOTS) -- 7 : niveau où slots atteint 9
local LIFE_BACK_ROUND = 3      -- début de CE round : +1 vie si on a déjà perdu (filet SAP)
local STREAK_CAP      = 3      -- bonus d'or max par série
local SELL_REFUND_FRAC = 0.5   -- remboursement à la revente (< coût -> aucun exploit)
local DEFAULT_COST    = 3      -- coût si une unité n'en déclare pas

-- Pool d'unités achetables (ids). Défaut : le roster complet.
local POOL = Units.pool or Units.order

-- Coût pour passer DU niveau L à L+1 (croissant). 1->2:5, 2->3:6, ... 6->7:10.
local function levelCostAt(level) return 4 + level end

-- Slots débloqués à un niveau donné (1 slot par niveau au-dessus du départ).
local function slotsForLevel(level)
  return math.min(MAX_SLOTS, START_SLOTS + (level - START_LEVEL))
end

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
    level = START_LEVEL,
    slots = slotsForLevel(START_LEVEL),
    winStreak = 0,
    lossStreak = 0,
    shop = {},
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

function RunState:levelCost() return levelCostAt(self.level) end

function RunState:canLevel() return self.level < MAX_LEVEL and self.gold >= self:levelCost() end

-- Monte d'un niveau : débloque le slot suivant (slots dérivés du niveau).
function RunState:levelUp()
  if self.level >= MAX_LEVEL then return false end
  local cost = self:levelCost()
  if self.gold < cost then return false end
  self.gold = self.gold - cost
  self.level = self.level + 1
  self.slots = slotsForLevel(self.level)
  return true
end

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

-- Constantes exposées (UI/tests) — lecture seule.
RunState.GOLD_PER_ROUND = GOLD_PER_ROUND
RunState.REROLL_COST = REROLL_COST
RunState.SHOP_SIZE = SHOP_SIZE
RunState.START_LIVES = START_LIVES
RunState.WIN_TARGET = WIN_TARGET
RunState.START_SLOTS = START_SLOTS
RunState.MAX_SLOTS = MAX_SLOTS
RunState.MAX_LEVEL = MAX_LEVEL

return RunState
