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
  local stacks = ctx.victim.dots.poison
  stacks[#stacks + 1] = { dps = p.dps or 0, remaining = p.dur or 0, acc = 0,
    weaken = p.weaken or 0, source = ctx.source }
  if #stacks > 8 then table.remove(stacks, 1) end -- POISON_STACK_CAP : rare, retire le plus ancien
end)

-- Os brises (skeleton) : renvoie value dégâts à l'attaquant (ignore le bouclier).
Effects.register("thorns", function(ctx, p)
  ctx.arena:damage(ctx.victim, p.value or 0, { ignoreShield = true, source = ctx.source, cause = "thorns" })
end)

-- Rempart (templar / shield_aura) : aura d'adjacence -> RÉSOLUE AU BUILD via le graphe du plateau
-- (cf. src/scenes/build.lua), pas en combat (l'arène ne connaît pas les voisins). Pas d'op combat.

-- ── Familles d'altérations (cf. docs/research/effects-dot-families.md). La POSE est ici ; le TICK est
-- dans arena:tickDots (ordre fixe, accumulation entière). Chiffres = PLACEHOLDERS (équilibrage via sim). ──

-- BRÛLURE : pose/rallume une brûlure (intensité qui décroît). Garde la plus FORTE (remplace si dps >).
Effects.register("burn", function(ctx, p)
  local v = ctx.victim
  local dps = p.dps or 0
  local cur = v.dots.burn
  if not cur or dps > cur.dps then
    v.dots.burn = { dps = dps, remaining = p.dur or 180, acc = 0,
      decayEvery = p.decayEvery or 60, decayAcc = 0, decayPct = p.decayPct or 0.30, source = ctx.source }
  elseif p.refresh then
    cur.remaining = math.max(cur.remaining, p.dur or 0)
  end
end)

-- SAIGNEMENT : pose un saignement (bas DPS) + un SLOW de cadence (retiré à l'expiration par tickDots).
Effects.register("bleed", function(ctx, p)
  local v = ctx.victim
  local cur = v.dots.bleed
  if not cur then
    v.dots.bleed = { dps = p.dps or 0, remaining = p.dur or 240, acc = 0, slowPct = p.slowPct or 0, source = ctx.source }
    v.atkSlow = v.atkSlow + (p.slowPct or 0)
  else
    if (p.dps or 0) > cur.dps then cur.dps = p.dps end
    cur.remaining = math.max(cur.remaining, p.dur or 0)
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

-- CHOC : empile du choc (amplification de dégâts-pris). shockAmp recalculé par tickDots (cap dur).
Effects.register("shock", function(ctx, p)
  local v = ctx.victim
  local cur = v.dots.shock
  if not cur then
    v.dots.shock = { stacks = math.min(p.cap or 8, p.add or 1), remaining = p.dur or 180,
      perStack = p.perStack or 0.06, cap = p.cap or 8 }
  else
    cur.stacks = math.min(cur.cap, cur.stacks + (p.add or 1))
    cur.remaining = p.dur or cur.remaining
  end
end)

-- REGEN (contre-DoT) : arme un soin/seconde sur le porteur (combat_start). Tické par arena:tickDots.
Effects.register("regen", function(ctx, p)
  ctx.source.regen = (ctx.source.regen or 0) + (p.value or 0)
end)

return Effects
