-- src/ui/pedestal.lua
-- LE PIÉDESTAL DU COMMANDANT (C4, spec docs/research/commanders-plan.md §4.1-4.2) : un socle/trône CARVÉ
-- (pierre + or terni, DA forge ARPG), DISTINCT du plateau-graphe 3×3 — la lisibilité « pas d'adjacence » est
-- portée par l'ABSENCE de toute arête vers le board. C'est un atome RENDER PUR (love.graphics, espace design
-- 1280×720, sous Draw.begin), HEADLESS-SAFE (love.graphics stubé -> no-op, golden neutre).
--
-- ── CE QU'IL DESSINE (toutes les coords en ESPACE DESIGN) ──────────────────────────────────────────────
--   Pedestal.draw(x, y, w, h, opts) — le socle complet, en couches :
--     1) un DAIS à degrés (marches de pierre carvée + filet laiton terni) ;
--     2) une NICHE creuse au sommet où repose (ou non) le commandant ;
--     3) ÉTAT VIDE -> niche sombre + CTA discret « CROWN A BEAST » + lente pulsation d'invite ;
--        ÉTAT REMPLI -> liseré DORÉ qui respire + halo de rareté doux (le commandant est SURÉLEVÉ par
--        le caller, qui le rend dans la niche) ; AUCUNE arête vers le board ;
--        DROP VALIDE -> la niche s'illumine en VERT (seul vert de la palette = cible de drop) ;
--        REFUS / SHAKE -> liseré sang bref (le caller pilote l'offset de shake) ;
--     4) un LABEL gravé « WARLORD » au-dessus, sur une petite plaque laiton ;
--     5) la BARRE DE CADENCE LENTE sous le socle (remplissage = phase, lisiblement plus lente que les troupes).
--
-- Le caller (build.lua) fournit la GÉOMÉTRIE (x,y,w,h) et l'ÉTAT (opts), et rend le RIG du commandant dans
-- la niche (Pedestal.nicheRect renvoie la boîte interne pour caler les pieds). On ne dessine JAMAIS le rig
-- ici (séparation rendu monde / overlay du build), juste le socle + le décor.
--
-- Réf DA : Slot/Panel/Badge (mêmes tokens Theme), Frame « pierre gravée » (biseau), forge-ui-reference.

local Theme = require("src.ui.theme")
local Draw = require("src.ui.draw")
local I18n = require("src.core.i18n")
local T = I18n.t

local Pedestal = {}

local C = Theme.c
local floor, min, max, sin = math.floor, math.min, math.max, math.sin
local PI = math.pi

local function g() return love and love.graphics or nil end

