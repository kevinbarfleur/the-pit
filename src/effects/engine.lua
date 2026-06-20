-- src/effects/engine.lua
-- Moteur d'effets DÉCOUPLÉ (couche SIM, zéro love.*). Un effet = DONNÉE pure :
--   { trigger, op, params, condition?, target? }
-- Le porteur (unité) tient une LISTE d'effets. À chaque point de hook (on_attack, on_hit,
-- on_attacked, combat_start...), Effects.run(porteur, trigger, ctx) exécute les effets dont le
-- trigger correspond, via le REGISTRE d'ops.
--
-- Principe ouvert/fermé (le cœur de la demande) : ajouter un effet / une relique =
--   1) enregistrer un op : Effects.register("mon_effet", function(ctx, params, e) ... end)
--   2) poser une ligne de data sur l'unité/relique
-- JAMAIS éditer la boucle de combat. L'op n°50 ne peut pas casser le n°1 (ils ne se référencent
-- jamais, seulement le contrat de ctx). cf. docs/research/engine-architecture.md §6.

local EMPTY = {}

local Effects = { ops = {} }

-- Enregistre un op. Public -> une relique = un fichier autonome qui appelle Effects.register(...).
function Effects.register(name, fn)
  assert(type(name) == "string", "op sans nom")
  assert(not Effects.ops[name], "op deja enregistre: " .. name)
  Effects.ops[name] = fn
  return fn
end

-- Condition optionnelle (skip GRACIEUX, jamais de crash). RNG SEEDÉ via ctx.arena.rng (déterminisme).
function Effects.passCondition(cond, ctx)
  if not cond then return true end
  if cond.kind == "chance" then
    return ctx.arena.rng:random() < (cond.value or 1)
  end
  return true -- condition inconnue -> tolérant : ne bloque pas
end

-- Exécute les effets d'un porteur pour un trigger donné, dans l'ORDRE DE LA LISTE (déterministe).
-- ctx = table RÉUTILISÉE (perf : aucune allocation par hook). Champs attendus selon le hook :
--   ctx.arena, ctx.source (porteur de l'effet), ctx.victim, ctx.amount, ctx.dealt.
function Effects.run(owner, trigger, ctx)
  local list = owner.effects
  if not list then return end
  for i = 1, #list do
    local e = list[i]
    if e.trigger == trigger and Effects.passCondition(e.condition, ctx) then
      local op = Effects.ops[e.op]
      if op then op(ctx, e.params or EMPTY, e) end -- op absent -> ignoré (comme une part de rig absente)
    end
  end
end

return Effects
