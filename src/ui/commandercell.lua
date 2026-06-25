-- src/ui/commandercell.lua
-- LA CASE DU COMMANDANT — version SIMPLE (refonte 2026-06, retour user : l'ancien trône carvé était jugé
-- « horrible / contours chelou » et l'interaction cassée). On la veut LISIBLE D'UN COUP : une case propre
-- (même langage visuel que les cases du plateau, cf. src/ui/slot.lua) surmontée d'un header texte « COMMANDER ».
-- AUCUNE fioriture : pas de niche/dais/socle, pas de couronne, pas de halo, pas de barre de cadence. Juste une
-- case + un titre + (si vide) un hint pour qu'on COMPRENNE ce qu'on fait. La fiche au survol (MonsterCard, avec
-- son bandeau « AT COMMAND ») reste le canal d'explication de l'aura — gérée par le caller.
--
-- ── CE QU'ELLE DESSINE (coords en ESPACE DESIGN, sous Draw.begin) ──────────────────────────────────────
--   CommanderCell.draw(x, y, w, h, opts) — la case complète :
--     1) un HEADER (petite plaque sombre + liseré) avec le mot « COMMANDER » (Space Mono caps) au-dessus ;
--     2) la CASE elle-même (fond sombre + liseré d'état) où le caller rend le rig du commandant (s'il y en a) ;
--     3) ÉTAT VIDE -> hint discret centré (« Drop a unit to command ») pour expliquer l'usage ;
--        DROP VALIDE -> liseré VERT (seul vert de la palette = cible de drop) ;
--        REFUS -> liseré sang bref (le caller pilote opts.danger + le shake d'offset).
--
-- Le caller (build.lua) fournit la GÉOMÉTRIE (x,y,w,h) et l'ÉTAT (opts), et rend le RIG dans la case (cellRect
-- renvoie la boîte interne pour caler les pieds). RENDER PUR (love.graphics), HEADLESS-SAFE (stub -> no-op).

local Theme = require("src.ui.theme")
local Draw = require("src.ui.draw")
local I18n = require("src.core.i18n")
local T = I18n.t

local CommanderCell = {}

local C = Theme.c
local floor, min, sin = math.floor, math.min, math.sin

local function g() return love and love.graphics or nil end

-- Hauteur RÉSERVÉE au-dessus de la boîte pour le header « COMMANDER ». Design px. Le caller la garde libre.
CommanderCell.HEADER_H = 13

-- La CASE utile (boîte interne où le caller cale le rig). Identique à (x,y,w,h) : la case EST la boîte (plus de
-- niche imbriquée façon trône). Le header vit AU-DESSUS de y (espace réservé HEADER_H). Exposée pour le hit-test.
function CommanderCell.cellRect(x, y, w, h)
  return { x = floor(x), y = floor(y), w = floor(w), h = floor(h) }
end

-- Hachure diagonale sombre (case occupée/active) — même grain que les cases du plateau (src/ui/slot.lua).
local function hatchFill(x, y, w, h, col, sz)
  local gr = g(); if not gr then return end
  sz = sz or 3
  gr.setColor(col[1], col[2], col[3], col[4] or 1)
  for sx = 0, w - 1 do
    for sy = 0, h - 1 do
      if (floor((sx + sy) / sz) % 2) == 0 then gr.rectangle("fill", x + sx, y + sy, 1, 1) end
    end
  end
  gr.setColor(1, 1, 1, 1)
end

-- Liseré additif (lueur de bord) — l'« émissif » d'état (drop vert / refus sang). Discret, jamais clignotant.
local function glowRect(x, y, w, h, col, a)
  local gr = g(); if not gr or not gr.setBlendMode then return end
  gr.setBlendMode("add")
  gr.setColor(col[1], col[2], col[3], a)
  gr.rectangle("line", x, y, w, h)
  gr.rectangle("line", x - 1, y - 1, w + 2, h + 2)
  gr.setBlendMode("alpha")
  gr.setColor(1, 1, 1, 1)
end

