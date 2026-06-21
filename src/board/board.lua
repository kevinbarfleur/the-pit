-- src/board/board.lua
-- Le plateau-graphe : 9 slots, topologie échangeable par sigil. cf. gd-research-result.md §1.3-1.5.
-- Le CODE reste trivial : toute la complexité vit dans les DONNÉES (les formes/arêtes de shapes.lua).
-- Ajouter un sigil plus tard = ajouter de la data, zéro refacto.

local Shapes = require("src.board.shapes")

local START_OPEN = 3 -- cases ouvertes au départ (miroir de RunState.START_SLOTS) ; les grants timés en ouvrent +

local Board = {}
Board.__index = Board

function Board.new(shapeName)
  local self = setmetatable({ slots = {}, activeCount = 0 }, Board)
  for i = 1, 9 do self.slots[i] = { unit = nil, unlocked = false } end
  self:setShape(shapeName or "carre")
  -- Départ = CLUSTER CENTRAL connexe (case de plus haut degré + voisines), PAS la rangée du haut linéaire :
  -- l'adjacence compte dès le 1er round (décision 2026-06, cf. the-pit-balance-diagnosis « rangée du milieu »).
  self:ensureOpen(START_OPEN)
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

-- ── OUVERTURE DE CASES (placement libre). L'ensemble des cases ouvertes n'est PLUS un préfixe d'index
-- (1..n) mais un ENSEMBLE arbitraire : un grant timé ouvre la case CHOISIE par le joueur (acceptSlotGrant).
-- Heuristique de défaut (UI absente / headless) : on grandit un CLUSTER CONNEXE central. ──

function Board:degreeOf(i) return #(self.adj[i] or {}) end
function Board:isOpen(i) return self.slots[i] ~= nil and self.slots[i].unlocked end
function Board:openCount() return self.activeCount or 0 end

-- Recompte la capacité active depuis l'ensemble ouvert (source de vérité = les flags unlocked).
function Board:recount()
  local n = 0
  for i = 1, 9 do if self.slots[i].unlocked then n = n + 1 end end
  self.activeCount = n
  return n
end

-- Meilleure case VIDE à ouvrir : maximise la connexité aux cases déjà ouvertes (cluster connexe), puis le
-- degré (cases centrales), puis index bas. Au tout début (rien d'ouvert) -> la case de plus haut degré.
function Board:bestEmptyCell()
  local best, bestScore
  for i = 1, 9 do
    if not self.slots[i].unlocked then
      local conn = 0
      for _, j in ipairs(self.adj[i]) do if self.slots[j].unlocked then conn = conn + 1 end end
      local score = conn * 100 + self:degreeOf(i) * 10 - i -- connexité >> degré >> index
      if not bestScore or score > bestScore then best, bestScore = i, score end
    end
  end
  return best
end

-- Ouvre une case précise (placement libre côté UI). Renvoie false si invalide ou déjà ouverte.
function Board:openCell(i)
  if not (i and self.slots[i]) or self.slots[i].unlocked then return false end
  self.slots[i].unlocked = true
  self:recount()
  return true
end

-- Réconcilie l'ensemble ouvert à une capacité n : ouvre les meilleures cases vides jusqu'à n (ne ferme JAMAIS).
-- Sert au départ et au pilotage headless (le grant accepté ouvre une case ; ici on rattrape si en retard).
function Board:ensureOpen(n)
  n = math.max(0, math.min(9, n))
  while self:openCount() < n do
    local i = self:bestEmptyCell()
    if not i then break end
    self:openCell(i)
  end
end

-- COMPAT : ouverture en PRÉFIXE d'index (cases 1..n), un RESET déterministe. Utilisé par le CATALOGUE de
-- compositions, les tests et les outils de sim, qui assignent des slots EXPLICITES (1..boardLevel) et veulent
-- un ensemble reproductible — PAS le placement libre du jeu (qui passe par openCell/ensureOpen). Réf data:
-- src/data/compositions.lua. Le jeu réel (src/scenes/build.lua) n'appelle jamais ceci.
function Board:unlock(n)
  n = math.max(0, math.min(9, n))
  for i = 1, 9 do self.slots[i].unlocked = (i <= n) end
  self.activeCount = n
end

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
