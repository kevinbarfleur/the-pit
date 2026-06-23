-- src/ui/feel.lua
-- LE JUICE de l'UI propre (bible docs/research/game-ui-implementation.md §4 « FEEL & impact » + §5 son).
-- Petit moteur d'ANIMATION + TIMING par id de bouton, RENDER-PUR et HEADLESS-SAFE : il ne touche JAMAIS la
-- SIM (combat/board/effects/run) — c'est du cosmétique piloté par le dt MURAL. Calibré GRIMDARK : lourd,
-- contenu, organique ; PAS le juice « mignon » de Balatro (pas d'élastique exubérant, pas de glow blanc).
--
-- CE QU'IL GÈRE (cf. §4) :
--   • HOVER immédiat : ease-out ~120 ms vers une cible (glow doux + lift de quelques px). On préfère
--     lift/glow au scale fractionnaire (casse la grille pixel) -> Feel n'émet PAS de scale, juste lift/glow.
--   • MICRO-FLOTTEMENT permanent (respiration) : deux sinus incommensurables, basse amplitude, LENT et
--     irrégulier (chair qui palpite, pas carte qui jiggle) -> pour les éléments héros (CTA).
--   • PRESS = feedback IMMÉDIAT au pointer-DOWN (squash ~95 % + flash bref), fenêtre 30–85 ms.
--   • ⭐ ACTION DIFFÉRÉE : Feel.press(id, action) joue le feedback TOUT DE SUITE et FILE l'action ~120–220 ms
--     plus tard (l'utilisateur SENT son clic avant que l'écran change). Feel.update(dt) fire les actions mûres.
--   • RELEASE : léger overshoot non-linéaire (backout) au retour du squash.
--   • INPUT-BUFFER / VERROU : un re-clic sur un bouton DÉJÀ en attente est ignoré (anti double-fire) ; les
--     autres ids restent indépendants -> un clic rapide n'est jamais « perdu » (chaque id a son créneau).
--   • HOOKS de son (§5) : Feel.onPress / Feel.onHover sont des champs OPTIONNELS (nil par défaut) ; Feel les
--     appelle s'ils existent. AUCUN audio ici (juste les points d'accroche, no-op si absent).
--
-- HORLOGE : les scènes passent dt en « frames » (~1.0 par tick au pas fixe 1/60 ; cf. main.lua FRAME=60).
-- Feel convertit en SECONDES (÷60) pour raisonner en ms comme la bible. Headless : le mock passe dt=1.0 ->
-- ~16,7 ms/appel, déterministe ; les easings convergent, les actions différées finissent par fire (testé).
--
-- API :
--   Feel.update(dtFrames)              -- avance tous les états + fire les actions différées mûres
--   Feel.hover(id, isOver)             -- pose la cible de survol (immédiat) ; tick son au passage 0->1
--   Feel.press(id, action, opts)       -- squash immédiat + flash + ARME l'action différée (opts.delay s)
--   Feel.fire(id, action, opts)        -- comme press MAIS sans verrou de re-clic (clavier : toujours agir)
--   Feel.state(id)                     -- { glow, lift, squash, flash, hover } à LIRE dans Button.draw
--   Feel.floatY(id, amp)               -- offset de respiration permanent (héros) ; 0 si amp absent
--   Feel.pending(id)                   -- true si une action est en attente sur cet id (verrou)
--   Feel.reset()                       -- vide tout (tests / changement de scène)

local Feel = {}

-- ── Réglages (en SECONDES, calibrage GRIMDARK = bord HAUT des fourchettes de la bible) ──────────────────
local HOVER_TAU   = 0.10   -- constante de temps du survol (ease-out ~100–150 ms ; glow + lift montent vite)
local PRESS_TAU   = 0.055  -- attaque du squash au DOWN (feedback perçu « au doigt » : 30–85 ms)
local RELEASE_TAU = 0.16   -- relâche du squash avec overshoot (backout) ~120–180 ms
local FLASH_TAU   = 0.09   -- extinction du flash de press (bref : ~1 frame perçu puis decay)
local LIFT_PX     = 3      -- lift de survol (px design) : on bouge le bouton, on ne le scale pas
local SQUASH_PX   = 2      -- enfoncement supplémentaire au press (px design) ; petit (grille pixel)
local FLASH_MAX   = 0.5    -- intensité du flash au DOWN (alpha additif ; braise, jamais blanc pur)
local GLOW_MAX    = 1.0    -- plafond du canal de survol (le bouton lit glow*intensité voulue)
local DELAY_DEF   = 0.16   -- délai par défaut de l'action différée (~160 ms : « optimum confortable »)
local BUFFER_MAX  = 0.5    -- au-delà, on ne garde plus une action mûre en file (filet anti-fuite)

