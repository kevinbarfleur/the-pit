-- src/effects/ops.lua
-- Vocabulaire d'ops de BASE (les 6 passifs du roster v0), enregistrés dans le moteur d'effets.
-- Chaque op est une petite fonction pure-sim `(ctx, params, effet)`. Aucun love.*.
--
-- Le contenu ajouté plus tard (reliques) suivra le MÊME pattern, idéalement 1 fichier par relique
-- qui fait `require("src.effects.engine").register(...)`. Ici on regroupe le vocabulaire de base.
--
-- Contrat ctx (rempli par arena.lua) :
--   ctx.arena   = l'arène (pour ctx.arena:damage / ctx.arena.rng)
--   ctx.source  = le PORTEUR de l'effet (l'attaquant pour on_attack/on_hit ; le défenseur pour on_attacked)
--   ctx.victim  = l'autre partie
--   ctx.amount  = dégâts sortants (mutables par les ops on_attack)
--   ctx.dealt   = PV réellement infligés (lisible par les ops on_hit, ex. vol de vie)

local Effects = require("src.effects.engine")
local Stats = require("src.effects.stats") -- couche de modificateurs : pose de DoT renforcée + cappée (framework payoff)

local ceil, min, max = math.ceil, math.min, math.max

-- Framework PAYOFF (cf. docs/research/payoff-framework.md) : une pose de DoT amplifiée = base × (1+Σinc),
-- bornée à ×3 (cap par-axe anti-snowball). `inc` (nombre) vient de l'aura bakée sur le porteur au build.
local DOT_CAP_MULT = 3
local function ampDps(base, inc)
  if not inc or inc == 0 then return base end
  return Stats.resolve(base, { Stats.increased(inc) }, { max = base * DOT_CAP_MULT, round = "nearest" })
end

-- SPREAD proportionnel à l'investissement de la SOURCE (décision design #3), borné par famille.
local function spreadValue(load, frac, lo, hi)
  return max(lo, min(hi, ceil(load * frac)))
end

-- Brutalite (marauder) : +value dégâts sur la 1re frappe du combat.
Effects.register("bonus_first", function(ctx, p)
  local s = ctx.source
  if s.firstHit then
    ctx.amount = ctx.amount + (p.value or 0)
    s.firstHit = false
  end
end)

-- Sangsue (demon) : soigne le porteur de frac × dégâts infligés. Le malus de valeur (poison) le réduit.
Effects.register("lifesteal", function(ctx, p)
  local dealt = ctx.dealt or 0
  if dealt > 0 then
    local s = ctx.source
    local frac = (p.frac or 0) * (1 - (s.weaken or 0)) -- weaken (poison) ronge le taux de soin
    s.hp = math.min(s.maxHp, s.hp + math.floor(dealt * frac + 0.5))
  end
end)

