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
local Juice = require("src.ui.juice") -- MOUVEMENT « candy » : screen-shake trauma² + hitstop, piloté au dt MURAL (RENDER pur)
local SFX = require("src.audio.sfx") -- SON PROCÉDURAL (identité Oniric grave) : bake + câble les hooks Feel ; no-op headless
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
  elseif name == "inspect" then
    -- BUILD VERROUILLÉ (depuis le Proving Ground) : inspecte une compo figée (hover/auras/fiche TOUS actifs),
    -- SANS boutique ni économie ; le bouton FIGHT lance le combat fourni (payload.fight). Host WRAPPER run=nil
    -- -> la scène build se comporte en sandbox (pas de bannière/boutique/orbe) SANS toucher au run réel.
    -- Recréé à chaque entrée (compo fraîche, board propre). [esc] -> retour playground.
    local lockedHost = setmetatable({ run = nil }, { __index = host })
    local b = Build.new(Palette, VW, VH, lockedHost)
    b:setupLocked(payload)
    host.scene = b
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
    if host.build and host.build.onEnter then host.build:onEnter() end -- repart au repos (anti hover collé post-combat)
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
  -- CANAL 3 — JALON DE PALIER (refonte reliques 2026-06, plan relics-overhaul §3.3) : une cérémonie GARANTIE
  -- à la 3e ET 6e victoire, plancher minTier="mid" (le jalon ne sert jamais 3 stat-sticks ; à w6, le plafond
  -- vaut déjà HAUT -> vrai payoff late). Placé AVANT le test marchand `% 3` AVEC un `return` -> ANTI
  -- DOUBLE-COMPTAGE (§3.4) : à w3, `combats % 3` peut valoir 0 mais le jalon CONSOMME le créneau (1 seul
  -- relicpick servi). Routage post-combat (comme le marchand) -> startRound au retour (PAS midRound).
  if win and (host.run.wins == 3 or host.run.wins == 6) then
    local choices = host.run:rollRelicChoices(3, { minTier = "mid" })
    if #choices > 0 then host.goto("relicpick", { choices = choices, milestone = true }); return end
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

-- HARNAIS D'EXPORT (DEV / RENDER pur) : capté AVANT tout démarrage normal du jeu si un flag CLI est présent.
-- `args` = arguments de jeu déjà parsés par love.run (love.arg.parseGameArguments) -> liste 1-indexée des
-- flags utilisateur (`args[1] == "--export-bestiary"`, `"--shoot=menu"`, ...). Le harnais fait son travail puis
-- love.event.quit() : la branche n'EST JAMAIS atteinte sans flag explicite (démarrage normal byte-for-byte intact).
-- Ce code est RENDER-only, hors SIM, ignoré de check.sh/golden -> aucune empreinte sur le déterminisme.
local function tryExport(args)
  if not args then return false end
  local doBestiary, shoot = false, nil
  for _, a in ipairs(args) do
    if a == "--export-bestiary" then doBestiary = true
    else
      local name = type(a) == "string" and a:match("^%-%-shoot=(.+)$")
      if name then shoot = name end
    end
  end
  if not doBestiary and not shoot then return false end

  -- L'export rasterise dans des Canvas réels : on s'assure du filtre nearest (cohérent avec le jeu) et on
  -- charge la DA (polices) pour que les captures de scènes affichent le texte. Aucun host/scène de jeu monté ici.
  love.graphics.setDefaultFilter("nearest", "nearest")
  if Theme.load then Theme.load() end
  if Grimoire.load then Grimoire.load() end
  if Bestiary.load then Bestiary.load() end

  local Export = require("src.core.export")
  if doBestiary then
    local n, dir = Export.bestiary()
    print(string.format("[export] bestiary: %d PNG -> %s/ (save dir: %s)", n, dir, love.filesystem.getSaveDirectory()))
  end
  if shoot then
    local Scenes = require("src.core.export_scenes")
    local function one(name)
      local builder = Scenes.builder(name)
      if not builder then
        print("[export] shoot: UNKNOWN scene '" .. tostring(name) .. "' (known: " .. table.concat(Scenes.names, ", ") .. ")")
        return
      end
      local ok, res = pcall(Export.shoot, name, builder)
      if ok then print(string.format("[export] shoot %s -> %s (save dir: %s)", name, res, love.filesystem.getSaveDirectory()))
      else print("[export] shoot " .. name .. " FAILED: " .. tostring(res)) end
    end
    if shoot == "all" then for _, nm in ipairs(Scenes.names) do one(nm) end else one(shoot) end
  end

  love.event.quit()
  return true
