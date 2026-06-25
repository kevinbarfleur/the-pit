-- src/render/critter.lua
-- RENDU VIVANT des créatures — port du prototype HTML (`blit`/`disp`). Au lieu de transformer un sprite BAKÉ
-- figé, on re-dessine la GRILLE 64×64 à CHAQUE frame avec un déplacement PAR PIXEL propre à la famille
-- (respiration, balancement planté aux pieds, lévitation, ailes qui battent, tentacules, ondulation) + un
-- overlay des YEUX (clignement + saccade de pupille). Rendu en CADRE NATIF : échelle UNIFORME (cadre→boîte),
-- donc les tailles RELATIVES et le placement vertical des créatures sont CONSERVÉS (contrairement au fit-
-- silhouette qui zoome tout le monde pareil). Ombre au sol pour ancrer la baseline (les flottants la laissent
-- au sol → lecture de lévitation).
--
-- Couche RENDER (love.graphics) — hors firewall SIM. HEADLESS-SAFE : no-op sans SpriteBatch (mock LÖVE).
-- DÉTERMINISTE PAR ID : grille via CreatureGen.cachedLive (MÊME résolution famille/arch/palette/seed que la
-- version bakée → visuel identique). `t` = horloge en SECONDES (fréquences = celles du proto, en rad/s).

local CreatureGen = require("src.gen.creaturegen")
local Units = require("src.data.units")
local Creatures = require("src.data.creatures")

local Critter = {}
local sin, cos, floor, abs, max = math.sin, math.cos, math.floor, math.abs, math.max
local sqrt, atan2, exp, min = math.sqrt, math.atan2, math.exp, math.min
local function hypot(a, b) return sqrt(a * a + b * b) end

