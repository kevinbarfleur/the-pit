-- src/render/chronicle_draw.lua
-- LA CHRONIQUE — le PANNEAU (vue + interactions) : barre de filtres (type × équipe) + liste scrollable
-- d'entrées. Couche RENDER. Réutilisé tel quel par l'overlay (src/render/chronicle_overlay.lua).
--
-- Lisibilité par ÉQUIPE (spec §4.2) : GOUTTIÈRE = équipe de l'ACTEUR (or = joueur "left", sang = "right")
-- + NOMS colorés par équipe. Tout le CONTENU est en POLICE DE LECTURE (Theme.read / Pixel Operator) — jamais
-- de Silkscreen pour des infos (feedback user récurrent).

local Draw = require("src.ui.draw")
local Theme = require("src.ui.theme")
local Keywords = require("src.ui.keywords") -- couleurs d'affliction
local T = require("src.core.i18n").t

local CD = {}
CD.__index = CD

local ROW_H = 22
local KINDS = { "strike", "affliction", "spread", "shield", "death" }
local FLABEL = {
  strike = "chronicle.f.strike", affliction = "chronicle.f.affliction",
  spread = "chronicle.f.spread", shield = "chronicle.f.shield", death = "chronicle.f.death",
}
local TEAM_CYCLE = { [0] = nil, [1] = "left", [2] = "right" }
local TEAM_LABEL = { "chronicle.team.all", "chronicle.team.you", "chronicle.team.foe" }

local function ptIn(px, py, x, y, w, h) return px >= x and px <= x + w and py >= y and py <= y + h end

function CD.new(chronicle)
  return setmetatable({
    chron = chronicle,
    scroll = 0,
    fkinds = { strike = true, affliction = true, spread = true, shield = true, death = true },
    fstate = 0, -- index dans TEAM_CYCLE (0 = tout)
    _rect = nil, _frects = {}, _teamRect = nil,
  }, CD)
end

function CD:setChron(chron)
  self.chron = chron
  self.scroll = 0
end

function CD:teamFilter() return TEAM_CYCLE[self.fstate] end

local function teamColor(c, team)
  if team == "left" then return c.gold elseif team == "right" then return c.blood end
  return c.muted
end

function CD:_segColor(c, seg, e)
  if seg.role == "actor" or seg.role == "target" then return teamColor(c, seg.team) end
  if seg.role == "family" and e.family then
    local kw = Keywords.afflictions and Keywords.afflictions[e.family]
    return (kw and kw.color) or c.muted
  end
  return c.muted
end

local function drawPill(x, y, h, label, active, color, font)
  local pad = 7
  local w = pad * 2 + Draw.textWidth(label, font)
  Draw.rect(x, y, w, h, active and Theme.c.panelDeep or Theme.c.panel, active and color or Theme.c.line, 1)
  Draw.text(label, x + pad, y + math.floor((h - font:getHeight()) / 2 + 0.5), active and color or Theme.c.fainter, font)
  return w
end

function CD:draw(view, x, y, w, h)
  local c = Theme.c
  Draw.begin(view)
  Draw.rect(x, y, w, h, c.panel, c.line, 1)

  -- Barre de filtres : puces de TYPE (toggle) + sélecteur d'ÉQUIPE (cycle). Police de lecture, lisible.
  local ffont = Theme.read(12)
  local fh = ffont:getHeight() + 6
  local fx, fy = x + 8, y + 8
  self._frects = {}
  for _, k in ipairs(KINDS) do
    local kcol = (k == "affliction") and c.poison or (k == "death") and c.bloodBright or c.gold
    local fw = drawPill(fx, fy, fh, T(FLABEL[k]), self.fkinds[k], kcol, ffont)
    self._frects[k] = { x = fx, y = fy, w = fw, h = fh }
    fx = fx + fw + 4
  end
  local tlabel = T(TEAM_LABEL[self.fstate + 1])
  local tw = 14 + Draw.textWidth(tlabel, ffont)
  local tx = x + w - tw - 8
  Draw.rect(tx, fy, tw, fh, c.panelDeep, c.line, 1)
  Draw.text(tlabel, tx + 7, fy + math.floor((fh - ffont:getHeight()) / 2 + 0.5),
    self:teamFilter() and teamColor(c, self:teamFilter()) or c.muted, ffont)
  self._teamRect = { x = tx, y = fy, w = tw, h = fh }

  -- Liste scrollable (clip), ordonnée par tick.
  local listY = y + 8 + fh + 8
  local listH = h - (listY - y) - 8
  self._rect = { x = x, y = listY, w = w, h = listH }
  local entries = self.chron:visible(self.fkinds, self:teamFilter())
  local contentH = #entries * ROW_H
  local maxS = math.max(0, contentH - listH)
  self.scroll = math.max(0, math.min(maxS, self.scroll))

  Draw.scissor(view, x + 2, listY, w - 4, listH)
  local font = Theme.read(13)
  for i, e in ipairs(entries) do
    local ry = listY + (i - 1) * ROW_H - self.scroll
    if ry + ROW_H >= listY and ry <= listY + listH then self:_drawRow(c, font, e, x, ry, w) end
  end
  Draw.noScissor()

  if maxS > 0 then
    local thumbH = math.max(24, listH * listH / contentH)
    local ty = listY + (listH - thumbH) * (self.scroll / maxS)
    Draw.rect(x + w - 4, listY, 2, listH, c.panelDeep)
    Draw.rect(x + w - 4, ty, 2, thumbH, c.gold)
  end
  if #entries == 0 then Draw.text(T("chronicle.empty"), x + 12, listY + 8, c.fainter, font) end
  Draw.finish()
end

function CD:_drawRow(c, font, e, x, y, w)
  Draw.rect(x + 5, y + 3, 3, ROW_H - 6, teamColor(c, e.actorTeam)) -- gouttière = équipe de l'acteur
  local ty = y + math.floor((ROW_H - font:getHeight()) / 2 + 0.5)
  Draw.text(self.chron:timeStr(e), x + 12, ty, c.fainter, font)
  local cx = x + 12 + Draw.textWidth("00.0s ", font) + 4 -- colonne fixe après le timestamp
  for _, seg in ipairs(self.chron:segments(e)) do
    Draw.text(seg.text, cx, ty, self:_segColor(c, seg, e), font)
    cx = cx + Draw.textWidth(seg.text, font)
  end
  if e.kind == "affliction" and e.total and e.total > 0 then
    Draw.textR(tostring(e.total), x + w - 12, ty, c.dmg or c.bloodBright, font) -- total cumulé (rouge dégât)
  end
  local val = self.chron:value(e)
  if val then
    local vx = (e.kind == "affliction" and e.total and e.total > 0) and (x + w - 48) or (x + w - 12)
    Draw.textR(val, vx, ty, c.muted, font)
  end
end

function CD:wheelmoved(_, dy) self.scroll = self.scroll - (dy or 0) * ROW_H * 2 end

-- Renvoie true si le clic a été consommé (puce de filtre / sélecteur d'équipe).
function CD:mousepressed(vx, vy)
  for k, r in pairs(self._frects) do
    if ptIn(vx, vy, r.x, r.y, r.w, r.h) then self.fkinds[k] = not self.fkinds[k]; return true end
  end
  if self._teamRect and ptIn(vx, vy, self._teamRect.x, self._teamRect.y, self._teamRect.w, self._teamRect.h) then
    self.fstate = (self.fstate + 1) % 3
    return true
  end
  return false
end

return CD
