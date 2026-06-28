-- tests/lab.lua
-- BANC D'ESSAI (lab) — garde-fous du socle de simulation :
--   1. INTÉGRITÉ du catalogue de compositions (ids/unités/slots/board-level/refs de scénarios)
--   2. FIDÉLITÉ du pont compbuild (les auras d'adjacence sont bien RÉSOLUES, pas sautées)
--   3. PURETÉ/déterminisme de runMatch (mêmes compos+seed -> verdict identique, compos non mutées)
--   4. SMOKE : chaque scénario featured conclut (verdict booléen) sous le plafond
--   5. MONOTONICITÉ du coût d'investissement (perfect >= variantes amputées ; score borné)
-- Lancement : luajit tests/lab.lua
package.path = "./?.lua;" .. package.path
love = require("tests.mock_love")

local Units = require("src.data.units")
local Shapes = require("src.board.shapes")
local Compositions = require("src.data.compositions")
local Compbuild = require("src.lab.compbuild")
local Compcost = require("src.lab.compcost")
local Arena = require("src.combat.arena")
local Match = require("src.combat.match")
local Pacing = require("src.run.pacing")
local Common = require("tools.scenarios.common")
local Bossrush = require("src.lab.bossrush")
local Abominations = require("src.data.abominations")
local Effects = require("src.effects.engine")

local ARCH = {}; for _, a in ipairs(Compositions.archetypes) do ARCH[a] = true end
local VARIANTS = { perfect = true, missing_minor = true, missing_clutch = true, wall = true, baseline = true, amp = true }

local ok, err = pcall(function()
  -- 1) INTÉGRITÉ DU CATALOGUE
  local seenId = {}
  for _, c in ipairs(Compositions.list) do
    assert(type(c.id) == "string" and not seenId[c.id], "id unique requis: " .. tostring(c.id))
    seenId[c.id] = true
    assert(ARCH[c.archetype], "archetype inconnu: " .. tostring(c.archetype) .. " (" .. c.id .. ")")
    assert(VARIANTS[c.variant], "variant inconnu: " .. tostring(c.variant) .. " (" .. c.id .. ")")
    assert(Shapes[c.sigil], "sigil inconnu: " .. tostring(c.sigil) .. " (" .. c.id .. ")")
    assert(type(c.boardLevel) == "number" and c.boardLevel >= 3 and c.boardLevel <= 9, "boardLevel 3..9: " .. c.id)
    assert(#c.units >= 1, "compo non vide: " .. c.id)
    assert(c.boardLevel >= #c.units, "boardLevel >= #units: " .. c.id)
    assert(type(c.noteKey) == "string", "noteKey requis: " .. c.id)
    local usedSlot = {}
    for _, u in ipairs(c.units) do
      assert(Units[u.id], "unite inconnue: " .. tostring(u.id) .. " (" .. c.id .. ")")
      assert(type(u.slot) == "number" and u.slot >= 1 and u.slot <= 9, "slot 1..9: " .. c.id)
      assert(u.slot <= c.boardLevel, "slot <= boardLevel (placable): " .. c.id .. " slot " .. u.slot)
      assert(not usedSlot[u.slot], "slot unique dans la compo: " .. c.id .. " slot " .. u.slot)
      usedSlot[u.slot] = true
      local lvl = u.level or 1
      assert(lvl >= 1 and lvl <= 3, "level 1..3: " .. c.id)
    end
  end
  for _, s in ipairs(Compositions.scenarios) do
    assert(Compositions.byId[s.a], "scenario " .. s.id .. " : compo A inconnue " .. tostring(s.a))
    assert(Compositions.byId[s.b], "scenario " .. s.id .. " : compo B inconnue " .. tostring(s.b))
    assert(type(s.seed) == "number", "scenario " .. s.id .. " : seed requis")
    if s.tags then -- facette de filtre thematique : tout tag doit etre connu (anti-typo)
      for _, tg in ipairs(s.tags) do
        assert(Compositions.tagSet[tg], "scenario " .. s.id .. " : tag inconnu " .. tostring(tg))
      end
    end
  end
  print(string.format("  lab : catalogue OK (%d compos, %d scenarios ; integrite + slots + refs)",
    #Compositions.list, #Compositions.scenarios))

  -- 2) FIDÉLITÉ DU PONT : auras RÉSOLUES (framework payoff). spore_tick@2 est voisin de miasma_acolyte@5
  -- sur diamant (arête 2-5) -> reçoit `poisonInc` (increased) baké sur l'UNITÉ, lu à la pose ET hérité par
  -- le spread (cf. payoff-framework.md). Un builder naïf ne verrait pas l'adjacence.
  local function poisonIncOf(comp, id)
    for _, s in ipairs(comp) do if s.id == id then return s.poisonInc end end
    return nil
  end
  local pc = Compositions.byId["poison_diamant_perfect"]
  local resolved = Compbuild.toComp(pc, -1)
  assert(#resolved == #pc.units, "pont: toutes les unites posees (" .. #resolved .. "/" .. #pc.units .. ")")
  local inc = poisonIncOf(resolved, "spore_tick")
  assert(inc and inc > 0, "pont: aura miasma resolue -> spore_tick poisonInc > 0 (obtenu " .. tostring(inc) .. ")")
  for _, c in ipairs(Compositions.list) do
    local rc = Compbuild.toComp(c, -1)
    assert(#rc == #c.units, "pont: " .. c.id .. " -> " .. #rc .. "/" .. #c.units .. " unites posees")
  end
  print("  lab : pont fidele OK (auras resolues ; toutes les compos se materialisent)")

  -- 3) PURETÉ/DÉTERMINISME du runner : memes compos+seed -> verdict identique ; compos non mutees.
  local L = Compbuild.toComp(Compositions.byId["bruiser_carre"], -1)
  local R = Compbuild.toComp(Compositions.byId["tank_carre"], 1)
  local r1 = Match.run(L, R, 4242, { assertPure = true })
  local r2 = Match.run(L, R, 4242, { assertPure = true })
  assert(r1.win == r2.win and r1.ticks == r2.ticks and r1.decided == r2.decided,
    "runner deterministe (memes compos+seed)")
  local paceL = { { id = "bandit", hp = 100, dmg = 1, cd = 36, x = 0, y = 0, facing = 1 } }
  local paceR = { { id = "skeleton", hp = 100, dmg = 1, cd = 44, x = 20, y = 0, facing = -1 } }
  local paced = Match.run(paceL, paceR, 77, { expose = true, judge = false, tickCap = 1, hpMult = 1, cooldownMult = 1.5 })
  assert(Arena.scaleCooldown(36, 1.5) == 54, "cooldown scale: arrondi deterministe")
  assert(Pacing.id("live") == "live_hp2_cd15_f26", "pacing live: profil documente")
  assert(Pacing.scaleCooldown(60, "live") == 90 and Pacing.formatCooldown(60, "live") == "1.5",
    "pacing live: cooldown affiche le temps reel joue")
  local legacyPace = Pacing.arenaOptions("legacy")
  assert(legacyPace.hpMult == 2 and legacyPace.cooldownMult == 1 and legacyPace.fatigue.start == 1020,
    "pacing legacy: profil de comparaison disponible")
  assert(paceL[1].cd == 36 and paceR[1].cd == 44, "cooldownMult: specs d'entree non mutees")
  assert(paced.arena.units[1].cd == 54 and paced.arena.units[2].cd == 66,
    "cooldownMult: copies combat scalees")
  print(string.format("  lab : runner pur/deterministe OK (ticks=%d win=%s decided=%s)",
    r1.ticks, tostring(r1.win), tostring(r1.decided)))

  -- 4) SMOKE : chaque scénario featured conclut (ou jugé) sous le plafond, verdict booléen.
  for _, s in ipairs(Compositions.scenarios) do
    local a = Compbuild.toComp(Compositions.byId[s.a], -1)
    local b = Compbuild.toComp(Compositions.byId[s.b], 1)
    local res = Match.run(a, b, s.seed, {})
    assert(type(res.win) == "boolean", "scenario " .. s.id .. " : verdict booleen")
  end
  print(string.format("  lab : smoke OK (%d scenarios concluent, verdict booleen)", #Compositions.scenarios))

  -- 5) MONOTONICITÉ DU COÛT : perfect >= variantes amputées (le clutch/redondance coûte de l'or) ;
  -- score dans (0,1] ; placementSens dans [0,1]. C'est le socle de l'analyse investissement-aware.
  local function gold(id) return Compcost.of(Compositions.byId[id]).gold end
  assert(gold("poison_diamant_perfect") >= gold("poison_diamant_missing_minor"),
    "cout: perfect >= missing_minor")
  assert(gold("poison_diamant_perfect") > gold("poison_diamant_missing_clutch"),
    "cout: perfect > missing_clutch (festering premium retire)")
  for _, c in ipairs(Compositions.list) do
    local cc = Compcost.of(c)
    assert(cc.score > 0 and cc.score <= 1.0001, "score dans (0,1]: " .. c.id .. " = " .. cc.score)
    assert(cc.placementSens >= 0 and cc.placementSens <= 1, "placementSens dans [0,1]: " .. c.id)
    assert(cc.rankPressure >= 0 and cc.rankPressure <= 1, "rankPressure dans [0,1]: " .. c.id)
    assert(cc.duplicatePressure >= 0 and cc.duplicatePressure <= 1, "duplicatePressure dans [0,1]: " .. c.id)
  end
  local premiumAccess = Compcost.of({ sigil = "carre", boardLevel = 3, units = { { id = "gravewarden", slot = 1 } } })
  assert(premiumAccess.rankPressure > 0.45, "cout: rang 4 impose une pression d'acces")
  assert(premiumAccess.score >= premiumAccess.rankPressure, "cout: pression d'acces plancher du score")
  local duplicateAccess = Compcost.of({ sigil = "carre", boardLevel = 3, units = { { id = "spore_tick", slot = 1, level = 3 } } })
  assert(duplicateAccess.duplicatePressure >= 0.60, "cout: niveau 3 impose une pression de copies")
  assert(duplicateAccess.score >= duplicateAccess.duplicatePressure, "cout: pression de copies plancher du score")
  print("  lab : cout monotone OK (perfect>=minor>clutch en or ; score/rank/duplicatePressure bornes ; placementSens [0,1])")

  -- 6) SMOKE SCÈNE : le Proving Ground se construit, sélectionne, lance un batch SIM (étalé) et se
  -- dessine sans crash sous mock LÖVE (attrape tout appel love.graphics non stubé / clé i18n manquante).
  local Playground = require("src.scenes.playground")
  local Palette = require("src.core.palette")
  local pg = Playground.new(Palette, 320, 180, { goto = function() end })
  local view = { scale = 4, ox = 0, oy = 0 }
  pg:drawBack(view); pg:drawWorld(); pg:drawOverlay(view)
  pg:select(2); pg:mousemoved(10, 40); pg:startSim()
  for _ = 1, 3 do pg:update(1.0) end
  pg:drawOverlay(view)
  assert(pg.sim or pg.result, "scene: la boucle SIM tourne (en cours ou aboutie)")
  -- CONTENEUR SCROLLABLE : sélectionner la dernière ligne défile ; la molette est bornée [0, maxScroll].
  pg:select(#pg.scenarios)
  assert(pg.scroll > 0, "scene: selectionner la derniere ligne fait defiler la liste")
  pg:wheelmoved(0, 999); assert(pg.scroll == 0, "scene: molette haut -> debut de liste (borne 0)")
  pg:wheelmoved(0, -999); assert(pg.scroll == pg:maxScroll(), "scene: molette bas -> borne maxScroll")
  pg:drawOverlay(view)
  print("  lab : scene Proving Ground OK (construit + select + SIM + scroll + draw headless)")

  -- 7) PILOTE DE RUN : déterminisme (même seed+politique -> trajectoire identique).
  local Rundriver = require("src.lab.rundriver")
  local Policies = require("src.lab.policies")
  local liveDriver = Rundriver.new(7, {})
  assert(liveDriver.hpMult == Pacing.profiles.live.hpMult
    and liveDriver.cooldownMult == Pacing.profiles.live.cooldownMult
    and liveDriver.fatigue.start == Pacing.profiles.live.fatigue.start,
    "rundriver pacing: defaut aligne sur le live")
  assert(#liveDriver.build.benchSlots == Rundriver.DEFAULT_BENCH_SIZE,
    "rundriver bench: defaut live conserve")
  local reserveDriver = Rundriver.new(7, { benchSize = 6 })
  assert(#reserveDriver.build.benchSlots == 6 and reserveDriver:state().benchSize == 6,
    "rundriver bench: benchSize lab expose une vraie capacite")
  local legacyDriver = Rundriver.new(7, { pacingProfile = "legacy" })
  assert(legacyDriver.cooldownMult == Pacing.profiles.legacy.cooldownMult
    and legacyDriver.fatigue.start == Pacing.profiles.legacy.fatigue.start,
    "rundriver pacing: profil legacy disponible")
  local overrideDriver = Rundriver.new(7, { cooldownMult = 2, fatigue = { start = 1200 } })
  assert(overrideDriver.cooldownMult == 2 and overrideDriver.fatigue.start == 1200,
    "rundriver pacing: overrides explicites prioritaires")
  local t1 = Rundriver.run(31337, Policies.greedy_stats, {})
  local t2 = Rundriver.run(31337, Policies.greedy_stats, {})
  assert(t1.result == t2.result and t1.wins == t2.wins and #t1.rounds == #t2.rounds
    and t1.finalCost.gold == t2.finalCost.gold, "rundriver deterministe (greedy)")
  local r1 = Rundriver.run(42, Policies.random_baseline(love.math.newRandomGenerator(7)), {})
  local r2 = Rundriver.run(42, Policies.random_baseline(love.math.newRandomGenerator(7)), {})
  assert(r1.wins == r2.wins and #r1.rounds == #r2.rounds, "rundriver deterministe (random, RNG re-seede)")
  local function pacedRun()
    local calls = { left = 0, right = 0 }
    local mut = function(comp, side)
      calls[side] = (calls[side] or 0) + 1
      for _, s in ipairs(comp or {}) do s.cd = math.max(1, math.floor((s.cd or 1) * 2 + 0.5)) end
    end
    return Rundriver.run(314159, Policies.greedy_stats, { hpMult = 2, compMutator = mut }), calls
  end
  local pt1, pc1 = pacedRun()
  local pt2, pc2 = pacedRun()
  assert(pt1.result == pt2.result and pt1.wins == pt2.wins and #pt1.rounds == #pt2.rounds,
    "rundriver mutateur compo: deterministe")
  assert(pc1.left == pc1.right and pc1.left == #pt1.rounds and pc2.left == pc2.right,
    "rundriver mutateur compo: applique aux deux camps a chaque combat")
  local ft1 = Rundriver.run(161803, Policies.greedy_stats, { fatigue = { start = 1440 }, hpMult = 2 })
  local ft2 = Rundriver.run(161803, Policies.greedy_stats, { fatigue = { start = 1440 }, hpMult = 2 })
  assert(ft1.wins == ft2.wins and #ft1.rounds == #ft2.rounds,
    "rundriver fatigue override: deterministe")
  local leftCalls = 0
  local lt = Rundriver.run(271828, Policies.greedy_stats, {
    leftMutator = function(comp)
      leftCalls = leftCalls + 1
      if comp[1] then comp[1].hp = comp[1].hp + 1 end
    end,
  })
  assert(leftCalls == #lt.rounds, "rundriver leftMutator: applique uniquement au joueur a chaque combat")
  local intentDrv = Rundriver.new(20260626, {})
  local desired = Policies.greedy_stats:desiredOffers(intentDrv)
  assert(desired.visibleCount >= desired.count and desired.visibleCost >= desired.cost,
    "policy intent: distingue offres visibles et placables")
  assert(desired.count > 0 and desired.cost > 0, "policy intent: greedy expose les offres desirees")
  local committed = Policies.committed_archetype("poison", "diamant")
  intentDrv.build.board:unlock(3)
  intentDrv.build:placeId(1, "spore_tick", 1)
  intentDrv.build:placeId(2, "witch", 1)
  intentDrv.build:placeId(3, "marauder", 1)
  local commitment = committed:commitment(intentDrv)
  assert(commitment.committed and commitment.hits == 2, "policy intent: commitment archetype detecte")
  local function findEvent(events, kind)
    for _, ev in ipairs(events or {}) do if ev.type == kind then return ev end end
    return nil
  end
  local function unlockedSlots(d)
    local slots = {}
    for i = 1, 9 do if d.build.board.slots[i].unlocked then slots[#slots + 1] = i end end
    return slots
  end
  local relicEventDrv = Rundriver.new(20260632, {
    recordEvents = true,
    leftMutator = function(comp)
      for _, s in ipairs(comp or {}) do s.hp = 999; s.dmg = 120 end
    end,
  })
  relicEventDrv.build:placeId(5, "marauder", 3)
  relicEventDrv.run.wins = 2
  local relicFight = relicEventDrv:fight()
  assert(relicFight.relicChoices and #relicFight.relicChoices > 0, "events: offre de relique forcee")
  local relicOffer = findEvent(relicEventDrv.events, "relic_offer")
  assert(relicOffer and relicOffer.choices[1] == relicFight.relicChoices[1],
    "events: relic_offer trace les choix sans les modifier")
  local pickedRelic = relicEventDrv:pickRelic(1)
  assert(pickedRelic == relicFight.relicChoices[1], "events: pickRelic garde le meme resultat")
  assert(findEvent(relicEventDrv.events, "relic_pick").id == pickedRelic,
    "events: relic_pick trace la relique choisie")
  local runEventDrv = Rundriver.new(2026063201, {
    recordEvents = true,
    runEvents = true,
    leftMutator = function(comp)
      for _, s in ipairs(comp or {}) do s.hp = 999; s.dmg = 120 end
    end,
  })
  runEventDrv.build:placeId(5, "marauder", 2)
  runEventDrv.run.wins = 1
  runEventDrv.run.losses = 1
  local runEventFight = runEventDrv:fight()
  assert(runEventFight.runEvent and #(runEventFight.runEvent.choices or {}) > 0,
    "events: offre run_event au 3e combat hors jalon")
  local runEventOffer = findEvent(runEventDrv.events, "run_event_offer")
  assert(runEventOffer and runEventOffer.id == runEventFight.runEvent.id,
    "events: run_event_offer trace la rencontre")
  local pickedEvent = runEventDrv:pickRunEvent(1)
  assert(pickedEvent and pickedEvent.reward, "events: pickRunEvent renvoie le choix materialise")
  assert(findEvent(runEventDrv.events, "run_event_pick").id == runEventFight.runEvent.id,
    "events: run_event_pick trace le choix")
  local unitRewardDrv = Rundriver.new(2026063202, { recordEvents = true })
  unitRewardDrv.build:placeId(5, "skeleton", 1)
  assert(unitRewardDrv:grantUnitReward({ kind = "unit", id = "marauder", level = 2 }),
    "events: reward unite se range via Build")
  assert(unitRewardDrv:copyCount("marauder", 2) == 1,
    "events: reward unite respecte le niveau materialise")
  local function commanderEventRun()
    local d = Rundriver.new(20260633, { recordEvents = true, commanderMode = "auto" })
    d.run.pendingCommanderGrant = true
    d.build:placeId(5, "skeleton", 1)
    d.build.bench[1] = { id = "witch", level = 1, char = d.build:newRig("witch") }
    d:resolveCommanderMode()
    return d
  end
  local commanderA, commanderB = commanderEventRun(), commanderEventRun()
  local windowA, windowB = findEvent(commanderA.events, "commander_window"), findEvent(commanderB.events, "commander_window")
  assert(windowA and windowB and windowA.candidates[1].id == windowB.candidates[1].id,
    "events: ordre des candidats commandants stable")
  assert(findEvent(commanderA.events, "commander_place").id == windowA.candidates[1].id,
    "events: commander_place trace le candidat pose")
  local commanderIgnore = Rundriver.new(20260634, { recordEvents = true, commanderMode = "ignore" })
  commanderIgnore.run.pendingCommanderGrant = true
  commanderIgnore.build:placeId(5, "skeleton", 1)
  assert(commanderIgnore:resolveCommanderMode() == nil and not findEvent(commanderIgnore.events, "commander_place"),
    "events: commanderMode ignore ne pose pas de commandant")
  local focusedPlan = Policies.committed_unit_set_plan("test_focused_rot", "rot", "carre", {
    "rot_hound", "carrion_pecker",
  }, { supportArchetypes = { rot = true } })
  assert(focusedPlan:pickRelic(nil, { "bloodstone", "grave_cap", "aegis" }) == 2,
    "policy plan: choisit une relique focus plutot qu'une relique generique")
  assert(focusedPlan:pickRunEvent(nil, {
    choices = {
      { reward = { kind = "gold", amount = 9 } },
      { reward = { kind = "relic", id = "grave_cap" } },
      { reward = { kind = "shop_xp", amount = 4 } },
    },
  }) == 2, "policy plan: choisit une relique focus dans un event")
  assert(focusedPlan:pickRunEvent(nil, {
    choices = {
      { reward = { kind = "gold", amount = 9 } },
      { reward = { kind = "unit", id = "rot_hound", level = 2 } },
      { reward = { kind = "shop_xp", amount = 4 } },
    },
  }) == 2, "policy plan: choisit une unite coeur dans un event")
  local cmdPick = focusedPlan:chooseCommanderCandidate(nil, {
    { where = "bench", slot = 1, id = "gash_fiend", level = 1 },
    { where = "bench", slot = 2, id = "rot_hound", level = 1 },
  })
  assert(cmdPick and cmdPick.id == "rot_hound",
    "policy plan: choisit le commandant qui amplifie le coeur du plan")
  local spacePlan = Policies.committed_unit_set_plan("test_core_space", "rot", "carre", {
    "marrow_drinker",
  }, { supportArchetypes = { rot = true, bleed = true } })
  local spaceDrv = Rundriver.new(20260635, {})
  spaceDrv.run.gold = 99
  spaceDrv.run.slots = 5
  spaceDrv.build.board:ensureOpen(5)
  local sts = unlockedSlots(spaceDrv)
  spaceDrv.build:placeId(sts[1], "gash_fiend", 1)
  spaceDrv.build:placeId(sts[2], "rot_hound", 1)
  spaceDrv.build:placeId(sts[3], "razorkin", 1)
  spaceDrv.build:placeId(sts[4], "marauder", 1)
  spaceDrv.build:placeId(sts[5], "bandit", 1)
  for i = 1, #spaceDrv.build.benchSlots do
    spaceDrv.build.bench[i] = { id = "templar", level = 2, char = spaceDrv.build:newRig("templar") }
  end
  spaceDrv.run.shop[1] = { id = "marrow_drinker", cost = 5, sold = false }
  for i = 2, #spaceDrv.run.shop do spaceDrv.run.shop[i].sold = true end
  local spaceDecision = spacePlan:act(spaceDrv)
  assert(spaceDecision.boardSold == 1 and spaceDrv:copyCount("marrow_drinker", 1) == 1,
    "policy plan: vend un filler support pour acheter une piece coeur")
  local xpGatePlan = Policies.committed_unit_set_plan("test_xp_gate", "rot", "carre", {
    "rot_hound", "carrion_pecker",
  }, {
    minRank = 5,
    maxXpBuysPerRound = 3,
    xpCoverageGate = { holdRank = 3, minUnitCoverage = 0.5, minLevelCoverage = 0.5 },
    targetLevels = { rot_hound = 3, carrion_pecker = 3 },
  })
  local gateDrv = Rundriver.new(20260636, {})
  gateDrv.run.gold = 99
  gateDrv.run.shopTier = 3
  gateDrv.run.shopXp = 0
  gateDrv.build:placeId(unlockedSlots(gateDrv)[1], "marauder", 1)
  for i = 1, #gateDrv.run.shop do gateDrv.run.shop[i].sold = true end
  local gateDecision = xpGatePlan:act(gateDrv)
  assert(gateDecision.xpBuys == 0 and gateDecision.xpGateBlocked and gateDrv.run.shopTier == 3,
    "policy plan: la barriere de couverture bloque le rush XP sans pieces coeur")
  assert(gateDecision.xpGateUnitCoverage == 0 and gateDecision.xpGateLevelCoverage == 0,
    "policy plan: la barriere expose la couverture manquante")
  local allowDrv = Rundriver.new(20260637, {})
  allowDrv.run.gold = 99
  allowDrv.run.shopTier = 3
  allowDrv.run.shopXp = 0
  allowDrv.build:placeId(unlockedSlots(allowDrv)[1], "rot_hound", 3)
  for i = 1, #allowDrv.run.shop do allowDrv.run.shop[i].sold = true end
  local allowDecision = xpGatePlan:act(allowDrv)
  assert(allowDecision.xpBuys > 0 and not allowDecision.xpGateBlocked,
    "policy plan: la barriere autorise l'XP quand le coeur est assez couvert")
  print(string.format("  lab : rundriver deterministe OK (greedy %s en %d rounds)", tostring(t1.result), #t1.rounds))

  -- 8) LÉGALITÉ : chaque politique mène une run a une issue valide (win/lose), invariants tenus.
  local prng = love.math.newRandomGenerator(555)
  local analysisPolicies = Policies.analysisSet(prng)
  for _, p in ipairs(analysisPolicies) do
    local t = Rundriver.run(909, p, {})
    assert(t.result == "win" or t.result == "lose", "politique " .. p.name .. " : run conclut")
    assert(#t.rounds >= 1 and t.wins >= 0 and t.losses >= 0, "politique " .. p.name .. " : compteurs valides")
  end
  print(string.format("  lab : %d politiques menent des runs valides (win/lose)", #analysisPolicies))

  -- 9) API D'ACTIONS : refus propres + effets attendus + classifieur d'archétype (jamais d'exception).
  local drv = Rundriver.new(2025, {})
  assert(drv:buy(1, 99) == false, "buy: slot invalide refuse (pas d'or debite)")
  local before, boughtId = drv.run.gold, nil
  for i = 1, #drv.run.shop do
    local o = drv.run.shop[i]
    if o and not o.sold and drv.run.gold >= o.cost then boughtId = drv:buy(i); break end
  end
  assert(boughtId and drv.run.gold < before and drv.build:placedCount() >= 1, "buy: or debite + unite posee")
  local benchDrv = Rundriver.new(20260627, {})
  for i = 1, 9 do
    if benchDrv.build.board.slots[i].unlocked then benchDrv.build:placeId(i, "marauder", 3) end
  end
  benchDrv.run.gold = 99
  local benchOffer = benchDrv.run.shop[1].id
  assert(benchDrv:buy(1) == benchOffer, "buy: plateau plein -> achat auto vers banc")
  assert(benchDrv.build.bench[1] and benchDrv.build.bench[1].id == benchOffer, "buy: unite posee dans le banc")
  local benchState = benchDrv:state()
  assert(benchState.benchUsed == 1 and benchState.benchFree == #benchDrv.build.benchSlots - 1,
    "state: expose occupation du banc")
  local wideBenchDrv = Rundriver.new(202606271, { benchSize = 6 })
  for i = 1, 9 do
    if wideBenchDrv.build.board.slots[i].unlocked then wideBenchDrv.build:placeId(i, "marauder", 3) end
  end
  for i = 1, 5 do wideBenchDrv.build.bench[i] = { id = "templar", level = 2, char = wideBenchDrv.build:newRig("templar") } end
  wideBenchDrv.run.gold = 99
  local wideOffer = wideBenchDrv.run.shop[1].id
  assert(wideBenchDrv:buy(1) == wideOffer and wideBenchDrv.build.bench[6],
    "benchSize: achat auto utilise les slots de reserve additionnels")
  local sellBefore = benchDrv.run.gold
  assert(benchDrv:sellBench(1), "sellBench: vend une unite du banc")
  assert(not benchDrv.build.bench[1] and benchDrv.run.gold > sellBefore, "sellBench: libere le banc + rembourse")
  local sellMetrics = benchDrv:metricSnapshot()
  assert(sellMetrics.sells == 1 and sellMetrics.sellGold > 0 and sellMetrics.benchSells == 1,
    "sellBench: metrique vente tracee")
  local pairDrv = Rundriver.new(20260628, {})
  pairDrv.run.gold = 99
  pairDrv.run.shop[1] = { id = "spore_tick", cost = 1, sold = false }
  local ps = unlockedSlots(pairDrv)
  pairDrv.build:placeId(ps[1], "spore_tick", 1)
  assert(pairDrv:buy(1) == "spore_tick", "buy: achat d'une deuxieme copie")
  local pairMetrics = pairDrv:metricSnapshot()
  assert(pairMetrics.pairBuys == 1 and pairMetrics.mergeBuys == 0, "buy: metrique paire tracee")
  local supportDrv = Rundriver.new(202606281, {
    economy = { id = "test_pair_support", pairCompletionSupport = { maxPerRound = 1, minRound = 1 } },
  })
  supportDrv.run.shop = {
    { id = "husk", cost = 1, sold = false },
    { id = "rot_hound", cost = 1, sold = false },
    { id = "bore_worm", cost = 1, sold = false },
    { id = "marauder", cost = 1, sold = false },
    { id = "templar", cost = 1, sold = false },
  }
  local ss = unlockedSlots(supportDrv)
  supportDrv.build:placeId(ss[1], "spore_tick", 1)
  supportDrv.build:placeId(ss[2], "spore_tick", 1)
  assert(supportDrv:applyShopSupport("test") == true and supportDrv.run.shop[5].id == "spore_tick",
    "pair support: injecte une troisieme copie quand une paire est tenue")
  assert(supportDrv.run.shop[5].support == "pair_completion" and supportDrv.run.shop[5].replacedId == "templar",
    "pair support: marque l'offre supportee et l'offre remplacee")
  assert(supportDrv:applyShopSupport("test") == false,
    "pair support: une seule injection par round par defaut")
  assert(supportDrv:metricSnapshot().pairSupportOffers == 1,
    "pair support: metrique tracee")
  local delayedDrv = Rundriver.new(202606282, {
    economy = { id = "test_pair_support_delayed", pairCompletionSupport = { maxPerRound = 1, minRound = 1, minMissedWindows = 2 } },
  })
  delayedDrv.run.shop = {
    { id = "husk", cost = 1, sold = false },
    { id = "rot_hound", cost = 1, sold = false },
    { id = "bore_worm", cost = 1, sold = false },
    { id = "marauder", cost = 1, sold = false },
    { id = "templar", cost = 1, sold = false },
  }
  local ds = unlockedSlots(delayedDrv)
  delayedDrv.build:placeId(ds[1], "spore_tick", 1)
  delayedDrv.build:placeId(ds[2], "spore_tick", 1)
  assert(delayedDrv:applyShopSupport("test") == false,
    "pair support delayed: attend une premiere fenetre ratee")
  delayedDrv.run.shop[5] = { id = "templar", cost = 1, sold = false }
  assert(delayedDrv:applyShopSupport("test") == true and delayedDrv.run.shop[5].id == "spore_tick",
    "pair support delayed: injecte apres deux fenetres ratees")
  local mergeDrv = Rundriver.new(20260629, {})
  mergeDrv.run.gold = 99
  mergeDrv.run.shop[1] = { id = "spore_tick", cost = 1, sold = false }
  local ms = unlockedSlots(mergeDrv)
  mergeDrv.build:placeId(ms[1], "spore_tick", 1)
  mergeDrv.build:placeId(ms[2], "spore_tick", 1)
  assert(mergeDrv:buy(1) == "spore_tick", "buy: achat d'une troisieme copie")
  local mergeMetrics = mergeDrv:metricSnapshot()
  assert(mergeMetrics.mergeBuys == 1 and mergeDrv:copyCount("spore_tick", 2) == 1,
    "buy: metrique fusion tracee")
  local exactDrv = Rundriver.new(202606291, {})
  exactDrv.run.gold = 99
  local es = unlockedSlots(exactDrv)
  exactDrv.build:placeId(es[1], "spore_tick", 1)
  exactDrv.run.shop[1] = { id = "spore_tick", cost = 1, sold = false }
  assert(exactDrv:buy(1) == "spore_tick", "copy lifecycle: achat de paire")
  exactDrv.run.shop[1] = { id = "spore_tick", cost = 1, sold = false }
  assert(exactDrv:buy(1) == "spore_tick", "copy lifecycle: achat de fusion")
  assert(#exactDrv.pairEvents == 1 and #(exactDrv.pairEvents[1].copyIds or {}) == 2,
    "copy lifecycle: la paire porte les 2 copyIds")
  assert(#exactDrv.exactMergeEvents == 1 and #(exactDrv.exactMergeEvents[1].copyIds or {}) == 3,
    "copy lifecycle: la fusion exacte porte les 3 copyIds")
  local ml = Common.mergeLifecycleAgg()
  Common.addMergeLifecycle(ml, {
    pairEvents = exactDrv.pairEvents,
    exactMergeEvents = exactDrv.exactMergeEvents,
    rounds = {},
  })
  local mf = Common.finishMergeLifecycle(ml)
  assert(mf.exact_pairs == 1 and mf.exact_resolved == 1 and mf.exact_resolve_rate == 1,
    "copy lifecycle: merge_lifecycle resout la paire par identite exacte")
  local heldMl = Common.mergeLifecycleAgg()
  Common.addMergeLifecycle(heldMl, {
    pairEvents = pairDrv.pairEvents,
    exactMergeEvents = {},
    rounds = {},
    finalCopies = pairDrv:copyState(),
  })
  local heldMf = Common.finishMergeLifecycle(heldMl)
  assert(heldMf.unresolved == 1 and heldMf.terminal_causes.counts.held_to_run_end == 1,
    "copy lifecycle: paire exacte non fusionnee encore tenue -> held_to_run_end")
  assert(heldMf.third_copy_access.counts.never_offered == 1,
    "copy lifecycle: paire exacte tenue sans offre ulterieure -> never_offered")
  local function assertBossOps(list, owner)
    for _, e in ipairs(list or {}) do
      assert(Effects.ops[e.op], "bossrush: op inconnue " .. tostring(e.op) .. " dans " .. owner)
    end
  end
  for _, abom in ipairs(Abominations.list) do
    assertBossOps(abom.boss and abom.boss.effects, abom.key .. "/boss")
    for gi, g in ipairs(abom.generals or {}) do
      assertBossOps(g.effects, abom.key .. "/general" .. gi)
    end
  end
  local bossComp = Compbuild.toComp(Compositions.byId["bruiser_carre"], -1)
  local bossA = Bossrush.run(bossComp, "leviathan", 202606292, { scoreTicks = 120, tickCap = 2400 })
  local bossB = Bossrush.run(bossComp, "leviathan", 202606292, { scoreTicks = 120, tickCap = 2400 })
  assert(bossA.boss_key == "leviathan" and bossA.total_ticks > 0,
    "bossrush: combat pve produit un resultat")
  assert(bossA.boss_damage == bossB.boss_damage and bossA.total_ticks == bossB.total_ticks,
    "bossrush: resultat deterministe a seed identique")
  assert(type(bossA.damage_by_cause) == "table" and bossA.boss_hp_max > 0,
    "bossrush: degats/capacite boss reportes")
  local boardSellDrv = Rundriver.new(20260630, {})
  local bss = unlockedSlots(boardSellDrv)
  boardSellDrv.build:placeId(bss[1], "skeleton", 1)
  local boardSellBefore = boardSellDrv.run.gold
  assert(boardSellDrv:sell(bss[1]), "sell: vend une unite du plateau")
  local boardSellMetrics = boardSellDrv:metricSnapshot()
  assert(boardSellMetrics.boardSells == 1 and boardSellDrv.run.gold > boardSellBefore,
    "sell: metrique vente plateau tracee")
  local sellEventDrv = Rundriver.new(20260638, { recordEvents = true })
  sellEventDrv.build.bench[1] = { id = "spore_tick", level = 2, char = sellEventDrv.build:newRig("spore_tick") }
  assert(sellEventDrv:sellBench(1), "events: vend une unite de banc niveau 2")
  local benchSellEvent = findEvent(sellEventDrv.events, "sell")
  assert(benchSellEvent and benchSellEvent.where == "bench" and benchSellEvent.level == 2,
    "events: sellBench trace le niveau vendu")
  local boardSellEventDrv = Rundriver.new(20260639, { recordEvents = true })
  local eventSellSlot = unlockedSlots(boardSellEventDrv)[1]
  boardSellEventDrv.build:placeId(eventSellSlot, "rot_hound", 3)
  assert(boardSellEventDrv:sell(eventSellSlot), "events: vend une unite de plateau niveau 3")
  local boardSellEvent = findEvent(boardSellEventDrv.events, "sell")
  assert(boardSellEvent and boardSellEvent.where == "board" and boardSellEvent.level == 3,
    "events: sell plateau trace le niveau vendu")
  local planDrv = Rundriver.new(20260631, {})
  planDrv.run.gold = 99
  planDrv.run.slots = 5
  planDrv.build.board:ensureOpen(5)
  local ss = unlockedSlots(planDrv)
  planDrv.build:placeId(ss[1], "spore_tick", 1)
  planDrv.build:placeId(ss[2], "skeleton", 1)
  planDrv.build:placeId(ss[3], "bandit", 1)
  planDrv.build:placeId(ss[4], "marauder", 1)
  planDrv.build:placeId(ss[5], "demon", 1)
  for i = 1, #planDrv.build.benchSlots do
    planDrv.build.bench[i] = { id = "templar", level = 2, char = planDrv.build:newRig("templar") }
  end
  planDrv.run.shop[1] = { id = "spore_tick", cost = 1, sold = false }
  for i = 2, #planDrv.run.shop do planDrv.run.shop[i].sold = true end
  assert(Policies.greedy_plan:act(planDrv).boardSold == 1, "planner: libere une case board faible pour une paire")
  local planMetrics = planDrv:metricSnapshot()
  assert(planMetrics.boardSells == 1 and planMetrics.pairBuys == 1,
    "planner: trace vente board + achat de paire")
  if require("src.board.board").SIGILS_PAUSED then
    -- Sigils EN PAUSE : reshape est indisponible (refus propre) ; le plateau reste un carré.
    assert(drv:reshape("ligne") == false and drv.build.board.shape.name == "carre", "reshape refuse (sigils en pause)")
  else
    assert(drv:reshape("ligne") and drv.build.board.shape.name == "ligne", "reshape applique")
  end
  assert(drv:reshape("inexistant") == false, "reshape: sigil inconnu refuse")
  assert(Policies.archetypeOf("spore_tick") == "poison", "classifier: spore_tick = poison")
  assert(Policies.archetypeOf("gravewarden") == "tank", "classifier: gravewarden = tank")
  assert(Policies.archetypeOf("marauder") == "bruiser", "classifier: marauder = bruiser")
  assert(Policies.minRankForArchetype("tank") == 1, "classifier: tank commence au rang 1")
  print("  lab : API d'actions OK (refus propres + reshape + classifieur)")

  -- 10) ENCODEUR JSON du daemon (Pilier C) : types + tri des cles + echappement (sortie parsee par Python).
  local json = require("tools.gamed.json")
  assert(json.encode(42) == "42" and json.encode(-7) == "-7", "json: entiers")
  assert(json.encode(true) == "true" and json.encode(false) == "false", "json: booleens")
  assert(json.encode('x"y') == '"x\\"y"', "json: echappement des guillemets")
  assert(json.encode({ 1, 2, 3 }) == "[1,2,3]", "json: array dense")
  assert(json.encode({ b = 2, a = 1 }) == '{"a":1,"b":2}', "json: objet (cles triees -> diff-able)")
  print("  lab : encodeur JSON daemon OK (types + tri + echappement)")
end)

if ok then
  print("=> LAB OK : catalogue + pont + runner + smoke + cout.")
else
  print("=> LAB FAIL :")
  print(err)
  os.exit(1)
end
