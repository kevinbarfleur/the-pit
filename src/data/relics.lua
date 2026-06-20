-- src/data/relics.lua
-- RELIQUES CRYPTIQUES (pilier #2, signature du jeu). L'effet est CACHÉ : l'infobulle montre 3 CANDIDATS
-- (le vrai + 2 leurres), MÉLANGÉS par run (seedé). Le vrai effet (`op`) s'applique quand même au build ;
-- le joueur le DÉDUIT par observation, puis le verrouille au Grimoire (lore permanent au niveau compte).
--
-- DATA quasi-pure : on require Units uniquement pour matérialiser les effets ajoutés (copie, jamais de
-- mutation de la base). Aucun love. L'op TRANSFORME la compo du joueur au build (cf. RunState:applyRelics).
--
-- Modèle : { id, op, params, realKey, decoys = { key1, key2 } }
--   realKey  = clé i18n de la VRAIE description (celle à identifier).
--   decoys   = 2 clés i18n de fausses descriptions plausibles (les leurres du 1-parmi-3).

local Units = require("src.data.units")

local R = {
  bloodstone = { id = "bloodstone", op = "relic_more_dmg", params = { mult = 0.20 },
    realKey = "relic.bloodstone.real", decoys = { "relic.bloodstone.d1", "relic.bloodstone.d2" } },
  carapace = { id = "carapace", op = "relic_flat_hp", params = { value = 15 },
    realKey = "relic.carapace.real", decoys = { "relic.carapace.d1", "relic.carapace.d2" } },
  ember_heart = { id = "ember_heart", op = "relic_add_effect",
    params = { effect = { trigger = "on_attack", op = "bonus_first", params = { value = 6 } } },
    realKey = "relic.ember_heart.real", decoys = { "relic.ember_heart.d1", "relic.ember_heart.d2" } },
  venom_sigil = { id = "venom_sigil", op = "relic_add_effect",
    params = { effect = { trigger = "on_attacked", op = "thorns", params = { value = 3 } } },
    realKey = "relic.venom_sigil.real", decoys = { "relic.venom_sigil.d1", "relic.venom_sigil.d2" } },
  gravewax = { id = "gravewax", op = "relic_add_effect",
    params = { effect = { trigger = "combat_start", op = "regen", params = { value = 2 } } },
    realKey = "relic.gravewax.real", decoys = { "relic.gravewax.d1", "relic.gravewax.d2" } },
}

R.order = { "bloodstone", "carapace", "ember_heart", "venom_sigil", "gravewax" }

-- Applique l'effet RÉEL d'une relique à une compo (liste de specs d'unités), au BUILD. Modifie en place.
-- Effets ajoutés : on matérialise une COPIE des effets du spec (jamais de mutation de la base Units).
function R.apply(comp, relic)
  local op, p = relic.op, relic.params or {}
  for _, spec in ipairs(comp) do
    if op == "relic_more_dmg" then
      spec.dmg = math.floor(spec.dmg * (1 + (p.mult or 0)) + 0.5)
    elseif op == "relic_flat_hp" then
      spec.hp = spec.hp + (p.value or 0)
    elseif op == "relic_add_effect" and p.effect then
      local base = spec.effects or (Units[spec.id] and Units[spec.id].effects) or {}
      local eff = {}
      for _, e in ipairs(base) do eff[#eff + 1] = e end -- copie superficielle (on n'AJOUTE que)
      eff[#eff + 1] = p.effect
      spec.effects = eff
    end
  end
end

-- Les 3 clés candidates d'une relique (vraie + 2 leurres), AVANT mélange (le mélange est seedé par run).
function R.candidateKeys(id)
  local r = R[id]
  if not r then return {} end
  return { r.realKey, r.decoys[1], r.decoys[2] }
end

return R
