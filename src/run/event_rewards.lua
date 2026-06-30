-- src/run/event_rewards.lua
-- Application live des recompenses d'events de run.
--
-- RunState sait materialiser les rewards lisibles (relic/unit/gold/xp/tier),
-- mais les unites et mutations appartiennent aux occurrences du Build
-- (banc/plateau/fusions/snapshots). Ce module garde ce pont au meme endroit
-- pour eviter de dupliquer la logique dans main.lua et dans la scene.

local Units = require("src.data.units")
local Mutations = require("src.run.mutations")

local EventRewards = {}

local function unitLevel(reward)
  return math.max(1, math.min(2, (reward and reward.level) or 1))
end

local function unitArchetype(id)
  local u = Units[id]
  if not u then return "bruiser" end
  if u.taunt or (u.aggro and u.aggro >= 40) then return "tank" end
  for _, e in ipairs(u.effects or {}) do
    local op = e.op or ""
    if op == "poison" then return "poison" end
    if op == "burn" then return "burn" end
    if op == "bleed" then return "bleed" end
    if op == "rot" or op == "convert_to_rot" then return "rot" end
    if op == "shock" then return "shock" end
    if op == "regen" then return "tank" end
    if op:find("aura_", 1, true) then
      if op:find("burn", 1, true) then return "burn" end
      if op:find("poison", 1, true) then return "poison" end
      if op:find("bleed", 1, true) then return "bleed" end
      if op:find("rot", 1, true) then return "rot" end
    end
  end
  return "bruiser"
end

local function buildUnitContext(build)
  local ctx = { ids = {}, levels = {}, archetypes = {}, types = {}, families = {}, total = 0 }
  local function add(sr)
    if not sr or not sr.id then return end
    local u = Units[sr.id]
    local level = sr.level or 1
    ctx.total = ctx.total + 1
    ctx.ids[sr.id] = (ctx.ids[sr.id] or 0) + 1
    ctx.levels[sr.id .. "\0" .. tostring(level)] = (ctx.levels[sr.id .. "\0" .. tostring(level)] or 0) + 1
    local arch = unitArchetype(sr.id)
    ctx.archetypes[arch] = (ctx.archetypes[arch] or 0) + 1
    if u and u.type then ctx.types[u.type] = (ctx.types[u.type] or 0) + 1 end
    if u and u.family then ctx.families[u.family] = (ctx.families[u.family] or 0) + 1 end
  end
  if build then
    for i = 1, 9 do add(build.slotRigs and build.slotRigs[i]) end
    local cap = (build.benchCapacity and build:benchCapacity()) or #(build.bench or {})
    for i = 1, cap do add(build.bench and build.bench[i]) end
  end
  return ctx
end

local function contextualUnitPriority(build)
  local ctx = buildUnitContext(build)
  if (ctx.total or 0) <= 0 then return nil end
  return function(id, rewardSpec)
    local u = Units[id]
    if not u then return 0 end
    local level = unitLevel(rewardSpec)
    local sameLevel = ctx.levels[id .. "\0" .. tostring(level)] or 0
    local sameId = ctx.ids[id] or 0
    local score = 0
    if sameLevel >= 2 then score = score + 1200
    elseif sameLevel == 1 then score = score + 650
    elseif sameId > 0 then score = score + 280 end
    local arch = unitArchetype(id)
    local archCount = ctx.archetypes[arch] or 0
    if arch ~= "bruiser" then score = score + archCount * 120
    else score = score + archCount * 35 end
    if u.type then score = score + (ctx.types[u.type] or 0) * 22 end
    if u.family then score = score + (ctx.families[u.family] or 0) * 14 end
    score = score + (u.rank or 1) * 4
    return score
  end
end

