-- tools/scenarios/coherence.lua
-- MODE P10 -- COHERENCE BANDS.
--
-- Connects the semantic intent layer to actual combat outcomes. The report
-- bins fixed and generated teams by coherence score, then measures win-rate,
-- TTK, and cost against representative band fields. This answers:
--   high coherence but weak? low coherence but strong? expensive but flat?

local Common = require("tools.scenarios.common")
local Coherence = require("src.lab.coherence")
local Compositions = require("src.data.compositions")
local Bands = require("src.lab.bands")
local Compbuild = require("src.lab.compbuild")
local Policies = require("src.lab.policies")
local Units = require("src.data.units")

local N = require("tools.scenarios.argn")(24) -- generated candidates per stage
local MATCHES = Common.envNumber("PIT_COHERENCE_MATCHES", 4)
local RELIC_VARIANTS = Common.envNumber("PIT_COHERENCE_RELIC_VARIANTS", 1) ~= 0
local BASE_SEED = 1560000
local HPM = Common.envNumber("PIT_HP_MULT", nil)

local STAGES = { "early", "mid", "end_" }
local STAGE_LABEL = { early = "early", mid = "mid", end_ = "end" }
local ARCHETYPES = { "poison", "burn", "bleed", "rot", "shock", "tank", "bruiser" }
local RELIC_BY_ARCHETYPE = {
  poison = "kings_bowl",
  burn = "ember_heart",
  bleed = "weeping_nail",
  rot = "grave_cap",
  shock = "forked_tongue",
  tank = "tide_caller",
  bruiser = "blood_banner",
}
local STAGE_LEVEL = {
  early = { board = 4, maxRank = 2, size = 4, l2 = 0, l3 = 0 },
  mid = { board = 6, maxRank = 4, size = 6, l2 = 20, l3 = 0 },
  end_ = { board = 9, maxRank = 5, size = 9, l2 = 35, l3 = 8 },
}

