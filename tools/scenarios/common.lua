-- tools/scenarios/common.lua
-- SOCLE PARTAGÉ du MOTEUR DE SCÉNARIOS d'équilibrage (Phase C.0). Tous les modes (invest/policy/godroll/
-- commander/counter/economy/tank/pacing/sweep/coherence) en dépendent. PUR-par-dépendance : aucun love.graphics ; le seul hasard est un RNG
-- SEEDÉ injecté par chaque mode (love.math.newRandomGenerator) — JAMAIS math.random global pour la sim.
--
-- Réutilise l'EXISTANT (ne réinvente rien) :
--   · Compcost.of  : modèle d'INVESTISSEMENT (or × niveau + slots + relique + sigil + agencement) -> le
--     « juge suprême » (§2.5) : on ne flague que ce qui gagne SOUS son coût hors counter intentionnel.
--   · Match.run    : un combat SIM-pur seedé (verdict + ticks) -> brique de tous les modes.
--   · tools/gamed/json : encodeur trié -> rapports DIFF-ABLES (clés ordonnées, déterministe).
--   · Policies.archetypeOf : classifieur unité -> archétype (pour étiqueter compos et matrice).
--
-- RAPPORTS : chaque mode écrit runs/report-<mode>.json (diff-able) ET un golden de méta runs/report-ref.json
-- (cf. §2.7-5) qu'on diffe patch-sur-patch. Le P0 (tools/sim.lua nominal) garde son runs/report.json intact.

package.path = "./?.lua;" .. package.path

local Compcost = require("src.lab.compcost")
local Match = require("src.combat.match")
local Policies = require("src.lab.policies")
local Compositions = require("src.data.compositions")
local Bands = require("src.lab.bands")
local Json = require("tools.gamed.json")

local Common = {}

Common.json = Json
Common.FPS = 60
Common.DEFAULT_FATIGUE_START = 1020

-- ── RÉPERTOIRE DE SORTIE des rapports. Défaut "runs" (le golden de méta de référence). Override par
-- PIT_SCEN_OUT (ex. le SMOKE de tests/scenarios.lua redirige vers un dossier JETABLE pour NE PAS écraser le
-- runs/report-ref.json de référence avec des données à N=1). Tous les chemins passent par Common.outDir(). ──
local OUT_DIR = os.getenv("PIT_SCEN_OUT")
if not OUT_DIR or OUT_DIR == "" then OUT_DIR = "runs" end
function Common.outDir() return OUT_DIR end

