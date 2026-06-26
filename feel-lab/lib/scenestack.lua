-- feel-lab/lib/scenestack.lua
-- PILE DE SCÈNES — remplace le « swap brutal » par une vraie pile avec cycle de vie (recherche §1).
--   switch(scene)  -> remplace le sommet : leave(ancien) + enter(nouveau)         [flux : build->combat]
--   push(scene)    -> empile SANS détruire le dessous : pause(courant) + enter()  [hiérarchie : menu->codex]
--   pop()          -> dépile : leave(sommet) + resume(révélé)                       [retour en arrière gratuit]
-- Pur (aucun love.* requis), déterministe (array + ipairs). Les transitions sont orchestrées par l'appelant
-- (main) AUTOUR de switch/push/pop ; la pile ne fait que gérer l'ordre et le cycle de vie.
--
-- Une « scène » (room) : table avec, optionnels, :enter(prev)/:leave(next)/:pause(next)/:resume(prev)
-- + :update(dt) :draw(view) :mousepressed :mousemoved :mousereleased :wheelmoved :keypressed.

local Stack = {}
Stack.__index = Stack

function Stack.new() return setmetatable({ items = {} }, Stack) end

local function call(scene, m, ...)
  if scene and scene[m] then return scene[m](scene, ...) end
end

function Stack:top() return self.items[#self.items] end
function Stack:depth() return #self.items end
function Stack:isStacked() return #self.items > 1 end

function Stack:switch(scene, ...)
  local old = self.items[#self.items]
  call(old, "leave", scene)
  if #self.items == 0 then self.items[1] = scene else self.items[#self.items] = scene end
  call(scene, "enter", old, ...)
  return scene
end

function Stack:push(scene, ...)
  call(self:top(), "pause", scene)
  self.items[#self.items + 1] = scene
  call(scene, "enter", nil, ...)
  return scene
end

function Stack:pop(...)
  if #self.items == 0 then return nil end
  local old = table.remove(self.items)
  call(old, "leave")
  call(self:top(), "resume", old, ...)
  return old
end

-- routage (seul le sommet est actif)
function Stack:update(dt) call(self:top(), "update", dt) end
function Stack:draw(view) call(self:top(), "draw", view) end
function Stack:input(m, ...) return call(self:top(), m, ...) end

return Stack
