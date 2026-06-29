-- tests/export_scenes.lua
-- Garde-fou headless pour les scenes capturables par `love . --shoot=<name>`.
-- Le rendu visuel reste valide par captures reelles, mais la liste publique doit
-- toujours pointer vers des builders existants et couvrir les familles de boss.
--   Lancement : luajit tests/export_scenes.lua
package.path = "./?.lua;" .. package.path
love = require("tests.mock_love")

local ExportScenes = require("src.core.export_scenes")
local Abominations = require("src.data.abominations")
local RunEvents = require("src.data.run_events")

local ok, err = pcall(function()
  assert(type(ExportScenes.names) == "table" and #ExportScenes.names > 0, "liste de scenes exportables manquante")

  local seen = {}
  for i, name in ipairs(ExportScenes.names) do
    assert(type(name) == "string" and name ~= "", "nom de scene invalide a l'index " .. tostring(i))
    assert(not seen[name], "nom de scene duplique: " .. name)
    seen[name] = true
    assert(type(ExportScenes.builder(name)) == "function", "builder manquant pour --shoot=" .. name)
  end

  for _, name in ipairs({
    "runevent_brood",
    "runevent_economy",
    "runevent_shop_tier",
    "runevent_unit_glossary",
    "build_aura_hover",
    "build_aura_network_focus",
    "build_aura_network_all",
    "combat_network_focus",
    "combat_network_all",
    "combat_impacts",
    "playground",
    "playground_boss",
  }) do
    assert(seen[name], "scene de regression visuelle attendue absente: " .. name)
  end

  assert(seen.bossrush, "scene bossrush par defaut absente")
  for _, key in ipairs(Abominations.order) do
    local scene = "bossrush_" .. key
    assert(seen[scene], "export bossrush manquant pour abomination: " .. key)
  end

  local brood = RunEvents.events and RunEvents.events.sealed_brood
  assert(brood and brood.choices and brood.choices[2], "event sealed_brood attendu pour la capture unit glossary")
  assert(brood.choices[2].reward and brood.choices[2].reward.kind == "unit",
    "runevent_unit_glossary doit survoler un reward creature")
  assert(brood.choices[2].reward.level == 2,
    "runevent_unit_glossary doit couvrir une creature deja niveau 2")
end)

if not ok then
  io.stderr:write("EXPORT-SCENES TEST FAIL: " .. tostring(err) .. "\n")
  os.exit(1)
end

print("=> EXPORT-SCENES OK : noms uniques + builders + run-event/bossrush coverage.")
