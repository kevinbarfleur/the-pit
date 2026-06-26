-- tests/effect_audit.lua
-- First semantic audit prototype: resolved effect facts, visible tags, command
-- context, hidden whisper leakage, and level-delta coverage.
package.path = "./?.lua;" .. package.path
love = require("tests.mock_love")

local Resolver = require("src.core.unit_resolver")
local Tags = require("src.core.tags")
local Units = require("src.data.units")
local Whispers = require("src.data.whispers")

local function has(list, id)
  for _, v in ipairs(list or {}) do if v == id then return true end end
  return false
end

local function addSet(set, list)
  for _, id in ipairs(list or {}) do set[id] = true end
end

local function starts(s, prefix)
  return tostring(s or ""):sub(1, #prefix) == prefix
end

local function assertNoWhisperLeak(id, tags)
  assert(not has(tags, "whisper"), "whisper tag leaked in public context: " .. id)
end

local ok, err = pcall(function()
  local factCount, levelAuthoredFacts = 0, 0
  local authoredUnits = {}

  for _, id in ipairs(Units.order) do
    local unit = Units[id]
    if Resolver.hasAuthoredLevel(id) then authoredUnits[id] = true end

    for level = 1, Resolver.MAX_LEVEL do
      local resolved = Resolver.unitForLevel(id, level)
      local tags = Tags.forUnit(resolved)
      assertNoWhisperLeak(id, tags)
      assert(has(tags, "type_" .. unit.type), "resolved unit keeps type tag: " .. id .. " L" .. level)
      assert(not has(tags, "commander"), "normal context hides command tag: " .. id .. " L" .. level)

      local backed = {}
      local facts = Resolver.effectFactsFor(id, level)
      for _, fact in ipairs(facts) do
        factCount = factCount + 1
        assert(fact.source == id and fact.level == level, "fact identity stable: " .. id)
        assert(fact.op and fact.trigger, "fact has op+trigger: " .. id)
        assert(#(fact.tags or {}) > 0, "public fact has at least one tag: " .. id .. ":" .. tostring(fact.op))
        addSet(backed, fact.tags)
        if fact.levelAuthored then levelAuthoredFacts = levelAuthoredFacts + 1 end

        if (fact.op == "poison" or fact.op == "bleed") and (fact.values.dps == 0 or fact.values.base == 0) then
          local utility = fact.values.weaken or fact.values.slowPct or fact.values.aggravateMult
          assert(utility, "0-dps affliction must carry utility wording hook: " .. id .. ":" .. fact.op)
        end
      end

      for _, tag in ipairs(tags) do
        local allowed = starts(tag, "type_") or tag == "taunt" or tag == "execute"
        assert(allowed or backed[tag], "visible tag without resolved fact: " .. id .. " L" .. level .. " tag=" .. tag)
      end

      if unit.commandBonus then
        local commandTags = Tags.forUnit(resolved, { context = "commander" })
        local commandFacts = Resolver.effectFactsFor(id, level, { context = "commander" })
        assert(has(commandTags, "commander"), "command context exposes commander tag: " .. id .. " L" .. level)
        assert(#commandFacts == 1, "command context has one command fact: " .. id .. " L" .. level)
        assert(#(commandFacts[1].tags or {}) > 0, "command fact has tags: " .. id)
        assertNoWhisperLeak(id, commandTags)
      end
    end
  end

  for id in pairs(authoredUnits) do
    local any = false
    for level = 2, Resolver.MAX_LEVEL do
      for _, fact in ipairs(Resolver.effectFactsFor(id, level, { includeCommand = true })) do
        if fact.levelAuthored then any = true end
      end
    end
    assert(any, "authored level unit exposes authored fact: " .. id)
  end

  for id in pairs(Whispers) do
    assertNoWhisperLeak(id, Tags.forUnit(id))
    assert(has(Tags.forUnit(id, { includeHidden = true }), "whisper"), "whisper tag available in hidden/debug context: " .. id)
  end

  assert(factCount > 0, "audit saw effect facts")
  assert(levelAuthoredFacts > 0, "audit saw authored level facts")

  print(string.format("  effect_audit : %d facts / authored level facts %d / public whisper leakage blocked OK",
    factCount, levelAuthoredFacts))
end)

if ok then
  print("=> EFFECT AUDIT OK : first semantic checks pass.")
else
  print("=> EFFECT AUDIT FAIL :")
  print(err)
  os.exit(1)
end
