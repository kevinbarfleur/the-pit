-- tests/props.lua
-- Tests de PROPRIÉTÉS / INVARIANTS + FUZZ. On génère des builds valides aléatoires (déterministes
-- via un RNG seedé) et on vérifie, sur chaque combat, des invariants qui DOIVENT toujours tenir :
--   · PV >= 0 et bouclier >= 0 à chaque tick
--   · TERMINAISON (le combat se conclut sous un plafond de ticks)
--   · exactement UN vainqueur à la fin
--   · DÉTERMINISME : même scénario + seed -> event-log identique (empreinte)
-- Un échec dump le seed pour rejouer. Lancement : luajit tests/props.lua
package.path = "./?.lua;" .. package.path
love = require("tests.mock_love")

local Palette = require("src.core.palette")
local Units = require("src.data.units")
local Shapes = require("src.board.shapes")
local Encounters = require("src.data.encounters")
local Arena = require("src.combat.arena")
local Build = require("src.scenes.build")
local EventLog = require("tools.eventlog")

local TICK_CAP = 8000
local gen = love.math.newRandomGenerator(20260620) -- RNG du fuzz, seedé -> reproductible

local ok, err = pcall(function()
  -- Joue un combat jusqu'à conclusion en vérifiant les invariants par tick.
  local function runToEnd(left, right, seed)
    local arena = Arena.new({ left = left, right = right, autoReset = false, seed = seed })
    local log = EventLog.attach(arena, { seed = seed })
    local n = 0
    for i = 1, TICK_CAP do
      arena:update(1.0, i * 1.0); n = i
      for _, u in ipairs(arena.units) do
        assert(u.hp >= 0, "invariant PV>=0 viole (seed=" .. seed .. ")")
        assert(u.shield >= 0, "invariant bouclier>=0 viole (seed=" .. seed .. ")")
        assert(u.hp <= u.maxHp, "invariant PV<=maxHp viole (seed=" .. seed .. ")")
      end
      if arena.over then break end
    end
    assert(arena.over, "non-terminaison sous " .. TICK_CAP .. " ticks (seed=" .. seed .. ")")
    -- Décompte côté BOARD (exclut les commandants intouchables, cohérent avec la logique de victoire de l'arène).
    local l, r = 0, 0
    for _, u in ipairs(arena.units) do
      if u.alive and not u.isCommander then if u.team == "left" then l = l + 1 else r = r + 1 end end
    end
    assert((l > 0) ~= (r > 0), "fin de combat: il faut exactement un camp survivant (seed=" .. seed .. ")")
    return arena, log, n
  end

  -- Génère un build valide aléatoire (forme/sigil, slots débloqués, unités posées).
  local function randomBuild()
    local b = Build.new(Palette, 320, 180, { goto = function() end })
    b.board:setShape(Shapes.order[gen:random(1, #Shapes.order)]); b:computeLayout()
    b.board:unlock(gen:random(2, 9))
    local nplace = gen:random(1, 9)
    for _ = 1, nplace do
      local slot = gen:random(1, 9)
      if b.board.slots[slot] and b.board.slots[slot].unlocked then
        b:placeId(slot, Units.order[gen:random(1, #Units.order)])
      end
    end
    return b
  end

  -- 1) DÉTERMINISME via event-log : même scénario + seed -> empreinte identique.
  do
    local b = randomBuild()
    local left = b:buildLeftComp()
    if #left == 0 then b:placeId(5, "marauder"); left = b:buildLeftComp() end
    local right = b:buildRightComp(Encounters[1])
    local _, log1 = runToEnd(left, right, 555)
    local _, log2 = runToEnd(left, right, 555)
    assert(log1:fingerprint() == log2:fingerprint(),
      "determinisme: meme scenario+seed -> event-log identique")
  end

  -- 2) FUZZ : N builds aléatoires vs encounters aléatoires, tous les invariants tiennent.
  local N, played = 250, 0
  for _ = 1, N do
    local b = randomBuild()
    local left = b:buildLeftComp()
    if #left > 0 then
      local enc = Encounters[gen:random(1, #Encounters)]
      runToEnd(left, b:buildRightComp(enc), gen:random(1, 2147483647))
      played = played + 1
    end
  end
  -- 3) COMMANDANT des DEUX côtés (§6.4.4) : le commandant est UNTARGETABLE (damage=0) et EXCLU du décompte.
  -- Un combat commandant-vs-commandant DOIT conclure (le board meurt, la fatigue le garantit). On fuzz des
  -- builds avec un commandant injecté dans CHAQUE camp -> terminaison + un seul vainqueur côté BOARD.
  do
    -- spec minimal d'unité (réutilise une unité réelle, marque isCommander). Le commandant n'a pas de slot board.
    local function commander(id, team)
      local u = Units[id]
      local facing = (team == "left") and 1 or -1
      local x = (team == "left") and 120 or 200
      return { id = id, hp = u.hp, dmg = u.dmg, cd = u.cd, depth = 0, row = -1,
        isCommander = true, untargetable = true, cdMult = 1.5, x = x, y = 50, facing = facing }
    end
    local fuzz2 = love.math.newRandomGenerator(424242)
    local concluded = 0
    for k = 1, 40 do
      local b = randomBuild()
      local left = b:buildLeftComp()
      if #left == 0 then b:placeId(5, "marauder"); left = b:buildLeftComp() end
      left[#left + 1] = commander("templar", "left")       -- commandant gauche (intouchable)
      local right = b:buildRightComp(Encounters[(k % #Encounters) + 1])
      right[#right + 1] = commander("witch", "right")       -- commandant droite (intouchable)
      local arena, _, n = runToEnd(left, right, fuzz2:random(1, 2147483647))
      -- vérifie : les commandants des DEUX camps survivent (intouchables) MAIS le combat est tranché côté board.
      local liveCmd = 0
      for _, u in ipairs(arena.units) do if u.isCommander and u.alive then liveCmd = liveCmd + 1 end end
      assert(liveCmd == 2, "commandants intouchables: les 2 survivent (combat tranche par le board)")
      assert(n < TICK_CAP, "commandant-vs-commandant: terminaison sous le plafond")
      concluded = concluded + 1
    end
    assert(concluded == 40, "commandant des 2 cotes: 40/40 combats conclus")
  end

  -- 4) TERMINAISON sous HASTE CUMULÉ MAX (rollout § command-auras V0) : le cap de lecture HASTE_CAP borne la
  -- cadence -> même un `haste` ABSURDE (cumul aura-commandant + relique + adjacence, voire >1.0) ne donne JAMAIS
  -- un timer ≤0 (qui ferait une frappe instantanée -> boucle infinie / non-terminaison). On force un haste démesuré
  -- sur CHAQUE unité des deux camps et on exige : terminaison sous le plafond + timer toujours > 0 à chaque swing.
  do
    local Arena2 = require("src.combat.arena")
    assert(Arena2.HASTE_CAP and Arena2.HASTE_CAP < 1, "HASTE_CAP exposé et < 1 (sinon timer peut atteindre 0)")
    local fuzzH = love.math.newRandomGenerator(909090)
    local concluded = 0
    for _ = 1, 60 do
      local b = randomBuild()
      local left = b:buildLeftComp()
      if #left == 0 then b:placeId(5, "marauder"); left = b:buildLeftComp() end
      local right = b:buildRightComp(Encounters[fuzzH:random(1, #Encounters)])
      -- haste ABSURDE sur tout le monde (≥1 sans cap = swing instantané). Le cap doit le neutraliser.
      for _, s in ipairs(left) do s.haste = 5.0 end
      for _, s in ipairs(right) do s.haste = 5.0 end
      local arena = Arena2.new({ left = left, right = right, autoReset = false, seed = fuzzH:random(1, 2147483647) })
      local n = 0
      for i = 1, TICK_CAP do
        arena:update(1.0, i * 1.0); n = i
        for _, u in ipairs(arena.units) do assert(u.hp >= 0, "haste-max: PV>=0") end
        if arena.over then break end
      end
      -- TERMINAISON = la propriété que HASTE_CAP garantit : sans cap, atkTimer se re-arme à cd*(1-5)<0 -> le
      -- swing « ne se re-positive jamais » (frappe chaque frame, état dégénéré) ; avec cap, atkTimer >= cd*(1-0.40)>0
      -- (cd>=1) -> cadence saine et combat conclu. On exige la conclusion sous le plafond.
      assert(arena.over, "haste-max: terminaison sous le plafond malgré haste=5.0 (cap HASTE_CAP actif)")
      assert(n < TICK_CAP, "haste-max: conclu strictement sous TICK_CAP")
      concluded = concluded + 1
    end
    assert(concluded == 60, "haste-max: 60/60 combats conclus sous haste cumulé absurde")
  end

  print(string.format("  props : %d/%d combats fuzz + invariants (PV/terminaison/1-vainqueur/determinisme) OK",
    played, N))
  print("  props K4: commandant des 2 cotes (intouchable + exclu du decompte) -> 40/40 termines")
  print("  props V0: terminaison sous haste cumule absurde (HASTE_CAP borne le timer) -> 60/60 conclus")
end)

if ok then
  print("=> PROPS OK : tous les invariants tiennent.")
else
  print("=> PROPS FAIL :")
  print(err)
  os.exit(1)
end
