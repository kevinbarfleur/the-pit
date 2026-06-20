-- src/core/i18n.lua
-- INTERNATIONALISATION (i18n) : toutes les chaînes AFFICHÉES passent par i18n.t(key, vars).
-- Le jeu est en ANGLAIS par défaut ; ajouter une langue = déposer un fichier `src/i18n/<code>.lua`
-- (table plate clé -> chaîne) — zéro autre changement. Les données (units/shapes/encounters) ne
-- portent QUE des clés/ids mécaniques ; le texte vit dans les locales.
--
-- Module PUR (aucun love.*) -> chargeable headless. Déterministe (lecture de tables, pas de pairs
-- dans un chemin sensible). Interpolation par marqueurs nommés {name} (réordonnables en traduction).
--
-- Usage :
--   local T = require("src.core.i18n").t
--   T("ui.fight")                         -> "FIGHT"
--   T("ui.cost", { n = 3 })               -> "3g"
--   require("src.core.i18n").setLocale("fr")  -- bascule (retombe sur "en" pour les clés absentes)

local I18n = {}
I18n.locale = "en"
I18n.fallback = "en"
I18n._locales = {} -- [code] = { [key] = string }

-- Charge une locale par require (mise en cache). Tolérant : une locale absente -> nil (fallback gère).
local function ensure(code)
  if I18n._locales[code] == nil then
    local ok, tbl = pcall(require, "src.i18n." .. code)
    I18n._locales[code] = (ok and type(tbl) == "table") and tbl or false
  end
  local v = I18n._locales[code]
  return v or nil
end

-- Enregistre une table de locale à la main (utile pour les tests).
function I18n.register(code, tbl) I18n._locales[code] = tbl end

function I18n.setLocale(code) ensure(code); I18n.locale = code end

-- Remplace {name}/{some_var} par vars[name]. Un marqueur sans valeur est laissé tel quel (visible).
local function interp(s, vars)
  if not vars then return s end
  return (s:gsub("{([%w_]+)}", function(k)
    local v = vars[k]
    return v ~= nil and tostring(v) or "{" .. k .. "}"
  end))
end

-- Traduit une clé. Locale courante -> fallback -> la clé elle-même (clé manquante VISIBLE = détectable).
function I18n.t(key, vars)
  local loc = ensure(I18n.locale)
  local s = loc and loc[key]
  if s == nil and I18n.locale ~= I18n.fallback then
    local fb = ensure(I18n.fallback)
    s = fb and fb[key]
  end
  if s == nil then return key end
  return interp(s, vars)
end

-- Vrai si la clé existe dans la locale courante OU le fallback (tests de couverture).
function I18n.has(key)
  local loc = ensure(I18n.locale)
  if loc and loc[key] ~= nil then return true end
  local fb = ensure(I18n.fallback)
  return fb ~= nil and fb[key] ~= nil
end

ensure("en") -- précharge la locale par défaut
return I18n