-- Venin (witch + famille POISON) : pousse un STACK de poison (axe « nombre ») sur la victime, plus un
-- éventuel malus de valeur (weaken). N stacks indépendants ; cap anti-explosion (retire le plus ancien).
-- On mémorise la source pour l'attribution des dégâts (event-log / stats d'équilibrage).
Effects.register("poison", function(ctx, p)
  local v = ctx.victim
  local stacks = v.dots.poison
  local tf = ctx.arena.teamFlags and ctx.arena.teamFlags[ctx.source.team] -- THE FESTERING : sans-cap + duree++
  local cap = (tf and tf.poisonNoCap) and 99 or 8
  local dps = ampDps(p.dps or 0, ctx.source.poisonInc) -- RENFORCÉ : aura d'ampli (increased), cappé ×3
  if ctx.source.poisonInc and ctx.source.poisonInc > 0 then -- signal « ça s'allume » (RENDER, golden-safe)
    ctx.arena.bus:emit("amped", { unit = v, family = "poison" })
  end
  stacks[#stacks + 1] = { dps = dps, remaining = (p.dur or 0) + ((tf and tf.poisonDurBonus) or 0),
    acc = 0, weaken = p.weaken or 0, source = ctx.source }
  if #stacks > cap then table.remove(stacks, 1) end -- POISON_STACK_CAP (levé par The Festering)
  if p.igniteAt then -- VENOM-CENSER : arme la détonation au seuil (poison->burn), tickée par tickDots
    v.igniteAt = p.igniteAt
    v.igniteDps = (p.igniteBurst and p.igniteBurst.dps) or 8
    v.igniteDur = (p.igniteBurst and p.igniteBurst.dur) or 120
    v.igniteSrc = ctx.source
  end
  if p.shieldEat and v.shield and v.shield > 0 then -- ACID-MAW : le venin DISSOUT l'armure (par pose)
    v.shield = math.floor(v.shield * (1 - p.shieldEat))
  end
  if p.spread then -- PLAGUE-BEARER : CONTAGION proportionnelle au FARDEAU de la cible (payoff ressenti, cappé)
    local load = 0
    for i = 1, #stacks do load = load + (stacks[i].dps or 0) end -- Σ dps des stacks de la cible = investissement
    local sdps = spreadValue(load, 0.70, 4, 12)                  -- frac 0.70, MIN 4, CAP 12 (anti-snowball)
    local sdur = max(120, min(240, ceil((p.dur or 180) * 0.66))) -- assez long pour tick ET être vu
    local capped = sdps >= 12
    for _, nb in ipairs(ctx.arena:neighborsOf(v)) do
      local ns = nb.dots.poison
      ns[#ns + 1] = { dps = sdps, remaining = sdur, acc = 0, weaken = 0, source = ctx.source, viaSpread = true }
      if #ns > 8 then table.remove(ns, 1) end
      -- RENDER : arc dont la taille ∝ magnitude (golden-safe : aucun abonné SIM). viaSpread = profondeur 1.
      ctx.arena.bus:emit("spread", { from = v, to = nb, family = "poison", magnitude = sdps, capped = capped })
    end
  end
end)

-- Os brises (skeleton) : renvoie value dégâts à l'attaquant (ignore le bouclier).
Effects.register("thorns", function(ctx, p)
  ctx.arena:damage(ctx.victim, p.value or 0, { ignoreShield = true, source = ctx.source, cause = "thorns" })
end)

-- COUNTER de bouclier (framework payoff §3.4, « loi du même lot ») : la frappe DISSOUT une fraction du
-- bouclier de la cible (pierce/strip). Contre les murs de boucliers périodiques.
Effects.register("strip_shield", function(ctx, p)
  local v = ctx.victim
  if v.shield and v.shield > 0 then v.shield = math.floor(v.shield * (1 - (p.frac or 0.5))) end
end)

-- Rempart (templar / shield_aura) : aura d'adjacence -> RÉSOLUE AU BUILD via le graphe du plateau
-- (cf. src/scenes/build.lua), pas en combat (l'arène ne connaît pas les voisins). Pas d'op combat.

-- ── Familles d'altérations (cf. docs/research/effects-dot-families.md). La POSE est ici ; le TICK est
-- dans arena:tickDots (ordre fixe, accumulation entière). Chiffres = PLACEHOLDERS (équilibrage via sim). ──

-- BRÛLURE : pose/rallume une brûlure (intensité qui décroît). Garde la plus FORTE (remplace si dps >).
Effects.register("burn", function(ctx, p)
  local v = ctx.victim
  local dps = ampDps(p.dps or 0, ctx.source.burnInc) -- RENFORCÉ : aura d'ampli (increased), cappé ×3
  if ctx.source.burnInc and ctx.source.burnInc > 0 then -- signal « ça s'allume » (RENDER, golden-safe)
    ctx.arena.bus:emit("amped", { unit = v, family = "burn" })
  end
  local cur = v.dots.burn
  if not cur or dps > cur.dps then
    v.dots.burn = { dps = dps, remaining = p.dur or 180, acc = 0,
      decayEvery = p.decayEvery or 60, decayAcc = 0, decayPct = p.decayPct or 0.30, source = ctx.source }
  elseif p.mode == "extend_if_weaker" then -- KILN-WARDEN : le surplus (plus faible) PROLONGE au lieu d'être perdu
    cur.remaining = cur.remaining + (p.dur or 0)
  elseif p.refresh then
    cur.remaining = math.max(cur.remaining, p.dur or 0)
  end
end)

-- SAIGNEMENT : pose un saignement (bas DPS) + un SLOW de cadence (retiré à l'expiration par tickDots).
Effects.register("bleed", function(ctx, p)
  local v = ctx.victim
  local cur = v.dots.bleed
  if not cur then
    v.dots.bleed = { dps = p.dps or 0, remaining = p.dur or 240, acc = 0, slowPct = p.slowPct or 0,
      slowScalesMissingHp = p.slowScalesMissingHp, aggravateMult = p.aggravateMult, dynBonus = 0, source = ctx.source }
    v.atkSlow = v.atkSlow + (p.slowPct or 0)
  else
    if (p.dps or 0) > cur.dps then cur.dps = p.dps end
    cur.remaining = math.max(cur.remaining, p.dur or 0)
    if p.slowScalesMissingHp then cur.slowScalesMissingHp = true end -- conserve les flags T2 si réappliqué
    if p.aggravateMult then cur.aggravateMult = p.aggravateMult end
  end
end)

-- POURRITURE : pose/enfle une pourriture (durée croissante) ; ampute les PV max au tick (maxHpFrac).
Effects.register("rot", function(ctx, p)
  local v = ctx.victim
  local cur = v.dots.rot
  if not cur then
    v.dots.rot = { dps = p.base or 1, remaining = p.dur or 240, acc = 0,
      capDps = p.capDps or 10, maxHpFrac = p.maxHpFrac or 0, source = ctx.source }
  else
    cur.dps = math.min(cur.capDps, cur.dps + (p.growth or 1)) -- enfle si entretenue
    cur.remaining = p.dur or cur.remaining
  end
end)

-- CHOC : charge un CONDENSATEUR sur la victime (axe stacks). AUCUN dégât ici : la DÉCHARGE (stacks × volt)
-- se fait à la frappe (Arena:dischargeShock) en une instance cause="shock". `volt` = dégâts/stack (déf. 3).
local SHOCK_STACK_CAP = 8 -- miroir de la constante d'arena (ops.lua sans dépendance à arena)
Effects.register("shock", function(ctx, p)
  local v = ctx.victim
  local cap = math.min(p.cap or SHOCK_STACK_CAP, SHOCK_STACK_CAP)
  local cur = v.dots.shock
  if not cur then
    v.dots.shock = { stacks = math.min(cap, p.add or 1), remaining = p.dur or 180,
      cap = cap, volt = p.volt, source = ctx.source }
  else
    cur.stacks = math.min(cur.cap, cur.stacks + (p.add or 1))
    cur.remaining = p.dur or cur.remaining
    if p.volt and (not cur.volt or p.volt > cur.volt) then cur.volt = p.volt end
  end
end)

-- REGEN (contre-DoT) : arme un soin/seconde sur le porteur (combat_start). Tické par arena:tickDots.
Effects.register("regen", function(ctx, p)
  ctx.source.regen = (ctx.source.regen or 0) + (p.value or 0)
end)

-- ── PROPAGATION À LA MORT (trigger on_death, broadcast par l'arène en fin de frame). « Voisins » =
-- proximité du CHAMP DE BATAILLE (arena:neighborsOf), PAS le graphe du sigil (cf. décision d'archi dans
-- arena.lua). On ne pose que des DoT (zéro dégât immédiat -> pas de cascade de mort). ctx.victim = le mort ;
-- ctx.source = le porteur (l'afflicteur du camp adverse). cf. effects-dot-families.md §H. ──

-- WILDFIRE-HOUND / PLAGUE-PYRE : à la mort d'un ennemi EN FEU, la brûlure saute à ses voisins (+ venin pour Plague-Pyre).
Effects.register("spread_burn_on_death", function(ctx, p)
  local dead = ctx.victim
  local db = dead.dots and dead.dots.burn
  if not db or db.viaSpread then return end -- mort en feu DIRECT seulement (profondeur 1 : la contagion ne chaîne pas)
  local dps = spreadValue(db.dps or 0, 0.75, 4, 14) -- proportionnel au feu du mort, CAP 14
  local capped = dps >= 14
  for _, nb in ipairs(ctx.arena:neighborsOf(dead)) do
    local cur = nb.dots.burn
    if not cur or dps > cur.dps then
      nb.dots.burn = { dps = dps, remaining = p.dur or 120, acc = 0,
        decayEvery = 60, decayAcc = 0, decayPct = 0.30, source = ctx.source, viaSpread = true }
      ctx.arena.bus:emit("spread", { from = dead, to = nb, family = "burn", magnitude = dps, capped = capped })
    end
    if p.alsoPoison then -- croisement feu->poison (Plague-Pyre) : le feu sème aussi le venin (proportionnel, cap 8)
      local seed = spreadValue(db.dps or 0, 0.35, 2, 8)
      local ns = nb.dots.poison
      ns[#ns + 1] = { dps = seed, remaining = p.alsoPoison.dur or 120, acc = 0, weaken = 0, source = ctx.source, viaSpread = true }
      if #ns > 8 then table.remove(ns, 1) end
      ctx.arena.bus:emit("spread", { from = dead, to = nb, family = "poison", magnitude = seed, capped = seed >= 8 })
    end
  end
end)

-- BLIGHT-SPREADER : à la mort d'une cible POURRIE, la pourriture se pose sur ses voisins.
Effects.register("spread_rot", function(ctx, p)
  local dead = ctx.victim
  local dr = dead.dots and dead.dots.rot
  if not dr or dr.viaSpread then return end -- mort pourri DIRECT seulement (profondeur 1)
  local dps = spreadValue(dr.dps or 2, 0.75, 4, 14) -- proportionnel à la pourriture (déjà enflée) du mort, CAP 14
  local capped = dps >= 14
  for _, nb in ipairs(ctx.arena:neighborsOf(dead)) do
    if not nb.dots.rot then
      nb.dots.rot = { dps = dps, remaining = p.dur or 240, acc = 0,
        capDps = p.capDps or 14, maxHpFrac = p.maxHpFrac or 0, source = ctx.source, viaSpread = true }
      ctx.arena.bus:emit("spread", { from = dead, to = nb, family = "rot", magnitude = dps, capped = capped })
    end
  end
end)

-- ── TRANSFORMS T3 (combat_start) — GRANT_TEAM pose des DRAPEAUX d'équipe (lus par le tick/les ops) et/ou
-- des AURAS immédiates. Le T3 ne scale QUE ses stats, jamais son seuil ni sa bascule (anti double-snowball,
-- cf. effects-design.md §3). cf. effects-dot-families.md §H. ──
Effects.register("grant_team", function(ctx, p)
  local arena, team = ctx.arena, ctx.source.team
  local tf = arena.teamFlags and arena.teamFlags[team]
  if tf then
    if p.burnNoDecay then tf.burnNoDecay = true end                         -- ASH-MAW : feux sans décroissance
    if p.poisonNoCap then tf.poisonNoCap = true end                         -- THE FESTERING : poison sans cap
    if p.poisonDurBonus then tf.poisonDurBonus = (tf.poisonDurBonus or 0) + p.poisonDurBonus end
  end
  if p.slowEnemies then -- THE SLOW BLEED : aura de slow sur TOUTE l'équipe ennemie (immédiate)
    for _, w in ipairs(arena.units) do
      if w.alive and w.team ~= team then w.atkSlow = w.atkSlow + p.slowEnemies end
    end
  end
  if p.rotEnemies then -- THE PIT-MAW : la présence pourrit toute l'équipe ennemie (immédiate)
    local re = p.rotEnemies
    for _, w in ipairs(arena.units) do
      if w.alive and w.team ~= team and not w.dots.rot then
        w.dots.rot = { dps = re.base or 1, remaining = re.dur or 240, acc = 0,
          capDps = re.capDps or 8, maxHpFrac = re.maxHpFrac or 0.10, source = ctx.source }
      end
    end
  end
end)

-- MARROW-DRINKER (croisement saignement->pourriture) : sur une cible DÉJÀ saignante, le coup convertit
-- le sang noir en nécrose (pose/enfle une pourriture, consomme le bleed). Payoff conditionnel d'usure.
Effects.register("convert_to_rot", function(ctx, p)
  local v = ctx.victim
  if not v.dots.bleed then return end -- seulement si la cible saigne (synergie cross-famille)
  if not v.dots.rot then
    v.dots.rot = { dps = p.base or 2, remaining = p.dur or 240, acc = 0,
      capDps = p.capDps or 10, maxHpFrac = p.maxHpFrac or 0.10, source = ctx.source }
  else
    v.dots.rot.dps = math.min(v.dots.rot.capDps, v.dots.rot.dps + (p.growth or 1))
  end
  v.atkSlow = math.max(0, v.atkSlow - (v.dots.bleed.slowPct or 0) - (v.dots.bleed.dynBonus or 0))
  v.dots.bleed = nil -- la plaie se nécrose : le bleed devient pourriture
end)

return Effects
