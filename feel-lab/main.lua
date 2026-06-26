-- feel-lab/main.lua — ORCHESTRATEUR du FEEL LAB (mini-projet isolé : `love feel-lab`).
-- Câble TOUT ce qui répond à la demande : shell persistant (« un seul jeu ») + pile de scènes + transitions
-- enrobantes + pile de modales unifiée + toasts + juice global (screen-shake trauma² + hitstop) + son
-- procédural. RENDER pur ; aucune dépendance au jeu principal (DA copiée). Pipeline pixel-perfect du jeu :
-- monde DESIGN 1280×720 (= virtuel 320×180 ×4) blitté en scale, texte net en résolution native.

local Theme      = require("lib.theme")
local Draw       = require("lib.draw")
local Feel       = require("lib.feel")
local Juice      = require("lib.juice")
local SFX        = require("lib.sfx")
local B          = require("lib.behavior")
local Shell      = require("lib.shell")
local Stack      = require("lib.scenestack")
local Transition = require("lib.transition")
local ModalStack = require("lib.modalstack")
local Modals     = require("lib.modals")
local Particles  = require("lib.particles")
local PostFX     = require("lib.postfx")

local ROOMS = {
  menu        = require("rooms.menu"),
  interaction = require("rooms.interaction"),
  components  = require("rooms.components"),
  transitions = require("rooms.transitions"),
  modals      = require("rooms.modals"),
  sound       = require("rooms.sound"),
  levelup     = require("rooms.levelup"),
  combat_lab  = require("rooms.combat_lab"),
}

local VW, VH = 320, 180
local view = { scale = 4, ox = 0, oy = 0 }

-- HÔTE partagé avec les rooms (leur API de navigation/services).
local app = {}
app.stack      = Stack.new()
app.transition = Transition.new()
app.modals     = ModalStack.new()
app.toasts     = {}
app.sfxOn      = true
app.mx, app.my = -1, -1

-- pixels fenêtre -> espace DESIGN 1280×720 (inverse du blit : screen = ox + design*scale/4)
function app:toDesign(x, y)
  local s = (view.scale or 4) / 4
  if s <= 0 then return x, y end
  return (x - view.ox) / s, (y - view.oy) / s
end