-- ── État interne ────────────────────────────────────────────────────────────────────────────────────────
-- byId[id] = { glow, lift, squash, flash, hover(cible 0/1), pressV(impulsion vers le bas), wasOver }
local byId = {}
-- queue = file FIFO d'actions différées { id, action, t (restant), opts }
local queue = {}
-- t = horloge murale cumulée (secondes) -> phase de la respiration (continue, indépendante des ids)
local t = 0

local function st(id)
  local s = byId[id]
  if not s then
    s = { glow = 0, lift = 0, squash = 0, flash = 0, hover = 0, pressV = 0, wasOver = false }
    byId[id] = s
  end
  return s
end

-- Lissage exponentiel framerate-correct vers une cible : x += (target-x)*(1-exp(-dt/tau)). Stable quel que
-- soit dt (un gros dt headless ne dépasse pas la cible). tau petit = rapide (ease-out franc).
local function approach(x, target, dt, tau)
  if tau <= 0 then return target end
  local k = 1 - math.exp(-dt / tau)
  return x + (target - x) * k
end

-- ── Avance générale : easings + flottement + actions différées. dt en FRAMES (÷60 -> secondes). ──────────
function Feel.update(dtFrames)
  local dt = (dtFrames or 1) / 60
  if dt < 0 then dt = 0 end
  t = t + dt

  for _, s in pairs(byId) do
    -- HOVER : glow + lift suivent la cible en ease-out (asymétrie naturelle : même tau in/out, franc).
    s.glow = approach(s.glow, s.hover * GLOW_MAX, dt, HOVER_TAU)
    s.lift = approach(s.lift, s.hover * LIFT_PX, dt, HOVER_TAU)
    -- PRESS : pressV est une impulsion [0..1] posée au DOWN. Elle se relâche en overshoot (backout) :
    -- on la ramène vers 0 mais en PASSANT légèrement au-dessus du repos pour un retour non-linéaire « vivant ».
    s.pressV = approach(s.pressV, -0.10, dt, RELEASE_TAU) -- cible -0.10 = overshoot (remonte au-delà du repos)
    if s.pressV < 0 and s.pressV > -0.012 then s.pressV = 0 end -- snap propre près du repos
    -- squash effectif = part positive de l'impulsion (l'overshoot négatif sert au rebond du lift, pas au sink)
    s.squash = math.max(0, s.pressV) * SQUASH_PX
    -- FLASH : décroît vers 0 (bref).
    s.flash = approach(s.flash, 0, dt, FLASH_TAU)
    if s.flash < 0.003 then s.flash = 0 end
  end

  -- ACTIONS DIFFÉRÉES : décrémente, fire les mûres (FIFO). On itère sur une copie d'indices pour retirer sûr.
  if #queue > 0 then
    local keep = {}
    for _, q in ipairs(queue) do
      q.t = q.t - dt
      if q.t <= 0 then
        if q.action then q.action() end
        local s2 = byId[q.id]; if s2 then s2.pendingDepth = nil end
      elseif q.t < -BUFFER_MAX then
        -- filet : une action jamais firée (scène détruite ?) finit par être lâchée pour ne pas fuir.
        local s2 = byId[q.id]; if s2 then s2.pendingDepth = nil end
      else
        keep[#keep + 1] = q
      end
    end
    queue = keep
  end
end

-- ── Survol : pose la cible (0/1). Tick de son seulement au FRANCHISSEMENT not-over -> over (anti-spam). ──
function Feel.hover(id, isOver)
  local s = st(id)
  s.hover = isOver and 1 or 0
  if isOver and not s.wasOver then
    if Feel.onHover then Feel.onHover(id) end -- HOOK son optionnel (no-op si absent)
  end
  s.wasOver = isOver and true or false
end

-- Pose le feedback de press IMMÉDIAT (squash + flash) + (option) son. Helper interne partagé press/fire.
local function impulse(id)
  local s = st(id)
  s.pressV = 1.0          -- impulsion pleine (squash max au DOWN, fenêtre 30–85 ms ensuite)
  s.flash = FLASH_MAX
  if Feel.onPress then Feel.onPress(id) end -- HOOK son optionnel (au PRESS, même frame que le visuel)
end

-- ⭐ PRESS : feedback immédiat + arme l'action différée. VERROU : si une action est déjà en attente sur cet
-- id, on IGNORE le re-clic (anti double-achat / double-entrée) tout en re-jouant un petit feedback (jamais
-- de dead-click). Les AUTRES ids gardent leur propre créneau -> un clic rapide ailleurs n'est pas perdu.
function Feel.press(id, action, opts)
  opts = opts or {}
  local s = st(id)
  impulse(id) -- feedback TOUJOURS immédiat (même si verrouillé : on confirme le clic)
  if s.pendingDepth and s.pendingDepth > 0 then return false end -- déjà armé -> verrou, on ne re-file pas
  if action then
    s.pendingDepth = (s.pendingDepth or 0) + 1
    queue[#queue + 1] = { id = id, action = action, t = opts.delay or DELAY_DEF, opts = opts }
  end
  return true
end

-- FIRE : comme press mais SANS verrou de re-clic — pour le clavier (return/space), où l'on veut toujours
-- déclencher (et où il n'y a pas de risque de double-clic souris). Garde le feedback + l'action différée.
function Feel.fire(id, action, opts)
  opts = opts or {}
  impulse(id)
  if action then
    local s = st(id); s.pendingDepth = (s.pendingDepth or 0) + 1
    queue[#queue + 1] = { id = id, action = action, t = opts.delay or DELAY_DEF, opts = opts }
  end
  return true
end

-- État à LIRE dans le rendu (Button.draw / la scène). Toujours une table (id inconnu -> état neutre au repos).
function Feel.state(id)
  return byId[id] or { glow = 0, lift = 0, squash = 0, flash = 0, hover = 0 }
end

-- true tant qu'une action différée est en attente sur cet id (le bouton « est armé »). Utile aux scènes pour
-- éviter de ré-armer / pour un état visuel d'attente.
function Feel.pending(id)
  local s = byId[id]
  return (s and s.pendingDepth and s.pendingDepth > 0) and true or false
end

-- SEED/PHASE stable par id : somme des octets de l'id -> une graine déterministe et constante pour ce bouton
-- (désynchronise la respiration ET sème la nuée d'YEUX du CTA : même bouton -> même placement d'yeux entre
-- frames). Exposé pour que Button.draw (variant primary) demande une nuée seedée stable au survol. id nil -> 0.
function Feel.seedOf(id)
  local ph = 0
  if id then for i = 1, #id do ph = ph + string.byte(id, i) end end
  return ph
end

-- Offset vertical de RESPIRATION permanente (héros). amp en px design (sub-pixel toléré : c'est de l'overlay
-- natif, pas du sprite sur grille). Deux sinus incommensurables -> mouvement organique non périodique évident,
-- LENT (≈0,4 Hz dominant) : « chair qui palpite ». phase légèrement décalée par id pour désynchroniser.
function Feel.floatY(id, amp)
  if not amp or amp == 0 then return 0 end
  local p = Feel.seedOf(id) * 0.013 -- phase stable par id (désynchro douce)
  return (math.sin(t * 2.5 + p) * 0.62 + math.sin(t * 1.13 + p * 1.7) * 0.38) * amp
end

-- Vide tout (tests + changement de scène pour repartir au repos). N'efface pas l'horloge (continuité du float).
function Feel.reset()
  byId = {}
  queue = {}
end

return Feel
