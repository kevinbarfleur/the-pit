-- src/scenes/gallery.lua
-- Écran GALERIE (debug/revue visuelle) : affiche TOUTES les entités du roster dans une grille,
-- rendues par le VRAI pipeline (Creatures[id] pour les 6 dédiées, sinon le générateur procédural).
-- Sert à juger le rendu animé à l'écran (l'ASCII headless est abstrait).
--
-- Interface scène : update / drawWorld / drawOverlay(view) / keypressed / mousepressed / mousemoved.
-- Accès : [g] depuis build (bascule, cf. main.lua). Survol = inspecter ; [a]/[h]/clic = animer.

local Background = require("src.fx.background")
local Rig = require("src.core.rig")
local Creatures = require("src.data.creatures")
local Units = require("src.data.units")
local CreatureGen = require("src.gen.creaturegen")
local T = require("src.core.i18n").t

local Gallery = {}
Gallery.__index = Gallery

-- Couleur d'accent par faction (panneau d'inspection / nom).
local TYPE_COL = {
  flesh = { 0.66, 0.53, 0.45 }, order = { 0.77, 0.63, 0.29 }, bone = { 0.66, 0.57, 0.44 },
  arcane = { 0.55, 0.40, 0.66 }, abyss = { 0.62, 0.24, 0.16 },
}

-- Mise en page (pixels virtuels). 10 colonnes × 5 rangées = 50 cases / page.
local COLS, MAX_ROWS = 10, 5
local CELL_W, CELL_H = 30, 28
local GX0, GY0 = 10, 26

