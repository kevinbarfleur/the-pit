-- src/render/chronicle_draw.lua
-- LA CHRONIQUE — le PANNEAU (vue + interactions) : plaque forge + barre de filtres (type × équipe, en chips
-- forge) + liste scrollable d'entrées HIÉRARCHISÉES par impact. Couche RENDER. Réutilisé tel quel par
-- l'overlay (src/render/chronicle_overlay.lua).
--
-- HIÉRARCHIE D'IMPACT (le poids vient de la HAUTEUR/FOND/GOUTTIÈRE/INDENTATION, jamais d'une police gothique) :
--   MORT        : bloc 32px qui RESSORT (cadre Frame gilded sang + fond voilé + crâne) -> on LIT qui meurt.
--   COUP        : ligne 22px, gouttière d'équipe, zébrure 1/2, montant en rouge dégât.
--   BOUCLIER    : ligne 22px, icône bouclier, valeur en bleu bouclier.
--   AFFLICTION  : ligne 22px (racine) OU 20px INDENTÉE (conséquence d'un coup / propagation), chevron + famille.
--   SÉPARATEUR  : entre deux secondes entières, un filet forge + le timestamp « ◆ 3.0s ◆ ».
-- Tout le CONTENU est en POLICE DE LECTURE (Theme.read / Pixel Operator) — jamais de Silkscreen pour des infos.

local Draw = require("src.ui.draw")
local Theme = require("src.ui.theme")
local Frame = require("src.ui.frame")       -- cadre runique gildé (bloc MORT)
local Keywords = require("src.ui.keywords") -- couleurs + icônes d'affliction
local Chip = require("src.ui.chip")         -- chips de filtre (liseré famille)
local Forge = require("src.ui.forge")       -- plaque + diamant de séparateur
local MiniRig = require("src.render.minirig") -- frimousse figée préfixant chaque nom de monstre (J3)
local T = require("src.core.i18n").t

local CD = {}
CD.__index = CD

-- Hauteurs par rôle (le RANG visuel) : la mort domine, la conséquence s'efface.
local H_DEATH   = 32
local H_ROW     = 22 -- coup / bouclier / affliction racine
local H_CAUSED  = 20 -- conséquence indentée / propagation
local INDENT    = 22 -- décalage des conséquences (sous leur cause)
-- Frimousse (mini-rig figé) devant chaque nom : carrée, ≈ hauteur de la police du nom, avec une gouttière.
local MINI_ROW   = 16 -- boîte sur une ligne 22px (≈ police de lecture 13)
local MINI_CAUSE = 14 -- boîte sur une conséquence 20px (police 12)
local MINI_DEATH = 22 -- boîte sur le bloc MORT 32px (gros, du poids visuel)
local MINI_GAP   = 3  -- gouttière entre la frimousse et le nom

local KINDS = { "strike", "affliction", "spread", "shield", "death" }
local FLABEL = {
  strike = "chronicle.f.strike", affliction = "chronicle.f.affliction",
  spread = "chronicle.f.spread", shield = "chronicle.f.shield", death = "chronicle.f.death",
}
-- Les puces de filtre sont des CATÉGORIES (pas des familles précises) : pas d'icône (elle induirait en erreur,
-- ex. « Afflict » couvre poison/bleed/burn/rot). On lit la catégorie par son LISERÉ coloré + son label.
local FCOLOR = function(c, k)
  return (k == "affliction") and c.poison or (k == "spread") and c.rot
    or (k == "shield") and c.shield or (k == "death") and c.bloodBright or c.gold
end
local TEAM_CYCLE = { [0] = nil, [1] = "left", [2] = "right" }
local TEAM_LABEL = { "chronicle.team.all", "chronicle.team.you", "chronicle.team.foe" }

local function ptIn(px, py, x, y, w, h) return px >= x and px <= x + w and py >= y and py <= y + h end

function CD.new(chronicle)
  return setmetatable({
    chron = chronicle,
    scroll = 0,
    fkinds = { strike = true, affliction = true, spread = true, shield = true, death = true },
    fstate = 0, -- index dans TEAM_CYCLE (0 = tout)
    t = 0,      -- horloge d'animation (pour la plaque forge qui respire), avancée par :update
    _rect = nil, _frects = {}, _teamRect = nil, _id = tostring(chronicle), -- id stable de cache forge
  }, CD)
end

function CD:setChron(chron)
  self.chron = chron
  self.scroll = 0
  self._id = tostring(chron) -- nouvel id de cache (plaque/widgets) par chronique
