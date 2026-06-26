-- src/effects/whispers_ops.lua
-- OPS RESOLVER des MURMURES (3e couche cachée — du spice). cf. docs/research/murmures-plan.md §2.
-- Couche SIM PURE (aucun love.*, RNG seedé via ctx.arena.rng uniquement). Deux ops généralistes
-- couvrent tous les murmures NON-RNG de la v1 ; le dodge (RNG) reste OFF (W7).
--
-- CONTRAT (data dans src/data/whispers.lua, DÉCLARATIF PUR) : un murmure = un effet du roster
--   { trigger, op, params, condition? } + { kind, key, partner?, verb }.
-- L'op LIT params.effect (table bornée) et POSE le bonus sur le porteur via les CHAMPS combat-time
-- EXISTANTS (atkInc/burnInc/dmgReduce/... lus par hit()/damage()/la pose de DoT), puis ÉMET l'event
-- `murmur` 2 canaux (canal joueur cryptique + canal dev trueKind/trueValue). cf. §4.
--
-- BORNES (le contrat §0) : `stat_inc` ≤ 0.10 en `increased` (additif, déterministe, cappé à la lecture)
-- OU 1 `oneshot`. Le cumul (`husk`) est plafonné par `capStacks` et ré-appliqué sur la base mémorisée
-- (pattern `frenzy_gain` -> pas de dérive d'arrondi). Tout GATED : aucune unité du roster ne porte ces
-- ops par défaut (les murmures sont mergés PAR ID au combat_start, voie A) -> empreinte golden inchangée.

local Effects = require("src.effects.engine")
local Units = require("src.data.units")

local min, max, floor = math.min, math.max, math.floor

-- Borne DURE d'un murmure stat (garde-fou : la data ne DOIT déjà pas dépasser, mais on clampe à la pose
-- pour qu'un placeholder mal réglé reste du spice). 10% en valeur d'`increased`/de fraction.
local WHISPER_STAT_CAP = 0.10

-- Applique l'effet BORNÉ d'un murmure sur le porteur `u`. Écrit un CHAMP combat-time existant -> le moteur
-- (hit/damage/pose de DoT) le lit déjà. Renvoie (trueKind, trueValue) pour le canal dev de l'event.
local function applyEffect(u, eff)
  if not eff then return nil, nil end
  local kind = eff.kind
  if kind == "stat_inc" then
    local v = min(WHISPER_STAT_CAP, eff.value or 0)
    local stat = eff.stat
    if stat == "atkInc" or stat == "burnInc" or stat == "poisonInc" or stat == "bleedInc"
       or stat == "rotInc" or stat == "dmgReduce" or stat == "lifestealBonus" then
      -- champs lus DIRECTEMENT par le moteur (increased/fraction). Additif -> commutatif, déterministe.
      u[stat] = (u[stat] or 0) + v
      return "stat_inc", v
    elseif stat == "statInc" or stat == "dmgInc" then
      -- « stats globales » : non lues en combat (statInc est baké au build) -> on les MATÉRIALISE sur le
      -- dmg courant, base mémorisée (pas de dérive). Cumul BORNÉ via capStacks (husk : +5%/mort, cap 4).
      u._whisperBase = u._whisperBase or u.dmg
      local capS = eff.capStacks or 1
      u._whisperStacks = min(capS, (u._whisperStacks or 0) + 1)
      u.dmg = floor(u._whisperBase * (1 + u._whisperStacks * v) + 0.5)
      return "stat_inc", v * u._whisperStacks
    end
  elseif kind == "oneshot" then
    -- ONE-SHOT borné : pose un petit ampli persistant sur le champ visé (placeholder de la sémantique
    -- « 1re instance plus intense » sans nouveau hook dans les ops d'affliction — cf. report W2).
    local v = min(WHISPER_STAT_CAP, eff.value or 0)
    local field = eff.field
    if field then u[field] = (u[field] or 0) + v end
    return "oneshot", v
  end
  return nil, nil
end

-- Émet l'event `murmur` 2 canaux (RENDER-only, golden-safe : aucun abonné SIM n'altère l'issue). cf. §4.
--   CANAL JOUEUR  : key/source/partner/verb -> phrasé cryptique i18n, ZÉRO chiffre.
--   CANAL DEV     : trueKind/trueValue -> event-log/sim (la VRAIE magnitude, jamais affichée au joueur).
local function emitMurmur(ctx, e, source, partner, trueKind, trueValue)
  ctx.arena.bus:emit("murmur", {
    key = e.key, source = source, partner = partner, verb = e.verb,
    trueKind = trueKind, trueValue = trueValue,
  })
end

-- Présence d'un ALLIÉ (id == partnerId) OU d'un allié posant la famille `family`. `reach`="presence"
-- (toute l'équipe) | "adjacency" (voisins-champ de la source). Déterministe (ipairs), zéro RNG.
local function findPartner(arena, source, partnerId, family, reach)
  local pool
  if reach == "adjacency" then pool = arena:neighborsOf(source)
  else pool = arena.units end
  for _, w in ipairs(pool) do
    if w.alive and w ~= source and (reach == "adjacency" or w.team == source.team) then
      if partnerId and w.id == partnerId then return w end
      if family and not partnerId then
        local fam = Units.dotFamily and Units.dotFamily[w.id]
        if fam == family then return w end
      end
    end
  end
  return nil
end

-- ── whisper_lineage (DUO) — combat_start : un PARTENAIRE (présence/adjacence) renforce le porteur. ──
-- params = { needPartner?=id, needFamily?="burn"|..., reach="presence"|"adjacency", effect={...} }.
Effects.register("whisper_lineage", function(ctx, p, e)
  local source = ctx.source
  if not (source and source.alive) then return end
  local found = findPartner(ctx.arena, source, p.needPartner, p.needFamily, p.reach or "presence")
  if not found then return end -- pas de partenaire -> murmure inerte (rien posé, rien émis)
  local tk, tv = applyEffect(source, p.effect)
  if tk then emitMurmur(ctx, e, source, found, tk, tv) end
end)

-- ── whisper_solo (SOLO) — condition portée sur le PORTEUR (seuil/mort d'allié/position/durée). ──
-- params = { threshold?, afterT?, aloneOfType?, effect={...} }. Les variantes :
--   on_low_hp     : franchissement de seuil (géré par arena:checkLowHp + params.threshold) -> applique.
--   on_ally_death : cumul borné (capStacks) à chaque mort alliée (géré par le broadcast différé).
--   combat_start  : aloneOfType (aucun allié de ce `type`) -> applique immédiat ; afterT -> ARMÉ (tické).
Effects.register("whisper_solo", function(ctx, p, e)
  local source = ctx.source
  if not (source and source.alive) then return end
  -- aloneOfType : aucun AUTRE allié vivant du même `type` (ex. SKULL COLOSSUS seul de son espèce os).
  if p.aloneOfType then
    for _, w in ipairs(ctx.arena.units) do
      if w.alive and w ~= source and w.team == source.team and not w.isCommander
         and Units[w.id] and Units[w.id].type == p.aloneOfType then
        return -- un congénère présent -> pas seul -> murmure inerte
      end
    end
  end
  -- afterT : armer un murmure DIFFÉRÉ (le porteur n'agit qu'après ~N frames de combat). Tické par l'arène
  -- (Arena:tickWhispers) qui appliquera l'effet + émettra l'event au franchissement. Pose data, zéro RNG.
  if p.afterT and ctx.source._whisperTimed == nil then
    -- key/verb vivent sur le DESCRIPTEUR `e` (pas dans params `p`) : on les capture pour le futur emit.
    source._whisperTimed = { afterT = p.afterT, effect = p.effect, key = e.key, verb = e.verb }
    return
  end
  -- Sinon (on_low_hp / on_ally_death / aloneOfType-validé / combat_start immédiat) : applique tout de suite.
  local tk, tv = applyEffect(source, p.effect)
  if tk then emitMurmur(ctx, e, source, nil, tk, tv) end
end)

-- ── whisper_apply — pose immédiate d'un murmure ARMÉ (afterT), appelée par Arena:tickWhispers au
-- franchissement du délai. `e` = { effect, key, verb } (le bloc armé). Même chemin que whisper_solo
-- immédiat (applique l'effet borné + émet l'event 2 canaux). Pas de re-check de condition (déjà passée). ──
Effects.register("whisper_apply", function(ctx, p, e)
  local source = ctx.source
  if not (source and source.alive) then return end
  local tk, tv = applyEffect(source, p.effect or (e and e.effect))
  if tk then emitMurmur(ctx, e, source, nil, tk, tv) end
end)

return Effects
