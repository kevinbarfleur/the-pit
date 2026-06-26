-- src/ui/system_menu.lua
-- MENU SYSTÈME GLOBAL : pause/settings/confirmations au-dessus de n'importe quelle scène.
-- Même contrat qu'une overlay : le host la dessine au-dessus, lui route les inputs, et la scène derrière reste
-- figée. Les actions dangereuses passent par une confirmation ; revenir au menu suspend la run sans l'effacer.

local Draw = require("src.ui.draw")
local Theme = require("src.ui.theme")
local Panel = require("src.ui.panel")
local Button = require("src.ui.button")
local Dividers = require("src.ui.dividers")
local Feel = require("src.ui.feel")
local OverlayFx = require("src.ui.overlay")
local SFX = require("src.audio.sfx")
local T = require("src.core.i18n").t

local SystemMenu = {}
SystemMenu.__index = SystemMenu

local PANEL_W = 456
local BTN_W, BTN_H, GAP = 384, 42, 10

local function ptIn(px, py, r)
  return r and px >= r.x and px <= r.x + r.w and py >= r.y and py <= r.y + r.h
end

local function toDesign(vx, vy) return vx * 4, vy * 4 end

local function hostBool(host, name, fallback)
  local f = host and host[name]
  if type(f) == "function" then return f() end
  if f ~= nil then return f and true or false end
  return fallback
end

local function stateWord(on) return on and T("system.on") or T("system.off") end

function SystemMenu.new(host, opts)
  opts = opts or {}
  local self = setmetatable({
    kind = "system",
    host = host,
    mode = opts.mode or "pause",
    prevMode = opts.prevMode,
    sceneName = opts.sceneName,
    mx = -100, my = -100,
    sel = 1,
    t = 0,
    rects = {},
  }, SystemMenu)
  self:rebuild()
  return self
end

function SystemMenu:setMode(mode, prev)
  self.mode = mode
  self.prevMode = prev
  self.sel = 1
  self:rebuild()
end

function SystemMenu:close()
  if self.host then self.host.overlay = nil end
end

function SystemMenu:rebuild()
  local h = self.host
  local mode = self.mode
  local items = {}
  local title, tag, flavor = T("system.title"), T("system.tag"), nil

  local function add(id, key, variant, opts)
    opts = opts or {}
    items[#items + 1] = {
      id = id,
      label = opts.label or T(key),
      variant = variant or "secondary",
      disabled = opts.disabled,
    }
  end

  if mode == "settings" then
    title, tag = T("system.settings"), T("system.settings_tag")
    add("toggle_sfx", nil, "secondary", { label = T("system.sfx", { state = stateWord(SFX.enabled) }) })
    add("toggle_music", nil, "secondary", { label = T("system.music", { state = stateWord(hostBool(h, "musicEnabled", true)) }) })
    local fxOn = hostBool(h, "postfxEnabled", false)
    local fxReady = hostBool(h, "postfxReady", true)
    add("toggle_postfx", nil, "secondary", {
      label = T("system.postfx", { state = fxReady and stateWord(fxOn) or T("system.unavailable") }),
      disabled = not fxReady,
    })
    add("back", "system.back", "secondary")
  elseif mode == "confirm_abandon" then
    title, tag, flavor = T("system.abandon_title"), T("system.abandon_tag"), T("system.abandon_flavor")
    add("back", "system.keep_playing", "secondary")
    add("abandon_confirm", "system.abandon_confirm", "primary")
  elseif mode == "confirm_new_run" then
    title, tag, flavor = T("system.new_run_title"), T("system.new_run_tag"), T("system.new_run_flavor")
    add("back", "system.cancel", "secondary")
    add("new_run_confirm", "system.new_run_confirm", "primary")
  elseif mode == "confirm_quit" then
    title, tag, flavor = T("system.quit_title"), T("system.quit_tag"), T("system.quit_flavor")
    add("back", "system.cancel", "secondary")
    add("quit_confirm", "system.quit_confirm", "primary")
  else
    local inMenu = h and h.name == "menu"
    title, tag = inMenu and T("system.menu_title") or T("system.title"), T("system.tag")
    if not inMenu then add("continue", "system.continue", "primary") end
    add("settings", "system.settings", "secondary")
    if not inMenu then add("return_menu", "system.return_menu", "secondary") end
    if h and h.canResumeRun and h.canResumeRun() then add("abandon", "system.abandon", "secondary") end
    add("quit", "system.quit", "secondary")
  end

  self.title, self.tag, self.flavor, self.items = title, tag, flavor, items
  self:layout()
end

function SystemMenu:layout()
  local n = #(self.items or {})
  local headerH = self.flavor and 140 or 112
  local listH = n * BTN_H + math.max(0, n - 1) * GAP
  self.panel = {
    x = math.floor((Draw.W - PANEL_W) / 2),
    y = math.floor((Draw.H - headerH - listH - 28) / 2),
    w = PANEL_W,
    h = headerH + listH + 28,
  }
  local x = math.floor((Draw.W - BTN_W) / 2)
  local y = self.panel.y + headerH
  self.rects = {}
  for i, it in ipairs(self.items) do
    self.rects[i] = { id = it.id, x = x, y = y, w = BTN_W, h = BTN_H }
    y = y + BTN_H + GAP
  end
