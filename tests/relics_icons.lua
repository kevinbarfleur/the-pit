-- tests/relics_icons.lua
-- Tests du GÉNÉRATEUR VISUEL DES RELIQUES (src/gen/relicgen.lua, refonte 40×40 + moteur de motifs) et de
-- son RENDU ANIMÉ (src/render/relic_anim.lua). Tourne headless (mock_love) : on valide la GRILLE COLORÉE
-- (data pure) avant tout baking, puis le bake (smoke) et le chemin animé (no-op headless). Garde check.sh vert.
--   Lancement : luajit tests/relics_icons.lua   (depuis la racine du projet)
--
-- Invariants vérifiés pour CHAQUE relique de RelicGen.order :
--   (a) grille EXACTEMENT 40×40 (format { w, h, data }) — la taille du nouveau moteur,
--   (b) chaque pixel posé = une couleur { r, g, b } de 3 floats DANS [0,1] (zéro NaN, zéro hors-borne),
--   (c) silhouette DENSE (≥ 80 pixels posés) et NON triviale (pas un seul point) : un vrai objet,
--   (d) RelicGen.bake / cached produisent un { image, w, h } 40×40 sous mock (smoke, sans crash ni écran),
--   (e) cache déterministe : .cached(id) et .view(id) renvoient deux fois la MÊME table,
--   (f) RÉCONCILIATION : tout id de src/data/relics.lua est mappé (RelicGen.order == Relics.order, set),
--   (g) RelicAnim.draw ne CRASHE pas headless (mock sans newSpriteBatch -> no-op) sur tous les ids/t.
package.path = "./?.lua;" .. package.path
love = require("tests.mock_love")

local RelicGen = require("src.gen.relicgen")
local RelicAnim = require("src.render.relic_anim")
local Relics = require("src.data.relics")

local function fail(msg) print("=> RELIC-ICONS FAIL : " .. msg); os.exit(1) end

local SIZE = RelicGen.SIZE
if SIZE ~= 40 then fail("RelicGen.SIZE = " .. tostring(SIZE) .. " (attendu 40)") end

-- 1. Toutes les icônes de l'ordre existent + grille colorée valide (taille, couleurs, densité).
do
  local count, totalPix = 0, 0
  for _, id in ipairs(RelicGen.order) do
    local g = RelicGen.grid(id)
    if not g then fail(id .. " : grille absente (présente dans .order mais buildRelic a échoué)") end

    -- (a) format { w, h, data } 40×40.
    if g.w ~= SIZE or g.h ~= SIZE then fail(id .. " : grille " .. tostring(g.w) .. "x" .. tostring(g.h) .. " (attendu " .. SIZE .. "x" .. SIZE .. ")") end
    if type(g.data) ~= "table" then fail(id .. " : data n'est pas une table") end

    -- (b)(c) chaque pixel posé = { r, g, b } floats DANS [0,1] ; densité suffisante.
    local pix = 0
    for i = 1, g.w * g.h do
      local c = g.data[i]
      if c ~= nil then
        if type(c) ~= "table" or #c ~= 3 then fail(id .. " : pixel " .. i .. " n'est pas {r,g,b}") end
        for k = 1, 3 do
          local v = c[k]
          if type(v) ~= "number" or v ~= v then fail(id .. " : couleur NaN/non-nombre au pixel " .. i) end
          if v < 0 or v > 1 then fail(id .. " : couleur " .. v .. " hors [0,1] au pixel " .. i .. " (floats requis)") end
        end
        pix = pix + 1
      end
    end
    if pix < 80 then fail(id .. " : seulement " .. pix .. " pixels posés (silhouette trop pauvre, attendu >=80)") end
    totalPix = totalPix + pix
    count = count + 1
  end
  print("  structure : OK (" .. count .. " icônes : 40x40 + couleurs floats [0,1] + densité, " ..
    string.format("%.0f", totalPix / count) .. " px/icône en moyenne)")
