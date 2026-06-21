-- src/scenes/menu.lua
-- ÉCRAN TITRE "The Pit" (premier écran de la DA). « YOU DESCEND / The Pit » sur fond d'atmosphère
-- (gueule du puits + stalactites + braises), puis 4 entrées de menu, et un pied de page rappelant la
-- méta-progression (reliques inscrites au Grimoire). On entre dans le Puits depuis ici.
--
-- Couche RENDER/scène (love.graphics autorisé) : atmosphère en pre-pass natif (drawBack), texte en
-- overlay natif. UI composée en ESPACE DESIGN 1280x720 (= virtuel ×4) ; les coords souris (virtuelles
-- 0..320/0..180) sont multipliées par 4 pour le hit-test. daChrome=true -> pas de HUD générique.

local Theme = require("src.ui.theme")
local Draw = require("src.ui.draw")
local Ambient = require("src.fx.ambient")
local Grimoire = require("src.core.grimoire")
local Relics = require("src.data.relics")
local Dev = require("src.core.dev") -- MODE DEV : toggle full-unlock (visible/inerte selon Dev.ENABLED)
local T = require("src.core.i18n").t

local Menu = {}
Menu.__index = Menu

local CX = Draw.W / 2
local ITEM_Y0, ITEM_GAP, ITEM_HALF_H, ITEM_HALF_W = 472, 44, 18, 240

function Menu.new(palette, vw, vh, host)
  local self = setmetatable({}, Menu)
  self.palette = palette
  self.vw, self.vh = vw, vh
  self.host = host
  self.daChrome = true          -- dessine sa propre chrome -> pas de HUD générique
  self.titleKey = "ui.title"
  self.hintKey = "ui.empty"
  self.t = 0
  self.ambient = Ambient.new(7) -- seed fixe -> atmosphère stable

  -- Entrées : 2 actives (ENTER/ABANDON), 2 scellées (Grimoire/Rites -> phases ultérieures).
  self.items = {
    { id = "enter",    key = "menu.enter",    enabled = true,  action = function() self.host.newRun() end },
    { id = "grimoire", key = "menu.grimoire", enabled = true,  action = function() self.host.goto("grimoire") end },
    { id = "proving",  key = "menu.proving",  enabled = true,  action = function() self.host.goto("playground") end },
    { id = "rites",    key = "menu.rites",    enabled = false },
    { id = "abandon",  key = "menu.abandon",  enabled = true,  action = function() love.event.quit() end },
  }
  self.hover = nil
  -- Toggle MODE DEV (cheat) — coin haut-gauche, présent UNIQUEMENT si Dev.ENABLED (masqué/inerte en release).
  self.devRect = Dev.ENABLED and { x = 16, y = 14, w = 252, h = 26 } or nil
  return self
end

local function itemY(i) return ITEM_Y0 + (i - 1) * ITEM_GAP end

-- Indice de l'entrée sous (dx,dy) en coords design, ou nil (entrées scellées ignorées).
function Menu:itemAt(dx, dy)
  if math.abs(dx - CX) > ITEM_HALF_W then return nil end
  for i, it in ipairs(self.items) do
    if it.enabled and math.abs(dy - (itemY(i) + 12)) <= ITEM_HALF_H then return i end
  end
  return nil
end

function Menu:update(dt)
  self.t = self.t + (dt or 1)
  self.ambient:update(dt)
end

