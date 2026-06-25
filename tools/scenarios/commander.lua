-- tools/scenarios/commander.lua
-- SCÉNARIOS COMMANDANT (valide command-auras Pass 3 — balance-psychology §2.7-3, the-pit-command-auras-campaign).
-- Mesure l'IMPACT À L'ÉCHELLE d'une aura de COMMANDEMENT : on pose un commandant au PIÉDESTAL (cf. build.lua
-- pedestal + Units.commandBonus, voie FIDÈLE via Compbuild) et on mesure le DELTA DE WIN-RATE qu'il apporte
-- (commandant présent vs ABSENT), à compo + champ FIXES. On agrège par CATÉGORIE D'AURA pour voir lesquelles
-- font snowball. On surveille surtout :
--   · dmgReduce (~18% du pool -> RISQUE DE CONVERGENCE all-tank : tout le monde prend le même écu) ;
--   · haste (cadence -> sert TOUT, anti-terminaison borné HASTE_CAP) ;
--   · multicast × afflicteur × ampli-école (le SNOWBALL : le combo god-roll porté par un commandant).
-- Le delta isole l'effet du commandant (le « 1 levier à la fois » : seul le piédestal change). SIM-pur, seedé.
--   luajit tools/sim.lua commander [N]      (N défaut 40 matchs/cellule)

local Common = require("tools.scenarios.common")
local Units = require("src.data.units")
local Compbuild = require("src.lab.compbuild")

local N = require("tools.scenarios.argn")(40)
local BASE_SEED = 640000
local HPM = tonumber(os.getenv("PIT_HP_MULT"))

