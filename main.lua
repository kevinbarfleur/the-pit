-- main.lua — point d'entrée LÖVE (11.5).
--
-- Pipeline de rendu :
--   monde -> Canvas virtuel basse résolution (320x180) -> blit en SCALE ENTIER, letterbox.
-- C'est le pattern pixel-perfect recommandé : chaque pixel source = bloc N×N à l'écran.
--
-- Boucle : love.run est surchargée en bas du fichier avec un PAS DE TEMPS FIXE
-- (accumulateur), prérequis d'un combat déterministe pour un autobattler.

local Palette = require("src.core.palette")
local Build = require("src.scenes.build")
local Combat = require("src.scenes.combat")
local Runover = require("src.scenes.runover")
local Gallery = require("src.scenes.gallery")
local Relicons = require("src.scenes.relicons")
local Menu = require("src.scenes.menu")
local Relicpick = require("src.scenes.relicpick")
local GrimoireScene = require("src.scenes.grimoire")
local Playground = require("src.scenes.playground")
local ForgeIter = require("src.scenes.forge_iter") -- vue d'iteration dev : isole les creatures en cours de refonte
local DesignSystem = require("src.scenes.designsystem") -- STORYBOOK in-engine : source de vérité visuelle de l'UI
local RunState = require("src.run.state")
local ChronicleOverlay = require("src.render.chronicle_overlay") -- LA CHRONIQUE : overlay modal (journal de combat)
local PostFX = require("src.render.postfx") -- SURCOUCHE CAUCHEMARDESQUE : post-fx RENDER-pur par-dessus l'UI nette ([F9])
local Grimoire = require("src.core.grimoire")
local Dev = require("src.core.dev") -- MODE DEV (cheat) : toggle full-unlock du codex (menu) ; master switch Dev.ENABLED
local Bestiary = require("src.core.bestiary") -- codex des créatures rencontrées (persistant, full-unlock-aware)
local Theme = require("src.ui.theme")
local T = require("src.core.i18n").t

local VW, VH = 320, 180           -- résolution virtuelle (×4 = 1280×720 pile)
local FRAME = 60                  -- conversion dt(s) -> "frames" pour l'horloge des anims
local canvas
local postfx                      -- SURCOUCHE CAUCHEMARDESQUE (post-fx RENDER-pur ; nil/inerte en headless)
local view = { scale = 1, ox = 0, oy = 0 }

-- Mini state-machine : build <-> combat, enrobée par la méta de RUN (host.run). Une scène demande
-- une transition via host.goto(name, payload). La phase build est PERSISTANTE sur tout le run (le
-- plateau est conservé de round en round) ; combat et runover sont recréés à chaque entrée.
local host = { scene = nil, name = nil, build = nil, run = nil, overlay = nil }

-- LA CHRONIQUE : overlay modal ouvrable n'importe où dans une run ([c]). Construit avec la chronique du
-- combat EN COURS (si on y est) + l'historique archivé (run.chronicles). Toggle : referme si déjà ouvert.
function host.openChronicle()
  if host.overlay then host.overlay = nil; return end
  if not host.run then return end -- pas de chronique hors run (menu)
  local cur = (host.name == "combat" and host.scene and host.scene.chron) or nil
  host.overlay = ChronicleOverlay.new(host.run, cur)
end

