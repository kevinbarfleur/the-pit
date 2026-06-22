-- src/ui/keywords.lua
-- REGISTRE DES MOTS-CLÉS (source UNIQUE) — « à chaque fois qu'on voit cette affliction, on comprend que
-- c'est ça ». 1 affliction = 1 couleur + 1 icône bakée + 1 nom i18n + 1 phrase. Consommé par les chips
-- (src/ui/chip.lua), la carte monstre, le codex et plus tard les reliques : ils parlent tous le même langage.
--
-- DÉCOUPLÉ de la couche combat (render/healthbar a sa propre rangée d'icônes) MAIS partage les MÊMES
-- GRILLES (src/render/affliction_icons.lua, data-only) -> identité visuelle garantie identique, zéro risque
-- de toucher le rendu de combat. Couleurs alignées sur la palette (Theme.c) et le `hi` jaune de la brûlure.
--
-- PUR au require (aucun love.* exécuté) : le registre, op->clé et applied(unit) sont testables headless.
-- Le bake d'icône est LAZY (mémoïsé) et no-op sans love.graphics (renvoie nil proprement).

local Theme = require("src.ui.theme")
local Sprite = require("src.core.sprite")
local GRIDS = require("src.render.affliction_icons") -- DATA-ONLY (pas de love au require)
local I18n = require("src.core.i18n")
local C = Theme.c

local Keywords = {}

-- Descripteurs d'AFFLICTIONS. color/hi alignés sur render/healthbar (même teinte = même affliction partout).
Keywords.afflictions = {
  poison = { key = "poison", color = C.poison, name = "kw.poison.name", blurb = "kw.poison.blurb" },
  bleed  = { key = "bleed",  color = C.bleed,  name = "kw.bleed.name",  blurb = "kw.bleed.blurb" },
  burn   = { key = "burn",   color = C.burn, hi = Theme.hex(0xf7d048), name = "kw.burn.name", blurb = "kw.burn.blurb" },
  rot    = { key = "rot",    color = C.rot,    name = "kw.rot.name",    blurb = "kw.rot.blurb" },
  shock  = { key = "shock",  color = C.shock,  name = "kw.shock.name",  blurb = "kw.shock.blurb" },
}
-- Ordre canonique (stabilité visuelle des rangées de chips, calqué sur l'ordre de la barre de vie).
Keywords.order = { "poison", "bleed", "burn", "rot", "shock" }

-- Quelles OPS (descripteurs d'effets, src/effects/ops.lua) posent quelle affliction. Défensif : une op
-- inconnue (ex. ajoutée par un autre chantier) -> nil -> simplement aucun chip, jamais de crash.
local OP_AFFLICTION = {
  poison = "poison", bleed = "bleed", burn = "burn", rot = "rot", shock = "shock",
  aura_grant_bleed = "bleed",
  spread_burn_on_death = "burn",
  spread_rot = "rot", convert_to_rot = "rot",
}

function Keywords.get(key) return Keywords.afflictions[key] end
function Keywords.opAffliction(op) return op and OP_AFFLICTION[op] or nil end

-- Nom/phrase d'un mot-clé via i18n (fallback : clé en capitales / chaîne vide).
function Keywords.name(key)
  local a = Keywords.afflictions[key]
  return a and I18n.t(a.name) or (key and key:upper()) or ""
end
function Keywords.blurb(key)
  local a = Keywords.afflictions[key]
  return a and I18n.t(a.blurb) or ""
end

-- Liste ORDONNÉE (ordre canonique, dédupliquée) des afflictions qu'une unité APPLIQUE, lue de ses `effects`.
-- Sert à composer la rangée de chips d'une carte monstre (« quelles afflictions fait ce monstre »).
function Keywords.applied(unit)
  local seen = {}
  local effects = unit and unit.effects
  if effects then
    for _, e in ipairs(effects) do
      local k = e.op and OP_AFFLICTION[e.op]
      if k then seen[k] = true end
    end
  end
  local out = {}
  for _, k in ipairs(Keywords.order) do
    if seen[k] then out[#out + 1] = k end
  end
  return out
end

-- ── Bake d'icône (lazy, mémoïsé) : teinte la grille abstraite (o/d/m/h) par la couleur de la famille ──
-- Même logique que render/healthbar (shade), mais cache séparé (découplage). Renvoie { image, w, h } | nil.
local function shade(c, f)
  if f <= 1 then return { c[1] * f, c[2] * f, c[3] * f, 1 } end
  local t = f - 1
  return { c[1] + (1 - c[1]) * t, c[2] + (1 - c[2]) * t, c[3] + (1 - c[3]) * t, 1 }
end

local iconCache = {} -- [key] = { image, w, h } | false (échec/headless : on ne réessaie pas)
function Keywords.icon(key)
  local cached = iconCache[key]
  if cached ~= nil then return cached or nil end
  local a = Keywords.afflictions[key]
  local grid = a and GRIDS[key]
  if not grid or not (love and love.graphics and love.image) then
    iconCache[key] = false
    return nil
  end
  local pal = {
    o = shade(a.color, 0.30),
    d = shade(a.color, 0.60),
    m = a.color,
    h = a.hi or shade(a.color, 1.60),
  }
  local ok, baked = pcall(Sprite.bake, grid, pal)
  iconCache[key] = (ok and baked) or false
  return (ok and baked) or nil
end

return Keywords
