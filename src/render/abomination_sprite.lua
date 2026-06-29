-- src/render/abomination_sprite.lua
-- Rendu combat des abominations PvE. Les pixels viennent du generateur source
-- docs/generation/generateur-abominations.html via src/data/abomination_assets.lua.

local Sprite = require("src.core.sprite")
local Assets = require("src.data.abomination_assets")

local AbominationSprite = {}

local PIXEL_TO_WORLD = 0.58
local cache = {}

local function hexToColor(n)
  return {
    math.floor(n / 65536) % 256 / 255,
    math.floor(n / 256) % 256 / 255,
    n % 256 / 255,
    1,
  }
end

local function bake(asset)
  if not asset then return nil end
  local palette = {}
  for ch, n in pairs(asset.palette or {}) do
    palette[ch] = hexToColor(n)
  end
  local baked = Sprite.bake(asset.rows or {}, palette)
  baked.base = asset.base or baked.h
  baked.float = asset.float
  baked.assetId = asset.id
  return baked
end

local function bossAsset(key)
  local species = Assets.species[key]
  return species and species.boss or nil
end

local function generalAsset(id, key)
  local speciesKey = key or Assets.generalToSpecies[id]
  local species = speciesKey and Assets.species[speciesKey]
  return species and species.generals and species.generals[id] or nil
end

local function rawAssetFor(u)
  local spec = u and u.spec
  if not spec then return nil end
  if spec.visualKind == "abomination" then
    return bossAsset(spec.abomination or "leviathan")
  end
  if spec.visualKind == "abomination_general" then
    return generalAsset(spec.id or u.id, spec.abomination)
  end
  return nil
end

local function bakedFor(u)
  local asset = rawAssetFor(u)
  if not asset then return nil end
  local key = asset.id or asset.arch
  if not cache[key] then cache[key] = bake(asset) end
  return cache[key]
end

local function bossBaked(key)
  local asset = bossAsset(key or "leviathan")
  if not asset then return nil end
  local cacheKey = "boss:" .. tostring(asset.id or asset.arch)
  if not cache[cacheKey] then cache[cacheKey] = bake(asset) end
  return cache[cacheKey]
end

function AbominationSprite.isAbomination(u)
  local spec = u and u.spec
  return spec and spec.visualKind == "abomination"
end

function AbominationSprite.isGeneral(u)
  local spec = u and u.spec
  return spec and spec.visualKind == "abomination_general"
end

function AbominationSprite.isBossOrGeneral(u)
  return AbominationSprite.isAbomination(u) or AbominationSprite.isGeneral(u)
end

function AbominationSprite.shadowSize(u)
  if AbominationSprite.isAbomination(u) then return 24, 5 end
  if AbominationSprite.isGeneral(u) then return 11, 2.6 end
  return 8, 2
end

function AbominationSprite.draw(u, _t, opts)
  opts = opts or {}
  local baked = bakedFor(u)
  if not baked then return end

  local alpha = opts.alpha or 1
  local scale = PIXEL_TO_WORLD
  local x = math.floor((u.x or 0) - baked.w * scale * 0.5 + 0.5)
  local y = math.floor((u.y or 0) - baked.base * scale + 0.5)

  love.graphics.setColor(1, 1, 1, alpha)
  love.graphics.draw(baked.image, x, y, 0, scale, scale)

  if opts.flash and opts.flash > 0 then
    love.graphics.setColor(1, 1, 1, opts.flash)
    love.graphics.draw(baked.image, x, y, 0, scale, scale)
  end

  love.graphics.setColor(1, 1, 1, 1)
end

function AbominationSprite.drawBossIcon(key, cx, cy, maxW, maxH, alpha)
  local baked = bossBaked(key)
  if not baked then return false end
  maxW = maxW or baked.w
  maxH = maxH or baked.h
  local scale = math.min(maxW / baked.w, maxH / baked.h)
  local x = math.floor(cx - baked.w * scale * 0.5 + 0.5)
  local y = math.floor(cy - baked.h * scale * 0.5 + 0.5)
  love.graphics.setColor(1, 1, 1, alpha or 1)
  love.graphics.draw(baked.image, x, y, 0, scale, scale)
  love.graphics.setColor(1, 1, 1, 1)
  return true
end

function AbominationSprite.clearCache()
  cache = {}
end

return AbominationSprite