-- ── CATÉGORIE d'aura d'un commandant (depuis commandBonus). Sert à agréger l'impact par famille d'aura. ──
local function commanderCategory(id)
  local cb = Units[id] and Units[id].commandBonus
  if not cb then return nil end
  local p = cb.params or {}
  if cb.op == "grant_team" then
    local keys = {}; for k in pairs(p) do keys[#keys + 1] = k end; table.sort(keys)
    return "grant_team:" .. table.concat(keys, ",")
  end
  local s = p.stat
  if s == "atkInc" then return "empower" end
  if s and s:find("Inc") and s ~= "statInc" then return "school_amp" end
  return s or "?"
end

-- ── REPRÉSENTANTS de commandant par catégorie d'aura à tester (1 fort par catégorie -> couvre tout le SPECTRE
-- d'auras sans exploser le temps). On CIBLE en priorité les catégories à risque (dmgReduce / haste / multicast /
-- empower / amplis d'école / les grant_team transformatifs). Les ids sont validés (présents dans Units). ──
local COMMANDERS = {
  "templar",        -- dmgReduce team (LE risque de convergence ~18% du pool)
  "skeleton",       -- dmgReduce team (rang 1, le défaut sûr)
  "marauder",       -- empower role:front
  "maggot_king",    -- multicast role:front (Couronne d'Échos -> snowball)
  "hookjaw",        -- multicast role:front (rang 2)
  "bandit",         -- haste team (tempo)
  "witch",          -- school_amp poison
  "razorkin",       -- school_amp bleed
  "emberling",      -- school_amp burn
  "rot_hound",      -- school_amp rot
  "plague_doctor",  -- regen team (anti-DoT)
  "demon",          -- lifesteal team
  "corruptor",      -- grant_team markEnemiesVuln (vuln d'équipe)
  "festering",      -- grant_team plagueAmp (transform poison late)
  "pit_maw",        -- grant_team rotEnemies (transform rot late)
  "stormlord",      -- grant_team shockChain (le choc rebondit)
}

-- ── BASES représentatives (board mid/end) sur lesquelles poser le commandant. On choisit des compos dont
-- l'archétype EXPLOITE potentiellement l'aura (un afflicteur pour les amplis ; un frappeur front pour multicast/
-- empower ; un mur pour dmgReduce/regen). Plusieurs bases -> on voit où l'aura snowball le plus. ──
local BASES = { "end_shock_multicast", "end_poison", "end_rot", "mid_poison", "mid_tank", "bruiser_carre" }

-- Champ d'adversaires FIXE (la référence ne bouge pas -> le delta isole le commandant).
local FOE_IDS = { "tank_carre", "bruiser_carre", "cross_venom_pyre", "fortress_thorns_carre", "end_poison" }
local FOES = {}
for _, id in ipairs(FOE_IDS) do FOES[#FOES + 1] = Common.compById(id) end
local rightCache = {}
local function rightOf(c) local v = rightCache[c.id]; if not v then v = Compbuild.toComp(c, 1); rightCache[c.id] = v end; return v end

-- win-rate d'une compo (résolue, avec ou sans commandant) vs le champ fixe, sur N matchs/adversaire (seeds dérivés).
local function winrateVsField(L, seedBase)
  local wins, total, s = 0, 0, seedBase
  for _, fc in ipairs(FOES) do
    if fc.id then
      local R = rightOf(fc)
      for _ = 1, N do
        s = s + 1
        local res = Common.fight(L, R, s, HPM)
        total = total + 1; if res.win then wins = wins + 1 end
      end
    end
  end
  return (total > 0) and (wins / total) or 0
end

print(string.format("== SCENARIOS COMMANDANT : %d bases x %d commandants x %d adversaires x %d matchs ==",
  #BASES, #COMMANDERS, #FOES, N))

-- delta par (base, commandant) + agrégat par catégorie d'aura.
local rows = {}
local catSum, catN = {}, {} -- [cat] = somme des deltas / nb
local seedCursor = 0
for _, baseId in ipairs(BASES) do
  local baseComp = Common.compById(baseId)
  -- référence SANS commandant (résolue une fois par base)
  seedCursor = seedCursor + 100000
  local Lbase = Compbuild.toComp(baseComp, -1)
  local wrBase = winrateVsField(Lbase, BASE_SEED + seedCursor)
  for _, cmd in ipairs(COMMANDERS) do
    local cat = commanderCategory(cmd) or "?"
    seedCursor = seedCursor + 10000
    local Lcmd = Compbuild.toComp(baseComp, -1, { commander = cmd })
    local wrCmd = winrateVsField(Lcmd, BASE_SEED + seedCursor)
    local delta = wrCmd - wrBase
    rows[#rows + 1] = { base = baseId, cmd = cmd, cat = cat, wr_base = wrBase, wr_cmd = wrCmd, delta = delta }
    catSum[cat] = (catSum[cat] or 0) + delta
    catN[cat] = (catN[cat] or 0) + 1
  end
end

-- ── Top deltas (les commandants qui changent le plus l'issue = candidats snowball) ──
table.sort(rows, function(a, b) if a.delta ~= b.delta then return a.delta > b.delta end
  if a.base ~= b.base then return a.base < b.base end return a.cmd < b.cmd end)
print(string.format("%-22s %-14s %-14s %7s %7s %7s", "base", "commandant", "categorie", "wr0%", "wr+%", "delta"))
local shown = 0
for _, r in ipairs(rows) do
  if shown < 18 then
    print(string.format("%-22s %-14s %-14s %6.1f%% %6.1f%% %+6.1f%%",
      r.base, r.cmd, r.cat, r.wr_base * 100, r.wr_cmd * 100, r.delta * 100))
    shown = shown + 1
  end
end

-- ── Agrégat par CATÉGORIE D'AURA (delta moyen) : quelle famille d'aura pèse le plus ? (surveillance convergence) ──
local catRows = {}
for cat, sum in pairs(catSum) do catRows[#catRows + 1] = { cat = cat, avg = sum / catN[cat], n = catN[cat] } end
table.sort(catRows, function(a, b) if a.avg ~= b.avg then return a.avg > b.avg end return a.cat < b.cat end)
print("delta moyen par CATEGORIE d'aura (impact a l'echelle) :")
for _, c in ipairs(catRows) do
  local warn = ""
  if c.cat == "dmgReduce" then warn = "  <- ~18% du pool : RISQUE DE CONVERGENCE all-tank" end
  if c.cat == "multicast" then warn = "  <- SNOWBALL (multicast x afflicteur x ampli)" end
  if c.cat == "haste" then warn = "  <- sert tout (cadence, borne HASTE_CAP)" end
  print(string.format("  %-22s delta moyen %+6.1f%% (n=%d)%s", c.cat, c.avg * 100, c.n, warn))
end

-- ── Rapport diff-able : delta par (base|cmd) + agrégat par catégorie. ──
local detail = {}
for _, r in ipairs(rows) do
  detail[r.base .. "|" .. r.cmd] = { category = r.cat, wr_base = r.wr_base, wr_cmd = r.wr_cmd, delta = r.delta }
end
local catOut = {}
for _, c in ipairs(catRows) do catOut[c.cat] = { avg_delta = c.avg, n = c.n } end
local payload = { mode = "commander", matchs_per_cell = N, bases = #BASES, commanders = #COMMANDERS,
  foes = #FOES, by_pair = detail, by_category = catOut }
-- résumé de méta : delta moyen par catégorie (compact, diff stable).
local refCat = {}
for _, c in ipairs(catRows) do refCat[c.cat] = c.avg end
local summary = { matchs_per_cell = N, bases = #BASES, commanders = #COMMANDERS, category_avg_delta = refCat }
local path = Common.writeReport("commander", payload, { refSummary = summary })
print("=> ecrit " .. path .. " (+ runs/report-ref.json)")
