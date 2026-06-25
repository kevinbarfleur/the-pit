-- src/core/export.lua
-- HARNAIS D'EXPORT (DEV / RENDER pur) : rend des PNG sur disque pour une revue VISUELLE hors-jeu.
--   · Bestiaire  : chaque créature du roster -> son propre PNG (sprite procédural, agrandi, lisible).
--   · Captures   : une scène rendue dans le pipeline canvas-virtuel du jeu (320x180 ×4 = 1280x720) -> PNG.
--
-- POURQUOI un vrai `love` (et pas le mock headless) : le chemin luajit + tests/mock_love.lua ne RASTERISE
-- aucun pixel (ImageData:setPixel est un no-op, pas d'encode). Ce module exige donc un contexte GL réel —
-- il n'est appelé QUE depuis la branche dev-gated de main.lua:love.load (jamais en headless / jamais par la SIM).
--
-- FIREWALL : module RENDER (utilise love.graphics) ; il n'est PAS sous src/combat|board|effects, n'est lu
-- par AUCUN test (check.sh / golden l'ignorent), et la branche d'appel ne s'arme qu'avec un flag CLI explicite.
--
-- APIs LÖVE 11.5 vérifiées (love2d.org/wiki, 2026-06) :
--   · love.graphics.newCanvas(w, h)                         -> Canvas
--   · Canvas:setFilter("nearest","nearest")                 (pixel-perfect upscale)
--   · love.graphics.setCanvas(canvas) / setCanvas()         (la cible DOIT être nil avant newImageData)
--   · Canvas:newImageData()                                 -> ImageData (variante sans argument)
--   · ImageData:encode("png", "<chemin>")                   -> écrit dans le SAVE DIR (love.filesystem)
--   · love.filesystem.createDirectory(path) / getSaveDirectory()
-- Le PNG atterrit dans le dossier de SAUVEGARDE (conf.lua t.identity = "the-pit").

local Palette      = require("src.core.palette")
local Units        = require("src.data.units")
local CreatureGen  = require("src.gen.creaturegen")
local Rig          = require("src.core.rig")

local Export = {}

-- Helper commun : décroche la cible courante, rend `fn` dans un canvas neuf, l'encode en PNG (save dir).
-- `fn(w, h, target)` dessine dans l'espace [0..w]×[0..h] (origine à 0,0, fond transparent). `target` = le
-- canvas d'export : à re-cibler (setCanvas(target)) si `fn` doit lui-même décrocher la cible (passe via un
-- canvas virtuel intermédiaire) -> sans ça, le rendu retomberait sur l'écran et le PNG serait vide.
local function renderToPng(w, h, path, fn)
  local prev = love.graphics.getCanvas() -- restaure la cible précédente (sûr même si nil = écran)
  local cv = love.graphics.newCanvas(w, h)
  cv:setFilter("nearest", "nearest")

  love.graphics.setCanvas(cv)
  love.graphics.clear(0, 0, 0, 0) -- fond TRANSPARENT (silhouette nette à l'agrandissement)
  love.graphics.push("all")
  love.graphics.origin()
  love.graphics.setColor(1, 1, 1, 1)
  fn(w, h, cv)
  love.graphics.pop()
  love.graphics.setCanvas() -- la cible DOIT être décrochée avant newImageData (cf. wiki)

  local data = cv:newImageData()
  data:encode("png", path) -- écrit dans le SAVE DIR
  if data.release then data:release() end
  if cv.release then cv:release() end

  love.graphics.setCanvas(prev) -- restaure (no-op si on était sur l'écran)
end

-- ───────────────────────── Bestiaire : 1 PNG par unité ─────────────────────────
-- Pour CHAQUE id du roster : on résout le MÊME def visuel que le jeu (CreatureGen.cached) — qui délègue au
-- générateur par primitives -> sprite 64×64 dans une part « body » (pivot bas-centre). On le rend à l'échelle
-- NATIVE (scale=1, pas le WORLD_FIT 0.5 du combat) dans un canvas 64×SCALE pour une lisibilité maximale.
--
-- Cadrage : le sprite primgen occupe la grille 64×64 ; pivot (32,58). En posant char.x=32, char.y=58 avec
-- scale=1, l'origine (0,0) de la grille tombe en (0,0) du canvas -> la grille 64×64 remplit le canvas pile.
-- On agrandit ensuite ENTIER ×SCALE (nearest) -> aucun rééchantillonnage flou.
local BESTIARY_SCALE = 6
local GRID = 64 -- la primgen rend dans une grille 64×64 (cf. src/gen/primgen.lua)

function Export.bestiary(opts)
  opts = opts or {}
  local dir = opts.dir or "bestiary"
  local scale = opts.scale or BESTIARY_SCALE
  love.filesystem.createDirectory(dir)

  local order = Units.order
  local n = 0
  for _, id in ipairs(order) do
    local spec = Units[id] or {}
    local def = CreatureGen.cached({
      id = id, type = spec.type, family = spec.family, arch = spec.arch,
      effects = spec.effects, bodyplan = spec.bodyplan, rank = spec.rank,
    })
    local char = Rig.new(def, Palette)
    char.facing = 1
    char.scale = 1 -- pleine résolution (annule le WORLD_FIT du board) -> sprite 64px lisible
    -- pose le pivot (32,58) à (0,0) de la grille : la grille 64×64 couvre exactement le canvas.
    char.x, char.y = GRID / 2, 58
    char.idlePhase = 0 -- pose d'idle DÉTERMINISTE (sinon love.math.random décale la respiration)
    Rig.update(char, 0, 1) -- un tick d'idle (pose stable)

    renderToPng(GRID * scale, GRID * scale, dir .. "/" .. id .. ".png", function()
      love.graphics.scale(scale, scale) -- agrandissement ENTIER (nearest) : 64 -> 64*scale
      Rig.draw(char)
    end)
    n = n + 1
  end

  return n, dir
end

-- ───────────────────────── Captures de scènes ─────────────────────────
-- Rend UNE scène dans le pipeline du jeu : monde -> canvas virtuel VW×VH -> blit en scale ENTIER, +UI native.
-- C'est un MIROIR fidèle de main.lua:love.draw (mêmes étapes drawBack/drawWorld/drawOverlay, même letterbox),
-- mais cadré sur une fenêtre VIRTUELLE de VW*SCALE × VH*SCALE -> ox=oy=0 (remplissage exact, zéro barre noire).
--
-- `buildScene(host)` doit renvoyer la scène à capturer (les scènes build/combat ont besoin d'un run/board ;
-- l'appelant fournit la fabrique, cf. src/core/export_scenes.lua qui reproduit le câblage de headless/main).
local SHOT_SCALE = 4
local VW, VH = 320, 180

function Export.shoot(name, buildScene, opts)
  opts = opts or {}
  local dir = opts.dir or "shots"
  local scale = opts.scale or SHOT_SCALE
  love.filesystem.createDirectory(dir)

  -- Host minimal : assez pour que les scènes se construisent et s'affichent (aucune transition réelle ici).
  local host = { scene = nil, name = name, run = nil, overlay = nil,
    goto = function() end, finishCombat = function() end, newRun = function() end,
    openChronicle = function() end, offerLevelUpRelic = function() end,
    finishRelicPick = function() end, finishRelicPickDecline = function() end }
  local scene = buildScene(host)
  host.scene = scene

  -- Quelques ticks pour stabiliser une pose (anims/transitions « molles » : Feel, respirations).
  local warm = opts.warm or 20
  for _ = 1, warm do
    if scene.update then scene:update(1.0) end
  end

  local view = { scale = scale, ox = 0, oy = 0 }
  local W, H = VW * scale, VH * scale

  renderToPng(W, H, dir .. "/" .. name .. ".png", function(_, _, target)
    -- 1. Pré-passe ATMOSPHÈRE (résolution native), derrière le monde pixel — comme main.lua.
    if scene.drawBack then scene:drawBack(view) end

    -- 2-3. Monde. Deux chemins (identiques à main.lua) : natif (sprites primgen nets) ou canvas virtuel basse-réso.
    love.graphics.setColor(1, 1, 1, 1)
    if scene.nativeWorld then
      love.graphics.push()
      love.graphics.translate(view.ox, view.oy)
      love.graphics.scale(scale, scale)
      scene:drawWorld()
      love.graphics.pop()
    else
      local vcanvas = love.graphics.newCanvas(VW, VH)
      vcanvas:setFilter("nearest", "nearest")
      love.graphics.setCanvas(vcanvas)
      love.graphics.clear(0, 0, 0, 0)
      scene:drawWorld()
      love.graphics.setCanvas(target) -- RE-CIBLE notre canvas d'export (setCanvas(vcanvas) l'avait décroché)
      love.graphics.draw(vcanvas, view.ox, view.oy, 0, scale, scale)
      if vcanvas.release then vcanvas:release() end
    end

    -- 4. UI native par-dessus (texte net). Pas de HUD générique (drawHud lit love.timer.getFPS -> bruit) :
    -- les scènes à chrome propre (daChrome) se suffisent ; on capture l'écran « tel que joué ».
    if scene.drawOverlay then scene:drawOverlay(view) end
  end)

  return dir .. "/" .. name .. ".png"
end

return Export
