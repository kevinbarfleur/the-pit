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
local Critter = require("src.render.critter") -- rendu VIVANT (cadre natif + mouvement par-pixel/famille) — vitrine
local Rarity = require("src.gen.rarity")
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

-- VITRINE des nouveaux BODY-PLANS (axe découplé de la famille) : créatures-démo générées à la volée,
-- pas des unités de jeu (donc hors Units/boutique/i18n). Affichées après le roster pour juger les
-- silhouettes radicalement non-bipèdes (blob / quadrupède / céphalopode) à travers les familles.
local DEMOS = {
  { label = "OOZE", type = "abyss", bodyplan = "blob" },
  { label = "OOZE", type = "bone", bodyplan = "blob" },
  { label = "OOZE", type = "arcane", bodyplan = "blob" },
  { label = "OOZE", type = "flesh", bodyplan = "blob" },
  { label = "BEAST", type = "flesh", bodyplan = "quadruped" },
  { label = "BEAST", type = "bone", bodyplan = "quadruped" },
  { label = "BEAST", type = "abyss", bodyplan = "quadruped" },
  { label = "BEAST", type = "order", bodyplan = "quadruped" },
  { label = "ELDRITCH", type = "arcane", bodyplan = "cephalopod" },
  { label = "ELDRITCH", type = "abyss", bodyplan = "cephalopod" },
  { label = "ELDRITCH", type = "order", bodyplan = "cephalopod" },
  { label = "ELDRITCH", type = "bone", bodyplan = "cephalopod" },
  -- nouveaux body-plans (axe découplé) : masse grouillante / chaîne en S / empreinte radiale / orbe.
  { label = "SWARM", type = "abyss", bodyplan = "swarm" },
  { label = "SWARM", type = "bone", bodyplan = "swarm" },
  { label = "SWARM", type = "flesh", bodyplan = "swarm" },
  { label = "SERPENT", type = "abyss", bodyplan = "serpent" },
  { label = "SERPENT", type = "arcane", bodyplan = "serpent" },
  { label = "SERPENT", type = "bone", bodyplan = "serpent" },
  { label = "ARACHNID", type = "abyss", bodyplan = "arachnid" },
  { label = "ARACHNID", type = "bone", bodyplan = "arachnid" },
  { label = "ARACHNID", type = "flesh", bodyplan = "arachnid" },
  { label = "EYE", type = "arcane", bodyplan = "eye" },
  { label = "EYE", type = "abyss", bodyplan = "eye" },
  { label = "EYE", type = "order", bodyplan = "eye" },
}

-- ÉCHELLE DE RANGS (rareté) : une même créature aux 5 rangs -> on lit la montée échelle+ornement+glow+cadre.
local RANK_LADDERS = {
  { label = "ELDRITCH", type = "arcane", bodyplan = "cephalopod" },
  { label = "BEAST", type = "flesh", bodyplan = "quadruped" },
  { label = "OOZE", type = "abyss", bodyplan = "blob" },
}

-- LÉGENDAIRES = CHIMÈRES (R5) : fusion de 2 body-plans (« mi-X mi-Y »). Cadre or + glow + couronne.
local LEGENDARIES = {
  { label = "SOVEREIGN", type = "arcane", bodyplan = "chimera:humanoid:tentacles" },
  { label = "HEAD-BEAST", type = "abyss", bodyplan = "chimera:cephalopod:quadruped" },
  { label = "BEAST-MAN", type = "flesh", bodyplan = "chimera:humanoid:quadruped" },
  { label = "DROWNED-KING", type = "bone", bodyplan = "chimera:humanoid:tentacles" },
}

-- Halo additif derrière le sprite (rangs hauts « rayonnent »). col = teinte de rang.
local function drawGlow(cx, cy, rad, col, a)
  love.graphics.setBlendMode("add")
  for i = 3, 1, -1 do
    love.graphics.setColor(col[1], col[2], col[3], a * 0.10 * i)
    love.graphics.circle("fill", cx, cy, rad * (i / 3))
  end
  love.graphics.setBlendMode("alpha")
  love.graphics.setColor(1, 1, 1, 1)
end

-- Pips de rang (1..5 petits carrés) en bas de case, teintés du rang.
local function drawPips(cx, cyBottom, rank, col)
  love.graphics.setColor(col[1], col[2], col[3], 0.95)
  for i = 1, rank do
    love.graphics.rectangle("fill", cx - CELL_W / 2 + 3 + (i - 1) * 3, cyBottom - 3, 2, 2)
  end
  love.graphics.setColor(1, 1, 1, 1)
end

