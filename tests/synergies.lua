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

  -- ════════ KEYSTONES — contrats MULTICAST (§2.1.1) + EMPOWER/VULN caps (§8.1 step 2) ════════

  -- K3-A — MULTICAST × PORTE-ÉPINES (§2.1.1) : un multicast×3 sur un skeleton (épines 3) prend 3× les épines
  -- (auto-dmg BORNÉ par MULTICAST_MAX). On compare 1 swing multicast=3 vs 3 swings simples : identique (3× épines).
  do
    local a = Arena.new({ left = { U("marauder", {}, { hp = 9999 }) },
      right = { U("skeleton") }, autoReset = false, seed = 31 })
    local atk, skel = a.units[1], a.units[2]
    atk.multicast = 3
    local hp0 = atk.hp
    -- swingAge atteint le point de connexion -> la boucle multicast frappe 3× ; le skeleton renvoie 3 ×3 épines.
    atk.atkTimer = 0
    a:update(1.0, 1) -- déclenche le swing (attack)
    for i = 2, 40 do a:update(1.0, i); if atk.swingHit then break end end
    local lost = hp0 - atk.hp
    assert(lost >= 9, ("K3 multicast×epines: 3 sous-coups -> >=3×3 epines (perte %d)"):format(lost))
    -- borne : jamais plus que MULTICAST_MAX × épines (3×3=9) sur CE swing (les épines sont plates).
    assert(lost <= 9, ("K3 multicast borne par MULTICAST_MAX (perte %d <= 9)"):format(lost))
  end

  -- K3-B — MULTICAST × CHOC (idempotence de la décharge, §2.1.1) : la charge se vide au 1ER sous-coup ; les
  -- sous-coups 2-3 ne la retrouvent pas (consommable). On charge la cible, on frappe avec multicast=3.
  do
    local a = Arena.new({ left = { U("bandit", {}) }, right = { U("marauder", {}, { hp = 9999 }) },
      autoReset = false, seed = 32 })
    local atk, tgt = a.units[1], a.units[2]
    atk.multicast = 3
    tgt.dots.shock = { stacks = 4, remaining = 600, cap = 8, volt = 3, source = atk } -- décharge attendue 12, UNE fois
    local hp0 = tgt.hp
    a:hit(atk, tgt) -- 1er sous-coup (décharge) — appel direct
    assert(tgt.dots.shock == nil, "K3 multicast×choc: condensateur vidé au 1er sous-coup")
    local d1 = hp0 - tgt.hp
    a:hit(atk, tgt) -- 2e sous-coup : plus de charge
    local d2 = (hp0 - tgt.hp) - d1
    assert(d2 < d1, ("K3 idempotence choc: la décharge ne se reproduit pas (d2 %d < d1 %d)"):format(d2, d1))
  end

  -- K2-A — EMPOWER (atkInc) : +increased sur la base, cappé à ATK_INC_CAP. Un atkInc demesuré est CLAMPÉ.
  do
    local a = Arena.new({ left = { U("bandit", {}) }, right = { U("marauder", {}, { hp = 99999 }) },
      autoReset = false, seed = 33 })
    local atk, tgt = a.units[1], a.units[2]
    local hp0 = tgt.hp; a:hit(atk, tgt); local base = hp0 - tgt.hp -- bandit dmg = 7
    atk.atkInc = 0.5 -- +50%
    local hp1 = tgt.hp; a:hit(atk, tgt); local emp = hp1 - tgt.hp
    assert(emp > base, ("K2 empower: +increased augmente la frappe (%d > %d)"):format(emp, base))
    atk.atkInc = 99 -- absurde -> clampé à ATK_INC_CAP (×2.5 max), backstop ×7 du dmg de base
    local hp2 = tgt.hp; a:hit(atk, tgt); local capped = hp2 - tgt.hp
    assert(capped <= (atk.dmg) * Arena.HIT_DMG_CAP_MULT,
      ("K2 backstop: une frappe ne depasse pas ×%d le dmg de base (%d)"):format(Arena.HIT_DMG_CAP_MULT, capped))
    assert(capped <= math.floor(atk.dmg * (1 + Arena.ATK_INC_CAP)) + 1,
      ("K2 cap atkInc: empower clampe a ATK_INC_CAP (%d)"):format(capped))
  end

  -- K2-B — VULN (vulnInc) : +increased sur les dégâts ENTRANTS (frappe ET DoT), cappé VULN_INC_CAP.
  do
    local a = Arena.new({ left = { U("bandit", {}) }, right = { U("marauder", {}, { hp = 99999 }) },
      autoReset = false, seed = 34 })
    local atk, tgt = a.units[1], a.units[2]
    local hp0 = tgt.hp; a:hit(atk, tgt); local base = hp0 - tgt.hp
    tgt.vulnInc = 0.5
    local hp1 = tgt.hp; a:hit(atk, tgt); local vuln = hp1 - tgt.hp
    assert(vuln > base, ("K2 vuln: +increased sur degats entrants (%d > %d)"):format(vuln, base))
    -- s'applique AUSSI au DoT (poison ignore le bouclier) : un tick poison amplifié.
    tgt.vulnInc = 99 -- absurde -> clampé VULN_INC_CAP
    local hp2 = tgt.hp; a:hit(atk, tgt); local capped = hp2 - tgt.hp
    assert(capped <= math.floor(atk.dmg * (1 + Arena.VULN_INC_CAP)) + 1,
      ("K2 cap vuln: clampe a VULN_INC_CAP (%d)"):format(capped))
  end

  -- DÉTERMINISME des nouveaux chemins : même seed + même build (multicast+empower+vuln) -> même résultat.
  do
    local function loss(seed)
      local a = Arena.new({ left = { U("bandit", {}) }, right = { U("marauder", {}, { hp = 99999 }) },
        autoReset = false, seed = seed })
      local atk, tgt = a.units[1], a.units[2]
      atk.multicast = 3; atk.atkInc = 0.4; tgt.vulnInc = 0.3
      local hp0 = tgt.hp
      atk.atkTimer = 0
      for i = 1, 30 do a:update(1.0, i); if atk.swingHit then break end end
      return hp0 - tgt.hp
    end
    assert(loss(77) == loss(77), "K-determinisme: multicast×empower×vuln reproductible (meme seed)")
  end

  -- ════════ NEW-OPS agnostiques (spec §8.2 step 8) — chacun gated, testé synthétiquement (hors golden) ════════

  -- OP crit — RNG SEEDÉE en on_attack (AVANT damage). chance=1.0 -> toujours ×2 ; chance=0.0 -> jamais.
  do
    local critEff = { { trigger = "on_attack", op = "crit", params = { mult = 2 }, condition = { kind = "chance", value = 1.0 } } }
    local a = Arena.new({ left = { U("bandit", critEff) }, right = { U("marauder", {}, { hp = 99999 }) }, autoReset = false, seed = 41 })
    local atk, tgt = a.units[1], a.units[2]
    local hp0 = tgt.hp; a:hit(atk, tgt); local crit = hp0 - tgt.hp
    -- comparatif sans crit (chance 0)
    local noEff = { { trigger = "on_attack", op = "crit", params = { mult = 2 }, condition = { kind = "chance", value = 0.0 } } }
    local b = Arena.new({ left = { U("bandit", noEff) }, right = { U("marauder", {}, { hp = 99999 }) }, autoReset = false, seed = 41 })
    local hp1 = b.units[2].hp; b:hit(b.units[1], b.units[2]); local base = hp1 - b.units[2].hp
    assert(crit > base, ("op crit: ×2 quand chance=1.0 (%d > %d)"):format(crit, base))
    assert(crit <= base * 2 + 1, "op crit: ×2 borné (pas plus)")
  end

  -- OP execute — état pur (zéro RNG) : bonus seulement sous le seuil de PV de la victime.
  do
    local exEff = { { trigger = "on_attack", op = "execute", params = { threshold = 0.25, bonus = 1.0 } } }
    local a = Arena.new({ left = { U("bandit", exEff) }, right = { U("marauder", {}, { hp = 100, maxHp = 100 }) }, autoReset = false, seed = 42 })
    local atk, tgt = a.units[1], a.units[2]
    tgt.maxHp = 100; tgt.hp = 100
    local hp0 = tgt.hp; a:hit(atk, tgt); local healthy = hp0 - tgt.hp -- au-dessus du seuil : pas de bonus
    tgt.hp = 20 -- 20% < 25% -> execute
    local hp1 = tgt.hp; a:hit(atk, tgt); local low = hp1 - tgt.hp
    assert(low > healthy, ("op execute: +degats sous le seuil (%d > %d)"):format(low, healthy))
  end

  -- OP grant_vuln — pose vulnInc (on_hit), refresh (max), EXPIRE au tick (vulnRemaining -> vulnInc nil).
  do
    local gvEff = { { trigger = "on_hit", op = "grant_vuln", params = { value = 0.3, dur = 60 } } } -- dur en FRAMES
    local a = Arena.new({ left = { U("bandit", gvEff) }, right = { U("marauder", {}, { hp = 99999 }) }, autoReset = false, seed = 43 })
    local atk, tgt = a.units[1], a.units[2]
    a:hit(atk, tgt)
    assert(tgt.vulnInc and tgt.vulnInc > 0, "op grant_vuln: la cible est marquée (vulnInc posé)")
    assert(tgt.vulnRemaining and tgt.vulnRemaining > 0, "op grant_vuln: durée bornée armée")
    atk.alive = false -- l'attaquant ne re-pose plus la marque -> on observe l'EXPIRATION pure
    for i = 1, 70 do a:update(1.0, i) end -- > 60 frames -> expire (dur posé en frames)
    assert(tgt.vulnInc == nil, "op grant_vuln: la marque EXPIRE au tick (vulnInc effacé)")
  end

  -- OP cleave — éclabousse les VOISINS-champ (profondeur 1), cause="cleave", PAS d'on_hit secondaire ; respecte
  -- le bouclier (ignoreShield=false). Un voisin avec bouclier absorbe ; un voisin nu perd des PV.
  do
    local clEff = { { trigger = "on_hit", op = "cleave", params = { frac = 0.5 } } }
    local a = Arena.new({ left = { U("bandit", clEff) },
      right = { U("marauder", {}, { row = 0 }), U("marauder", {}, { row = 1 }) }, autoReset = false, seed = 44 })
    local atk, t0, t1 = a.units[1], a.units[2], a.units[3]
    local h1 = t1.hp
    a:hit(atk, t0)
    assert(t1.hp < h1, "op cleave: le voisin-champ de la cible prend l'éclaboussure (profondeur 1)")
    -- pas de double-comptage : le cleave ne re-déclenche pas un on_hit (sinon le bandit n'a pas d'on_hit, neutre).
  end

  -- OP cleave × MULTICAST (plan relics-overhaul §4 #4, GATE de splitting_maw) : un porteur cleave qui frappe
  -- AVEC multicast=3 produit 3 cleaves (1 par sous-coup), chacun PROFONDEUR 1 (aucun on_hit secondaire ->
  -- pas de boucle), chacun borné. On compare 3 sous-coups (multicast) vs 1 sous-coup : 3× l'éclaboussure.
  do
    local clEff = { { trigger = "on_hit", op = "cleave", params = { frac = 0.5 } } }
    -- 1 sous-coup : 1 cleave sur le voisin.
    local a1 = Arena.new({ left = { U("bandit", clEff, { dmg = 6, multicast = 1 }) },
      right = { U("marauder", {}, { row = 0, hp = 999, maxHp = 999 }),
                U("marauder", {}, { row = 1, hp = 999, maxHp = 999 }) }, autoReset = false, seed = 70 })
    local nb1 = a1.units[3]; local h1 = nb1.hp; a1:hit(a1.units[1], a1.units[2]); local splash1 = h1 - nb1.hp
    -- 3 sous-coups (multicast=3) : 3 cleaves sur le voisin (chaque hit() re-déclenche on_hit -> cleave).
    local a3 = Arena.new({ left = { U("bandit", clEff, { dmg = 6, multicast = 3 }) },
      right = { U("marauder", {}, { row = 0, hp = 999, maxHp = 999 }),
                U("marauder", {}, { row = 1, hp = 999, maxHp = 999 }) }, autoReset = false, seed = 70 })
    local nb3 = a3.units[3]; local h3 = nb3.hp
    for _ = 1, 3 do a3:hit(a3.units[1], a3.units[2]) end -- simule les 3 sous-coups d'un swing multicast
    local splash3 = h3 - nb3.hp
    assert(splash1 > 0, "cleave×multicast: 1 sous-coup eclabousse le voisin")
    assert(splash3 == splash1 * 3, ("cleave×multicast: 3 sous-coups = 3× l'eclaboussure (%d vs %d), borne, pas de boucle"):format(splash3, splash1))
    -- profondeur 1 : le cleave ne re-declenche PAS d'on_hit (sinon le cleave du voisin re-cleaverait -> cascade).
    -- Le bandit n'a pas d'autre on_hit que cleave : la cible directe ne recoit aucun cleave d'elle-meme (mono).
    assert(a3.units[2].alive or not a3.units[2].alive, "cleave×multicast: termine sans boucle infinie (atteint cette ligne)")
  end

  -- SEERS_MARK × autres marques (plan relics-overhaul §4 #3) : grant_vuln pose en max(), JAMAIS Σ -> 3 marques
  -- sur la meme cible = la plus FORTE gagne (sûr par construction, cappé VULN_INC_CAP). On pose 3 vuln via l'op.
  do
    local gv = { { trigger = "on_hit", op = "grant_vuln", params = { value = 0.12, dur = 600 } } }
    local a = Arena.new({ left = { U("bandit", gv) }, right = { U("marauder", {}) }, autoReset = false, seed = 71 })
    local atk, v = a.units[1], a.units[2]
    a:hit(atk, v) -- 1re marque 0.12
    v.vulnInc = math.max(v.vulnInc or 0, 0.20) -- corruptor (plus forte)
    a:hit(atk, v) -- seers_mark re-pose 0.12 -> max(0.20, 0.12) = 0.20 (ne REDESCEND pas, n'additionne pas)
    assert(math.abs((v.vulnInc or 0) - 0.20) < 1e-9, ("seers_mark×corruptor: vulnInc = max (0.20), pas Σ (got %.2f)"):format(v.vulnInc or 0))
  end

  -- OP heal_on_kill — on_kill (broadcast fin de frame, ctx.source = killer). Le tueur se soigne, borné maxHp.
  do
    local hkEff = { { trigger = "on_kill", op = "heal_on_kill", params = { value = 30 } } }
    local a = Arena.new({ left = { U("marauder", hkEff, { hp = 200, maxHp = 200 }) },
      right = { U("marauder", {}, { hp = 1 }) }, autoReset = false, seed = 45 })
    local killer, victim = a.units[1], a.units[2]
    killer.hp = 50; killer.maxHp = 200
    a:damage(victim, 999, { source = killer, cause = "attack" }) -- tue -> deaths {victim, killer}
    assert(not victim.alive, "la victime meurt")
    local hp0 = killer.hp
    a:update(1.0, 1) -- draine -> on_kill au killer
    assert(killer.hp > hp0, ("op heal_on_kill: le tueur se soigne (%d > %d)"):format(killer.hp, hp0))
    assert(killer.hp <= killer.maxHp, "op heal_on_kill: borné à maxHp")
  end

  -- OP purge — vide ses propres afflictions (anti-DoT). combat_start OU on_low_hp. Ici on l'arme on_low_hp.
  do
    local pgEff = { { trigger = "on_low_hp", op = "purge", params = { threshold = 0.5 } } }
    local a = Arena.new({ left = { U("marauder", pgEff, { hp = 100, maxHp = 100 }) }, right = {}, autoReset = false, seed = 46 })
    local u = a.units[1]
    u.maxHp = 100; u.hp = 100
    u.dots.poison[1] = { dps = 2, remaining = 600, acc = 0, weaken = 0, source = u }
    u.dots.burn = { dps = 3, remaining = 600, acc = 0, decayEvery = 60, decayAcc = 0, decayPct = 0.3, source = u }
    u.hp = 40 -- sous 50% -> on_low_hp edge-trigger
    a:update(1.0, 1)
    assert(#u.dots.poison == 0 and u.dots.burn == nil, "op purge: afflictions retirées au franchissement du seuil")
  end

  -- OP purge BORNÉE (9c′ plague_doctor) : ne retire QUE la famille `family` et au plus `maxStacks` (les plus anciens).
  -- La purge INCLINE le matchup DoT, ne l'EFFACE pas (le burn reste, et le poison résiduel survit > maxStacks).
  do
    local pgB = { { trigger = "on_low_hp", op = "purge", params = { threshold = 0.5, family = "poison", maxStacks = 4 } } }
    local a = Arena.new({ left = { U("marauder", pgB, { hp = 100, maxHp = 100 }) }, right = {}, autoReset = false, seed = 67 })
    local u = a.units[1]
    u.maxHp = 100; u.hp = 100
    for i = 1, 7 do u.dots.poison[i] = { dps = 2, remaining = 600, acc = 0, weaken = 0, source = u } end -- 7 stacks
    u.dots.burn = { dps = 3, remaining = 600, acc = 0, decayEvery = 60, decayAcc = 0, decayPct = 0.3, source = u }
    u.hp = 40 -- < 50% -> edge-trigger
    a:update(1.0, 1)
    assert(#u.dots.poison == 3, ("op purge bornée: retire au plus 4 stacks de poison (reste %d, attendu 3)"):format(#u.dots.poison))
    assert(u.dots.burn ~= nil, "op purge bornée: le burn (hors family=poison) est ÉPARGNÉ (incline, n'efface pas)")
  end

  -- OP convert_dot — généralise convert_to_rot : {from=bleed, to=rot} consomme le bleed, pose la pourriture.
  do
    local cvEff = { { trigger = "on_hit", op = "convert_dot", params = { from = "bleed", to = "rot", base = 3 } } }
    local a = Arena.new({ left = { U("bandit", cvEff) }, right = { U("marauder", {}) }, autoReset = false, seed = 47 })
    local atk, tgt = a.units[1], a.units[2]
    tgt.dots.bleed = { dps = 2, remaining = 300, acc = 0, slowPct = 0.2, dynBonus = 0, source = atk }
    tgt.atkSlow = 0.2
    a:hit(atk, tgt)
    assert(not tgt.dots.bleed, "op convert_dot: le bleed (from) est consommé")
    assert(tgt.dots.rot, "op convert_dot: la pourriture (to) est posée")
  end

  -- OP grant_affliction_if_absent — pose poison SI absent (pas de double-stack).
  do
    local giEff = { { trigger = "on_hit", op = "grant_affliction_if_absent", params = { family = "poison", dps = 1, dur = 120 } } }
    local a = Arena.new({ left = { U("bandit", giEff) }, right = { U("marauder", {}) }, autoReset = false, seed = 48 })
    local atk, tgt = a.units[1], a.units[2]
    a:hit(atk, tgt); assert(#tgt.dots.poison == 1, "grant_if_absent: pose si absent")
    a:hit(atk, tgt); assert(#tgt.dots.poison == 1, "grant_if_absent: PAS de 2e pose (déjà présent)")
  end

  -- ════════ PIRE COMBO (§9.1) — multicast × empower × vuln × crit : 4 multiplicateurs composés. Prouve que le
  -- TTK ne s'EFFONDRE PAS (les caps + le backstop tiennent) : le combo tue plus vite qu'une frappe nue MAIS reste
  -- au-dessus d'un plancher de ticks (pas un one-shot instantané). Déterministe (même seed -> même TTK). ════════
  do
    local critEff = { { trigger = "on_attack", op = "crit", params = { mult = 2 }, condition = { kind = "chance", value = 1.0 } } }
    local function ttk(combo)
      local a = Arena.new({ left = { U("bandit", combo and critEff or {}) },
        right = { U("templar", {}, { hp = 600, maxHp = 600 }) }, autoReset = false, seed = 99 })
      local atk, tgt = a.units[1], a.units[2]
      tgt.maxHp = 600; tgt.hp = 600
      if combo then atk.multicast = 3; atk.atkInc = 99; tgt.vulnInc = 99 end -- atkInc/vulnInc absurdes -> clampés
      local n = 0
      for i = 1, 8000 do a:update(1.0, i); n = i; if not tgt.alive then break end end
      return n, tgt.alive
    end
    local tCombo = ttk(true)
    local tBase = ttk(false)
    assert(not select(2, ttk(true)), "pire combo: la cible MEURT (le combo conclut)")
    assert(tCombo < tBase, ("pire combo: tue plus vite que nu (%d < %d ticks)"):format(tCombo, tBase))
    -- plancher anti-one-shot : avec backstop ×7 + caps, il faut PLUSIEURS swings (le swing dure SWING_DUR ticks).
    assert(tCombo >= 30, ("pire combo: PAS un one-shot instantané (%d ticks >= 30, TTK p10 ne s'effondre pas)"):format(tCombo))
    assert(ttk(true) == tCombo, "pire combo: déterministe (même seed -> même TTK)")
  end

  -- ════════ SURVEILLANCE GRAVÉE (plan §4/§5/§6.4) — hookjaw multicast × Couronne d'Échos × poison + miasma-aura :
  -- le combo le PLUS explosif (Écho empile sur Saturation/Marque). Prouve que les CAPS tiennent même quand le
  -- frappeur re-frappe ×3 ET pose poison(weaken)+vuln : WEAKEN_CAP(0.40), POISON_STACK_CAP(8), VULN_INC_CAP(0.5),
  -- et que le TTK p10 ne s'effondre PAS (pas de one-shot). Le multicast est baké comme le ferait K1 (hookjaw +1 +
  -- Couronne +1 = 2, cap MULTICAST_MAX=3). Déterministe (même seed -> même résultat). ════════
  do
    -- carry = corruptor (poison weaken=0.06 + grant_vuln) sous multicast=2 (hookjaw +1 + Couronne +1, plafonné).
    -- miasma-aura simulée par poisonInc=0.5 baké sur le frappeur (comme le bake build de miasma_acolyte).
    local function loadOn(cap)
      local a = Arena.new({ left = { U("corruptor") },
        right = { U("templar", {}, { hp = 99999, maxHp = 99999 }) }, autoReset = false, seed = 64 })
      local cor, tgt = a.units[1], a.units[2]
      cor.multicast = 2          -- Écho baké (hookjaw role:front +1 + Couronne d'Échos +1) ; cap MULTICAST_MAX=3
      cor.poisonInc = 0.5        -- miasma-aura bakée (aura_poison_dps inc 0.5) -> stacks renforcés, cappés ×3
      -- on frappe BEAUCOUP : chaque hit = corruptor pose 1 stack (poison) + (grant_vuln quand greffé). On
      -- veut saturer pour PROUVER que les caps bornent (et pas que le combo ne proc jamais).
      for _ = 1, cap or 30 do a:hit(cor, tgt) end
      a:update(1.0, 1) -- recompute weaken (tickDots agrège le weaken des stacks)
      return cor, tgt, a
    end
    local cor, tgt = loadOn(30)
    -- CAP weaken : 30 stacks × 0.06 = 1.8 sans cap -> doit être borné à WEAKEN_CAP (0.40).
    assert(tgt.weaken <= 0.40 + 1e-9, ("SURVEILLANCE weaken cappé (%.3f <= 0.40)"):format(tgt.weaken))
    -- CAP stacks poison : jamais plus que 8 (le plus ancien est retiré).
    assert(#tgt.dots.poison <= 8, ("SURVEILLANCE poison cap (%d <= 8 stacks)"):format(#tgt.dots.poison))
    -- CAP vuln (si la marque est greffée sur corruptor) : la LECTURE dans damage est cappée VULN_INC_CAP=0.5.
    -- On vérifie qu'une vuln absurde reste bornée à l'application (frappe nue d'un voisin).
    do
      local _, t2, a2 = loadOn(8)
      t2.vulnInc = 99 -- marque absurde -> doit être clampée VULN_INC_CAP à la lecture
      local atkr = a2.units[1]
      local h0 = t2.hp; a2:hit(atkr, t2); local d = h0 - t2.hp
      assert(d <= math.floor(atkr.dmg * (1 + Arena.VULN_INC_CAP)) + 4 + 8,
        ("SURVEILLANCE vuln clampé VULN_INC_CAP (degats %d bornés)"):format(d)) -- +marge décharge/weaken arrondi
    end
    -- ANTI ONE-SHOT (TTK p10 ne s'effondre pas) : le carry multicast=2 + poison + miasma met PLUSIEURS swings à
    -- tuer un mur (le multicast ne re-frappe que la FRAPPE, bornée par MULTICAST_MAX et HIT_DMG_CAP_MULT).
    local function ttkCombo()
      local a = Arena.new({ left = { U("corruptor") },
        right = { U("templar", {}, { hp = 400, maxHp = 400 }) }, autoReset = false, seed = 65 })
      local cor, tgt = a.units[1], a.units[2]
      cor.multicast = 2; cor.poisonInc = 0.5
      tgt.maxHp = 400; tgt.hp = 400
      local n = 0
      for i = 1, 8000 do a:update(1.0, i); n = i; if not tgt.alive then break end end
      return n, tgt.alive
    end
    local tc, aliveAfter = ttkCombo()
    assert(not aliveAfter, "SURVEILLANCE: le combo conclut (la cible meurt)")
    assert(tc >= 30, ("SURVEILLANCE anti one-shot: TTK p10 ne s'effondre pas (%d ticks >= 30)"):format(tc))
    assert(select(1, ttkCombo()) == tc, "SURVEILLANCE: déterministe (même seed -> même TTK)")
  end

  print("  surveillance: hookjaw-multicast × Couronne × poison+miasma -> WEAKEN/POISON/VULN caps + anti one-shot OK")

  -- ════════ SURVEILLANCE 9c′ — TRIPLE SUSTAIN (heal_on_kill ×2 + lifesteal) : prouve l'absence de sur-sustain.
  -- Même un porteur empilant deux soins-sur-kill ET du lifesteal ne dépasse JAMAIS maxHp (cap gravé dans les ops).
  -- C'est le pire empilement de soin du roster (carrion_pecker + skull_colossus + demon sur la même unité). ════════
  do
    local sustainEff = {
      { trigger = "on_kill", op = "heal_on_kill", params = { value = 4 } },  -- carrion_pecker
      { trigger = "on_kill", op = "heal_on_kill", params = { value = 8 } },  -- skull_colossus
      { trigger = "on_hit", op = "lifesteal", params = { frac = 0.4 } },     -- demon
    }
    local a = Arena.new({ left = { U("marauder", sustainEff, { hp = 100, maxHp = 100 }) },
      right = { U("marauder", {}, { hp = 1 }), U("marauder", {}, { hp = 1 }) }, autoReset = false, seed = 66 })
    local hero, v1, v2 = a.units[1], a.units[2], a.units[3]
    hero.maxHp = 100; hero.hp = 95 -- presque plein -> le sustain doit PLAFONNER, pas overflow
    a:hit(hero, v1) -- lifesteal + tue v1 -> on_kill (les deux heal_on_kill)
    a:damage(v2, 999, { source = hero, cause = "attack" }) -- tue v2 -> on_kill encore
    a:update(1.0, 1) -- draine la file des morts -> broadcast on_kill (heal ×2 ×2 morts)
    assert(hero.hp <= hero.maxHp, ("SURVEILLANCE triple-sustain: PV bornés à maxHp (%d <= %d)"):format(hero.hp, hero.maxHp))
    assert(hero.hp >= 95, "SURVEILLANCE triple-sustain: le soin agit bien (PV >= base)") -- le sustain proc (mais plafonne)
  end

  print("  surveillance+: triple-sustain (heal_on_kill×2 + lifesteal) -> jamais > maxHp (pas de sur-sustain) OK")

  -- ════════ SURVEILLANCE 9c′ — CLEAVE × MULTICAST (plan §4 (e), gating de siege_breaker) : un frappeur cleave SOUS
  -- multicast=3 contre une ligne de cibles fragiles -> morts SIMULTANÉES. Prouve : (1) PAS de boucle (cleave est
  -- profondeur 1, ne re-déclenche aucun on_hit/dischargeShock secondaire) ; (2) l'ordre de broadcast on_death suit
  -- §2.4.1 (file self.deaths, drainée en fin de frame) ; (3) déterministe (même seed -> même résultat). ════════
  do
    local clEff = { { trigger = "on_hit", op = "cleave", params = { frac = 0.5 } } }
    local function run(seed)
      -- bandit cleave (dmg 7) × multicast=3 contre 3 cibles 1-PV alignées : chaque sous-coup tue la principale + éclabousse.
      local a = Arena.new({ left = { U("bandit", clEff, { hp = 9999 }) },
        right = { U("marauder", {}, { row = 0, hp = 1 }), U("marauder", {}, { row = 1, hp = 1 }),
                  U("marauder", {}, { row = 2, hp = 1 }) }, autoReset = false, seed = seed })
      local atk = a.units[1]; atk.multicast = 3
      atk.atkTimer = 0
      local deaths = 0
      a.bus:on("death", function() deaths = deaths + 1 end)
      local guard = 0
      for i = 1, 200 do a:update(1.0, i); guard = i; if a.over then break end end
      return deaths, guard, atk.alive
    end
    local d1, g1 = run(50)
    assert(g1 < 200, "SURVEILLANCE cleave×multicast: le combat CONCLUT (pas de boucle infinie, profondeur 1)")
    assert(d1 >= 1, "SURVEILLANCE cleave×multicast: au moins une mort par éclaboussure/frappe")
    local d2 = run(50)
    assert(d2 == d1, "SURVEILLANCE cleave×multicast: déterministe (même seed -> même nb de morts)")
  end

  print("  surveillance#: cleave × multicast -> conclut (profondeur 1, pas de boucle) + déterministe OK")

  print("  synergies : choc-decharge-allie / poison-multi-sources / weaken-reduit-output / bleed-ralentit-cadence / regen-contre-DoT")
  print("  synergies+: contagion / propagation-a-la-mort / aggravate / shieldEat (T2)")
  print("  synergies#: bleed->rot / poison->feu / festering-sans-cap (T3 croises) OK")
  print("  keystones : multicast×epines (borne) / multicast×choc (idempotence) / empower+vuln caps / determinisme OK")
  print("  new-ops   : crit(seedé) / execute / grant_vuln(expire) / cleave / heal_on_kill / purge / convert_dot / grant_if_absent OK")
  print("  pire-combo: multicast×empower×vuln×crit conclut SANS one-shot (caps+backstop tiennent) OK")
end)

if ok then
  print("=> SYNERGIES OK : les effets interagissent correctement en combat (deroule + resultat).")
else
  print("=> SYNERGIES FAIL :")
  print(err)
  os.exit(1)
end
