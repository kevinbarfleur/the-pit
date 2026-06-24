-- tests/biome.lua
-- Tests du MOTEUR DE DÉCORS (src/fx/biome.lua) : module RENDER/fx HEADLESS-SAFE (mock LÖVE).
-- Couvre : construction de CHAQUE biome (no-crash), update+draw no-crash, fallback "inconnu" -> abysses,
-- et DÉTERMINISME (même (key,seed) -> même état de particules après N updates ; seed ≠ -> état ≠).
-- Pur RENDER (ne touche pas la SIM) -> golden inchangé par construction.
--   Lancement : luajit tests/biome.lua
package.path = "./?.lua;" .. package.path
love = require("tests.mock_love")

local Biome = require("src.fx.biome")

-- Empreinte de l'état des particules (positions) -> compare le déterminisme sans dépendre des objets.
local function partsFingerprint(b)
  local acc = {}
  for i, p in ipairs(b.particles) do
    -- arrondi stable (le mock RNG est déterministe ; on compare des nombres reproductibles).
    acc[i] = string.format("%.5f,%.5f", p.x, p.y)
  end
  return table.concat(acc, ";")
end

local function advance(b, n)
  for _ = 1, n do b:update(1 / 60) end
end

local ok, err = pcall(function()
  -- KEYS exposé, non vide, et chaque clé construit une instance.
  assert(type(Biome.KEYS) == "table" and #Biome.KEYS == 4, "Biome.KEYS = 4 biomes")
  for _, key in ipairs(Biome.KEYS) do
    local b = Biome.new(key, 1234)
    assert(b and b.key == key, "new(" .. key .. ") -> instance avec la bonne cle")
    assert(type(b.particles) == "table" and #b.particles > 0, key .. " : particules construites")
    assert(type(b.speeds) == "table" and b.speeds.sky == 0, key .. " : speeds present (sky=0)")
    assert(type(b.accent) == "table" and #b.accent == 3, key .. " : accent {r,g,b}")
    -- update + draw ne crashent pas sous mock LÖVE (no-op visuel, jamais d'erreur).
    advance(b, 5)
    b:draw(0, 0, 1280, 720)
    b:draw() -- valeurs par defaut (dx,dy,dw,dh) -> ne crashe pas non plus
  end

  -- Fallback : clé inconnue -> abysses (et nil -> abysses).
  assert(Biome.new("inconnu", 1).key == "abysses", "cle inconnue -> abysses")
  assert(Biome.new(nil, 1).key == "abysses", "cle nil -> abysses")

  -- DÉTERMINISME : même (key,seed) -> même nombre de particules + même état après N updates.
  do
    local a = Biome.new("brasier", 42)
    local b = Biome.new("brasier", 42)
    assert(#a.particles == #b.particles, "meme (key,seed) -> meme nb de particules")
    assert(partsFingerprint(a) == partsFingerprint(b), "meme (key,seed) -> meme etat initial")
    advance(a, 37); advance(b, 37)
    assert(partsFingerprint(a) == partsFingerprint(b), "meme (key,seed) -> meme etat apres N updates")
  end

  -- Sensibilité au seed : un autre seed change l'état (sinon le RNG ne serait pas branché).
  do
    local a = Biome.new("floraison", 1)
    local c = Biome.new("floraison", 2)
    assert(partsFingerprint(a) ~= partsFingerprint(c), "seed different -> etat different")
  end

  -- Wrap toroïdal des particules : après beaucoup d'updates, x reste dans [0,W] et y dans [-1,H+1].
  do
    local b = Biome.new("abysses", 7)
    advance(b, 600) -- ~10 s -> de quoi faire wrapper
    for _, p in ipairs(b.particles) do
      assert(p.x >= 0 and p.x <= 192, "particule x dans [0,W] apres wrap")
      assert(p.y >= -1 and p.y <= 109, "particule y dans [-1,H+1] apres wrap")
    end
  end

  print(string.format("  biome : %d biomes construits (no-crash) + update/draw + fallback + determinisme + wrap OK",
    #Biome.KEYS))
end)

if ok then
  print("=> BIOME OK : moteur de decors headless-safe, deterministe par (key,seed).")
else
  print("=> BIOME FAIL :")
  print(err)
  os.exit(1)
end