function Gallery.new(palette, vw, vh, host)
  local self = setmetatable({
    vw = vw, vh = vh, t = 0, host = host, palette = palette,
    nativeWorld = true, -- créatures rendues en RÉSOLUTION NATIVE (nettes ; le bg ×4 reste identique)
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
      or CreatureGen.cached({ id = id, type = spec.type, family = spec.family, effects = spec.effects, bodyplan = spec.bodyplan, rank = spec.rank })
    local char = Rig.new(def, palette)
    char.facing = 1
    -- rank/bodyplan portés sur l'item -> cadre+pips+glow de rareté visibles sur les VRAIES unités
    -- (pas que les démos) dès qu'units.lua porte ces champs. Vanille (handmade) : spec.rank nil -> pas de cadre.
    self.items[#self.items + 1] = {
      id = id, char = char, type = spec.type, gen = not handmade,
      bodyplan = spec.bodyplan, rank = spec.rank,
    }
    if handmade then self.nHand = self.nHand + 1 else self.nGen = self.nGen + 1 end
  end

  -- Vitrine des body-plans (démos générées à la volée, déterministes par id-démo).
  for i, d in ipairs(DEMOS) do
    local id = "demo_" .. d.bodyplan .. "_" .. d.type
    local def = CreatureGen.cached({ id = id, type = d.type, effects = {}, bodyplan = d.bodyplan })
    local char = Rig.new(def, palette)
    char.facing = 1
    self.items[#self.items + 1] = {
      id = id, char = char, type = d.type, gen = true, demo = true,
      label = d.label, bodyplan = d.bodyplan,
    }
    self.nGen = self.nGen + 1
    local _ = i
  end

  -- Échelles de rangs : même créature aux 5 rangs (rareté visible : échelle/ornement/glow/cadre/pips).
  for _, d in ipairs(RANK_LADDERS) do
    for rank = 1, 5 do
      local id = "rank_" .. d.bodyplan .. "_" .. rank
      local def = CreatureGen.cached({ id = id, type = d.type, effects = {}, bodyplan = d.bodyplan, rank = rank })
      local char = Rig.new(def, palette)
      char.facing = 1
      self.items[#self.items + 1] = {
        id = id, char = char, type = d.type, gen = true, demo = true,
        label = d.label, bodyplan = d.bodyplan, rank = rank,
      }
      self.nGen = self.nGen + 1
    end
  end

  -- Légendaires chimériques (R5) : la fusion de 2 plans = l'« événement visuel du run ».
  for _, d in ipairs(LEGENDARIES) do
    local id = "legend_" .. d.bodyplan:gsub(":", "_") .. "_" .. d.type
    local def = CreatureGen.cached({ id = id, type = d.type, effects = {}, bodyplan = d.bodyplan, rank = 5 })
    local char = Rig.new(def, palette)
    char.facing = 1
    self.items[#self.items + 1] = {
      id = id, char = char, type = d.type, gen = true, demo = true,
      label = d.label, bodyplan = d.bodyplan, rank = 5,
    }
    self.nGen = self.nGen + 1
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
    -- glow de rareté DERRIÈRE le sprite (rangs hauts seulement ; halo additif teinté du rang).
    if it.rank then
      local rar = Rarity.get(it.rank)
      if rar.glow > 0 then drawGlow(cx, cy - 11, 13, Rarity.frame(it.rank), rar.glow) end
    end
    -- liseré : rang -> teinte de rareté (toujours visible) ; sinon survol = accent faction / trait discret.
    local hovered = (self.hover == gi)
    if it.rank then
      local col = Rarity.frame(it.rank)
      love.graphics.setColor(col[1], col[2], col[3], hovered and 0.95 or 0.6)
    elseif hovered then
      local col = TYPE_COL[it.type] or { 0.7, 0.7, 0.7 }
      love.graphics.setColor(col[1], col[2], col[3], 0.5)
    else
      love.graphics.setColor(0.18, 0.15, 0.20, 0.35)
    end
    love.graphics.rectangle("line", cx - CELL_W / 2 + 1, cy - CELL_H + 2, CELL_W - 2, CELL_H - 2)
    love.graphics.setColor(1, 1, 1, 1)
    -- RENDU VIVANT pour les vraies unités générées en idle (cadre natif 64 -> tailles relatives + mouvement
    -- par famille). Démos/échelles/dédiées + anims attack/hurt restent sur le rig baké (Rig.draw).
    if self.mode == "idle" and it.gen and not it.demo and Critter.has(it.id) then
      Critter.draw(nil, it.id, cx - CELL_W / 2, cy - CELL_H, CELL_W, CELL_H, self.t / 60, 1, 1.0)
    else
      Rig.draw(it.char)
    end
    -- marqueur : rang -> pips ; sinon démo body-plan (cyan) / généré (vert) / dédié (rien).
    if it.rank then
      drawPips(cx, cy + 1, it.rank, Rarity.frame(it.rank))
    elseif it.demo then
      love.graphics.setColor(0.40, 0.70, 0.82, 0.85)
      love.graphics.rectangle("fill", cx + CELL_W / 2 - 4, cy - CELL_H + 3, 2, 2)
      love.graphics.setColor(1, 1, 1, 1)
    elseif it.gen then
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
    local col = TYPE_COL[it.type] or { 0.8, 0.8, 0.8 }
    local x, y = 16, sh - 56
    love.graphics.setColor(col[1], col[2], col[3], 1)
    if it.demo then
      -- démo body-plan : pas d'unité de jeu derrière (ni stats ni i18n) -> on affiche forme + famille.
      love.graphics.print(it.label .. "  <" .. it.bodyplan .. ">", x, y)
      love.graphics.setColor(0.72, 0.68, 0.60, 0.95)
      love.graphics.print(T("type." .. tostring(it.type)) .. " family", x, y + 16)
      if it.rank then
        local rc = Rarity.frame(it.rank)
        love.graphics.setColor(rc[1], rc[2], rc[3], 1)
        love.graphics.print("RANK " .. it.rank .. " / 5  (scale " .. string.format("%.2f", Rarity.get(it.rank).scale) .. ")", x, y + 32)
      else
        love.graphics.setColor(0.40, 0.70, 0.82, 0.9)
        love.graphics.print("body-plan demo", x, y + 32)
      end
    else
      local spec = Units[it.id] or {}
      love.graphics.print(T("ui.unit_header", {
        name = T("unit." .. it.id .. ".name"), type = T("type." .. tostring(it.type)),
      }), x, y)
      love.graphics.setColor(0.72, 0.68, 0.60, 0.95)
      love.graphics.print(T("ui.unit_stats", { hp = spec.hp or 0, dmg = spec.dmg or 0, cd = spec.cd or 0 }), x, y + 16)
      love.graphics.setColor(0.50, 0.60, 0.45, 0.9)
      love.graphics.print(it.gen and T("gallery.generated") or T("gallery.handmade"), x, y + 32)
    end
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
