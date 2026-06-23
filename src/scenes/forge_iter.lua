-- src/scenes/forge_iter.lua
-- VUE D'ITERATION (dev/debug) : showcase de la technique en cours d'exploration.
-- ITERATION ACTUELLE = GENERATEUR PAR PRIMITIVES (src/gen/primgen.lua) : archetype + palette + corruption,
-- seede/deterministe, bake en Image nearest. On y teste NOS themes pour comparer a l'exploration HTML externe.
--
-- ANIMATION : les sprites primgen sont MONOLITHIQUES (une Image) -> on les anime en SPRITE-ENTIER (squash/stretch) :
--   idle = respiration/bob (toujours) · [a] attaque = fente + etirement · [h] hurt = recul + flash.
-- (Demo de compatibilite animation : le mouvement secondaire ancre -- queue/tentacules via l'anatomie -- viendra apres.)
--
-- Strings en DUR (outil dev, hors i18n). Acces : [i] depuis build/galerie (bascule, cf. main.lua). [r] reroll · [esc] build.

local Primgen = require("src.gen.primgen")
local Draw = require("src.ui.draw")               -- pour Draw.begin/finish (transform espace-design du cadre)
local ScreenFrame = require("src.ui.screenframe") -- ENROBAGE partagé : cadre de pierre gravée + onglet « ITERATION »

local ForgeIter = {}
ForgeIter.__index = ForgeIter

-- Inset (pixels VIRTUELS) du cadre de pierre gravée (ScreenFrame) : marge ~10px = (8+2)×4 design /4.
-- La grille de sujets vit dans [IN_X, IN_X+IN_W]×[IN_Y, IN_Y+IN_H] -> ne passe jamais sous la pierre.
local IN_X, IN_Y, IN_W, IN_H = 10, 10, 300, 160

-- ── SUJETS : vitrine des 5 FAMILLES v3 (corps EXCLUSIFS) sur (family, archetype, palette) de primgen.
-- familles : cauchemar(4 archs) · mortvivant(3) · bete(3) · demon(3) · insecte(3). arch/pal = index DANS la famille.
local SUBJECTS = {
  { label = "MORTVIVANT / skeleton", family = "mortvivant", arch = 1, pal = 1, seed = 101 },
  { label = "MORTVIVANT / revenant", family = "mortvivant", arch = 3, pal = 2, seed = 137 },
  { label = "CAUCHEMAR / pendu",     family = "cauchemar",  arch = 2, pal = 2, seed = 202 },
  { label = "CAUCHEMAR / tisserand", family = "cauchemar",  arch = 3, pal = 1, seed = 233 },
  { label = "BETE / dragon",         family = "bete",       arch = 1, pal = 2, seed = 303 },
  { label = "BETE / wolf",           family = "bete",       arch = 3, pal = 1, seed = 331 },
  { label = "DEMON / brute",         family = "demon",      arch = 1, pal = 1, seed = 404 },
  { label = "DEMON / imp",           family = "demon",      arch = 3, pal = 3, seed = 433 },
  { label = "INSECTE / mantis",      family = "insecte",    arch = 2, pal = 1, seed = 505 },
}

local FAM_COL = {
  mortvivant = { 0.82, 0.80, 0.70 }, cauchemar = { 0.55, 0.80, 0.64 }, bete = { 0.84, 0.74, 0.40 },
  demon = { 0.88, 0.44, 0.26 }, insecte = { 0.58, 0.88, 0.42 },
}

local ATK_DUR, HRT_DUR = 22, 20 -- en "frames" (dt ~= 1.0/tick)

function ForgeIter.new(palette, vw, vh, host)
  local self = setmetatable({
    vw = vw, vh = vh, t = 0, host = host, palette = palette,
    daChrome = true,
    salt = 0,             -- reroll
    mode = "idle", modeAge = 0, -- anim sprite-entier rejouee sur tous (comme la galerie)
    items = {},
  }, ForgeIter)
  self:rebuild()
  return self
end

function ForgeIter:rebuild()
  self.items = {}
  for i, s in ipairs(SUBJECTS) do
    local def = Primgen.generate({ seed = s.seed + self.salt * 0x9E3779B9, family = s.family, archIndex = s.arch, paletteIndex = s.pal })
    self.items[#self.items + 1] = {
      label = s.label, family = s.family, img = def.image, w = def.w, h = def.h, name = def.name, arch = def.arch,
      phase = i * 1.9, -- decalage d'idle -> pas de respiration synchronisee
    }
  end
end

function ForgeIter:update(dt)
  dt = dt or 1
  self.t = self.t + dt
  if self.mode ~= "idle" then
    self.modeAge = self.modeAge + dt
    local dur = (self.mode == "attack") and ATK_DUR or HRT_DUR
    if self.modeAge >= dur then self.mode = "idle"; self.modeAge = 0 end
  end
end

-- Grille calée sur l'INSET (cellW/cellH dérivés de IN_W/IN_H, pas de vw/vh plein écran) -> la grille tient
-- dans le cadre de pierre. Les origines de cellule sont décalées par IN_X/IN_Y dans drawWorld.
function ForgeIter:layout()
  local n = #self.items
  local cols = math.min(3, n)
  local rows = math.ceil(n / cols)
  return cols, rows, IN_W / cols, IN_H / rows
end

-- transform d'anim sprite-entier pour un item -> dx,dy,sx,sy,flash.
function ForgeIter:animOf(it)
  local dx, dy = 0, math.sin((self.t + it.phase) * 0.08) * 1.5       -- idle bob
  local sx, sy = 1, 1 + math.sin((self.t + it.phase) * 0.10) * 0.03  -- idle respiration
  local flash = 0
  if self.mode == "attack" then
    local f = math.sin(math.min(1, self.modeAge / ATK_DUR) * math.pi)
    dx = dx + f * 6; sx = sx + f * 0.12; sy = sy - f * 0.06          -- fente + etirement avant
  elseif self.mode == "hurt" then
    local f = math.sin(math.min(1, self.modeAge / HRT_DUR) * math.pi)
    dx = dx - f * 4; sx = sx - f * 0.05; sy = sy + f * 0.10; flash = f -- recul + squash + flash
  end
  return dx, dy, sx, sy, flash
end

function ForgeIter:drawWorld()
  love.graphics.setColor(0.05, 0.04, 0.07, 1)
  love.graphics.rectangle("fill", 0, 0, self.vw, self.vh)

  local cols, rows, cellW, cellH = self:layout()
  for i, it in ipairs(self.items) do
    local ci, ri = (i - 1) % cols, math.floor((i - 1) / cols)
    local cx = math.floor(IN_X + (ci + 0.5) * cellW + 0.5)            -- décalé dans l'inset
    local feetY = math.floor(IN_Y + (ri + 1) * cellH - 16 + 0.5)      -- décalé dans l'inset
    local scale = (cellH * 0.62) / it.h
    if it.w * scale > cellW * 0.86 then scale = (cellW * 0.86) / it.w end
    it._cx, it._feetY = cx, feetY
    local dx, dy, sx, sy, flash = self:animOf(it)
    love.graphics.setColor(0, 0, 0, 0.32) -- ombre de contact
    love.graphics.ellipse("fill", cx, feetY, it.w * scale * 0.34, 2.5)
    love.graphics.setColor(1, 1 - flash * 0.45, 1 - flash * 0.6, 1) -- flash rougeoyant sur hurt
    love.graphics.draw(it.img, cx + dx, feetY + dy, 0, scale * sx, scale * sy, it.w / 2, 58)
  end
  love.graphics.setColor(1, 1, 1, 1)
end

function ForgeIter:drawOverlay(view)
  -- Bandeaux (haut-gauche, résolution native) rentrés DANS l'inset du cadre de pierre : origine décalée de
  -- 10px virtuels (= marge ScreenFrame) convertis en px écran via `view`. Ne passent jamais sous la pierre.
  local m = 10 * (view.scale or 4)
  local tx, ty = (view.ox or 0) + m, (view.oy or 0) + m
  love.graphics.setColor(0.80, 0.74, 0.62, 0.95)
  love.graphics.print("FORGE  -  ITERATION  ::  primitives v3 (5 familles, corps exclusifs + ancrage)  ::  anim sprite-entier", tx, ty + 2)
  love.graphics.setColor(0.50, 0.45, 0.40, 1)
  love.graphics.print("[a] attaque   [h] hurt   [r] reroll   [i]/[esc] build    -    salt #" .. self.salt, tx, ty + 20)

  for _, it in ipairs(self.items) do
    if it._cx then
      local sx = view.ox + it._cx * view.scale
      local sy = view.oy + (it._feetY + 6) * view.scale
      local col = FAM_COL[it.family] or { 0.8, 0.8, 0.8 }
      love.graphics.setColor(col[1], col[2], col[3], 1)
      love.graphics.printf(it.label .. "  ::  " .. it.name, sx - 160, sy, 320, "center")
      love.graphics.setColor(0.55, 0.52, 0.48, 0.9)
      love.graphics.printf("<" .. tostring(it.arch) .. ">", sx - 160, sy + 16, 320, "center")
    end
  end
  love.graphics.setColor(1, 1, 1, 1)

  -- ENROBAGE partagé : cadre de pierre gravée + onglet « ITERATION », posé EN DERNIER (espace design via
  -- Draw.begin) par-dessus le monde + les bandeaux. Intérieur transparent : la grille vit dans l'inset.
  Draw.begin(view)
  ScreenFrame.draw("ITERATION", { ft = ScreenFrame.FT })
  Draw.finish()
end

function ForgeIter:keypressed(key)
  if key == "a" then
    self.mode = "attack"; self.modeAge = 0
  elseif key == "h" then
    self.mode = "hurt"; self.modeAge = 0
  elseif key == "r" or key == "space" then
    self.salt = self.salt + 1; self:rebuild()
  end
end

return ForgeIter