function host.goto(name, payload)
  if name == "combat" then
    host.scene = Combat.new(Palette, VW, VH, host, payload)
  elseif name == "runover" then
    host.scene = Runover.new(Palette, VW, VH, host, payload)
  elseif name == "relicpick" then
    host.scene = Relicpick.new(Palette, VW, VH, host, payload)
  elseif name == "gallery" then
    -- Galerie de revue visuelle (debug) : construite à la demande, mémoïsée (indépendante du run).
    host.gallery = host.gallery or Gallery.new(Palette, VW, VH, host)
    host.scene = host.gallery
  elseif name == "relicons" then
    -- Cabinet de reliques (debug) : revue visuelle des icônes d'artefacts ; mémoïsé (indépendant du run).
    host.relicons = host.relicons or Relicons.new(Palette, VW, VH, host)
    host.scene = host.relicons
  elseif name == "menu" then
    -- Écran titre : mémoïsé (indépendant du run). ENTER THE PIT -> host.newRun().
    host.menu = host.menu or Menu.new(Palette, VW, VH, host)
    host.scene = host.menu
  elseif name == "grimoire" then
    -- Codex persistant (reliques + bestiaire) : mémoïsé (rigs construits une fois) ; refresh() relit connu/vu.
    host.grimoire = host.grimoire or GrimoireScene.new(Palette, VW, VH, host)
    host.grimoire:refresh()
    host.scene = host.grimoire
  elseif name == "playground" then
    -- Banc d'essai (Proving Ground) : mémoïsé (indépendant du run ; lit le catalogue de compos).
    host.playground = host.playground or Playground.new(Palette, VW, VH, host)
    host.scene = host.playground
  elseif name == "forge_iter" then
    -- Vue d'ITÉRATION (dev) : revue isolée des créatures en cours de refonte. Mémoïsée (rigs bakés une fois).
    host.forgeIter = host.forgeIter or ForgeIter.new(Palette, VW, VH, host)
    host.scene = host.forgeIter
  elseif name == "designsystem" then
    -- Storybook in-engine (source de vérité VISUELLE de l'UI) : mémoïsé (indépendant du run).
    host.designsystem = host.designsystem or DesignSystem.new(Palette, VW, VH, host)
    host.scene = host.designsystem
  else
    host.scene = host.build
  end
  host.name = name
end

-- Fin d'un combat : la méta de run résout l'issue (vies/victoires/streaks), puis ouvre le round
-- suivant (retour build, plateau PERSISTANT) — ou l'écran de fin de run si le run est conclu.
function host.finishCombat(win)
  -- Archive le journal du combat (pour le sélecteur de round de la Chronique) AVANT de résoudre/changer de scène.
  if host.scene and host.scene.chron then
    host.run:archiveChronicle(host.scene.chron.entries,
      { round = host.run.round, win = win, enemyKey = host.scene.enemyKey })
  end
  host.run:resolve(win)
  local over = host.run:isOver()
  if over then
    host.goto("runover", { result = over, run = host.run })
    return
  end
  -- Acquisition : un MARCHAND passe tous les 3 COMBATS (victoire OU défaite), pas toutes les 3 victoires
  -- (PRD progression-economy §5.1) -> ~5-6 offres/run, densité de choix build-shaping. Écran 1-parmi-3
  -- (« A Fragment Surfaces »). Si le pool est épuisé (#choices == 0), on saute directement au round suivant.
  local combats = host.run.wins + host.run.losses
  if combats % 3 == 0 then
    local choices = host.run:rollRelicChoices(3)
    if #choices > 0 then host.goto("relicpick", { choices = choices }); return end
  end
  host.run:startRound()
  host.goto("build")
end

-- Récompense de LEVEL-UP (Lot 5, PRD progression-economy §5.2) : une fusion en phase build (3 copies ->
-- niveau+1) ouvre une offre 1-parmi-3, mais BORNÉE 1/round (drapeau run.relicFromLevelThisRound, posé par
-- la scène build). On marque _relicMidRound : le retour de choix (finishRelicPick*) reste sur le MÊME round
-- (PAS de startRound -> boutique/or/plateau préservés). Si le pool est épuisé (#choices == 0), on ne fait
-- RIEN (on reste en build : pas d'écran vide). C'est build:checkMerges qui garde l'unicité par round.
function host.offerLevelUpRelic()
  local choices = host.run:rollRelicChoices(3)
  if #choices > 0 then
    host._relicMidRound = true
    host.goto("relicpick", { choices = choices, midRound = true })
  end
end

-- Choix de relique confirmé (BIND) : octroi + inscription au Grimoire (collection cross-run). Le routage
-- post-choix DÉPEND de l'origine de l'offre (lue puis effacée) : MID-ROUND (level-up §5.2) -> retour au MÊME
-- round (board/boutique/or préservés, AUCUN startRound) ; POST-COMBAT (marchand /3) -> round suivant.
function host.finishRelicPick(id)
  host.run:grantRelic(id)
  Grimoire.learn(id)
  local midRound = host._relicMidRound
  host._relicMidRound = nil
  if not midRound then host.run:startRound() end
  host.goto("build")
end

-- Refus de l'offre de relique (REFUSE) : +or (declineRelic) au lieu d'une relique ; AUCUNE inscription au
-- Grimoire (rien appris). Routage selon l'origine (lue puis effacée) :
--   · MID-ROUND (level-up §5.2) : AUCUN startRound -> le +or de declineRelic PERSISTE dans le round courant.
--   · POST-COMBAT (marchand /3) : startRound D'ABORD (budget SAP frais), PUIS declineRelic -> le +or se
--     pose PAR-DESSUS le budget du round suivant (sinon il serait écrasé par le reset d'or de startRound).
function host.finishRelicPickDecline()
  local midRound = host._relicMidRound
  host._relicMidRound = nil
  if not midRound then host.run:startRound() end
  host.run:declineRelic()
  host.goto("build")
end

-- Démarre une run neuve : nouvel état seedé (boutique/seeds de combat dérivés) + plateau remis à zéro.
function host.newRun()
  host.run = RunState.new(love.math.random(1, 2147483647))
  host.build = Build.new(Palette, VW, VH, host)
  host.goto("build")
end

local function drawHud(scene)
  love.graphics.setColor(0.78, 0.72, 0.60, 0.9)
  love.graphics.print(T("ui.title") .. "  -  " .. T(scene.titleKey or "ui.empty"), 16, 12)
  love.graphics.setColor(0.40, 0.34, 0.30, 1)
  love.graphics.print(T("ui.fps", { n = love.timer.getFPS() }), 16, 30)
  love.graphics.print(T(scene.hintKey or "ui.empty") .. "   -   " .. T("ui.quit"), 16, 46)
  love.graphics.setColor(1, 1, 1, 1)
end

-- Pixels fenêtre -> espace virtuel (inverse exact du blit en scale entier).
-- LÖVE 11 + highdpi : les events souris ET love.graphics partagent le MÊME espace PIXELS (getDimensions
-- renvoie des pixels ; la souris aussi). Donc AUCUNE conversion DPI ici — appliquer toPixels re-scalait du
-- facteur DPI et décalait tous les clics (×2 sur Retina). On inverse directement le blit.
local function toVirtual(x, y)
  if view.scale <= 0 then return x, y end
  return (x - view.ox) / view.scale, (y - view.oy) / view.scale
end

function love.load()
  love.graphics.setDefaultFilter("nearest", "nearest") -- AVANT toute création d'Image/Canvas
  love.graphics.setLineStyle("rough")
  love.graphics.setBackgroundColor(0.024, 0.016, 0.039)

  canvas = love.graphics.newCanvas(VW, VH)
  canvas:setFilter("nearest", "nearest")

  postfx = PostFX.new() -- SURCOUCHE CAUCHEMARDESQUE : shader+canvas natifs créés une fois (no-op si GPU/shader absent)

  Theme.load() -- charge polices + DA une fois (pré-chauffe les tailles courantes ; fallback si TTF absent)
  Grimoire.load() -- charge le codex persistant (reliques identifiées, méta-progression cross-run)
  Dev.load()      -- MODE DEV : restaure l'état du toggle full-unlock (inerte si Dev.ENABLED = false)
  Bestiary.load() -- codex des créatures rencontrées (méta cross-run)
  host.goto("menu") -- écran titre ; "ENTER THE PIT" lance une run (host.newRun)
end

function love.update(dt)
  if host.overlay then return end -- Chronique ouverte : le jeu derrière est FIGÉ (combat/anims gelés)
  host.scene:update(dt * FRAME) -- ~1.0 par tick au pas fixe 1/60
end

function love.draw()
  local scene = host.scene

  -- 0. Vue (scale ENTIER + letterbox) calculée d'abord : l'atmosphère native en dépend.
  local sw, sh = love.graphics.getDimensions()
  local scale = math.max(1, math.floor(math.min(sw / VW, sh / VH)))
  view.scale = scale
  view.ox = math.floor((sw - VW * scale) / 2)
  view.oy = math.floor((sh - VH * scale) / 2)

  -- 0bis. SURCOUCHE CAUCHEMARDESQUE : on rend TOUTE la frame dans un canvas à la RÉSOLUTION NATIVE (sw,sh),
  -- puis on le blit 1:1 à travers le shader (endFrame) -> ZÉRO rééchantillonnage, le texte reste net. Si la
  -- surcouche est inactive (toggle off / headless), fxOn = false et le pipeline rend directement à l'écran
  -- (inchangé). dt mural via getDelta (RENDER : pas de déterminisme requis) ; absent en headless -> 0.
  local fxOn = false
  if postfx then
    local dt = (love.timer and love.timer.getDelta and love.timer.getDelta()) or 0
    fxOn = postfx:beginFrame(dt, sw, sh)
  end
  -- Cible à restaurer après les passes monde (un setCanvas() nu retournerait à l'écran, court-circuitant la
  -- capture). fxCanvas = le canvas natif si la surcouche est engagée, sinon nil (== écran : comportement par défaut).
  local fxCanvas = postfx and postfx:currentCanvas() or nil

  -- 1. Pre-pass ATMOSPHÈRE native (glows lisses), DERRIÈRE le monde pixel. Optionnel par scène.
  if scene.drawBack then scene:drawBack(view) end

  -- 2-3. Monde. Deux chemins :
  --   • `scene.nativeWorld` -> rendu DIRECT en résolution écran. Les sprites primgen font 64px : passés par le
  --     canvas 320×180 ils étaient réduits à ~32px puis ré-agrandis ×4 (double rééchantillonnage = bouillie de
  --     pixels). Le MÊME transform que le blit (translate ox/oy + scale ENTIER) => positions/tailles identiques
  --     au canvas, mais un seul rééchantillonnage => créatures NETTES (cf. combat/build/gallery).
  --   • sinon -> canvas virtuel basse-réso (look pixel du décor), blit en scale ENTIER. Clear TRANSPARENT :
  --     l'atmosphère transparaît dans les vides (nearest + scale entier => alpha droit correct, pas de halo).
  love.graphics.setColor(1, 1, 1, 1)
  if scene.nativeWorld then
    love.graphics.push()
    love.graphics.translate(view.ox, view.oy)
    love.graphics.scale(scale, scale)
    scene:drawWorld()
    love.graphics.pop()
  else
    love.graphics.setCanvas(canvas)
    love.graphics.clear(0, 0, 0, 0)
    scene:drawWorld()
    love.graphics.setCanvas(fxCanvas) -- restaure la cible (canvas natif fx, ou écran si surcouche inactive)
    love.graphics.draw(canvas, view.ox, view.oy, 0, scale, scale)
  end

  -- 4. UI native par-dessus (texte net). La chrome DA est portée par la scène ; sinon HUD générique.
  scene:drawOverlay(view)
  if not scene.daChrome then drawHud(scene) end

  -- 5. Overlay MODAL (La Chronique) par-dessus tout, si ouvert.
  if host.overlay then host.overlay:draw(view) end

  -- 6. SURCOUCHE CAUCHEMARDESQUE : rend le MASQUE des bandes-bordures (sous le MÊME `view` que l'UI), décroche
  -- le canvas et le blit 1:1 à travers le shader -> la distorsion d'UV est CONFINÉE aux bordures des box (le
  -- fond/monde/centre des box restent nets). La `tension` (0..1) ferme la vignette quand le run tourne mal (vies
  -- perdues) -> l'écran « se ferme ». 100% RENDER (firewall SIM). `view` est requis pour aligner l'anneau.
  if fxOn then
    local tension = 0
    local run = host.run
    if run and run.lives and RunState.START_LIVES then
      tension = math.max(0, math.min(1, 1 - run.lives / RunState.START_LIVES))
    end
    postfx:endFrame(view, tension)
  end
end

function love.keypressed(key)
  -- Plein écran (desktop) : [F11] ou Alt+Entrée. "desktop" garde la résolution du bureau (pas de changement
  -- de mode) ; love.draw recalcule `view` sur getDimensions chaque frame -> s'adapte sans rien recréer.
  if key == "f11" or (key == "return" and (love.keyboard.isDown("lalt") or love.keyboard.isDown("ralt"))) then
    love.window.setFullscreen(not love.window.getFullscreen(), "desktop")
    return
  end
  -- [F9] : bascule la SURCOUCHE CAUCHEMARDESQUE (post-fx) ON/OFF, n'importe où, pour comparer le rendu net
  -- vs grimdark. Capté en priorité (comme le plein écran) ; inerte si la surcouche n'est pas disponible.
  if key == "f9" then
    if postfx then postfx:toggle() end
    return
  end
  -- LA CHRONIQUE (overlay modal) : capte le clavier en priorité tant qu'elle est ouverte.
  if host.overlay then
    if key == "escape" or key == "c" then host.overlay = nil; return end
    host.overlay:keypressed(key); return
  end
  -- [c] ouvre la Chronique (n'importe où dans une run) : journal du combat + sélecteur de round.
  if key == "c" and host.run and (host.name == "build" or host.name == "combat" or host.name == "runover") then
    host.openChronicle(); return
  end
  if key == "escape" then
    -- Depuis le Grimoire ou le Proving Ground (ouverts via le menu) : retour menu ; sinon quitte.
    if host.name == "grimoire" or host.name == "playground" or host.name == "designsystem" then host.goto("menu"); return end
    if host.name == "forge_iter" then host.goto("build"); return end -- vue d'itération : retour build
    love.event.quit(); return
  end
  -- [g] bascule build <-> galerie (revue visuelle des entités). Réservé aux scènes de revue.
  if key == "g" and (host.name == "build" or host.name == "gallery" or host.name == "relicons") then
    host.goto(host.name == "gallery" and "build" or "gallery"); return
  end
  -- [i] bascule build/galerie <-> vue d'ITÉRATION (dev) : créatures en cours de refonte, isolées et en grand.
  if key == "i" and (host.name == "build" or host.name == "gallery" or host.name == "forge_iter") then
    host.goto(host.name == "forge_iter" and "build" or "forge_iter"); return
  end
  -- [r] bascule build/galerie <-> cabinet de reliques (revue visuelle des icônes d'artefacts).
  if key == "r" and (host.name == "build" or host.name == "gallery" or host.name == "relicons") then
    host.goto(host.name == "relicons" and "build" or "relicons"); return
  end
  if host.scene.keypressed then host.scene:keypressed(key) end
end

function love.mousepressed(x, y, button)
  local vx, vy = toVirtual(x, y)
  if host.overlay then
    -- modal : capte tout. Le bouton X renvoie "close" -> on referme l'overlay (le reste reste capté).
    if host.overlay:mousepressed(vx, vy, button) == "close" then host.overlay = nil end
    return
  end
  if not host.scene.mousepressed then return end
  host.scene:mousepressed(vx, vy, button)
end

function love.mousereleased(x, y, button)
  if host.overlay then return end
  if not host.scene.mousereleased then return end
  local vx, vy = toVirtual(x, y)
  host.scene:mousereleased(vx, vy, button)
end

function love.mousemoved(x, y)
  local vx, vy = toVirtual(x, y)
  if host.overlay then
    if host.overlay.mousemoved then host.overlay:mousemoved(vx, vy) end -- survol des boutons forge de l'overlay
    return -- la scène derrière est figée
  end
  if not host.scene.mousemoved then return end
  host.scene:mousemoved(vx, vy)
end

-- Molette : défilement des listes scrollables (la scène décide). dx,dy en crans.
function love.wheelmoved(dx, dy)
  if host.overlay then host.overlay:wheelmoved(dx, dy); return end -- scroll du journal
  if host.scene.wheelmoved then host.scene:wheelmoved(dx, dy) end
end

-- ───────────────────────── Boucle à pas de temps fixe ─────────────────────────
-- love.update est toujours appelée avec dt = TICK (déterministe) ; love.draw tourne
-- une fois par frame. MAX_SKIP borne le rattrapage pour éviter la "spirale de la mort".
-- Réf : https://love2d.org/wiki/love.run · https://gafferongames.com/post/fix_your_timestep/
local TICK = 1 / 60
local MAX_SKIP = 25

function love.run()
  if love.load then love.load(love.arg.parseGameArguments(arg), arg) end
  if love.timer then love.timer.step() end
  local lag = 0.0

  return function()
    if love.event then
      love.event.pump()
      for name, a, b, c, d, e, f in love.event.poll() do
        if name == "quit" then
          if not love.quit or not love.quit() then return a or 0 end
        end
        love.handlers[name](a, b, c, d, e, f)
      end
    end

    if love.timer then lag = math.min(lag + love.timer.step(), TICK * MAX_SKIP) end
    while lag >= TICK do
      if love.update then love.update(TICK) end
      lag = lag - TICK
    end

    if love.graphics and love.graphics.isActive() then
      love.graphics.origin()
      love.graphics.clear(love.graphics.getBackgroundColor())
      if love.draw then love.draw() end
      love.graphics.present()
    end

    if love.timer then love.timer.sleep(0.001) end
  end
end
