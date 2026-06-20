-- src/board/board.lua
-- Le plateau-graphe : 9 slots, topologie échangeable par sigil. cf. gd-research-result.md §1.3-1.5.
-- Le CODE reste trivial : toute la complexité vit dans les DONNÉES (les formes/arêtes de shapes.lua).
-- Ajouter un sigil plus tard = ajouter de la data, zéro refacto.

local Shapes = require("src.board.shapes")

local Board = {}
Board.__index = Board

function Board.new(shapeName)
  local self = setmetatable({ slots = {} }, Board)
  for i = 1, 9 do self.slots[i] = { unit = nil, unlocked = false } end
  self:setShape(shapeName or "carre")
  self:unlock(3) -- on démarre à 3 slots actifs ; le leveling en débloque d'autres (§1.5)
  return self
end

-- Échange la topologie. Les unités restent attachées à leur slot (index conservé, les 9 slots
-- sont constants) ; seules la position de rendu et l'adjacence changent.
function Board:setShape(name)
  local shape = Shapes[name]
  assert(shape, "forme inconnue: " .. tostring(name))
  self.shape = shape
  -- Table d'adjacence symétrique reconstruite depuis la liste d'arêtes.
  local adj = {}
  for i = 1, 9 do adj[i] = {} end
  for _, e in ipairs(shape.edges) do
    local a, b = e[1], e[2]
    table.insert(adj[a], b)
    table.insert(adj[b], a)
  end
  self.adj = adj
end

-- Voisins (= portée des synergies) d'un slot, lus dans le graphe. C'est tout.
function Board:neighbors(i) return self.adj[i] end

function Board:unlock(n)
  self.activeCount = math.max(0, math.min(9, n))
  for i = 1, 9 do self.slots[i].unlocked = (i <= self.activeCount) end
end

function Board:unlockMore() self:unlock((self.activeCount or 0) + 1) end

function Board:place(i, unit) self.slots[i].unit = unit end

-- Slot le plus « avancé » (front = plus grand x de rendu) parmi les slots actifs.
-- Sert au ciblage front/back par colonne (§1.4) : survit à tout changement de forme.
function Board:frontIndex()
  local best, bestX
  for i = 1, 9 do
    if self.slots[i].unlocked then
      local x = self.shape.cells[i].x
      if not bestX or x > bestX then best, bestX = i, x end
    end
  end
  return best
end

return Board
