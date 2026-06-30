-- feel-lab/main.lua — ORCHESTRATEUR du FEEL LAB (mini-projet isolé : `love feel-lab`).
-- Shell persistant + scenes propres + transitions + juice global (screen-shake trauma² + hitstop) + son
-- procedural. RENDER pur ; aucune dependance SIM. Pipeline pixel-perfect du jeu :
-- monde DESIGN 1280×720 (= virtuel 320×180 ×4) blitte en scale, texte net en resolution native.

local Theme      = require("lib.theme")
local Draw       = require("lib.draw")
local Feel       = require("lib.feel")
local Juice      = require("lib.juice")
local SFX        = require("lib.sfx")
local B          = require("lib.behavior")
local Shell      = require("lib.shell")
local Stack      = require("lib.scenestack")
local Transition = require("lib.transition")
local Particles  = require("lib.particles")
local PostFX     = require("lib.postfx")

local ROOMS = {
  menu        = require("rooms.menu"),
  contract    = require("rooms.contract"),
  components  = require("rooms.components"),
  flow        = require("rooms.flow"),
  impact      = require("rooms.impact"),
  particles   = require("rooms.particles"),
  sound       = require("rooms.sound"),
  levelup     = require("rooms.levelup"),
}

local VW, VH = 320, 180
local view = { scale = 4, ox = 0, oy = 0 }

-- HÔTE partagé avec les rooms (leur API de navigation/services).
local app = {}
app.stack      = Stack.new()
app.transition = Transition.new()
app.sfxOn      = true
app.mx, app.my = -1, -1

function app:shellContext()
  local top = self.stack:top()
  return {
    title = top and top.title or "Feel Lab",
    canBack = self.current and self.current ~= "menu",
    mx = self.mx, my = self.my,
    status = { sfx = self.sfxOn, profile = B.profile, fps = love.timer.getFPS(),
               fx = self.postfx and self.postfx.on },
    hint = "Esc back · F11 fullscreen · F9 shader",
  }
end

function app:drawSurface(v, captureBack)
  self.stack:draw(v)
  local back = Shell.drawFront(v, self:shellContext())
  if captureBack then self._backRect = back end
end

-- pixels fenêtre -> espace DESIGN 1280×720 (inverse du blit : screen = ox + design*scale/4)
function app:toDesign(x, y)
  local s = (view.scale or 4) / 4
  if s <= 0 then return x, y end
  return (x - view.ox) / s, (y - view.oy) / s
end

