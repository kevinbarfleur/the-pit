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

-- ── RELIQUES : cadence + refus + paliers (PRD progression-economy §5.1/§5.3, Lot 4) ──
-- Le MARCHAND passe tous les 3 COMBATS (victoire OU défaite), pas toutes les 3 victoires (cf. host).
-- À chaque offre 1-parmi-3, on peut REFUSER pour +DECLINE_RELIC_GOLD or (calque exact du refus de slot).
local DECLINE_RELIC_GOLD = 3   -- or reçu en refusant l'offre de relique (≈ le prix d'1 unité ; PLACEHOLDER tunable)

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

-- ── NIVEAU DE BOUTIQUE (PRD progression-economy §3, modèle TFT : XP passive + achetée) ──
-- La boutique a un tier 1->5 et une BARRE D'XP vers le suivant. On gagne de l'XP de DEUX façons :
--   · PASSIVE : +PASSIVE_XP_PER_ROUND à chaque round (sauf le round 1 = départ) -> évolution GARANTIE même
--     sans investir (sinon un joueur qui n'achète jamais resterait tier 1 toute la partie : bizarre).
--   · ACHETÉE : bouton BUY XP = BUY_XP_AMOUNT d'XP pour BUY_XP_COST or (ratio 1:1) -> accélère, rush des hauts rangs.
-- C'est de l'ODDS-gating (cotes), pas du slot-gating : on monte une distribution, pas une case vide.
-- Le nombre d'offres reste SHOP_SIZE quel que soit le tier ; monter change seulement QUELS RANGS sortent.
-- ⚠️ Tous les chiffres (XP, seuils, cotes) sont des PLACEHOLDERS à calibrer via tools/sim.lua (Lot 7).
-- INTENTION DE CALIBRAGE (placeholders, ne pas hard-tuner ici) : un joueur PUREMENT PASSIF atteint ~tier 3
--   en fin de partie (pas tier 5) ; un joueur qui dépense de l'or en XP rush le tier 5 vers le milieu. Avec
--   passif 1/round (à partir du round 2), l'XP cumulée au round R vaut R-1, donc tier 3 (cumul 7) tombe ~round 8
--   et tier 4 (cumul 15) ~round 16 -> passif ≈ tier 3 en fin de partie typique.
local MAX_TIER      = 5
local START_TIER    = 1
local PASSIVE_XP_PER_ROUND = 1  -- XP gagnée à chaque round (à partir du round 2) — placeholder
local BUY_XP_AMOUNT        = 4  -- XP obtenue par achat — placeholder
local BUY_XP_COST          = 4  -- or pour BUY_XP_AMOUNT d'XP (ratio 1:1) — placeholder
local XP_TO_LEVEL = { [1] = 2, [2] = 5, [3] = 8, [4] = 12 } -- XP pour passer DE tier i à i+1 (placeholder ; cumul T2=2/T3=7/T4=15/T5=27)
-- Cotes par tier : % de chance par slot de tirer une unité de chaque RANG (chaque ligne somme à 100).
local ODDS = {
  [1] = { 100,  0,  0,  0,  0 },
  [2] = {  70, 30,  0,  0,  0 },
  [3] = {  44, 34, 20,  2,  0 },
  [4] = {  25, 30, 30, 13,  2 },
  [5] = {  15, 20, 30, 25, 10 },
}

-- Pool d'unités achetables (ids). Défaut : le roster complet.
local POOL = Units.pool or Units.order

-- Index des ids du POOL par RANG, construit UNE FOIS au chargement, DÉTERMINISTE (ipairs, jamais pairs) :
-- POOL_BY_RANK[r] = { ids de rang r... } dans l'ordre du POOL. roll() y pioche après avoir tiré un rang.
local POOL_BY_RANK = {}
for r = 1, MAX_TIER do POOL_BY_RANK[r] = {} end
for _, id in ipairs(POOL) do
  local u = Units[id]
  local r = u and u.rank
  if r and POOL_BY_RANK[r] then
    local bucket = POOL_BY_RANK[r]
    bucket[#bucket + 1] = id
  end
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
    slots = START_SLOTS,           -- capacité du plateau (cases qu'on PEUT ouvrir) ; croît par grants timés
    pendingSlotGrant = false,      -- une offre de slot attend une décision (accepter/refuser) ce round
    slotGrantsResolved = 0,        -- nb d'offres déjà tranchées (accept OU refus) ; plafonné à MAX_GRANTS
    winStreak = 0,
    lossStreak = 0,
    shopTier = START_TIER,         -- niveau de boutique (1->5) : gate QUELS rangs apparaissent (cotes ODDS)
    shopXp = 0,                    -- XP de boutique accumulée vers le tier suivant (cascade par XP_TO_LEVEL)
    shopOddsShift = 0,             -- Lot 6 : décalage PERSISTANT du tier utilisé POUR LES COTES (relique beggars_lantern = -1). 0 = identique au tier réel.
    shop = {},
    relics = {}, -- possédées : { { id } } (modèle LISIBLE : effet affiché ; collection Grimoire inscrite au grant)
    relicFromLevelThisRound = false, -- Lot 5 (§5.2) : une seule récompense de relique par level-up et PAR round
    chronicles = {}, -- HISTORIQUE des journaux de combat (1 par combat) pour le sélecteur de round (UI, hors éco)
  }, RunState)
  self:startRound()
  return self
end

-- Archive le journal d'un combat (entries sérialisées) pour consultation ultérieure via le sélecteur de
-- round. PUR (ids/équipes/nombres) ; hors économie -> n'affecte pas le déterminisme du run.
function RunState:archiveChronicle(entries, meta)
  meta = meta or {}
  self.chronicles[#self.chronicles + 1] = {
    round = meta.round or self.round, win = meta.win, enemyKey = meta.enemyKey, entries = entries or {},
  }
end

-- Tire un RANG (1..MAX_TIER) selon une ligne de cotes `odds` (fournie par roll() = ODDS du tier décalé),
-- par poids cumulés. On tire 1..100 puis on additionne les poids rang 1->MAX_TIER : le 1er rang dont le
-- total cumulé atteint le tirage est retourné. Comme chaque ligne d'ODDS somme à 100, un rang est toujours désigné.
local function rollRank(self, odds)
  local roll = self.rng:random(1, 100)
  local acc = 0
  for r = 1, MAX_TIER do
    acc = acc + odds[r]
    if roll <= acc then return r end
  end
  return MAX_TIER -- garde-fou numérique (ne devrait jamais arriver : la ligne somme à 100)
end

-- Choisit le bucket d'ids d'un rang ; si vide (défensif — tous les rangs 1..5 sont peuplés), retombe sur
-- le rang non-vide inférieur le plus proche, sinon le POOL entier. Garantit un id à piocher.
local function bucketForRank(rank)
  for r = rank, 1, -1 do
    local b = POOL_BY_RANK[r]
    if b and #b > 0 then return b end
  end
  return POOL
end

-- (Re)tire la boutique : SHOP_SIZE offres (doublons permis, comme SAP/TFT). Chaque slot = 2 tirages RNG :
-- (1) un RANG selon les cotes du tier (rollRank), puis (2) un id au hasard dans ce rang.
-- Lot 6 : les cotes utilisent le tier DÉCALÉ (shopOddsShift, ex. beggars_lantern = -1), borné à [1,MAX_TIER].
-- Avec shopOddsShift == 0 (défaut), tier == shopTier -> comportement STRICTEMENT identique (déterminisme/cotes conservés).
function RunState:roll()
  local tier = math.max(1, math.min(MAX_TIER, self.shopTier + self.shopOddsShift))
  local odds = ODDS[tier]
  local shop = {}
  for i = 1, SHOP_SIZE do
    local rank = rollRank(self, odds)
    local bucket = bucketForRank(rank)
    local id = bucket[self.rng:random(1, #bucket)]
    shop[i] = { id = id, cost = unitCost(id), sold = false }
  end
  self.shop = shop
end

-- Ouvre un nouveau round : or FRAIS (modèle SAP) + bonus de série, filet de vie, boutique re-tirée.
-- Le plateau (les unités posées) PERSISTE entre les rounds : seuls l'or et la boutique se renouvellent.
function RunState:startRound()
  self.round = self.round + 1
  -- Lot 5 (§5.2) : nouvelle fenêtre de round -> la récompense de level-up (relique) redevient disponible.
  self.relicFromLevelThisRound = false
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
  -- XP PASSIVE de boutique (TFT-style) : +PASSIVE_XP_PER_ROUND, mais SEULEMENT à partir du round 2 — le
  -- round 1 est le DÉPART (aucun temps écoulé) -> un run frais est proprement tier 1 / xp 0. La cascade de
  -- tier est gérée par addShopXp. N'utilise PAS self.rng -> la suite RNG (offres/seeds) est inchangée.
  if self.round > 1 then self:addShopXp(PASSIVE_XP_PER_ROUND) end
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

-- ── NIVEAU DE BOUTIQUE (cotes par tier). On monte par l'XP (passive + achetée), pas en payant le tier. ──

-- Ajoute n d'XP de boutique, puis CASCADE : tant que le seuil du tier courant est atteint, on consomme le
-- seuil et on monte d'un tier (un gros gain peut traverser plusieurs tiers). Au tier MAX, l'XP n'accumule
-- plus (barre pleine/masquée) -> shopXp figé à 0. Ne touche JAMAIS self.rng (déterminisme des offres préservé).
function RunState:addShopXp(n)
  if self.shopTier >= MAX_TIER then return end
  self.shopXp = self.shopXp + n
  while self.shopTier < MAX_TIER and self.shopXp >= XP_TO_LEVEL[self.shopTier] do
    self.shopXp = self.shopXp - XP_TO_LEVEL[self.shopTier]
    self.shopTier = self.shopTier + 1
  end
  if self.shopTier >= MAX_TIER then self.shopXp = 0 end
end

-- XP requise pour passer DU tier courant au suivant (nil au max -> barre « MAX » côté UI).
function RunState:xpToNext()
  return (self.shopTier >= MAX_TIER) and nil or XP_TO_LEVEL[self.shopTier]
end

-- Lot 6 : monte le tier de boutique DIRECTEMENT de n (défaut 1), borné à MAX_TIER (relique « rush » shop_tier_up).
-- Au tier max, l'XP partielle est remise à 0 (barre pleine, cohérent avec addShopXp). NE touche PAS self.rng.
function RunState:raiseShopTier(n)
  self.shopTier = math.min(MAX_TIER, self.shopTier + (n or 1))
  if self.shopTier >= MAX_TIER then self.shopXp = 0 end
end

-- Peut-on acheter de l'XP ? Pas au tier max, et on a de quoi payer.
function RunState:canBuyXp()
  return self.shopTier < MAX_TIER and self.gold >= BUY_XP_COST
end

-- Achète BUY_XP_AMOUNT d'XP pour BUY_XP_COST or (peut faire monter un ou plusieurs tiers via la cascade).
-- Renvoie true si effectué, false sinon. NE tire PAS de self.rng.
function RunState:buyXp()
  if not self:canBuyXp() then return false end
  self.gold = self.gold - BUY_XP_COST
  self:addShopXp(BUY_XP_AMOUNT)
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

-- ── PALIER DE RELIQUE par AVANCÉE DE RUN (PRD §5.3 : universel tôt, build-definer tard) ──
-- Plafond de tier autorisé dans l'offre selon les victoires : early (0-1 win) -> stats simples/universelles
-- (tier ≤2) ; mid (2-4) -> ampli conditionnel (≤3) ; late (5+) -> transformatives (≤4). Ainsi le seuil
-- « 2+ afflictions » (plague_communion, tier 4) n'apparaît QUE quand on a déjà de quoi le nourrir.
function RunState:maxRelicTier()
  if self.wins < 2 then return 2 elseif self.wins < 5 then return 3 else return 4 end
end

-- Tire jusqu'à n ids DISTINCTS de reliques NON possédées (seedé) : l'offre 1-parmi-n de l'écran de relique.
-- Tiérée par avancée (maxRelicTier) : on ne propose QUE des reliques de tier ≤ plafond. FALLBACK : si moins
-- de n candidats existent à ce plafond, on élargit à TOUTES les non possédées -> une offre est toujours
-- remplissable (le pool ne s'assèche pas tant qu'il reste des reliques). Fisher-Yates seedé -> rejouable.
function RunState:rollRelicChoices(n)
  n = n or 3
  local cap = self:maxRelicTier()
  local all = {}   -- toutes les non possédées (pour le fallback)
  local capped = {} -- celles sous le plafond de tier (le pool nominal)
  for _, id in ipairs(Relics.order) do
    local owned = false
    for _, r in ipairs(self.relics) do if r.id == id then owned = true; break end end
    if not owned then
      all[#all + 1] = id
      if (Relics[id].tier or 1) <= cap then capped[#capped + 1] = id end
    end
  end
  -- Pool nominal = celles sous le plafond ; on n'élargit à TOUT que s'il n'y en a pas assez pour n choix.
  local avail = (#capped >= n) and capped or all
  for i = #avail, 2, -1 do -- Fisher-Yates seedé (RNG du run) -> rejouable
    local j = self.rng:random(1, i)
    avail[i], avail[j] = avail[j], avail[i]
  end
  local out = {}
  for i = 1, math.min(n, #avail) do out[i] = avail[i] end
  return out
end

-- REFUSE l'offre de relique : +DECLINE_RELIC_GOLD or (calque exact de declineSlotGrant : on échange le
-- choix contre de l'or). N'inscrit RIEN au Grimoire (rien d'appris). Renvoie l'or accordé.
function RunState:declineRelic()
  self.gold = self.gold + DECLINE_RELIC_GOLD
  return DECLINE_RELIC_GOLD
end

-- Octroie une relique (modèle LISIBLE : on ne stocke que l'id ; l'effet est affiché). Le host inscrit
-- la relique au Grimoire (collection cross-run) au moment du grant. Args extra ignorés (compat appelants).
function RunState:grantRelic(id)
  local relic = Relics[id]
  if not relic then return false end
  for _, r in ipairs(self.relics) do if r.id == id then return false end end -- pas de doublon (anti double-grant)
  self.relics[#self.relics + 1] = { id = id }
  -- Lot 6 (§3.4) : les reliques de BOUTIQUE portent un `runOp` appliqué AU GRANT sur le RUN (pas la compo de
  -- combat). Dispatch unique (le doublon est déjà refusé ci-dessus -> un runOp ne s'applique qu'une fois).
  local runOp = relic.runOp
  if runOp then
    local p = relic.params or {}
    if runOp == "shop_xp" then self:addShopXp(p.amount or 0)
    elseif runOp == "shop_tier_up" then self:raiseShopTier(1)
    elseif runOp == "shop_tier_down" then self.shopOddsShift = self.shopOddsShift - 1
    end
  end
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
RunState.DECLINE_RELIC_GOLD = DECLINE_RELIC_GOLD
RunState.MAX_TIER = MAX_TIER
RunState.START_TIER = START_TIER
RunState.PASSIVE_XP_PER_ROUND = PASSIVE_XP_PER_ROUND
RunState.BUY_XP_AMOUNT = BUY_XP_AMOUNT
RunState.BUY_XP_COST = BUY_XP_COST
RunState.XP_TO_LEVEL = XP_TO_LEVEL
RunState.ODDS = ODDS

return RunState
