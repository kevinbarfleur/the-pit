-- src/core/sprite.lua
-- Bake une grille (table de strings) + palette -> Image LÖVE filtrée "nearest".
-- On bake UNE fois au chargement, jamais par frame : la recherche perf est formelle,
-- des milliers de love.graphics.rectangle() par frame ne tiennent pas la charge.
-- Réf : love.image.newImageData / ImageData:setPixel / love.graphics.newImage

local Sprite = {}

-- grid    : { "KIK", "KKK", ... }  (lignes pouvant être de longueurs différentes)
-- palette : char -> {r,g,b,a} ou nil (transparent)
-- retourne { image = Image, w, h }
function Sprite.bake(grid, palette)
  local h = #grid
  local w = 0
  for _, row in ipairs(grid) do
    if #row > w then w = #row end
  end

  local data = love.image.newImageData(w, h) -- initialisé transparent (0,0,0,0)
  for y = 1, h do
    local row = grid[y]
    for x = 1, #row do
      local c = palette[row:sub(x, x)]
      if c then
        data:setPixel(x - 1, y - 1, c[1], c[2], c[3], c[4] or 1) -- coords 0-indexées
      end
    end
  end

  local img = love.graphics.newImage(data)
  img:setFilter("nearest", "nearest") -- indispensable pour rester net au scale-up
  return { image = img, w = w, h = h }
end

return Sprite
