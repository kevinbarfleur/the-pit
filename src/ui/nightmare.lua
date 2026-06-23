-- src/ui/nightmare.lua
-- LA SURCOUCHE ONIRIQUE de l'UI propre — le « réveil du cauchemar » sur des box par ailleurs NETTES.
-- Demande user : « les bordures sont nettes mais elles ONT TENDANCE À TANGUER, comme si la personne voyait
-- flou, des couleurs violettes/bizarres qui ont du mal à se distinguer — léger mais là ». IMPORTANT (retour
-- user) : ce n'est PAS un glow/rétro-éclairage qui clignote — c'est la LIGNE qui ONDULE. On dessine donc le
-- bord en POLYLIGNE dont chaque point est déplacé PERPENDICULAIREMENT par une onde sinusoïdale qui VOYAGE le
-- long du périmètre (déplacement POSITIONNEL, alpha STABLE) -> on VOIT la ligne tanguer. Deux passes (un
-- fantôme VIOLET c.rot + un fantôme ABYSSE froid) à fréquences/phases/vitesses légèrement différentes : les
-- deux ondes se croisent et se séparent = la « double vision » qui gondole. On N'ALTÈRE PAS le contenu/texte
-- ni le liseré net d'origine (posé par le caller) — l'onde vit à BAS alpha, autour du contour franc.
--
-- 100% RENDER, headless-safe (love.graphics gardé -> no-op sous le mock ; golden inchangé). Piloté par le dt
-- MURAL (cosmétique, aucun déterminisme). Couleurs via Theme. Résolution-indépendant (px design sous Draw.begin).
--
-- API :
--   Nightmare.update(dtFrames)          -- avance l'horloge onirique (dt en FRAMES, ÷60 -> secondes)
--   Nightmare.border(x, y, w, h, opts)  -- bord qui ONDULE (double polyligne violet/abysse). opts =
--     { t?, amp?, alpha?, tint?, seed? } : t horloge ; amp amplitude de l'onde (px, déf 1.8) ; alpha plafond
--     (déf 0.38) ; tint couleur principale (déf c.rot) ; seed déphasage stable par box.

local Theme = require("src.ui.theme")

local Nightmare = {}

local floor, sin = math.floor, math.sin

-- Horloge onirique murale (secondes). Les scènes passent dt en FRAMES (~1.0/tick au pas fixe 1/60) -> ÷60.
local clock = 0
function Nightmare.update(dtFrames)
  local dt = (dtFrames or 1) / 60
  if dt < 0 then dt = 0 end
  clock = clock + dt
end

-- Teinte d'abysse FROIDE dérivée de la palette : le 2e fantôme « bizarre » qui « a du mal à se distinguer » du
-- violet. Mix violet(rot) vers le bleu froid de la palette (shield), assombri. Calculé une fois (pure).
local C = Theme.c
local function coolTint()
  local rot = C.rot or { 0.66, 0.43, 0.77 }
  local blue = C.shield or { 0.43, 0.66, 0.90 }
  return {
    (rot[1] * 0.55 + blue[1] * 0.45) * 0.9,
    (rot[2] * 0.55 + blue[2] * 0.45) * 0.9,
    (rot[3] * 0.55 + blue[3] * 0.45),
  }
end
local COOL = coolTint()

-- Point + NORMALE SORTANTE à la distance d'arc `s` le long du périmètre du rect (x,y,w,h). Sert à déplacer
-- chaque échantillon PERPENDICULAIREMENT au bord (l'onde « pousse » la ligne vers l'intérieur/extérieur).
local function perimPoint(x, y, w, h, s)
  if s < w then return x + s, y, 0, -1 end           -- haut  (gauche->droite), normale = haut
  s = s - w
  if s < h then return x + w, y + s, 1, 0 end          -- droite (haut->bas),     normale = droite
  s = s - h
  if s < w then return x + w - s, y + h, 0, 1 end       -- bas   (droite->gauche), normale = bas
  s = s - w
  return x, y + h - s, -1, 0                            -- gauche (bas->haut),     normale = gauche
end

-- Une passe : polyligne FERMÉE dont chaque point est déplacé de amp·sin(s·k − t·speed + phase) le long de la
-- normale -> une ONDE qui VOYAGE autour du bord (sa crête se déplace dans le temps = la ligne tangue). Alpha
-- STABLE (le mouvement porte l'effet, pas le clignotement). Blend NORMAL (une ligne colorée, pas un glow).
local function wavyLoop(x, y, w, h, amp, k, t, speed, phase, col, a)
  local g = love.graphics
  local P = 2 * (w + h)
  local n = floor(P / 5)
  if n < 12 then n = 12 end
  local pts = {}
  local j = 0
  for i = 0, n do
    local s = (i / n) * P
    local px, py, nx, ny = perimPoint(x, y, w, h, s >= P and 0 or s)
    local d = amp * sin(s * k - t * speed + phase)
    pts[j + 1] = px + nx * d
    pts[j + 2] = py + ny * d
    j = j + 2
  end
  g.setColor(col[1], col[2], col[3], a)
  if g.setLineWidth then g.setLineWidth(2) end
  g.line(pts)
end

-- Le bord qui ONDULE : fantôme VIOLET + fantôme ABYSSE, fréquences/vitesses/phases distinctes (les deux ondes
-- se croisent -> double-vision qui gondole), déphasés par seed (désync entre box). Léger (bas alpha) mais le
-- MOUVEMENT le rend bien présent. Le caller pose son liseré net par-dessus/dessous : le contour franc demeure.
function Nightmare.border(x, y, w, h, opts)
  local g = love.graphics
  if not (g and g.line and g.setColor) then return end -- headless / pas de GL -> no-op propre
  opts = opts or {}
  x, y, w, h = floor(x + 0.5), floor(y + 0.5), floor(w + 0.5), floor(h + 0.5)
  if w < 6 or h < 6 then return end
  local t = opts.t or clock
  local amp = opts.amp or 3.5                 -- amplitude de l'onde (px design)
  if amp < 3.0 then amp = 3.5 end             -- FRANCO : on ignore les overrides trop faibles des call-sites
                                              -- (Panel passait amp=1.0) — le user préfère trop fort, on réduira
  local seed = opts.seed or 0
  local tint = opts.tint or C.rot or { 0.66, 0.43, 0.77 }
  local a = opts.alpha or 0.65                -- alpha STABLE bien VISIBLE (franco) — pas un clignotement
  local ph = seed * 0.013
  local breath = 0.88 + 0.12 * sin(t * 0.6 + ph) -- micro-souffle (toujours « là », jamais dominant)

  -- VIOLET (l'onde principale) : longueur d'onde ~28px (k≈0.22), vitesse 1.5 rad/s.
  wavyLoop(x, y, w, h, amp,        0.22, t, 1.5, ph,        tint, a * breath)
  -- ABYSSE (le 2e œil) : onde plus longue (k≈0.17) et plus lente (1.0), déphasée ~π -> croise la violette.
  wavyLoop(x, y, w, h, amp * 1.2,  0.17, t, 1.0, ph + 3.14, COOL, a * 0.72 * breath)
  g.setColor(1, 1, 1, 1)
end

return Nightmare
