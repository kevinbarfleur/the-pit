-- tests/commanders.lua
-- GARANTIE PERMANENTE « tout le monde commande » (Pass 2, command-auras-rollout-spec §3). Vérifie que CHAQUE
-- unité de Units.order porte un `commandBonus` BIEN FORMÉ (qui RÉSOUT contre le moteur Pass 1, jamais inerte) ET
-- les clés i18n que la fiche au survol consomme (`command_desc` surtout — monstercard.lua:240-242 affiche « AT
-- COMMAND » + l'aura ssi `commandBonus ~= nil` ET `I18n.has(command_desc)`). Empêche tout retour du « Cannot
-- command » de façon permanente (pas seulement au screenshot). Module PUR (mock LÖVE), golden-neutre.
--   Lancement : luajit tests/commanders.lua
package.path = "./?.lua;" .. package.path
love = require("tests.mock_love")

local U = require("src.data.units")
local I18n = require("src.core.i18n")

-- ── CONTRAT MOTEUR (Pass 1) — recopié du code lu : seules ces stats/cibles/flags RÉSOLVENT. Une aura qui en
--    sort est INERTE (le bandeau « At command » mentirait, spec §0.3). On garde ce contrat ICI pour piéger
--    toute dérive data (ex. un `stat` mal orthographié) ET pour documenter ce que le moteur sait lire.
-- aura_stat : whitelist STAT_FIELDS (build.lua:1170-1172) — agnostiques + amplis d'école (TROU #1) + focusWith.
local STAT_FIELDS = {
  haste = true, atkInc = true, dmgReduce = true, regen = true, multicast = true,
  lifesteal = true, statInc = true, focusWith = true,
  poisonInc = true, burnInc = true, bleedInc = true, rotInc = true,
}
-- aura_stat : whitelist target (build.lua:1184-1200, resolveTargets) — team/role:*/tier:N/level:N (neighbors = vide au piédestal).
local FIXED_TARGETS = { team = true, ["role:front"] = true, ["role:back"] = true, ["role:center"] = true }
local function targetResolves(t)
  if type(t) ~= "string" then return false end
  if FIXED_TARGETS[t] then return true end
  if t:sub(1, 5) == "tier:" and tonumber(t:sub(6)) then return true end
  if t:sub(1, 6) == "level:" and tonumber(t:sub(7)) then return true end
  return false
end
-- grant_team : flags RÉELLEMENT lus (ops.lua:281-305 handler + arena:spawn). Tout autre flag = inerte.
local GRANT_FLAGS = {
  burnNoDecay = true, poisonNoCap = true, poisonDurBonus = true, pierceHeal = true,
  invulnT = true, shockChain = true, bleedNoExpire = true, plagueAmp = true,
  stripEnemyShield = true, slowEnemies = true, rotEnemies = true, markEnemiesVuln = true,
}
-- Garde-fous de design gravés (spec §1.2) : interdits par construction (broken).
local function bannedCombo(stat, target)
  if stat == "multicast" and target == "team" then return "multicast target=team (broken, spec §1.2)" end
  if stat == "statInc" and target == "team" then return "statInc target=team (toujours conditionnel, spec §1.2)" end
  return nil
end

local ok, err = pcall(function()
  local nAura, nGrant = 0, 0
  local byStat = {}
  for _, id in ipairs(U.order) do
    local def = U[id]
    assert(def, "unite inconnue dans U.order : " .. tostring(id))
    local cb = def.commandBonus

    -- 1) ZÉRO « Cannot command » : chaque unité PORTE un commandBonus.
    assert(cb, "unite SANS commandBonus (afficherait « Cannot command ») : " .. id)
    assert(type(cb) == "table", "commandBonus n'est pas une table : " .. id)
    assert(cb.trigger == "combat_start", id .. " : commandBonus.trigger doit etre 'combat_start' (lu au piedestal), pas " .. tostring(cb.trigger))
    assert(type(cb.params) == "table", id .. " : commandBonus.params manquant")

    -- 2) L'aura RÉSOUT contre le moteur (jamais inerte -> jamais de fausse promesse, spec §0.3).
    if cb.op == "aura_stat" then
      nAura = nAura + 1
      local p = cb.params
      assert(STAT_FIELDS[p.stat], id .. " : stat hors whitelist STAT_FIELDS (inerte) : " .. tostring(p.stat))
      assert(targetResolves(cb.target), id .. " : target ne resout pas (inerte) : " .. tostring(cb.target))
      if p.stat ~= "focusWith" then
        assert(type(p.value) == "number", id .. " : aura_stat sans value numerique : " .. tostring(p.value))
      end
      local banned = bannedCombo(p.stat, cb.target)
      assert(not banned, id .. " : combo interdit -> " .. tostring(banned))
      byStat[p.stat] = (byStat[p.stat] or 0) + 1
    elseif cb.op == "grant_team" then
      nGrant = nGrant + 1
      local seen = false
      for flag, _ in pairs(cb.params) do
        assert(GRANT_FLAGS[flag], id .. " : grant_team flag inerte (non lu par le moteur) : " .. tostring(flag))
        seen = true
      end
      assert(seen, id .. " : grant_team sans aucun flag (inerte)")
      byStat["grant_team"] = (byStat["grant_team"] or 0) + 1
    else
      error(id .. " : commandBonus.op doit etre 'aura_stat' ou 'grant_team' (les seuls injectes au piedestal), pas " .. tostring(cb.op))
    end

    -- 3) La fiche au survol a de quoi afficher « AT COMMAND » + l'aura : `command_desc` PRÉSENT et NON-VIDE
    --    (monstercard.lua:242 exige I18n.has). + `command_name`/`command_flavor` (requis par tests/i18n.lua
    --    pour toute unite a commandBonus, et prevus par le systeme de carte).
    for _, suffix in ipairs({ "command_desc", "command_name", "command_flavor" }) do
      local key = "unit." .. id .. "." .. suffix
      assert(I18n.has(key), id .. " : cle i18n manquante -> " .. key)
      local txt = I18n.t(key)
      assert(type(txt) == "string" and #txt > 0 and txt ~= key, id .. " : " .. suffix .. " vide ou non resolue")
    end
  end

  -- 4) Compte total = tout le roster (la garantie « 100% commande »).
  assert(nAura + nGrant == #U.order,
    "couverture incomplete : " .. (nAura + nGrant) .. " commandBonus pour " .. #U.order .. " unites")

  -- distribution (informative — anti-monoculture, spec §1.2 : aucune stat ne devrait dominer)
  local parts = {}
  for stat, n in pairs(byStat) do parts[#parts + 1] = stat .. " " .. n end
  table.sort(parts)
  print(string.format("  commanders : %d/%d unites commandent (%d aura_stat / %d grant_team) ; aucune aura inerte",
    nAura + nGrant, #U.order, nAura, nGrant))
  print("  distribution : " .. table.concat(parts, "  "))
end)

if ok then
  print("=> COMMANDERS OK : tout le roster commande (aura resolue + i18n complete) -> zero « Cannot command ».")
else
  print("=> COMMANDERS FAIL :")
  print(err)
  os.exit(1)
end