function EventRewards.canGrantUnit(build, id, level)
  if not (build and Units[id]) then return false end
  level = math.max(1, math.min(2, level or 1))
  for i = 1, build:benchCapacity() do
    if not build.bench[i] then return true end
  end
  for i = 1, 9 do
    if build.board.slots[i].unlocked and not build.slotRigs[i] then return true end
  end
  -- Full-board merge-on-grant is intentionally deferred: presenting a reward
  -- that cannot be placed would break the "explicit outcome" event contract.
  return false
end

function EventRewards.bestMutationTarget(build, spec)
  if not build then return nil end
  spec = spec or {}
  local minRank = math.max(1, math.min(5, spec.rank or spec.rankMin or 1))
  local maxRank = math.max(minRank, math.min(5, spec.rank or spec.rankMax or 5))
  local best, bestScore
  local function consider(where, slot, sr)
    if not sr or (sr.mutations and #sr.mutations > 0) then return end
    local u = Units[sr.id]
    local rank = u and (u.rank or 1) or 1
    if rank < minRank or rank > maxRank then return end
    local level = sr.level or 1
    local score = ((where == "board") and 1000 or 0) + level * 120 + rank * 12 + (u and (u.dmg or 0) or 0)
    if not bestScore or score > bestScore or (score == bestScore and slot < best.slot) then
      bestScore = score
      best = { copyId = sr.copyId, where = where, slot = slot, id = sr.id, level = level }
    end
  end
  for i = 1, 9 do consider("board", i, build.slotRigs[i]) end
  for i = 1, build:benchCapacity() do consider("bench", i, build.bench[i]) end
  return best
end

function EventRewards.rollOptions(build, opts)
  opts = opts or {}
  local out = {}
  out.unitFilter = function(id, rewardSpec)
    if opts.unitFilter and not opts.unitFilter(id, rewardSpec) then return false end
    return EventRewards.canGrantUnit(build, id, unitLevel(rewardSpec))
  end
  local contextPriority = (opts.contextualUnits == false) and nil or contextualUnitPriority(build)
  if contextPriority or opts.unitPriority then
    out.unitPriority = function(id, rewardSpec)
      local score = contextPriority and contextPriority(id, rewardSpec) or 0
      if opts.unitPriority then score = score + (opts.unitPriority(id, rewardSpec) or 0) end
      return score
    end
  end
  if opts.mutations then
    out.mutationTarget = function(rewardSpec)
      return EventRewards.bestMutationTarget(build, rewardSpec)
    end
  end
  return out
end

function EventRewards.grantUnit(build, reward)
  if not (build and reward and Units[reward.id]) then return false, "bad_unit" end
  local occ = build:makeOcc(reward.id, unitLevel(reward), { mutations = reward.mutations })
  if not build:stowUnit(occ) then return false, "no_space" end
  build:checkMerges()
  return true
end

function EventRewards.grantMutation(build, reward)
  if not (build and reward and Mutations.byId[reward.id or reward.mutation]) then return false, "bad_mutation" end
  local mutationId = reward.id or reward.mutation
  local target = reward.target or {}
  local sr
  if target.where == "board" and target.slot then sr = build.slotRigs[target.slot]
  elseif target.where == "bench" and target.slot then sr = build.bench[target.slot] end
  if not sr or (target.copyId and sr.copyId ~= target.copyId) or (sr.mutations and #sr.mutations > 0) then
    return false, "bad_mutation_target"
  end
  sr.mutations = Mutations.clone({ mutationId })
  return true
end

function EventRewards.apply(run, build, reward, opts)
  reward = reward or {}
  if reward.kind == "unit" then return EventRewards.grantUnit(build, reward) end
  if reward.kind == "mutation" then return EventRewards.grantMutation(build, reward) end
  if reward.kind == "gold" and opts and opts.deferGold and run then
    run._pendingGold = (run._pendingGold or 0) + math.max(0, reward.amount or 0)
    return true
  end
  if run and run.applyRunEventReward then return run:applyRunEventReward(reward) end
  return false, "bad_run"
end

return EventRewards