-- ── draw — la case complète. ──────────────────────────────────────────────────────────────────────────
-- x,y,w,h = la CASE (le header est au-dessus de y, dans HEADER_H). opts = {
--   filled    = bool   -- le commandant est dans la case (le caller rend son rig ; on hachure le fond)
--   hover     = bool   -- survol de la case (liseré un peu plus chaud)
--   validDrop = bool   -- un porteur de commandBonus est glissé par-dessus (liseré VERT)
--   danger    = bool   -- refus en cours (liseré sang bref ; le caller gère le shake d'offset)
--   t         = secondes -- horloge d'animation (légère respiration de l'invite)
-- }
function CommanderCell.draw(x, y, w, h, opts)
  opts = opts or {}
  x, y, w, h = floor(x), floor(y), floor(w), floor(h)
  local gr = g()
  local t = opts.t or 0
  local breath = 0.5 + 0.5 * sin(t * 1.8) -- respiration lente (≈0,3 Hz)

  -- ── HEADER « COMMANDER » au-dessus de la case (plaque sombre + liseré laiton, lecture immédiate du rôle). ──
  do
    local hf = Theme.label(7)
    local txt = T("ui.commander_header")
    local hy = y - CommanderCell.HEADER_H
    Draw.rect(x, hy, w, CommanderCell.HEADER_H - 1, { 0x16 / 255, 0x12 / 255, 0x1d / 255, 1 }, C.brass, 1)
    -- éclat 1px en haut (cohérent avec Panel/UI) puis le mot centré, laiton clair (sourd, pas criard).
    if gr then gr.setColor(C.brassS[1], C.brassS[2], C.brassS[3], 0.14); gr.rectangle("fill", x + 1, hy + 1, w - 2, 1); gr.setColor(1, 1, 1, 1) end
    Draw.textC(txt, x + w / 2, hy + 1, opts.filled and C.brassL or C.brass, hf)
  end

  -- ── ÉTAT DU LISERÉ (priorité : refus > drop > rempli/survol > vide). Même vocabulaire que les cases plateau. ──
  local border, glow, glowA
  if opts.danger then border = C.bloodL; glow = C.blood; glowA = 0.6
  elseif opts.validDrop then border = C.drop; glow = C.drop; glowA = 0.4 + 0.2 * breath
  elseif opts.filled then border = C.brass; glow = nil
  elseif opts.hover then border = C.brassL; glow = nil
  else border = C.slotEdge; glow = nil end

  -- ── LA CASE : fond sombre plein + (si remplie/active) hachure diagonale + liseré d'état 2px. ──
  Draw.rect(x + 1, y + 1, w - 2, h - 2, opts.filled and C.stone800 or C.stone850)
  if opts.filled then hatchFill(x + 1, y + 1, w - 2, h - 2, C.stone700, 3) end
  Draw.rect(x, y, w, h, nil, border, 2)
  if gr then
    gr.setColor(C.iron[1], C.iron[2], C.iron[3], 0.5)
    gr.rectangle("line", x + 2, y + 2, w - 4, h - 4)
  end
  if glow then glowRect(x, y, w, h, glow, glowA) end

  -- REFUS : voile sang DANS la case (le creux « rejette » la bête, lisible même sous un rig glissé par-dessus).
  if opts.danger and gr then
    gr.setColor(C.blood[1], C.blood[2], C.blood[3], 0.20)
    gr.rectangle("fill", x + 1, y + 1, w - 2, h - 2)
    gr.setColor(1, 1, 1, 1)
  end

  -- ── ÉTAT VIDE : HINT centré (« Drop a unit to command ») — court, lisible, wrap pour ne jamais déborder de
  -- la case. C'est le « pourquoi » de la case affiché en clair (fix « widget muet »). Pulse à peine à l'offre.
  if not opts.filled then
    local f = Theme.label(7)
    local a = 0.55 + 0.15 * breath
    Draw.setColor(C.faint, a)
    Draw.textWrap(T("ui.commander_hint"), x + 4, y + floor(h / 2) - 8, w - 8, { C.faint[1], C.faint[2], C.faint[3], a }, f, "center")
    Draw.reset()
  end

  Draw.reset()
end

return CommanderCell