local function cloneUnits(units)
  local out = {}
  for _, u in ipairs(units or {}) do
    out[#out + 1] = { id = u.id, slot = u.slot, level = u.level or 1 }
  end
  return out
end

local function stageOf(comp)
  if comp.band and STAGE_LEVEL[comp.band] then return comp.band end
  local n = comp.boardLevel or 9
  if n <= 4 then return "early" end
  if n <= 6 then return "mid" end
  return "end_"
end

local function stableCompId(prefix, index, stage, archetype)
  return string.format("%s_%s_%s_%03d", prefix, STAGE_LABEL[stage], archetype or "mixed", index)
end

local function unitPool(stage, archetype)
  local cfg = STAGE_LEVEL[stage]
  local out = {}
  for _, id in ipairs(Units.order) do
    local u = Units[id]
    local rank = u and (u.rank or u.cost or 1) or 1
    if rank <= cfg.maxRank and (not archetype or Policies.archetypeOf(id) == archetype) then
      out[#out + 1] = id
    end
  end
  if #out == 0 and archetype then return unitPool(stage, nil) end
  return out
end

local function randomLevel(rng, stage)
  local cfg = STAGE_LEVEL[stage]
  local roll = rng:random(1, 100)
  if roll <= cfg.l3 then return 3 end
  if roll <= cfg.l3 + cfg.l2 then return 2 end
  return 1
end

local function randomComp(rng, index, stage, archetype)
  local cfg = STAGE_LEVEL[stage]
  local pool = unitPool(stage, archetype)
  local units, seen = {}, {}
  for slot = 1, cfg.size do
    local id
    for _ = 1, 20 do
      id = pool[rng:random(1, #pool)]
      if not seen[id] or rng:random(1, 100) <= 12 then break end
    end
    seen[id] = true
    units[#units + 1] = { id = id, slot = slot, level = randomLevel(rng, stage) }
  end
  return {
    id = stableCompId(archetype and "gen_focused" or "gen_mixed", index, stage, archetype),
    source = archetype and "generated_focused" or "generated_mixed",
    archetype = archetype or "mixed",
    band = stage,
    variant = "generated",
    sigil = "carre",
    boardLevel = cfg.board,
    units = units,
  }
end

local function addCandidate(out, seen, comp, source)
  if not comp or seen[comp.id] then return end
  local c = {
    id = comp.id,
    source = source or comp.source or "fixed",
    archetype = comp.archetype or Common.archetypeOf(comp),
    band = stageOf(comp),
    variant = comp.variant,
    sigil = comp.sigil,
    boardLevel = comp.boardLevel,
    commander = comp.commander,
    relics = Common.clone(comp.relics or {}),
    units = cloneUnits(comp.units),
  }
  seen[c.id] = true
  out[#out + 1] = c
end

local function fixedCandidates()
  local out, seen = {}, {}
  for _, stage in ipairs(STAGES) do
    for _, c in ipairs(Bands.list[stage] or {}) do addCandidate(out, seen, c, "band") end
  end
  for _, c in ipairs(Compositions.list or {}) do
    if c.variant == "perfect" or c.variant == "baseline" or c.variant == "wall" or c.variant == "amp" then
      addCandidate(out, seen, c, "catalog")
    end
  end
  return out, seen
end

local function addRelicVariants(out, seen)
  local base = Common.clone(out)
  for _, c in ipairs(base) do
    local relic = RELIC_BY_ARCHETYPE[c.archetype]
    if relic then
      local v = Common.clone(c)
      v.id = c.id .. "__" .. relic
      v.source = (c.source or "fixed") .. "_relic"
      v.relics = Common.clone(c.relics or {})
      v.relics[#v.relics + 1] = relic
      addCandidate(out, seen, v, v.source)
    end
  end
end

local function generatedCandidates(out, seen)
  local rng = love.math.newRandomGenerator(91573)
  for _, stage in ipairs(STAGES) do
    for i = 1, N do
      local focused = (i % 2) == 0
      local archetype = focused and ARCHETYPES[((i / 2 - 1) % #ARCHETYPES) + 1] or nil
      addCandidate(out, seen, randomComp(rng, i, stage, archetype), "generated")
    end
  end
end

local candidates, seen = fixedCandidates()
if RELIC_VARIANTS then addRelicVariants(candidates, seen) end
generatedCandidates(candidates, seen)

local rightCache, leftCache = {}, {}
local function leftOf(c)
  local v = leftCache[c.id]
  if not v then v = Compbuild.toComp(c, -1); leftCache[c.id] = v end
  return v
end
local function rightOf(c)
  local v = rightCache[c.id]
  if not v then v = Compbuild.toComp(c, 1); rightCache[c.id] = v end
  return v
end

local function bucketFor(coherence)
  if coherence < 0.25 then return "00_25" end
  if coherence < 0.50 then return "25_50" end
  if coherence < 0.75 then return "50_75" end
  return "75_100"
end

local function newBucket()
  return { candidates = 0, wins = 0, fights = 0, coherence = 0, cost = 0, ticks = 0, tickN = 0 }
end

local function addBucket(b, row)
  b.candidates = b.candidates + 1
  b.wins = b.wins + row.wins
  b.fights = b.fights + row.fights
  b.coherence = b.coherence + row.coherence
  b.cost = b.cost + row.cost_score
  b.ticks = b.ticks + row.ticks
  b.tickN = b.tickN + row.tickN
end

local function finishBucket(b)
  return {
    candidates = b.candidates,
    fights = b.fights,
    avg_coherence = (b.candidates > 0) and (b.coherence / b.candidates) or 0,
    avg_cost_score = (b.candidates > 0) and (b.cost / b.candidates) or 0,
    winrate = (b.fights > 0) and (b.wins / b.fights) or 0,
    avg_seconds = (b.tickN > 0) and (b.ticks / b.tickN / Common.FPS) or 0,
  }
end

local function pearson(rows)
  if #rows < 2 then return 0 end
  local sx, sy = 0, 0
  for _, r in ipairs(rows) do sx = sx + r.coherence; sy = sy + r.winrate end
  local mx, my = sx / #rows, sy / #rows
  local num, dx, dy = 0, 0, 0
  for _, r in ipairs(rows) do
    local x, y = r.coherence - mx, r.winrate - my
    num = num + x * y
    dx = dx + x * x
    dy = dy + y * y
  end
  if dx <= 0 or dy <= 0 then return 0 end
  return num / math.sqrt(dx * dy)
end

local function take(rows, n)
  local out = {}
  for i = 1, math.min(n, #rows) do out[i] = rows[i] end
  return out
end

local function compactRow(r)
  return {
    id = r.id,
    source = r.source,
    stage = STAGE_LABEL[r.stage],
    archetype = r.archetype,
    coherence = r.coherence,
    winrate = r.winrate,
    cost_score = r.cost_score,
    gold = r.gold,
    avg_seconds = r.avg_seconds,
    subscores = r.subscores,
    units = r.units,
    relics = r.relics,
  }
end

print(string.format("== P10 COHERENCE BANDS : %d candidats (%d generated/stage) x champs de bande x %d matchs ==",
  #candidates, N, MATCHES))

local rows, byBucket, byStage = {}, {}, {}
local seedCounter = 0
for _, key in ipairs({ "00_25", "25_50", "50_75", "75_100" }) do byBucket[key] = newBucket() end
for _, stage in ipairs(STAGES) do byStage[stage] = newBucket() end

for _, comp in ipairs(candidates) do
  local stage = comp.band
  local foes = Bands.field[stage] or {}
  local score = Coherence.scoreTeam(comp.units, { commander = comp.commander, relics = comp.relics })
  local inv = Common.invest(comp)
  local L = leftOf(comp)
  local wins, fights, ticks, tickN = 0, 0, 0, 0
  for _, foeId in ipairs(foes) do
    local foe = Common.compByIdOrNil(foeId)
    if foe and foe.id ~= comp.id then
      local R = rightOf(foe)
      for _ = 1, MATCHES do
        seedCounter = seedCounter + 1
        local res = Common.fight(L, R, BASE_SEED + seedCounter, HPM)
        fights = fights + 1
        if res.win then wins = wins + 1 end
        if res.ticks then ticks = ticks + res.ticks; tickN = tickN + 1 end
      end
    end
  end
  local row = {
    id = comp.id, source = comp.source, stage = stage, archetype = comp.archetype,
    coherence = score.coherence, subscores = score.subscores,
    cost_score = inv.score or 0, gold = inv.gold or 0,
    wins = wins, fights = fights, winrate = (fights > 0) and (wins / fights) or 0,
    ticks = ticks, tickN = tickN, avg_seconds = (tickN > 0) and (ticks / tickN / Common.FPS) or 0,
    units = cloneUnits(comp.units),
    relics = Common.clone(comp.relics or {}),
  }
  rows[#rows + 1] = row
  addBucket(byBucket[bucketFor(row.coherence)], row)
  addBucket(byStage[stage], row)
end

local highCoherenceWeak, lowCoherenceStrong, cheapStrong, expensiveWeak = {}, {}, {}, {}
for _, r in ipairs(rows) do
  if r.coherence >= 0.65 and r.winrate <= 0.35 then highCoherenceWeak[#highCoherenceWeak + 1] = compactRow(r) end
  if r.coherence <= 0.35 and r.winrate >= 0.55 then lowCoherenceStrong[#lowCoherenceStrong + 1] = compactRow(r) end
  if r.cost_score <= 0.45 and r.winrate >= 0.60 then cheapStrong[#cheapStrong + 1] = compactRow(r) end
  if r.cost_score >= 0.70 and r.winrate <= 0.35 then expensiveWeak[#expensiveWeak + 1] = compactRow(r) end
end
table.sort(highCoherenceWeak, function(a, b)
  if a.winrate ~= b.winrate then return a.winrate < b.winrate end
  return a.coherence > b.coherence
end)
table.sort(lowCoherenceStrong, function(a, b)
  if a.winrate ~= b.winrate then return a.winrate > b.winrate end
  return a.coherence < b.coherence
end)
table.sort(cheapStrong, function(a, b)
  if a.winrate ~= b.winrate then return a.winrate > b.winrate end
  return a.cost_score < b.cost_score
end)
table.sort(expensiveWeak, function(a, b)
  if a.winrate ~= b.winrate then return a.winrate < b.winrate end
  return a.cost_score > b.cost_score
end)

local bucketOut, stageOut = {}, {}
for key, b in pairs(byBucket) do bucketOut[key] = finishBucket(b) end
for stage, b in pairs(byStage) do stageOut[STAGE_LABEL[stage]] = finishBucket(b) end

table.sort(rows, function(a, b)
  if a.winrate ~= b.winrate then return a.winrate > b.winrate end
  return a.id < b.id
end)

print(string.format("%-8s %6s %8s %8s %8s %8s", "bucket", "teams", "coh", "win%", "cost", "secs"))
for _, key in ipairs({ "00_25", "25_50", "50_75", "75_100" }) do
  local b = bucketOut[key]
  print(string.format("%-8s %6d %8.3f %7.1f%% %8.3f %8.2f",
    key, b.candidates, b.avg_coherence, b.winrate * 100, b.avg_cost_score, b.avg_seconds))
end

local corr = pearson(rows)
print(string.format("coherence/winrate correlation: %.3f | low-coh strong=%d | high-coh weak=%d",
  corr, #lowCoherenceStrong, #highCoherenceWeak))

local rowOut = {}
for _, r in ipairs(rows) do rowOut[#rowOut + 1] = compactRow(r) end

local payload = {
  mode = "coherence",
  generated_per_stage = N,
  matches_per_foe = MATCHES,
  candidates = #rows,
  fights = seedCounter,
  config = {
    hp_mult = HPM,
    matches = Common.env("PIT_COHERENCE_MATCHES"),
    relic_variants = RELIC_VARIANTS,
  },
  correlation = corr,
  buckets = bucketOut,
  by_stage = stageOut,
  outliers = {
    high_coherence_weak = take(highCoherenceWeak, 16),
    low_coherence_strong = take(lowCoherenceStrong, 16),
    cheap_strong = take(cheapStrong, 16),
    expensive_weak = take(expensiveWeak, 16),
  },
  rows = rowOut,
}

local summary = {
  generated_per_stage = N,
  matches_per_foe = MATCHES,
  candidates = #rows,
  fights = seedCounter,
  correlation = corr,
  buckets = bucketOut,
  outlier_counts = {
    high_coherence_weak = #highCoherenceWeak,
    low_coherence_strong = #lowCoherenceStrong,
    cheap_strong = #cheapStrong,
    expensive_weak = #expensiveWeak,
  },
  top_low_coherence_strong = take(lowCoherenceStrong, 8),
  top_high_coherence_weak = take(highCoherenceWeak, 8),
}

local path = Common.writeReport("coherence", payload, { refSummary = summary })
print("=> ecrit " .. path .. " (+ runs/report-ref.json)")
