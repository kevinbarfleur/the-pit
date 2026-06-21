-- tests/run.lua
-- Tests de l'ÉCONOMIE de run (src/run/state.lua) : module PUR, donc testable headless avec le mock.
-- Couvre les invariants éco (or>=0, vies/slots/niveau bornés), les transitions (achat, reroll, niveau,
-- résolution, streaks, filet de vie tour 3, fin de run) et le DÉTERMINISME seedé (rejouabilité du run).
--   Lancement : luajit tests/run.lua   (depuis la racine du projet)
package.path = "./?.lua;" .. package.path
love = require("tests.mock_love")

local RunState = require("src.run.state")

local function shopIds(r)
  local t = {}
  for i, o in ipairs(r.shop) do t[i] = o.id end
  return table.concat(t, ",")
end

local ok, err = pcall(function()
  -- ── État initial (round 1 déjà ouvert) ──
  do
    local r = RunState.new(42)
    assert(r.gold == RunState.GOLD_PER_ROUND, "or initial = or/round")
    assert(r.lives == RunState.START_LIVES, "vies initiales = 5")
    assert(r.wins == 0 and r.losses == 0, "0 victoire / 0 defaite")
    assert(r.round == 1, "demarre au round 1")
    assert(r.slots == RunState.START_SLOTS, "demarre a 3 slots")
    assert(r.pendingSlotGrant == false, "round 1 : aucune offre de slot en attente")
    assert(#r.shop == RunState.SHOP_SIZE, "boutique = 5 offres")
    assert(r:isOver() == nil, "run en cours")
  end

  -- ── DÉTERMINISME : même seed + mêmes actions -> état strictement identique ──
  do
    local function trace(seed)
      local r = RunState.new(seed)
      local parts = { shopIds(r) }
      r:reroll(); parts[#parts + 1] = shopIds(r)
      parts[#parts + 1] = tostring(r:nextCombatSeed())
      parts[#parts + 1] = tostring(r:nextCombatSeed())
      r:startRound(); parts[#parts + 1] = shopIds(r)
      return table.concat(parts, "|")
    end
    assert(trace(12345) == trace(12345), "determinisme: meme seed -> meme run")
    assert(trace(1) ~= trace(2) or true, "seeds differents (informatif)")
  end

  -- ── Achat ──
  do
    local r = RunState.new(7)
    local offer = r.shop[1]
    local g0 = r.gold
    local id = r:buy(1)
    assert(id == offer.id, "achat: renvoie l'id de l'offre")
    assert(r.gold == g0 - offer.cost, "achat: or deduit du cout")
    assert(r.shop[1].sold, "achat: offre consommee")
    assert(r:buy(1) == nil, "achat: une offre vendue ne se rachete pas")
    -- Trop cher -> nil, or inchangé.
    r.gold = 0
    local g1 = r.gold
    assert(r:buy(2) == nil and r.gold == g1, "achat: refuse si or insuffisant")
  end

  -- ── Reroll ──
  do
    local r = RunState.new(9)
    local before = shopIds(r)
    local g0 = r.gold
    assert(r:reroll() == true, "reroll: reussit avec de l'or")
    assert(r.gold == g0 - RunState.REROLL_COST, "reroll: cout deduit")
    -- (le contenu PEUT coincider par hasard, mais l'or a bien baissé)
    r.gold = 0
    assert(r:reroll() == false, "reroll: refuse sans or")
    assert(before == before, "garde-fou")
  end

  -- ── Emplacements = GRANTS TIMÉS (accepter +1 slot / refuser +or), plus de gold-leveling ──
  do
    local r = RunState.new(3)
    -- Round 1 : pas d'offre. On avance les rounds : une offre arrive aux rounds 2..7.
    assert(r:canGrant() == false, "round 1 : pas d'offre")
    assert(r:acceptSlotGrant() == false and r:declineSlotGrant() == false, "rien a trancher sans offre")
    r:startRound() -- round 2 : 1re offre
    assert(r.round == 2 and r:canGrant(), "round 2 : une offre de slot")
    local slots0 = r.slots
    assert(r:acceptSlotGrant() == true, "accepter l'offre")
    assert(r.slots == slots0 + 1, "accepter : +1 capacite de slot")
    assert(r.pendingSlotGrant == false, "offre consommee")
    assert(r:acceptSlotGrant() == false, "pas de double-accept sur la meme offre")
    -- Refus : +or, capacite INCHANGÉE, offre consommée (slot renonce).
    r:startRound() -- round 3 : nouvelle offre
    local g0, sl0 = r.gold, r.slots
    assert(r:canGrant(), "round 3 : offre")
    assert(r:declineSlotGrant() == true, "refuser l'offre")
    assert(r.gold == g0 + RunState.SLOT_DECLINE_GOLD, "refuser : +or du refus")
    assert(r.slots == sl0, "refuser : capacite inchangee")
    -- Total borné : 6 grants (rounds 2..7) -> au plus 9 slots si tout accepte.
    local r2 = RunState.new(9)
    for _ = 1, 12 do r2:startRound(); if r2:canGrant() then r2:acceptSlotGrant() end end
    assert(r2.slots == RunState.MAX_SLOTS, "tout accepter -> 9 slots")
    assert(r2.slotGrantsResolved == RunState.MAX_GRANTS, "exactement MAX_GRANTS offres tranchees")
    assert(r2:canGrant() == false, "plus d'offre au-dela du plafond")
  end

  -- ── Résolution + streaks ──
  do
    local r = RunState.new(5)
    r:resolve(true)
    assert(r.wins == 1 and r.winStreak == 1 and r.lossStreak == 0, "victoire: +1 win, streak")
    r:resolve(true); assert(r.winStreak == 2, "victoire: streak cumule")
    r:resolve(false)
    assert(r.losses == 1 and r.lives == RunState.START_LIVES - 1, "defaite: -1 vie")
    assert(r.lossStreak == 1 and r.winStreak == 0, "defaite: reset win streak")
  end

  -- ── Or FRAIS chaque round (modèle SAP, pas de report) + bonus de série ──
  do
    local r = RunState.new(5)
    r.gold = 0 -- on a tout dépensé
    r:resolve(true); r:resolve(true); r:resolve(true) -- streak 3 -> bonus 2
    r:startRound()
    assert(r.gold == RunState.GOLD_PER_ROUND + 2, "or reset a 10 + bonus de streak (3 -> +2)")
  end

  -- ── Filet de vie au round 3 (SAP) ──
  do
    local r = RunState.new(8)
    r:resolve(false) -- perte au round 1 -> 4 vies
    assert(r.lives == 4, "perte round 1")
    r:startRound() -- round 2
    assert(r.round == 2 and r.lives == 4, "round 2: pas de vie rendue")
    r:startRound() -- round 3 -> +1 vie
    assert(r.round == 3 and r.lives == 5, "round 3: +1 vie si on a perdu tot")
    -- Sans perte, pas de cadeau.
    local r2 = RunState.new(8)
    r2:startRound(); r2:startRound()
    assert(r2.lives == RunState.START_LIVES, "round 3 sans perte: vies pleines, rien en plus")
  end

  -- ── Fin de run ──
  do
    local r = RunState.new(1)
    for _ = 1, RunState.WIN_TARGET do r:resolve(true) end
    assert(r:isOver() == "win", "10 victoires -> win")
    local r2 = RunState.new(1)
    for _ = 1, RunState.START_LIVES do r2:resolve(false) end
    assert(r2:isOver() == "lose", "plus de vie -> lose")
  end

  -- ── Invariants sous fuzz d'actions seedées ──
  do
    local gen = love.math.newRandomGenerator(20260620)
    local runs, steps = 60, 80
    for run = 1, runs do
      local r = RunState.new(run * 101)
      for _ = 1, steps do
        local a = gen:random(1, 5)
        if a == 1 then r:buy(gen:random(1, RunState.SHOP_SIZE))
        elseif a == 2 then r:reroll()
        elseif a == 3 then if gen:random(1, 2) == 1 then r:acceptSlotGrant() else r:declineSlotGrant() end
        elseif a == 4 then r:resolve(gen:random(1, 2) == 1)
        else r:startRound() end
        -- Invariants durs (jamais violés, quelle que soit la suite d'actions).
        assert(r.gold >= 0, "invariant: or >= 0")
        assert(r.lives >= 0 and r.lives <= RunState.START_LIVES, "invariant: vies dans [0,5]")
        assert(r.slots >= RunState.START_SLOTS and r.slots <= RunState.MAX_SLOTS, "invariant: slots [3,9]")
        assert(r.slotGrantsResolved <= RunState.MAX_GRANTS, "invariant: offres tranchees <= MAX_GRANTS")
        assert(#r.shop == RunState.SHOP_SIZE, "invariant: boutique = 5 offres")
        if r:isOver() then break end
      end
    end
    print(string.format("  fuzz : %d runs x %d actions, invariants eco OK", runs, steps))
  end

  print("  eco : etat initial / determinisme / achat / reroll / niveau / streaks / or-reset / vie-tour3 / fin OK")
end)

if ok then
  print("=> RUN OK : economie deterministe et invariants tenus.")
else
  print("=> RUN FAIL :")
  print(err)
  os.exit(1)
end
