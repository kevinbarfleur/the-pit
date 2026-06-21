-- src/lab/policies.lua
-- POLITIQUES SCRIPTÉES (Pilier B) : des « joueurs-IA » déterministes qui pilotent une run via l'API
-- d'actions du rundriver (drv:buy/sell/reroll/levelUp/move/reshape/pickRelic). Une politique =
--   { name, act(self, drv) -> décisions, pickRelic?(self, drv, choices) -> index }
-- act() est appelée à chaque phase de build (avant fight). PUR-par-dépendance : n'appelle QUE des
-- méthodes publiques du driver ; aucun love.*, aucun math.random global (le hasard est un RNG INJECTÉ).
--
-- Les personas LLM du Pilier C (MCP) sont la MÊME taxonomie, version qualitative -> on garde des noms
-- parlants (econ / greedy / force_level / committed / random).

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

-- ── 1) GREEDY STATS : monte de niveau dès que confortable, remplit avec tout l'abordable (priorise les
-- premiums via l'ordre boutique). Le « bon joueur » qui dépense tout chaque round. ──
Policies.greedy_stats = {
  name = "greedy_stats",
  act = function(_, drv)
    if drv.run:canLevel() and drv.run.gold >= drv.run:levelCost() + 4 then drv:levelUp() end
    local bought = buyMatching(drv, nil)
    ensureNonEmpty(drv)
    return { leveled = drv.run.level, bought = bought }
  end,
}

-- ── 2) ECON STREAK : ne reroll JAMAIS (épargne), REMPLIT au moins cher puis monte de niveau quand le
-- plateau est plein (et remplit le nouveau slot). Le joueur « éco » qui fait grossir un board solide. ──
Policies.econ_streak = {
  name = "econ_streak",
  act = function(_, drv)
    local cheap = function(id) return (Units[id].cost or 3) <= 3 end
    local bought = buyMatching(drv, cheap)
    ensureNonEmpty(drv)
    while not drv:firstEmptySlot() and drv.run:canLevel() do -- board plein -> niveau -> remplir le slot
      if not drv:levelUp() then break end
      buyMatching(drv, cheap)
    end
    return { leveled = drv.run.level, bought = bought }
  end,
}

-- ── 3) FORCE LEVEL FAST : rushe le niveau (débloque tous les slots au plus vite), achète le strict
-- minimum pour ne pas perdre. Teste « le scaling de board bat-il la qualité de compo ? ». ──
Policies.force_level_fast = {
  name = "force_level_fast",
  act = function(_, drv)
    -- garantit 1 unité pour ne pas auto-perdre, PUIS vide la bourse dans le niveau.
    ensureNonEmpty(drv)
    while drv.run:canLevel() do if not drv:levelUp() then break end end
    buyMatching(drv, nil) -- dépense le reliquat
    return { leveled = drv.run.level }
  end,
}

-- ── 4) COMMITTED ARCHETYPE (factory) : reshape vers `sigil` une fois, n'achète QUE des unités de
-- `archetype` (reroll jusqu'à 2× pour en trouver), filet anti-défaite sinon. Teste une COMPO PRÉCISE. ──
function Policies.committed_archetype(archetype, sigil)
  return {
    name = "committed_" .. archetype,
    archetype = archetype, sigil = sigil,
    act = function(self, drv)
      if sigil and drv.build.board.shape.name ~= sigil then drv:reshape(sigil) end
      local want = function(id) return Policies.archetypeOf(id) == self.archetype end
      -- REMPLIR du bon type d'abord (reroll jusqu'à 2× pour trouver des cases vides à combler).
      local bought = buyMatching(drv, want)
      local rerolls = 0
      while drv:firstEmptySlot() and drv.run:canReroll() and rerolls < 2 do
        drv:reroll(); rerolls = rerolls + 1; bought = bought + buyMatching(drv, want)
      end
      ensureNonEmpty(drv) -- jamais perdre faute d'unité du bon type
      -- board plein -> investir un niveau et combler le nouveau slot du bon archétype.
      while not drv:firstEmptySlot() and drv.run:canLevel() do
        if not drv:levelUp() then break end
        buyMatching(drv, want)
      end
      return { archetype = self.archetype, bought = bought, rerolls = rerolls }
    end,
  }
end

-- ── 5) RANDOM BASELINE (factory, RNG INJECTÉ -> déterministe) : reroll/level/achats au hasard. Le
-- plancher de référence (toute politique sensée doit le battre). ──
function Policies.random_baseline(rng)
  return {
    name = "random_baseline",
    act = function(_, drv)
      if rng:random() < 0.3 and drv.run:canReroll() then drv:reroll() end
      if rng:random() < 0.4 and drv.run:canLevel() then drv:levelUp() end
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

-- Jeu de politiques « batch » par défaut (pour tools/runsim). Le committed couvre les 4 familles DoT.
function Policies.defaultSet(rng)
  return {
    Policies.greedy_stats,
    Policies.econ_streak,
    Policies.force_level_fast,
    Policies.committed_archetype("poison", "diamant"),
    Policies.committed_archetype("burn", "ligne"),
    Policies.committed_archetype("rot", "carre"),
    Policies.committed_archetype("tank", "carre"),
    Policies.random_baseline(rng),
  }
end

return Policies
