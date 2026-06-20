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
local Menu = require("src.scenes.menu")
local Relicpick = require("src.scenes.relicpick")
local RunState = require("src.run.state")
local Grimoire = require("src.core.grimoire")
local Theme = require("src.ui.theme")
local T = require("src.core.i18n").t

local VW, VH = 320, 180           -- résolution virtuelle (×4 = 1280×720 pile)
local FRAME = 60                  -- conversion dt(s) -> "frames" pour l'horloge des anims
local canvas
local view = { scale = 1, ox = 0, oy = 0 }

-- Mini state-machine : build <-> combat, enrobée par la méta de RUN (host.run). Une scène demande
-- une transition via host.goto(name, payload). La phase build est PERSISTANTE sur tout le run (le
-- plateau est conservé de round en round) ; combat et runover sont recréés à chaque entrée.
local host = { scene = nil, name = nil, build = nil, run = nil }

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
  elseif name == "menu" then
    -- Écran titre : mémoïsé (indépendant du run). ENTER THE PIT -> host.newRun().
    host.menu = host.menu or Menu.new(Palette, VW, VH, host)
    host.scene = host.menu
  else
    host.scene = host.build
  end
  host.name = name
end

-- Fin d'un combat : la méta de run résout l'issue (vies/victoires/streaks), puis ouvre le round
-- suivant (retour build, plateau PERSISTANT) — ou l'écran de fin de run si le run est conclu.
function host.finishCombat(win)
  host.run:resolve(win)
  -- Reliques cryptiques (pilier #2) : observation post-combat -> identification -> Grimoire (méta cross-run).
  for _, id in ipairs(host.run:observeRelics()) do Grimoire.learn(id) end
  local over = host.run:isOver()
  if over then
    host.goto("runover", { result = over, run = host.run })
    return
  end
  -- Acquisition : tous les 3 victoires, un écran de CHOIX 1-parmi-3 (« A Fragment Surfaces »).
  if win and host.run.wins % 3 == 0 then
    local choices = host.run:rollRelicChoices(3)
    if #choices > 0 then host.goto("relicpick", { choices = choices }); return end
  end
  host.run:startRound()
  host.goto("build")
end

-- Choix de relique confirmé (BIND) : octroi (identifiée d'emblée si déjà connue au Grimoire), round suivant.
function host.finishRelicPick(id)
  host.run:grantRelic(id, Grimoire.isKnown(id))
  host.run:startRound()
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

  Theme.load() -- charge polices + DA une fois (pré-chauffe les tailles courantes ; fallback si TTF absent)
  Grimoire.load() -- charge le codex persistant (reliques identifiées, méta-progression cross-run)
  host.goto("menu") -- écran titre ; "ENTER THE PIT" lance une run (host.newRun)
end

function love.update(dt)
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

  -- 1. Pre-pass ATMOSPHÈRE native (glows lisses), DERRIÈRE le monde pixel. Optionnel par scène.
  if scene.drawBack then scene:drawBack(view) end

  -- 2. Monde -> canvas virtuel. Clear TRANSPARENT : l'atmosphère transparaît dans les vides (nearest +
  --    scale entier => alpha droit correct, pas de halo). Les scènes opaques (combat) écrasent ce vide.
  love.graphics.setCanvas(canvas)
  love.graphics.clear(0, 0, 0, 0)
  scene:drawWorld()
  love.graphics.setCanvas()

  -- 3. Blit du monde en scale ENTIER, par-dessus l'atmosphère.
  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.draw(canvas, view.ox, view.oy, 0, scale, scale)

  -- 4. UI native par-dessus (texte net). La chrome DA est portée par la scène ; sinon HUD générique.
  scene:drawOverlay(view)
  if not scene.daChrome then drawHud(scene) end
end

function love.keypressed(key)
  if key == "escape" then love.event.quit(); return end
  -- [g] bascule build <-> galerie (revue visuelle des entités). Réservé à ces deux scènes.
  if key == "g" and (host.name == "build" or host.name == "gallery") then
    host.goto(host.name == "gallery" and "build" or "gallery"); return
  end
  if host.scene.keypressed then host.scene:keypressed(key) end
end

function love.mousepressed(x, y, button)
  if not host.scene.mousepressed then return end
  local vx, vy = toVirtual(x, y)
  host.scene:mousepressed(vx, vy, button)
end

function love.mousereleased(x, y, button)
  if not host.scene.mousereleased then return end
  local vx, vy = toVirtual(x, y)
  host.scene:mousereleased(vx, vy, button)
end

function love.mousemoved(x, y)
  if not host.scene.mousemoved then return end
  local vx, vy = toVirtual(x, y)
  host.scene:mousemoved(vx, vy)
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
