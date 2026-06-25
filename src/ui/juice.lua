-- src/ui/juice.lua
-- LA COUCHE « CANDY » du game feel — sœur de src/ui/feel.lua (même famille, même contrat). Feel est calibré
-- GRIMDARK et n'émet VOLONTAIREMENT pas de scale (lift/glow seulement) ; Juice porte ce que Feel ne fait pas :
-- punch de SCALE en ressort (squash & stretch), TILT, SCREEN-SHAKE trauma² (Eiserloh/Vlambeer) via
-- love.math.noise, et HITSTOP (gel bref du monde). Transplanté À L'IDENTIQUE depuis le Feel Lab (feel-lab/
-- lib/juice.lua), source de vérité validée du feeling — on ne ré-invente pas, on câble les vrais composants.
--
-- 100% RENDER/cosmétique, piloté par le dt MURAL : Juice ne lit/écrit JAMAIS la SIM (combat/board/effects/run).
-- Le screen-shake/hitstop s'accroche AUTOUR de la boucle de rendu (main.lua) et écoute le bus d'évènements via
-- les couches RENDER (arena_draw) ; il ne touche jamais arena.lua. Headless-safe : love.math.noise existe aussi
-- sous un vrai LÖVE headless, mais le mock de test ne le fournit pas -> repli sinus déterministe (no-op visuel).
--
-- DÉTERMINISME : le hitstop ne fait que RETARDER la consommation des pas de sim À L'ÉCRAN ; le total de pas
-- reste piloté par le pas fixe seedé -> aucune empreinte sur le golden. (cf. main.lua : Juice.timeScale() ne
-- multiplie QUE le dt de la scène, jamais Feel/Juice eux-mêmes.)
--
-- Modèle : chaque canal par-id est un RESSORT amorti (position+vélocité) -> overshoot organique gratuit.
--   juice_up(id, amount)  -> impulsion de scale (punch qui dépasse 1.0 puis revient en oscillant)
--   nudge(id, ax, ay)     -> impulsion de translation (ex. rebond au drop)
--   tilt(id, amount)      -> impulsion de rotation (ex. secousse de carte)
-- Lecture : Juice.scale(id) -> multiplicateur ~1.0 ; Juice.offset(id) -> dx,dy ; Juice.rot(id) -> radians.
--
-- GLOBAL :
--   addTrauma(amount)     -> empile du trauma [0..1] ; shake() -> dx,dy,rot (= maxOffset*trauma^2*noise)
--   freeze(seconds)       -> hitstop ; timeScale() -> 0 pendant le gel, 1 sinon (le timer ignore le gel)
--
-- API :
--   Juice.update(dt)                 -- dt en SECONDES MURALES (ressorts framerate-correct + decay trauma + hitstop)
--   Juice.juice_up(id, amount)       -- punch de scale (defaut 0.14)
--   Juice.nudge(id, ax, ay)          -- impulsion de translation
--   Juice.tilt(id, amount)           -- impulsion de rotation (radians)
--   Juice.setTiltTarget(id, rad)     -- pose une CIBLE de tilt suivie en lerp (drag : inclinaison par vélocité)
--   Juice.scale(id) -> number        -- multiplicateur (1.0 au repos)
--   Juice.offset(id) -> dx, dy
--   Juice.rot(id) -> number
--   Juice.addTrauma(a)               -- gros évènement +0.5, petit +0.15 (clamp 1)
--   Juice.shake() -> dx, dy, rot     -- secousse caméra courante (en px DESIGN 1280×720 + radians)
--   Juice.freeze(sec)                -- hitstop (ne s'empile pas : garde le plus long)
--   Juice.timeScale() -> 0|1         -- à multiplier au dt de gameplay (on gèle le monde, jamais l'UI/le juice)
--   Juice.reset()

local Juice = {}

-- ── Réglages des ressorts (par-id) ──────────────────────────────────────────────────────────────────────
-- Stiffness/damping calibrés pour un overshoot net mais bref (squash & stretch « vivant », pas mou).
local STIFF      = 420    -- raideur du ressort de scale (haut = revient vite)
local DAMP       = 22     -- amortissement (bas = plus d'oscillations/overshoot)
local STIFF_POS  = 360
local DAMP_POS   = 26
local STIFF_ROT  = 300
local DAMP_ROT   = 20
local TILT_TAU   = 0.09   -- suivi de la cible de tilt (drag) : ease-out ~90ms

-- ── Réglages du screen-shake trauma-based (réf Eiserloh/Vlambeer ; valeurs en px DESIGN 1280×720) ────────
local MAX_OFFSET = 22     -- amplitude max de translation (à trauma=1) — modeste, on tune en contexte
local MAX_ROLL   = 0.05   -- amplitude max de rotation (radians) — à doser, sparingly
local SHAKE_FREQ = 18     -- Hz de l'échantillonnage de bruit (trop haut = jittery, trop bas = roulis lent)
local TRAUMA_POW = 2      -- exposant (2 = petits chocs quasi-nuls, gros chocs énormes)
local DECAY      = 1.1    -- vitesse d'extinction du trauma/s (1.0 trauma s'éteint en ~0.9s)

-- ── État ────────────────────────────────────────────────────────────────────────────────────────────────
local byId = {}
local trauma = 0
local freezeT = 0          -- temps de hitstop restant (secondes)
local t = 0                -- horloge murale cumulée (phase du bruit de shake)

local function st(id)
  local s = byId[id]
  if not s then
    s = { sc = 0, scV = 0, ox = 0, oxV = 0, oy = 0, oyV = 0, rt = 0, rtV = 0, tiltTarget = nil }
    byId[id] = s
  end
  return s
end

-- intégrateur de ressort amorti (semi-implicite, stable) vers 0
local function spring(x, v, dt, k, d)
  local a = -k * x - d * v
  v = v + a * dt
  x = x + v * dt
  return x, v
end

function Juice.update(dt)
  if not dt or dt < 0 then dt = 0 end
  if dt > 0.05 then dt = 0.05 end   -- borne (anti-explosion si gros hoquet de frame)
  t = t + dt

  -- hitstop : décrémente avec le dt RÉEL (il doit finir même si le « monde » est gelé)
  if freezeT > 0 then freezeT = math.max(0, freezeT - dt) end

  -- ressorts par-id
  for _, s in pairs(byId) do
    s.sc, s.scV = spring(s.sc, s.scV, dt, STIFF, DAMP)
    s.ox, s.oxV = spring(s.ox, s.oxV, dt, STIFF_POS, DAMP_POS)
    s.oy, s.oyV = spring(s.oy, s.oyV, dt, STIFF_POS, DAMP_POS)
    if s.tiltTarget then
      -- suivi d'une cible de tilt (drag) : ease-out framerate-correct
      local k = 1 - math.exp(-dt / TILT_TAU)
      s.rt = s.rt + (s.tiltTarget - s.rt) * k
      s.rtV = 0
    else
      s.rt, s.rtV = spring(s.rt, s.rtV, dt, STIFF_ROT, DAMP_ROT)
    end
  end

  -- trauma -> decay linéaire (clamp 0)
  if trauma > 0 then trauma = math.max(0, trauma - DECAY * dt) end
end

-- ── Impulsions ──────────────────────────────────────────────────────────────────────────────────────────
function Juice.juice_up(id, amount)
  local s = st(id)
  s.scV = s.scV + (amount or 0.14) * STIFF * 0.06   -- impulsion de vélocité -> overshoot
end
function Juice.nudge(id, ax, ay)
  local s = st(id)
  s.oxV = s.oxV + (ax or 0) * STIFF_POS * 0.05
  s.oyV = s.oyV + (ay or 0) * STIFF_POS * 0.05
end
function Juice.tilt(id, amount)
  local s = st(id); s.tiltTarget = nil
  s.rtV = s.rtV + (amount or 0.1) * STIFF_ROT * 0.05
end
function Juice.setTiltTarget(id, rad)
  local s = st(id); s.tiltTarget = rad
end
function Juice.clearTiltTarget(id)
  local s = byId[id]; if s then s.tiltTarget = nil end
end

-- ── Lectures ────────────────────────────────────────────────────────────────────────────────────────────
function Juice.scale(id) local s = byId[id]; return s and (1 + s.sc) or 1 end
function Juice.offset(id) local s = byId[id]; if not s then return 0, 0 end return s.ox, s.oy end
function Juice.rot(id) local s = byId[id]; return s and s.rt or 0 end

-- ── Screen-shake global (trauma²) ───────────────────────────────────────────────────────────────────────
function Juice.addTrauma(a) trauma = math.min(1, trauma + (a or 0.3)) end
function Juice.trauma() return trauma end

-- bruit dans [-1,1] : love.math.noise(∈[0,1]) recentré ; repli sinus si love.math.noise absent (mock de test).
local function noise1(seed)
  if love and love.math and love.math.noise then
    return love.math.noise(seed, t * SHAKE_FREQ) * 2 - 1
  end
  return math.sin((seed * 12.9898 + t * SHAKE_FREQ) * 1.0)
end
function Juice.shake()
  if trauma <= 0 then return 0, 0, 0 end
  local s = trauma ^ TRAUMA_POW
  return MAX_OFFSET * s * noise1(1.3),
         MAX_OFFSET * s * noise1(7.7),
         MAX_ROLL   * s * noise1(13.1)
end

-- ── Hitstop ─────────────────────────────────────────────────────────────────────────────────────────────
function Juice.freeze(sec) freezeT = math.max(freezeT, sec or 0.06) end
function Juice.timeScale() return freezeT > 0 and 0 or 1 end
function Juice.frozen() return freezeT > 0 end

function Juice.reset()
  byId = {}; trauma = 0; freezeT = 0
end

return Juice
