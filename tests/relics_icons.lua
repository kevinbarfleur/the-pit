-- tests/relics_icons.lua
-- Tests des ICÔNES DE RELIQUES (src/gen/relicgen.lua). Tourne headless (mock_love) : on valide les
-- GRILLES (strings) avant tout baking — comme tests/gen.lua pour les créatures. Garde check.sh vert.
--   Lancement : luajit tests/relics_icons.lua   (depuis la racine du projet)
--
-- Invariants vérifiés pour CHAQUE relique de RelicGen.order :
--   (a) grille EXACTEMENT 16×16 (largeur cohérente -> pas de pixel décalé),
--   (b) chaque caractère ∈ Palette (ou ' ' = transparent) : zéro pixel-trou,
--   (c) au moins un contour 'K' (silhouette lisible, jamais 0x000000 ailleurs),
--   (d) un « point de focus lumineux » présent (≥1 highlight : q/Q/T/W/S/I/B), signature « objet qui luit »,
--   (e) RelicGen.bake / cached produisent un objet {image,w,h} sous mock (smoke, sans crash ni écran),
--   (f) cache déterministe : .cached(id) renvoie deux fois la MÊME table.
package.path = "./?.lua;" .. package.path
love = require("tests.mock_love")

local Palette = require("src.core.palette")
local RelicGen = require("src.gen.relicgen")

local function fail(msg) print("=> RELIC-ICONS FAIL : " .. msg); os.exit(1) end

local SIZE = RelicGen.SIZE
-- Caractères « lumineux » admissibles comme focus (clairs de chaque famille). Au moins UN par icône.
local FOCUS = { q = true, Q = true, T = true, W = true, S = true, I = true, B = true, z = true }

-- 1. Toutes les icônes de l'ordre existent + structure valide.
do
  local count = 0
  for _, id in ipairs(RelicGen.order) do
    local g = RelicGen.grid(id)
    if not g then fail(id .. " : grille absente (présente dans .order mais pas dans ICONS)") end

    -- (a) 16 lignes de 16 colonnes exactement.
    if #g ~= SIZE then fail(id .. " : " .. #g .. " lignes (attendu " .. SIZE .. ")") end
    for y = 1, #g do
      if #g[y] ~= SIZE then
        fail(id .. " : ligne " .. y .. " fait " .. #g[y] .. " colonnes (attendu " .. SIZE .. ")")
      end
    end

    -- (b)(c)(d) palette + contour + focus, en un seul passage.
    local hasOutline, hasFocus, hasPixel = false, false, false
    for y = 1, #g do
      local row = g[y]
      for x = 1, #row do
        local ch = row:sub(x, x)
        if ch ~= " " then
          if not Palette[ch] then
            fail(id .. " : char '" .. ch .. "' (l" .. y .. " c" .. x .. ") hors palette (pixel-trou)")
          end
          hasPixel = true
          if ch == "K" then hasOutline = true end
          if FOCUS[ch] then hasFocus = true end
        end
      end
    end
    if not hasPixel then fail(id .. " : icône totalement transparente") end
    if not hasOutline then fail(id .. " : aucun contour 'K' (silhouette illisible)") end
    if not hasFocus then fail(id .. " : aucun point de focus lumineux (objet sans éclat)") end

    count = count + 1
  end
  print("  structure : OK (" .. count .. " icônes : 16x16 + palette + contour + focus lumineux)")
end

-- 2. Bake (smoke) : Sprite.bake via RelicGen.bake produit {image,w,h} sans crash (mock LÖVE).
do
  for _, id in ipairs(RelicGen.order) do
    local baked = RelicGen.bake(id, Palette)
    if not baked or not baked.image then fail(id .. " : bake a renvoyé nil/sans image") end
    if baked.w ~= SIZE or baked.h ~= SIZE then
      fail(id .. " : bake dimensions " .. tostring(baked.w) .. "x" .. tostring(baked.h) .. " (attendu " .. SIZE .. ")")
    end
  end
  print("  bake : OK (12 icônes bakées sous mock, dimensions 16x16)")
end

-- 3. Cache déterministe : .cached(id) renvoie deux fois la même table (mémoïsation par id).
do
  local a = RelicGen.cached("bloodstone", Palette)
  local b = RelicGen.cached("bloodstone", Palette)
  if a ~= b then fail("cache : .cached('bloodstone') renvoie deux objets différents") end
  if RelicGen.grid("does_not_exist") ~= nil then fail("grid(id inconnu) devrait être nil") end
  if RelicGen.bake("does_not_exist", Palette) ~= nil then fail("bake(id inconnu) devrait être nil") end
  print("  cache : OK (mémoïsation par id + id inconnu -> nil)")
end

print("=> RELIC-ICONS OK.")