-- Géométrie INTERNE dérivée de la boîte (x,y,w,h design). Le socle se compose, du haut vers le bas :
--   · une plaque LABEL (au-dessus de la boîte, plaqué laiton)
--   · la NICHE (carrée, en haut de la boîte) où repose le commandant
--   · le DAIS à 2 degrés sous la niche (marches qui s'élargissent)
--   · la barre de CADENCE sous le dais.
-- nicheRect = la niche utile (le caller y cale le rig). On garde la niche CARRÉE et centrée horizontalement.
-- NOTE : la fraction de hauteur de la niche (0.58) DOIT rester alignée avec build.lua:computeLayout
-- (self.commanderRect = hit-test souris) -> le hit-test colle exactement à la niche dessinée.
local NICHE_FRAC = 0.58
local function geom(x, y, w, h)
  x, y, w, h = floor(x), floor(y), floor(w), floor(h)
  local nicheH = floor(h * NICHE_FRAC + 0.5)  -- la niche (siège) occupe le haut ; le dais s'étage dessous
  local niche = { x = x + 2, y = y, w = w - 4, h = nicheH }
  local daisY = y + nicheH
  local daisH = h - nicheH
  return { box = { x = x, y = y, w = w, h = h }, niche = niche, daisY = daisY, daisH = daisH }
end

-- Niche utile (boîte interne où le caller cale le rig du commandant). Exposée pour le rendu monde du build.
function Pedestal.nicheRect(x, y, w, h)
  return geom(x, y, w, h).niche
end

-- Hauteur RÉSERVÉE au-dessus de la boîte pour la plaque LABEL (le caller la garde libre). Design px.
Pedestal.LABEL_H = 13
-- Hauteur réservée SOUS la boîte pour la barre de cadence + légende. Design px.
Pedestal.CADENCE_H = 14

-- Petit dégradé vertical local (pierre carvée) : on n'importe pas Panel pour rester atomique + sans PostFX
-- (le piédestal n'est pas une carte flottante ; pas de marquage de distorsion onirique sur ses bords).
local function vgrad(x, y, w, h, top, bot)
  local gr = g(); if not gr then return end
  local n = max(2, min(18, floor(h)))
  local bh = h / n
  for i = 0, n - 1 do
    local t = i / (n - 1)
    gr.setColor(top[1] + (bot[1] - top[1]) * t, top[2] + (bot[2] - top[2]) * t,
      top[3] + (bot[3] - top[3]) * t, (top[4] or 1) + ((bot[4] or 1) - (top[4] or 1)) * t)
    gr.rectangle("fill", x, y + i * bh, w, bh + 1)
  end
  gr.setColor(1, 1, 1, 1)
end

-- Liseré additif (lueur de bord) — l'« émissif » d'état (drop vert / sélection dorée / refus sang).
local function glowRect(x, y, w, h, col, a)
  local gr = g(); if not gr or not gr.setBlendMode then return end
  gr.setBlendMode("add")
  gr.setColor(col[1], col[2], col[3], a)
  gr.rectangle("line", x, y, w, h)
  gr.rectangle("line", x - 1, y - 1, w + 2, h + 2)
  gr.setBlendMode("alpha")
  gr.setColor(1, 1, 1, 1)
end

-- ── DAIS à degrés : 2 marches de pierre qui s'élargissent vers le bas (un trône surélevé, pas une case). ──
-- Carvé : dégradé pierre + arête laiton ternie en haut de chaque marche + ourlet sombre (relief ciselé).
local function drawDais(gm)
  local gr = g()
  local x, w = gm.box.x, gm.box.w
  local y, h = gm.daisY, gm.daisH
  if h <= 0 then return end
  -- 2 marches : la 1re (haute) un peu plus étroite, la 2e (base) plus large -> silhouette de socle.
  local steps = {
    { x = x + 3, w = w - 6, y = y,            h = floor(h * 0.5) },
    { x = x - 1, w = w + 2, y = y + floor(h * 0.42), h = h - floor(h * 0.42) },
  }
  for _, s in ipairs(steps) do
    vgrad(s.x, s.y, s.w, s.h, { 0x29 / 255, 0x22 / 255, 0x18 / 255, 1 }, { 0x12 / 255, 0x0e / 255, 0x09 / 255, 1 })
    Draw.rect(s.x, s.y, s.w, s.h, nil, C.iron, 1)
    -- arête laiton ternie en crête de marche (filet 1px) + ourlet sombre dessous (le ciseau).
    if gr then
      gr.setColor(C.brass[1], C.brass[2], C.brass[3], 0.85)
      gr.rectangle("fill", s.x + 1, s.y + 1, s.w - 2, 1)
      gr.setColor(C.iron[1], C.iron[2], C.iron[3], 0.6)
      gr.rectangle("fill", s.x + 1, s.y + 3, s.w - 2, 1)
      gr.setColor(1, 1, 1, 1)
    end
  end
end

-- ── NICHE : la cuve creuse au sommet (où trône le commandant). Fond très sombre (creux) + biseau enfoncé
-- (ombre haut-gauche / lumière bas-droite = ça s'enfonce, inset) + liseré d'état. ──
local function drawNiche(niche, st)
  local gr = g()
  local nx, ny, nw, nh = niche.x, niche.y, niche.w, niche.h
  -- 1) cuve : pierre très sombre (creux), dégradé vers un fond plus noir en bas.
  vgrad(nx, ny, nw, nh, { 0x14 / 255, 0x10 / 255, 0x0c / 255, 1 }, { 0x07 / 255, 0x05 / 255, 0x08 / 255, 1 })
  -- 2) biseau ENFONCÉ (inset) : ombre en haut+gauche, lumière sourde en bas+droite -> la pierre se creuse.
  if gr then
    gr.setColor(0, 0, 0, 0.55)
    gr.rectangle("fill", nx, ny, nw, 2)         -- ombre haute
    gr.rectangle("fill", nx, ny, 2, nh)         -- ombre gauche
    gr.setColor(C.brass[1], C.brass[2], C.brass[3], 0.16)
    gr.rectangle("fill", nx, ny + nh - 1, nw, 1) -- lumière basse (réflexe terni)
    gr.setColor(1, 1, 1, 1)
  end
  -- 3) liseré d'état (le bord de la cuve). idle = laiton terni ; selected = doré ; drop = vert ; danger = sang.
  Draw.rect(nx, ny, nw, nh, nil, st.border, 1)