local EMPTY = {}            -- table vide partagée (évite des allocs ; lue en LECTURE seule)
local EMPTY_PR = {}         -- params d'attaque par défaut
local DEFAULT_HEAD = { x = 32, y = 26, r = 4 } -- tête de repli si A.head absente (proto: {x:32,y:26,r:4})
local DEFAULT_MASS0 = { 32, 34, 9 }            -- masse de repli si A.mass absente (proto fallback)
-- gerbe de sang : couleurs fixes du proto (deathFx l.863). En floats 0..1 (#7d1426 / #34060f).
local BLOOD_COL = { 0x7d / 255, 0x14 / 255, 0x26 / 255 }
local DARK_COL = { 0x34 / 255, 0x06 / 255, 0x0f / 255 }

-- ── Tables d'anim de réaction (port DIRECT du proto l.769-811, 880-897 ; cross-check bestiary-dictionary.json) ──
-- ATK : FORME -> descripteur d'attaque {k=kind, ...params}. 18 kinds. Couvre les 102 formes + alias legacy.
-- HURT/DEATH : FAMILLE -> kind (8 hurt, 7 death). Résolus par d.arch / d.family (cf. Critter.atkFor/hurtFor/deathFor).
-- Données PURES, append-only. Fallbacks sûrs : atk -> lunge, hurt -> recoil, death -> gib (clé absente).
local ATK = {
  -- ELDER (pièces maîtresses imp 9-10)
  voidtyrant = { k = "lash" }, devourer = { k = "bite" }, skulltitan = { k = "gaze" },
  juggernaut = { k = "slam" }, veiledking = { k = "cast" }, broodmother = { k = "lunge" },
  broodsac = { k = "engulf" }, bilesac = { k = "spew" }, chrysalis = { k = "lash" }, embersac = { k = "multi" },
  -- cauchemar
  bouffi = { k = "bite" }, pendu = { k = "lash", reach = 7 }, fleshcrawler = { k = "bite" },
  -- mortvivant
  skeleton = { k = "swing", side = -1 }, skeletonquad = { k = "pounce" }, revenant = { k = "claw" },
  -- bete
  dragon = { k = "bite", reach = 7 }, behemoth = { k = "pounce", reach = 7, leap = 4 }, direcat = { k = "pounce" },
  centaur = { k = "pounce" },
  -- demon
  fiend = { k = "claw" }, serpent = { k = "bite" }, imp = { k = "claw" },
  -- insecte
  insectoid = { k = "bite" }, mantis = { k = "claw", reach = 8 },
  -- cephalo
  octopus = { k = "lash" }, squid = { k = "lash" }, reef = { k = "lash" },
  -- gelatine
  slime = { k = "lunge", reach = 7 }, ooze = { k = "lunge", reach = 7 }, blobmonster = { k = "lunge", reach = 8 },
  -- oeil
  eyeball = { k = "gaze" }, eyecluster = { k = "gaze" }, eyeswarm = { k = "gaze" },
  -- golem
  golem = { k = "slam" }, sentinel = { k = "shard" }, idol = { k = "cast" },
  -- spectre
  wraith = { k = "phase", reach = 7 }, veiledlady = { k = "phase", reach = 7 }, howler = { k = "phase", reach = 7 },
  -- culte
  cultist = { k = "cast" }, hierophant = { k = "cast" }, possessed = { k = "lash" },
  -- spore
  sporewalker = { k = "spew" }, myconid = { k = "spew" }, infectedhost = { k = "spew" },
  -- abyssal
  anglerfish = { k = "bite", reach = 7 }, deepone = { k = "claw" }, moray = { k = "bite" },
  -- cristal
  crystalcluster = { k = "shard" }, shardwalker = { k = "shard" }, prism = { k = "shard" },
  -- aile
  byakhee = { k = "wing" }, harpy = { k = "claw" }, carrionflyer = { k = "wing" },
  -- colosse
  ogre = { k = "slam" }, cyclops = { k = "slam" }, troll = { k = "claw", reach = 8 },
  -- ombre
  shade = { k = "phase" }, voidmaw = { k = "engulf", mouth = { 32, 38 }, mr = 13 },
  -- essaim
  swarm = { k = "surge", reach = 9 }, hive = { k = "surge", reach = 9 },
  -- annelide
  graboid = { k = "bite", reach = 9 }, leech = { k = "bite", reach = 9 },
  -- templier
  crusader = { k = "swing", side = -1 }, sentinelshield = { k = "lunge", reach = 6 }, paladin = { k = "swing", side = 1 },
  -- inquisiteur
  inquisitor = { k = "smite" }, zealot = { k = "cast" }, confessor = { k = "smite" },
  -- seraphin
  seraph = { k = "smite" }, throne = { k = "smite" },
  -- griffon
  gryphon = { k = "pounce" }, hippogriff = { k = "pounce" },
  -- bandit
  cutthroat = { k = "claw", reach = 7 }, brigand = { k = "claw", reach = 7 }, cutpurse = { k = "lunge", reach = 7 },
  -- canide
  wolf = { k = "pounce" }, hound = { k = "pounce" }, jackal = { k = "pounce" },
  -- reptile
  coilserpent = { k = "bite" }, cobra = { k = "bite", reach = 7 }, lizard = { k = "bite" },
  -- rongeur
  ratgiant = { k = "bite" }, ratking = { k = "surge", reach = 8 },
  -- arachnide
  spider = { k = "skitter", ox = 32, oy = 37 }, widow = { k = "skitter", ox = 32, oy = 38 },
  -- crustace
  crab = { k = "claw", reach = 8 }, mantisshrimp = { k = "lunge", reach = 8 },
  -- meduse
  jelly = { k = "lash" }, siphon = { k = "lash" },
  -- echassier
  strider = { k = "bite", reach = 7 }, heron = { k = "bite", reach = 7 },
  -- wendigo
  wendigo = { k = "claw", reach = 7 }, stag = { k = "lunge", reach = 7 },
  -- hydre
  hydra = { k = "bite", reach = 7 },
  -- kraken
  kraken = { k = "lash", reach = 8 },
  -- pendu (marionnettes)
  marionette = { k = "phase" }, hanged = { k = "phase" },
  -- chimere (5 sous-attaques calées sur le dessin de aChimera — coords du proto l.805)
  chimera = { k = "multi", loops = 2, parts = {
    { x = 26, y = 22, r = 6, fd = { -1, -0.2 }, mode = "bite", reach = 7, off = 0 },
    { x = 36, y = 24, r = 5, fd = { 1, -0.1 }, mode = "bite", reach = 6, off = 0.4 },
    { x = 30, y = 12, r = 5, fd = { 0, -1 }, mode = "bite", reach = 6, off = 0.7 },
    { x = 12, y = 36, r = 6, fd = { -1, 0 }, mode = "swipe", reach = 8, off = 0.2 },
    { x = 40, y = 30, r = 6, fd = { 1, -0.3 }, mode = "swipe", reach = 6, off = 0.55 },
  } },
  -- cocon générique (legacy)
  cocoon = { k = "spew" },
  -- plante
  maweed = { k = "bite" }, vinemaw = { k = "lash" },
  -- larve
  grub = { k = "bite" },
  -- crane
  skullking = { k = "bite", reach = 6 },
  -- automate
  automaton = { k = "cast" }, reliquary = { k = "smite" },
}
local ATK_FALLBACK = { k = "lunge" } -- forme inconnue -> attaque générique (bond)
local HURT = {
  cauchemar = "waver", mortvivant = "recoil", bete = "recoil", demon = "recoil", insecte = "jolt",
  cephalo = "clench", gelatine = "jelly", golem = "jolt", spectre = "waver", culte = "recoil", spore = "recoil",
  abyssal = "clench", cristal = "jolt", aile = "flinchfly", colosse = "recoil", ombre = "waver", essaim = "scatter",
  annelide = "kink", templier = "recoil", inquisiteur = "recoil", seraphin = "flinchfly", griffon = "flinchfly",
  bandit = "recoil", canide = "recoil", reptile = "kink", rongeur = "recoil", arachnide = "jolt", crustace = "jolt",
  meduse = "clench", echassier = "recoil", wendigo = "recoil", hydre = "kink", kraken = "clench", pendu = "recoil",
  chimere = "recoil", cocon = "jelly", plante = "kink", larve = "jelly", crane = "jolt", automate = "jolt",
}
local DEATH = {
  cauchemar = "disintegrate", mortvivant = "gib", bete = "gib", demon = "gib", insecte = "gib",
  cephalo = "burstLimp", gelatine = "splatter", golem = "crumble", spectre = "disintegrate", culte = "gib",
  spore = "splatter", abyssal = "burstLimp", cristal = "shatter", aile = "gib", colosse = "gib",
  ombre = "disintegrate", essaim = "disintegrate", annelide = "unravel", templier = "gib", inquisiteur = "gib",
  seraphin = "gib", griffon = "gib", bandit = "gib", canide = "gib", reptile = "unravel", rongeur = "gib",
  arachnide = "gib", crustace = "gib", meduse = "burstLimp", echassier = "gib", wendigo = "gib", hydre = "unravel",
  kraken = "burstLimp", pendu = "gib", chimere = "gib", cocon = "splatter", plante = "gib", larve = "splatter",
  crane = "crumble", automate = "crumble",
}

local CELL = 1.3 -- léger sur-dessin de chaque cellule (couvre les trous quand les pixels se déplacent)

-- ── Profils de mouvement PAR FAMILLE (port direct de `PROF` du proto) ──
-- amplitudes en px de grille, fréquences en rad/s. eyes = { blink, dart } (dart absent -> 1.4 ; comme le proto).
local PROF_DEFAULT = { breathe = { 0.018, 1.8 }, eyes = { 0.9, 1.3 } }
local PROF = {
  -- amorphes / chair molle
  cauchemar   = { breathe = { 0.03, 1.6 }, eyes = { 0.8, 1.2 } },
  gelatine    = { breathe = { 0.05, 2.2 }, eyes = { 0.8, 1.2 } },
  larve       = { writhe = { 0.8, 2.8 }, breathe = { 0.04, 2.2 }, eyes = { 1.1 } },
  cocon       = { breathe = { 0.045, 1.4 }, eyes = { 0.6, 1.0 } },
  chimere     = { writhe = { 0.7, 2.6 }, breathe = { 0.03, 1.8 }, eyes = { 0.9, 1.5 } },
  -- marcheurs / bêtes
  bete        = { legs = { 0.7, 3.0 }, breathe = { 0.02, 2.0 }, eyes = { 0.9, 1.2 } },
  demon       = { sway = { 1.0, 1.8 }, breathe = { 0.02, 2.0 }, eyes = { 0.8, 1.3 } },
  colosse     = { legs = { 0.6, 2.4 }, breathe = { 0.025, 1.8 }, eyes = { 0.8, 1.1 } },
  canide      = { legs = { 0.55, 3.2 }, breathe = { 0.03, 2.6 }, eyes = { 1.0, 1.3 } },
  bandit      = { breathe = { 0.022, 2.0 }, sway = { 0.4, 1.4 }, eyes = { 1.0, 1.6 } },
  culte       = { sway = { 0.8, 1.6 }, breathe = { 0.02, 1.8 }, eyes = { 0.9 } },
  inquisiteur = { sway = { 0.6, 1.6 }, breathe = { 0.02, 1.7 }, eyes = { 0.8 } },
  templier    = { legs = { 0.35, 2.0 }, breathe = { 0.02, 1.7 }, eyes = { 0.8 } },
  wendigo     = { sway = { 0.7, 1.5 }, breathe = { 0.025, 1.6 }, eyes = { 0.8, 1.2 } },
  echassier   = { legs = { 0.6, 2.2 }, sway = { 0.7, 1.6 }, eyes = { 0.9, 1.3 } },
  -- os / minéral / mécanique (quasi statiques)
  mortvivant  = { legs = { 0.5, 3.2 }, writhe = { 0.3, 2.2 }, eyes = { 1.1 } },
  crane       = { breathe = { 0.015, 1.2 }, eyes = { 0.6, 1.6 } },
  cristal     = { breathe = { 0.02, 1.4 }, eyes = { 0.7, 1.0 } },
  golem       = { legs = { 0.4, 2.2 }, eyes = { 0.7 } },
  automate    = { legs = { 0.4, 2.6 }, eyes = { 0.5, 1.0 } },
  -- segmentés / nerveux
  insecte     = { legs = { 0.5, 4.2 }, writhe = { 0.4, 3.0 }, eyes = { 1.0 } },
  arachnide   = { legs = { 0.6, 3.6 }, breathe = { 0.025, 2.0 }, eyes = { 1.0 } },
  crustace    = { legs = { 0.5, 3.4 }, breathe = { 0.025, 2.0 }, eyes = { 0.9, 1.5 } },
  rongeur     = { breathe = { 0.045, 3.6 }, legs = { 0.4, 4.0 }, eyes = { 1.4 } },
  -- reptiles / vers / hydres / plantes (ondulation)
  reptile     = { sway = { 1.0, 1.8 }, breathe = { 0.02, 1.8 }, eyes = { 0.8, 1.4 } },
  annelide    = { sway = { 1.2, 2.0 }, breathe = { 0.025, 1.8 }, eyes = { 0.9 } },
  hydre       = { sway = { 1.1, 1.9 }, breathe = { 0.02, 1.7 }, eyes = { 0.9, 1.4 } },
  plante      = { sway = { 0.9, 1.6 }, breathe = { 0.035, 1.8 }, eyes = { 0.9, 1.3 } },
  spore       = { sway = { 0.7, 1.5 }, breathe = { 0.03, 1.6 }, eyes = { 0.9 } },
  -- FLOTTANTS : lévitation d'ensemble (bob) + signature
  oeil        = { bob = { 0.9, 1.5 }, breathe = { 0.02, 1.7 }, eyes = { 0.9, 1.5 } },
  ombre       = { bob = { 1.4, 1.4 }, breathe = { 0.04, 1.6 }, eyes = { 0.9, 1.8 } },
  spectre     = { bob = { 1.4, 1.5 }, sway = { 1.2, 1.2 }, eyes = { 0.8 } },
  aile        = { flap = { 0.22, 3.6, 0.06 }, bob = { 1.2, 1.8 }, eyes = { 0.9, 1.3 } },
  seraphin    = { flap = { 0.2, 3.0, 0.05 }, bob = { 1.2, 1.5 }, eyes = { 0.9, 1.6 } },
  griffon     = { legs = { 0.5, 2.8 }, flap = { 0.14, 3.2, 0.04 }, eyes = { 0.9, 1.2 } },
  meduse      = { bob = { 1.3, 1.6 }, tentacles = { 1.2, 2.0 }, breathe = { 0.04, 1.8 }, eyes = { 0.9 } },
  essaim      = { writhe = { 0.8, 3.2 }, bob = { 0.8, 1.6 }, eyes = { 1.2 } },
  abyssal     = { bob = { 1.0, 1.6 }, tentacles = { 1.0, 2.2 }, eyes = { 0.9, 1.5 } },
  cephalo     = { tentacles = { 1.3, 2.4 }, breathe = { 0.03, 1.8 }, eyes = { 0.9, 1.4 } },
  kraken      = { sway = { 1.2, 2.0 }, tentacles = { 1.3, 2.2 }, eyes = { 0.9, 1.4 } },
  pendu       = { bob = { 1.2, 1.3 }, sway = { 1.0, 1.1 }, eyes = { 0.8 } },
}

-- ═══════════════════ MOTEUR DE RÉACTIONS (attack / hurt / death) ═══════════════════
-- Port FIDÈLE des moteurs v3/v2 du proto (generateur-bestiaire.html l.716-897). Tout est PUR (math),
-- donc snapshot-safe : `_h2` = bruit déterministe = fract de `(x*12.9898+y*78.233)*43758.5453` — reproductible
-- bit-à-bit en double IEEE (comme le `bucket` PHI), AUCUN sin ici (le proto n'en met pas — fidélité à la source).
-- Ces 3 couches s'AJOUTENT au déplacement idle dans fillBatch (atk/hurt) ; death s'applique à part car il porte
-- AUSSI un alpha par cellule. Les coords passées sont en ESPACE GRILLE (comme idle). Aucune teinte (le hurt du
-- proto est mouvement PUR — on NE reproduit PAS le flash rouge de BODY_ANIM.hurt ; cf. spec §2.4 [CONFLIT]).

-- ── Enveloppes temporelles partagées (proto l.717-722, 832) ──
local function _sstep(a, b, x) -- smoothstep cubique
  x = (x - a) / (b - a); x = (x < 0) and 0 or (x > 1) and 1 or x
  return x * x * (3 - 2 * x)
end
local function _smoo(a, b, x) -- smootherstep quintique
  x = (x - a) / (b - a); x = (x < 0) and 0 or (x > 1) and 1 or x
  return x * x * x * (x * (x * 6 - 15) + 10)
end
-- enveloppe d'attaque : [windup (anticipation brève), strike (frappe + retour)]
local function _env(ph)
  return _sstep(0, 0.24, ph) - _sstep(0.24, 0.40, ph), _smoo(0.30, 0.44, ph) - _smoo(0.66, 0.92, ph)
end
-- squash&stretch anisotrope le long de faceDir (retourne le DÉPLACEMENT à appliquer à (x,y))
local function _dscale(x, y, cx, cy, fdx, fdy, s)
  local rx, ry = x - cx, y - cy
  local al = rx * fdx + ry * fdy
  local ex, ey = rx - al * fdx, ry - al * fdy
  local ka, kp = 1 + s, 1 / (1 + s)
  return (cx + al * ka * fdx + ex * kp) - x, (cy + al * ka * fdy + ey * kp) - y
end
local function _nrm(vx, vy) local d = hypot(vx, vy); if d == 0 then d = 1 end; return vx / d, vy / d end
local function _h2(x, y) local n = (x * 12.9898 + y * 78.233) * 43758.5453; return n - floor(n) end
local function _dprog(ph) return _smoo(0.12, 0.82, ph) end -- progression de désintégration (deathFx)

-- ── atkDisp (18 kinds) : déplacement d'attaque par cellule (proto l.723-746) ──
-- atk = { k, pr, ph }. Renvoie (dx,dy). `A` porte head/faceDir/mass (cf. anatomie). reach/pull défaut 8/3.
local function atkDisp(atk, x, y, cx, cy, bellyY, groundY, headSpan, A)
  local ph = atk.ph
  local wu, st = _env(ph)
  local fdx, fdy = _nrm((A.faceDir and A.faceDir[1]) or 0, (A.faceDir and A.faceDir[2]) or -1)
  local pr = atk.pr or EMPTY_PR
  local k = atk.k
  local reach, pull = pr.reach or 8, pr.pull or 3
  local dx, dy = 0, 0
  local head = A.head or DEFAULT_HEAD
  local bR = (A.mass and A.mass[1]) and A.mass[1][3] or 9
  if k == "lunge" then
    local m = st * reach - wu * pull
    local ppx, ppy = -fdy, fdx
    local sx, sy = _dscale(x, y, cx, cy, fdx, fdy, st * 0.22 - wu * 0.16)
    dx = fdx * m + ppx * st * 1.8 + sx; dy = fdy * m + ppy * st * 1.8 + sy
  elseif k == "pounce" then
    local m2 = st * reach - wu * pull * 0.5
    local sx, sy = _dscale(x, y, cx, cy, fdx, fdy, st * 0.20 - wu * 0.18)
    dx = fdx * m2 + sx
    dy = fdy * m2 * 0.5 - st * (pr.leap or 7) + wu * (pr.crouch or 3) + sy
  elseif k == "bite" then
    local dh = hypot(x - head.x, y - head.y)
    local f = max(0, 1 - dh / (head.r + 8))
    local m3 = st * reach - wu * pull
    local bpx, bpy = -fdy, fdx
    dx = (fdx * m3 + bpx * st * 1.6) * f; dy = (fdy * m3 + bpy * st * 1.6) * f
  elseif k == "swing" then
    local side = pr.side or ((fdx >= 0) and 1 or -1)
    local px, py = cx, bellyY + 1
    local lag = min(0.13, max(0, py - y) * 0.006)
    local elwu, elst = _env(ph - lag)
    local angg = (-elwu * 0.55 + elst * 1.6) * side
    local rx, ry = x - px, y - py
    local ca, sa = cos(angg), sin(angg)
    local hf = _sstep(0, 10, py - y)
    dx = ((px + rx * ca - ry * sa) - x) * hf; dy = ((py + rx * sa + ry * ca) - y) * hf
  elseif k == "claw" then
    local hf2 = max(0, (groundY - y) / headSpan); hf2 = hf2 * hf2
    local dir = (fdx ~= 0) and fdx or 1
    dx = (st * reach * dir - wu * pull * dir) * hf2; dy = -st * 2.5 * hf2
  elseif k == "lash" then
    if y > bellyY - 2 then
      local f2 = min(1, (y - (bellyY - 2)) / max(1, groundY - (bellyY - 2)))
      local wul, stl = _env(ph - f2 * 0.16)
      dx = fdx * stl * reach * 2.2 * f2 - wul * pull * fdx * f2
      dy = fdy * stl * reach * 0.9 * f2 - stl * 3.2 * f2
    end
  elseif k == "cast" then
    if y < bellyY then
      local u = max(0, (bellyY - y) / max(1, bellyY - (cy - 12)))
      dx = -fdx * (wu * 3 + st * 2.2) * u; dy = -fdy * wu * 2 * u + st * 0.8
    end
  elseif k == "smite" then
    dy = -st * 4.5 + wu * 1.6; dx = (x - cx) * st * 0.03
  elseif k == "shard" then
    local s2 = st * 0.09 - wu * 0.14; dx = (x - cx) * s2; dy = (y - cy) * s2
  elseif k == "slam" then
    local hf3 = max(0, (groundY - y) / headSpan); hf3 = hf3 * hf3
    dy = (-wu * 7 + st * 10) * hf3 + st * 0.6
  elseif k == "surge" then
    local s3 = -wu * 0.16
    dx = (x - cx) * s3 + fdx * st * reach + (_h2(x, y) - 0.5) * st * 4.5
    dy = (y - cy) * s3 + fdy * st * reach + (_h2(y, x) - 0.5) * st * 4.5
  elseif k == "wing" then
    local d2 = abs(x - cx)
    if d2 > bR * 0.85 then
      local wf = d2 - bR * 0.85
      dy = (-wu + st) * wf * 0.8; dx = ((x < cx) and 1 or -1) * wf * st * 0.35
    end
    dx = dx + fdx * st * 3; dy = dy + fdy * st * 3
  elseif k == "engulf" then
    local mx, my = head.x, head.y
    if pr.mouth then mx, my = pr.mouth[1], pr.mouth[2] end
    local ddx, ddy = x - mx, y - my
    local dd = hypot(ddx, ddy)
    local ndx, ndy = _nrm(ddx, ddy)
    local f3 = max(0, 1 - dd / (pr.mr or 14))
    dx = ndx * (wu * 4 - st * 6) * f3; dy = ndy * (wu * 4 - st * 6) * f3
  elseif k == "spew" then
    local s4 = st * 0.07; dx = (x - cx) * s4; dy = (y - cy) * s4
    local dh2 = hypot(x - head.x, y - head.y)
    local fh = max(0, 1 - dh2 / (head.r + 7))
    dx = dx + fdx * st * 3 * fh; dy = dy + fdy * st * 3 * fh
  elseif k == "gaze" then
    local s5 = st * 0.06 - wu * 0.04; dx = (x - cx) * s5; dy = (y - cy) * s5
  elseif k == "phase" then
    local m6 = st * reach - wu * pull
    dx = fdx * m6 + sin(ph * 9 + y * 0.3) * st * 2.2; dy = fdy * m6
  elseif k == "multi" then
    local parts = pr.parts or EMPTY
    for pi = 1, #parts do
      local P = parts[pi]
      local lp = ((ph * (pr.loops or 2) + (P.off or 0)) % 1 + 1) % 1
      local lwu, lst = _env(lp)
      local pfx, pfy = _nrm((P.fd and P.fd[1]) or 0, (P.fd and P.fd[2]) or -1)
      local dpx, dpy = x - P.x, y - P.y
      local ddp = hypot(dpx, dpy)
      local ff = max(0, 1 - ddp / (P.r or 5))
      if ff > 0 then
        if P.mode == "swipe" then
          local sg = (pfx ~= 0) and pfx or 1
          dx = dx + (sg * lst * (P.reach or 7) - lwu * 2 * sg) * ff; dy = dy - lst * 2 * ff
        else
          local mm = lst * (P.reach or 7) - lwu * 2.5
          dx = dx + pfx * mm * ff; dy = dy + pfy * mm * ff
        end
      end
    end
  elseif k == "skitter" then
    local ox = (pr.ox ~= nil) and pr.ox or cx
    local oy = (pr.oy ~= nil) and pr.oy or cy
    local sdx, sdy = x - ox, y - oy
    local sr = hypot(sdx, sdy)
    local sang = atan2(sdy, sdx)
    local lf = _sstep(5, 11, sr)
    if lf > 0 then
      local stt = max(st, 0.35 * _sstep(0.30, 0.45, ph) * (1 - _sstep(0.80, 1.0, ph)))
      local th = (pr.amp or 0.6) * sin(ph * (pr.freq or 11) + sang * 2.7) * lf * stt
      local ca2, sa2 = cos(th), sin(th)
      local nx, ny = sdx * ca2 - sdy * sa2, sdx * sa2 + sdy * ca2
      local rd = (pr.rad or 3.2) * sin(ph * 8 + sang * 1.6 + 1.0) * lf * stt
      dx = (nx - sdx) + cos(sang) * rd; dy = (ny - sdy) + sin(sang) * rd
    end
  end
  return dx, dy
end

-- ── hurtDisp (8 kinds) : réaction aux dégâts, MOUVEMENT seul (proto l.817-829) ──
-- h = { k, ph }. Secousse amortie ~0.42 s. Aucune teinte (cf. en-tête).
local function hurtDisp(h, x, y, cx, cy, bellyY, groundY, headSpan, A)
  local ph, k = h.ph, h.k
  local fdx, fdy = _nrm((A.faceDir and A.faceDir[1]) or 0, (A.faceDir and A.faceDir[2]) or -1)
  local bR = (A.mass and A.mass[1]) and A.mass[1][3] or 9
  local dx, dy = 0, 0
  local hit = exp(-ph * 4.5) * (1 - _sstep(0, 0.95, ph))
  if k == "recoil" then
    local f = 0.4 + 0.6 * max(0, (groundY - y)) / headSpan
    dx = -fdx * 7 * hit * f + sin(ph * 26) * 1.2 * hit; dy = -fdy * 7 * hit * f
  elseif k == "jelly" then
    local w = exp(-ph * 3) * cos(ph * 17)
    local sx, sy = _dscale(x, y, cx, cy, 0, 1, w * 0.16)
    dx = sx + (x - cx) * w * 0.04; dy = sy
  elseif k == "clench" then
    local f2 = _sstep(bR * 0.6, bR * 2.4, hypot(x - cx, y - cy))
    local ndx, ndy = _nrm(cx - x, cy - y)
    dx = ndx * 6 * hit * f2; dy = ndy * 6 * hit * f2
  elseif k == "jolt" then
    local j = exp(-ph * 7) * cos(ph * 26)
    dx = -fdx * 5 * j; dy = -fdy * 5 * j
  elseif k == "flinchfly" then
    local d = abs(x - cx)
    if d > bR * 0.8 then
      local wf = d - bR * 0.8
      dx = dx + ((x < cx) and 1 or -1) * wf * 0.4 * hit; dy = dy + wf * 0.2 * hit
    end
    dy = dy + 3 * hit
  elseif k == "kink" then
    dx = sin(y * 0.5 - ph * 12) * 5 * hit
  elseif k == "waver" then
    local rr = exp(-ph * 3)
    local f3 = max(0, (groundY - y)) / headSpan
    dx = -fdx * 5 * rr * cos(ph * 12) + sin(y * 0.4 - ph * 10) * 2 * rr * f3; dy = -fdy * 4 * rr
  elseif k == "scatter" then
    local b = hit * (1 - _sstep(0, 0.6, ph))
    local an = _h2(x, y) * 6.283
    local mg = (2 + _h2(y, x) * 5) * b
    dx = cos(an) * mg; dy = sin(an) * mg
  end
  return dx, dy
end

-- ── deathPix (7 kinds) : désagrégation, retourne (dx,dy,alpha) (proto l.833-860) ──
local function deathPix(D, x, y, cx, cy, bellyY, groundY, headSpan, A)
  local ph, k = D.ph, D.k
  local fdx, fdy = _nrm((A.faceDir and A.faceDir[1]) or 0, (A.faceDir and A.faceDir[2]) or -1)
  local rx, ry = x - cx, y - cy
  local r = hypot(rx, ry); if r == 0 then r = 0.001 end
  local ux, uy = rx / r, ry / r
  local n1 = _h2(x, y)
  local n2 = _h2(y * 1.7 + 1, x * 1.3 + 1)
  local react = _sstep(0, 0.16, ph) * (1 - _sstep(0.16, 0.32, ph))
  local frag = _sstep(0.24, 0.74, ph)
  local sc = 0.5 + n1 * 0.5
  local dx, dy, a = 0, 0, 1
  if k == "disintegrate" then
    local ri = _sstep(0.10, 0.85, ph)
    dx = ux * ri * 5 + (n1 - 0.5) * ri * 9; dy = -ri * 15 + (n2 - 0.5) * ri * 7; a = 1 - _sstep(0.12, 0.84, ph)
  elseif k == "shatter" then
    dx = (n1 - 0.5) * 2 * react + ux * frag * (7 + sc * 12)
    dy = (n2 - 0.5) * 2 * react + uy * frag * (7 + sc * 12) + frag * frag * 7; a = 1 - _sstep(0.5, 0.9, ph)
  elseif k == "crumble" then
    dx = ux * frag * (5 + sc * 9) + (n1 - 0.5) * frag * 3
    dy = uy * frag * (3 + sc * 6) + frag * frag * 13 + (n2 - 0.5) * frag * 2; a = 1 - _sstep(0.55, 0.92, ph)
  elseif k == "unravel" then
    local th = exp(-ph * 3) * sin(y * 0.5 - ph * 16) * 5 * (1 - frag)
    dx = th + ux * frag * (6 + sc * 10) + (n1 - 0.5) * frag * 3
    dy = uy * frag * (5 + sc * 8) + frag * frag * 7 + (n2 - 0.5) * frag * 3; a = 1 - _sstep(0.55, 0.92, ph)
  elseif k == "splatter" then
    local wob = exp(-ph * 4) * cos(ph * 16) * 0.12
    local sx, sy = _dscale(x, y, cx, cy, 0, 1, wob)
    dx = sx + ux * frag * (6 + sc * 11) + (n1 - 0.5) * frag * 3
    dy = sy + uy * frag * (4 + sc * 7) + frag * frag * 12 + (n2 - 0.5) * frag * 2; a = 1 - _sstep(0.5, 0.9, ph)
  elseif k == "burstLimp" then
    local sink = _sstep(0, 0.3, ph) * 3
    dx = ux * frag * (5 + sc * 10) + (n1 - 0.5) * frag * 3
    dy = sink + uy * frag * (4 + sc * 7) + frag * 6 + (n2 - 0.5) * frag * 2; a = 1 - _sstep(0.5, 0.9, ph)
  else -- gib (défaut)
    dx = ux * frag * (6 + sc * 11) + (n1 - 0.5) * frag * 3 + (-fdx) * react * 2
    dy = uy * frag * (5 + sc * 10) + frag * frag * 10 + (n2 - 0.5) * frag * 2 + (-fdy) * react * 2
    a = 1 - _sstep(0.5, 0.9, ph)
  end
  return dx, dy, a
end

-- ── atkFx / deathFx : overlays de particules ONE-SHOT (proto l.747-768, 861-878) ──
-- Dessinés APRÈS le batch, en ESPACE GRILLE (le transform push/scale du caller est encore actif). Le proto
-- dessine des `fillRect` device-px arrondis ; ici on reste en unités de grille (le scale entier de la scène
-- assure des bords nets). Couleurs = palette `p` portée par le cache info() (eyeCol/boneCol/baseCol/hiCol).
-- petit bloc plein à (gx,gy), côté s, couleur {r,g,b}, alpha al. (love.graphics.rectangle "fill" vérifié 11.5)
local function fxBlk(gx, gy, s, col, al)
  love.graphics.setColor(col[1], col[2], col[3], al)
  local ss = (s < 1) and 1 or s
  love.graphics.rectangle("fill", gx - ss * 0.5, gy - ss * 0.5, ss, ss)
end
-- ligne pointillée de blocs entre (x0,y0) et (x1,y1) (proto `ln`)
local function fxLine(x0, y0, x1, y1, s, col, al)
  local n = max(2, math.ceil(hypot(x1 - x0, y1 - y0)))
  for i = 0, n do fxBlk(x0 + (x1 - x0) * i / n, y0 + (y1 - y0) * i / n, s, col, al) end
end

-- Overlay d'attaque. `c` = cache info() (couleurs), `atk` = {k,pr,ph}, `A` = anatomie.
local function atkFx(c, atk, A)
  local ph, k = atk.ph, atk.k
  local pr = atk.pr or EMPTY_PR
  local fdx, fdy = _nrm((A.faceDir and A.faceDir[1]) or 0, (A.faceDir and A.faceDir[2]) or -1)
  local head = A.head or DEFAULT_HEAD
  local sp = _sstep(0.30, 0.62, ph); if sp <= 0 then return end
  local fade = 1 - _sstep(0.66, 0.90, ph)
  local col = pr.fxCol or c.glowCol or c.eyeCol -- couleur d'éclat (param > glow > œil)
  local hot = c.boneCol
  local mass0 = (A.mass and A.mass[1]) or DEFAULT_MASS0
  local cx, cy = mass0[1], mass0[2]
  if k == "cast" then
    local ox, oy = head.x + fdx * (head.r + 1), head.y + fdy * (head.r + 1)
    local px, py = ox + fdx * sp * 30, oy + fdy * sp * 30
    fxBlk(px, py, 3, col, fade); fxBlk(px - fdx * 3, py - fdy * 3, 2, hot, fade)
    fxBlk(px - fdx * 6, py - fdy * 6, 1, col, fade); fxBlk(ox, oy, 2, hot, fade)
  elseif k == "spew" then
    local ox2, oy2 = head.x + fdx * head.r, head.y + fdy * head.r
    local ba = atan2(fdy, fdx)
    for i = 0, 15 do
      local spr = (_h2(i, 9) - 0.5) * 1.0
      local dist = sp * (20 + _h2(i, 1) * 12)
      local ang = ba + spr
      fxBlk(ox2 + cos(ang) * dist, oy2 + sin(ang) * dist, (i % 4 ~= 0) and 1 or 2, (i % 3 ~= 0) and col or hot, fade)
    end
  elseif k == "swing" or k == "claw" then
    local R = (pr.reach or 8) + 7
    local base = atan2(fdy, fdx)
    local arcs = (k == "claw") and 4 or 1
    for a = 0, arcs - 1 do
      local off = (a - (arcs - 1) / 2) * 0.20
      local a0 = base - 0.7 + sp * 1.2
      for s2 = 0, 8 do
        local aa = a0 + s2 * 0.15 + off
        fxBlk(cx + cos(aa) * R, cy + sin(aa) * R * 0.8, (s2 < 2) and 2 or 1, (s2 < 3) and hot or col, fade)
      end
    end
  elseif k == "slam" then
    local rr = sp * 26
    for i = 0, 17 do
      local an = i / 18 * 6.283
      fxBlk(32 + cos(an) * rr, 56 + sin(an) * rr * 0.3, 1, col, fade)
      fxBlk(32 + cos(an) * rr * 0.7, 56 + sin(an) * rr * 0.3 * 0.7, 1, hot, fade)
    end
  elseif k == "smite" then
    local bx = head.x
    for yy = 0, 57 do
      if yy % 2 == 0 then fxBlk(bx, yy, 2, (yy < head.y) and hot or col, fade) end
    end
    fxBlk(bx - 2, head.y, 1, col, fade); fxBlk(bx + 2, head.y, 1, col, fade)
    for i9 = 0, 7 do
      local an9 = i9 / 8 * 6.283
      fxBlk(head.x + cos(an9) * sp * 8, head.y + sin(an9) * sp * 8, 1, hot, fade)
    end
  elseif k == "gaze" then
    fxLine(head.x, head.y, head.x + fdx * sp * 30, head.y + fdy * sp * 30, 2, col, fade)
    fxLine(head.x, head.y, head.x + fdx * sp * 30, head.y + fdy * sp * 30, 1, hot, fade)
  elseif k == "shard" then
    local base2 = atan2(fdy, fdx)
    for i3 = 0, 9 do
      local ang3 = base2 + (i3 / 9 - 0.5) * 1.6
      local d3 = sp * (14 + _h2(i3, 3) * 18)
      fxBlk(cx + cos(ang3) * d3, cy + sin(ang3) * d3, 2, (i3 % 2 ~= 0) and col or hot, fade)
      fxBlk(cx + cos(ang3) * d3 * 0.6, cy + sin(ang3) * d3 * 0.6, 1, col, fade)
    end
  elseif k == "wing" then
    for i4 = 0, 5 do
      local yw = 18 + i4 * 5
      fxLine(32 + fdx * 4, yw, 32 + fdx * (10 + sp * 20), yw + 5 + sp * 8, 1, (i4 % 2 ~= 0) and col or hot, fade)
    end
  elseif k == "engulf" then
    local mx, my = head.x, head.y
    if pr.mouth then mx, my = pr.mouth[1], pr.mouth[2] end
    for i5 = 0, 11 do
      local an5 = i5 / 12 * 6.283
      local r0 = 22 * (1 - sp)
      fxBlk(mx + cos(an5) * r0, my + sin(an5) * r0, 1, (i5 % 2 ~= 0) and col or hot, fade)
    end
  elseif k == "surge" then
    local ba2 = atan2(fdy, fdx)
    for i6 = 0, 13 do
      local an6 = ba2 + (_h2(i6, 5) - 0.5) * 1.3
      local d6 = sp * (10 + _h2(i6, 7) * 22)
      fxBlk(cx + cos(an6) * d6, cy + sin(an6) * d6, (i6 % 3 ~= 0) and 1 or 2, col, fade)
    end
  elseif k == "multi" then
    local parts = pr.parts or EMPTY
    for pm = 1, #parts do
      local P = parts[pm]
      local lp = ((ph * (pr.loops or 2) + (P.off or 0)) % 1 + 1) % 1
      local lsp = _sstep(0.30, 0.62, lp)
      if lsp > 0.25 then
        local pfx, pfy = _nrm((P.fd and P.fd[1]) or 0, (P.fd and P.fd[2]) or -1)
        local tx, ty = P.x + pfx * (P.r + 2), P.y + pfy * (P.r + 2)
        for d = 0, 3 do
          fxBlk(tx + (_h2((pm - 1) * 7 + d, 2) - 0.5) * 5, ty + (_h2((pm - 1) * 7 + d, 4) - 0.5) * 5, 1,
            (d % 2 ~= 0) and col or hot, fade)
        end
      end
    end
  elseif (k == "lunge" or k == "pounce" or k == "bite") and sp > 0.2 then
    local hx, hy = head.x + fdx * 5, head.y + fdy * 5
    for i7 = 0, 6 do
      fxBlk(hx + (_h2(i7, 2) - 0.5) * 8, hy + (_h2(i7, 4) - 0.5) * 6, (i7 % 3 ~= 0) and 1 or 2, col, fade)
    end
  elseif k == "skitter" then
    for i8 = 0, 4 do
      local an8 = _h2(i8, floor(ph * 30)) * 6.283
      local rr8 = 14 + _h2(i8, 3) * 8
      fxBlk(32 + cos(an8) * rr8, 40 + sin(an8) * rr8 * 0.7, 1, col, fade)
    end
  end
  love.graphics.setColor(1, 1, 1, 1)
end

-- Overlay de mort (gerbe de sang/ichor/poussière/âme). `c` = cache info(), `D` = {k,ph}, `A` = anatomie.
local function deathFx(c, D, A)
  local ph, k = D.ph, D.k
  local mass0 = (A.mass and A.mass[1]) or DEFAULT_MASS0
  local cx, cy = mass0[1], mass0[2]
  local blood, dark = BLOOD_COL, DARK_COL
  local ich = c.eyeCol           -- ichor = couleur d'œil de la palette
  local base, hi = c.baseCol, c.hiCol
  local emit = _sstep(0.24, 0.6, ph)
  local fade = 1 - _sstep(0.62, 0.92, ph)
  if emit <= 0 or fade <= 0 then love.graphics.setColor(1, 1, 1, 1); return end
  local blast = emit * fade
  if k == "gib" or k == "unravel" or k == "burstLimp" then
    for i = 0, 12 do
      local an = _h2(i, 7) * 6.283
      local d = blast * (7 + _h2(i, 3) * 15)
      local col = (i % 3 ~= 0) and blood or ((i % 2 ~= 0) and dark or ich)
      fxBlk(cx + cos(an) * d, cy + sin(an) * d + blast * blast * 6, (i % 4 ~= 0) and 1 or 2, col, 0.85 * fade)
    end
  elseif k == "splatter" then
    for i2 = 0, 12 do
      local an2 = _h2(i2, 5) * 6.283
      local d2 = blast * (6 + _h2(i2, 2) * 14)
      fxBlk(cx + cos(an2) * d2, cy + sin(an2) * d2 + blast * blast * 6, (i2 % 3 ~= 0) and 1 or 2,
        (i2 % 2 ~= 0) and base or hi, 0.8 * fade)
    end
  elseif k == "shatter" or k == "crumble" then
    for i3 = 0, 10 do
      local an3 = _h2(i3, 9) * 6.283
      local d3 = blast * (6 + _h2(i3, 4) * 14)
      fxBlk(cx + cos(an3) * d3, cy + sin(an3) * d3, 1, (i3 % 2 ~= 0) and hi or base, 0.8 * fade)
    end
  elseif k == "disintegrate" then
    for i4 = 0, 10 do
      local px = cx + (_h2(i4, 4) - 0.5) * 16
      local py = cy - _dprog(ph) * 18 - _h2(i4, 2) * 6
      fxBlk(px, py, 1, ich, 0.6 * fade)
    end
  end
  love.graphics.setColor(1, 1, 1, 1)
end

-- Déplacement PAR PIXEL (x,y) -> (dx,dy) en coords de grille. Port fidèle de `disp` du proto.
local function makeDisp(t, m, cx, cy, bodyR, bellyY, groundY, headSpan)
  return function(x, y)
    local dx, dy = 0, 0
    if m.bob then dy = dy + m.bob[1] * sin(t * m.bob[2]) end
    if m.breathe then
      local s = m.breathe[1] * sin(t * m.breathe[2]); dx = dx + (x - cx) * s; dy = dy + (y - cy) * s
    end
    if m.sway then
      local f = max(0, groundY - y) / headSpan; dx = dx + m.sway[1] * sin(t * m.sway[2] + y * 0.16) * f
    end
    if m.legs and y > cy then
      local side = (x < cx) and -1 or 1; dy = dy + m.legs[1] * sin(t * m.legs[2]) * side
    end
    if m.flap then
      local d = abs(x - cx)
      if d > bodyR * 0.9 then
        local wf = d - bodyR * 0.9
        dy = dy - wf * m.flap[1] * sin(t * m.flap[2])
        dx = dx + ((x < cx) and 1 or -1) * wf * (m.flap[3] or 0) * (0.5 + 0.5 * sin(t * m.flap[2]))
      end
    end
    if m.tentacles and y > bellyY then
      dx = dx + m.tentacles[1] * sin(t * m.tentacles[2] + y * 0.45 + x * 0.3)
    end
    if m.writhe then
      dx = dx + m.writhe[1] * sin(t * m.writhe[2] + y * 0.6)
      dy = dy + m.writhe[1] * 0.5 * cos(t * m.writhe[2] + x * 0.5)
    end
    return dx, dy
  end
end

-- 1×1 blanc bake une fois : teinté par cellule via SpriteBatch:setColor (un seul draw call par créature).
local PIXEL
local function pixel()
  if PIXEL then return PIXEL end
  local idata = love.image.newImageData(1, 1)
  idata:setPixel(0, 0, 1, 1, 1, 1)
  PIXEL = love.graphics.newImage(idata)
  PIXEL:setFilter("nearest", "nearest")
  return PIXEL
end

local function unpack3(cc) return (floor(cc / 65536) % 256) / 255, (floor(cc / 256) % 256) / 255, (cc % 256) / 255 end

-- Une créature dessinée-main (Creatures[id]) n'a pas de grille -> non rendable en vivant (le caller retombe sur Rig).
function Critter.has(id) return not (Creatures and Creatures[id]) end

-- Données de rendu mémoïsées par id : liste de cellules opaques {x,y,r,g,b}, yeux, anatomie, palette, profil, bounds.
local cache = {}
local function info(id)
  local c = cache[id]
  if c then return c end
  local spec = Units[id] or {}
  local ok, d = pcall(CreatureGen.cachedLive,
    { id = id, type = spec.type, family = spec.family, effects = spec.effects, rank = spec.rank })
  if not ok or not d or not d.grid then return nil end
  local data, W, H = d.grid, d.w, d.h
  local cells, n, minX, maxX, minY, maxY = {}, 0, W, 0, H, 0
  for y = 0, H - 1 do
    local row = y * W
    for x = 0, W - 1 do
      local cc = data[row + x]
      if cc then
        local r, g, b = unpack3(cc)
        n = n + 1; cells[n] = { x, y, r, g, b }
        if x < minX then minX = x end
        if x > maxX then maxX = x end
        if y < minY then minY = y end
        if y > maxY then maxY = y end
      end
    end
  end
  local A = d.A or {}
  local cx, cy, bodyR = 32, 34, 10
  if A.mass and A.mass[1] then cx, cy, bodyR = A.mass[1][1], A.mass[1][2], A.mass[1][3] end
  local bellyY = (A.belly and A.belly.y) or 42
  local groundY = 57
  local p = d.p or EMPTY
  local er, eg, eb = unpack3(p.eye or 0xffffff)
  local or_, og, ob = unpack3(p.out or 0x000000)
  local sr, sg, sb = unpack3(p.sh or 0x444444)
  local br, bg, bb = unpack3(p.bone or 0xffffff)  -- "hot" des FX d'attaque (proto hot=p.bone)
  local bsr, bsg, bsb = unpack3(p.base or 0x888888) -- matière (splatter/crumble)
  local hr, hg, hb = unpack3(p.hi or 0xcccccc)     -- éclat clair
  c = {
    cells = cells, eyes = d.eyes or {}, h = H,
    cx = cx, cy = cy, bodyR = bodyR, bellyY = bellyY, groundY = groundY,
    topY = (n > 0) and minY or 0, contentH = max(1, (n > 0) and (maxY - minY + 1) or H), -- bounds TIGHTS (fit-to-content)
    headSpan = max(1, groundY - (cy - bodyR - 6)),
    halfW = max(4, (maxX - minX) / 2),
    float = A.float and true or false,
    A = A,                                          -- anatomie complète (head/faceDir/mass) lue par les dispatchers réactifs
    arch = d.arch, family = d.family,               -- forme + famille -> résolution ATK[arch] / HURT[fam] / DEATH[fam]
    prof = PROF[d.family] or PROF_DEFAULT,
    eyeCol = { er, eg, eb }, outCol = { or_, og, ob }, shCol = { sr, sg, sb },
    boneCol = { br, bg, bb }, baseCol = { bsr, bsg, bsb }, hiCol = { hr, hg, hb },
    glowCol = nil,                                  -- (réservé : éclat de relique/glow d'équipe ; défaut = eyeCol côté FX)
  }
  cache[id] = c
  return c
end

-- Remplit le SpriteBatch (espace GRILLE : chaque cellule à (gx+dx, gy+dy)).
-- SOMME des couches (comme `disp` du proto, l.91-106) : idle + atkDisp + hurtDisp, puis deathPix À PART (il porte
-- aussi un alpha PAR CELLULE, multiplié sur la couleur via b:setColor(r,g,b,a) — per-sprite, floats 0..1, vérifié 11.5).
-- Renvoie la fn `dispRO` (idle+atk+hurt, SANS la mort) pour caler les yeux dessus comme le proto.
local function fillBatch(c, t, atk, hurt, death)
  if not c.batch then c.batch = love.graphics.newSpriteBatch(pixel(), #c.cells, "stream") end
  local idle = makeDisp(t, c.prof, c.cx, c.cy, c.bodyR, c.bellyY, c.groundY, c.headSpan)
  local A = c.A
  local cx, cy, bellyY, groundY, headSpan = c.cx, c.cy, c.bellyY, c.groundY, c.headSpan
  -- déplacement idle+atk+hurt (réutilisé pour les cellules ET les yeux ; la mort est appliquée à part).
  local function dispRO(x, y)
    local dx, dy = idle(x, y)
    if atk then local ax, ay = atkDisp(atk, x, y, cx, cy, bellyY, groundY, headSpan, A); dx = dx + ax; dy = dy + ay end
    if hurt then local hx, hy = hurtDisp(hurt, x, y, cx, cy, bellyY, groundY, headSpan, A); dx = dx + hx; dy = dy + hy end
    return dx, dy
  end
  local b = c.batch
  b:clear()
  local off = (CELL - 1) * 0.5
  for i = 1, #c.cells do
    local cell = c.cells[i]
    local dx, dy = dispRO(cell[1], cell[2])
    local a = 1
    if death then
      local ddx, ddy, da = deathPix(death, cell[1], cell[2], cx, cy, bellyY, groundY, headSpan, A)
      dx = dx + ddx; dy = dy + ddy; a = da
    end
    if a > 0 then -- cellule éteinte (alpha<=0 sous le fondu de mort) : on l'omet (comme `continue` du proto)
      b:setColor(cell[3], cell[4], cell[5], a)
      b:add(cell[1] + dx - off, cell[2] + dy - off, 0, CELL, CELL)
    end
  end
  b:setColor(1, 1, 1, 1)
  return dispRO
end

-- Dessine ombre + corps + (FX d'attaque/mort) + yeux en ESPACE GRILLE (le caller a déjà posé le transform :
-- (32, groundY) -> pieds). `disp` = idle+atk+hurt (cale les yeux). `atk`/`death` = descripteurs (overlays + coupe yeux).
local function paint(c, t, disp, alpha, shadow, atk, death)
  if shadow then -- ombre au sol (subtile) ; les flottants la laissent en bas en montant -> lecture de lévitation
    love.graphics.setColor(0, 0, 0, 0.22 * alpha)
    love.graphics.ellipse("fill", 32, c.groundY + (c.float and 3 or 1), c.halfW * 1.05, c.float and 1.6 or 2.4)
  end
  love.graphics.setColor(1, 1, 1, alpha) -- l'alpha global multiplie les couleurs par-cellule du batch (fondu de mort)
  love.graphics.draw(c.batch, 0, 0)
  -- overlays one-shot APRÈS le corps (proto l.108-109) : éclat d'arme/projectile, gerbe de mort. En espace grille.
  if atk then atkFx(c, atk, c.A) end
  if death then deathFx(c, death, c.A) end
  -- yeux coupés dès la fragmentation (proto l.110 : !(_death.ph>0.3)) — le corps se désagrège, plus de globe.
  if death and death.ph > 0.3 then return end
  local e = c.prof.eyes
  if e and #c.eyes > 0 then -- yeux PAR-DESSUS : clignement (carré sombre) ou globe + saccade de pupille
    local blink, dart = e[1] or 0.9, e[2] or 1.4
    for k = 1, #c.eyes do
      local ey = c.eyes[k]
      local ddx, ddy = disp(ey[1], ey[2])
      local qx, qy, r = ey[1] + ddx, ey[2] + ddy, ey[3]
      local ph = ey[1] * 1.3 + ey[2] * 0.7
      if sin(t * blink + ph) > 0.93 then
        love.graphics.setColor(c.shCol[1], c.shCol[2], c.shCol[3], alpha)
        love.graphics.rectangle("fill", qx - r, qy - r, 2 * r + 1, 2 * r + 1)
      elseif r >= 2 then
        love.graphics.setColor(c.eyeCol[1], c.eyeCol[2], c.eyeCol[3], alpha)
        local rr = r - 1
        love.graphics.rectangle("fill", qx - rr, qy - rr, 2 * rr + 1, 2 * rr + 1)
        local pdx, pdy = floor(sin(t * dart + ph) + 0.5), floor(cos(t * dart * 1.3 + ph) + 0.5)
        local pr = (r >= 3) and 1 or 0
        love.graphics.setColor(c.outCol[1], c.outCol[2], c.outCol[3], alpha)
        love.graphics.rectangle("fill", qx + pdx - pr, qy + pdy - pr, 2 * pr + 1, 2 * pr + 1)
      end
    end
  end
end

-- DESSINE `id` ANCRÉ AUX PIEDS : la base du cadre (grille col 32, ligne groundY) tombe sur (footX, footY), à
-- l'échelle `scale` (cadre natif 64 -> 64*scale px ; les tailles RELATIVES sont conservées). t = SECONDES.
-- facing 1/-1 (miroir). `Critter` reste STATELESS : le caller passe la phase de l'évènement.
--   opts = { alpha = fondu (défaut 1), shadow = false si la scène dessine déjà son ombre,
--            atk = {k, pr, ph}, hurt = {k, ph}, death = {k, ph} }  -- réactions optionnelles.
-- Priorité (comme le driver du proto, l.932-940) : death > hurt > atk (un mort n'attaque plus ; un touché
-- interrompt l'attaque). `pr` d'attaque vient de Critter.atkFor(id) ; les kinds de Critter.atkFor/hurtFor/deathFor.
function Critter.drawAt(view, id, footX, footY, scale, t, facing, opts)
  if not (love.graphics and love.graphics.newSpriteBatch and love.graphics.newImage) then return end
  local c = info(id)
  if not c or #c.cells == 0 then return end
  t = t or 0
  facing = (facing == -1) and -1 or 1
  scale = scale or 1
  opts = opts or EMPTY
  local alpha = opts.alpha or 1
  if alpha <= 0 then return end
  -- résolution de priorité : on n'active qu'une couche réactive (la plus prioritaire présente).
  local death = opts.death
  local hurt = (not death) and opts.hurt or nil
  local atk = (not death and not hurt) and opts.atk or nil
  local disp = fillBatch(c, t, atk, hurt, death)
  love.graphics.push()
  love.graphics.translate(footX, footY)
  love.graphics.scale(facing * scale, scale)
  love.graphics.translate(-32, -c.groundY)
  paint(c, t, disp, alpha, opts.shadow ~= false, atk, death)
  love.graphics.pop()
  love.graphics.setColor(1, 1, 1, 1)
end

-- DESSINE `id` dans une BOÎTE (x,y,boxW,boxH) : échelle = hauteur de boîte (cadre natif), pieds ancrés ~en bas.
-- fill (~1.0) ajuste le remplissage. Pratique pour les vignettes (galerie, fiches au survol).
function Critter.draw(view, id, x, y, boxW, boxH, t, facing, fill, opts)
  local c = info(id)
  if not c then return end
  fill = fill or 1.0
  local scale = (boxH / c.h) * fill
  Critter.drawAt(view, id, x + boxW * 0.5, y + (c.groundY / c.h) * boxH * fill, scale, t, facing, opts)
end

-- DESSINE `id` AJUSTÉ AU CONTENU dans une boîte (x,y,boxW,boxH) : échelle par les bounds TIGHTS (la créature
-- REMPLIT la boîte quelle que soit la place vide de son cadre 64×64 -> un commandant bas-et-large ne « flotte »
-- plus dans le grand creux d'un piédestal). Pieds ancrés au BAS de la boîte (margin px sous le sol). Limité par
-- maxScale pour ne pas pixeliser à outrance. fill (~0.9) = part de la boîte remplie. Réutilisable (niches/fiches).
function Critter.drawFit(view, id, x, y, boxW, boxH, t, facing, fill, maxScale, opts)
  local c = info(id)
  if not c then return end
  fill = fill or 0.9
  maxScale = maxScale or 2.0
  -- scale par la hauteur RÉELLE du contenu (contentH), pas le cadre (h) -> remplissage franc.
  local sH = (boxH * fill) / c.contentH
  local sW = (boxW * fill) / (c.halfW * 2)
  local scale = math.min(maxScale, sH, sW)
  -- pieds calés vers le bas de la boîte : on place le SOL (groundY) à ~ boxH - 1px du bas.
  local footX = x + boxW * 0.5
  local footY = y + boxH - 1
  Critter.drawAt(view, id, footX, footY, scale, t, facing, opts)
end

-- ── Résolution forme/famille -> descripteur de réaction (pour le caller : combat, planches d'export) ──
-- Le caller fournit ENSUITE la phase : opts.atk = { k=desc.k, pr=desc, ph=… }. Fallbacks sûrs (cf. en-tête des tables).
-- Headless-safe : info() est no-op sans grille (mock) -> retombe sur les tables par id direct si possible, sinon défaut.
local function specOf(id) -- (arch, family) de l'unité, via le cache info() si dispo, sinon via le spec Units.
  local c = cache[id] or info(id)
  if c then return c.arch, c.family end
  local spec = Units[id]
  return nil, spec and spec.family
end

-- Descripteur d'attaque de l'unité (table {k,...}). Défaut : lunge. À passer tel quel comme `pr` + `.k` dans opts.atk.
function Critter.atkFor(id)
  local arch = specOf(id)
  return (arch and ATK[arch]) or ATK_FALLBACK
end
-- Kind de réaction aux dégâts (string). Défaut : recoil.
function Critter.hurtFor(id)
  local _, family = specOf(id)
  return (family and HURT[family]) or "recoil"
end
-- Kind de mort (string). Défaut : gib.
function Critter.deathFor(id)
  local _, family = specOf(id)
  return (family and DEATH[family]) or "gib"
end

-- Tables exposées (lecture seule) pour un caller qui résout par forme/famille directement (ex. arena_draw B.1b).
Critter.ATK, Critter.HURT, Critter.DEATH = ATK, HURT, DEATH

-- Réinitialise le cache (changement de palette / tests). La grille live elle-même est cachée côté CreatureGen.
function Critter.clear() cache = {}; PIXEL = nil end

return Critter