local function trim(s)
  return tostring(s or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

function Common.clone(v)
  if type(v) ~= "table" then return v end
  local out = {}
  for k, vv in pairs(v) do out[k] = Common.clone(vv) end
  return out
end

function Common.env(name)
  local v = os.getenv(name)
  if not v or v == "" then return nil end
  return v
end

function Common.envAny(names)
  for _, name in ipairs(names or {}) do
    local v = Common.env(name)
    if v then return v, name end
  end
  return nil, nil
end

function Common.envNumber(name, default)
  local v = Common.env(name)
  if not v then return default end
  local n = tonumber(v)
  assert(n ~= nil, name .. " doit etre numerique, recu: " .. tostring(v))
  return n
end

function Common.csv(value)
  local out = {}
  for part in tostring(value or ""):gmatch("[^,]+") do
    local p = trim(part)
    if p ~= "" then out[#out + 1] = p end
  end
  return out
end

function Common.envCsv(name)
  local v = Common.env(name)
  return v and Common.csv(v) or nil
end

function Common.envCsvAny(names)
  local v = Common.envAny(names)
  return v and Common.csv(v) or nil
end

function Common.envNumberList(name, default)
  local parts = Common.envCsv(name)
  if not parts then return default end
  local out = {}
  for _, p in ipairs(parts) do
    local n = tonumber(p)
    assert(n ~= nil, name .. " doit contenir des nombres separes par virgules, recu: " .. tostring(p))
    out[#out + 1] = n
  end
  return out
end

function Common.idSet(ids)
  if not ids then return nil end
  local set, order = {}, {}
  for _, id in ipairs(ids) do
    if not set[id] then
      set[id] = true
      order[#order + 1] = id
    end
  end
  return set, order
end

function Common.filteredRows(rows, ids, key)
  local set, order = Common.idSet(ids)
  if not set then return Common.clone(rows) end
  key = key or "id"
  local byId, out = {}, {}
  for _, row in ipairs(rows or {}) do byId[row[key]] = row end
  for _, id in ipairs(order) do
    assert(byId[id], "profil inconnu dans filtre: " .. tostring(id))
    out[#out + 1] = Common.clone(byId[id])
  end
  return out
end

function Common.paceProfiles(defaults, opts)
  opts = opts or {}
  local custom = Common.envAny({ opts.specEnv or "PIT_PACE_PROFILES", opts.fallbackSpecEnv })
  local rows = {}
  if custom then
    -- Format: id:hpMult:cdMult:fatigueStart[:fatigueBase[:fatigueRamp]],...
    for _, spec in ipairs(Common.csv(custom)) do
      local parts = {}
      for p in spec:gmatch("[^:]+") do parts[#parts + 1] = trim(p) end
      assert(#parts >= 4, "profil pacing invalide: " .. spec)
      rows[#rows + 1] = {
        id = parts[1],
        label = parts[1],
        hpMult = assert(tonumber(parts[2]), "hpMult invalide dans " .. spec),
        cdMult = assert(tonumber(parts[3]), "cdMult invalide dans " .. spec),
        fatigueStart = assert(tonumber(parts[4]), "fatigueStart invalide dans " .. spec),
        fatigueBase = tonumber(parts[5]),
        fatigueRamp = tonumber(parts[6]),
      }
    end
  else
    rows = Common.clone(defaults)
  end
  local filter = Common.envCsvAny({ opts.filterEnv or "PIT_PACE_IDS", opts.fallbackFilterEnv })
  return Common.filteredRows(rows, filter)
end

-- ── RÉSOLUTION d'une compo par id dans LES DEUX sources : le catalogue (src/data/compositions) ET les bandes
-- (src/lab/bands : compos paramétriques par stade early/mid/end). Format IDENTIQUE ({sigil,boardLevel,units}).
-- ERREUR si introuvable (anti-angle-mort : un id mal orthographié ne doit PAS être sauté silencieusement —
-- c'est exactement le bug qui faisait disparaître les candidats shock du god-roll explorer). ──
function Common.compById(id)
  local c = Compositions.byId[id] or Bands.byId[id]
  assert(c, "compo introuvable (ni catalogue ni bandes) : " .. tostring(id))
  return c
end

-- Variante NON-fatale : renvoie la compo ou nil (pour les champs optionnels où l'absence est tolérée).
function Common.compByIdOrNil(id) return Compositions.byId[id] or Bands.byId[id] end

-- ── DESIGNED : counters INTENTIONNELS (cf. balance-sim-design.md §4 + psychologie §2.5). On ne flague
-- JAMAIS l'attaquant si (attArch -> {defArch...}) est listé : c'est le counter VOULU (le DoT perce le mur).
-- attArch gagne LÉGITIMEMENT contre defArch même sous son coût -> c'est la récompense d'un matchup conçu,
-- pas un déséquilibre. Cure manuelle au fil du design (ce n'est PAS auto-généré). ──
Common.DESIGNED = {
  poison = { tank = true },
  burn   = { tank = true },
  rot    = { tank = true },
  shock  = { tank = true },
  bleed  = { bruiser = true },
  tank   = { bruiser = true },
}

-- Le matchup (att -> def) est-il un counter intentionnel (à NE PAS flaguer) ?
function Common.isDesigned(attArch, defArch)
  local row = Common.DESIGNED[attArch]
  return row ~= nil and row[defArch] == true
end

-- ── INVESTISSEMENT d'une compo-catalogue (format { sigil, boardLevel, units = {{id,slot,level?}}, relics? }).
-- Délègue à Compcost.of (source de vérité). Renvoie le descripteur complet { gold, score, maxLevel, ... }. ──
function Common.invest(comp) return Compcost.of(comp) end

-- ── ARCHÉTYPE DOMINANT d'une compo-catalogue : champ déclaré (compo de bande/catalogue) sinon vote des
-- unités (Policies.archetypeOf). Sert à étiqueter les camps pour le contexte d'invest + la matrice DESIGNED. ──
function Common.archetypeOf(comp)
  if comp.archetype then return comp.archetype end
  local tally = {}
  for _, u in ipairs(comp.units or {}) do
    local a = Policies.archetypeOf(u.id)
    tally[a] = (tally[a] or 0) + 1
  end
  local best, bestN = "bruiser", -1
  -- ordre stable (clés triées) -> déterministe en cas d'égalité
  local keys = {}
  for k in pairs(tally) do keys[#keys + 1] = k end
  table.sort(keys)
  for _, k in ipairs(keys) do if tally[k] > bestN then best, bestN = k, tally[k] end end
  return best
end

-- ── Un combat entre deux compos d'ARÈNE déjà résolues (auras bakées), seedé. Renvoie { win, decided, ticks }.
-- left/right = arrays de specs (sortie de Compbuild.toComp). hpMult forwardé (sweep PIT_HP_MULT). ──
function Common.fight(left, right, seed, hpMult)
  return Match.run(left, right, seed, { tickCap = 8000, hpMult = hpMult })
end

-- ── PERCENTILE (q ∈ [0,1]) d'un échantillon DÉJÀ TRIÉ croissant (nearest-rank, cohérent avec tools/sim.lua). ──
function Common.percentileSorted(sorted, q)
  if #sorted == 0 then return 0 end
  local i = math.min(#sorted, math.max(1, math.floor((#sorted - 1) * q + 0.5) + 1))
  return sorted[i]
end

-- Moyenne d'un array de nombres (0 si vide).
function Common.mean(xs)
  if #xs == 0 then return 0 end
  local s = 0; for _, x in ipairs(xs) do s = s + x end
  return s / #xs
end

function Common.fatigueOptions(start, base, ramp)
  if not start and not base and not ramp then return nil end
  return { start = start, base = base, ramp = ramp }
end

function Common.cooldownMutator(cdMult)
  cdMult = cdMult or 1
  if cdMult == 1 then return nil end
  return function(comp)
    for _, s in ipairs(comp or {}) do
      s.cd = math.max(1, math.floor((s.cd or 1) * cdMult + 0.5))
      if s.shieldCaster and s.shieldCaster.cd then
        s.shieldCaster.cd = math.max(1, math.floor(s.shieldCaster.cd * cdMult + 0.5))
      end
    end
  end
end

function Common.durationBucket(fatigueStart)
  return {
    n = 0, sum = 0, samples = {}, under5 = 0, fatigue = 0,
    fatigueStart = fatigueStart or Common.DEFAULT_FATIGUE_START,
  }
end

function Common.addDuration(bucket, ticks)
  if not ticks then return end
  bucket.n = bucket.n + 1
  bucket.sum = bucket.sum + ticks
  bucket.samples[#bucket.samples + 1] = ticks
  if ticks < 5 * Common.FPS then bucket.under5 = bucket.under5 + 1 end
  if ticks >= (bucket.fatigueStart or Common.DEFAULT_FATIGUE_START) then bucket.fatigue = bucket.fatigue + 1 end
end

function Common.finishDurationBucket(bucket)
  table.sort(bucket.samples)
  local p10 = Common.percentileSorted(bucket.samples, 0.10)
  local p50 = Common.percentileSorted(bucket.samples, 0.50)
  local p90 = Common.percentileSorted(bucket.samples, 0.90)
  return {
    samples = bucket.n,
    avg_ticks = (bucket.n > 0) and (bucket.sum / bucket.n) or 0,
    avg_seconds = (bucket.n > 0) and (bucket.sum / bucket.n / Common.FPS) or 0,
    p10_seconds = p10 / Common.FPS,
    p50_seconds = p50 / Common.FPS,
    p90_seconds = p90 / Common.FPS,
    under_5s_rate = (bucket.n > 0) and (bucket.under5 / bucket.n) or 0,
    fatigue_touch_rate = (bucket.n > 0) and (bucket.fatigue / bucket.n) or 0,
    fatigue_start_seconds = (bucket.fatigueStart or Common.DEFAULT_FATIGUE_START) / Common.FPS,
  }
end

function Common.durationSet(fatigueStart)
  return {
    all = Common.durationBucket(fatigueStart),
    early = Common.durationBucket(fatigueStart),
    mid = Common.durationBucket(fatigueStart),
    late = Common.durationBucket(fatigueStart),
  }
end

function Common.addRoundDuration(set, rd)
  Common.addDuration(set.all, rd.ticks)
  if (rd.round or 0) <= 3 then Common.addDuration(set.early, rd.ticks)
  elseif (rd.round or 0) <= 8 then Common.addDuration(set.mid, rd.ticks)
  else Common.addDuration(set.late, rd.ticks) end
end

function Common.finishDurationSet(set)
  return {
    all = Common.finishDurationBucket(set.all),
    early = Common.finishDurationBucket(set.early),
    mid = Common.finishDurationBucket(set.mid),
    late = Common.finishDurationBucket(set.late),
  }
end

function Common.mergeLifecycleAgg()
  return {
    pairs = 0, resolved = 0, unresolved = 0, unpairedMerges = 0,
    roundsToMerge = 0, tiersToMerge = 0,
    byUnit = {},
  }
end

local function lifecycleBucket(map, id)
  local b = map[id]
  if not b then
    b = {
      pairs = 0, resolved = 0, unresolved = 0, unpairedMerges = 0,
      roundsToMerge = 0, tiersToMerge = 0,
    }
    map[id] = b
  end
  return b
end

local function sameMergeTrack(pair, merge)
  return pair and merge and pair.id == merge.id and (pair.level or 1) == (merge.level or 1)
    and (merge.round or 0) >= (pair.round or 0)
end

function Common.addMergeLifecycle(agg, traj)
  local used = {}
  local merges = traj.mergeEvents or {}
  for _, pair in ipairs(traj.pairEvents or {}) do
    local best, bestGap
    for i, merge in ipairs(merges) do
      if not used[i] and sameMergeTrack(pair, merge) then
        local gap = (merge.round or 0) - (pair.round or 0)
        if not bestGap or gap < bestGap then
          best, bestGap = i, gap
        end
      end
    end

    local b = lifecycleBucket(agg.byUnit, pair.id or "?")
    agg.pairs = agg.pairs + 1
    b.pairs = b.pairs + 1
    if best then
      local merge = merges[best]
      used[best] = true
      local roundGap = math.max(0, (merge.round or 0) - (pair.round or 0))
      local tierGap = math.max(0, (merge.shopTier or 0) - (pair.shopTier or 0))
      agg.resolved = agg.resolved + 1
      agg.roundsToMerge = agg.roundsToMerge + roundGap
      agg.tiersToMerge = agg.tiersToMerge + tierGap
      b.resolved = b.resolved + 1
      b.roundsToMerge = b.roundsToMerge + roundGap
      b.tiersToMerge = b.tiersToMerge + tierGap
    else
      agg.unresolved = agg.unresolved + 1
      b.unresolved = b.unresolved + 1
    end
  end

  for i, merge in ipairs(merges) do
    if not used[i] then
      agg.unpairedMerges = agg.unpairedMerges + 1
      lifecycleBucket(agg.byUnit, merge.id or "?").unpairedMerges =
        lifecycleBucket(agg.byUnit, merge.id or "?").unpairedMerges + 1
    end
  end
end

function Common.finishMergeLifecycle(agg, opts)
  opts = opts or {}
  local minWatchPairs = opts.minWatchPairs or 3
  local byUnit, watch = {}, {}
  for id, b in pairs(agg.byUnit or {}) do
    local row = {
      pairs = b.pairs or 0,
      resolved = b.resolved or 0,
      unresolved = b.unresolved or 0,
      unpaired_merges = b.unpairedMerges or 0,
      resolve_rate = ((b.pairs or 0) > 0) and ((b.resolved or 0) / b.pairs) or 0,
      avg_rounds_to_merge = ((b.resolved or 0) > 0) and ((b.roundsToMerge or 0) / b.resolved) or 0,
      avg_tiers_to_merge = ((b.resolved or 0) > 0) and ((b.tiersToMerge or 0) / b.resolved) or 0,
    }
    byUnit[id] = row
    if row.pairs >= minWatchPairs then
      watch[#watch + 1] = {
        id = id,
        pairs = row.pairs,
        resolved = row.resolved,
        unresolved = row.unresolved,
        resolve_rate = row.resolve_rate,
        avg_rounds_to_merge = row.avg_rounds_to_merge,
      }
    end
  end
  table.sort(watch, function(a, b)
    if a.resolve_rate ~= b.resolve_rate then return a.resolve_rate < b.resolve_rate end
    if a.unresolved ~= b.unresolved then return a.unresolved > b.unresolved end
    if a.pairs ~= b.pairs then return a.pairs > b.pairs end
    return a.id < b.id
  end)
  local top = {}
  for i = 1, math.min(opts.watchLimit or 12, #watch) do top[i] = watch[i] end
  return {
    pairs = agg.pairs or 0,
    resolved = agg.resolved or 0,
    unresolved = agg.unresolved or 0,
    unpaired_merges = agg.unpairedMerges or 0,
    resolve_rate = ((agg.pairs or 0) > 0) and ((agg.resolved or 0) / agg.pairs) or 0,
    avg_rounds_to_merge = ((agg.resolved or 0) > 0) and ((agg.roundsToMerge or 0) / agg.resolved) or 0,
    avg_tiers_to_merge = ((agg.resolved or 0) > 0) and ((agg.tiersToMerge or 0) / agg.resolved) or 0,
    by_unit = byUnit,
    watch = top,
  }
end

-- ── ÉCRITURE d'un rapport de scénario. `name` = clé de mode ("invest"/"policy"/...). On écrit
-- runs/report-<name>.json (le rapport DÉTAILLÉ du mode) ET on MET À JOUR le bloc <name> dans le golden de
-- méta runs/report-ref.json (agrégat diff-able multi-modes). Le ref est lu/édité bloc par bloc (chaque mode
-- ne touche QUE sa clé) -> un patch ne brouille pas les autres scénarios. Clés triées -> diff lisible. ──
function Common.writeReport(name, payload, opts)
  opts = opts or {}
  local dir = OUT_DIR
  os.execute("mkdir -p " .. dir)
  local detail = Json.encode(payload)
  local path = dir .. "/report-" .. name .. ".json"
  local f = io.open(path, "w")
  if f then f:write(detail .. "\n"); f:close() end
  if opts.updateRef ~= false then Common.updateRef(name, opts.refSummary or payload) end
  return path
end

-- Charge le golden de méta (objet { mode -> résumé }) en mémoire via un décodeur MINIMAL (notre JSON est
-- produit par nous -> bien formé, clés triées). On ne dépend d'aucune lib : on relit le fichier comme TEXTE
-- et on remplace le bloc du mode par regénération complète depuis un cache disque. Pour rester SANS décodeur,
-- on stocke chaque résumé de mode dans son PROPRE fichier runs/ref-<mode>.json, et report-ref.json est leur
-- CONCATÉNATION ordonnée régénérée à chaque écriture. Simple, déterministe, diff-able.
local REF_MODES = { "meta", "invest", "policy", "godroll", "commander", "counter", "economy", "tank", "pacing", "sweep", "coherence" }
function Common.updateRef(name, summary)
  local dir = OUT_DIR
  os.execute("mkdir -p " .. dir)
  -- 1) persiste le résumé de CE mode
  local mf = io.open(dir .. "/ref-" .. name .. ".json", "w")
  if mf then mf:write(Json.encode(summary) .. "\n"); mf:close() end
  -- 2) régénère report-ref.json = { mode: <résumé> } pour tous les modes ayant un ref-<mode>.json
  local parts = {}
  for _, m in ipairs(REF_MODES) do
    local rf = io.open(dir .. "/ref-" .. m .. ".json", "r")
    if rf then
      local body = rf:read("*a"); rf:close()
      body = (body or ""):gsub("%s+$", "")
      if #body > 0 then parts[#parts + 1] = Json.encode(m) .. ":" .. body end
    end
  end
  local agg = "{" .. table.concat(parts, ",") .. "}\n"
  local af = io.open(dir .. "/report-ref.json", "w")
  if af then af:write(agg); af:close() end
end

return Common
