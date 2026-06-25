-- src/audio/music.lua
-- DIRECTEUR MUSICAL DYNAMIQUE — joue 2 morceaux en STEMS (pistes séparées, mêmes longueurs, démarrées ensemble
-- + bouclées => restent SYNCHRO) et crossfade DOUX entre eux. 100% RENDER/cosmétique : JAMAIS dans la SIM
-- (combat/board/effects/run), aucune horloge de gameplay. Avancé au dt MURAL réel (pas le pas-fixe seedé).
-- Headless-safe : si love.audio absent (CI / mock LÖVE), TOUT est un no-op propre (mêmes gardes que sfx.lua).
--
-- POURQUOI des stems : un morceau = N pistes (bass/drums/other/piano/vocals) qu'on peut retirer/remonter à
-- chaud pour faire MONTER LA TENSION sans changer de musique (« un seul jeu vivant »). Les drums portent la
-- tension ; on peut aussi pousser `other` (textures) et retirer `vocals` (apaisant) quand ça chauffe.
--
-- POURQUOI suivre le MORCEAU et pas la scène : build↔combat↔relicpick partagent le MÊME morceau -> on ne
-- redémarre RIEN en changeant de scène (continuité). Seul un changement de MORCEAU (menu↔run) déclenche un
-- crossfade. C'est le directeur qui gère cette continuité ; main.lua appelle juste setScene() à chaque goto.
--
-- APIs vérifiées love2d.org/wiki (cible 11.5) :
--   love.audio.newSource(path, "stream")  -- STREAMING depuis le disque (musique longue ; pas "static" qui charge tout en RAM)
--   Source:setLooping(true) · Source:setVolume(0..1) · Source:play() · Source:stop() · Source:pause() · Source:isPlaying()
--   Source:seek(pos[,unit]) · Source:tell([unit])  -- unit défaut "seconds" (re-sync optionnel au bouclage)
--   (En 11.x le SourceType n'est plus optionnel : on le passe explicitement.)
--
-- API : Music.load() · Music.setScene(name) · Music.update(dt) · Music.setTension(level0to1[,fade]) ·
--       Music.setLayer(stem,vol[,fade]) · Music.setMaster(v) · Music.stop() · Music.pause() · Music.resume()

local Music = {}

-- ════════════════════════════════════ Données ════════════════════════════════════
-- Chaque morceau = un dossier + la liste de ses stems présents (les silencieux ont été élagués à l'extraction).
-- L'ordre n'a pas d'importance pour la synchro (tous démarrés/bouclés ensemble) ; il sert juste à itérer.
local TRACKS = {
  ["the-pit-main"] = {
    dir   = "assets/music/the-pit-main/",
    stems = { "bass", "drums", "other", "piano", "vocals" },
  },
  ["arming-the-squad"] = {
    dir   = "assets/music/arming-the-squad/",
    stems = { "bass", "drums", "other" },
  },
}

-- MAPPING SCÈNE -> MORCEAU (consigne user). La musique suit le MORCEAU : toutes les scènes mappées sur le
-- même id partagent la lecture EN CONTINU (zéro redémarrage en passant de l'une à l'autre).
--   the-pit-main     = titre + tous les sous-menus/codex (ambiance, contemplatif)
--   arming-the-squad = la RUN active (préparation, combat, succès, choix de relique, fin de run)
local SCENE_TRACK = {
  -- menu & codex
  menu         = "the-pit-main",
  grimoire     = "the-pit-main",
  relicons     = "the-pit-main",
  gallery      = "the-pit-main",
  designsystem = "the-pit-main",
  playground   = "the-pit-main",
  forge_iter   = "the-pit-main",
  -- run active
  build        = "arming-the-squad",
  inspect      = "arming-the-squad", -- build verrouillé (sandbox du Proving Ground) : reste en ambiance de run
  combat       = "arming-the-squad",
  relicpick    = "arming-the-squad",
  runover      = "arming-the-squad",
}

-- COUCHES DE TENSION (le but des stems). On exprime un niveau 0..1 -> un gain CIBLE par stem.
-- Convention de base : tension 0 = le morceau « comme mixé » (TOUS les stems à plein), c'est le repos.
-- Quand ça chauffe (tension ^), on ne fait que MODULER quelques pistes signifiantes :
--   • drums  : la tension elle-même -> on peut les ATTÉNUER au repos et les remonter à plein sous tension.
--   • vocals : apaisant/onirique -> on les retire un peu sous forte tension (plus pressant).
--   • bass/piano/other : socle harmonique -> restent à plein (le morceau garde son corps).
-- profileFor(track, level) renvoie une table stem->gainCible. Un stem absent du morceau est juste ignoré.
-- NB : par défaut on DÉMARRE à tension 0 mais avec les drums déjà présents (repos = mix complet) ; l'API
-- permet ensuite de descendre/remonter. On garde le design SIMPLE et lisible (pas de courbe par stem cachée).
local function profileFor(track, level)
  level = math.max(0, math.min(1, level or 0))
  local p = {}
  for _, s in ipairs(TRACKS[track] and TRACKS[track].stems or {}) do
    if s == "drums" then
      -- repos (0) = drums à 0.65 (présents mais en retrait) -> tension 1 = drums à 1.0 (plein, pressant).
      p[s] = 0.65 + 0.35 * level
    elseif s == "vocals" then
      -- apaisant : plein au repos, on les estompe sous forte tension (jamais coupés net -> plancher 0.45).
      p[s] = 1.0 - 0.55 * level
    else
      -- socle (bass/piano/other) : toujours plein.
      p[s] = 1.0
    end
  end
  return p
end

-- ════════════════════════════════════ État runtime ════════════════════════════════════
Music.master  = 0.6   -- volume MUSIQUE global, SÉPARÉ du master SFX. Défaut raisonnable (la musique reste un fond).
Music.tension = 0     -- niveau 0..1 courant
Music.current = nil   -- id du morceau actif (nil = rien ne joue)
Music.loaded  = false

-- Pour chaque morceau : { sources = {stem->Source}, gains = {stem->{cur,target,rate}}, base = volume morceau 0..1 (pour le crossfade) }
local tracks = {}
-- base{cur,target,rate} : enveloppe de CROSSFADE par morceau (multiplie tous ses stems). 1 = morceau en avant, 0 = muet.
-- Le volume final d'un stem = master * base.cur(morceau) * gain.cur(stem). Tout est lissé framerate-correct.

local CROSSFADE = 1.2  -- secondes du crossfade menu<->run (doux)
local LAYERFADE = 0.8  -- secondes par défaut d'un fondu de couche (tension)

local function haveAudio() return love and love.audio and love.audio.newSource end

-- pousse une enveloppe {cur,target,rate} vers `target` en `time` secondes (rate = pas/seconde ; 0 = instantané)
local function setEnv(env, target, time)
  env.target = math.max(0, math.min(1, target))
  if not time or time <= 0 then
    env.cur = env.target; env.rate = 0
  else
    -- rate signé en unités/seconde pour parcourir |target-cur| en `time` s (recalculé à chaque appel = robuste)
    env.rate = math.abs(env.target - env.cur) / time
    if env.rate <= 0 then env.rate = 1e-3 end
  end
end

local function stepEnv(env, dt)
  if env.cur == env.target then return end
  local d = (env.rate or 0) * dt
  if env.cur < env.target then env.cur = math.min(env.target, env.cur + d)
  else env.cur = math.max(env.target, env.cur - d) end
end

-- ════════════════════════════════════ Chargement ════════════════════════════════════
-- Crée les Sources STREAM des 2 morceaux (volume 0, bouclés, SANS jouer). Coût mémoire minime (stream =
-- lecture disque à la demande). pcall-gardé côté main.lua ; on garde aussi des gardes internes par fichier.
function Music.load()
  if not haveAudio() then Music.loaded = true; return end
  tracks = {}
  for id, def in pairs(TRACKS) do
    local sources, gains = {}, {}
    for _, stem in ipairs(def.stems) do
      local path = def.dir .. stem .. ".ogg"
      local ok, src = pcall(love.audio.newSource, path, "stream")
      if ok and src then
        src:setLooping(true)        -- chaque stem boucle ; tous de MÊME longueur -> restent calés au bouclage
        src:setVolume(0)            -- silencieux tant qu'on ne l'a pas démarré/fondu
        sources[stem] = src
        gains[stem]   = { cur = 0, target = 0, rate = 0 }
      end
    end
    tracks[id] = { sources = sources, gains = gains, base = { cur = 0, target = 0, rate = 0 } }
  end
  Music.loaded = true
end

-- Démarre TOUS les stems d'un morceau ENSEMBLE (synchro) à la position 0, base montée vers 1 (entrée du crossfade).
local function startTrack(id, fade)
  local t = tracks[id]; if not t then return end
  for _, src in pairs(t.sources) do
    src:stop()        -- repart proprement du début (au cas où il aurait joué avant)
    src:seek(0)       -- toutes les pistes calées sur 0 -> synchro garantie au démarrage
    src:play()
  end
  setEnv(t.base, 1, fade)
end

-- Coupe un morceau : base -> 0 ; les Sources sont réellement stop()ées dans update() quand base atteint 0.
local function fadeOutTrack(id, fade)
  local t = tracks[id]; if not t then return end
  setEnv(t.base, 0, fade)
end

-- (Re)applique le profil de tension d'un morceau : pour chaque stem, gain cible = profil(level), fondu `fade`.
local function applyTension(id, level, fade)
  local t = tracks[id]; if not t then return end
  local prof = profileFor(id, level)
  for stem, g in pairs(t.gains) do
    setEnv(g, prof[stem] or 1, fade)
  end
end

-- ════════════════════════════════════ API publique ════════════════════════════════════

-- Résout le morceau d'une scène et bascule SI ET SEULEMENT SI le morceau change (sinon : continuité totale).
function Music.setScene(name)
  if not haveAudio() then return end
  local want = SCENE_TRACK[name]
  if not want or not tracks[want] then return end  -- scène non mappée (ex. overlay) : on ne touche à rien
  if want == Music.current then return end          -- MÊME morceau -> NE FAIT RIEN (build<->combat<->relicpick continu)

  if Music.current then fadeOutTrack(Music.current, CROSSFADE) end -- fond sortant
  startTrack(want, CROSSFADE)                                       -- play + fond entrant
  applyTension(want, Music.tension, 0)                             -- pose le profil de tension courant d'emblée
  Music.current = want
end

-- Fait avancer crossfades + fondus de couche, applique les volumes, et libère les morceaux totalement muets.
-- À appeler au dt MURAL réel (cf. main.lua) : la musique vit en temps réel, indépendante du pas-fixe seedé.
function Music.update(dt)
  if not haveAudio() then return end
  dt = dt or 0
  for id, t in pairs(tracks) do
    stepEnv(t.base, dt)
    for stem, g in pairs(t.gains) do
      stepEnv(g, dt)
      local src = t.sources[stem]
      if src then
        local vol = Music.master * t.base.cur * g.cur
        src:setVolume(math.max(0, math.min(1, vol)))
      end
    end
    -- morceau devenu totalement muet (sortie de crossfade terminée) -> on l'arrête vraiment (libère le décodeur)
    if t.base.cur <= 0 and t.base.target <= 0 and id ~= Music.current then
      for _, src in pairs(t.sources) do
        if src:isPlaying() then src:stop() end
      end
    end
  end
end

-- Tension globale 0..1 : module les couches du morceau ACTIF (drums montent, vocals s'estompent — cf. profileFor).
function Music.setTension(level, fade)
  Music.tension = math.max(0, math.min(1, level or 0))
  if not haveAudio() then return end
  if Music.current then applyTension(Music.current, Music.tension, fade or LAYERFADE) end
end

-- Réglage MANUEL d'une couche du morceau actif (override ponctuel : ex. couper vocals dès un moment clé).
-- stem = "bass"/"drums"/"other"/"piano"/"vocals" (selon le morceau) ; vol 0..1 ; fade en secondes.
function Music.setLayer(stem, vol, fade)
  if not haveAudio() or not Music.current then return end
  local g = tracks[Music.current] and tracks[Music.current].gains[stem]
  if g then setEnv(g, vol or 1, fade or LAYERFADE) end
end

-- Volume musique global (séparé du master SFX). Appliqué au prochain update (lissage par les enveloppes).
function Music.setMaster(v)
  Music.master = math.max(0, math.min(1, v or 0.6))
end

-- Stoppe TOUTE la musique (et oublie le morceau courant -> un setScene() relancera proprement).
function Music.stop()
  if not haveAudio() then return end
  for _, t in pairs(tracks) do
    setEnv(t.base, 0, 0)
    for _, src in pairs(t.sources) do
      if src:isPlaying() then src:stop() end
    end
  end
  Music.current = nil
end

-- Pause/reprise GLOBALES (ex. fenêtre défocalisée). On ne touche pas aux enveloppes : la reprise repart au mix courant.
function Music.pause()
  if not haveAudio() then return end
  for _, t in pairs(tracks) do
    for _, src in pairs(t.sources) do
      if src:isPlaying() then src:pause() end
    end
  end
end

function Music.resume()
  if not haveAudio() then return end
  for _, t in pairs(tracks) do
    if t.base.target > 0 then
      for _, src in pairs(t.sources) do src:play() end
    end
  end
end

return Music
