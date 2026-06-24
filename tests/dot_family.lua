-- tests/dot_family.lua
-- LINT de la FAMILLE DoT DÉCLARATIVE (U.dotFamily, M2/2.4 — « type » des synergies P1 + Grimoire).
-- Garantit COUVERTURE et COHÉRENCE : toute unité qui pose/amplifie un DoT déclare sa famille, et la famille
-- déclarée est BIEN une famille que l'unité produit RÉELLEMENT (lue de l'`op`, pas du nom). Les unités sans
-- DoT ne doivent PAS être déclarées. Module PUR (aucun love) ; data non lue par la SIM -> golden inchangé.
--   Lancement : luajit tests/dot_family.lua
package.path = "./?.lua;" .. package.path

local U = require("src.data.units")

-- op -> famille qu'il IMPLIQUE (poseurs de base, auras, croisés, spreads). Les ops absents = non-affligeants.
local OP_FAMILY = {
  poison = "poison", burn = "burn", bleed = "bleed", rot = "rot", shock = "shock",
  aura_poison_dps = "poison", aura_burn_dps = "burn", aura_grant_bleed = "bleed", aura_rot_growth = "rot",
  spread_burn_on_death = "burn", spread_rot = "rot", convert_to_rot = "rot",
}
-- Familles dont la pose de BASE peut être à 0 dps (effet utilitaire pur : slow/weaken) -> ne compte PAS.
local DPS_GATED = { poison = true, burn = true, bleed = true }
local VALID = { burn = true, bleed = true, poison = true, rot = true, shock = true }

-- Ensemble des familles RÉELLEMENT produites par une unité (op réel ; dps>0 pour les familles dps-gated).
local function familiesOf(def)
  local set = {}
  for _, e in ipairs(def.effects or {}) do
    local fam = OP_FAMILY[e.op]
    if fam then
      local p = e.params or {}
      if not (DPS_GATED[e.op] and (not p.dps or p.dps <= 0)) then
        set[fam] = true
      end
    end
  end
  return set
end

local function sortedKeys(set)
  local t = {}
  for k in pairs(set) do t[#t + 1] = k end
  table.sort(t)
  return t
end

local ok, err = pcall(function()
  local covered = 0
  -- 1) couverture + cohérence par unité (parcours déterministe via U.order)
  for _, id in ipairs(U.order) do
    local def = U[id]
    assert(def, "unite inconnue dans U.order : " .. tostring(id))
    local set = familiesOf(def)
    local fam = U.dotFamily[id]
    if next(set) ~= nil then
      covered = covered + 1
      assert(fam, "unite a DoT sans dot_family declaree : " .. id)
      if not set[fam] then
        error("dot_family '" .. tostring(fam) .. "' n'est PAS une famille produite par " .. id
          .. " (familles reelles : " .. table.concat(sortedKeys(set), ",") .. ")")
      end
    else
      assert(fam == nil, "unite SANS DoT mais dot_family declaree (" .. tostring(fam) .. ") : " .. id)
    end
  end

  -- 2) aucune entree orpheline : toute cle = une unite reelle, a DoT, famille valide
  local declared = 0
  for id, fam in pairs(U.dotFamily) do
    declared = declared + 1
    assert(U[id], "dot_family declare pour une unite inexistante : " .. tostring(id))
    assert(next(familiesOf(U[id])) ~= nil, "dot_family declare pour une unite SANS DoT : " .. id)
    assert(VALID[fam], "famille DoT invalide pour " .. id .. " : " .. tostring(fam))
  end

  -- 3) couverture EXACTE : autant de declarations que d'unites a DoT (aucune oubliee, aucune en trop)
  assert(declared == covered,
    "couverture incomplete : " .. declared .. " declarees vs " .. covered .. " unites a DoT reelles")

  -- distribution (informative)
  local byFam = {}
  for _, fam in pairs(U.dotFamily) do byFam[fam] = (byFam[fam] or 0) + 1 end
  print(string.format(
    "  dot_family : %d unites a DoT couvertes (burn %d / bleed %d / poison %d / rot %d / shock %d) ; 0 orpheline OK",
    covered, byFam.burn or 0, byFam.bleed or 0, byFam.poison or 0, byFam.rot or 0, byFam.shock or 0))
end)

if ok then
  print("=> DOT_FAMILY OK : couverture + coherence (op reel vs famille declaree).")
else
  print("=> DOT_FAMILY FAIL :")
  print(err)
  os.exit(1)
end