end

function love.load(args)
  if tryExport(args) then return end -- DEV : export PNG demandé -> on a tout fait + quit, on n'amorce pas le jeu

  love.graphics.setDefaultFilter("nearest", "nearest") -- AVANT toute création d'Image/Canvas
  love.graphics.setLineStyle("rough")
  love.graphics.setBackgroundColor(0.024, 0.016, 0.039)

  canvas = love.graphics.newCanvas(VW, VH)
  canvas:setFilter("nearest", "nearest")

  postfx = PostFX.new() -- SURCOUCHE CAUCHEMARDESQUE : shader+canvas natifs créés une fois (no-op si GPU/shader absent)

  Theme.load() -- charge polices + DA une fois (pré-chauffe les tailles courantes ; fallback si TTF absent)
  pcall(SFX.load) -- SON : bake les SFX (Oniric grave) UNE fois + câble Feel.onHover/onPress -> tout l'UI sonne (no-op si pas de device)
  Grimoire.load() -- charge le codex persistant (reliques identifiées, méta-progression cross-run)
  Dev.load()      -- MODE DEV : restaure l'état du toggle full-unlock (inerte si Dev.ENABLED = false)
  Bestiary.load() -- codex des créatures rencontrées (méta cross-run)
  host.goto("menu") -- écran titre ; "ENTER THE PIT" lance une run (host.newRun)
end

