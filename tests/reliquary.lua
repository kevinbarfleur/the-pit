-- tests/reliquary.lua
-- LA BANDE GRAVÉE DU RELIQUAIRE (src/ui/reliquary.lua) : la bordure de pierre incisée se bake sans crash,
-- se mémoïse par taille, et reste HEADLESS-SAFE (no-op gracieux si love.image manque). RENDER pur -> golden
-- neutre. On exerce le chemin complet de gravure (bande + veines + perles de coin) sous le mock LÖVE.

love = require("tests.mock_love") -- SET le global love (le bake utilise love.image / love.math)
local Reliquary = require("src.ui.reliquary")

-- 1) bake + draw : aucun crash sur le chemin complet (bande 4 bords + 4 ruisseaux de veines + perles).
local ok, err = pcall(function()
  Reliquary.draw(0, 0, 1280, 720, { ft = 10 })   -- cadre plein écran (doc designer)
  Reliquary.draw(234, 82, 1016, 610, { ft = 8 }) -- cadre d'écran build (plus fin)
end)
assert(ok, "draw ne doit jamais crasher (headless-safe) : " .. tostring(err))

-- 2) mémoïsation : un 2e appel à la même taille NE recrée PAS d'entrée de cache.
local function cacheCount()
  local n = 0
  for _ in pairs(Reliquary._cache) do n = n + 1 end
  return n
end
local before = cacheCount()
Reliquary.draw(0, 0, 1280, 720, { ft = 10 }) -- même taille -> cache hit
assert(cacheCount() == before, "même taille -> pas de nouvelle entrée de cache (mémoïsé)")
assert(before >= 2, "au moins 2 tailles distinctes bakées (vu " .. before .. ")")

-- 3) inset : l'aire de contenu est strictement à l'intérieur de la bande.
local x, y, w, h = Reliquary.inset(0, 0, 1280, 720, { ft = 10 })
assert(x > 0 and y > 0 and w < 1280 and h < 720, "inset rentre le contenu dans le cadre")
assert(w == 1280 - 2 * x and h == 720 - 2 * y, "inset symétrique")

-- 4) PX exposé (cohérence du facteur d'échelle d'art).
assert(Reliquary.PX == 4, "PX = 4 (gros pixels nets, cohérent monde ×4)")

print("=> RELIQUARY OK : bande gravée bakée + mémoïsée + headless-safe + inset.")
