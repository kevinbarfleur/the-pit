-- tools/sim.lua
-- BATCH SIM d'équilibrage : joue N matchups (deux builds aléatoires symétriques, auras des deux
-- côtés) et agrège des statistiques exploitables :
--   · win-rate par unité (créditée si elle est dans la compo gagnante — méthode Ludus)
--   · dégâts infligés par unité (source) et par cause (attack/poison/thorns)
--   · TTK moyen (ticks jusqu'à conclusion)
--   · SANTÉ MÉTA : écart-type et entropie normalisée du vecteur de win-rate (haut = équilibré)
-- Écrit runs/report.json (diff-able). Déterministe : même N -> même rapport.
--
--   Lancement : luajit tools/sim.lua [N]      (N defaut 400)
package.path = "./?.lua;" .. package.path
love = require("tests.mock_love")

local Palette = require("src.core.palette")
local Units = require("src.data.units")
local Shapes = require("src.board.shapes")
local Arena = require("src.combat.arena")
local Build = require("src.scenes.build")
local EventLog = require("tools.eventlog")

local N = tonumber(arg and arg[1]) or 400
local BASE_SEED = 700000
local TICK_CAP = 8000
local gen = love.math.newRandomGenerator(13579) -- generateur de scenarios seede -> rapport reproductible

-- ── Build aléatoire valide (forme, slots débloqués, unités posées) ──
local function randomBuild()
  local b = Build.new(Palette, 320, 180, { goto = function() end })
  b.board:setShape(Shapes.order[gen:random(1, #Shapes.order)]); b:computeLayout()
  b.board:unlock(gen:random(3, 9))
  for _ = 1, gen:random(2, 9) do
    local slot = gen:random(1, 9)
    if b.board.slots[slot] and b.board.slots[slot].unlocked then
      b:placeId(slot, Units.order[gen:random(1, #Units.order)])
    end
  end
  return b
end

local function buildSide(side)
  local b = randomBuild()
  local comp = b:buildComp(side)
  if #comp == 0 then -- garantit au moins une unité
    b:placeId(5, Units.order[gen:random(1, #Units.order)])
    comp = b:buildComp(side)
  end
  return comp
end

-- ── Agrégats ──
local stat = {} -- [id] = { appear, wins, dmg }
local function S(id) local s = stat[id]; if not s then s = { appear = 0, wins = 0, dmg = 0 }; stat[id] = s end; return s end
local causeDmg = {}
local ttkSum, decided = 0, 0

for run = 1, N do
  local left = buildSide(-1)
  local right = buildSide(1)
  local arena = Arena.new({ left = left, right = right, autoReset = false, seed = BASE_SEED + run })
  local log = EventLog.attach(arena)
  local ticks = 0
  for i = 1, TICK_CAP do arena:update(1.0, i * 1.0); ticks = i; if arena.over then break end end

  local leftIds, rightIds = {}, {}
  for _, u in ipairs(left) do leftIds[#leftIds + 1] = u.id; S(u.id).appear = S(u.id).appear + 1 end
  for _, u in ipairs(right) do rightIds[#rightIds + 1] = u.id; S(u.id).appear = S(u.id).appear + 1 end

  if arena.over then
    decided = decided + 1
    ttkSum = ttkSum + ticks
    local winners = arena.win and leftIds or rightIds
    for _, id in ipairs(winners) do S(id).wins = S(id).wins + 1 end
  end

  for _, r in ipairs(log.records) do
    if r.ev == "damage" and r.hp and r.hp > 0 then
      if r.src then S(r.src).dmg = S(r.src).dmg + r.hp end
      causeDmg[r.cause or "?"] = (causeDmg[r.cause or "?"] or 0) + r.hp
    end
  end
end

-- ── Santé méta : écart-type + entropie normalisée du vecteur de win-rate ──
local winrates, totalDmg = {}, 0
for _, id in ipairs(Units.order) do
  local s = stat[id]
  if s and s.appear > 0 then winrates[#winrates + 1] = s.wins / s.appear end
  if s then totalDmg = totalDmg + s.dmg end
end
local mean = 0
for _, w in ipairs(winrates) do mean = mean + w end
mean = (#winrates > 0) and (mean / #winrates) or 0
local var = 0
for _, w in ipairs(winrates) do var = var + (w - mean) ^ 2 end
local stddev = (#winrates > 0) and math.sqrt(var / #winrates) or 0
-- entropie normalisée de la distribution des win-rates (1 = parfaitement uniforme = sain)
local sumw = 0
for _, w in ipairs(winrates) do sumw = sumw + w end
local entropy = 0
if sumw > 0 and #winrates > 1 then
  for _, w in ipairs(winrates) do
    local p = w / sumw
    if p > 0 then entropy = entropy - p * math.log(p) end
  end
  entropy = entropy / math.log(#winrates)
end
local avgTTK = (decided > 0) and (ttkSum / decided) or 0

-- ── Rapport console (trié par win-rate décroissant) ──
local rows = {}
for _, id in ipairs(Units.order) do
  local s = stat[id] or { appear = 0, wins = 0, dmg = 0 }
  rows[#rows + 1] = { id = id, appear = s.appear, wins = s.wins,
    wr = (s.appear > 0) and (s.wins / s.appear) or 0,
    dmg = s.dmg, share = (totalDmg > 0) and (s.dmg / totalDmg) or 0 }
end
table.sort(rows, function(a, b) if a.wr ~= b.wr then return a.wr > b.wr end return a.id < b.id end)

print(string.format("== BATCH SIM : %d combats (%d decides), TTK moyen %.0f ticks ==", N, decided, avgTTK))
print(string.format("%-10s %7s %7s %9s %9s", "unite", "appar.", "win%", "degats", "part%"))
for _, r in ipairs(rows) do
  print(string.format("%-10s %7d %6.1f%% %9d %8.1f%%", r.id, r.appear, r.wr * 100, r.dmg, r.share * 100))
end
print(string.format("degats par cause :"))
local causeKeys = {}
for k in pairs(causeDmg) do causeKeys[#causeKeys + 1] = k end
table.sort(causeKeys)
for _, k in ipairs(causeKeys) do
  print(string.format("  %-8s %9d (%.1f%%)", k, causeDmg[k], totalDmg > 0 and causeDmg[k] / totalDmg * 100 or 0))
end
print(string.format("sante meta : ecart-type win-rate = %.3f (bas = equilibre) | entropie = %.3f (haut = sain)",
  stddev, entropy))

-- ── report.json (clés triées -> diff-able) ──
local function num(v) if v == math.floor(v) then return string.format("%d", v) else return string.format("%.4f", v) end end
local parts = {}
parts[#parts + 1] = string.format('"n":%d,"decided":%d,"avg_ttk":%s', N, decided, num(avgTTK))
parts[#parts + 1] = string.format('"meta_stddev":%s,"meta_entropy":%s', num(stddev), num(entropy))
local unitParts = {}
for _, r in ipairs(rows) do
  unitParts[#unitParts + 1] = string.format(
    '"%s":{"appear":%d,"wins":%d,"winrate":%s,"dmg":%d,"dmg_share":%s}',
    r.id, r.appear, r.wins, num(r.wr), r.dmg, num(r.share))
end
table.sort(unitParts)
parts[#parts + 1] = '"units":{' .. table.concat(unitParts, ",") .. "}"
local causeParts = {}
for _, k in ipairs(causeKeys) do causeParts[#causeParts + 1] = string.format('"%s":%d', k, causeDmg[k]) end
parts[#parts + 1] = '"cause_dmg":{' .. table.concat(causeParts, ",") .. "}"
local json = "{" .. table.concat(parts, ",") .. "}\n"

os.execute("mkdir -p runs")
local f = io.open("runs/report.json", "w")
if f then f:write(json); f:close(); print("=> ecrit runs/report.json") else print("(!) impossible d'ecrire runs/report.json") end
