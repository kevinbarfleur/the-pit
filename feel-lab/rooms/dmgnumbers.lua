-- feel-lab/rooms/dmgnumbers.lua
-- ╔══════════════════════════════════════════════════════════════════════════════════════════════════╗
-- ║  INTERFACE DE BRANCHEMENT « CHIFFRES DE DÉGÂTS » — game-feel-engineer greffe ses variantes ICI.    ║
-- ╚══════════════════════════════════════════════════════════════════════════════════════════════════╝
--
-- C'est le SUBSTRAT des nombres flottants. Le combat (combat_lab.lua) et le banc manuel ÉMETTENT des
-- évènements `spawn{...}` ; ce module les fait vivre puis les dessine. On bascule de proposition par NOM
-- (« A » par défaut + B/C) sans rien changer côté appelant.
--
-- ── CONTRAT (signatures stables — NE PAS casser) ───────────────────────────────────────────────────────
--   local DN = require("rooms.dmgnumbers")
--   local layer = DN.new("A")                         -- crée une couche dans la variante nommée
--   layer:spawn{ x, y, val, cause, source, target, crit }  -- pose un nombre (coords MONDE virtuel 320×180)
--   layer:update(dt)                                  -- avance la vie des nombres (dt en FRAMES@60, comme la sim)
--   layer:draw(view)                                  -- dessine (gère lui-même Draw.begin/finish + ×4 design)
--   layer:setVariant(name)                            -- bascule de proposition (purge à la bascule)
--   DN.VARIANTS                                        -- { {id="A", name="..."}, ... } pour le sélecteur d'UI
--
--   Évènement `spawn` (le SEUL point d'entrée de données) :
--     x, y    = position MONDE (virtuel 320×180) où le nombre apparaît (typiquement la tête de la cible)
--     val     = montant ENTIER de dégâts (déjà la part qui mord les PV ; le pur-absorbé n'arrive pas ici)
--     cause   = "attack"|"burn"|"bleed"|"poison"|"rot"|"shock" (+ cleave/thorns/reflect/fatigue possibles)
--     source  = unité émettrice (ref ; sert au regroupement / à l'attribution) — peut être nil
--     target  = unité receveuse (ref ; sert au regroupement par cible) — peut être nil
--     crit    = bool optionnel (accentue ; aucune notion de crit dans la sim actuelle = seam de variante)
--
-- ── 3 VARIANTES LIVRÉES (objectif : JOUISSIF mais STRUCTURÉ/LISIBLE) ────────────────────────────────────
--   A « Registre »     — COLONNE NETTE au-dessus de la cible, le récent pousse les anciens vers le haut ; les
--                        tics de DoT s'AGRÈGENT en un total qui PULSE (zéro spam, lisibilité max).
--   B « Pop cinétique » — punch de scale (overshoot) -> settle -> drift montant + fade ; gros coup = punch plus
--                        lourd + glow ; offset DÉTERMINISTE (Weyl, pas de RNG). Jus maîtrisé.
--   C « Éclat typé »    — chiffre posé dans un ÉCLAT/plaque de la couleur du type (pop+glisse) ; intensité ∝
--                        montant ; fin trait/arc discret vers la SOURCE (provenance ultra-claire).
--
-- COMMUN aux 3 (helpers `Common` ci-dessous) : taille ∝ montant mais CAPPÉE (11→~22px, jamais énorme) ;
-- couleur + GLYPHE par cause (pip procédural, pas de glyphe Unicode = polices non garanties) ; crit accentué.
-- RENDER PUR. Coords d'entrée en MONDE virtuel ; le ×4 vers l'espace DESIGN 1280×720 est fait au draw.

local Draw  = require("lib.draw")
local Theme = require("lib.theme")
local c = Theme.c

local DN = {}

-- 2 variantes PROPRES, 100% PLATES (aucun backing/halo/plaque). La variante « Éclat typé » à plaque a été
-- SUPPRIMÉE (une plaque = exactement ce qui est banni).
DN.VARIANTS = {
  { id = "A", name = "Registre · colonne+merge" },
  { id = "B", name = "Pop cinétique" },
}

-- ════════════════════════════════════════════════════════════════════════════════════════════════════
-- COMMUN : couleur + glyphe par cause, taille cappée ∝ montant, dessin d'un nombre « typé ».
-- ════════════════════════════════════════════════════════════════════════════════════════════════════
local Common = {}

-- Couleur par CAUSE (mêmes teintes que le jeu : src/ui/theme.lua). attack = sang.
local CAUSE_COL = {
  attack = c.blood, burn = c.burn, bleed = c.bleed, poison = c.poison,
  rot = c.rot, shock = c.shock, cleave = c.bloodL, thorns = c.steel,
  reflect = c.shield, fatigue = c.ink3,
}
function Common.colOf(cause) return CAUSE_COL[cause] or c.blood end

-- TAILLE ∝ montant mais CAPPÉE : 1 PV -> MIN, >= CAP_VAL -> MAX. Courbe douce (sqrt) -> les petits restent
-- lisibles, les gros grossissent sans exploser. Crit = +bonus. Renvoie une taille de police ENTIÈRE (design).
local MIN_PX, MAX_PX, CAP_VAL = 13, 23, 14
function Common.sizeFor(val, crit)
  local k = math.min(1, math.sqrt(math.max(0, val) / CAP_VAL))
  local px = MIN_PX + (MAX_PX - MIN_PX) * k
  if crit then px = px + 4 end
  return math.floor(px + 0.5)
end

-- GLYPHE par cause = petit PIP procédural (forme propre, doublée à la couleur -> lisible même sans la teinte,
-- amical daltonien). Dessiné À GAUCHE du nombre. r = rayon ~ taille du texte. Coords DESIGN (déjà ×4).
function Common.glyph(cause, gx, gy, r, col, alpha)
  love.graphics.setColor(col[1], col[2], col[3], alpha)
  if cause == "attack" or cause == "cleave" then       -- ÉPÉE/coup = losange plein (frappe franche)
    love.graphics.polygon("fill", gx, gy - r, gx + r, gy, gx, gy + r, gx - r, gy)
  elseif cause == "burn" then                            -- FEU = triangle (flamme) pointe en haut
    love.graphics.polygon("fill", gx, gy - r, gx + r * 0.9, gy + r * 0.8, gx - r * 0.9, gy + r * 0.8)
  elseif cause == "bleed" then                           -- SAIGNEMENT = goutte (disque + pointe)
    love.graphics.circle("fill", gx, gy + r * 0.3, r * 0.8)
    love.graphics.polygon("fill", gx, gy - r, gx + r * 0.7, gy + r * 0.2, gx - r * 0.7, gy + r * 0.2)
  elseif cause == "poison" then                          -- POISON = hexagone (spore/cellule)
    local pts = {}
    for i = 0, 5 do local a = i / 6 * math.pi * 2 + math.pi / 6; pts[#pts+1] = gx + math.cos(a) * r; pts[#pts+1] = gy + math.sin(a) * r end
    love.graphics.polygon("fill", pts)
  elseif cause == "rot" then                             -- POURRITURE = anneau évidé (creux)
    love.graphics.setLineWidth(math.max(1.5, r * 0.5))
    love.graphics.circle("line", gx, gy, r * 0.85)
    love.graphics.setLineWidth(1)
  elseif cause == "shock" then                           -- CHOC = éclair zigzag
    love.graphics.setLineWidth(math.max(1.5, r * 0.45))
    love.graphics.line(gx - r * 0.5, gy - r, gx + r * 0.2, gy - r * 0.1, gx - r * 0.2, gy + r * 0.1, gx + r * 0.5, gy + r)
    love.graphics.setLineWidth(1)
  else                                                   -- défaut = petit disque
    love.graphics.circle("fill", gx, gy, r * 0.8)
  end
end

-- 8 directions du contour (lisibilité produit sur fond sombre). Un CONTOUR n'est PAS un halo : c'est un liseré
-- net 1px (texte décalé), pas un disque flou. C'est la SEULE chose tolérée pour détacher du fond.
local OUTLINE8 = { { -1, -1 }, { 0, -1 }, { 1, -1 }, { -1, 0 }, { 1, 0 }, { -1, 1 }, { 0, 1 }, { 1, 1 } }

-- DESSINE un nombre typé centré en (cx,cy) DESIGN — FINITION PRODUIT, 100% PLAT :
--   • RÈGLE ABSOLUE : AUCUN backing/plaque/halo/DISQUE DE GLOW derrière le chiffre (banni, « cringe »).
--   • typo NETTE Space Mono (Theme.value = chiffres tabulaires), taille ∝ montant CAPPÉE ;
--   • CONTOUR noir 8-dir (liseré net, PAS un halo) -> détache du fond sombre ; crit -> contour IVOIRE ;
--   • valeur teintée par cause + « ! » laiton sur crit ; glyphe de cause NET à gauche (forme propre).
function Common.number(val, cause, cx, cy, s, alpha, crit, sizeBoost)
  local col = Common.colOf(cause)
  local px = Common.sizeFor(val, crit) + (sizeBoost or 0)
  local font = Theme.value(px) -- Space Mono 700 : chiffres tabulaires, kerning régulier
  local str = "-" .. val
  local w = font:getWidth(str)
  local h = font:getHeight()
  local r = px * 0.30
  love.graphics.push()
  love.graphics.translate(math.floor(cx + 0.5), math.floor(cy + 0.5))
  love.graphics.scale(s, s)
  -- glyphe (à gauche, vertical-centré) avec une fine ombre 1px (détache ; ce n'est pas un halo)
  local gx = -w / 2 - r - 4
  Common.glyph(cause, gx + 1, 1, r, { 0, 0, 0 }, 0.6 * alpha)
  Common.glyph(cause, gx, 0, r, col, alpha)
  -- CONTOUR 8-dir (noir, ou ivoire si crit) -> liseré net qui détache, JAMAIS un disque/halo de fond.
  local oc = crit and c.ink or { 0, 0, 0 }
  local oa = (crit and 0.95 or 0.85) * alpha
  for _, o in ipairs(OUTLINE8) do
    Draw.text(str, -w / 2 + o[1], -h / 2 + o[2], { oc[1], oc[2], oc[3], oa }, font)
  end
  -- VALEUR teintée par cause (cœur lumineux : un soupçon d'ivoire mêlé pour la netteté).
  Draw.text(str, -w / 2, -h / 2, { col[1], col[2], col[3], alpha }, font)
  -- crit : « ! » laiton, collé à droite (taille déjà majorée par sizeFor).
  if crit then
    Draw.text("!", w / 2 + 2, -h / 2, { c.brassS[1], c.brassS[2], c.brassS[3], alpha }, font)
  end
  love.graphics.pop()
  love.graphics.setColor(1, 1, 1, 1)
end

-- ════════════════════════════════════════════════════════════════════════════════════════════════════
-- VARIANTE « A » — REGISTRE : colonne nette au-dessus de la cible (ZÉRO dispersion latérale). Le plus récent
-- apparaît en bas de la pile et POUSSE les anciens vers le haut (ressort de position). Les tics du même
-- (cible, cause) s'AGRÈGENT dans la même ligne (total qui PULSE) au lieu de spammer -> lisibilité maximale.
-- ════════════════════════════════════════════════════════════════════════════════════════════════════
local A = {}
A.LIFE      = 78     -- durée de vie (frames)
A.MERGE     = 40     -- fenêtre d'agrégation (frames) : un tic de même (cible,cause) s'additionne
A.ROW_H     = 13     -- hauteur d'une ligne dans la colonne (px DESIGN)
A.RISE_TAU  = 0.18   -- douceur du glissement vers la position-cible (lerp framerate-normalisé)

-- clé de regroupement : par CIBLE + CAUSE (le registre agrège tout le DoT d'un type sur une cible)
local function keyA(ev) return tostring(ev.target or ev.x) .. "|" .. (ev.cause or "attack") end

function A.spawn(self, ev)
  local n = ev.val
  if not (n and n > 0) then return end
  local key = keyA(ev)
  -- agrégation : une ligne récente de même clé -> on ajoute la valeur + on PULSE.
  for i = #self.items, 1, -1 do
    local d = self.items[i]
    if d.key == key and d.age < A.MERGE then
      d.val = d.val + n; d.age = 0; d.pop = 1.0; return
    end
  end
  -- nouvelle ligne : anchrée à la tête de la cible ; le slot vertical est attribué au draw (empilement).
  self.items[#self.items + 1] = {
    key = key, cause = ev.cause or "attack", val = n, crit = ev.crit or false,
    ax = ev.x, ay = ev.y, age = 0, pop = 1.0, yoff = 0, slot = 0,
  }
end

function A.update(self, dt)
  -- attribue les SLOTS verticaux par ancre (colonne) : le plus récent en bas (slot 0), les plus vieux montent.
  -- on regroupe par ancre x arrondie (même cible = même colonne).
  local cols = {}
  for i = #self.items, 1, -1 do
    local d = self.items[i]
    d.age = d.age + dt
    if d.pop and d.pop > 0 then d.pop = math.max(0, d.pop - 0.10 * dt) end
    if d.age >= A.LIFE then table.remove(self.items, i) end
  end
  -- empilement : pour chaque colonne (ancre x), trier par âge (récent en bas) -> slot croissant vers le haut.
  for _, d in ipairs(self.items) do
    local cx = math.floor((d.ax or 0) / 6 + 0.5)
    cols[cx] = cols[cx] or {}
    cols[cx][#cols[cx] + 1] = d
  end
  for _, list in pairs(cols) do
    table.sort(list, function(p, q) return p.age < q.age end) -- récent d'abord -> slot 0 en bas
    for i, d in ipairs(list) do
      d.targetSlot = i - 1
      -- glissement doux vers le slot cible (en frames -> on lisse)
      local lerp = 1 - math.exp(-(dt / 60) / A.RISE_TAU)
      d.slot = (d.slot or 0) + (d.targetSlot - (d.slot or 0)) * math.min(1, lerp * 1.5)
    end
  end
end

function A.draw(self, view)
  Draw.begin(view)
  for _, d in ipairs(self.items) do
    local p = d.age / A.LIFE
    local alpha = (p < 0.7) and 1 or math.max(0, 1 - (p - 0.7) / 0.3)
    local cx = d.ax * 4
    local cy = (d.ay - 8) * 4 - d.slot * A.ROW_H   -- colonne : slot pousse vers le HAUT, zéro dérive latérale
    local s = 1 + (d.pop or 0) * 0.45              -- pulse à l'agrégation
    Common.number(d.val, d.cause, cx, cy, s, alpha, d.crit)
  end
  Draw.finish()
  Draw.reset()
end

-- ════════════════════════════════════════════════════════════════════════════════════════════════════
-- VARIANTE « B » — POP CINÉTIQUE : à l'apparition, PUNCH de scale (overshoot ressort) puis settle, puis léger
-- drift montant + fade. Gros coup = punch plus lourd + GLOW additif derrière le chiffre. Offset latéral
-- DÉTERMINISTE (suite de Weyl, pas de RNG) -> pas de chevauchement, replay identique. Jus maîtrisé.
-- ════════════════════════════════════════════════════════════════════════════════════════════════════
local B = {}
B.LIFE  = 60
B.PHI   = 0.6180339887  -- Weyl : dispersion latérale déterministe
B.RISE  = -0.55         -- vitesse de drift montant (px/frame)

function B.spawn(self, ev)
  local n = ev.val
  if not (n and n > 0) then return end
  self.fxN = (self.fxN or 0) + 1
  local jitter = (((self.fxN * B.PHI) % 1) - 0.5) * 10 -- ±5 px DESIGN, déterministe
  -- punch initial ∝ montant (cappé) : un gros coup « claque » plus fort.
  local heavy = math.min(1, n / 14)
  self.items[#self.items + 1] = {
    cause = ev.cause or "attack", val = n, crit = ev.crit or false,
    cx = ev.x * 4 + jitter, cy = (ev.y - 6) * 4,
    age = 0, pop = 0.6 + 0.7 * heavy, popV = 0, heavy = heavy,
  }
end

function B.update(self, dt)
  for i = #self.items, 1, -1 do
    local d = self.items[i]
    d.age = d.age + dt
    -- ressort de scale (overshoot) : pop -> 0, intégré en frames (k/d calibrés pour un settle ~25 frames)
    local k, damp = 0.10, 0.55
    d.popV = (d.popV or 0) * damp + (0 - (d.pop or 0)) * k
    d.pop = (d.pop or 0) + d.popV * dt
    d.cy = d.cy + B.RISE * dt           -- drift montant
    if d.age >= B.LIFE then table.remove(self.items, i) end
  end
end

function B.draw(self, view)
  Draw.begin(view)
  for _, d in ipairs(self.items) do
    local p = d.age / B.LIFE
    local alpha = (p < 0.55) and 1 or math.max(0, 1 - (p - 0.55) / 0.45)
    local s = 1 + (d.pop or 0)          -- overshoot -> settle (le « jus » = le PUNCH de scale, PAS un glow de fond)
    -- 100% PLAT : aucun disque/halo de fond. Le gros coup « claque » par le punch de scale + sa taille, point.
    Common.number(d.val, d.cause, d.cx, d.cy, s, alpha, d.crit)
  end
  Draw.finish()
  Draw.reset()
end

-- (La variante « C — Éclat typé » à PLAQUE a été SUPPRIMÉE : une plaque/backing derrière le chiffre est
--  exactement ce qui est banni. Provenance désormais portée par le VFX directionnel, pas par un chevron sur
--  une plaque. On garde 2 variantes 100% plates : A « Registre » + B « Pop cinétique ».)

local IMPL = { A = A, B = B }

-- ── DISPATCHER ────────────────────────────────────────────────────────────────────────────────────────
local Layer = {}
Layer.__index = Layer

function DN.new(variant)
  return setmetatable({ items = {}, fxN = 0, variant = IMPL[variant] and variant or "A" }, Layer)
end

function Layer:setVariant(name)
  if IMPL[name] then self.variant = name; self.items = {}; self.fxN = 0 end -- purge à la bascule (comparaison nette)
end
function Layer:variantName() return self.variant end

function Layer:spawn(ev) IMPL[self.variant].spawn(self, ev) end
function Layer:update(dt) IMPL[self.variant].update(self, dt) end
function Layer:draw(view) IMPL[self.variant].draw(self, view) end
function Layer:clear() self.items = {}; self.fxN = 0 end

return DN
