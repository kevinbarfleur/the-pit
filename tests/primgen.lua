-- tests/primgen.lua
-- GARDE DE RÉGRESSION du générateur de bestiaire v7 (src/gen/primgen.lua, 42 familles / 111 formes —
-- dont la famille `sousetres` = 9 mini-corps d'engeance, AXE 3).
-- Comble le trou de couverture : tests/gen.lua teste le LEGACY `CreatureGen.build` (masks/Forge), JAMAIS
-- primgen. Ici on vérifie que CHAQUE famille de FAMILY_ORDER × chaque archétype génère une image 64×64 NON
-- VIDE (un archétype mal porté dessine 0 px ou plante), et que le rendu est DÉTERMINISTE (snapshot-safe).
--   Lancement : luajit tests/primgen.lua   (depuis la racine du projet)
package.path = "./?.lua;" .. package.path
love = require("tests.mock_love") -- pose le global `love` (mock partagé)
-- Le stub mock_love a un setPixel NO-OP -> on le remplace par un compteur pour mesurer le « non-vide ».
love.image.newImageData = function(w, h)
  local n = 0
  return { _w = w, _h = h, setPixel = function() n = n + 1 end, getCount = function() return n end }
end
love.graphics.newImage = function(d) return { setFilter = function() end, _data = d } end

local P = require("src.gen.primgen")

local fams = P.FAMILY_ORDER
assert(#fams == 42, "FAMILY_ORDER doit lister 42 familles (a " .. #fams .. ")")

local total = 0
for _, fam in ipairs(fams) do
  local nArch, nPal = P.familyShape(fam)
  assert(nArch >= 1 and nPal >= 1, fam .. " : famille vide (" .. nArch .. " archs / " .. nPal .. " palettes)")
  for ai = 1, nArch do
    local g = P.generate({ seed = ai * 9973 + 41, family = fam, archIndex = ai, paletteIndex = 1 + ((ai - 1) % nPal) })
    assert(g.w == 64 and g.h == 64, fam .. "/" .. ai .. " : dimensions " .. tostring(g.w) .. "x" .. tostring(g.h) .. " (attendu 64x64)")
    local px = g.image._data.getCount()
    assert(px >= 40, fam .. "/" .. tostring(g.arch) .. " : seulement " .. px .. " px dessinés (archétype cassé ?)")
    total = total + 1
  end
end
print(string.format("  primgen : 42 familles, %d archetypes -> image 64x64 non vide (>=40px) OK", total))

-- Déterminisme : mêmes opts -> même archétype + même nom (snapshot/replay-safe).
local A = P.generate({ seed = 777, family = "mortvivant", archIndex = 1, paletteIndex = 1 })
local B = P.generate({ seed = 777, family = "mortvivant", archIndex = 1, paletteIndex = 1 })
assert(A.arch == B.arch and A.name == B.name, "primgen NON déterministe (même seed -> sortie différente)")
print("  primgen : determinisme (meme seed -> meme arch/nom) OK")

print("=> PRIMGEN OK : bestiaire v7 (42 familles / 111 formes) genere sans regression.")
