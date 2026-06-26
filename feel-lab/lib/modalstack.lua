-- feel-lab/lib/modalstack.lua
-- PILE DE MODALES UNIFIÉE — un modal EST un push sur une pile (recherche §3) : il GÈLE le dessous, DIM le
-- fond, CAPTE l'input, et s'ANIME en entrée/sortie. Résout l'incohérence « chaque pop-up est un programme
-- différent » : toutes passent par le MÊME enrobage (voile + chorégraphie). RENDER pur, headless-safe.
--
-- Chorégraphie (recherche §5) : le BACKDROP dim d'abord (fond s'efface), le PANEL entre (scale 0.94->1 +
-- fade, courbe back) ; à la fermeture le PANEL part d'abord (scale->0.96 + fade), puis le backdrop revient.
-- L'anim ∈ [0,1] est portée par la pile ; chaque modal la lit pour son scale/alpha/slide d'entrée.
--
-- Un modal-objet :
--   :draw(view, a)         -- a ∈ [0,1] (0 = absent, 1 = pleinement entré) ; dessine le PANEL
--   :mousepressed(mx,my,b) -- retourne "close" pour demander la fermeture animée
--   :mousemoved / :wheelmoved / :keypressed (optionnels)
--   .dim                   -- opacité max du backdrop (def 0.6) ; .blockEsc pour empêcher esc
--   :onEnter() / :onClosed() (optionnels)
--
-- API : ModalStack.new() · :push(m) · :requestClose() · :any() · :top() · :update(dt) · :draw(view)
--       · :mousepressed/:mousemoved/:wheelmoved/:keypressed (true = event consommé)

local ModalStack = {}
ModalStack.__index = ModalStack

local ENTER_TAU = 0.085   -- vitesse d'entrée (~85ms, ease-out franc — courbe back appliquée par le modal)
local CLOSE_TAU = 0.07    -- sortie un peu plus rapide (recherche : panel out ~200ms vs in ~300ms)

function ModalStack.new() return setmetatable({ items = {} }, ModalStack) end
function ModalStack:any() return #self.items > 0 end
function ModalStack:top() return self.items[#self.items] end

function ModalStack:push(m)
  m.anim, m.closing, m.dim = 0, false, m.dim or 0.6
  self.items[#self.items + 1] = m
  if m.onEnter then m:onEnter() end
  return m
end

function ModalStack:requestClose()
  local m = self:top(); if m then m.closing = true end
end

function ModalStack:update(dt)
  dt = dt or 0
  -- on anime TOUS les éléments (un modal sous un autre garde son anim), mais seul le sommet se ferme via esc/clic
  for i = #self.items, 1, -1 do
    local m = self.items[i]
    local tau = m.closing and CLOSE_TAU or ENTER_TAU
    local k = 1 - math.exp(-dt / tau)
    local target = m.closing and 0 or 1
    m.anim = m.anim + (target - m.anim) * k
    if m.closing and m.anim < 0.02 then
      table.remove(self.items, i)
      if m.onClosed then m:onClosed() end
    end
    if m.update then m:update(dt) end
  end
end

function ModalStack:draw(view)
  if not (love and love.graphics) then return end
  local sw, sh = love.graphics.getDimensions()
  for i = 1, #self.items do
    local m = self.items[i]
    if i == #self.items or m.anim > 0.02 then
      -- backdrop dim (en coords écran : couvre tout, indépendant de la transform de design)
      love.graphics.push(); love.graphics.origin()
      love.graphics.setColor(0.02, 0.012, 0.03, (m.dim or 0.6) * m.anim)
      love.graphics.rectangle("fill", 0, 0, sw, sh)
      love.graphics.setColor(1, 1, 1, 1)
      love.graphics.pop()
      m:draw(view, m.anim)
    end
  end
end

function ModalStack:mousepressed(mx, my, b)
  local m = self:top(); if not m then return false end
  if m.mousepressed and m:mousepressed(mx, my, b) == "close" then self:requestClose() end
  return true   -- modal : capte tout (rien ne descend)
end
function ModalStack:mousereleased(mx, my, b)
  local m = self:top(); if not m then return false end
  if m.mousereleased then m:mousereleased(mx, my, b) end
  return true
end
function ModalStack:mousemoved(mx, my)
  local m = self:top(); if not m then return false end
  if m.mousemoved then m:mousemoved(mx, my) end
  return true
end
function ModalStack:wheelmoved(dx, dy)
  local m = self:top(); if not m then return false end
  if m.wheelmoved then m:wheelmoved(dx, dy) end
  return true
end
function ModalStack:keypressed(k)
  local m = self:top(); if not m then return false end
  if k == "escape" and not m.blockEsc then self:requestClose(); return true end
  if m.keypressed then m:keypressed(k) end
  return true
end

return ModalStack