end

-- 2. Bake (smoke) : RelicGen.bake produit { image, w, h } 40×40 sans crash (mock LÖVE).
do
  for _, id in ipairs(RelicGen.order) do
    local baked = RelicGen.bake(id)
    if not baked or not baked.image then fail(id .. " : bake a renvoyé nil/sans image") end
    if baked.w ~= SIZE or baked.h ~= SIZE then
      fail(id .. " : bake dimensions " .. tostring(baked.w) .. "x" .. tostring(baked.h) .. " (attendu " .. SIZE .. ")")
    end
  end
  print("  bake : OK (" .. #RelicGen.order .. " icônes bakées sous mock, dimensions 40x40)")
end

-- 3. Caches déterministes : .cached(id) et .view(id) renvoient deux fois la même table ; id inconnu -> nil.
do
  local a = RelicGen.cached("bloodstone")
  local b = RelicGen.cached("bloodstone")
  if a ~= b then fail("cache : .cached('bloodstone') renvoie deux objets différents") end
  local va = RelicGen.view("bloodstone")
  local vb = RelicGen.view("bloodstone")
  if va ~= vb then fail("cache : .view('bloodstone') renvoie deux objets différents") end
  if not (va.g and va.anim) then fail("view('bloodstone') doit porter g + anim") end
  if RelicGen.grid("does_not_exist") ~= nil then fail("grid(id inconnu) devrait être nil") end
  if RelicGen.bake("does_not_exist") ~= nil then fail("bake(id inconnu) devrait être nil") end
  print("  cache : OK (mémoïsation view/bake par id + id inconnu -> nil)")
end

-- 4. Intégrité de l'ORDRE (append-only) : aucun doublon + RÉCONCILIATION avec src/data/relics.lua.
--    Chaque id présent en jeu (Relics.order) DOIT avoir un visuel (présent dans RelicGen.order), et
--    inversement aucune icône orpheline (un id de RelicGen.order absent des données = jamais affiché).
do
  local seen = {}
  for _, id in ipairs(RelicGen.order) do
    if seen[id] then fail("order : id en double '" .. id .. "'") end
    seen[id] = true
  end
  local relset = {}
  for _, id in ipairs(Relics.order) do relset[id] = true end
  for _, id in ipairs(Relics.order) do
    if not seen[id] then fail("réconciliation : relique de données '" .. id .. "' SANS visuel (absente de RelicGen.order)") end
  end
  for _, id in ipairs(RelicGen.order) do
    if not relset[id] then fail("réconciliation : icône orpheline '" .. id .. "' (dans RelicGen.order mais pas dans Relics.order)") end
  end
  -- vagues récentes explicitement listées (verrou anti-régression).
  local mustHave = { "second_breath", "thornguard", "forked_tongue", "everburn", "plague_communion",
    "open_wounds", "blood_banner", "seers_mark", "splitting_maw" }
  for _, id in ipairs(mustHave) do
    if not seen[id] then fail("order : '" .. id .. "' livré mais absent de RelicGen.order") end
  end
  print("  ordre : OK (" .. #RelicGen.order .. " ids, sans doublon, réconcilié 1:1 avec Relics.order)")
end

-- 5. RENDU ANIMÉ headless-safe : RelicAnim.draw ne crashe pas (mock sans newSpriteBatch -> no-op).
do
  local n = 0
  for _, id in ipairs(RelicGen.order) do
    for _, t in ipairs({ 0, 0.37, 1.5, 3.14, 9.9 }) do
      RelicAnim.draw(nil, id, 100, 100, 3, t) -- no-op attendu (mock) ; on vérifie l'absence de crash
    end
    n = n + 1
  end
  RelicAnim.clear()
  print("  anim : OK (" .. n .. " icônes × 5 instants -> no-op headless sans crash)")
end

print("=> RELIC-ICONS OK.")
