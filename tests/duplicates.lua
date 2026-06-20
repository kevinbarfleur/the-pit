-- tests/duplicates.lua
-- DUPLICATAS (étape gameplay #2) : 3 copies de MÊME id+niveau fusionnent en niveau+1 (cap 3) ; les
-- stats scalent (LEVEL_MULT) dans buildComp. On vérifie la fusion, le scaling, et la CASCADE
-- (9 copies -> niveau 3). Pur build (aucun RNG). Lancement : luajit tests/duplicates.lua
package.path = "./?.lua;" .. package.path
love = require("tests.mock_love")

local Palette = require("src.core.palette")
local Build = require("src.scenes.build")

local function fresh()
  local b = Build.new(Palette, 320, 180, { goto = function() end })
  b.board:setShape("carre"); b:computeLayout(); b.board:unlock(9)
  return b
end
local function countPlaced(b) local n = 0; for i = 1, 9 do if b.slotRigs[i] then n = n + 1 end end; return n end
local function findLevel(b, id)
  for i = 1, 9 do local sr = b.slotRigs[i]; if sr and sr.id == id then return sr.level end end
end

local ok, err = pcall(function()
  -- 1) FUSION : 3 copies (niveau 1) -> 1 unité niveau 2, 2 slots libérés.
  local b = fresh()
  b:placeId(1, "spore_tick"); b:placeId(2, "spore_tick"); b:placeId(3, "spore_tick")
  b:checkMerges()
  assert(countPlaced(b) == 1, "fusion: 3 copies -> 1 unite (obtenu " .. countPlaced(b) .. ")")
  assert(findLevel(b, "spore_tick") == 2, "fusion: la rescapee est niveau 2")

  -- 2) STATS scalées : buildComp applique LEVEL_MULT[2]=1.8 (hp 30->54, dmg 3->5).
  local comp = b:buildComp(-1)
  assert(#comp == 1, "1 unite dans la compo apres fusion")
  local u = comp[1]
  assert(u.level == 2 and u.hp == 54 and u.dmg == 5,
    ("stats niveau 2 : hp=%d dmg=%d (attendu 54/5)"):format(u.hp, u.dmg))

  -- 3) NIVEAU 1 = IDENTITÉ (golden-safe) : sans fusion, stats inchangées.
  local b1 = fresh(); b1:placeId(5, "marauder")
  local c1 = b1:buildComp(-1)
  assert(c1[1].hp == 60 and c1[1].dmg == 9 and (c1[1].level or 1) == 1, "niveau 1 = stats de base inchangees")

  -- 4) CASCADE : 9 copies niveau 1 -> 3 fusions -> 3 niveau-2 -> 1 fusion -> 1 niveau-3 (cap).
  local c = fresh()
  for i = 1, 9 do c:placeId(i, "bandit") end
  c:checkMerges()
  assert(countPlaced(c) == 1 and findLevel(c, "bandit") == 3,
    "cascade: 9 copies -> 1 niveau-3 (obtenu " .. countPlaced(c) .. " unite(s), niveau " .. tostring(findLevel(c, "bandit")) .. ")")

  print("  duplicatas : 3->niveau2 / stats scalees / niveau1=identite / cascade->niveau3 OK")
end)

if ok then
  print("=> DUPLICATAS OK : fusion 3-copies + scaling de niveau.")
else
  print("=> DUPLICATAS FAIL :")
  print(err)
  os.exit(1)
end
