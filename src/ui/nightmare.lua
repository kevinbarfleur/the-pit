-- src/ui/nightmare.lua
-- LA SURCOUCHE ONIRIQUE de l'UI propre — le « réveil du cauchemar » sur des box par ailleurs NETTES.
-- Demande user : « les bordures des box sont nettes mais elles ONT TENDANCE À TANGUER, comme si la personne
-- voyait flou, avec des couleurs violettes/bizarres qui ont du mal à se distinguer — léger mais là ». On
-- N'ALTÈRE PAS la bordure d'origine ni le CONTENU/TEXTE : on AJOUTE un 2e liseré « double-vision » décalé
-- d'un poil (~0.5–1.5px) qui ONDULE lentement (sinus/dt, déphasé PAR CÔTÉ) et SHIMMER en VIOLET (Theme.c.rot)
-- avec une pointe d'abysse (bleu froid), à BAS ALPHA (~0.12–0.22). Le liseré net reste posé par-dessus (le
-- caller dessine sa bordure APRÈS, ou avant — l'effet vit à BAS alpha, il ne mange jamais le contour franc).
--
-- ── CONTRAT (100% RENDER, headless-safe) ─────────────────────────────────────────────────────────────
-- Piloté par le dt MURAL (jamais la SIM : c'est du cosmétique, aucun déterminisme requis). Tous les appels
-- love.graphics sont GARDÉS (no-op sous le mock LÖVE -> check.sh headless vert, golden inchangé). Couleurs
-- via Theme UNIQUEMENT (violet = c.rot, + une teinte d'abysse froide dérivée). Résolution-indépendant :
-- dessine en ESPACE DESIGN sous Draw.begin(view) comme le reste de l'UI ; l'amplitude est en px design.
--
-- API :
--   Nightmare.update(dtFrames)             -- avance l'horloge onirique (dt en FRAMES, ÷60 -> secondes)
--   Nightmare.border(x, y, w, h, opts)     -- 2e liseré qui tangue + shimmer violet/abysse (bas alpha)
--     opts = { t?, amp?, tint?, alpha?, seed? }
--       t     : horloge à utiliser (défaut = horloge interne) ; amp : amplitude max du décalage (px, déf 1.1)
--       tint  : couleur de base du shimmer {r,g,b,a} (défaut Theme.c.rot = violet) ; alpha : plafond (déf 0.18)
--       seed  : déphasage stable par box (désynchronise le tangage entre fenêtres ; défaut 0)

local Theme = require("src.ui.theme")

local Nightmare = {}

local floor, sin, min, max = math.floor, math.sin, math.min, math.max

-- Horloge onirique murale (secondes). Les scènes passent dt en FRAMES (~1.0/tick au pas fixe 1/60) -> ÷60.
local clock = 0
function Nightmare.update(dtFrames)
  local dt = (dtFrames or 1) / 60
  if dt < 0 then dt = 0 end
  clock = clock + dt
end

-- Teinte d'abysse FROIDE dérivée de la palette (bleu/violet sombre) : la pointe « bizarre » qui « a du mal à
-- se distinguer » du violet. On la calcule une fois (pure) à partir des tokens existants (pas de hex en dur).
-- Mix violet(rot) vers un bleu froid (shield est le bleu de la palette) -> un violet-abysse qui vire au bleu.
local C = Theme.c
local function coolTint()
  local rot = C.rot or { 0.66, 0.43, 0.77 }
  local blue = C.shield or { 0.43, 0.66, 0.90 }
  -- 60% violet / 40% bleu froid, assombri : un liseré « abyssal » distinct du shimmer violet principal.
  return {
    (rot[1] * 0.6 + blue[1] * 0.4) * 0.85,
    (rot[2] * 0.6 + blue[2] * 0.4) * 0.85,
    (rot[3] * 0.6 + blue[3] * 0.4) * 0.95,
  }
end
local COOL = coolTint()

-- Trace UN rectangle « line » décalé de (dx,dy) à une couleur/alpha donnés. Coords planchées (net), épaisseur
-- 1px. Garde-fou love.graphics (no-op headless). On NE plancher PAS le décalage (sub-pixel = le flou voulu :
-- l'adoucissement sous la transform de scale donne précisément l'effet « vision trouble » sur le liseré).
local function ghostRect(x, y, w, h, dx, dy, col, a)
  local g = love.graphics
  g.setColor(col[1], col[2], col[3], a)
  g.setLineWidth(1)
  g.rectangle("line", x + dx, y + dy, w, h)
end

-- Nightmare.border : le 2e liseré « double-vision » qui tangue. On dessine DEUX passes décalées (un fantôme
-- violet + un fantôme abysse), chacune ONDULÉE par un sinus LENT déphasé PAR CÔTÉ (le décalage n'est pas
-- uniforme : le haut/bas/gauche/droite respirent à des phases différentes -> la box « gondole » comme une
-- vision floue, pas un simple offset rigide). Bas alpha (le net d'origine domine) -> « léger mais là ».
function Nightmare.border(x, y, w, h, opts)
  local g = love.graphics
  if not (g and g.rectangle and g.setColor) then return end -- headless / pas de GL -> no-op propre
  opts = opts or {}
  x, y, w, h = floor(x + 0.5), floor(y + 0.5), floor(w + 0.5), floor(h + 0.5)
  if w < 3 or h < 3 then return end
  local t = opts.t or clock
  local amp = opts.amp or 1.1            -- amplitude max du décalage (px design) : ~0.5..1.5 voulu
  local seed = opts.seed or 0
  local tint = opts.tint or C.rot or { 0.66, 0.43, 0.77 }
  local aMax = opts.alpha or 0.18        -- plafond d'alpha (~0.12..0.22) : on RESPIRE entre ~0.5×aMax et aMax

  -- ph = phase de base (déphasée par seed -> chaque box tangue indépendamment). Deux sinus incommensurables
  -- pour un mouvement onirique non périodique évident (lent : ~0.35 Hz dominant).
  local ph = seed * 0.013
  -- décalages X/Y du fantôme VIOLET (principal) : ondulation lente, amplitude amp. Le X et le Y ont des
  -- fréquences différentes -> le fantôme décrit une petite ellipse molle qui « gondole ».
  local vx = (sin(t * 1.7 + ph) * 0.6 + sin(t * 0.9 + ph * 1.7) * 0.4) * amp
  local vy = (sin(t * 1.3 + ph + 1.1) * 0.6 + sin(t * 0.7 + ph * 2.1) * 0.4) * amp
  -- fantôme ABYSSE : décalé en OPPOSITION de phase (l'autre œil de la « double vision ») + un poil plus ample.
  local bx = (sin(t * 1.5 + ph + 3.14) * 0.6 + sin(t * 0.8 + ph * 1.3 + 2.0) * 0.4) * amp * 1.15
  local by = (sin(t * 1.1 + ph + 4.2) * 0.6 + sin(t * 0.6 + ph * 1.9 + 1.0) * 0.4) * amp * 1.15

  -- alpha qui RESPIRE (le shimmer « a du mal à se distinguer » : il monte et descend lentement). Jamais 0
  -- (toujours « là »), jamais > aMax (jamais gênant). Pulse incommensurable avec le tangage.
  local pulseV = 0.55 + 0.45 * (0.5 + 0.5 * sin(t * 0.8 + ph * 0.7))
  local pulseB = 0.55 + 0.45 * (0.5 + 0.5 * sin(t * 0.6 + ph * 1.1 + 2.4))
  local aV = aMax * min(1, max(0.4, pulseV))
  local aB = aMax * 0.7 * min(1, max(0.4, pulseB)) -- l'abysse est plus discret (la pointe, pas le corps)

  -- ADDITIF léger pour que le shimmer « brille » dans la pierre sombre sans laver les couleurs (braise/rune
  -- = lumière, pas peinture). On reste à bas alpha -> l'additif ne sature jamais. Restaure alpha-blend après.
  local hadAdd = false
  if g.setBlendMode then hadAdd = pcall(g.setBlendMode, "add") end
  ghostRect(x, y, w, h, vx, vy, tint, aV)  -- fantôme VIOLET (le tangage principal)
  ghostRect(x, y, w, h, bx, by, COOL, aB)  -- fantôme ABYSSE (la pointe froide, en opposition de phase)
  if hadAdd and g.setBlendMode then pcall(g.setBlendMode, "alpha") end
  g.setColor(1, 1, 1, 1)
end

return Nightmare
