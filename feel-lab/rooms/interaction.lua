-- feel-lab/rooms/interaction.lua
-- LE CŒUR « BONBON SUCRÉ » — atelier d'interaction. Démontre, en direct et comparable :
--   • boutons (tons variés) : hover lift/glow/scale + press squash/flash + action différée + SON (pitch ±)
--   • DRAG & DROP à la Balatro : spring découplé (vel*0.75+(tgt-pos)*0.25) + TILT par vélocité + lift/ombre + snap
--   • SCREEN-SHAKE trauma² + HITSTOP (bouton STRIKE) — apparié au son (« shake sans son = creux »)
--   • NUMBER-ROLL à pitch montant (échelle C-D-E-F-G) — le payoff dopaminergique
--   • SÉLECTEUR DE PROFIL (Grimdark 0.2 <-> Balatro 1.0) : règle l'intensité du candy pour JUGER le feeling

local Draw    = require("lib.draw")
local Theme   = require("lib.theme")
local Widgets = require("lib.widgets")
local B       = require("lib.behavior")
local Juice   = require("lib.juice")
local SFX     = require("lib.sfx")

local Room = {}
Room.__index = Room
local c = Theme.c
local W, H = 1280, 720
local TS = 70   -- taille d'un jeton de drag

local GEMS = {
  { id = "burn",   col = c.burn },
  { id = "bleed",  col = c.bleed },
  { id = "poison", col = c.poison },
  { id = "rot",    col = c.rot },
  { id = "shock",  col = c.shock },
}

function Room.new(app)
  local self = setmetatable({ app = app, mx = -1, my = -1, click = nil, t = 0 }, Room)
  -- jetons + slots du bac à sable de drag
  self.tokens, self.slots = {}, {}
  local homeY = 250
  local x0 = 760
  for i, g in ipairs(GEMS) do
    local hx = x0 + (i - 1) * (TS + 24)
    self.tokens[i] = { id = g.id, col = g.col, hx = hx, hy = homeY,
                       d = { px = hx, py = homeY }, slot = nil }
  end
  local slotY = 470
  for i = 1, #GEMS do
    self.slots[i] = { x = x0 + (i - 1) * (TS + 24), y = slotY, token = nil }
  end
  self.dragging = nil
  -- number roll
  self.score, self.shown = 0, 0
  self.combo = 0
  return self
end

function Room:enter() self.title = "Interaction Feel" end

function Room:update(dt)
  self.t = self.t + (dt or 0)
  for _, tk in ipairs(self.tokens) do B.dragApply(tk.d, dt) end
  -- roll du score affiché vers la cible (ease)
  if math.abs(self.score - self.shown) > 0.5 then
    self.shown = self.shown + (self.score - self.shown) * math.min(1, (dt or 0) * 9)
  else
    self.shown = self.score
  end
end

function Room:input(r)
  return { over = B.hit(r, self.mx, self.my), down = false,
           clicked = self.click and B.hit(r, self.click.x, self.click.y) or false }
end

-- ── STRIKE : combo impact (shake + hitstop + son grave + flash) ─────────────────────────────────────────
function Room:strike()
  Juice.addTrauma(0.6)
  Juice.freeze(0.08)
  SFX.play("thud")
  self.flash = 0.5
end

-- ── SCORE + : ajoute une valeur et monte d'un cran dans l'échelle (combo dopaminergique) ─────────────────
function Room:scorePlus()
  local add = 50 + math.floor((love and love.math.random() or math.random()) * 250)
  self.score = self.score + add
  self.combo = self.combo + 1
  SFX.ladder(self.combo == 1)        -- repart à C au 1er, monte ensuite
  Juice.addTrauma(0.12)
  Juice.juice_up("score", 0.16 + 0.10 * B.profile)
end

