-- feel-lab/lib/sprite.lua
-- BAKE pixel : grille de caractères + palette -> Image filtrée nearest (une fois). Port de src/core/sprite.lua.
-- '.' (ou tout char absent de la palette) = transparent. Réutilisé pour baker les sprites de PARTICULES.

local Sprite = {}

function Sprite.bake(grid, palette)
  if not (love and love.image and love.graphics) then return nil end
  local h = #grid
  local w = 0
  for _, row in ipairs(grid) do if #row > w then w = #row end end
  if w == 0 or h == 0 then return nil end
  local data = love.image.newImageData(w, h)
  for y = 1, h do
    local row = grid[y]
    for x = 1, #row do
      local ch = row:sub(x, x)
      local col = (ch ~= ".") and palette[ch] or nil
      if col then data:setPixel(x - 1, y - 1, col[1], col[2], col[3], col[4] or 1) end
    end
  end
  local img = love.graphics.newImage(data)
  img:setFilter("nearest", "nearest")
  return { image = img, w = w, h = h }
end

return Sprite