end

function SystemMenu:update(frameDt)
  self.t = self.t + (frameDt or 1)
  self._anim = OverlayFx.advance(self._anim, (frameDt or 1) / 60)
  Feel.update(frameDt)
  for i, r in ipairs(self.rects or {}) do
    local it = self.items[i]
    Feel.hover("system." .. it.id, (not it.disabled) and ptIn(self.mx, self.my, r))
  end
end

function SystemMenu:draw(view)
  local C = Theme.c
  local anim = self._anim or 1
  Draw.begin(view)
  Draw.rect(0, 0, Draw.W, Draw.H, { 0.02, 0.012, 0.03, 0.88 * anim })
  OverlayFx.pushContent(Draw.W / 2, Draw.H / 2, anim, 0.04)

  local p = self.panel
  Panel.draw(p.x, p.y, p.w, p.h, { fill1 = C.stone800, fill2 = C.stone900, border = C.iron, solid = true })
  Draw.textTrackedC(self.tag, Draw.W / 2, p.y + 26, C.ink4, Theme.label(10), 2.0)
  Draw.textC(self.title, Draw.W / 2, p.y + 46, C.ink, Theme.display(38))
  if self.flavor then
    Draw.textWrap(self.flavor, p.x + 44, p.y + 88, p.w - 88, C.ink3, Theme.bodyItalic(14), "center")
  end
  Dividers.brass(Draw.W / 2, p.y + (self.flavor and 126 or 92), 260)

  for i, it in ipairs(self.items) do
    local r = self.rects[i]
    local hot = (self.sel == i) or ptIn(self.mx, self.my, r)
    Button.draw(r.x, r.y, r.w, r.h, it.variant, it.label, {
      disabled = it.disabled,
      hover = hot and not it.disabled,
      feel = Feel.state("system." .. it.id),
      id = "system." .. it.id,
      mouse = { mx = self.mx, my = self.my },
      t = self.t / 60,
    })
  end

  OverlayFx.popContent()
  if anim < 1 then Draw.rect(0, 0, Draw.W, Draw.H, { 0.02, 0.012, 0.03, (1 - anim) * 0.5 }) end
  Draw.finish()
end

function SystemMenu:itemAt(dx, dy)
  for i, r in ipairs(self.rects or {}) do
    if ptIn(dx, dy, r) and not self.items[i].disabled then return i end
  end
  return nil
end

function SystemMenu:perform(id)
  local h = self.host
  if id == "continue" then self:close()
  elseif id == "settings" then self:setMode("settings", self.mode)
  elseif id == "return_menu" then if h and h.suspendToMenu then h.suspendToMenu() end
  elseif id == "abandon" then self:setMode("confirm_abandon", self.mode)
  elseif id == "quit" then self:setMode("confirm_quit", self.mode)
  elseif id == "toggle_sfx" then SFX.toggle(); self:rebuild()
  elseif id == "toggle_music" then if h and h.toggleMusic then h.toggleMusic(); self:rebuild() end
  elseif id == "toggle_postfx" then if h and h.togglePostFx then h.togglePostFx(); self:rebuild() end
  elseif id == "back" or id == "cancel" then
    if self.mode == "pause" or self.prevMode == "close" then self:close() else self:setMode(self.prevMode or "pause") end
  elseif id == "abandon_confirm" then if h and h.abandonRun then h.abandonRun() end
  elseif id == "new_run_confirm" then if h and h.newRun then h.newRun() end
  elseif id == "quit_confirm" then if love and love.event then love.event.quit() end
  end
end

function SystemMenu:press(i)
  local it = self.items and self.items[i]
  if not it or it.disabled then return end
  self.sel = i
  Feel.press("system." .. it.id, function() self:perform(it.id) end)
end

function SystemMenu:mousemoved(vx, vy)
  self.mx, self.my = toDesign(vx, vy)
  local i = self:itemAt(self.mx, self.my)
  if i then self.sel = i end
end

function SystemMenu:mousepressed(vx, vy, button)
  if button ~= 1 then return true end
  self.mx, self.my = toDesign(vx, vy)
  local i = self:itemAt(self.mx, self.my)
  if i then self:press(i) end
  return true
end

function SystemMenu:mousereleased() end
function SystemMenu:wheelmoved() end

function SystemMenu:keypressed(key)
  if key == "escape" then
    if self.mode == "pause" or self.prevMode == "close" then self:close() else self:setMode(self.prevMode or "pause") end
    return
  end
  if key == "up" or key == "down" then
    local n = #(self.items or {})
    if n == 0 then return end
    local step = key == "down" and 1 or -1
    local i = self.sel
    for _ = 1, n do
      i = i + step
      if i < 1 then i = n elseif i > n then i = 1 end
      if not self.items[i].disabled then self.sel = i; return end
    end
  elseif key == "return" or key == "kpenter" or key == "space" then
    self:press(self.sel)
  end
end

return SystemMenu