end

function CD:teamFilter() return TEAM_CYCLE[self.fstate] end
-- Avance l'horloge d'animation (plaque forge). Appelé par l'overlay/scène ; sans danger si jamais appelé.
function CD:update(dt) self.t = self.t + (dt or 0) end

local function teamColor(c, team)
  if team == "left" then return c.gold elseif team == "right" then return c.blood end
  return c.muted
end

-- Couleur d'un fragment de texte (acteur/cible = équipe ; famille = couleur d'affliction ; op = atténué).
function CD:_segColor(c, seg, e)
  if seg.role == "actor" or seg.role == "target" then return teamColor(c, seg.team) end
  if seg.role == "family" and e.family then
    local kw = Keywords.afflictions and Keywords.afflictions[e.family]
    return (kw and kw.color) or c.muted
  end
  return c.muted
end

-- Hauteur d'une entrée selon son rang d'impact (utilisé pour la mise en page de la liste).
local function rowHeight(e)
  if e.kind == "death" then return H_DEATH end
  if (e.kind == "affliction" and e.caused) or e.kind == "spread" then return H_CAUSED end
  return H_ROW
end

function CD:draw(view, x, y, w, h)
  local c = Theme.c
  self._view = view          -- mémorise la vue : les lignes clippent leur frimousse (Draw.scissor) avec (J3)
  self._nameRects = {}       -- rects {x,y,w,h,id} des NOMS dessinés cette frame -> survol = carte (J4)
  Draw.begin(view)
  -- la plaque forge RESPIRE : on avance une horloge locale à chaque frame de rendu (cosmétique, RENDER pur ;
  -- l'overlay modal n'a pas de boucle update -> on pilote l'animation ici, pas de couplage au host).
  self.t = self.t + 1 / 60
  Forge.uiCard("chron.panel." .. self._id, x, y, w, h, { seed = 137, t = self.t })

  -- Barre de filtres : chips de TYPE (toggle) + sélecteur d'ÉQUIPE (cycle). Police de lecture, lisible.
  local ffont = Theme.read(12)
  local fh = 18
  local fx, fy = x + 8, y + 8
  self._frects = {}
  for _, k in ipairs(KINDS) do
    local active = self.fkinds[k]
    local col = FCOLOR(c, k)
    local fw = Chip.draw(fx, fy, {
      icon = false, label = T(FLABEL[k]),
      color = active and col or c.fainter, font = ffont, h = fh,
    })
    self._frects[k] = { x = fx, y = fy, w = fw, h = fh }
    fx = fx + fw + 5
  end
  -- Sélecteur d'équipe : petite plaque de valeur (reste un cycle, pas un chip de famille).
  local tlabel = T(TEAM_LABEL[self.fstate + 1])
  local tcol = self:teamFilter() and teamColor(c, self:teamFilter()) or c.muted
  local tw = 14 + Draw.textWidth(tlabel, ffont)
  local tx = x + w - tw - 8
  Draw.rect(tx, fy, tw, fh, c.panelDeep, tcol, 1)
  Draw.text(tlabel, tx + 7, fy + math.floor((fh - ffont:getHeight()) / 2 + 0.5), tcol, ffont)
  self._teamRect = { x = tx, y = fy, w = tw, h = fh }

  -- Liste scrollable (clip), ordonnée par tick. Hauteurs VARIABLES (la mort prend plus de place).
  local listY = y + 8 + fh + 8
  local listH = h - (listY - y) - 8
  self._rect = { x = x, y = listY, w = w, h = listH }
  local entries = self.chron:visible(self.fkinds, self:teamFilter())
  -- offsets cumulés (hauteurs variables) + séparateurs de bloc temporel insérés AVANT chaque nouvelle seconde.
  local layout, contentH = self:_layout(entries)
  local maxS = math.max(0, contentH - listH)
  self.scroll = math.max(0, math.min(maxS, self.scroll))

  Draw.scissor(view, x + 2, listY, w - 4, listH)
  local font = Theme.read(13)
  for _, it in ipairs(layout) do
    local ry = listY + it.y - self.scroll
    if ry + it.h >= listY and ry <= listY + listH then
      if it.sep then
        self:_drawSeparator(c, it.tick, x, ry, w)
      else
        self:_drawRow(c, font, it.e, x, ry, w)
      end
    end
  end
  Draw.noScissor()

  if maxS > 0 then
    local thumbH = math.max(24, listH * listH / contentH)
    local ty = listY + (listH - thumbH) * (self.scroll / maxS)
    Draw.rect(x + w - 4, listY, 2, listH, c.panelDeep)
    Draw.rect(x + w - 4, ty, 2, thumbH, c.gold)
  end
  if #entries == 0 then Draw.text(T("chronicle.empty"), x + 12, listY + 8, c.fainter, font) end

  -- HOVER (J4) : on résout le nom survolé MAINTENANT (les _nameRects de cette frame sont à jour) -> l'appelant
  -- (overlay) lit hoveredName() et dessine la carte PAR-DESSUS, hors clip. Pas de carte dessinée ici (elle
  -- déborde volontairement du panneau -> l'overlay s'en charge au niveau supérieur).
  self._hoverId, self._hoverRect = self:_hitName()

  Draw.finish()
end

-- Calcule la pile (y cumulés + hauteurs) ; insère un SÉPARATEUR (14px) à chaque passage de seconde entière.
-- Renvoie (layout = liste de { y, h, e? , sep?, tick? }, contentH).
function CD:_layout(entries)
  local layout, yy, lastSec = {}, 0, nil
  for _, e in ipairs(entries) do
    local sec = math.floor((e.tick or 0) / 60)
    if lastSec ~= nil and sec ~= lastSec then
      layout[#layout + 1] = { y = yy, h = 14, sep = true, tick = e.tick }
      yy = yy + 14
    end
    lastSec = sec
    local hgt = rowHeight(e)
    layout[#layout + 1] = { y = yy, h = hgt, e = e }
    yy = yy + hgt
  end
  return layout, yy
end

-- Séparateur de bloc temporel : deux demi-filets en dégradé + diamants forge + timestamp « ◆ 3.0s ◆ ».
function CD:_drawSeparator(c, tick, x, y, w)
  local sfont = Theme.read(11)
  local label = string.format("%.1fs", (tick or 0) / 60)
  local cx = x + w / 2
  local my = y + 7
  local lw = Draw.textWidth(label, sfont)
  -- deux demi-filets de part et d'autre du label (le label respire au centre).
  Draw.divider(x + (w * 0.27), my, w * 0.40, c.hair, 0.8)
  Draw.divider(x + w - (w * 0.27), my, w * 0.40, c.hair, 0.8)
  Forge.diamondAt(cx - lw / 2 - 8, my, 2, c.gold, c.line)
  Forge.diamondAt(cx + lw / 2 + 8, my, 2, c.gold, c.line)
  Draw.textC(label, cx, my - sfont:getHeight() / 2, c.faint, sfont)
end

-- Pose l'icône d'affliction d'une famille à (x, midY) et renvoie la largeur consommée (icône + 2px), ou 0.
local function drawFamilyIcon(family, x, midY)
  local ic = family and Keywords.icon(family)
  if not ic then return 0 end
  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.draw(ic.image, math.floor(x), math.floor(midY - ic.h / 2), 0, 1, 1)
  return ic.w + 2
end

-- id du monstre porté par un fragment de NOM : le segment n'a pas d'id -> on mappe par rôle
-- (actor -> e.actorId, target -> e.targetId). Renvoie nil pour les autres rôles (op/family).
local function idForSeg(seg, e)
  if seg.role == "actor" then return e.actorId end
  if seg.role == "target" then return e.targetId end
  return nil
end

-- Dessine la FRIMOUSSE (mini-rig figé) de `id` calée à gauche du nom, centrée sur midY, et renvoie la
-- largeur consommée (boîte + gouttière), ou 0 si pas d'id. `box` = côté carré ; `team` oriente la frimousse
-- (toi/"left" regarde à DROITE +1 ; ennemi/"right" regarde à GAUCHE -1) -> lecture « face-à-face » du combat.
function CD:_mini(id, cx, midY, box, team)
  if not id then return 0 end
  local facing = (team == "right") and -1 or 1
  MiniRig.draw(self._view, id, nil, cx, math.floor(midY - box / 2 + 0.5), box, box, facing)
  return box + MINI_GAP
end

function CD:_drawRow(c, font, e, x, y, w)
  if e.kind == "death" then return self:_drawDeath(c, e, x, y, w) end

  local caused = (e.kind == "affliction" and e.caused) or e.kind == "spread"
  local rh = caused and H_CAUSED or H_ROW
  local indent = caused and INDENT or 0
  local rfont = caused and Theme.read(12) or font
  local midY = y + rh / 2

  -- ZÉBRURE (coup uniquement, 1 ligne sur 2) : bande sombre derrière le texte -> lecture en damier.
  if e.kind == "strike" and (math.floor((e.tick or 0)) % 2 == 0) then
    Draw.rect(x + 4, y + 1, w - 8, rh - 2, { c.panelDeep[1], c.panelDeep[2], c.panelDeep[3], 0.25 })
  end

  -- GOUTTIÈRE = équipe de l'acteur (or = toi, sang = ennemi). Estompée pour les conséquences.
  local gcol = teamColor(c, e.actorTeam)
  Draw.rect(x + 5 + indent, y + 3, caused and 2 or 3, rh - 6,
    caused and { gcol[1], gcol[2], gcol[3], 0.4 } or gcol)

  local ty = y + math.floor((rh - rfont:getHeight()) / 2 + 0.5)
  local cx = x + 12 + indent

  -- CHEVRON « └▸ » des conséquences : DESSINÉ (coude + pointe), atténué, pour rattacher la conséquence à
  -- sa cause au-dessus (les glyphes Unicode ne sont pas garantis par la police pixel -> on trace au pixel).
  if caused then
    local gx, gy = cx, midY
    Draw.rect(gx, gy - 5, 2, 7, c.fainter)         -- montant vertical du coude (└)
    Draw.rect(gx, gy + 1, 7, 2, c.fainter)         -- base horizontale du coude
    -- pointe ▸ pleine (triangle vers la droite) : colonnes de hauteur décroissante.
    Draw.rect(gx + 8, gy - 3, 2, 8, c.fainter)
    Draw.rect(gx + 10, gy - 2, 2, 6, c.fainter)
    Draw.rect(gx + 12, gy - 1, 2, 4, c.fainter)
    Draw.rect(gx + 14, gy, 2, 2, c.fainter)
    cx = cx + 19
  end

  -- ICÔNE de famille (préfixe) pour affliction / spread / bouclier.
  if e.family then
    cx = cx + drawFamilyIcon(e.family, cx, midY)
  elseif e.kind == "shield" then
    cx = cx + self:_shieldIcon(c, cx, midY)
  end

  -- Texte = fragments (acteur coloré équipe / verbe atténué / cible / famille colorée). Chaque fragment de
  -- NOM (actor/target) est préfixé de la FRIMOUSSE du monstre (J3) et enregistre son rect pour le survol (J4).
  local mbox = caused and MINI_CAUSE or MINI_ROW
  for _, seg in ipairs(self.chron:segments(e)) do
    local id = idForSeg(seg, e)
    local nameX = cx
    if id then cx = cx + self:_mini(id, cx, midY, mbox, seg.team) end
    Draw.text(seg.text, cx, ty, self:_segColor(c, seg, e), rfont)
    local tw = Draw.textWidth(seg.text, rfont)
    if id then
      -- le rect couvre frimousse + nom (zone de survol naturelle) -> carte au survol du « bloc monstre ».
      self._nameRects[#self._nameRects + 1] = { x = nameX, y = y, w = (cx + tw) - nameX, h = rh, id = id }
    end
    cx = cx + tw
  end

  -- VALEURS à droite : total cumulé de dégât de l'affliction (nombre en rouge dégât, précédé d'un petit point
  -- DESSINÉ = « tant de sang déjà tiré ») + valeur courante (dps/charge/montant). Tout aligné à droite.
  local rx = x + w - 12
  if (e.kind == "affliction" or e.kind == "spread") and e.total and e.total > 0 then
    local tot = tostring(e.total)
    Draw.textR(tot, rx, ty, c.dmg or c.bloodBright, rfont)
    local totW = Draw.textWidth(tot, rfont)
    Draw.rect(rx - totW - 5, midY - 1, 2, 2, c.dmg or c.bloodBright) -- point-puce devant le total
    rx = rx - totW - 10
  end
  local val = self.chron:value(e)
  if val then
    local vcol = (e.kind == "strike" and (c.dmg or c.bloodBright))
      or (e.kind == "shield" and c.shield) or c.muted
    Draw.textR(val, rx, ty, vcol, rfont)
  end
end

-- BOUCLIER : petite icône forge ✚ (croix) en bleu bouclier (Keywords n'a pas de clé « shield »). Renvoie sa largeur.
function CD:_shieldIcon(c, x, midY)
  Draw.rect(x + 2, midY - 4, 2, 8, c.shield) -- montant vertical
  Draw.rect(x, midY - 1, 6, 2, c.shield)     -- barre horizontale
  return 6 + 3 -- 6px de croix + 3px de gouttière
end

-- MORT : bloc qui RESSORT. Cadre Frame gilded (accent sang) + fond sang voilé + crâne (diamant sang) +
-- nom en gras, et « par <icône famille> » si la dernière cause connue est une affliction.
function CD:_drawDeath(c, e, x, y, w)
  local bx, by, bw, bh = x + 4, y + 2, w - 8, H_DEATH - 4
  -- fond sang profond voilé (sous le cadre) -> le bloc « saigne » sans noyer le texte.
  Draw.rect(bx + 3, by + 3, bw - 6, bh - 6, { c.bloodDeep[1], c.bloodDeep[2], c.bloodDeep[3], 0.5 })
  -- cadre runique gildé, accent sang : c'est l'événement le plus lourd de la chronique.
  local ix, iy, iw, ih = Frame.draw(bx, by, bw, bh,
    { level = "gilded", state = "danger", fill = false, accent = c.blood, px = 2 })
  local midY = iy + ih / 2
  local cx = ix + 6
  -- CRÂNE (préfixe) : un diamant Forge en sang vif tient lieu de glyphe (les polices ne garantissent pas ☠).
  Forge.diamondAt(cx + 3, midY, 4, c.bloodBright, c.bloodDeep)
  cx = cx + 12
  -- FRIMOUSSE du défunt (J3) entre le crâne et le nom -> on voit QUI tombe, en grand (bloc le plus lourd).
  local nameX = cx
  cx = cx + self:_mini(e.targetId, cx, midY, MINI_DEATH, e.targetTeam)
  -- NOM du défunt en gras (lecture immédiate de QUI tombe).
  local nfont = Theme.uiBold(13)
  local name = self.chron:segments(e)
  local who = (name[1] and name[1].text) or "?"
  Draw.text(who, cx, midY - nfont:getHeight() / 2, c.inkBright, nfont)
  local whoW = Draw.textWidth(who, nfont)
  -- rect de survol = frimousse + nom du défunt -> carte au survol (J4).
  if e.targetId then
    self._nameRects[#self._nameRects + 1] = { x = nameX, y = y, w = (cx + whoW) - nameX, h = H_DEATH - 4, id = e.targetId }
  end
  cx = cx + whoW + 4
  -- « falls » en lecture, atténué.
  local rfont = Theme.read(12)
  Draw.text(T("chronicle.v.fall"), cx, midY - rfont:getHeight() / 2, c.faint, rfont)
  cx = cx + Draw.textWidth(T("chronicle.v.fall") .. " ", rfont)
  -- suffixe « par <icône famille> » si la mort suit une affliction (cause portée par l'entrée).
  if e.causeFamily then
    Draw.text(T("chronicle.v.by") .. " ", cx, midY - rfont:getHeight() / 2, c.fainter, rfont)
    cx = cx + Draw.textWidth(T("chronicle.v.by") .. " ", rfont)
    drawFamilyIcon(e.causeFamily, cx, midY)
  end
end

function CD:wheelmoved(_, dy) self.scroll = self.scroll - (dy or 0) * H_ROW * 2 end

-- SURVOL d'un nom (J4) : mémorise la position souris (ESPACE DESIGN, comme les rects). Le hit-test réel se
-- fait en fin de :draw (mêmes positions que les _nameRects fraîchement posés -> pas de décalage de frame).
function CD:mousemoved(dx, dy) self._mx, self._my = dx, dy end

-- Détecte le nom sous le curseur dans les _nameRects de la frame courante. Renvoie (id, rect) ou nil.
-- Clippe le hit-test à la zone de liste (les rects au-dessus/dessous du clip ne comptent pas).
function CD:_hitName()
  if not (self._mx and self._nameRects and self._rect) then return nil end
  local lr = self._rect
  if not ptIn(self._mx, self._my, lr.x, lr.y, lr.w, lr.h) then return nil end -- hors liste
  for _, r in ipairs(self._nameRects) do
    if ptIn(self._mx, self._my, r.x, r.y, r.w, r.h) then return r.id, r end
  end
  return nil
end

-- id du monstre actuellement survolé (calculé en fin de :draw) + son rect, pour l'appelant (carte au survol).
function CD:hoveredName() return self._hoverId, self._hoverRect end

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
