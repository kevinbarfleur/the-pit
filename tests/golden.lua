-- tests/golden.lua
-- GOLDEN-LOG de régression : un scénario canonique FIGÉ + seed fixe produit un event-log
-- déterministe ; on compare son empreinte à une valeur de référence. Toute modification du
-- comportement de combat (timing, dégâts, effets) fera diverger l'empreinte -> on le voit
-- immédiatement. Si le changement est VOULU, mettre à jour EXPECTED. Lancement : luajit tests/golden.lua
package.path = "./?.lua;" .. package.path
love = require("tests.mock_love")

local Palette = require("src.core.palette")
local Build = require("src.scenes.build")
local Arena = require("src.combat.arena")
local Encounters = require("src.data.encounters")
local EventLog = require("tools.eventlog")

local SEED = 424242
local EXPECTED = 843214188 -- empreinte de référence (regénérer si changement VOULU ; maj : poison en N stacks + moteur de statuts)

local ok, err = pcall(function()
  -- Scénario canonique : carré 9 slots, 5 unités placées, encounter #2.
  local b = Build.new(Palette, 320, 180, { goto = function() end })
  b.board:setShape("carre"); b:computeLayout(); b.board:unlock(9)
  b:placeId(5, "templar"); b:placeId(4, "marauder"); b:placeId(6, "skeleton")
  b:placeId(2, "witch"); b:placeId(8, "demon")
  local left, right = b:buildLeftComp(), b:buildRightComp(Encounters[2])

  local arena = Arena.new({ left = left, right = right, autoReset = false, seed = SEED })
  local log = EventLog.attach(arena, { seed = SEED })
  for i = 1, 8000 do arena:update(1.0, i * 1.0); if arena.over then break end end
  local fp = log:fingerprint()

  if EXPECTED == nil then
    print("  golden : BASELINE etablie, empreinte = " .. fp .. "  -> coller dans EXPECTED")
  elseif fp == EXPECTED then
    print(string.format("  golden : empreinte stable (%d, %d evenements) -> aucune regression",
      fp, #log.records))
  else
    error(string.format("empreinte %d != attendu %d (regression OU changement a valider)", fp, EXPECTED))
  end
end)

if ok then
  print("=> GOLDEN OK.")
else
  print("=> GOLDEN FAIL : " .. tostring(err))
  os.exit(1)
end
