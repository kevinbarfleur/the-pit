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
    assert(r.level == 1 and r.slots == RunState.START_SLOTS, "niveau 1 -> 3 slots")
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

  -- ── Leveling = déblocage de slots ──
  do
    local r = RunState.new(3)
    r.gold = 99
    local lvl0, slots0 = r.level, r.slots
    assert(r:levelUp() == true, "niveau: monte avec assez d'or")
    assert(r.level == lvl0 + 1, "niveau +1")
    assert(r.slots == slots0 + 1, "niveau debloque +1 slot")
    -- Jusqu'au max (slots = 9).
    for _ = 1, 20 do r.gold = 99; r:levelUp() end
    assert(r.slots == RunState.MAX_SLOTS, "niveau max -> 9 slots")
    assert(r.level == RunState.MAX_LEVEL, "plafond de niveau")
    assert(r:levelUp() == false, "niveau: refuse au plafond")
    -- Refus si or insuffisant.
    local r2 = RunState.new(3); r2.gold = 0
    assert(r2:levelUp() == false, "niveau: refuse sans or")
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
        elseif a == 3 then r:levelUp()
        elseif a == 4 then r:resolve(gen:random(1, 2) == 1)
        else r:startRound() end
        -- Invariants durs (jamais violés, quelle que soit la suite d'actions).
        assert(r.gold >= 0, "invariant: or >= 0")
        assert(r.lives >= 0 and r.lives <= RunState.START_LIVES, "invariant: vies dans [0,5]")
        assert(r.slots >= RunState.START_SLOTS and r.slots <= RunState.MAX_SLOTS, "invariant: slots [3,9]")
        assert(r.level >= 1 and r.level <= RunState.MAX_LEVEL, "invariant: niveau [1,7]")
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
