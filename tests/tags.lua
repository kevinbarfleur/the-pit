-- tests/tags.lua
-- Pure mechanic-tag derivation. The tag system is read-only metadata: it must
-- not touch combat state, but every roster unit should expose a stable set of
-- explainable keywords for the UI glossary/wiki.
package.path = "./?.lua;" .. package.path
love = require("tests.mock_love")

local Tags = require("src.core.tags")
local Units = require("src.data.units")
local Whispers = require("src.data.whispers")
local I18n = require("src.core.i18n")

local function has(list, id)
  for _, v in ipairs(list) do if v == id then return true end end
  return false
end

local function join(list) return table.concat(list, ",") end

local ok, err = pcall(function()
  -- Direct examples across the new axes and old mechanics.
  local plague = Tags.forUnit("plague_bearer")
  assert(has(plague, "poison") and has(plague, "contagion"), "poison spread -> poison + contagion")
  assert(has(plague, "type_" .. Units.plague_bearer.type), "unit type tag")

  local cocoon = Tags.forUnit("brood_mother")
  assert(has(cocoon, "summon") and has(cocoon, "faint"), "on_death summon -> summon + faint")

  local plaguePyre = Tags.forUnit("plague_pyre")
  assert(has(plaguePyre, "propagation") and has(plaguePyre, "burn") and has(plaguePyre, "poison"),
    "death spread -> propagation + afflictions")
  assert(not has(plaguePyre, "faint"), "enemy-death propagation is not self-death/faint")

  local scavenger = Tags.forUnit("bone_harvest")
  assert(has(scavenger, "growth") and not has(scavenger, "faint"),
    "ally-death scavenge -> growth, not self-death/faint")

  local echo = Tags.forUnit("echo_flesh")
  assert(has(echo, "mimicry"), "repeat_ability -> mimicry")

  local pos = Tags.forUnit("vanguard_drummer")
  assert(has(pos, "behind") and has(pos, "aura"), "directional aura -> behind + aura")

  local wall = Tags.forUnit("wallbreaker")
  assert(has(wall, "strip_shield") and has(wall, "execute"), "wallbreaker -> strip + execute")

  local shield = Tags.forUnit("shieldbearer")
  assert(has(shield, "shield") and has(shield, "aura"), "shield aura -> shield + aura")

  local normalAbyss = Tags.forUnit("abyss_maw")
  assert(not has(normalAbyss, "commander"), "normal card hides commander tag")
  local commander = Tags.forUnit("abyss_maw", { context = "commander" })
  assert(has(commander, "commander") and has(commander, "type"), "command context -> commander + type target")

  local sporeNormal = Tags.forUnit("spore_tick")
  local sporeCommand = Tags.forUnit("spore_tick", { context = "commander" })
  assert(has(sporeNormal, "poison") and not has(sporeNormal, "haste"), "normal spore_tick -> poison, command haste hidden")
  assert(has(sporeCommand, "haste") and not has(sporeCommand, "poison") and not has(sporeCommand, "aura"),
    "commander spore_tick -> haste, board poison/aura hidden")

  -- Deterministic ordering: repeated derivation must be byte-identical.
  assert(join(Tags.forUnit("plague_bearer")) == join(Tags.forUnit("plague_bearer")), "forUnit deterministic")

  -- Roster coverage: every unit has a concrete type tag, and every declared op in unit data yields at least one tag.
  local untagged = {}
  for _, id in ipairs(Units.order) do
    local U = Units[id]
    local tags = Tags.forUnit(id)
    assert(has(tags, "type_" .. U.type), "type tag present: " .. id)
    for _, e in ipairs(U.effects or {}) do
      if #Tags.forEffect(e) == 0 then untagged[#untagged + 1] = id .. ":" .. tostring(e.op) end
    end
    if U.commandBonus and #Tags.forEffect(U.commandBonus, { commander = true }) == 0 then
      untagged[#untagged + 1] = id .. ":command:" .. tostring(U.commandBonus.op)
    end
  end
  assert(#untagged == 0, "ops sans tag : " .. table.concat(untagged, ", "))

  for id in pairs(Whispers) do
    assert(not has(Tags.forUnit(id), "whisper"), "whisper tag hidden by default: " .. id)
    assert(has(Tags.forUnit(id, { includeHidden = true }), "whisper"), "whisper tag available only to hidden/debug context: " .. id)
  end

  for _, id in ipairs(Tags.order) do
    assert(I18n.has("kw." .. id .. ".name"), "tag name i18n: " .. id)
    assert(I18n.has("kw." .. id .. ".blurb"), "tag blurb i18n: " .. id)
  end

  print(string.format("  tags : %d tags ordonnes / %d unites couvertes / ops roster mappees OK",
    #Tags.order, #Units.order))
end)

if ok then
  print("=> TAGS OK : derivation mecanique pure et glossary-ready.")
else
  print("=> TAGS FAIL :")
  print(err)
  os.exit(1)
end
