-- tests/forge.lua
-- THE FORGE (refonte du générateur, 2026-06) : générateur par ASSEMBLAGE DE PARTS AUTHORED.
-- Vérifie : (1) l'ATLAS est bien formé (pools non vides, parts {name,tags,grid}, RÔLES connus seulement —
-- un rôle non mappé serait silencieusement transparent) ; (2) DÉTERMINISME (même id -> même créature ;
-- ids différents -> distinctes) ; (3) COUVERTURE (chaque famille × body-plan produit les parts requises +
-- un rig non vide + bake réel sous mock) ; (4) outlineRole change la bordure (axe « bordures différentes »).
-- Lancement : luajit tests/forge.lua
package.path = "./?.lua;" .. package.path
love = require("tests.mock_love")

local Forge = require("src.gen.forge")
local Atlas = require("src.gen.atlas")
local Rig = require("src.core.rig")
local Palette = require("src.core.palette")

local POOLS = { "head", "torso", "arm", "legs", "weapon", "host" }
-- rôles que forge.lua sait recolorer (+ transparents). Un caractère hors set = rôle perdu au bake -> on le refuse.
local ROLES = { O = true, ["1"] = true, ["2"] = true, ["3"] = true, s = true, A = true, a = true, E = true, ["."] = true, [" "] = true }
local FAMILIES = { "flesh", "bone", "order", "arcane", "abyss" }
-- parts requises par body-plan (weapon optionnelle ; arm -> armBack+armFront).
local NEED = {
  humanoid = { "head", "torso", "arm", "legs" },
  robe = { "head", "torso", "arm" },
  deformed = { "head", "torso", "arm", "legs" },
  blob = { "host" }, eye = { "host" },
}

local function flat(d)
  local s = {}
  for k, p in pairs(d.parts) do for _, r in ipairs(p.grid) do s[#s + 1] = k .. r end end
  table.sort(s); return table.concat(s, "|")
end

local ok, err = pcall(function()
  -- 1) ATLAS bien formé + rôles connus seulement.
  for _, pool in ipairs(POOLS) do
    assert(Atlas[pool] and #Atlas[pool] > 0, "pool '" .. pool .. "' non vide")
    for _, p in ipairs(Atlas[pool]) do
      assert(type(p.name) == "string" and type(p.tags) == "table" and type(p.grid) == "table", pool .. " : part {name,tags,grid}")
      for _, row in ipairs(p.grid) do
        assert(type(row) == "string", p.name .. " : grille = strings litterales")
        for x = 1, #row do
          local ch = row:sub(x, x)
          assert(ROLES[ch], p.name .. " : role inconnu '" .. ch .. "' (forge ne le recolore pas)")
        end
      end
    end
  end

  -- 2) DÉTERMINISME.
  local a1 = Forge.build({ id = "x", type = "flesh", bodyplan = "humanoid" })
  local a2 = Forge.build({ id = "x", type = "flesh", bodyplan = "humanoid" })
  assert(flat(a1) == flat(a2), "deterministe : meme id -> meme creature")
  local diff = false
  for i = 1, 8 do
    if flat(Forge.build({ id = "h" .. i, type = "flesh", bodyplan = "humanoid" })) ~= flat(a1) then diff = true; break end
  end
  assert(diff, "ids differents -> creatures distinctes")

  -- 3) COUVERTURE famille × body-plan : parts requises + rig + bake.
  for _, plan in ipairs({ "humanoid", "robe", "deformed", "blob", "eye" }) do
    for _, fam in ipairs(FAMILIES) do
      local d = Forge.build({ id = "cov_" .. plan .. "_" .. fam, type = fam, bodyplan = plan })
      assert(d.bodyplan == plan, plan .. " : bodyplan conserve")
      for _, slot in ipairs(NEED[plan]) do
        if slot == "arm" then
          assert(d.parts.armBack and d.parts.armFront, plan .. "/" .. fam .. " : bras (avant+arriere)")
        else
          assert(d.parts[slot], plan .. "/" .. fam .. " : " .. slot .. " present")
        end
      end
      assert(#d.rig > 0, plan .. "/" .. fam .. " : rig non vide")
      local ch = Rig.new(d, Palette); ch.facing = 1
      Rig.update(ch, 1, 1); Rig.trigger(ch, "attack"); Rig.update(ch, 2, 1); Rig.draw(ch)
    end
  end

  -- 3b) MULTI-MEMBRES + CHIMÈRES : build + rig non vide + bake (parts dynamiques -> on ne verifie pas les noms).
  for _, plan in ipairs({ "quadruped", "cephalopod", "serpent", "arachnid", "swarm" }) do
    for _, fam in ipairs(FAMILIES) do
      local d = Forge.build({ id = "m_" .. plan .. "_" .. fam, type = fam, bodyplan = plan })
      assert(d.bodyplan == plan and #d.rig > 0, plan .. "/" .. fam .. " : rig non vide")
      local ch = Rig.new(d, Palette); ch.facing = 1; Rig.update(ch, 1, 1); Rig.draw(ch)
    end
  end
  for _, chim in ipairs({ "chimera:humanoid:quadruped", "chimera:humanoid:tentacles",
    "chimera:cephalopod:quadruped", "chimera:cephalopod:tentacles" }) do
    local d = Forge.build({ id = "c_" .. chim, type = "abyss", bodyplan = chim })
    assert(#d.rig > 0, chim .. " : rig non vide")
    local ch = Rig.new(d, Palette); ch.facing = 1; Rig.update(ch, 1, 1); Rig.draw(ch)
  end
  -- couverture déclarée == réelle : Forge.supports() vrai pour tous les plans du roster.
  for _, plan in ipairs({ "humanoid", "robe", "deformed", "blob", "eye", "quadruped", "cephalopod",
    "serpent", "arachnid", "swarm", "chimera:humanoid:quadruped" }) do
    assert(Forge.supports(plan), "Forge.supports(" .. plan .. ")")
  end

  -- 4) RANG : echelle/glow varient avec rank (parite visuelle avec le legacy au rollout).
  local r1 = Forge.build({ id = "r", type = "flesh", bodyplan = "humanoid", rank = 1 })
  local r5 = Forge.build({ id = "r", type = "flesh", bodyplan = "humanoid", rank = 5 })
  assert(r5.scale > r1.scale, "rank 5 -> echelle plus grande")

  -- 5) outlineRole : la bordure change (axe « bordures differentes »).
  local base = Forge.build({ id = "b", type = "flesh", bodyplan = "humanoid" })
  local osb = Forge.build({ id = "b", type = "flesh", bodyplan = "humanoid", outlineRole = "F" })
  assert(table.concat(osb.parts.head.grid):find("F"), "outlineRole=F -> contour os present")
  assert(flat(base) ~= flat(osb), "outlineRole change le rendu")

  print("  forge : atlas + determinisme + couverture 5fam x (5 bipedes/host + 5 multi + 4 chimeres) + rang + outlineRole OK")
end)

if ok then
  print("=> FORGE OK : generateur par assemblage de parts authored.")
else
  print("=> FORGE FAIL :")
  print(err)
  os.exit(1)
end
