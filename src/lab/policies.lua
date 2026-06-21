-- src/lab/policies.lua
-- POLITIQUES SCRIPTÉES (Pilier B) : des « joueurs-IA » déterministes qui pilotent une run via l'API
-- d'actions du rundriver (drv:buy/sell/reroll/acceptSlotGrant/declineSlotGrant/move/reshape/pickRelic).
-- Une politique = { name, act(self, drv) -> décisions, pickRelic?(self, drv, choices) -> index }
-- act() est appelée à chaque phase de build (avant fight). PUR-par-dépendance : n'appelle QUE des
-- méthodes publiques du driver ; aucun love.*, aucun math.random global (le hasard est un RNG INJECTÉ).
--
-- Modèle d'emplacements (décision 2026-06, cf. the-pit-balance-diagnosis) : les slots ne s'achètent plus,
-- ils arrivent en GRANTS timés (rounds 2-7). À chaque offre la politique tranche : ACCEPTER (+1 slot, jeu
-- « wide ») ou REFUSER (+or, jeu « tall » dense). Les politiques explorent donc les deux pôles de cet axe.
--
-- Les personas LLM du Pilier C (MCP) sont la MÊME taxonomie, version qualitative -> on garde des noms
-- parlants (greedy / econ / tall_dense / committed / random).

local Units = require("src.data.units")

local Policies = {}

-- ── Classifieur unité -> archétype (depuis effets/aggro). Réutilisé par committed + l'analyse (runsim). ──
function Policies.archetypeOf(id)
  local u = Units[id]
  if not u then return "bruiser" end
  if u.taunt or (u.aggro and u.aggro >= 40) then return "tank" end
  for _, e in ipairs(u.effects or {}) do
    local op = e.op or ""
    if op == "poison" then return "poison" end
    if op == "burn" then return "burn" end
    if op == "bleed" then return "bleed" end
    if op == "rot" or op == "convert_to_rot" then return "rot" end
    if op == "shock" then return "shock" end
    if op == "regen" then return "tank" end
    if op:find("aura_", 1, true) then
      if op:find("burn", 1, true) then return "burn" end
      if op:find("poison", 1, true) then return "poison" end
      if op:find("bleed", 1, true) then return "bleed" end
      if op:find("rot", 1, true) then return "rot" end
    end
  end
  return "bruiser"
end

-- ── Helpers communs ──
-- Achète les offres affordables passant `want(id)` (ou toutes si want=nil) dans les cases vides.
local function buyMatching(drv, want)
  local n = 0
  for i = 1, #drv.run.shop do
    if not drv:firstEmptySlot() then break end
    local o = drv.run.shop[i]
    if o and not o.sold and drv.run.gold >= o.cost and (not want or want(o.id)) then
      if drv:buy(i) then n = n + 1 end
    end
  end
  return n
end

-- Filet anti-défaite : si le plateau est vide, achète n'importe quelle offre abordable.
local function ensureNonEmpty(drv)
  if drv.build:placedCount() == 0 then buyMatching(drv, nil) end
end

-- Tranche l'offre de slot en attente : `accept`=true -> +1 slot (placement central par défaut, headless) ;
-- false -> refuse pour de l'or. No-op s'il n'y a pas d'offre en attente.
local function resolveGrant(drv, accept)
  if not drv.run.pendingSlotGrant then return end
  if accept then drv:acceptSlotGrant() else drv:declineSlotGrant() end
end

-- ── 1) GREEDY STATS (WIDE) : accepte tout slot offert, remplit avec tout l'abordable (priorise les
-- premiums via l'ordre boutique). Le « bon joueur » qui va large et dépense tout chaque round. ──
Policies.greedy_stats = {
  name = "greedy_stats",
  act = function(_, drv)
    resolveGrant(drv, true)
    local bought = buyMatching(drv, nil)
    ensureNonEmpty(drv)
    return { slots = drv.run.slots, bought = bought }
  end,
}

