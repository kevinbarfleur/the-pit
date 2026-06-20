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

-- Sangsue (demon) : soigne le porteur de frac × dégâts infligés.
Effects.register("lifesteal", function(ctx, p)
  local dealt = ctx.dealt or 0
  if dealt > 0 then
    local s = ctx.source
    s.hp = math.min(s.maxHp, s.hp + math.floor(dealt * (p.frac or 0) + 0.5))
  end
end)

-- Venin (witch) : applique un poison à la victime (dps/s pendant dur frames). Géré au tick par arena.
-- On mémorise la source pour l'attribution des dégâts (event-log / stats d'équilibrage).
Effects.register("poison", function(ctx, p)
  ctx.victim.poison = { dps = p.dps or 0, remaining = p.dur or 0, acc = 0, source = ctx.source }
end)

-- Os brises (skeleton) : renvoie value dégâts à l'attaquant (ignore le bouclier).
Effects.register("thorns", function(ctx, p)
  ctx.arena:damage(ctx.victim, p.value or 0, { ignoreShield = true, source = ctx.source, cause = "thorns" })
end)

-- Rempart (templar / shield_aura) : aura d'adjacence -> RÉSOLUE AU BUILD via le graphe du plateau
-- (cf. src/scenes/build.lua), pas en combat (l'arène ne connaît pas les voisins). Pas d'op combat.

return Effects
