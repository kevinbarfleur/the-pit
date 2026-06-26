-- feel-lab/lib/behavior.lua
-- BEHAVIORS COMPOSABLES — la réponse directe à « l'équivalent LÖVE des composants/effets réutilisables ».
-- Un behavior = une PETITE FONCTION PURE (id, rect, input, ...) qui DÉLÈGUE l'anim à Feel/Juice et renvoie un
-- delta de transform/visuel { dx, dy, glow, flash, scale, rot, alpha }. On les COMPOSE en chaîne (compose) ;
-- la somme des deltas = un seul transform à appliquer avant de dessiner n'importe quel composant existant,
-- SANS le modifier. C'est l'équivalent idiomatique des hooks/HOC/directives du web, posé au-dessus de Feel.
--
-- input = { over = bool, down = bool, clicked = bool } (état de la souris CE frame pour ce rect).
-- Render-pur, headless-safe (Feel/Juice le sont). Déterministe-cosmétique (pas de RNG de gameplay).
--
-- PROFIL : B.profile règle l'intensité du « candy » (0 = sobre/grimdark façon Feel ; 1 = exubérant façon
-- Balatro). Les behaviors lisent B.profile pour scaler scale/tilt -> comparaison de feeling à chaud.

local Feel  = require("lib.feel")
local Juice = require("lib.juice")

local B = { profile = 0.6 }   -- 0..1 (par défaut : entre grimdark et candy)

-- ── Behaviors atomiques ─────────────────────────────────────────────────────────────────────────────────

-- HOVERABLE : lift + glow (Feel) + un punch de scale au FRANCHISSEMENT de survol (juice_up, dosé par profil).
function B.hoverable(id, _, input)
  local wasOver = Feel.state(id).hover and Feel.state(id).hover > 0.5
  Feel.hover(id, input.over)                       -- gère lift/glow + son (hook) + anti-spam
  if input.over and not wasOver then
    Juice.juice_up(id, 0.05 + 0.07 * B.profile)    -- petit « rebond » d'accueil (candy)
  end
  local s = Feel.state(id)
  return { dy = -s.lift, glow = s.glow, scale = Juice.scale(id) }
end

