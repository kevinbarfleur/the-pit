-- src/data/relics.lua
-- RELIQUES (chantier 2026-06, cf. docs/research/relics-design.md). Modèle LISIBLE : l'effet est AFFICHÉ
-- clairement (plus de leurres ni d'identification ; on garde l'ambiance via nom + flavor, et la collection
-- via le Grimoire). Une relique = un buff TEAM-WIDE appliqué à la compo du joueur AU BUILD (R.apply).
--
-- PRINCIPES (garde-fous, cf. doc §1) : lisible ; AUCUN handicap persistant cross-combat (intra-combat only) ;
-- égalisateur de matchup (incline, jamais un gate 100%) ; chaque relique a un foyer ; déterministe.
--
-- DATA quasi-pure : require Units uniquement pour matérialiser un effet ajouté (copie, jamais de mutation de
-- la base). Aucun love. L'op TRANSFORME la compo du joueur au build (cf. RunState:applyRelics).
--
-- Modèle : { id, op, params, tier } — i18n : relic.<id>.name / .effect / .flavor.
--   tier : 1 = commune (stats plates) · 2 = ampli conditionnel · 3+ = paliers/transformatives (vagues ult.).
-- ⚠️ Les CHIFFRES (inc/frac/value) sont des PLACEHOLDERS d'équilibrage (à tuner via tools/runsim.lua).

local Units = require("src.data.units")

local R = {
  -- ── A — stats plates (communes, universelles) ──
  bloodstone = { id = "bloodstone", op = "relic_more_dmg",   params = { mult = 0.20 }, tier = 1 },
  carapace   = { id = "carapace",   op = "relic_flat_hp",    params = { value = 15 },  tier = 1 },
  aegis      = { id = "aegis",      op = "relic_dmg_reduce", params = { frac = 0.15 }, tier = 1 },

  -- ── B — amplis d'affliction (le cœur build-shaping : récompense le mono-archétype) ──
  -- Poison = APEX -> ampli CONSERVATEUR (0.20) ; familles faibles (burn/bleed/rot) -> ampli plus généreux (0.30).
  kings_bowl   = { id = "kings_bowl",   op = "relic_affliction_inc", params = { family = "poison", inc = 0.20 }, tier = 2 },
  ember_heart  = { id = "ember_heart",  op = "relic_affliction_inc", params = { family = "burn",   inc = 0.30 }, tier = 2 },
  weeping_nail = { id = "weeping_nail", op = "relic_affliction_inc", params = { family = "bleed",  inc = 0.30 }, tier = 2 },
  grave_cap    = { id = "grave_cap",    op = "relic_affliction_inc", params = { family = "rot",    inc = 0.30 }, tier = 2 },
}

R.order = { "bloodstone", "carapace", "aegis", "kings_bowl", "ember_heart", "weeping_nail", "grave_cap" }

-- Applique l'effet d'une relique à une compo (liste de specs d'unités), au BUILD. Modifie en place.
-- Les amplis (poisonInc/…/dmgReduce) sont ADDITIFS (cumul avec une aura d'adjacence qui poserait le même champ).
function R.apply(comp, relic)
  local op, p = relic.op, relic.params or {}
  for _, spec in ipairs(comp) do
    if op == "relic_more_dmg" then
      if spec.dmg then spec.dmg = math.floor(spec.dmg * (1 + (p.mult or 0)) + 0.5) end
    elseif op == "relic_flat_hp" then
      if spec.hp then spec.hp = spec.hp + (p.value or 0) end
    elseif op == "relic_dmg_reduce" then
      spec.dmgReduce = (spec.dmgReduce or 0) + (p.frac or 0) -- lu par Arena:damage (cause="attack"), gated
    elseif op == "relic_affliction_inc" then
      local key = (p.family or "") .. "Inc" -- poisonInc/burnInc/bleedInc/rotInc : lu par ampDps à la pose du DoT
      spec[key] = (spec[key] or 0) + (p.inc or 0)
    elseif op == "relic_add_effect" and p.effect then
      local base = spec.effects or (Units[spec.id] and Units[spec.id].effects) or {}
      local eff = {}
      for _, e in ipairs(base) do eff[#eff + 1] = e end -- copie superficielle (on n'AJOUTE que)
      eff[#eff + 1] = p.effect
      spec.effects = eff
    end
  end
end

return R
