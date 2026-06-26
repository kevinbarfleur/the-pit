-- tests/mock_love.lua
-- Mock minimal de l'API LÖVE pour exécuter la VRAIE logique du jeu sans écran (sous luajit).
-- Partagé par tests/headless.lua, tests/props.lua, tests/golden.lua, tools/sim.lua.
--
-- Renvoie la table `love`. Usage : `love = require("tests.mock_love")` (depuis la racine projet).
--
-- ⚠️ Le RNG de ce mock (xorshift32) N'EST PAS bit-identique au RNG de LÖVE. Il garantit le
-- déterminisme *à l'intérieur* du headless (même seed -> même suite), ce qui suffit pour les
-- tests de déterminisme/invariants/équilibrage. Les golden-logs qui doivent matcher le jeu
-- expédié devront tourner dans un vrai LÖVE headless (cf. docs/research/engine-architecture.md §8.7).

local bit = require("bit")

-- ── RandomGenerator seedé (interface : random / random(a,b) / getState / setState / setSeed) ──
local function newRandomGenerator(a, b)
  local seed = a or 0
  if b then seed = bit.bxor(bit.tobit(a), bit.lshift(bit.tobit(b), 1)) end -- (low, high) -> 1 état
  local s = bit.tobit(seed)
  if s == 0 then s = bit.tobit(0x1d2b3c4d) end -- l'état 0 est un point fixe du xorshift
  local rng = {}
  local function nextu()
    s = bit.bxor(s, bit.lshift(s, 13))
    s = bit.bxor(s, bit.rshift(s, 17))
    s = bit.bxor(s, bit.lshift(s, 5))
    return s
  end
  function rng:random(lo, hi)
    local f = bit.band(nextu(), 0x7fffffff) / 0x80000000 -- [0,1)
    if lo == nil then return f end
    if hi == nil then lo, hi = 1, lo end
    return lo + math.floor(f * (hi - lo + 1))
  end
  function rng:getState() return tostring(s) end
  function rng:setState(st) s = bit.tobit(tonumber(st) or 0) end
  function rng:setSeed(sd) s = bit.tobit(sd or 0); if s == 0 then s = bit.tobit(0x1d2b3c4d) end end
  return rng
end

-- ── Stubs graphiques / objets ──
local function texture() return { setFilter = function() end } end

local Transform = {}
Transform.__index = Transform
function Transform.new() return setmetatable({}, Transform) end
function Transform:apply() return self end
function Transform:transformPoint(x, y) return x or 0, y or 0 end

local imageData = {}
imageData.__index = imageData
function imageData:setPixel() end

local fontMock = {
  getWidth = function(_, s) return #tostring(s) * 6 end,
  getHeight = function() return 12 end,
  getWrap = function(_, s, limit) return limit, { tostring(s) } end, -- (width, lignes) : 1 ligne
  setFilter = function() end, getFilter = function() return "nearest", "nearest" end,
}

local love = {
  graphics = {
    setDefaultFilter = function() end, setLineStyle = function() end,
    setBackgroundColor = function() end, getBackgroundColor = function() return 0, 0, 0, 1 end,
    newCanvas = function() return texture() end, newImage = function() return texture() end,
    setCanvas = function() end, clear = function() end,
    setColor = function() end, draw = function() end,
    setBlendMode = function() end, getBlendMode = function() return "alpha", "alphamultiply" end,
    push = function() end, pop = function() end, origin = function() end,
    translate = function() end, rotate = function() end, scale = function() end,
    rectangle = function() end, circle = function() end, ellipse = function() end,
    polygon = function() end, line = function() end, setLineWidth = function() end,
    print = function() end, printf = function() end,
    setScissor = function() end, getScissor = function() end,
    setFont = function() end, newFont = function() return fontMock end,
    getFont = function() return fontMock end,
    getWidth = function() return 1280 end, getHeight = function() return 720 end,
    getDimensions = function() return 1280, 720 end,
    isActive = function() return true end, present = function() end,
  },
  image = { newImageData = function() return setmetatable({}, imageData) end },
  math = {
    random = function(a, b)
      if a and b then return a else return 0.5 end -- RNG global (hors-sim seulement)
    end,
    newRandomGenerator = newRandomGenerator,
    newTransform = function() return Transform.new() end,
  },
  keyboard = { isDown = function() return false end },
  mouse = { getPosition = function() return 0, 0 end, isDown = function() return false end },
  timer = { getFPS = function() return 60 end, step = function() return 1 / 60 end, sleep = function() end },
  event = { quit = function() end },
}

return love