-- PRESSABLE : squash + flash (Feel) ; au DOWN, un juice_up négatif (enfoncement) puis ressort (overshoot).
-- action différée via Feel.press (le clic se SENT avant que l'écran change). opts.delay / opts.sound.
function B.pressable(id, _, input, action, opts)
  opts = opts or {}
  if input.over and input.clicked then
    Juice.juice_up(id, -(0.10 + 0.05 * B.profile))  -- punch d'enfoncement -> rebond
    Feel.press(id, action, opts)
  end
  local s = Feel.state(id)
  return { dy = s.squash, flash = s.flash, scale = Juice.scale(id) }
end

-- PULSABLE : respiration permanente (héros / CTA). amp en px design.
function B.pulsable(id, _, _, amp)
  return { dy = Feel.floatY(id, amp or 1) }
end

-- SHAKEABLE : petite secousse de translation déclenchée à la demande (B.shake(id, mag)).
function B.shakeable(id, _, _)
  local dx, dy = Juice.offset(id)
  return { dx = dx, dy = dy, rot = Juice.rot(id) }
end
function B.shake(id, mag)
  mag = mag or 3
  Juice.nudge(id, (love and love.math.random() or math.random()) * 2 * mag - mag, 0)
  Juice.tilt(id, ((love and love.math.random() or math.random()) * 2 - 1) * 0.12)
end

-- ── DRAGGABLE — le cœur du feel Balatro (lead-and-follow découplé + tilt par vélocité) ───────────────────
-- État de drag porté par l'APPELANT (une petite table d), pour rester sans état global :
--   d = { dragging, gx, gy (logique = souris+grab), vx, vy, px, py (visuel suivi) }
-- B.dragBegin(d, mx, my, ox, oy) ; B.dragMove(d, mx, my) ; B.dragEnd(d) ; B.dragApply(d, dt) ; B.dragFx(d)
-- Formule canonique (Tom Delalande) : vel = vel*0.75 + (target-pos)*0.25 -> ressort/overshoot « bouncy ».
local FOLLOW   = 0.25   -- part de la cible dans le déplacement (0.25 = bouncy, 1 = snap dur)
local DAMP     = 0.75   -- conservation du momentum
local TILT_K   = 0.012  -- radians par px/s de vélocité X (clamp ±TILT_MAX)
local TILT_MAX = 0.16

function B.dragBegin(d, mx, my, ox, oy)
  d.dragging = true
  d.grabx, d.graby = ox or 0, oy or 0
  d.gx, d.gy = mx - d.grabx, my - d.graby
  d.px = d.px or d.gx; d.py = d.py or d.gy
  d.vx, d.vy = 0, 0
  d.lastx = d.gx
end
function B.dragMove(d, mx, my)
  if not d.dragging then return end
  d.gx, d.gy = mx - (d.grabx or 0), my - (d.graby or 0)
end
function B.dragEnd(d) d.dragging = false end

-- intègre le ressort (à appeler chaque frame avec dt en secondes). Renvoie px,py courants (position visuelle).
function B.dragApply(d, dt)
  if d.px == nil then d.px, d.py = d.gx or 0, d.gy or 0; d.vx, d.vy = 0, 0 end
  local tx, ty = d.gx or d.px, d.gy or d.py
  -- ressort discret « bouncy » (frame-rate ~normalisé : on échelle par dt*60 pour rester stable)
  local f = math.min(1, (dt or 1 / 60) * 60)
  d.vx = (d.vx or 0) * DAMP + (tx - d.px) * FOLLOW
  d.vy = (d.vy or 0) * DAMP + (ty - d.py) * FOLLOW
  d.px = d.px + d.vx * f
  d.py = d.py + d.vy * f
  -- tilt par vélocité X (inclinaison « tissu dans le vent ») — actif seulement pendant le drag
  if d.dragging then
    local target = math.max(-TILT_MAX, math.min(TILT_MAX, d.vx * TILT_K * 60))
    d.tilt = (d.tilt or 0) + (target - (d.tilt or 0)) * math.min(1, f * 0.25)
  else
    d.tilt = (d.tilt or 0) * (1 - math.min(1, f * 0.18))   -- revient à plat au repos
  end
  return d.px, d.py
end

-- delta visuel d'un drag (lift + scale au pickup + tilt). lift/scale dosés par profil.
function B.dragFx(d)
  local lift  = d.dragging and (8 + 6 * B.profile) or 0
  local scale = d.dragging and (1.04 + 0.06 * B.profile) or 1
  return { dy = -lift, scale = scale, rot = d.tilt or 0, shadow = d.dragging }
end

-- ── COMPOSITION ─────────────────────────────────────────────────────────────────────────────────────────
-- empile des behaviors -> une fonction (id, rect, input) qui SOMME leurs deltas en un seul fx.
-- chaque entrée : soit une fonction behavior, soit { fn, ...args } pour passer des arguments (ex. pressable).
function B.compose(...)
  local list = { ... }
  return function(id, rect, input)
    local fx = { dx = 0, dy = 0, glow = 0, flash = 0, scale = 1, rot = 0, alpha = 1 }
    for _, beh in ipairs(list) do
      local r
      if type(beh) == "table" then
        r = beh[1](id, rect, input, beh[2], beh[3], beh[4])
      else
        r = beh(id, rect, input)
      end
      if r then
        fx.dx = fx.dx + (r.dx or 0)
        fx.dy = fx.dy + (r.dy or 0)
        fx.glow = math.max(fx.glow, r.glow or 0)
        fx.flash = math.max(fx.flash, r.flash or 0)
        fx.rot = fx.rot + (r.rot or 0)
        if r.scale then fx.scale = fx.scale * r.scale end
        if r.alpha then fx.alpha = math.min(fx.alpha, r.alpha) end
        if r.shadow then fx.shadow = true end
      end
    end
    return fx
  end
end

-- helper hit-test (rect design) commun aux rooms.
function B.hit(rect, mx, my)
  return mx >= rect.x and mx <= rect.x + rect.w and my >= rect.y and my <= rect.y + rect.h
end

return B