end

-- ── draw — le socle complet. ──────────────────────────────────────────────────────────────────────────
-- x,y,w,h = la BOÎTE (niche + dais), espace design. (le LABEL est au-dessus de y, la CADENCE sous y+h.)
-- opts = {
--   filled    = bool          -- le commandant trône (liseré doré + halo)
--   hover     = bool          -- survol du piédestal (lueur d'invite renforcée)
--   validDrop = bool          -- un porteur de commandBonus est glissé par-dessus (niche VERTE)
--   offered   = bool          -- l'offre de piédestal attend (niche pulse en or, « clique pour accepter »)
--   danger    = bool          -- refus en cours (liseré sang bref ; le caller gère le shake d'offset)
--   accent    = {r,g,b}       -- couleur de rareté du commandant (halo + plaque), si filled
--   t         = secondes      -- horloge d'animation (pulsation, respiration du liseré)
--   cadence   = 0..1          -- phase de la barre de cadence lente (nil -> barre vide)
--   labelKey  = clé i18n      -- libellé de la plaque (def « WARLORD »)
-- }
function Pedestal.draw(x, y, w, h, opts)
  opts = opts or {}
  x, y, w, h = floor(x), floor(y), floor(w), floor(h)
  local gr = g()
  local t = opts.t or 0
  local gm = geom(x, y, w, h)
  -- respiration lente (≈0,5 Hz) : l'invite/sélection « palpite » doucement (grimdark, jamais clignotant).
  local breath = 0.5 + 0.5 * sin(t * 1.8)

  -- État de bord de la niche (priorité : refus > drop > offre > rempli > vide).
  local border, glow, glowA
  if opts.danger then border = C.bloodL; glow = C.blood; glowA = 0.7
  elseif opts.validDrop then border = C.drop; glow = C.drop; glowA = 0.45 + 0.25 * breath
  elseif opts.offered then border = C.brassS; glow = C.gold; glowA = 0.30 + 0.30 * breath
  elseif opts.filled then border = C.brassS; glow = C.gold; glowA = 0.18 + 0.18 * breath
  else border = C.brass; glow = nil end
  local st = { border = border }

  -- 1) HALO de rareté DERRIÈRE le socle (héros) : cercles additifs doux, seulement si rempli.
  if opts.filled and gr and gr.setBlendMode and gr.circle then
    local acc = opts.accent or C.gold
    local cx, cy = gm.niche.x + gm.niche.w / 2, gm.niche.y + gm.niche.h * 0.5
    gr.setBlendMode("add")
    for k = 3, 1, -1 do
      gr.setColor(acc[1], acc[2], acc[3], (0.05 + 0.03 * breath) * k)
      gr.circle("fill", cx, cy, gm.niche.w * 0.5 * (k / 3) + 4)
    end
    gr.setBlendMode("alpha"); gr.setColor(1, 1, 1, 1)
  end

  -- 2) le DAIS (degrés de pierre) PUIS la NICHE par-dessus (la cuve repose sur le socle).
  drawDais(gm)
  drawNiche(gm.niche, st)

  -- 3) lueur de bord d'état (émissif) sur la niche.
  if glow then glowRect(gm.niche.x, gm.niche.y, gm.niche.w, gm.niche.h, glow, glowA) end
  -- REFUS : voile sang DANS la niche (le creux « rejette » la bête, lisible même sous le rig glissé par-dessus).
  if opts.danger and gr then
    gr.setColor(C.blood[1], C.blood[2], C.blood[3], 0.22)
    gr.rectangle("fill", gm.niche.x + 1, gm.niche.y + 1, gm.niche.w - 2, gm.niche.h - 2)
    gr.setColor(1, 1, 1, 1)
  end

  -- 4) ÉTAT VIDE : COURONNE schématique gravée dans le creux (invite « couronne une bête »). 3 pointes nettes
  -- + un bandeau, dessinés en barres (pixel-friendly, pas un polygone mou) -> ça se lit « couronne », pas mont.
  -- Estompée au repos, pulse franchement à l'offre/survol. Petite gemme sang au pic central (le sceau du chef).
  if not opts.filled and gr then
    local cx = gm.niche.x + gm.niche.w / 2
    local baseY = gm.niche.y + gm.niche.h * 0.60
    local s = gm.niche.w * 0.30                 -- demi-largeur de la couronne
    local hSpike = s * 0.95                      -- hauteur des pointes
    local a = (opts.offered and 0.62 or 0.32) + 0.26 * breath * ((opts.hover or opts.offered) and 1 or 0.4)
    local col = opts.offered and C.brassS or C.brassL
    gr.setColor(col[1], col[2], col[3], a)
    -- bandeau de base (la jante de la couronne).
    local bandH = max(2, floor(s * 0.34))
    gr.rectangle("fill", floor(cx - s), floor(baseY), floor(s * 2), bandH)
    -- 3 pointes triangulaires (gauche/centre plus haute/droite) montant du bandeau.
    if gr.polygon then
      local tips = { { cx - s, -hSpike * 0.7 }, { cx, -hSpike }, { cx + s, -hSpike * 0.7 } }
      for _, tp in ipairs(tips) do
        local tw = s * 0.42
        gr.polygon("fill", tp[1] - tw, baseY, tp[1] + tw, baseY, tp[1], baseY + tp[2])
      end
    end
    -- gemme sang sertie au centre du bandeau (le sceau) — seul accent coloré, discret.
    gr.setColor(C.blood[1], C.blood[2], C.blood[3], a * 0.9)
    gr.rectangle("fill", floor(cx - 1.5), floor(baseY + bandH * 0.15), 3, max(1, floor(bandH * 0.6)))
    gr.setColor(1, 1, 1, 1)
  end

  -- 5) PLAQUE LABEL au-dessus du socle (laiton terni gravé) : « WARLORD ». Centrée sur la boîte.
  do
    local lf = Theme.label(7)
    local txt = T(opts.labelKey or "ui.pedestal_label")
    local tw = (lf and lf:getWidth(txt)) or (#txt * 5)
    local pw = tw + 12
    local px = floor(gm.box.x + gm.box.w / 2 - pw / 2)
    local py = gm.box.y - Pedestal.LABEL_H
    vgrad(px, py, pw, Pedestal.LABEL_H - 2, { 0x22 / 255, 0x1a / 255, 0x0e / 255, 1 }, { 0x12 / 255, 0x0c / 255, 0x07 / 255, 1 })
    local lcol = opts.filled and C.brassS or C.brass
    Draw.rect(px, py, pw, Pedestal.LABEL_H - 2, nil, lcol, 1)
    Draw.textC(txt, gm.box.x + gm.box.w / 2, py + 1, opts.filled and C.gold or C.brassL, lf)
  end

  -- 6) BARRE DE CADENCE LENTE sous le socle (spec §4.2) : un long sillon gravé qui se remplit lentement.
  -- N'apparaît QUE si rempli (un commandant attaque). Le remplissage est piloté par opts.cadence (0..1),
  -- lui-même AVANCÉ lentement par le caller (cd × cdMult) -> visiblement plus lent que les troupiers.
  if opts.filled and opts.cadence ~= nil then
    local barY = gm.box.y + gm.box.h + 4
    local barX = gm.box.x + 2
    local barW = gm.box.w - 4
    local barH = 5
    -- sillon gravé (creux sombre + ourlet).
    Draw.rect(barX, barY, barW, barH, { 0x09 / 255, 0x07 / 255, 0x0c / 255, 1 }, C.iron, 1)
    local fw = floor((barW - 2) * max(0, min(1, opts.cadence)))
    if fw > 0 then
      -- remplissage laiton chaud (rythme lent du chef) + crête éclairée.
      vgrad(barX + 1, barY + 1, fw, barH - 2, { 0xca / 255, 0xa6 / 255, 0x4a / 255, 1 }, { 0x7a / 255, 0x5e / 255, 0x24 / 255, 1 })
      if gr then
        gr.setColor(C.brassS[1], C.brassS[2], C.brassS[3], 0.7)
        gr.rectangle("fill", barX + 1, barY + 1, fw, 1)
        gr.setColor(1, 1, 1, 1)
      end
    end
    -- légende discrète sous la barre (capitales courtes, Space Mono) : « SLOW CADENCE ».
    local cf = Theme.label(6)
    Draw.textC(T("ui.pedestal_cadence"), gm.box.x + gm.box.w / 2, barY + barH + 1, C.ink4, cf)
  end

  Draw.reset()
  return gm
end

return Pedestal
