-- src/render/chronicle_draw.lua
-- LA CHRONIQUE — le PANNEAU (vue + interactions). Prend un modèle `Chronicle` (src/render/chronicle.lua)
-- et l'affiche : barre de filtres (type × équipe) + liste scrollable d'entrées. Couche RENDER pure.
--
-- Lisibilité par ÉQUIPE (décision spec §4.2) : GOUTTIÈRE colorée = équipe de l'ACTEUR (or = joueur "left",
-- sang = "right") + NOMS colorés par équipe dans le texte. Un coup d'œil suffit à voir qui a initié quoi.

local Draw = require("src.ui.draw")
local Theme = require("src.ui.theme")
local Keywords = require("src.ui.keywords") -- couleurs d'affliction
local T = require("src.core.i18n").t

local CD = {}
CD.__index = CD

local ROW_H = 18
local KINDS = { "strike", "affliction", "spread", "shield", "death" } -- ordre des puces de filtre
local FLABEL = {
  strike = "chronicle.f.strike", affliction = "chronicle.f.affliction",
  spread = "chronicle.f.spread", shield = "chronicle.f.shield", death = "chronicle.f.death",
}
local TEAM_CYCLE = { [0] = nil, [1] = "left", [2] = "right" } -- Tout -> Toi -> Adverse
local TEAM_LABEL = { "chronicle.team.all", "chronicle.team.you", "chronicle.team.foe" }

local function ptIn(px, py, x, y, w, h) return px >= x and px <= x + w and py >= y and py <= y + h end

function CD.new(chronicle)
  return setmetatable({
    chron = chronicle,
    scroll = 0,
    fkinds = { strike = true, affliction = true, spread = true, shield = true, death = true },
    fstate = 0, -- index dans TEAM_CYCLE (0 = tout)
    _rect = nil, -- zone de liste (mémorisée au draw pour le hit-test molette/clic)
    _frects = {}, -- hit-rects des puces de filtre
    _teamRect = nil,
  }, CD)
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

-- Une puce de filtre (style onglet du Grimoire) ; renvoie sa largeur.
local function drawPill(x, y, label, active, color, font)
  local pad = 6
  local w = pad * 2 + Draw.textWidth(label, font)
  Draw.rect(x, y, w, 15, active and Theme.c.panelDeep or Theme.c.panel, active and color or Theme.c.line, 1)
  Draw.text(label, x + pad, y + 2, active and color or Theme.c.fainter, font)
  return w
end

function CD:draw(view, x, y, w, h)
  local c = Theme.c
  Draw.begin(view)
  Draw.rect(x, y, w, h, c.panel, c.line, 1)
  Draw.text(T("chronicle.title"), x + 10, y + 8, c.title, Theme.uiBold(13))

  -- Barre de filtres : puces de TYPE (toggle) + sélecteur d'ÉQUIPE (cycle), avec compteurs.
  local ffont = Theme.ui(9)
  local fx, fy = x + 10, y + 28
  self._frects = {}
  for _, k in ipairs(KINDS) do
    local kwcol = (k == "affliction") and c.poison or (k == "death") and c.bloodBright or c.gold
    local fw = drawPill(fx, fy, T(FLABEL[k]), self.fkinds[k], kwcol, ffont)
    self._frects[k] = { x = fx, y = fy, w = fw, h = 15 }
    fx = fx + fw + 4
  end
  -- sélecteur d'équipe (aligné à droite de l'en-tête)
  local tlabel = T(TEAM_LABEL[self.fstate + 1])
  local tw = 12 + Draw.textWidth(tlabel, ffont)
  local tx = x + w - tw - 10
  Draw.rect(tx, fy, tw, 15, c.panelDeep, c.line, 1)
  Draw.text(tlabel, tx + 6, fy + 2, self:teamFilter() and teamColor(c, self:teamFilter()) or c.muted, ffont)
  self._teamRect = { x = tx, y = fy, w = tw, h = 15 }

  -- Liste scrollable (clip), ordonnée par tick.
  local listY = y + 50
  local listH = h - 50 - 8
  self._rect = { x = x, y = listY, w = w, h = listH }
  local entries = self.chron:visible(self.fkinds, self:teamFilter())
  local contentH = #entries * ROW_H
  local maxS = math.max(0, contentH - listH)
  if self.scroll > maxS then self.scroll = maxS end
  if self.scroll < 0 then self.scroll = 0 end

  Draw.scissor(view, x + 2, listY, w - 4, listH)
  local font = Theme.read(11)
  for i, e in ipairs(entries) do
    local ry = listY + (i - 1) * ROW_H - self.scroll
    if ry + ROW_H >= listY and ry <= listY + listH then self:_drawRow(c, font, e, x, ry, w) end
  end
  Draw.noScissor()

  -- Scrollbar (si débordement) — pattern Grimoire.
  if maxS > 0 then
    local thumbH = math.max(20, listH * listH / contentH)
    local ty = listY + (listH - thumbH) * (self.scroll / maxS)
    Draw.rect(x + w - 4, listY, 2, listH, c.panelDeep)
    Draw.rect(x + w - 4, ty, 2, thumbH, c.gold)
  end

  -- Vide : un mot d'ambiance.
  if #entries == 0 then
    Draw.text(T("chronicle.empty"), x + 12, listY + 8, c.fainter, font)
  end
  Draw.finish()
end

function CD:_drawRow(c, font, e, x, y, w)
  -- gouttière = équipe de l'acteur (qui a initié) ; pour une mort, l'équipe du défunt.
  Draw.rect(x + 5, y + 2, 3, ROW_H - 4, teamColor(c, e.actorTeam))
  Draw.text(self.chron:timeStr(e), x + 12, y + 4, c.fainter, font)
  local cx = x + 12 + 34
  for _, seg in ipairs(self.chron:segments(e)) do
    Draw.text(seg.text, cx, y + 4, self:_segColor(c, seg, e), font)
    cx = cx + Draw.textWidth(seg.text, font)
  end
  -- valeur à droite ; pour une affliction, le TOTAL cumulé des ticks en accent dégât (rouge = ce que ça a coûté).
  if e.kind == "affliction" and e.total and e.total > 0 then
    Draw.textR(tostring(e.total), x + w - 10, y + 4, c.dmg or c.bloodBright, font)
  end
  local val = self.chron:value(e)
  if val then
    local vx = (e.kind == "affliction" and e.total and e.total > 0) and (x + w - 44) or (x + w - 10)
    Draw.textR(val, vx, y + 4, c.muted, font)
  end
end

function CD:wheelmoved(_, dy)
  self.scroll = self.scroll - (dy or 0) * ROW_H * 2
  -- (le clamp final est appliqué au prochain draw, qui connaît la hauteur de contenu)
end

-- Renvoie true si le clic a été consommé par le panneau (filtre/équipe).
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