-- navigue vers une room avec transition enrobante (switch + snapshot de l'ancienne)
local function currentViewMetrics()
  if app.view then return app.view.scale or 4, app.view.ox or 0, app.view.oy or 0 end
  if love and love.graphics and love.graphics.getDimensions then
    local sw, sh = love.graphics.getDimensions()
    local scale = math.max(1, math.min(sw / VW, sh / VH))
    return scale, math.floor((sw - VW * scale) / 2), math.floor((sh - VH * scale) / 2)
  end
  return 4, 0, 0
end

function app:designToScreen(x, y)
  local scale, ox, oy = currentViewMetrics()
  local s = scale / 4
  return ox + x * s, oy + y * s
end

function app:designRectToScreen(r)
  local scale, ox, oy = currentViewMetrics()
  local s = scale / 4
  return {
    x = ox + (r.x or 0) * s,
    y = oy + (r.y or 0) * s,
    w = (r.w or 0) * s,
    h = (r.h or 0) * s,
  }
end

function app:go(name, kind, opts)
  if self.transition.active then return end
  local ctor = ROOMS[name]; if not ctor then return end
  local room = ctor.new(self)
  opts = opts or {}
  if opts.originRectDesign and not opts.originDesign then
    local r = opts.originRectDesign
    opts.originDesign = { x = (r.x or 0) + (r.w or 0) / 2, y = (r.y or 0) + (r.h or 0) / 2 }
  end
  if opts.originRectDesign and not opts.originRectScreen then
    opts.originRectScreen = self:designRectToScreen(opts.originRectDesign)
  end
  if opts.originDesign and not opts.originScreen then
    local sx, sy = self:designToScreen(opts.originDesign.x or 640, opts.originDesign.y or 540)
    opts.originScreen = { x = sx, y = sy }
  end
  if opts.originRectScreen and not opts.originScreen then
    local r = opts.originRectScreen
    opts.originScreen = { x = (r.x or 0) + (r.w or 0) / 2, y = (r.y or 0) + (r.h or 0) / 2 }
  end
  if self.view then
    local dur = (kind == "blood_rain" or kind == "blood_bloom" or kind == "blood_button") and 2.35
      or ((kind == "fade_black" or not kind) and 0.36 or 0.3)
    self.transition:start(kind or "fade_black", dur,
      function() self:drawSurface(self.view, false) end, opts)   -- snapshot de la room SORTANTE + shell
  end
  self.stack:switch(room)
  self.current = name
end

function app:back()
  if self.current == "menu" then return end
  self:go("menu", "slide_right")
end

function app:setSfx(on) self.sfxOn = on end

-- HARNAIS DE CAPTURE (dev) : `love feel-lab --shoot` rend chaque room active, capture en PNG dans le
-- save dir, puis quitte. RENDER-only, permet de juger À L'ŒIL sans bloquer l'écran. Séquence pilotée frame-à-frame.
local shoot = { on = false, idx = 0, frame = 0, warm = 26 }
shoot.shots = {
  { name = "menu" },
  { name = "contract" },
  { name = "contract", scenario = "blood_button", at = 16 },
  { name = "contract", scenario = "blood_button", at = 38 },
  { name = "contract", scenario = "blood_button", at = 78 },
  { name = "contract", scenario = "blood_button", at = 118 },
  { name = "contract", scenario = "blood_bloom", at = 92 },
  { name = "contract", scenario = "blood_rain", at = 40 },
  { name = "contract", scenario = "blood_rain", at = 92 },
  { name = "contract", scenario = "blood_rain", at = 118 },
  { name = "flow" },
  { name = "flow", scenario = "rewards", at = 76 },
  { name = "flow", scenario = "score", at = 220 },
  { name = "components" },
  { name = "components", scenario = "eyes", at = 34 },  -- survol simulé du CTA -> l'œil ouvert qui fixe la souris
  { name = "impact", at = 46 },
  { name = "impact", scenario = "poison", at = 46 },
  { name = "impact", scenario = "bleed", at = 46 },
  { name = "impact", scenario = "burn", at = 46 },
  { name = "impact", scenario = "rot", at = 46 },
  { name = "impact", scenario = "shock_pixel", at = 46 },
  { name = "impact", scenario = "bloom", at = 46 },
  { name = "particles", at = 44 },
  { name = "particles", scenario = "seal", at = 36 },
  { name = "sound" },
  { name = "levelup" },
  { name = "levelup", scenario = "shop", at = 16 },     -- convergence + aspiration de la carte shop
  { name = "levelup", scenario = "shop", at = 86 },     -- climax « TAAA » + echo jackpot
  { name = "levelup", scenario = "shop", at = 100 },    -- peak settle
  { name = "levelup", scenario = "cascade", at = 150 }, -- climax escaladé du 2e palier (big)
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
  app.postfx = PostFX.new()  -- surcouche cauchemardesque (dither/grain/palette-lock) — togglable [F9]
  if app.postfx then app.postfx.on = false end -- le lab juge d'abord les composants nets ; shader sur demande
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
  if app.transition then app.transition.active = false end
  setRoom(sh.name)
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

  -- scène + shell (ou transition entre deux surfaces complètes)
  if app.transition.active then
    app._backRect = nil
    app.transition:draw(function() app:drawSurface(view, false) end)
  else
    app:drawSurface(view, true)
  end
  love.graphics.pop()

  if fxOn then app.postfx:endFrame(0) end   -- blit le canvas à travers le shader cauchemardesque
end

-- ───────────────────────────────────────── Input ─────────────────────────────────────────
function love.mousepressed(x, y, button)
  local dx, dy = app:toDesign(x, y)
  app.mx, app.my = dx, dy
  if app.transition.active then return end          -- bloque l'input pendant une transition (recherche §6)
  if app._backRect and Shell.backHit(app._backRect, dx, dy) then
    Feel.press("shell_back", function() app:back() end, { delay = 0.05 }); return
  end
  app.stack:input("mousepressed", dx, dy, button)
end

function love.mousereleased(x, y, button)
  local dx, dy = app:toDesign(x, y)
  if app.transition.active then return end
  app.stack:input("mousereleased", dx, dy, button)
end

function love.mousemoved(x, y)
  local dx, dy = app:toDesign(x, y)
  app.mx, app.my = dx, dy
  app.stack:input("mousemoved", dx, dy)
end

function love.wheelmoved(dx, dy)
  app.stack:input("wheelmoved", dx, dy)
end

function love.keypressed(key)
  if key == "f11" or (key == "return" and (love.keyboard.isDown("lalt") or love.keyboard.isDown("ralt"))) then
    love.window.setFullscreen(not love.window.getFullscreen(), "desktop"); return
  end
  if key == "f9" then if app.postfx then app.postfx:toggle() end; return end  -- bascule la surcouche shader
  if key == "escape" then
    if app.current ~= "menu" then app:back() else love.event.quit() end
    return
  end
  app.stack:input("keypressed", key)
end
