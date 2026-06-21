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
local Match = require("src.combat.match")
local Encounters = require("src.data.encounters")
local EventLog = require("tools.eventlog")

local SEED = 424242
local EXPECTED = 537920171 -- empreinte de référence (regénérer si changement VOULU ; maj : P6 aggro activée -> ciblage par aggro)

local ok, err = pcall(function()
  -- Scénario canonique : carré 9 slots, 5 unités placées, encounter #2.
  local b = Build.new(Palette, 320, 180, { goto = function() end })
  b.board:setShape("carre"); b:computeLayout(); b.board:unlock(9)
  b:placeId(5, "templar"); b:placeId(4, "marauder"); b:placeId(6, "skeleton")
  b:placeId(2, "witch"); b:placeId(8, "demon")
  local left, right = b:buildLeftComp(), b:buildRightComp(Encounters[2])

  -- Combat via le runner partagé (même boucle exacte qu'avant -> empreinte inchangée). L'event-log est
  -- attaché APRÈS Arena.new (comme à l'origine) via le closure, puis renvoyé par expose.
  local res = Match.run(left, right, SEED, {
    tickCap = 8000,
    attach = function(a) return EventLog.attach(a, { seed = SEED }) end,
    expose = true,
  })
  local log = res.log
  local fp = log:fingerprint()

  -- GARDE Fatigue : le golden DOIT conclure avant le seuil d'usure, sinon la Fatigue influencerait
  -- l'empreinte et celle-ci ne serait plus « golden-safe ». Si ce scénario venait à dépasser le seuil,
  -- c'est un changement à valider explicitement (revoir le scénario OU rebaseliner sciemment).
  assert(res.ticks < Arena.FATIGUE_START,
    string.format("golden doit conclure avant le seuil de Fatigue (%d) : conclu a %d", Arena.FATIGUE_START, res.ticks))

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
