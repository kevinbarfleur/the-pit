-- src/ui/system_button.lua
-- Bouton système global : affordance visible pour ouvrir pause/settings depuis les scènes de run.

local Draw = require("src.ui.draw")
local Button = require("src.ui.button")

local M = {}

local SIZE = 28
local MARGIN = 16
local RUN_Y = 14

local VISIBLE = {
  build = true,
  combat = true,
  relicpick = true,
  runover = true,
}

local function ptIn(px, py, r)
  return r and px >= r.x and px <= r.x + r.w and py >= r.y and py <= r.y + r.h
end

function M.visible(sceneName)
  return VISIBLE[sceneName] and true or false
end

function M.rect(sceneName)
  return {
    x = Draw.W - MARGIN - SIZE,
    y = RUN_Y,
    w = SIZE,
    h = SIZE,
  }
end

function M.hit(sceneName, dx, dy)
  if not M.visible(sceneName) then return false end
  return ptIn(dx, dy, M.rect(sceneName))
end

function M.draw(view, sceneName, hover)
  if not M.visible(sceneName) then return end
  local r = M.rect(sceneName)
  Draw.begin(view)
  Button.icon(r.x, r.y, r.w, "gear", { hover = hover })
  Draw.finish()
end

return M
