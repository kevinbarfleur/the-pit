-- tests/auras.lua
-- AURAS d'adjacence (vague 2) : build-résolues via le GRAPHE du sigil (buildComp + board:neighbors),
-- comme shield_aura. On vérifie que poser une unité-aura À CÔTÉ d'une unité compatible BAKE bien le
-- bonus sur les EFFETS du voisin AVANT tout combat — et qu'une unité ISOLÉE garde ses effets de base
-- (effects = nil -> fallback -> golden inchangé). Déterministe (pur build, aucun RNG).
--   Lancement : luajit tests/auras.lua
package.path = "./?.lua;" .. package.path
love = require("tests.mock_love")

local Palette = require("src.core.palette")
local Build = require("src.scenes.build")

-- dps de la 1re brûlure trouvée dans les effets MATÉRIALISÉS d'une unité de la compo (nil si base).
local function burnDpsOf(comp, id)
  for _, s in ipairs(comp) do
    if s.id == id and s.effects then
      for _, e in ipairs(s.effects) do if e.op == "burn" then return e.params.dps end end
    end
  end
  return nil
end

local function fresh()
  local b = Build.new(Palette, 320, 180, { goto = function() end })
  b.board:setShape("carre"); b:computeLayout(); b.board:unlock(9)
  return b
end

local ok, err = pcall(function()
  -- 1) AURA ACTIVE (framework payoff) : soot_acolyte au centre, emberling sur un VRAI voisin -> burnInc
  -- (increased +0.50) baké sur l'UNITÉ (pas sur ses effets), lu à la POSE via Stats.resolve (cappé ×3).
  local Stats = require("src.effects.stats")
  local b = fresh()
  local center = 5
  local nb = b.board:neighbors(center)[1]
  assert(nb, "le centre a au moins un voisin dans le graphe")
  b:placeId(center, "soot_acolyte")
  b:placeId(nb, "emberling")
  local comp = b:buildComp(-1)
  local inc
  for _, s in ipairs(comp) do if s.id == "emberling" then inc = s.burnInc end end
  assert(inc and math.abs(inc - 0.5) < 1e-6, "aura: emberling recoit burnInc = 0.50 (obtenu " .. tostring(inc) .. ")")
  assert(Stats.resolve(6, { Stats.increased(inc) }, { max = 18, round = "nearest" }) == 9,
    "aura: pose renforcee 6 -> 9 dps (increased +50%, cappee x3)")

  -- 2) GRANT : clot_mender donne un bleed au voisin qui n'en avait pas (marauder = vanille).
  local b2 = fresh()
  local nb2 = b2.board:neighbors(center)[1]
  b2:placeId(center, "clot_mender")
  b2:placeId(nb2, "marauder")
  local comp2 = b2:buildComp(-1)
  local granted = false
  for _, s in ipairs(comp2) do
    if s.id == "marauder" and s.effects then
      for _, e in ipairs(s.effects) do if e.op == "bleed" then granted = true end end
    end
  end
  assert(granted, "aura grant: le voisin du clot_mender gagne un effet bleed")

  -- 3) ISOLÉ : sans aura adjacente, effects = nil (base, golden-safe ; aucune copie matérialisée).
  local b3 = fresh()
  b3:placeId(1, "emberling")
  local comp3 = b3:buildComp(-1)
  local iso
  for _, s in ipairs(comp3) do if s.id == "emberling" then iso = s end end
  assert(iso and iso.effects == nil and iso.burnInc == nil, "isolé: effects = nil ET burnInc = nil (base, golden inchangé)")

  print("  auras : ampli increased sur voisin (lu a la pose) / grant d'effet / isolé = base (golden-safe) OK")
end)

if ok then
  print("=> AURAS OK : auras d'adjacence build-resolues via le graphe du sigil.")
else
  print("=> AURAS FAIL :")
  print(err)
  os.exit(1)
end
