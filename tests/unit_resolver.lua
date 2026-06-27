-- tests/unit_resolver.lua
-- Level-aware unit resolver: shared stat multiplier, authored ability deltas,
-- and build/snapshot propagation for level 2/3 mechanics.
package.path = "./?.lua;" .. package.path
love = require("tests.mock_love")

local Palette = require("src.core.palette")
local Build = require("src.scenes.build")
local Snapshot = require("src.net.snapshot")
local Resolver = require("src.core.unit_resolver")

local function fresh()
  local b = Build.new(Palette, 320, 180, { goto = function() end })
  b.board:setShape("carre")
  b:computeLayout()
  b.board:unlock(9)
  return b
end

local function compById(comp, id)
  for _, s in ipairs(comp) do if s.id == id then return s end end
end

local function effectByOp(spec, op)
  for _, e in ipairs(spec.effects or {}) do if e.op == op then return e end end
end

local function commandEffect(spec)
  for _, e in ipairs(spec.effects or {}) do
    if e.op == "grant_team" then return e end
  end
end

local ok, err = pcall(function()
  -- Shared stat multiplier remains the duplicate-level contract.
  local stats = Resolver.statsFor("spore_tick", 2)
  assert(stats.hp == 54 and stats.dmg == 5, "resolver stats: spore_tick level 2 uses shared 1.8 multiplier")

  -- Level 1 is identity for authored units.
  local l1 = Resolver.effectsFor("spore_tick", 1)[1]
  assert(l1.op == "poison" and l1.params.dps == 1 and not l1.levelAuthored,
    "resolver effects: level 1 remains base data")

  -- Authored low-rank reroll progression.
  local spore3 = Resolver.effectsFor("spore_tick", 3)[1]
  assert(spore3.params.dps == 2 and spore3.params.dur == 210 and spore3.params.spread,
    "spore_tick level 3 gains poison spread clutch rider")

  local rat3 = Resolver.effectsFor("gnaw_rat", 3)[1]
  assert(rat3.params.dps == 2 and rat3.params.aggravateMult == 1.5,
    "gnaw_rat level 3 gains bleed aggravate clutch rider")

  local husk3 = Resolver.effectsFor("husk", 3)[1]
  assert(husk3.op == "aura_stat" and husk3.target == "team" and husk3.params.value == 0.08,
    "husk level 3 turns front guard into team wall clutch")

  -- Build comp must materialize authored level effects; otherwise Arena would
  -- fall back to raw Units[id].effects and silently play level 1.
  do
    local b = fresh()
    b:placeId(5, "spore_tick", 3)
    local sp = compById(b:buildComp(-1), "spore_tick")
    local poison = effectByOp(sp, "poison")
    assert(poison and poison.params.spread and poison.params.dps == 2,
      "buildComp materializes level-authored spore_tick effects")
  end

  -- Authored build-time auras should not be multiplied a second time by the
  -- legacy source-level multiplier.
  do
    local b = fresh()
    b:placeId(5, "husk", 3)
    b:placeId(2, "marauder", 1)
    local husk = compById(b:buildComp(-1), "husk")
    local mar = compById(b:buildComp(-1), "marauder")
    assert(husk and mar and math.abs((husk.dmgReduce or 0) - 0.08) < 1e-9
      and math.abs((mar.dmgReduce or 0) - 0.08) < 1e-9,
      "husk L3 team wall bakes dmgReduce on the team")
  end

  do
    local b = fresh()
    b:placeId(5, "shieldbearer", 2)
    b:placeId(2, "marauder")
    local mar = compById(b:buildComp(-1), "marauder")
    assert(mar and mar.shield == 11, "shieldbearer L2 shield = 11, not double-scaled")
  end

  do
    local b = fresh()
    b:placeId(5, "miasma_acolyte", 2)
    b:placeId(2, "witch")
    local wit = compById(b:buildComp(-1), "witch")
    assert(wit and math.abs((wit.poisonInc or 0) - 0.90) < 1e-9,
      "miasma_acolyte L2 poisonInc = 0.90, not double-scaled")
  end

  -- Concrete mismatch fix: clot_mender now grants stronger bleed by level.
  do
    local b = fresh()
    b:placeId(5, "clot_mender", 3)
    b:placeId(2, "marauder")
    local mar = compById(b:buildComp(-1), "marauder")
    local bleed = effectByOp(mar, "bleed")
    assert(bleed and bleed.params.dps == 3 and bleed.params.dur == 210,
      "clot_mender L3 grants level-aware bleed")
  end

  -- grant_team command bonuses can now scale by commander level.
  do
    local b = fresh()
    b:placeId(5, "marauder")
    b.commanderSlot = { id = "corruptor", level = 3 }
    local cmd = compById(b:buildComp(-1), "corruptor")
    local grant = commandEffect(cmd)
    assert(grant and grant.params.markEnemiesVuln == 0.18,
      "corruptor command L3 markEnemiesVuln scales through resolver")
  end

  -- Snapshots must carry authored level effects too; async ghosts cannot play
  -- a different version of the card.
  do
    local snap = Snapshot.capture({ { id = "spore_tick", level = 3, col = 1, row = 1 } }, "carre", 7)
    local comp = Snapshot.toComp(snap, 1)
    local poison = effectByOp(comp[1], "poison")
    assert(poison and poison.params.spread, "snapshot toComp materializes authored level effects")
  end

  print("  unit_resolver : stats shared / level effects / build + command + snapshot propagation OK")
end)

if ok then
  print("=> UNIT RESOLVER OK : level-aware source of truth is wired.")
else
  print("=> UNIT RESOLVER FAIL :")
  print(err)
  os.exit(1)
end