function Room:draw(view)
  Draw.begin(view)

  -- ── bandeau de contrôle (profil / son / strike) ───────────────────────────────────────────────────────
  local barY = 84
  Draw.textTrackedL("FEEL PROFILE", 40, barY, c.ink4, Theme.label(11), 2)
  local presets = { { "Grimdark", 0.2 }, { "Balanced", 0.6 }, { "Balatro", 1.0 } }
  for i, p in ipairs(presets) do
    local r = { x = 40 + (i - 1) * 132, y = barY + 18, w = 120, h = 38 }
    local sel = math.abs(B.profile - p[2]) < 0.06
    Widgets.button("prof_" .. i, r, { label = p[1], tone = sel and "cta" or "ghost", font = Theme.label(14),
      onClick = function() B.profile = p[2] end }, self:input(r))
  end

  -- SOUND toggle
  local sndR = { x = 480, y = barY + 18, w = 56, h = 30 }
  Widgets.toggle("snd", sndR, { on = SFX.enabled, label = "Sound",
    onClick = function() local on = SFX.toggle(); self.app:setSfx(on) end }, self:input(sndR))

  -- STRIKE (shake + hitstop)
  local strR = { x = 600, y = barY + 14, w = 160, h = 44 }
  Widgets.button("strike", strR, { label = "Strike!", tone = "cta", font = Theme.title(16),
    onClick = function() self:strike() end }, self:input(strR))

  Draw.divider(W / 2, barY + 74, W - 80, c.brass, 0.5)

  -- ── colonne gauche : showcase de boutons + carte ──────────────────────────────────────────────────────
  Draw.textTrackedL("BUTTONS — hover · press · sound", 40, 190, c.gold, Theme.title(15), 2)
  local btns = {
    { id = "b_cta", label = "Enter The Pit", tone = "cta" },
    { id = "b_def", label = "Reroll", tone = "default" },
    { id = "b_eco", label = "Level Up", tone = "eco" },
    { id = "b_ghost", label = "Inspect", tone = "ghost" },
  }
  for i, b in ipairs(btns) do
    local r = { x = 40, y = 224 + (i - 1) * 64, w = 320, h = 50 }
    Widgets.button(b.id, r, { label = b.label, tone = b.tone, font = Theme.title(17),
      onClick = function() SFX.play("click") end }, self:input(r))
  end
  -- bouton désactivé (compare l'absence de juice)
  local dr = { x = 40, y = 224 + 4 * 64, w = 320, h = 50 }
  Widgets.button("b_dis", dr, { label = "Sold out", tone = "default", enabled = false }, self:input(dr))

  -- carte hoverable (lift + glow + scale)
  local cardR = { x = 400, y = 224, w = 300, h = 230 }
  Widgets.card("card_demo", cardR, { title = "Maw of Ash", accent = c.ember,
    body = "On a kill, your team's afflictions refuse to decay. The Pit remembers every wound." },
    self:input(cardR))

  -- ── number-roll (payoff) ──────────────────────────────────────────────────────────────────────────────
  local scR = { x = 400, y = 478, w = 300, h = 56 }
  Widgets.button("score_btn", scR, { label = "+ Score (combo)", tone = "eco", font = Theme.title(16),
    onClick = function() self:scorePlus() end }, self:input(scR))
  local resR = { x = 400, y = 544, w = 140, h = 40 }
  Widgets.button("score_reset", resR, { label = "Reset", tone = "ghost", font = Theme.label(14),
    onClick = function() self.score, self.combo = 0, 0 end }, self:input(resR))
  -- valeur qui roule, punchée
  local sc = Juice.scale("score")
  love.graphics.push()
  love.graphics.translate(620, 600)
  love.graphics.scale(sc, sc)
  Draw.textC(string.format("%d", math.floor(self.shown + 0.5)), 0, -28, c.gold, Theme.display(48))
  love.graphics.pop()
  Draw.textC(self.combo > 0 and ("combo ×" .. self.combo) or "click to score", 620, 626, c.ink4, Theme.label(12))

  -- ── colonne droite : bac à sable DRAG & DROP ──────────────────────────────────────────────────────────
  Draw.textTrackedL("DRAG & DROP", 760, 188, c.gold, Theme.title(15), 2)
  Draw.text("pick up a sigil · feel the sway · drop it in a socket", 760, 210, c.ink4, Theme.body(13))
  Draw.text("home", 760, 232, c.ink5, Theme.label(11))
  Draw.text("sockets", 760, 446, c.ink5, Theme.label(11))
  -- slots
  for _, s in ipairs(self.slots) do
    local occupied = s.token ~= nil
    Widgets.panel(s.x, s.y, TS, TS, { r = 8, fill = c.stone850, border = occupied and c.brass or c.brassD })
    if not occupied then
      love.graphics.setColor(c.brassD[1], c.brassD[2], c.brassD[3], 0.6)
      love.graphics.circle("line", s.x + TS / 2, s.y + TS / 2, 18)
    end
  end
  -- jetons (le draggé en DERNIER = au-dessus, z-order propre)
  for i = 1, #self.tokens do
    if i ~= self.dragging then self:drawToken(self.tokens[i], false) end
  end
  if self.dragging then self:drawToken(self.tokens[self.dragging], true) end

  -- flash plein écran (STRIKE)
  if self.flash and self.flash > 0.01 then
    love.graphics.setColor(c.ember[1], c.ember[2], c.ember[3], 0.18 * self.flash)
    love.graphics.rectangle("fill", 0, 0, W, H)
    self.flash = self.flash * 0.86
  end

  Draw.finish()
  self.click = nil
end

function Room:drawToken(tk, isDrag)
  local fx = B.dragFx(tk.d)
  local px, py = tk.d.px, tk.d.py
  local cx, cy = px + TS / 2, py + TS / 2
  -- ombre (grandit avec le lift au pickup)
  if fx.shadow then
    love.graphics.setColor(0, 0, 0, 0.34)
    love.graphics.rectangle("fill", px + 4, py + (-fx.dy) + 8, TS, TS, 8, 8)
  end
  love.graphics.push()
  love.graphics.translate(cx, cy + fx.dy)
  love.graphics.rotate(fx.rot or 0)
  love.graphics.scale(fx.scale or 1, fx.scale or 1)
  love.graphics.translate(-cx, -(cy))
  Widgets.panel(px, py, TS, TS, { r = 8, fill = c.stone800, border = isDrag and c.brassL or c.brass })
  -- gemme
  love.graphics.setColor(tk.col[1], tk.col[2], tk.col[3], 1)
  love.graphics.circle("fill", cx, cy, 20)
  love.graphics.setColor(1, 1, 1, 0.25)
  love.graphics.circle("fill", cx - 5, cy - 6, 6)
  love.graphics.pop()
  Draw.reset()
end

-- ── input drag ──────────────────────────────────────────────────────────────────────────────────────────
function Room:tokenAt(mx, my)
  for i = #self.tokens, 1, -1 do
    local tk = self.tokens[i]
    if mx >= tk.d.px and mx <= tk.d.px + TS and my >= tk.d.py and my <= tk.d.py + TS then return i end
  end
end

function Room:mousepressed(mx, my, button)
  self.mx, self.my = mx, my
  self.click = { x = mx, y = my }
  if button == 1 then
    local i = self:tokenAt(mx, my)
    if i then
      local tk = self.tokens[i]
      -- MÉMORISE l'origine (pour le SWAP / le retour) : son slot + sa position de repos
      self.dragFrom = { slot = tk.slot, x = tk.d.gx or tk.hx, y = tk.d.gy or tk.hy }
      -- libère le slot d'origine (il redevient disponible pour le snap)
      if tk.slot then self.slots[tk.slot].token = nil end
      tk.slot = nil
      self.dragging = i
      B.dragBegin(tk.d, mx, my, mx - tk.d.px, my - tk.d.py)
      SFX.play("pickup")
    end
  end
end

function Room:mousemoved(mx, my)
  self.mx, self.my = mx, my
  if self.dragging then B.dragMove(self.tokens[self.dragging].d, mx, my) end
end

function Room:mousereleased(mx, my)
  if not self.dragging then return end
  local i = self.dragging
  local tk = self.tokens[i]
  B.dragEnd(tk.d)
  -- socket le plus proche (OCCUPÉ OU LIBRE) dont le centre du jeton est dans la portée
  local cx, cy = tk.d.px + TS / 2, tk.d.py + TS / 2
  local best, bestD
  for si, s in ipairs(self.slots) do
    local dx, dy = (s.x + TS / 2) - cx, (s.y + TS / 2) - cy
    local dist = dx * dx + dy * dy
    if dist < (TS * TS) and (not bestD or dist < bestD) then best, bestD = si, dist end
  end
  local from = self.dragFrom or { slot = nil, x = tk.hx, y = tk.hy }
  if best then
    local s = self.slots[best]
    local occ = s.token                    -- index du jeton déjà là (ou nil)
    if occ and occ ~= i then
      -- ⇄ SWAP : l'occupant retourne à l'ORIGINE du jeton déplacé (ressort), le déplacé prend le socket
      local b = self.tokens[occ]
      b.slot = from.slot
      b.d.gx, b.d.gy = from.x, from.y       -- l'occupant glisse (ressort) vers l'origine du déplacé
      if from.slot then self.slots[from.slot].token = occ end
      SFX.play("drop"); Juice.addTrauma(0.12)
    else
      SFX.play("drop"); Juice.addTrauma(0.08)
    end
    tk.slot = best; tk.d.gx, tk.d.gy = s.x, s.y
    s.token = i
  else
    -- hors portée : retour à l'origine (slot ou maison)
    tk.slot = from.slot
    tk.d.gx, tk.d.gy = from.x, from.y
    if from.slot then self.slots[from.slot].token = i end
    SFX.play("drop", { pitch = 0.9 })
  end
  self.dragging = nil
  self.dragFrom = nil
end

return Room
