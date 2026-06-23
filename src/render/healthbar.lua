-- src/render/healthbar.lua
-- Barre de vie STYLISÉE (encadré runique) + lecture des AFFLICTIONS, dessinée dans l'OVERLAY (ESPACE
-- DESIGN, sous Draw.begin) à une grille FINE (scale entier ×2) au-dessus de chaque unité. Plus fine que la
-- grille ×4 chunky du monde -> finition d'UI ciselée (fini le « alpha »). Couche RENDER pure (love.graphics)
-- : lit l'état de la SIM en LECTURE SEULE (u.hp/maxHp/shield/dots), ne mute JAMAIS. cf. engine-architecture §4.
--
-- LECTURE DES DOTS (réf hack&slash / ARPG) : chaque altération « réserve » une portion de la VIE
-- COURANTE, colorée par sa famille (poison=vert, saignement=cramoisi, brûlure=braise, pourriture=violet).
-- La portion = les dégâts À VENIR (dps × temps restant). Les segments s'empilent depuis la POINTE de la
-- vie vers la gauche (= « ce qui est déjà condamné »), bornés à la vie courante. Le CHOC n'inflige pas de
-- dégâts directs (amplification) -> icône seule, AUCUN segment.
--
-- Une rangée d'ICÔNES pixel art (src/render/affliction_icons.lua, peaufinées par pixel-art-master) au-
-- dessus de la barre dit QUI a QUOI. Repli inline robuste si le module data manque/diffère.

local Theme = require("src.ui.theme")
local Sprite = require("src.core.sprite")

local HealthBar = {}
local C = Theme.c

-- ── Icônes (teintes ABSTRAITES : ' ' transparent, o sombre, d mi-sombre, m principal, h surlignage) ──
-- Repli inline (fonctionnel) ; remplacé par le module data si présent et valide.
local FALLBACK = {
  bleed = {
    "  m  ",
    "  m  ",
    " mmm ",
    "mmhmm",
    "mmmmm",
    "mmmmm",
    " mmm ",
  },
  poison = {
    " m    ",
    "   m  ",
    "mmmmmm",
    "mhmmmm",
    " mmmm ",
  },
  burn = {
    "  m  ",
    "  mm ",
    " mmm ",
    " mhm ",
    "mhmmm",
    "mmmmm",
    " mmm ",
  },
  rot = {
    " mmmm ",
    "mmmmmm",
    "mommom",
    "mmmmmm",
    "mmmmmm",
    " momo ",
  },
  shock = {
    "  mm ",
    "  m  ",
    " mm  ",
    "mmhm ",
    " mm  ",
    " m   ",
    "m    ",
  },
}

local ICONS = {}
for k, v in pairs(FALLBACK) do ICONS[k] = v end
do
  local ok, mod = pcall(require, "src.render.affliction_icons")
  if ok and type(mod) == "table" then
    for k in pairs(FALLBACK) do
      if type(mod[k]) == "table" and #mod[k] > 0 then ICONS[k] = mod[k] end
    end
  end
end

-- ── Dégâts à venir d'un DoT (en PV) : dps × temps restant (les frames -> secondes, /60) ──
local function dotPending(dot)
  if not dot then return 0 end
  local rem = dot.remaining or 0
  if rem < 0 then rem = 0 end
  return (dot.dps or 0) * rem / 60
end

