-- feel-lab/lib/modals.lua
-- FABRIQUE de MODALES réutilisables (objets pour ModalStack). Toutes partagent la MÊME chorégraphie d'entrée
-- (panel scale 0.94->1 + fade, courbe back) et le MÊME enrobage -> fin de l'incohérence « chaque pop-up est
-- un programme différent ». Démontre aussi des composants réutilisables (boutons internes via Widgets).
--
-- Types : Modals.confirm{...} · Modals.banner{...} (victory/defeat) · Modals.tooltipDemo (showcase).
-- Chaque modal lit `a ∈ [0,1]` (fourni par la pile) pour son scale/alpha/slide d'entrée.

local Draw    = require("lib.draw")
local Theme   = require("lib.theme")
local Feel    = require("lib.feel")
local Widgets = require("lib.widgets")
local B       = require("lib.behavior")
local SFX     = require("lib.sfx")

local Modals = {}
local c = Theme.c
local W, H = 1280, 720

-- courbe « back » (overshoot) pour l'entrée des panneaux
local function backEase(a)
  local s = 1.70158
  local p = a - 1
  return 1 + (s + 1) * p * p * p + s * p * p
end

-- base commune : gère une liste de boutons (rect + action), hover via mx,my, clic via Feel.press (juice+son).
local function newBase()
  return {
    mx = -1, my = -1, btns = {}, dim = 0.62,
    addBtn = function(self, id, r, onClick, tone, label, opts)
      self.btns[#self.btns + 1] = { id = id, r = r, onClick = onClick, tone = tone, label = label, opts = opts or {} }
    end,
    drawBtns = function(self)
      for _, b in ipairs(self.btns) do
        local over = B.hit(b.r, self.mx, self.my)
        Widgets.button(b.id, b.r, { label = b.label, tone = b.tone, onClick = b.onClick,
          font = b.opts.font or Theme.title(15), delay = 0.05 }, { over = over, down = false, clicked = false })
      end
    end,
    mousemoved = function(self, mx, my) self.mx, self.my = mx, my end,
    mousepressed = function(self, mx, my)
      for _, b in ipairs(self.btns) do
        if B.hit(b.r, mx, my) then
          -- press juice + son + action différée (le clic se SENT avant que la modale parte)
          Feel.press(b.id, b.onClick, { delay = 0.10 })
          return
        end
      end
    end,
  }
end

-- panneau centré animé : applique scale/alpha/slide depuis `a`, exécute body(ix,iy,iw,ih) à l'intérieur.
local function drawPanel(a, w, h, body, opts)
  opts = opts or {}
  local sc = 0.94 + 0.06 * backEase(math.min(1, a))
  local alpha = math.min(1, a * 1.4)
  local cx, cy = W / 2, H / 2 - (1 - a) * 18   -- léger slide-up à l'entrée
  love.graphics.push()
  love.graphics.translate(cx, cy)
  love.graphics.scale(sc, sc)
  love.graphics.translate(-w / 2, -h / 2)
  -- ombre portée
  love.graphics.setColor(0, 0, 0, 0.45 * alpha)
  love.graphics.rectangle("fill", -8, 6, w + 16, h + 12, 12, 12)
  -- panneau
  love.graphics.setColor(c.stone850[1], c.stone850[2], c.stone850[3], alpha)
  love.graphics.rectangle("fill", 0, 0, w, h, 10, 10)
  love.graphics.setColor((opts.accent or c.brass)[1], (opts.accent or c.brass)[2], (opts.accent or c.brass)[3], alpha)
  love.graphics.setLineWidth(2.5); love.graphics.rectangle("line", 0, 0, w, h, 10, 10); love.graphics.setLineWidth(1)
  -- éclat de bord
  love.graphics.setColor(c.brassL[1], c.brassL[2], c.brassL[3], 0.2 * alpha)
  love.graphics.rectangle("fill", 4, 3, w - 8, 1)
  if body then body(0, 0, w, h, alpha) end
  love.graphics.pop()
  Draw.reset()
  return cx, cy, sc, w, h
end

-- ── CONFIRM : titre + corps + 2 boutons (annuler / confirmer[danger]) ─────────────────────────────────────
function Modals.confirm(o)
  o = o or {}
  local m = newBase()
  m.dim = 0.62
  local w, h = 460, 230
  function m:onEnter() SFX.play("whoosh") end
  function m:draw(view, a)
    Draw.begin(view)
    self.btns = {}
    drawPanel(a, w, h, function(_, _, pw, _)
      local cx = pw / 2
      Draw.textTrackedC((o.title or "ARE YOU SURE?"):upper(), cx, 30, c.ink, Theme.title(22), 2)
      Draw.divider(cx, 64, pw * 0.7, o.danger and c.blood or c.brass, 0.7)
      Draw.textWrap(o.body or "", 28, 84, pw - 56, c.ink2, Theme.body(14), "center")
      -- boutons (positions ABSOLUES en design : on les recadre depuis le centre du panneau)
      local bw, bh, gap = 170, 46, 24
      local bx = W / 2 - bw - gap / 2
      local by = H / 2 + h / 2 - bh - 26
      self:addBtn("modal_cancel", { x = bx, y = by, w = bw, h = bh }, function()
        if o.onCancel then o.onCancel() end
      end, "default", o.cancelLabel or "Go back")
      self:addBtn("modal_ok", { x = bx + bw + gap, y = by, w = bw, h = bh }, function()
        if o.onConfirm then o.onConfirm() end
      end, o.danger and "cta" or "eco", o.confirmLabel or "Confirm")
    end, { accent = o.danger and c.blood or c.brass })
    self:drawBtns()
    Draw.finish()
  end
  return m
end

-- ── BANNER : grand mot du destin (VICTORY / DEFEAT), cérémonial + 1 bouton continuer ──────────────────────
function Modals.banner(o)
  o = o or {}
  local victory = (o.kind or "victory") == "victory"
  local m = newBase()
  m.dim = 0.7
  local w, h = 620, 300
  function m:onEnter() SFX.play(victory and "success" or "defeat"); if victory then SFX.ladder(true) end end
  m._t = 0
  function m:update(dt) self._t = (self._t or 0) + (dt or 0) end
  function m:draw(view, a)
    Draw.begin(view)
    self.btns = {}
    local accent = victory and c.gold or c.blood
    drawPanel(a, w, h, function(_, _, pw, _)
      local cx = pw / 2
      Draw.textTrackedC(victory and "VICTORY" or "DEFEAT", cx, 46, accent, Theme.display(66), 2)
      Draw.divider(cx, 132, pw * 0.6, accent, 0.8)
      Draw.textWrap(o.flavor or (victory and "The Pit yields. For now." or "The dark drinks deep."),
        40, 150, pw - 80, c.ink2, Theme.flavor(16), "center")
      local bw, bh = 220, 50
      local bx, by = W / 2 - bw / 2, H / 2 + h / 2 - bh - 28
      self:addBtn("banner_ok", { x = bx, y = by, w = bw, h = bh }, function()
        if o.onClose then o.onClose() end
      end, victory and "cta" or "default", o.button or "Continue")
    end, { accent = accent })
    self:drawBtns()
    Draw.finish()
  end
  return m
end

-- ── TOAST (non-bloquant) : objet léger géré par main (PAS la pile modale ; ne gèle/capte rien) ────────────
-- renvoie { text, kind, t (vie restante), life } ; main le dessine et l'expire.
function Modals.toast(text, kind)
  return { text = text, kind = kind or "info", t = 2.6, life = 2.6 }
end

-- dessine une pile de toasts en bas (appelé par main). list = array de toasts.
function Modals.drawToasts(view, list)
  if not list or #list == 0 then return end
  Draw.begin(view)
  local y = H - 90
  for i = #list, 1, -1 do
    local t = list[i]
    -- t.t décompte de life -> 0 : fade-in sur les 200 premiers ms, fade-out sur les 300 derniers
    local a = 1
    if t.t > t.life - 0.2 then a = (t.life - t.t) / 0.2 end
    if t.t < 0.3 then a = t.t / 0.3 end
    a = math.max(0, math.min(1, a))
    local col = t.kind == "good" and c.regen or t.kind == "bad" and c.blood or c.gold
    local tw = Draw.textWidth(t.text, Theme.label(14)) + 44
    local x = W / 2 - tw / 2
    love.graphics.setColor(c.stone850[1], c.stone850[2], c.stone850[3], 0.92 * a)
    love.graphics.rectangle("fill", x, y, tw, 36, 8, 8)
    love.graphics.setColor(col[1], col[2], col[3], a)
    love.graphics.setLineWidth(2); love.graphics.rectangle("line", x, y, tw, 36, 8, 8); love.graphics.setLineWidth(1)
    Draw.textC(t.text, W / 2, y + 9, col, Theme.label(14))
    y = y - 46
  end
  Draw.reset()
  Draw.finish()
end

return Modals
