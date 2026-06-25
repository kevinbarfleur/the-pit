-- src/ui/overlay.lua
-- CHORÉGRAPHIE D'ENTRÉE UNIFIÉE des overlays flottants — le « même programme » partout. Plainte d'origine :
-- « le popup de fin de combat diffère des autres vues ». Tous les overlays (bilan de combat, chronique,
-- relicpick, runover) apparaissaient d'un COUP, avec des voiles incohérents. Ce helper porte la MÊME courbe
-- d'entrée pour TOUS : un `anim` 0→1 qui monte le VOILE, agrandit/fond le CONTENU en back-ease, et qu'on
-- branche A MINIMA dans chaque overlay (un champ `_anim` avancé chaque frame -> scale+alpha au groupe + dim).
--
-- Transplant de feel-lab/lib/modalstack.lua (chorégraphie validée) : approche framerate-correcte vers 1
-- (ENTER_TAU ~85 ms, ease-out franc), panneau scale = 0.94 + 0.06·backEase(anim) + fade, dim = dimLevel·anim
-- (le voile MONTE avec l'entrée, il ne « pope » plus). On NE recrée PAS la pile de modales (chaque overlay
-- garde sa logique de fermeture/contenu) — on lui DONNE juste la courbe et le voile standardisés.
--
-- RENDER pur (love.graphics), HEADLESS-SAFE : sous le mock LÖVE, push/translate/scale/rectangle sont stubés
-- (no-op) -> aucune des fns ne crashe. Les fns PURES (advance/backEase/scaleOf/alphaOf) tournent partout.
-- Le voile est peint en COORDS ÉCRAN (origin) comme modalstack : il couvre tout l'écran, indépendant de la
-- transform de design -> aucune barre, aucun trou aux échelles non-entières.

local Overlay = {}

-- Vitesse d'entrée : ~85 ms en ease-out franc (la courbe « back » est appliquée par scaleOf, pas ici). Même
-- valeur que modalstack ENTER_TAU. dt est en SECONDES (les scènes passent frameDt@60 -> on /60 à l'appel).
Overlay.ENTER_TAU = 0.085

-- Avance un `anim` ∈ [0,1] vers 1 de façon FRAMERATE-CORRECTE (k = 1 - e^(-dt/tau)) : converge à la même
-- vitesse réelle quel que soit le pas de temps (60/120/144 Hz). Renvoie le nouvel anim (à réassigner).
-- dt en secondes ; tau optionnel (def ENTER_TAU). dt nil/<=0 -> renvoie anim inchangé (pose figée headless).
function Overlay.advance(anim, dt, tau)
  anim = anim or 0
  if not dt or dt <= 0 then return anim end
  tau = tau or Overlay.ENTER_TAU
  local k = 1 - math.exp(-dt / tau)
  return anim + (1 - anim) * k
end

-- Ease « back-out » : dépasse légèrement 1 puis revient (le panneau « claque » en place au lieu de glisser
-- mollement). Identique à la courbe d'entrée du modalstack. a clampé [0,1] -> jamais d'overshoot incontrôlé.
function Overlay.backEase(a)
  a = a < 0 and 0 or (a > 1 and 1 or a)
  local s = 1.70158
  local p = a - 1
  return p * p * ((s + 1) * p + s) + 1
end

-- Scale du CONTENU pour un anim donné : 0.94 (légèrement réduit à l'entrée) -> 1.0 (back-ease). `range`
-- optionnel resserre l'amplitude (def 0.06) : pour un PLEIN ÉCRAN riche (bilan de combat) on veut une entrée
-- SUBTILE (range ~0.025), pas un rétrécissement de petite modale. base = 1 - range.
function Overlay.scaleOf(anim, range)
  range = range or 0.06
  return (1 - range) + range * Overlay.backEase(anim or 0)
end

-- Alpha du CONTENU : le fade suit l'anim, mais on l'ACCÉLÈRE un peu (^0.7) -> le contenu devient lisible tôt
-- pendant que le scale finit sa course (évite un texte fantôme à mi-entrée). Borné [0,1].
function Overlay.alphaOf(anim)
  anim = anim or 0
  if anim <= 0 then return 0 end
  if anim >= 1 then return 1 end
  return anim ^ 0.7
end

-- VOILE standardisé (le « dim » qui monte avec l'entrée) : alpha = dimLevel · anim, peint en COORDS ÉCRAN
-- (origin) pour couvrir tout l'écran indépendamment de la transform de design (comme modalstack). Teinte
-- abysse Wraeclast (très sombre, légèrement violacée) -> cohérente avec la DA, jamais un noir plat. À appeler
-- AVANT de dessiner le contenu de l'overlay. Headless-safe (love.graphics stubé -> no-op propre).
function Overlay.backdrop(_, dimLevel, anim)
  if not (love and love.graphics) then return end
  local a = (dimLevel or 0.6) * (anim or 1)
  if a <= 0 then return end
  local g = love.graphics
  local sw, sh = g.getDimensions()
  g.push(); g.origin()
  g.setColor(0.02, 0.012, 0.03, a)
  g.rectangle("fill", 0, 0, sw, sh)
  g.setColor(1, 1, 1, 1)
  g.pop()
end

-- ENROBAGE du contenu : pousse une transform qui AGRANDIT le groupe autour de son CENTRE (cx,cy en espace
-- DESIGN) selon scaleOf(anim, range), à appeler SOUS Draw.begin(view) juste avant de dessiner le contenu ;
-- refermer avec Overlay.popContent(). Le caller applique l'alpha lui-même (les couleurs portent l'alpha dans
-- ce kit). Pour un anim plein (1.0) c'est une transform identité -> rendu inchangé (pose finale = exactement
-- l'ancien rendu). Headless-safe. Renvoie l'alpha à appliquer (commodité).
function Overlay.pushContent(cx, cy, anim, range)
  if love and love.graphics then
    local s = Overlay.scaleOf(anim, range)
    love.graphics.push()
    love.graphics.translate(cx, cy)
    love.graphics.scale(s, s)
    love.graphics.translate(-cx, -cy)
  end
  return Overlay.alphaOf(anim)
end

function Overlay.popContent()
  if love and love.graphics then love.graphics.pop() end
end

return Overlay
