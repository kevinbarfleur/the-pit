-- tools/scenarios/common.lua
-- SOCLE PARTAGÉ du MOTEUR DE SCÉNARIOS d'équilibrage (Phase C.0). Tous les modes (invest/policy/godroll/
-- commander/counter) en dépendent. PUR-par-dépendance : aucun love.graphics ; le seul hasard est un RNG
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

-- ── RÉPERTOIRE DE SORTIE des rapports. Défaut "runs" (le golden de méta de référence). Override par
-- PIT_SCEN_OUT (ex. le SMOKE de tests/scenarios.lua redirige vers un dossier JETABLE pour NE PAS écraser le
-- runs/report-ref.json de référence avec des données à N=1). Tous les chemins passent par Common.outDir(). ──
local OUT_DIR = os.getenv("PIT_SCEN_OUT")
if not OUT_DIR or OUT_DIR == "" then OUT_DIR = "runs" end
function Common.outDir() return OUT_DIR end

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
local REF_MODES = { "meta", "invest", "policy", "godroll", "commander", "counter" }
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
