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
    local l, r = 0, 0
    for _, u in ipairs(arena.units) do
      if u.alive then if u.team == "left" then l = l + 1 else r = r + 1 end end
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
  print(string.format("  props : %d/%d combats fuzz + invariants (PV/terminaison/1-vainqueur/determinisme) OK",
    played, N))
end)

if ok then
  print("=> PROPS OK : tous les invariants tiennent.")
else
  print("=> PROPS FAIL :")
  print(err)
  os.exit(1)
end