-- Ordre FIXE (stabilité visuelle des segments et de la rangée d'icônes). `segment` : occupe une part de la
-- barre (DoT) ; sinon icône seule (choc = amplification). `pending(u)` -> PV à venir ; `active(u)` -> bool.
local AFFLICTIONS = {
  { key = "poison", color = C.poison, segment = true,
    pending = function(u)
      local t = 0
      local p = u.dots and u.dots.poison
      if p then for _, s in ipairs(p) do t = t + dotPending(s) end end
      return t
    end },
  { key = "bleed", color = C.bleed, segment = true,
    pending = function(u) return dotPending(u.dots and u.dots.bleed) end },
  -- burn : hi JAUNE chaud (pas un simple orange éclairci) -> pointes jaunes / corps orange = vraie flamme.
  { key = "burn", color = C.burn, hi = Theme.hex(0xf7d048), segment = true,
    pending = function(u) return dotPending(u.dots and u.dots.burn) end },
  { key = "rot", color = C.rot, segment = true,
    pending = function(u) return dotPending(u.dots and u.dots.rot) end },
  { key = "shock", color = C.shock, segment = false,
    active = function(u) return (u.dots and u.dots.shock ~= nil) or false end },
}

-- ── Bake des icônes (paresseux, mémoïsé) : teinte la grille abstraite avec la couleur de la famille ──
-- f<=1 assombrit (×f) ; f>1 éclaircit vers le blanc (interpolation). Portable (arithmétique pure).
local function shade(c, f)
  if f <= 1 then return { c[1] * f, c[2] * f, c[3] * f, 1 } end
  local t = f - 1
  return { c[1] + (1 - c[1]) * t, c[2] + (1 - c[2]) * t, c[3] + (1 - c[3]) * t, 1 }
end

local bakeCache = {} -- [key] = { image, w, h } | false (échec/absence : on ne réessaie pas)
local function iconFor(a)
  local b = bakeCache[a.key]
  if b ~= nil then return b or nil end
  local grid = ICONS[a.key]
  if not grid then bakeCache[a.key] = false; return nil end
  local pal = {
    o = shade(a.color, 0.30),
    d = shade(a.color, 0.60),
    m = a.color,
    h = a.hi or shade(a.color, 1.60), -- `hi` optionnel par famille (ex. burn -> jaune, pas orange clair)
  }
  local ok, baked = pcall(Sprite.bake, grid, pal)
  bakeCache[a.key] = (ok and baked) or false
  return (ok and baked) or nil
end

-- Icône bakée d'une affliction PAR CLÉ (poison/bleed/burn/rot/shock) -> { image, w, h } | nil.
-- Réutilisée par arena_draw pour coller l'icône à gauche d'un nombre de dégâts (cohérence couleur/forme).
local BY_KEY = {}
for _, a in ipairs(AFFLICTIONS) do BY_KEY[a.key] = a end
function HealthBar.icon(key)
  local a = BY_KEY[key]
  return a and iconFor(a) or nil
end

-- Liste des afflictions ACTIVES de u, dans l'ordre fixe (segments + icône-seule type choc).
local function activeOf(u)
  local active = {}
  for _, a in ipairs(AFFLICTIONS) do
    local on
    if a.segment then on = a.pending(u) > 0 else on = a.active and a.active(u) end
    if on then active[#active + 1] = a end
  end
  return active
end

-- Rangée d'ICÔNES, HAUT aligné sur `top` (design). leftAlign=true -> départ à x ; sinon centré sur x.
-- scale entier -> net.
local function drawIconsRow(u, scale, x, top, leftAlign)
  local active = activeOf(u)
  if #active == 0 then return end
  local gap = scale
  local baked, totalW = {}, 0
  for i, a in ipairs(active) do
    local b = iconFor(a); baked[i] = b
    if b then totalW = totalW + b.w * scale + (totalW > 0 and gap or 0) end
  end
  if totalW <= 0 then return end
  local ix = leftAlign and math.floor(x) or math.floor(x - totalW / 2)
  local ty = math.floor(top)
  love.graphics.setColor(1, 1, 1, 1)
  for i = 1, #active do
    local b = baked[i]
    if b then
      love.graphics.draw(b.image, ix, ty, 0, scale, scale)
      ix = ix + b.w * scale + gap
    end
  end
end

-- ── Géométrie de la barre (ESPACE DESIGN, spec §C.2) : barre PROPRE 54×8, fond sombre + liseré 1px iron,
-- remplissage SANG gauche-ancré + segments d'altération + overlay bouclier HACHURÉ bleu. Plus de cadre bronze
-- biseauté ni de studs dorés (kit gritty retiré) -> lecture nette, cohérente avec le design-system.
local BAR_W, BAR_H = 54, 8
local BAR_DY = -31          -- top de la barre relatif à u.y (pieds, virtuel) : juste au-dessus de la tête.
HealthBar.BAR_DY = BAR_DY   -- exposé : arena_draw place le NOM de l'unité juste au-dessus de la barre.

local FILL = {
  track = Theme.hex(0x0a0810), -- piste vide (recessed très sombre)
  body  = Theme.hex(0xc0392f), -- crête rouge (haut éclairé)
  bodyD = Theme.hex(0x5a1714), -- base rouge sombre
}

-- Dessine la barre de vie COMPLÈTE (encadré + vie multi-tons + segments + bord de jauge + bouclier + icônes)
-- en ESPACE DESIGN (à appeler SOUS Draw.begin), centrée au-dessus de `u`. SIM en lecture seule.
function HealthBar.draw(u, scale) -- `scale` conservé pour compat de signature (la barre est en design px).
  local maxHp = u.maxHp or 0
  if maxHp <= 0 then return end
  local gr = love and love.graphics
  if not gr then return end -- pur-headless sans love : barre purement cosmétique -> no-op (golden neutre)
  local frac = (u.hp or 0) / maxHp
  if frac < 0 then frac = 0 elseif frac > 1 then frac = 1 end

  local x = math.floor(u.x * 4 - BAR_W / 2)
  local y = math.floor((u.y + BAR_DY) * 4)

  -- PISTE : fond sombre + liseré 1px iron.
  gr.setColor(FILL.track[1], FILL.track[2], FILL.track[3], 1)
  gr.rectangle("fill", x, y, BAR_W, BAR_H)
  gr.setColor(C.iron[1], C.iron[2], C.iron[3], 1)
  gr.rectangle("line", x + 0.5, y + 0.5, BAR_W - 1, BAR_H - 1)
  local ix, iy, iw, ih = x + 1, y + 1, BAR_W - 2, BAR_H - 2

  -- REMPLISSAGE SANG gauche-ancré (base sombre + crête éclairée), largeur = fraction de vie.
  local hpW = math.floor(frac * iw + 0.5)
  if hpW > 0 then
    gr.setColor(FILL.bodyD[1], FILL.bodyD[2], FILL.bodyD[3], 1)
    gr.rectangle("fill", ix, iy, hpW, ih)
    gr.setColor(FILL.body[1], FILL.body[2], FILL.body[3], 1)
    gr.rectangle("fill", ix, iy, hpW, math.max(1, math.floor(ih * 0.45)))

    -- SEGMENTS d'altération : depuis la pointe de la vie vers la gauche, bornés à la vie (ordre AFFLICTIONS).
    local cursor, budget = ix + hpW, hpW
    for _, a in ipairs(AFFLICTIONS) do
      if a.segment and budget > 0 then
        local pend = a.pending(u)
        if pend > 0 then
          local segW = math.floor(pend / maxHp * iw + 0.5)
          if segW > budget then segW = budget end
          if segW > 0 then
            cursor = cursor - segW; budget = budget - segW
            gr.setColor(a.color[1], a.color[2], a.color[3], 0.8) -- voile de famille sur la tranche condamnée
            gr.rectangle("fill", cursor, iy, segW, ih)
            local hi = a.hi or shade(a.color, 1.3)
            gr.setColor(hi[1], hi[2], hi[3], 1)
            gr.rectangle("fill", cursor, iy, segW, 1) -- crête éclairée du segment
          end
        end
      end
    end

    -- front net (liseré vif) à la pointe de la vie.
    gr.setColor(C.bloodBright[1], C.bloodBright[2], C.bloodBright[3], 0.9)
    gr.rectangle("fill", ix + hpW - 1, iy, 1, ih)
  end

  -- BOUCLIER : overlay HACHURÉ bleu (1px sur 4 sur la diagonale x+y) sur la portion de bouclier depuis la
  -- gauche + liseré droit (spec §C.2 : « le bouclier se lit par-dessus la vie »).
  if u.shield and u.shield > 0 then
    local shW = math.floor(math.min(1, u.shield / maxHp) * iw + 0.5)
    gr.setColor(C.shield[1], C.shield[2], C.shield[3], 0.55)
    for sx = 0, shW - 1 do
      for sy = 0, ih - 1 do
        if ((sx + sy) % 4) == 0 then gr.rectangle("fill", ix + sx, iy + sy, 1, 1) end
      end
    end
    gr.setColor(C.shield[1], C.shield[2], C.shield[3], 0.7)
    gr.rectangle("fill", ix + shW - 1, iy, 1, ih)
  end
  gr.setColor(1, 1, 1, 1)

  -- ICÔNES de statut : petites (×1), EN DESSOUS de la barre, alignées à GAUCHE (= pips de statut, §C.2).
  drawIconsRow(u, 1, x, y + BAR_H + 2, true)
end

return HealthBar
