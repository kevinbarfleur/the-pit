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
local GRIDS = require("src.render.tag_icons") -- DATA-ONLY (pas de love au require)
local I18n = require("src.core.i18n")
local Tags = require("src.core.tags")
local C = Theme.c

local Keywords = {}

-- Descripteurs d'AFFLICTIONS. color/hi alignés sur render/healthbar (même teinte = même affliction partout).
Keywords.afflictions = {
  poison = { key = "poison", color = C.poison, name = "kw.poison.name", blurb = "kw.poison.blurb", category = "affliction", icon = "poison" },
  bleed  = { key = "bleed",  color = C.bleed,  name = "kw.bleed.name",  blurb = "kw.bleed.blurb",  category = "affliction", icon = "bleed" },
  burn   = { key = "burn",   color = C.burn, hi = Theme.hex(0xf7d048), name = "kw.burn.name", blurb = "kw.burn.blurb", category = "affliction", icon = "burn" },
  rot    = { key = "rot",    color = C.rot,    name = "kw.rot.name",    blurb = "kw.rot.blurb",    category = "affliction", icon = "rot" },
  shock  = { key = "shock",  color = C.shock,  name = "kw.shock.name",  blurb = "kw.shock.blurb",  category = "affliction", icon = "shock" },
}
-- Ordre canonique (stabilité visuelle des rangées de chips, calqué sur l'ordre de la barre de vie).
Keywords.order = { "poison", "bleed", "burn", "rot", "shock" }
Keywords.categoryOrder = Tags.categoryOrder

Keywords.tags = {}
for _, k in ipairs(Keywords.order) do Keywords.tags[k] = Keywords.afflictions[k] end

local function tag(id, color, category, icon)
  Keywords.tags[id] = {
    key = id,
    color = color,
    name = "kw." .. id .. ".name",
    blurb = "kw." .. id .. ".blurb",
    category = category,
    icon = icon or id,
  }
end

tag("contagion", C.rot, "affliction", "poison")
tag("propagation", C.burn, "affliction", "burn")
tag("conversion", C.ink, "affliction", "mimicry")
tag("aggravate", C.bleed, "affliction", "bleed")

tag("shield", C.shield, "defense")
tag("heal", C.regen, "defense")
tag("regen", C.regen, "defense")
tag("thorns", C.steel, "defense")
tag("taunt", C.gold, "defense")
tag("guard", C.shield, "defense")

tag("empower", C.dmg, "offense")
tag("growth", C.gold, "offense")
tag("execute", C.blood, "offense")
tag("crit", C.bloodL, "offense")
tag("cleave", C.blood, "offense")
tag("strip_shield", C.steel, "offense")
tag("vulnerable", C.ember, "offense")
tag("weaken", C.poison, "offense")

tag("aura", C.gold, "structural")
tag("commander", C.brassS, "structural")
tag("whisper", C.ink3, "structural")
tag("multicast", C.echo, "structural")
tag("haste", C.haste, "structural")

tag("ahead", C.ember, "direction")
tag("behind", C.shield, "direction")
tag("above", C.haste, "direction")
tag("below", C.bleed, "direction")

tag("summon", Theme.types.arcane.color, "newaxis")
tag("faint", C.rot, "newaxis")
tag("mimicry", Theme.types.arcane.color, "newaxis")

tag("type", C.ink3, "type")
for _, ty in ipairs({ "flesh", "bone", "arcane", "abyss", "order" }) do
  local t = Theme.type(ty)
  Keywords.tags["type_" .. ty] = {
    key = "type_" .. ty,
    color = t.color,
    name = "kw.type_" .. ty .. ".name",
    blurb = "kw.type_" .. ty .. ".blurb",
    category = "type",
    icon = "type",
    pip = t.pip,
  }
end

-- Quelles OPS (descripteurs d'effets, src/effects/ops.lua) posent quelle affliction. Défensif : une op
-- inconnue (ex. ajoutée par un autre chantier) -> nil -> simplement aucun chip, jamais de crash.
local OP_AFFLICTION = {
  poison = "poison", bleed = "bleed", burn = "burn", rot = "rot", shock = "shock",
  aura_grant_bleed = "bleed",
  spread_burn_on_death = "burn",
  spread_rot = "rot", convert_to_rot = "rot",
}

function Keywords.get(key) return Keywords.tags[key] or Keywords.afflictions[key] end
function Keywords.tag(key) return key and Keywords.tags[key] or nil end
function Keywords.opAffliction(op) return op and OP_AFFLICTION[op] or nil end

-- Nom/phrase d'un mot-clé via i18n (fallback : clé en capitales / chaîne vide).
function Keywords.tagName(key)
  local a = Keywords.tag(key)
  return a and I18n.t(a.name) or (key and key:upper()) or ""
end
function Keywords.tagBlurb(key)
  local a = Keywords.tag(key)
  return a and I18n.t(a.blurb) or ""
end
function Keywords.tagColor(key)
  local a = Keywords.tag(key)
  return (a and a.color) or C.muted
end
Keywords.PRISMATIC_TAGS = { conversion = true }
Keywords.PRISMATIC_PALETTE = { C.burn, C.shock, C.poison, C.shield, C.bleed, C.gold }
function Keywords.isPrismatic(key) return key and Keywords.PRISMATIC_TAGS[key] == true end
function Keywords.prismaticColor(key, i, t)
  local pal = Keywords.PRISMATIC_PALETTE
  if not Keywords.isPrismatic(key) then return Keywords.tagColor(key) end
  local phase = math.floor(((t or 0) * 2) % #pal)
  return pal[((i + phase - 1) % #pal) + 1]
end
function Keywords.name(key) return Keywords.tagName(key) end
function Keywords.blurb(key) return Keywords.tagBlurb(key) end
function Keywords.tagsForUnit(unitOrId, opts) return Tags.forUnit(unitOrId, opts) end
function Keywords.tagsForRelic(relicOrId, opts) return Tags.forRelic(relicOrId, opts) end

-- Liste ORDONNÉE (ordre canonique, dédupliquée) des afflictions qu'une unité APPLIQUE, lue de ses `effects`.
-- Sert à composer la rangée de chips d'une carte monstre (« quelles afflictions fait ce monstre »).
function Keywords.applied(unit) return Tags.afflictionsForUnit(unit) end

function Keywords.plainText(line)
  return tostring(line or ""):gsub("%[([^%]]+)%]", function(inner)
    local id, label = inner:match("^([%w_]+)|(.+)$")
    id = id or inner
    if Keywords.tag(id) then return label or Keywords.tagName(id) end
    return "[" .. inner .. "]"
  end)
end

local function activeSet(activeTags)
  if not activeTags then return nil end
  local set = {}
  if activeTags[1] ~= nil then
    for _, id in ipairs(activeTags) do set[id] = true end
  else
    for id, v in pairs(activeTags) do if v then set[id] = true end end
  end
  return set
end

local function autoTagForWord(word, active)
  if not active then return nil end
  local core = tostring(word or ""):lower():gsub("^['\"%(%)%[%]{},;:%.!%?]+", ""):gsub("['\"%(%)%[%]{},;:%.!%?]+$", "")
  core = core:gsub("'s$", "")
  if core == "" then return nil end
  for _, id in ipairs(Tags.order) do
    if active[id] then
      local d = Keywords.tag(id)
      if d then
        local name = I18n.t(d.name):lower()
        if name == core or id == core then return id end
      end
    end
  end
  return nil
end

local function appendAutoRuns(out, text, baseCol, active)
  text = tostring(text or "")
  if not active then
    out[#out + 1] = { text = text, color = baseCol }
    return
  end
  local any = false
  for lead, word in text:gmatch("(%s*)(%S+)") do
    any = true
    if lead ~= "" then out[#out + 1] = { text = lead, color = baseCol } end
    local id = autoTagForWord(word, active)
    out[#out + 1] = { text = word, color = id and Keywords.tagColor(id) or baseCol, tag = id }
  end
  local trail = any and text:match("(%s+)$") or nil
  if trail then out[#out + 1] = { text = trail, color = baseCol } end
  if not any and text ~= "" then
    out[#out + 1] = { text = text, color = baseCol }
  end
end

function Keywords.inlineRuns(line, baseCol, activeTags)
  line = tostring(line or "")
  local active = activeSet(activeTags)
  local out, pos = {}, 1
  while true do
    local s, e, inner = line:find("%[([^%]]+)%]", pos)
    if not s then break end
    if s > pos then appendAutoRuns(out, line:sub(pos, s - 1), baseCol, active) end
    local id, label = inner:match("^([%w_]+)|(.+)$")
    id = id or inner
    if Keywords.tag(id) and (not active or active[id]) then
      out[#out + 1] = { text = label or Keywords.tagName(id), color = Keywords.tagColor(id), tag = id }
    elseif Keywords.tag(id) then
      out[#out + 1] = { text = label or Keywords.tagName(id), color = baseCol }
    else
      out[#out + 1] = { text = "[" .. inner .. "]", color = baseCol }
    end
    pos = e + 1
  end
  if pos <= #line then appendAutoRuns(out, line:sub(pos), baseCol, active) end
  if #out == 0 then out[1] = { text = line, color = baseCol } end
  return out
end

local function inlineRunWidth(run, font)
  local text = run.text or ""
  local w = font:getWidth(text)
  if text:match("^%s+$") then w = math.max(w, #text * 4) end
  if run.tag then
    local ic = Keywords.icon(run.tag)
    if ic then w = w + ic.w + 2 end
  end
  return w
end

function Keywords.inlineWidth(line, font, activeTags)
  local w = 0
  for _, run in ipairs(Keywords.inlineRuns(line, { 1, 1, 1, 1 }, activeTags)) do
    w = w + inlineRunWidth(run, font)
  end
  return w
end

function Keywords.wrapInline(line, font, maxW, activeTags)
  line = tostring(line or "")
  if not font or not maxW or maxW <= 0 then return { line } end
  local out, cur = {}, ""
  for word, sp in line:gmatch("(%S+)(%s*)") do
    local nextChunk = word .. sp
    local candidate = cur .. nextChunk
    if cur ~= "" and Keywords.inlineWidth(candidate, font, activeTags) > maxW then
      out[#out + 1] = cur:gsub("%s+$", "")
      cur = nextChunk
    else
      cur = candidate
    end
  end
  if cur ~= "" then out[#out + 1] = cur:gsub("%s+$", "") end
  if #out == 0 then out[1] = "" end
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
  local a = Keywords.tag(key)
  local iconKey = a and a.icon
  local grid = iconKey and GRIDS[iconKey]
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
