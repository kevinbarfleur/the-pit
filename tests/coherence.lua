-- tests/coherence.lua
-- Intent graph / coherence scoring guardrails for the balance program.
-- This does not simulate combat; it verifies that the analysis layer sees the
-- same plans the player is meant to read from cards, level-ups, and economy.
package.path = "./?.lua;" .. package.path
love = require("tests.mock_love")

local Coherence = require("src.lab.coherence")

local function hasEdge(edges, kind, family, from, to)
  for _, e in ipairs(edges or {}) do
    if e.kind == kind and e.family == family and (not from or e.from == from) and (not to or e.to == to) then
      return e
    end
  end
  return nil
end

local ok, err = pcall(function()
  local spore3 = Coherence.profileFor("spore_tick", 3)
  assert(spore3 and spore3.clutch, "spore_tick L3 is a low-rank clutch plan")
  assert(spore3.produces.poison and spore3.propagates.poison, "spore_tick L3 exposes poison spread to the graph")

  local miasma = Coherence.profileFor("miasma_acolyte", 3)
  assert(miasma.amplifies.poison and miasma.targets.neighbors, "miasma_acolyte is a neighbor poison amplifier")
  assert(hasEdge(Coherence.edgesForPair(miasma, spore3), "producer_amplifier", "poison", "miasma_acolyte", "spore_tick"),
    "miasma + spore creates a poison producer/amplifier edge")

  local burnEdges = Coherence.edgesForPair("wildfire_hound", "emberling")
  assert(hasEdge(burnEdges, "propagation_payoff", "burn", "wildfire_hound", "emberling"),
    "wildfire_hound reads as burn propagation payoff, not only a self-death effect")

  local shieldEdges = Coherence.edgesForPair("barrier_savant", "ward_weaver")
  assert(hasEdge(shieldEdges, "shield_engine", "shield", "barrier_savant", "ward_weaver"),
    "barrier_savant + ward_weaver forms a shield engine edge")

  local faintEdges = Coherence.edgesForPair("brood_mother", "carrion_choir")
  assert(hasEdge(faintEdges, "faint_engine", "faint", "brood_mother", "carrion_choir"),
    "summon units feed faint/scavenge payoff units")

  local mimicEdges = Coherence.edgesForPair("mimic_spawn", "witch")
  assert(hasEdge(mimicEdges, "mimicry_payoff", "mimicry", "mimic_spawn", "witch"),
    "mimicry units connect to on-hit carriers")

  local poison = Coherence.scoreTeam({
    { id = "spore_tick", level = 3, slot = 2 },
    { id = "miasma_acolyte", level = 3, slot = 5 },
    { id = "witch", level = 1, slot = 4 },
    { id = "corruptor", level = 3, slot = 6 },
  }, { commander = { id = "corruptor", level = 3 } })
  assert(poison.coherence > 0.80, "coherent poison reroll shell scores high")
  assert(poison.subscores.command > 0, "corruptor commander contributes a command score")
  assert(poison.subscores.level_plan > 0, "authored/clutch levels contribute to level_plan")
  assert(poison.economy.accessibility == "reroll_low_rank", "L3 spore makes the shell visible as low-rank reroll")

  local kingsBowl = Coherence.profileForRelic("kings_bowl")
  assert(kingsBowl and kingsBowl.amplifies.poison, "kings_bowl reads as a poison relic amplifier")
  local poisonRelic = Coherence.scoreTeam({
    { id = "spore_tick", level = 3, slot = 2 },
    { id = "miasma_acolyte", level = 3, slot = 5 },
    { id = "witch", level = 1, slot = 4 },
    { id = "corruptor", level = 3, slot = 6 },
  }, { commander = { id = "corruptor", level = 3 }, relics = { "kings_bowl" } })
  assert(poisonRelic.subscores.relic > 0, "matching relics contribute a relic coherence subscore")
  assert(hasEdge(poisonRelic.relicEdges, "producer_amplifier", "poison", "relic:kings_bowl"),
    "matching relics produce explicit relic->unit edges")

  local poisonBadPlacement = Coherence.scoreTeam({
    { id = "spore_tick", level = 3, slot = 1 },
    { id = "miasma_acolyte", level = 3, slot = 9 },
    { id = "witch", level = 1, slot = 3 },
    { id = "corruptor", level = 3, slot = 7 },
  }, { commander = { id = "corruptor", level = 3 } })
  assert(poisonBadPlacement.subscores.position < poison.subscores.position,
    "neighbor aura placement is measured separately from tag synergy")

  local randomPile = Coherence.scoreTeam({
    { id = "marauder", slot = 3 },
    { id = "skeleton", slot = 2 },
    { id = "bandit", slot = 1 },
    { id = "demon", slot = 4 },
  })
  assert(poison.coherence > randomPile.coherence + 0.25,
    "intentional poison shell scores clearly above a low-synergy pile")

  local tank = Coherence.scoreTeam({
    { id = "gravewarden", slot = 6 },
    { id = "templar", slot = 5 },
    { id = "plague_doctor", slot = 4 },
    { id = "leech_thorn", slot = 3 },
    { id = "skeleton", slot = 2, level = 2 },
    { id = "footman", slot = 1 },
  })
  assert(hasEdge(tank.edges, "guard_frontline", "guard"),
    "tank shells expose guard/frontline coherence, not only DoT tags")
  assert(tank.coherence > randomPile.coherence + 0.12,
    "readable tank shells score above a low-synergy pile")

  local burn = Coherence.scoreTeam({
    { id = "emberling", slot = 2 },
    { id = "soot_acolyte", slot = 5 },
    { id = "wildfire_hound", slot = 6 },
    { id = "bellows_priest", slot = 4 },
  }, { commander = "emberling" })
  assert(burn.coherence > randomPile.coherence + 0.20, "burn shell scores above the random baseline")

  local cur = Coherence.shopPressure("baseline")
  local sap = Coherence.shopPressure("sap_cost")
  local curved = Coherence.shopPressure("early_curve")
  local tiered = Coherence.shopPressure("tiered_reroll")
  assert(cur[1].fullShopCostRatio == 0.5, "baseline tier-1 shop costs half of 10g")
  assert(Coherence.shopPressure("current")[1].profile == "baseline", "legacy current alias resolves to baseline")
  assert(sap[1].fullShopCostRatio == 1.0, "SAP-like tier-1 shop consumes the full 10g")
  assert(curved[1].fullShopCostRatio > cur[1].fullShopCostRatio,
    "curved income increases early pressure while preserving cost=rank")
  assert(tiered[3].rerollCost == 2 and cur[3].rerollCost == 1,
    "coherence pressure reads real tiered reroll costs from run economy profiles")

  local coverage = Coherence.coverage()
  assert(coverage.units >= 100, "coherence coverage sees the full roster")
  assert(coverage.authoredLevelUnits >= 6, "authored level-up units are counted")
  assert(coverage.clutchUnits >= 2, "low-rank clutch units are counted")

  print(string.format("  coherence : poison %.3f / burn %.3f / random %.3f / graph edges %d OK",
    poison.coherence, burn.coherence, randomPile.coherence, coverage.graphEdgesLevel1))
end)

if ok then
  print("=> COHERENCE OK : intent graph, level plans, position and economy pressure are wired.")
else
  print("=> COHERENCE FAIL :")
  print(err)
  os.exit(1)
end
