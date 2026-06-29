-- tests/i18n.lua
-- Tests de l'INTERNATIONALISATION (src/core/i18n.lua + src/i18n/en.lua) : module PUR, testable headless.
-- Couvre : locale par défaut, interpolation nommée, fallback, clé manquante, ET surtout la COUVERTURE
-- (toute clé d'affichage référencée par les DONNÉES — units/types/sigils/encounters — existe en anglais).
--   Lancement : luajit tests/i18n.lua
package.path = "./?.lua;" .. package.path
love = require("tests.mock_love")

local I18n = require("src.core.i18n")
local T = I18n.t
local Units = require("src.data.units")
local Shapes = require("src.board.shapes")
local Encounters = require("src.data.encounters")
local Relics = require("src.data.relics")
local Compositions = require("src.data.compositions")
local Whispers = require("src.data.whispers") -- MURMURES : chaque key active doit avoir sa ligne cryptique
local Keywords = require("src.ui.keywords")

local ok, err = pcall(function()
  -- Locale par défaut = anglais.
  assert(I18n.locale == "en", "locale par defaut = en")
  assert(T("ui.fight") == "FIGHT", "traduction simple")

  -- Interpolation par marqueurs nommés.
  assert(T("ui.cost", { n = 3 }) == "3g", "interpolation {n}")
  assert(T("ui.win_streak", { n = 4 }) == "WIN STREAK x4", "interpolation nommee")

  -- Clé manquante -> la clé elle-même (visible = détectable). Marqueur sans valeur -> conservé.
  assert(T("does.not.exist") == "does.not.exist", "cle manquante = cle")
  assert(T("ui.cost") == "{n}g", "marqueur sans valeur conserve")

  -- Fallback : une locale partielle retombe sur l'anglais pour les clés absentes.
  I18n.register("xx", { ["ui.fight"] = "ZZZ" })
  I18n.setLocale("xx")
  assert(T("ui.fight") == "ZZZ", "locale active prioritaire")
  assert(T("ui.reroll", { n = 1 }) == "REROLL 1g", "fallback en pour cle absente")
  assert(I18n.has("ui.fight") and I18n.has("ui.decline_slot"), "has() couvre locale + fallback")
  I18n.setLocale("en") -- restaure

  -- COUVERTURE : toute clé d'affichage dérivée des données existe en anglais (anti-trou de traduction).
  local missing = {}
  local function need(key) if not I18n.has(key) then missing[#missing + 1] = key end end
  for _, id in ipairs(Units.order) do
    need("unit." .. id .. ".name")
    need("unit." .. id .. ".passive_name")
    need("unit." .. id .. ".passive_desc")
    need("type." .. Units[id].type)
    if Units[id].commandBonus then -- COMMANDANTS (C2) : identité de chef + descripteur d'aura + flavor canon
      need("unit." .. id .. ".command_name")
      need("unit." .. id .. ".command_desc")
      need("unit." .. id .. ".command_flavor")
    end
  end
  for _, name in ipairs(Shapes.order) do
    need("shape." .. name .. ".label")
    need("shape." .. name .. ".archetype")
  end
  for _, enc in ipairs(Encounters) do need("encounter." .. enc.key .. ".name") end
  for _, id in ipairs(Relics.order) do -- reliques (modele lisible) : nom + effet clair + flavor
    need("relic." .. id .. ".name")
    need("relic." .. id .. ".effect")
    need("relic." .. id .. ".flavor")
  end
  -- MURMURES (3e couche cachee) : chaque key ACTIVE du registre a sa ligne cryptique (canal joueur). Le
  -- registre est indexe par id-porteur ; on couvre toutes les keys declarees (les murmures OFF/commentes
  -- comme the_coward ne sont pas dans le registre, donc non requis -- mais leur ligne existe deja pour W7).
  for _, list in pairs(Whispers) do
    for _, w in ipairs(list) do need("whisper." .. w.key .. ".cryptic") end
  end
  -- Banc d'essai (Proving Ground) : archetype/variant/note de chaque compo + labels/notes de scénarios.
  for _, comp in ipairs(Compositions.list) do
    need("pg.archetype." .. comp.archetype)
    need("pg.variant." .. comp.variant)
    need(comp.noteKey)
  end
  for _, sc in ipairs(Compositions.scenarios) do
    need("scenario." .. sc.id .. ".label")
    need("scenario." .. sc.id .. ".note")
  end
  for _, k in ipairs({ "pg.title", "pg.subtitle", "pg.vs", "pg.watch", "pg.sim", "pg.simming",
    "pg.winrate", "pg.decided", "pg.invest_delta", "pg.idle", "pg.watched", "pg.invest", "pg.gold", "pg.trials",
    "pg.boss_stats", "pg.boss_generals", "pg.boss_rule", "pg.boss_preview_hint", "pg.boss_score",
    "pg.boss_slain", "pg.boss_measured", "pg.boss_avg_score", "pg.boss_sim_line",
    "result.left", "result.right", "ui.hint_playground", "menu.proving", "encounter.exhibition.name" }) do
    need(k)
  end
  -- GRIMOIRE Pokédex : noms de TIER (caste affichée sur les chips de filtre tier + sous-label de case) +
  -- libellés de FACETTE de filtre (TYPE/TIER/BAND) + ALL. Tout texte affiché passe par i18n (anti-trou).
  for r = 1, 5 do need("tier." .. r .. ".name") end
  for _, k in ipairs({ "grimoire.filter_all", "grimoire.facet_type", "grimoire.facet_tier",
    "grimoire.facet_band", "grimoire.band_low", "grimoire.band_mid", "grimoire.band_high", "grimoire.hint" }) do
    need(k)
  end
  for id in pairs(Keywords.tags) do
    need("kw." .. id .. ".name")
    need("kw." .. id .. ".blurb")
  end
  for _, cat in ipairs(Keywords.categoryOrder) do need("kw.category." .. cat) end
  need("ui.keyword_hint")
  need("ui.keyword_title")

  assert(#missing == 0, "cles de traduction manquantes : " .. table.concat(missing, ", "))

  print(string.format("  i18n : en par defaut + interpolation + fallback ; couverture %d unites / %d sigils / %d encounters / %d reliques OK",
    #Units.order, #Shapes.order, #Encounters, #Relics.order))
end)

if ok then
  print("=> I18N OK : multilangue pret, couverture anglaise complete.")
else
  print("=> I18N FAIL :")
  print(err)
  os.exit(1)
end