-- Pre-pass : atmosphère native derrière (le menu n'a pas de monde pixel).
function Menu:drawBack(view)
  Draw.begin(view)
  self.ambient:draw("menu")
  Draw.finish()
end

function Menu:drawWorld() end -- aucun monde pixel (canvas laissé transparent)

-- Titre gothique avec halo sang (faux bloom : passes décalées en dim puis le titre net).
local function drawTitleGlow(str, cx, y, font)
  local c = Theme.c
  local off = { { 3, 0 }, { -3, 0 }, { 0, 3 }, { 0, -3 }, { 2, 2 }, { -2, -2 } }
  for _, o in ipairs(off) do Draw.textC(str, cx + o[1], y + o[2], { c.blood[1], c.blood[2], c.blood[3], 0.16 }, font) end
  Draw.textC(str, cx, y, c.title, font)
end

function Menu:drawOverlay(view)
  local c = Theme.c
  Draw.begin(view)

  -- Kicker (saveur, serif romain lisible) + logotype gothique.
  Draw.textTrackedC(T("menu.descend"), CX, 250, c.faint, Theme.loreRoman(20), 8)
  drawTitleGlow(T("menu.title"), CX, 280, Theme.display(128))
  Draw.divider(CX, 430, 300, c.blood, 1)

  -- Entrées : Silkscreen (fonctionnel = lisible), léger interlettrage cérémonial.
  for i, it in ipairs(self.items) do
    local y = itemY(i)
    local font = Theme.uiBold(16)
    if not it.enabled then
      Draw.textTrackedC(T(it.key), CX, y + 2, c.lock, font, 2)
      Draw.textC(T("menu.sealed"), CX, y + 24, c.ghost, Theme.ui(9))
    elseif self.hover == i then
      -- survol : doré + léger bloom.
      Draw.textTrackedC(T(it.key), CX, y + 2, { c.bloodBright[1], c.bloodBright[2], c.bloodBright[3], 0.20 }, font, 2)
      Draw.textTrackedC(T(it.key), CX, y + 2, c.goldBright, font, 2)
    else
      Draw.textTrackedC(T(it.key), CX, y + 2, c.muted, font, 2)
    end
  end

  -- Pied : reliques inscrites (méta-progression) à gauche, tag à droite.
  local inscribed = (Grimoire.count and Grimoire.count()) or 0
  Draw.text(T("menu.relics", { n = inscribed, total = #Relics.order }), 24, 690, c.fainter, Theme.ui(12))
  Draw.textR(T("menu.tag"), Draw.W - 24, 690, c.ghost, Theme.ui(12))

  -- Toggle MODE DEV (coin haut-gauche) : visible seulement si Dev.ENABLED. Libellé en dur (dev-only, jamais shippé).
  if self.devRect then
    local on, r = Dev.fullUnlock(), self.devRect
    Draw.rect(r.x, r.y, r.w, r.h, c.panelDeep, on and c.gold or c.hair, 1)
    Draw.text(on and "[DEV] FULL UNLOCK: ON" or "[DEV] FULL UNLOCK: OFF", r.x + 10, r.y + 7,
      on and c.goldBright or c.fainter, Theme.ui(11))
  end

  Draw.finish()
end

-- Souris : hover (mousemoved) + activation (mousepressed). Coords virtuelles -> design (×4).
function Menu:mousemoved(vx, vy)
  self.hover = self:itemAt(vx * 4, vy * 4)
end

function Menu:mousepressed(vx, vy, button)
  if button ~= 1 then return end
  local dx, dy = vx * 4, vy * 4
  if self.devRect then -- MODE DEV : clic sur le toggle full-unlock
    local r = self.devRect
    if dx >= r.x and dx <= r.x + r.w and dy >= r.y and dy <= r.y + r.h then Dev.toggleFullUnlock(); return end
  end
  local i = self:itemAt(dx, dy)
  if i and self.items[i].action then self.items[i].action() end
end

-- Clavier : navigation haut/bas parmi les entrées actives + entrée/espace pour valider.
function Menu:keypressed(key)
  if key == "up" or key == "down" then
    local order = {}
    for i, it in ipairs(self.items) do if it.enabled then order[#order + 1] = i end end
    if #order == 0 then return end
    local cur = 1
    for k, i in ipairs(order) do if i == self.hover then cur = k end end
    cur = cur + (key == "down" and 1 or -1)
    if cur < 1 then cur = #order elseif cur > #order then cur = 1 end
    self.hover = order[cur]
  elseif key == "return" or key == "kpenter" or key == "space" then
    if self.hover and self.items[self.hover].action then self.items[self.hover].action() end
  elseif key == "u" and Dev.ENABLED then -- MODE DEV : toggle full-unlock du codex
    Dev.toggleFullUnlock()
  end
end

return Menu