-- ── 2) ECON STREAK (WIDE, frugal) : ne reroll JAMAIS (épargne), accepte les slots, REMPLIT au moins cher.
-- Le joueur « éco » qui fait grossir un board solide à bas coût et garde de l'or pour les streaks. ──
Policies.econ_streak = {
  name = "econ_streak",
  act = function(_, drv)
    resolveGrant(drv, true)
    local cheap = function(id) return (Units[id].cost or 3) <= 3 end
    local bought = buyMatching(drv, cheap)
    ensureNonEmpty(drv)
    return { slots = drv.run.slots, bought = bought }
  end,
}

-- ── 3) TALL DENSE (factory, le pôle TALL) : accepte les grants jusqu'à `keep` slots puis REFUSE le reste
-- pour de l'or, qu'il convertit en DENSITÉ (reroll -> duplicatas -> merges 3->niveau). Teste l'axe wide-vs-
-- tall que le système de grants introduit : peu d'unités fortes plutôt que beaucoup de faibles. ──
function Policies.tall_dense(keep)
  keep = keep or 5
  return {
    name = "tall_dense",
    keep = keep,
    act = function(self, drv)
      resolveGrant(drv, drv.run.slots < self.keep) -- accepte tant qu'on est sous `keep`, sinon refuse
      local bought = buyMatching(drv, nil)
      ensureNonEmpty(drv)
      -- surplus d'or (gonflé par les refus) -> densité : reroll + rachat (merges via build:checkMerges).
      local rerolls = 0
      while drv.run.gold >= 3 and rerolls < 4 do
        if not drv:reroll() then break end
        rerolls = rerolls + 1
        bought = bought + buyMatching(drv, nil)
      end
      return { slots = drv.run.slots, bought = bought, rerolls = rerolls }
    end,
  }
end

-- ── 4) COMMITTED ARCHETYPE (factory, WIDE themed) : reshape vers `sigil` une fois, accepte les slots,
-- n'achète QUE des unités de `archetype` (reroll jusqu'à 2× pour en trouver), filet anti-défaite sinon. ──
function Policies.committed_archetype(archetype, sigil)
  return {
    name = "committed_" .. archetype,
    archetype = archetype, sigil = sigil,
    act = function(self, drv)
      if sigil and drv.build.board.shape.name ~= sigil then drv:reshape(sigil) end
      resolveGrant(drv, true)
      local want = function(id) return Policies.archetypeOf(id) == self.archetype end
      -- REMPLIR du bon type d'abord (reroll jusqu'à 2× pour trouver des cases vides à combler).
      local bought = buyMatching(drv, want)
      local rerolls = 0
      while drv:firstEmptySlot() and drv.run:canReroll() and rerolls < 2 do
        drv:reroll(); rerolls = rerolls + 1; bought = bought + buyMatching(drv, want)
      end
      ensureNonEmpty(drv) -- jamais perdre faute d'unité du bon type
      return { archetype = self.archetype, bought = bought, rerolls = rerolls }
    end,
  }
end

-- ── 5) RANDOM BASELINE (factory, RNG INJECTÉ -> déterministe) : accepte/refuse, reroll, achats au hasard.
-- Le plancher de référence (toute politique sensée doit le battre). ──
function Policies.random_baseline(rng)
  return {
    name = "random_baseline",
    act = function(_, drv)
      if drv.run.pendingSlotGrant then resolveGrant(drv, rng:random(1, 2) == 1) end
      if rng:random() < 0.3 and drv.run:canReroll() then drv:reroll() end
      -- achète chaque offre abordable avec proba 0.7, dans une case vide
      for i = 1, #drv.run.shop do
        if not drv:firstEmptySlot() then break end
        local o = drv.run.shop[i]
        if o and not o.sold and drv.run.gold >= o.cost and rng:random() < 0.7 then drv:buy(i) end
      end
      ensureNonEmpty(drv)
      return {}
    end,
  }
end

-- Jeu de politiques « batch » par défaut (pour tools/runsim). Couvre les 2 pôles (wide/tall) + 4 familles DoT.
function Policies.defaultSet(rng)
  return {
    Policies.greedy_stats,
    Policies.econ_streak,
    Policies.tall_dense(5),
    Policies.committed_archetype("poison", "diamant"),
    Policies.committed_archetype("burn", "ligne"),
    Policies.committed_archetype("rot", "carre"),
    Policies.committed_archetype("tank", "carre"),
    Policies.random_baseline(rng),
  }
end

return Policies