function love.update(dt)
  if host.overlay then return end -- Chronique ouverte : le jeu derrière est FIGÉ (combat/anims gelés)
  if not host.scene then return end -- mode export/--shoot : la scène GLOBALE n'est pas montée (Export.shoot a son propre host)
  -- HITSTOP (juice) : le dt de la SCÈNE/MONDE est multiplié par Juice.timeScale() -> 0 pendant un micro-gel
  -- (gros coup/mort), 1 sinon. La SIM ne fait que SUSPENDRE sa progression À L'ÉCRAN ; le pas reste fixe et
  -- le total de pas est inchangé (le golden tourne l'arène directement, hors de cette boucle) -> empreinte
  -- intacte. Feel/Juice eux-mêmes ne sont JAMAIS gelés (avancés au dt mural dans love.draw).
  host.scene:update(dt * FRAME * Juice.timeScale()) -- ~1.0 par tick au pas fixe 1/60 (0 pendant un hitstop)
end

function love.draw()
  local scene = host.scene
  if not scene then return end -- mode export/--shoot : la scène GLOBALE n'est pas montée (Export.shoot a son propre host)

  -- 0. Vue (scale FRACTIONNAIRE = REMPLIT la fenêtre, plus de letterbox entier) calculée d'abord : tout
  -- (monde pixel, UI, atmosphère, post-fx) en dépend, tout reste aligné. On garde l'ASPECT 16:9 du design ->
  -- sur une fenêtre 16:9 (cas courant + plein écran desktop), ox/oy ≈ 0 => remplissage EXACT, ZÉRO barre noire.
  -- Le texte d'UI reste NET (rasterisé à la résolution native, cf. Draw/Theme.fontNative) ; le monde pixel est
  -- blité à ce scale (léger non-entier seulement hors multiples exacts de 320×180 -> mais fini les bandes noires).
  local sw, sh = love.graphics.getDimensions()
  local scale = math.max(1, math.min(sw / VW, sh / VH))
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

  -- SCREEN-SHAKE (juice trauma²) : on avance Juice au dt MURAL (1×/frame réelle, JAMAIS gelé par le hitstop)
  -- puis on ENROBE scène + monde + chrome d'un transform translate/rotate autour du CENTRE écran (comme
  -- feel-lab/main.lua). shx/shy sont en px DESIGN 1280×720 -> ramenés en px écran par s = scale/4 (le design
  -- = virtuel 320×180 ×4). La Chronique (overlay modal) et la surcouche shader restent HORS du shake
  -- (lisibilité). RENDER pur : Juice ne lit/écrit jamais la SIM. dt mural via getDelta (0 en headless).
  do
    local wallDt = (love.timer and love.timer.getDelta and love.timer.getDelta()) or 0
    Juice.update(wallDt)
  end
  local shx, shy, shr = Juice.shake()
  local shaking = (shx ~= 0 or shy ~= 0 or shr ~= 0)
  if shaking and love.graphics.push then
    local s = scale / 4
    love.graphics.push()
    love.graphics.translate(sw / 2, sh / 2); love.graphics.rotate(shr); love.graphics.translate(-sw / 2, -sh / 2)
    love.graphics.translate(shx * s, shy * s)
  end

  -- 1. Pre-pass ATMOSPHÈRE native (glows lisses), DERRIÈRE le monde pixel. Optionnel par scène.
  if scene.drawBack then scene:drawBack(view) end

  -- 2-3. Monde. Deux chemins :
  --   • `scene.nativeWorld` -> rendu DIRECT en résolution écran. Les sprites primgen font 64px : passés par le
  --     canvas 320×180 ils étaient réduits à ~32px puis ré-agrandis ×4 (double rééchantillonnage = bouillie de
  --     pixels). Le MÊME transform que le blit (translate ox/oy + scale ENTIER) => positions/tailles identiques
  --     au canvas, mais un seul rééchantillonnage => créatures NETTES (cf. combat/build/gallery).
  --   • sinon -> canvas virtuel basse-réso (look pixel du décor), blit en scale ENTIER. Clear TRANSPARENT :
  --     l'atmosphère transparaît dans les vides (nearest + scale entier => alpha droit correct, pas de halo).
  -- Le monde HORS-canvas (nativeWorld + le blit) hérite du transform de shake ci-dessus -> il TREMBLE. La passe
  -- vers le canvas virtuel (setCanvas) écrit dans un buffer à son PROPRE repère : on neutralise le shake le temps
  -- de le remplir (origin) puis on le restaure pour BLITTER le canvas (c'est le blit qui tremble, pas la gravure).
  love.graphics.setColor(1, 1, 1, 1)
  if scene.nativeWorld then
    love.graphics.push()
    love.graphics.translate(view.ox, view.oy)
    love.graphics.scale(scale, scale)
    scene:drawWorld()
    love.graphics.pop()
  else
    love.graphics.setCanvas(canvas)
    love.graphics.push(); love.graphics.origin() -- grave le décor dans le buffer SANS le shake (repère canvas)
    love.graphics.clear(0, 0, 0, 0)
    scene:drawWorld()
    love.graphics.pop()
    love.graphics.setCanvas(fxCanvas) -- restaure la cible (canvas natif fx, ou écran si surcouche inactive)
    love.graphics.draw(canvas, view.ox, view.oy, 0, scale, scale) -- ce BLIT hérite du shake -> le décor tremble
  end

  -- 4. UI native par-dessus (texte net). La chrome DA est portée par la scène ; sinon HUD générique.
  scene:drawOverlay(view)
  if not scene.daChrome then drawHud(scene) end

  if shaking and love.graphics.pop then love.graphics.pop() end -- fin du transform de shake (scène + chrome)

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
    if host.name == "inspect" then host.goto("playground"); return end -- build verrouillé -> retour banc d'essai
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
  if host.scene and host.scene.keypressed then host.scene:keypressed(key) end
end

function love.mousepressed(x, y, button)
  local vx, vy = toVirtual(x, y)
  if host.overlay then
    -- modal : capte tout. Le bouton X renvoie "close" -> on referme l'overlay (le reste reste capté).
    if host.overlay:mousepressed(vx, vy, button) == "close" then host.overlay = nil end
    return
  end
  if not (host.scene and host.scene.mousepressed) then return end
  host.scene:mousepressed(vx, vy, button)
end

function love.mousereleased(x, y, button)
  if host.overlay then return end
  if not (host.scene and host.scene.mousereleased) then return end
  local vx, vy = toVirtual(x, y)
  host.scene:mousereleased(vx, vy, button)
end

function love.mousemoved(x, y)
  local vx, vy = toVirtual(x, y)
  if host.overlay then
    if host.overlay.mousemoved then host.overlay:mousemoved(vx, vy) end -- survol des boutons forge de l'overlay
    return -- la scène derrière est figée
  end
  if not (host.scene and host.scene.mousemoved) then return end
  host.scene:mousemoved(vx, vy)
end

-- Molette : défilement des listes scrollables (la scène décide). dx,dy en crans.
function love.wheelmoved(dx, dy)
  if host.overlay then host.overlay:wheelmoved(dx, dy); return end -- scroll du journal
  if host.scene and host.scene.wheelmoved then host.scene:wheelmoved(dx, dy) end
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
