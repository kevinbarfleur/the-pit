-- src/ui/drag.lua
-- RESSORT DE DRAG « Balatro » — transplanté À L'IDENTIQUE depuis feel-lab/lib/behavior.lua (B.dragXxx),
-- source de vérité validée du feeling. On NE ré-invente pas : on porte le ressort découplé bouncy + le tilt
-- par vélocité + le lift/ombre au pickup, et on les câble sur les VRAIS jetons du plateau (build.lua).
--
-- 100% RENDER/cosmétique : Drag ne pilote QUE la position VISUELLE (px, py affichés). La LOGIQUE du build
-- (quelle pièce dans quelle case, achat/vente/fusion/niveau) reste INSTANTANÉE et inchangée — résolue par
-- build:mousereleased, jamais ici. Le sprite RATTRAPE ensuite sa cible logique en glissant. Headless-safe :
-- maths pures (math.exp/min/max), zéro love.* ; le mock pilote les drags et le ressort converge en dt mock.
--
-- ÉTAT porté par l'APPELANT (une petite table `d` par jeton, sans état global) :
--   d = { dragging, grabx, graby, gx, gy (= cible logique), vx, vy, px, py (= position visuelle suivie), tilt }
-- gx,gy = où la pièce VEUT être ce frame (souris+grab pendant le drag, sinon le centre de sa case/banc).
-- px,py = où elle EST visuellement (rattrape gx,gy par ressort).
--
-- Formule canonique (Tom Delalande / feel Balatro) : vel = vel*DAMP + (cible-pos)*FOLLOW -> overshoot « bouncy ».
-- Frame-rate ~normalisé : on échelle le pas par dt*60 pour rester stable quel que soit le framerate (et le gros
-- dt headless ne fait pas exploser le ressort : le pas est borné à 1).
--
-- API (miroir du lab) :
--   Drag.begin(d, mx, my, grabx, graby)  -- saisit : la cible = souris-grab, vélocité remise à 0
--   Drag.move(d, mx, my)                 -- déplace la cible pendant le drag
--   Drag.stop(d)                         -- relâche (le ressort continue de rattraper la cible logique)
--   Drag.setTarget(d, tx, ty)            -- pose la cible logique d'un jeton AU REPOS (sa case / son banc)
--   Drag.apply(d, dt) -> px, py          -- intègre le ressort 1 frame (dt en SECONDES MURALES) ; renvoie px,py
--   Drag.fx(d) -> { dy, scale, rot, shadow }  -- delta visuel (lift + scale + tilt + ombre au pickup)
--   Drag.snap(d, x, y)                   -- pose px,py = gx,gy = (x,y) instantanément (montage / téléportation rare)

local Drag = {}

-- Réglages (identiques à feel-lab/lib/behavior.lua — calibrage validé) :
local FOLLOW   = 0.25   -- part de la cible dans le déplacement (0.25 = bouncy ; 1 = snap dur)
local DAMP     = 0.75   -- conservation du momentum
local TILT_K   = 0.012  -- radians par px/s de vélocité X (clamp ±TILT_MAX)
local TILT_MAX = 0.16
-- profil grimdark (≈ B.profile du lab, posé sur 0.6 par défaut) -> dose le lift/scale du pickup.
local PROFILE  = 0.6

function Drag.begin(d, mx, my, grabx, graby)
  d.dragging = true
  d.grabx, d.graby = grabx or 0, graby or 0
  d.gx, d.gy = mx - d.grabx, my - d.graby
  d.px = d.px or d.gx; d.py = d.py or d.gy
  d.vx, d.vy = 0, 0
end

function Drag.move(d, mx, my)
  if not d.dragging then return end
  d.gx, d.gy = mx - (d.grabx or 0), my - (d.graby or 0)
end

function Drag.stop(d) d.dragging = false end

-- Cible logique d'un jeton AU REPOS (sa case / son banc) : lue par apply pour le rattrapage en ressort.
function Drag.setTarget(d, tx, ty)
  d.gx, d.gy = tx, ty
end

-- Pose px,py = gx,gy = (x,y) D'UN COUP (1re frame d'une pièce / placement direct sans glisse souhaitée).
function Drag.snap(d, x, y)
  d.px, d.py, d.gx, d.gy = x, y, x, y
  d.vx, d.vy, d.tilt = 0, 0, 0
end

-- Intègre le ressort amorti (à appeler chaque frame, dt en SECONDES). Renvoie la position visuelle (px,py).
function Drag.apply(d, dt)
  if d.px == nil then d.px, d.py = d.gx or 0, d.gy or 0; d.vx, d.vy = 0, 0 end
  local tx, ty = d.gx or d.px, d.gy or d.py
  -- ressort discret « bouncy » (frame-rate ~normalisé : on échelle par dt*60, pas borné à 1 -> stable)
  local f = math.min(1, (dt or 1 / 60) * 60)
  d.vx = (d.vx or 0) * DAMP + (tx - d.px) * FOLLOW
  d.vy = (d.vy or 0) * DAMP + (ty - d.py) * FOLLOW
  d.px = d.px + d.vx * f
  d.py = d.py + d.vy * f
  -- tilt par vélocité X (« tissu dans le vent ») — actif seulement pendant le drag ; revient à plat au repos.
  if d.dragging then
    local target = math.max(-TILT_MAX, math.min(TILT_MAX, d.vx * TILT_K * 60))
    d.tilt = (d.tilt or 0) + (target - (d.tilt or 0)) * math.min(1, f * 0.25)
  else
    d.tilt = (d.tilt or 0) * (1 - math.min(1, f * 0.18))
  end
  return d.px, d.py
end

-- Delta visuel d'un drag : lift + scale au pickup + tilt (lift/scale dosés par le profil grimdark).
-- `liftPx` (optionnel) règle l'amplitude du soulèvement dans l'ESPACE de l'appelant : le lab travaille en
-- design 1280×720 (~11px), le board de build dessine en VIRTUEL 320×180 -> on passe ~3px (échelle du sprite,
-- cohérente avec le sautillement de fusion `bounceLift` = 3px). Défaut = la valeur design du lab.
function Drag.fx(d, liftPx)
  local L     = liftPx or (8 + 6 * PROFILE)
  local lift  = d.dragging and L or 0
  local scale = d.dragging and (1.04 + 0.06 * PROFILE) or 1
  return { dy = -lift, scale = scale, rot = d.tilt or 0, shadow = d.dragging }
end

return Drag
