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
  bloodstone = { id = "bloodstone", op = "relic_more_dmg",   params = { mult = 0.14 }, tier = 1 }, -- 0.20->0.14 (calibrage)
  carapace   = { id = "carapace",   op = "relic_flat_hp",    params = { value = 8 },   tier = 1 }, -- 15->8 (flat ×5 unités = trop)
  aegis      = { id = "aegis",      op = "relic_dmg_reduce", params = { frac = 0.15 }, tier = 1 },

  -- ── B — amplis d'affliction (le cœur build-shaping : récompense le mono-archétype) ──
  -- Poison = APEX -> ampli CONSERVATEUR (0.20) ; familles faibles (burn/bleed/rot) -> ampli plus généreux (0.30).
  kings_bowl   = { id = "kings_bowl",   op = "relic_affliction_inc", params = { family = "poison", inc = 0.20 }, tier = 2 },
  ember_heart  = { id = "ember_heart",  op = "relic_affliction_inc", params = { family = "burn",   inc = 0.30 }, tier = 2 },
  weeping_nail = { id = "weeping_nail", op = "relic_affliction_inc", params = { family = "bleed",  inc = 0.18 }, tier = 2 }, -- 0.30->0.18 (calibrage)
  grave_cap    = { id = "grave_cap",    op = "relic_affliction_inc", params = { family = "rot",    inc = 0.18 }, tier = 2 }, -- 0.30->0.18 (calibrage)

  -- ── C — paliers / payoffs (récompense NON-LINÉAIRE d'un build / archétype ; cf. doc §4-C) ──
  -- FAMINE'S MATH (« tall ») : ≤3 unités -> elles frappent ET encaissent plus. HOLLOW CHOIR (anti-sustain) :
  -- afflictions percent les soins ennemis (règle burn/DoT vs tank/regen). FEEDING FRENZY : chaque kill renforce.
  famines_math = { id = "famines_math", op = "relic_few_units",
    params = { max = 3, dmgInc = 0.30, hpInc = 0.20 }, tier = 3 },
  hollow_choir = { id = "hollow_choir", op = "relic_add_effect", tier = 3,
    params = { effect = { trigger = "combat_start", op = "grant_team", params = { pierceHeal = 0.40 } } } },
  feeding_frenzy = { id = "feeding_frenzy", op = "relic_add_effect", tier = 3,
    params = { effect = { trigger = "on_death", op = "frenzy_gain", params = { per = 0.08, cap = 6 } } } },

  -- ── A (suite) cadence · D — défensives / globales (intra-combat ; cf. doc §4-A/D) ──
  whetstone     = { id = "whetstone",     op = "relic_haste", params = { value = 0.15 }, tier = 1 }, -- +15% cadence
  thornguard    = { id = "thornguard",    op = "relic_add_effect", tier = 2, -- épines d'équipe (renvoie en étant frappé)
    params = { effect = { trigger = "on_attacked", op = "thorns", params = { value = 2 } } } }, -- 4->2 (brutal vs taunt-tank)
  sacred_shield = { id = "sacred_shield", op = "relic_add_effect", tier = 3, -- 0,5 s d'invulnérabilité d'ouverture (t<30)
    params = { effect = { trigger = "combat_start", op = "grant_team", params = { invulnT = 30 } } } },
  second_breath = { id = "second_breath", op = "relic_second_breath", tier = 3 }, -- chaque unité survit 1× à 1 PV

  -- ── E — transformatives (changent une RÈGLE intra-combat ; build-defining ; cf. doc §4-E). Réutilisent
  -- toutes relic_add_effect + grant_team (flags lus par le tick/les ops à combat_start ; ZÉRO nouvel op). ──
  forked_tongue = { id = "forked_tongue", op = "relic_add_effect", tier = 4, -- le choc rebondit sur 1 ennemi
    params = { effect = { trigger = "combat_start", op = "grant_team", params = { shockChain = 1 } } } },
  everburn = { id = "everburn", op = "relic_add_effect", tier = 4, -- les feux ne décroissent jamais (réutilise burnNoDecay)
    params = { effect = { trigger = "combat_start", op = "grant_team", params = { burnNoDecay = true } } } },
  open_wounds = { id = "open_wounds", op = "relic_add_effect", tier = 4, -- les saignements ne se referment jamais
    params = { effect = { trigger = "combat_start", op = "grant_team", params = { bleedNoExpire = true } } } },
  plague_communion = { id = "plague_communion", op = "relic_add_effect", tier = 4, -- 2+ afflictions -> +25% de tous nos dégâts
    params = { effect = { trigger = "combat_start", op = "grant_team", params = { plagueAmp = 0.25 } } } },
}

R.order = { "bloodstone", "carapace", "aegis", "kings_bowl", "ember_heart", "weeping_nail", "grave_cap",
  "famines_math", "hollow_choir", "feeding_frenzy",
  "whetstone", "thornguard", "sacred_shield", "second_breath",
  "forked_tongue", "everburn", "open_wounds", "plague_communion" }

-- Applique l'effet d'une relique à une compo (liste de specs d'unités), au BUILD. Modifie en place.
-- Les amplis (poisonInc/…/dmgReduce) sont ADDITIFS (cumul avec une aura d'adjacence qui poserait le même champ).
function R.apply(comp, relic)
  local op, p = relic.op, relic.params or {}
  local n = #comp -- taille de l'équipe, pour les paliers conditionnels (ex. « ≤3 unités »)
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
    elseif op == "relic_few_units" then -- FAMINE'S MATH : si l'équipe est petite (≤max), elle frappe/encaisse plus
      if n <= (p.max or 3) then
        if spec.dmg then spec.dmg = math.floor(spec.dmg * (1 + (p.dmgInc or 0)) + 0.5) end
        if spec.hp then spec.hp = math.floor(spec.hp * (1 + (p.hpInc or 0)) + 0.5) end
      end
    elseif op == "relic_haste" then -- WHETSTONE : cadence d'attaque (lu par le timer de l'arène, gated)
      spec.haste = (spec.haste or 0) + (p.value or 0)
    elseif op == "relic_second_breath" then -- SECOND BREATH : survie 1× à 1 PV (lu par Arena:damage)
      spec.secondBreath = true
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
