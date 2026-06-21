-- tests/synergies.lua
-- Tests d'INTERACTION (synergies) — le cœur de la valeur du jeu : on vérifie que les effets
-- s'influencent ENTRE eux dans un VRAI combat (le « déroulé » dans le temps ET le « résultat »),
-- pas seulement chaque famille en isolation (ça, c'est dans headless). Déterministe (RNG seedé).
--   Lancement : luajit tests/synergies.lua
package.path = "./?.lua;" .. package.path
love = require("tests.mock_love")

local Arena = require("src.combat.arena")
local Units = require("src.data.units")

-- spec minimal : on peut injecter des effets custom (eff) et écraser des champs (over) pour ISOLER
-- l'interaction qu'on teste, sans bruit (ex. désactiver un passif gênant en passant eff = {}).
local function U(id, eff, over)
  local u = Units[id]
  local s = { id = id, hp = u.hp, dmg = u.dmg, cd = u.cd, effects = eff or u.effects,
    depth = 0, row = 0, shield = 0, x = 0, y = 0, facing = 1 }
  if over then for k, v in pairs(over) do s[k] = v end end
  return s
end

local ok, err = pcall(function()

  -- SYNERGIE 1 — CHOC : la charge se DÉCHARGE au coup d'un ALLIÉ. Un condensateur chargé (par le choqueur)
  -- libère stacks × volt EN PLUS du coup du second attaquant, puis se consume (le coup vaut plus que sur cible saine).
  do
    local a = Arena.new({ left = { U("bandit", {}), U("stormcaller", {}) },
      right = { U("marauder", {}) }, autoReset = false, seed = 1 })
    local hitter, storm, target = a.units[1], a.units[2], a.units[3]
    local hp0 = target.hp; a:hit(hitter, target); local base = hp0 - target.hp -- cible SAINE (aucune charge)
    assert(target.dots.shock == nil, "choc: pas de charge sur cible saine apres le coup du hitter")
    -- on charge le condensateur (3 stacks, volt 3 -> décharge 9) : isole la synergie inter-unités
    target.dots.shock = { stacks = 3, remaining = 600, cap = 8, volt = 3, source = storm }
    local hp1 = target.hp; a:hit(hitter, target); local amped = hp1 - target.hp
    assert(amped > base, ("SYNERGIE choc: decharge au coup d'un allie (%d > %d)"):format(amped, base))
    assert(target.dots.shock == nil, "choc: condensateur consume apres decharge")
  end

  -- SYNERGIE 2 — POISON multi-sources : DEUX unités empilent sur la MÊME cible (axe « nombre »), et
  -- le weaken des stacks se cumule.
  do
    local p1 = { { trigger = "on_hit", op = "poison", params = { dps = 1, dur = 300 } } }
    local p2 = { { trigger = "on_hit", op = "poison", params = { dps = 2, dur = 300, weaken = 0.1 } } }
    local a = Arena.new({ left = { U("spore_tick", p1), U("corruptor", p2) },
      right = { U("marauder", {}) }, autoReset = false, seed = 2 })
    local sp, cor, target = a.units[1], a.units[2], a.units[3]
    a:hit(sp, target); a:hit(cor, target); a:hit(cor, target)
    assert(#target.dots.poison == 3, "poison: 3 stacks de 2 sources cumules")
    a:update(1.0, 1)
    assert(math.abs(target.weaken - 0.2) < 1e-9, "poison: weaken cumule (0.1 x 2 stacks de corruptor)")
  end

  -- SYNERGIE 3 — WEAKEN end-to-end : une unité empoisonnée (weaken) PRODUIT moins -> ses dégâts baissent.
  do
    local a = Arena.new({ left = { U("bandit", {}) }, right = { U("marauder", {}) }, autoReset = false, seed = 3 })
    local atk, tgt = a.units[1], a.units[2]
    local hp0 = tgt.hp; a:hit(atk, tgt); local base = hp0 - tgt.hp -- bandit dmg = 7
    table.insert(atk.dots.poison, { dps = 0, remaining = 300, acc = 0, weaken = 0.3, source = atk })
    a:update(1.0, 1)
    assert(math.abs(atk.weaken - 0.3) < 1e-9, "weaken arme")
    local hp1 = tgt.hp; a:hit(atk, tgt); local weakened = hp1 - tgt.hp
    assert(weakened < base, ("SYNERGIE weaken: attaquant empoisonne inflige moins (%d < %d)"):format(weakened, base))
  end

  -- SYNERGIE 4 — BLEED ralentit la CADENCE (le « déroulé » dans le temps) : sur une fenêtre identique,
  -- une unité saignante attaque MOINS de fois que la même sans saignement.
  local function countAttacks(bleed)
    local a = Arena.new({ left = { U("bandit", {}, { hp = 999 }) },
      right = { U("marauder", {}, { hp = 99999 }) }, autoReset = false, seed = 7 })
    local atkr = a.units[1]
    if bleed then
      atkr.dots.bleed = { dps = 0, remaining = 100000, acc = 0, slowPct = 0.5, source = atkr }
      atkr.atkSlow = 0.5
    end
    local n = 0
    a.bus:on("attack", function(u) if u == atkr then n = n + 1 end end)
    for i = 1, 1200 do a:update(1.0, i); if a.over then break end end
    return n
  end
  do
    local fast, slow = countAttacks(false), countAttacks(true)
    assert(slow < fast, ("SYNERGIE bleed: cadence ralentie (%d attaques < %d)"):format(slow, fast))
  end

  -- SYNERGIE 5 — CONTRE : la regen ATTÉNUE un DoT -> sous le même poison, l'unité avec regen perd
  -- moins de PV (le contre fait son office).
  local function netLoss(withRegen)
    local a = Arena.new({ left = { U("marauder", {}) }, right = {}, autoReset = false, seed = 9 })
    local u = a.units[1]
    table.insert(u.dots.poison, { dps = 3, remaining = 100000, acc = 0, source = u })
    if withRegen then u.regen = 2 end
    local hp0 = u.hp
    for i = 1, 300 do a:update(1.0, i) end
    return hp0 - u.hp
  end
  do
    local raw, warded = netLoss(false), netLoss(true)
    assert(warded < raw, ("SYNERGIE contre: regen attenue le poison (perte %d < %d)"):format(warded, raw))
  end

  -- ════════ VAGUE 3 — twists T2 (contagion, propagation à la mort, aggravate, shieldEat) ════════

  -- SYNERGIE 6 — CONTAGION (Plague-Bearer) : le poison se propage au VOISIN de la cible (proximité champ).
  do
    local a = Arena.new({ left = { U("plague_bearer") },
      right = { U("marauder", {}, { row = 0 }), U("marauder", {}, { row = 1 }) }, autoReset = false, seed = 11 })
    local pb, t0, t1 = a.units[1], a.units[2], a.units[3]
    a:hit(pb, t0)
    assert(#t0.dots.poison == 1, "contagion: la cible est empoisonnee")
    assert(#t1.dots.poison == 1, "SYNERGIE contagion: le VOISIN de la cible recoit un stack")
  end

  -- SYNERGIE 7 — PROPAGATION À LA MORT (Wildfire-Hound) : un ennemi qui meurt EN FEU enflamme son voisin
  -- (au DRAIN on_death, pas pendant le hit).
  do
    local a = Arena.new({ left = { U("wildfire_hound") },
      right = { U("marauder", {}, { row = 0 }), U("marauder", {}, { row = 1 }) }, autoReset = false, seed = 12 })
    local wh, t0, t1 = a.units[1], a.units[2], a.units[3]
    t0.dots.burn = { dps = 6, remaining = 300, acc = 0, decayEvery = 60, decayAcc = 0, decayPct = 0.30, source = wh }
    a:damage(t0, 999, { source = wh, cause = "test" })
    assert(not t0.alive, "la cible meurt en feu")
    assert(not t1.dots.burn, "le voisin n'est PAS encore en feu avant le drain")
    a:update(1.0, 1) -- draine la file des morts -> broadcast on_death
    assert(t1.dots.burn, "SYNERGIE on_death: le feu saute au voisin a la mort")
  end

  -- SYNERGIE 8 — AGGRAVATE (Bloodletter) : le saignement ECLATE quand la cible saignante AGIT (frappe).
  do
    local a = Arena.new({ left = { U("bandit", {}) }, right = { U("marauder", {}, { hp = 9999 }) }, autoReset = false, seed = 13 })
    local atkr = a.units[1]
    atkr.dots.bleed = { dps = 3, remaining = 600, acc = 0, slowPct = 0, aggravateMult = 2.0, dynBonus = 0, source = atkr }
    atkr.atkTimer = 0 -- pret a frapper ce tick
    local hp0 = atkr.hp
    a:update(1.0, 1) -- le swing declenche le burst d'aggravate (floor(3*2)=6) sur l'attaquant
    assert(hp0 - atkr.hp >= 6, ("SYNERGIE aggravate: l'attaquant saigne en frappant (perte %d >= 6)"):format(hp0 - atkr.hp))
  end

  -- SYNERGIE 9 — SHIELD-EAT (Acid-Maw) : le venin dissout le bouclier AU-DELA de la simple absorption.
  do
    local a = Arena.new({ left = { U("acid_maw") }, right = { U("templar", {}, { shield = 20 }) }, autoReset = false, seed = 14 })
    local am, tgt = a.units[1], a.units[2]
    a:hit(am, tgt) -- absorbe am.dmg PUIS ronge 30% du bouclier restant
    assert(tgt.shield < 20 - am.dmg, ("SYNERGIE shieldEat: bouclier ronge au-dela de l'absorption (%d < %d)"):format(tgt.shield, 20 - am.dmg))
  end

  -- ════════ VAGUE 4 — transforms T3 & CROISEMENTS de familles (enabler -> payoff cross-famille) ════════

  -- SYNERGIE 10 — CROISÉ saignement->pourriture (Marrow-Drinker) : frapper une cible DÉJÀ saignante
  -- convertit le bleed en rot (le sang noir devient nécrose).
  do
    local a = Arena.new({ left = { U("marrow_drinker") }, right = { U("marauder", {}) }, autoReset = false, seed = 21 })
    local md, tgt = a.units[1], a.units[2]
    tgt.dots.bleed = { dps = 2, remaining = 300, acc = 0, slowPct = 0.2, dynBonus = 0, source = md }
    tgt.atkSlow = 0.2
    a:hit(md, tgt)
    assert(not tgt.dots.bleed, "marrow: le bleed est consomme")
    assert(tgt.dots.rot, "SYNERGIE bleed->rot: la cible saignante recoit de la pourriture")
  end

  -- SYNERGIE 11 — CROISÉ poison->feu (Venom-Censer) : à 5 stacks de poison, la cible DÉTONE en flammes.
  do
    local a = Arena.new({ left = { U("venom_censer") }, right = { U("marauder", {}, { hp = 9999 }) }, autoReset = false, seed = 22 })
    local vc, tgt = a.units[1], a.units[2]
    for _ = 1, 5 do a:hit(vc, tgt) end
    assert(#tgt.dots.poison >= 5, "5 stacks de poison poses")
    assert(not tgt.dots.burn, "pas encore enflamme avant le tick")
    a:update(1.0, 1) -- le tick poison verifie le seuil -> detonation feu
    assert(tgt.dots.burn, "SYNERGIE poison->burn: a 5 stacks la cible s'enflamme")
  end

  -- SYNERGIE 12 — TRANSFORM d'équipe (The Festering) : lève le cap de stacks de poison pour TOUTE l'équipe
  -- (un allié peut alors dépasser 8 stacks).
  do
    local a = Arena.new({ left = { U("festering"), U("spore_tick") },
      right = { U("marauder", {}, { hp = 99999 }) }, autoReset = false, seed = 23 })
    local sp, tgt = a.units[2], a.units[3]
    for _ = 1, 12 do a:hit(sp, tgt) end -- spore_tick (left) profite du cap levé par festering (left)
    assert(#tgt.dots.poison == 12, ("SYNERGIE festering: cap leve, 12 stacks tiennent >8 (obtenu %d)"):format(#tgt.dots.poison))
  end

  print("  synergies : choc-decharge-allie / poison-multi-sources / weaken-reduit-output / bleed-ralentit-cadence / regen-contre-DoT")
  print("  synergies+: contagion / propagation-a-la-mort / aggravate / shieldEat (T2)")
  print("  synergies#: bleed->rot / poison->feu / festering-sans-cap (T3 croises) OK")
end)

if ok then
  print("=> SYNERGIES OK : les effets interagissent correctement en combat (deroule + resultat).")
else
  print("=> SYNERGIES FAIL :")
  print(err)
  os.exit(1)
end
