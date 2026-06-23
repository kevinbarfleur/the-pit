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

-- ── Géométrie de l'ENCADRÉ (en ART px ; rendu en ESPACE DESIGN à `scale` px/art -> grille fine, nette) ──
-- Cadre 2px (liseré sombre + métal biseauté) autour d'une aire de remplissage FW×FH. La barre vit dans
-- l'overlay (comme les nombres/icônes) -> bien plus fine que la grille ×4 du monde (fini le « alpha »).
local FW, FH = 34, 4        -- aire de remplissage (art px)
local PAD = 2               -- épaisseur du cadre (art px) : liseré 1 + métal 1
local AW, AH = FW + PAD * 2, FH + PAD * 2 -- 38 × 8 (art px)
local IX0, IY0 = PAD, PAD   -- origine art de l'aire de remplissage (2,2)
-- Pile verticale au-dessus du monstre : NOM (au-dessus) / encadré / ICÔNES (en dessous), le tout au-dessus
-- de la tête. BAR_DY positionne le HAUT de l'encadré pour laisser la place aux icônes entre la barre et la
-- tête (cf. ROW_GAP de place.lua qui garantit le creux entre monstres empilés).
local BAR_DY = -31          -- top de l'encadré relatif à u.y (pieds, virtuel) : COLLÉ juste sur la tête du
                            -- monstre (≈ dans sa case) -> plus de pile flottante haute, grille resserrable
HealthBar.BAR_DY = BAR_DY   -- exposé : arena_draw place le NOM de l'unité juste au-dessus de l'encadré

-- Encadré « runique » : bronze biseauté + accents dorés (réutilise le thème + 3 bronzes via Theme.hex).
local FRAME = {
  out  = Theme.hex(0x0a0608), -- liseré extérieur (presque noir, chaud)
  lit  = Theme.hex(0x82602a), -- métal éclairé (haut/gauche)
  dark = Theme.hex(0x3a2a14), -- métal ombré (bas/droite)
  gold = C.gold, goldBr = C.goldBright,
}
local FILL = {
  empty = Theme.hex(0x16090b), -- canal vide (vie perdue) : recessed très sombre
  sheen = C.bloodBright, body = C.blood, shadow = C.bloodDeep,
  edge  = C.dmg,               -- bord de jauge (cut lumineux)
}

-- Dessine la barre de vie COMPLÈTE (encadré + vie multi-tons + segments + bord de jauge + bouclier + icônes)
-- en ESPACE DESIGN (à appeler SOUS Draw.begin), centrée au-dessus de `u`. SIM en lecture seule.
function HealthBar.draw(u, scale)
  scale = scale or 2
  local maxHp = u.maxHp or 0
  if maxHp <= 0 then return end
  local frac = (u.hp or 0) / maxHp
  if frac < 0 then frac = 0 elseif frac > 1 then frac = 1 end

  local ox = math.floor(u.x * 4 - AW * scale / 2)
  local oy = math.floor((u.y + BAR_DY) * 4)

  -- Pose un rectangle en ART px (ax,ay,aw,ah) -> design via scale. alpha optionnel.
  local function ar(ax, ay, aw, ah, col, alpha)
    if aw <= 0 or ah <= 0 then return end
    love.graphics.setColor(col[1], col[2], col[3], alpha or col[4] or 1)
    love.graphics.rectangle("fill", ox + ax * scale, oy + ay * scale, aw * scale, ah * scale)
  end

  -- INTÉRIEUR : canal vide (recessed), puis vie courante en 3 tons (brillance / corps / ombre).
  ar(IX0, IY0, FW, FH, FILL.empty)
  local hpW = math.floor(frac * FW + 0.5)
  if hpW > 0 then
    ar(IX0, IY0, hpW, 1, FILL.sheen)
    ar(IX0, IY0 + 1, hpW, FH - 2, FILL.body)
    ar(IX0, IY0 + FH - 1, hpW, 1, FILL.shadow)
  end

  -- SEGMENTS d'altération : depuis la pointe de la vie vers la gauche, bornés à la vie (ordre AFFLICTIONS).
  local budget, cursor = hpW, IX0 + hpW
  for _, a in ipairs(AFFLICTIONS) do
    if a.segment and budget > 0 then
      local pend = a.pending(u)
      if pend > 0 then
        local segW = math.floor(pend / maxHp * FW + 0.5)
        if segW > budget then segW = budget end
        if segW > 0 then
          cursor = cursor - segW; budget = budget - segW
          ar(cursor, IY0, segW, 1, shade(a.color, 1.3)) -- brillance du segment
          ar(cursor, IY0 + 1, segW, FH - 1, a.color)    -- corps du segment
        end
      end
    end
  end

  -- Bord de jauge : cut lumineux au bord droit de la vie (si entamée) -> lecture nette de la descente.
  if hpW > 0 and hpW < FW then ar(IX0 + hpW - 1, IY0, 1, FH, FILL.edge, 0.7) end

  -- Bouclier : voile cyan sur le haut de l'intérieur (largeur = fraction de bouclier).
  if u.shield and u.shield > 0 then
    local sw = math.floor(math.min(1, u.shield / maxHp) * FW + 0.5)
    ar(IX0, IY0, sw, 1, C.shield, 0.85)
  end

  -- ENCADRÉ : liseré extérieur sombre + bande métal biseautée (haut/gauche clairs, bas/droite sombres).
  ar(0, 0, AW, 1, FRAME.out); ar(0, AH - 1, AW, 1, FRAME.out)
  ar(0, 0, 1, AH, FRAME.out); ar(AW - 1, 0, 1, AH, FRAME.out)
  ar(1, 1, AW - 2, 1, FRAME.lit); ar(1, 1, 1, AH - 2, FRAME.lit)
  ar(1, AH - 2, AW - 2, 1, FRAME.dark); ar(AW - 2, 1, 1, AH - 2, FRAME.dark)
  -- Accents dorés : studs aux 4 coins (haut plus brillants) + nubs runiques aux extrémités (milieu vertical).
  ar(1, 1, 1, 1, FRAME.goldBr); ar(AW - 2, 1, 1, 1, FRAME.goldBr)
  ar(1, AH - 2, 1, 1, FRAME.gold); ar(AW - 2, AH - 2, 1, 1, FRAME.gold)
  local midY = math.floor(AH / 2) - 1
  ar(0, midY, 1, 2, FRAME.gold); ar(AW - 1, midY, 1, 2, FRAME.gold)

  -- ICÔNES de statut : petites (×1), EN DESSOUS de l'encadré, alignées à GAUCHE (départ au bord gauche).
  drawIconsRow(u, 1, ox, oy + AH * scale + 1, true)

  love.graphics.setColor(1, 1, 1, 1)
end

return HealthBar
