-- feel-lab/rooms/transitions.lua
-- GALERIE DE TRANSITIONS — joue, en PLEIN ÉCRAN, chaque technique entre deux maquettes (BUILD <-> COMBAT),
-- pour COMPARER les feelings (l'user veut plusieurs propositions). Réutilise lib/transition.lua localement
-- (preuve de réutilisabilité) : le sélecteur de technique est dessiné PAR-DESSUS la transition (persistant).

local Draw       = require("lib.draw")
local Theme      = require("lib.theme")
local Widgets    = require("lib.widgets")
local B          = require("lib.behavior")
local SFX        = require("lib.sfx")
local Transition = require("lib.transition")

local Room = {}
Room.__index = Room
local c = Theme.c
local W, H = 1280, 720

-- libellés lisibles + durée conseillée + une « saveur » par technique
local KINDS = {
  { id = "fade_black", name = "Fade through black", dur = 0.42, note = "Lourd, grimdark. Build -> Combat : on plonge dans le Puits." },
  { id = "crossfade",  name = "Crossfade",          dur = 0.34, note = "Doux. Menu <-> sous-menu." },
  { id = "dissolve",   name = "Dissolve (noise)",   dur = 0.55, note = "Organique, sale. Le front se dissout (shader)." },
  { id = "burn",       name = "Burn (ember edge)",  dur = 0.6,  note = "Le bord s'embrase. Reveal dramatique." },
  { id = "slide_left", name = "Slide ‹ left",       dur = 0.32, note = "Navigation spatiale : on avance d'un cran." },
  { id = "slide_right",name = "Slide › right",      dur = 0.32, note = "Le retour : on recule d'un cran." },
  { id = "slide_up",   name = "Slide ^ up",         dur = 0.32, note = "Pousse vers le haut." },
  { id = "iris_in",    name = "Iris (circle)",      dur = 0.5,  note = "Focus rétro, se ferme au centre." },
  { id = "pixelate",   name = "Pixelate / mosaic",  dur = 0.5,  note = "Se désintègre en gros pixels (shader)." },
}

function Room.new(app)
  local self = setmetatable({ app = app, mx = -1, my = -1, click = nil, t = 0 }, Room)
  self.tr = Transition.new()
  self.scene = "build"          -- maquette courante
  self.sel = 1                  -- technique sélectionnée
  self.dur = KINDS[1].dur
  return self
end

function Room:enter() self.title = "Scene Transitions" end
function Room:update(dt) self.t = self.t + (dt or 0); self.tr:update(dt) end

function Room:input(r)
  return { over = B.hit(r, self.mx, self.my), down = false,
           clicked = self.click and B.hit(r, self.click.x, self.click.y) or false }
end

-- ── maquettes de scène (le CONTENU qui transitionne ; PAS le sélecteur) ─────────────────────────────────
function Room:drawScene(view, which)
  Draw.begin(view)
  if which == "build" then
    -- fond pierre + plateau 3×3 + rangée boutique
    Draw.rect(0, 0, W, H, c.stone900)
    Draw.textTrackedC("THE BUILD", W / 2, 70, c.ink, Theme.title(34), 4)
    local gs, gp = 120, 16
    local gx = W / 2 - (gs * 3 + gp * 2) / 2
    local gy = 170
    for r = 0, 2 do for col = 0, 2 do
      local x, y = gx + col * (gs + gp), gy + r * (gs + gp)
      Widgets.panel(x, y, gs, gs, { fill = c.stone800, border = c.brassD })
      if (r + col) % 2 == 0 then
        love.graphics.setColor(c.blood[1], c.blood[2], c.blood[3], 0.7)
        love.graphics.circle("fill", x + gs / 2, y + gs / 2, 26)
        love.graphics.setColor(c.bloodL[1], c.bloodL[2], c.bloodL[3], 1)
        love.graphics.circle("line", x + gs / 2, y + gs / 2, 26)
      end
    end end
    -- boutique
    local sw, sh2 = 150, 90
    local sx = W / 2 - (sw * 4 + 18 * 3) / 2
    for i = 0, 3 do
      Widgets.panel(sx + i * (sw + 18), H - 150, sw, sh2, { fill = c.stone850, border = c.brass })
    end
    Draw.textTrackedC("24 GOLD", W / 2, H - 200, c.gold, Theme.label(16), 2)
  else
    -- maquette combat : deux camps + barres de vie
    Draw.rect(0, 0, W, H, c.bgEmber)
    Draw.rect(0, 0, W, H, { c.blood[1], c.blood[2], c.blood[3], 0.06 })
    Draw.textTrackedC("THE COMBAT", W / 2, 70, c.bloodL, Theme.title(34), 4)
    for side = 0, 1 do
      local baseX = side == 0 and 220 or W - 220 - 3 * 110
      local col = side == 0 and c.regen or c.blood
      for i = 0, 2 do
        local x = baseX + i * 110
        local y = 280 + (i % 2) * 70
        love.graphics.setColor(c.stone800[1], c.stone800[2], c.stone800[3], 1)
        love.graphics.circle("fill", x, y, 40)
        love.graphics.setColor(col[1], col[2], col[3], 1)
        love.graphics.circle("line", x, y, 40)
        Draw.bar(x - 36, y + 50, 72, 8, 0.4 + 0.5 * ((i + side) % 2), col, c.stone900, c.iron)
      end
    end
    Draw.textTrackedC("VS", W / 2, H / 2 - 30, c.gold, Theme.display(60), 4)
  end
  Draw.finish()
end

-- ── sélecteur (panneau persistant, par-dessus la transition) ────────────────────────────────────────────
function Room:drawSelector(view)
  Draw.begin(view)
  local px, py, pw = 28, 96, 360
  Widgets.panel(px, py, pw, H - 96 - 60, { fill = { c.stone850[1], c.stone850[2], c.stone850[3], 0.92 }, border = c.brass })
  Draw.textTrackedL("TECHNIQUE", px + 20, py + 16, c.gold, Theme.title(15), 2)
  local by = py + 50
  for i, k in ipairs(KINDS) do
    local r = { x = px + 14, y = by + (i - 1) * 44, w = pw - 28, h = 38 }
    local selected = (i == self.sel)
    Widgets.button("tr_" .. k.id, r, {
      label = k.name, tone = selected and "cta" or "ghost", font = Theme.label(14),
      onClick = function() self.sel = i; self.dur = k.dur end,
    }, self:input(r))
  end
  -- note + bouton PLAY + durée
  local k = KINDS[self.sel]
  local ny = by + #KINDS * 44 + 12
  Draw.textWrap(k.note, px + 16, ny, pw - 32, c.ink3, Theme.flavor(13), "left")

  -- contrôle durée (− / valeur / +)
  local dy = H - 60 - 64
  Draw.textTrackedL("DURATION", px + 16, dy - 20, c.ink4, Theme.label(11), 2)
  local mR = { x = px + 16, y = dy, w = 38, h = 38 }
  local pR = { x = px + 16 + 120, y = dy, w = 38, h = 38 }
  Widgets.button("tr_dmin", mR, { label = "−", tone = "default", onClick = function() self.dur = math.max(0.12, self.dur - 0.04) end }, self:input(mR))
  Widgets.button("tr_dplus", pR, { label = "+", tone = "default", onClick = function() self.dur = math.min(1.2, self.dur + 0.04) end }, self:input(pR))
  Draw.textC(string.format("%.2fs", self.dur), px + 16 + 79, dy + 9, c.ink, Theme.label(16))

  -- PLAY
  local playR = { x = px + 16 + 180, y = dy, w = pw - 28 - 180, h = 38 }
  Widgets.button("tr_play", playR, { label = "Play", tone = "cta", font = Theme.title(15), onClick = function() self:play() end }, self:input(playR))

  Draw.finish()
end

function Room:play()
  if self.tr.active or not self.view then return end
  local k = KINDS[self.sel]
  SFX.play("whoosh")
  local cur = self.scene
  self.tr:start(k.id, self.dur, function() self:drawScene(self.view, cur) end)
  self.scene = (self.scene == "build") and "combat" or "build"
end

function Room:draw(view)
  self.view = view
  -- 1) la scène (ou la transition entre deux scènes)
  if self.tr.active then
    self.tr:draw(function() self:drawScene(view, self.scene) end)
  else
    self:drawScene(view, self.scene)
  end
  -- 2) le sélecteur, TOUJOURS par-dessus (persistant)
  self:drawSelector(view)
  self.click = nil
end

function Room:mousemoved(mx, my) self.mx, self.my = mx, my end
function Room:mousepressed(mx, my) self.mx, self.my = mx, my; self.click = { x = mx, y = my } end

return Room