function Gallery.new(palette, vw, vh, host)
  local self = setmetatable({
    vw = vw, vh = vh, t = 0, host = host, palette = palette,
    titleKey = "scene.gallery",
    hintKey = "ui.hint_gallery",
    bg = Background.new(palette, vw, vh),
    items = {},      -- { {id, char, type, gen}, ... } dans l'ordre du roster
    page = 1,
    mode = "idle",   -- "idle" | "attack" | "hurt" : anim rejouée en boucle sur toutes les entités
    hover = nil,     -- index global survolé
    nGen = 0, nHand = 0,
  }, Gallery)

  -- Construit un rig par unité, EXACTEMENT comme le combat (priorité aux 6 dédiées).
  for _, id in ipairs(Units.order) do
    local spec = Units[id] or {}
    local handmade = Creatures[id] ~= nil
    local def = handmade and Creatures[id]
      or CreatureGen.cached({ id = id, type = spec.type, effects = spec.effects })
    local char = Rig.new(def, palette)
    char.facing = 1
    self.items[#self.items + 1] = { id = id, char = char, type = spec.type, gen = not handmade }
    if handmade then self.nHand = self.nHand + 1 else self.nGen = self.nGen + 1 end
  end

  self.cols, self.rows = COLS, MAX_ROWS
  self.cellW, self.cellH = CELL_W, CELL_H
  self.perPage = COLS * MAX_ROWS
  self.pages = math.max(1, math.ceil(#self.items / self.perPage))
  return self
end

-- Position (centre x, baseline pieds y) d'une case locale de la page courante.
local function cellPos(localIdx)
  local i = localIdx - 1
  local c = i % COLS
  local r = math.floor(i / COLS)
  local cx = GX0 + c * CELL_W + math.floor(CELL_W / 2)
  local cy = GY0 + r * CELL_H + CELL_H - 3 -- pieds vers le bas de la case
  return cx, cy, c, r
end

function Gallery:update(frameDt)
  self.t = self.t + frameDt
  self.bg:update(frameDt, self.t)
  for _, it in ipairs(self.items) do
    -- rejoue l'anim choisie en boucle (revient à idle puis on re-déclenche).
    if self.mode ~= "idle" and it.char.state == "idle" then Rig.trigger(it.char, self.mode) end
    Rig.update(it.char, self.t, frameDt)
  end
end

function Gallery:drawWorld()
  self.bg:draw()

  local first = (self.page - 1) * self.perPage + 1
  local last = math.min(#self.items, self.page * self.perPage)
  for gi = first, last, 1 do
    local it = self.items[gi]
    local cx, cy = cellPos(gi - first + 1)
    it.char.x, it.char.y = cx, cy
    -- liseré de case (survol = accent faction, sinon trait discret).
    local hovered = (self.hover == gi)
    if hovered then
      local col = TYPE_COL[it.type] or { 0.7, 0.7, 0.7 }
      love.graphics.setColor(col[1], col[2], col[3], 0.5)
    else
      love.graphics.setColor(0.18, 0.15, 0.20, 0.35)
    end
    love.graphics.rectangle("line", cx - CELL_W / 2 + 1, cy - CELL_H + 2, CELL_W - 2, CELL_H - 2)
    love.graphics.setColor(1, 1, 1, 1)
    Rig.draw(it.char)
    -- marqueur "généré" (petit point) vs "dédié" (rien) au coin de la case.
    if it.gen then
      love.graphics.setColor(0.45, 0.78, 0.40, 0.7)
      love.graphics.rectangle("fill", cx + CELL_W / 2 - 4, cy - CELL_H + 3, 2, 2)
      love.graphics.setColor(1, 1, 1, 1)
    end
  end
end

function Gallery:drawOverlay(view)
  local sw, sh = love.graphics.getDimensions()

  -- Bandeau d'état (haut-droite, résolution native).
  love.graphics.setColor(0.62, 0.58, 0.50, 0.9)
  local status = T("gallery.status", {
    n = #self.items, gen = self.nGen, hand = self.nHand, mode = self.mode,
    page = self.page, pages = self.pages,
  })
  love.graphics.printf(status, 0, 12, sw - 16, "right")

  -- Panneau d'inspection de l'entité survolée (bas-gauche).
  if self.hover and self.items[self.hover] then
    local it = self.items[self.hover]
    local spec = Units[it.id] or {}
    local col = TYPE_COL[it.type] or { 0.8, 0.8, 0.8 }
    local x, y = 16, sh - 56
    love.graphics.setColor(col[1], col[2], col[3], 1)
    love.graphics.print(T("ui.unit_header", {
      name = T("unit." .. it.id .. ".name"), type = T("type." .. tostring(it.type)),
    }), x, y)
    love.graphics.setColor(0.72, 0.68, 0.60, 0.95)
    love.graphics.print(T("ui.unit_stats", { hp = spec.hp or 0, dmg = spec.dmg or 0, cd = spec.cd or 0 }), x, y + 16)
    love.graphics.setColor(0.50, 0.60, 0.45, 0.9)
    love.graphics.print(it.gen and T("gallery.generated") or T("gallery.handmade"), x, y + 32)
    love.graphics.setColor(1, 1, 1, 1)
  end
end

function Gallery:keypressed(key)
  if key == "a" then
    self.mode = (self.mode == "attack") and "idle" or "attack"
  elseif key == "h" then
    self.mode = (self.mode == "hurt") and "idle" or "hurt"
  elseif key == "right" or key == "]" then
    self.page = math.min(self.pages, self.page + 1)
  elseif key == "left" or key == "[" then
    self.page = math.max(1, self.page - 1)
  end
end

function Gallery:cellAt(vx, vy)
  local gx, gy = vx - GX0, vy - GY0
  if gx < 0 or gy < 0 then return nil end
  local c, r = math.floor(gx / CELL_W), math.floor(gy / CELL_H)
  if c < 0 or c >= COLS or r < 0 or r >= MAX_ROWS then return nil end
  local gi = (self.page - 1) * self.perPage + r * COLS + c + 1
  if gi > #self.items then return nil end
  return gi
end

function Gallery:mousemoved(vx, vy)
  self.hover = self:cellAt(vx, vy)
end

function Gallery:mousepressed(vx, vy, button)
  if button ~= 1 then return end
  local gi = self:cellAt(vx, vy)
  if gi then Rig.trigger(self.items[gi].char, "attack") end -- clic = rejoue l'attaque de l'entité
end

return Gallery