-- navigue vers une room avec transition enrobante (switch + snapshot de l'ancienne)
function app:go(name, kind)
  if self.transition.active then return end
  local ctor = ROOMS[name]; if not ctor then return end
  local room = ctor.new(self)
  if self.view then
    self.transition:start(kind or "fade_black", (kind == "fade_black" or not kind) and 0.36 or 0.3,
      function() self.stack:draw(self.view) end)   -- snapshot de la room SORTANTE
  end
  self.stack:switch(room)
  self.current = name
end

function app:back()
  if self.current == "menu" then return end
  self:go("menu", "slide_right")
end

function app:toast(text, kind) self.toasts[#self.toasts + 1] = Modals.toast(text, kind) end
function app:setSfx(on) self.sfxOn = on end

-- HARNAIS DE CAPTURE (dev) : `love feel-lab --shoot` rend chaque room + une modale, capture en PNG dans le
-- save dir, puis quitte. RENDER-only, permet de juger À L'ŒIL sans bloquer l'écran. Séquence pilotée frame-à-frame.
local shoot = { on = false, idx = 0, frame = 0, warm = 26 }
shoot.shots = {
  { name = "menu" },
  { name = "interaction" },
  { name = "components" },
  { name = "components", scenario = "eyes", at = 34 },  -- survol simulé du CTA -> l'œil ouvert qui fixe la souris
  { name = "sound" },
  { name = "transitions" },
  { name = "modals" },
  { name = "modals", modal = "confirm" },
  { name = "modals", modal = "banner" },
  { name = "levelup" },
  { name = "levelup", scenario = "shop", at = 16 },     -- convergence + aspiration de la carte shop
  { name = "levelup", scenario = "shop", at = 58 },     -- climax « TAAA » (burst + onde de choc)
  { name = "levelup", scenario = "cascade", at = 120 }, -- climax escaladé du 2e palier (big)
  { name = "combat_lab", at = 80 },  -- combat tournant (créatures animées + baseline chiffres/VFX)
  -- Revue : chiffres A/B (100% plats) × VFX A/B (cast+impact directionnel). Décommenter pour re-capturer.
  -- { name = "combat_lab", at = 6, setup = function(r) r:demoFill("A", "A") end },
  -- { name = "combat_lab", at = 6, setup = function(r) r:demoFill("B", "B") end },
}

local function setRoom(name)
  app.stack:switch(ROOMS[name].new(app)); app.current = name
end

-- ───────────────────────────────────────── LÖVE callbacks ─────────────────────────────────────────
function love.load(args)
  love.graphics.setDefaultFilter("nearest", "nearest")
  love.graphics.setLineStyle("rough")
  love.graphics.setBackgroundColor(Theme.c.void[1], Theme.c.void[2], Theme.c.void[3])
  Theme.load()
  pcall(SFX.load)   -- garde (pas de device audio en CI/headless)
  Particles.load()  -- bake l'atlas de sprites de particules (nearest) une fois
  app.postfx = PostFX.new()  -- surcouche cauchemardesque (dither/grain/palette-lock) — défaut ON
  setRoom("menu")
  for _, a in ipairs(args or {}) do if a == "--shoot" then shoot.on = true end end
  if shoot.on and love.filesystem then love.filesystem.createDirectory("shots") end
end

-- pilotage de la séquence de capture (frame-à-frame)
local function shootStep()
  if shoot.idx == 0 then shoot.idx = 1; shoot.frame = 0; applyShot() end
  shoot.frame = shoot.frame + 1
  local warm = shoot.shots[shoot.idx].at or shoot.warm
  if shoot.frame == warm then
    local sh = shoot.shots[shoot.idx]
    local tag = (sh.modal and ("_" .. sh.modal)) or (sh.scenario and ("_" .. sh.scenario .. "_" .. (sh.at or 0))) or ""
    local fname = string.format("shots/%02d_%s%s.png", shoot.idx, sh.name, tag)
    if love.graphics.captureScreenshot then love.graphics.captureScreenshot(fname) end
  elseif shoot.frame > warm then
    shoot.idx = shoot.idx + 1
    if shoot.idx > #shoot.shots then love.event.quit(); return end
    shoot.frame = 0; applyShot()
  end
end
function applyShot()
  local sh = shoot.shots[shoot.idx]
  -- room sans transition (instantané)
  while app.modals:any() do table.remove(app.modals.items) end
  setRoom(sh.name)
  if sh.modal == "confirm" then
    local m = app.modals:push(Modals.confirm{ title = "Abandon the run?", danger = true,
      body = "Your descent ends here. The Pit keeps what you found.",
      confirmLabel = "Abandon", cancelLabel = "Keep going" })
    m.anim = 1
  elseif sh.modal == "banner" then
    local m = app.modals:push(Modals.banner{ kind = "victory", flavor = "The Pit yields. For now." })
    m.anim = 1
  end
  if sh.scenario then
    local r = app.stack:top()
    if r and r.scenario then r:scenario(sh.scenario) end
  end
  if sh.setup then
    local r = app.stack:top()
    if r then sh.setup(r) end
  end
end

function love.update(dt)
  dt = math.min(dt or 0, 1 / 30)            -- borne anti-hoquet
  if shoot.on then shootStep() end
  Feel.update(dt * 60)                      -- Feel raisonne en « frames » (÷60 en interne)
  Juice.update(dt)                          -- dt RÉEL (le hitstop doit finir même monde gelé)
  app.transition:update(dt)
  app.modals:update(dt)
  -- toasts (non-bloquants)
  for i = #app.toasts, 1, -1 do
    local tt = app.toasts[i]; tt.t = tt.t - dt
    if tt.t <= 0 then table.remove(app.toasts, i) end
  end
  -- room : gelée pendant transition et hitstop (mais Feel/Juice continuent)
  if not app.transition.active then
    app.stack:update(dt * Juice.timeScale())
  end
end

function love.draw()
  local sw, sh = love.graphics.getDimensions()
  local scale = math.max(1, math.min(sw / VW, sh / VH))
  view.scale = scale
  view.ox = math.floor((sw - VW * scale) / 2)
  view.oy = math.floor((sh - VH * scale) / 2)
  app.view = view

  -- SURCOUCHE CAUCHEMARDESQUE : on rend TOUTE la frame dans un canvas natif, blité à travers le shader
  -- (dither Bayer + grain + palette-lock) -> unifie le look « clean, semi-net, semi-pixélisé ». [F9] bascule.
  local fxOn = app.postfx and app.postfx:beginFrame(love.timer and love.timer.getTime() or 0, sw, sh)

  -- fond d'ambiance partagé (toujours là)
  Shell.drawBack(view)

  -- screen-shake global : enrobe scène + chrome (pas les modales)
  local shx, shy, shr = Juice.shake()
  local s = scale / 4
  love.graphics.push()
  love.graphics.translate(sw / 2, sh / 2); love.graphics.rotate(shr); love.graphics.translate(-sw / 2, -sh / 2)
  love.graphics.translate(shx * s, shy * s)

  -- scène (ou transition entre deux scènes)
  if app.transition.active then
    app.transition:draw(function() app.stack:draw(view) end)
  else
    app.stack:draw(view)
  end

  -- shell persistant (barre de titre + retour + pied) PAR-DESSUS le contenu
  local top = app.stack:top()
  app._backRect = Shell.drawFront(view, {
    title = top and top.title or "Feel Lab",
    canBack = app.current ~= "menu",
    mx = app.mx, my = app.my,
    status = { sfx = app.sfxOn, profile = B.profile, fps = love.timer.getFPS(),
               fx = app.postfx and app.postfx.on },
    hint = "Esc: back/close · F11: fullscreen · F9: nightmare shader · click everything",
  })
  love.graphics.pop()

  -- modales + toasts au-dessus de tout (pas de shake)
  app.modals:draw(view)
  Modals.drawToasts(view, app.toasts)

  if fxOn then app.postfx:endFrame(0) end   -- blit le canvas à travers le shader cauchemardesque
end

-- ───────────────────────────────────────── Input ─────────────────────────────────────────
function love.mousepressed(x, y, button)
  local dx, dy = app:toDesign(x, y)
  app.mx, app.my = dx, dy
  if app.transition.active then return end          -- bloque l'input pendant une transition (recherche §6)
  if app.modals:any() then app.modals:mousepressed(dx, dy, button); return end
  if app._backRect and Shell.backHit(app._backRect, dx, dy) then
    Feel.press("shell_back", function() app:back() end, { delay = 0.05 }); return
  end
  app.stack:input("mousepressed", dx, dy, button)
end

function love.mousereleased(x, y, button)
  local dx, dy = app:toDesign(x, y)
  if app.transition.active then return end
  if app.modals:any() then app.modals:mousereleased(dx, dy, button); return end
  app.stack:input("mousereleased", dx, dy, button)
end

function love.mousemoved(x, y)
  local dx, dy = app:toDesign(x, y)
  app.mx, app.my = dx, dy
  if app.modals:any() then app.modals:mousemoved(dx, dy); return end
  app.stack:input("mousemoved", dx, dy)
end

function love.wheelmoved(dx, dy)
  if app.modals:any() then app.modals:wheelmoved(dx, dy); return end
  app.stack:input("wheelmoved", dx, dy)
end

function love.keypressed(key)
  if key == "f11" or (key == "return" and (love.keyboard.isDown("lalt") or love.keyboard.isDown("ralt"))) then
    love.window.setFullscreen(not love.window.getFullscreen(), "desktop"); return
  end
  if key == "f9" then if app.postfx then app.postfx:toggle() end; return end  -- bascule la surcouche shader
  if app.modals:any() then app.modals:keypressed(key); return end
  if key == "escape" then
    if app.current ~= "menu" then app:back() else love.event.quit() end
    return
  end
  app.stack:input("keypressed", key)
end
