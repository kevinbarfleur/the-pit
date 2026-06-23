-- src/ui/tooltip.lua
-- MOLÉCULE « infobulle / tooltip » (design-system §2.14) — un mini-panneau forge qui décrit une unité au
-- survol : NOM (Cinzel) + chip de famille à droite + BARRE DE STATS encastrée (Space Mono, labels ink3 /
-- valeurs ink) + nom de PASSIF (Space Mono or) + chip d'affliction + PROSE (Spectral). Une petite FLÈCHE
-- pointe vers l'élément survolé (gauche par défaut, comme la maquette : « left:-6px top:24px »).
--
-- ── ARCHI ─────────────────────────────────────────────────────────────────────────────────────────
-- On BAKE le FOND (mini-panneau : plaque + veines + cadre patiné + flèche) dans un widget Forge caché par
-- id ; le contenu LISIBLE (nom, stats, passif, prose) est dessiné en OVERLAY VIVANT (vraies voix typo) via
-- les helpers Draw + Chip. La barre de stats est un encadré sobre (Frame plain) qui ENCAISSE les valeurs.
-- RENDER pur, espace DESIGN, HEADLESS-SAFE (bake pcall-gardé ; overlays no-op sans police ; Chip no-op).
--
-- Tooltip.draw(x, y, opts) :
--   x,y     coin haut-gauche du panneau en ESPACE DESIGN. La flèche déborde à GAUCHE (opts.arrow="left").
--   opts = {
--     name    = nom de l'unité (Cinzel)                  -- requis pour l'en-tête
--     fam     = "flesh"|... (chip de famille à droite ; via Theme.types)  -- optionnel
--     stats   = { {label="HP", value=70}, {label="DMG", value=6}, {label="CD", value="6s"} }  -- barre Space Mono
--     passive = nom du passif (Space Mono or)             -- optionnel
--     affKey  = clé d'affliction du passif (chip)         -- optionnel
--     prose   = description (Spectral ink2, wrap)         -- optionnel
--     w       = largeur (défaut 248, §2.14) ; h auto-mesurée si absente.
--     arrow   = "left"|"right"|"none" (défaut "left")
--     id, t   = cache + horloge (le veilleur de l'œil + veines respirent).
--   }
--   Retourne (x, y, w, h) = le rect réel occupé (h mesurée) pour le placement / clamp à l'écran.

local Theme = require("src.ui.theme")
local Draw = require("src.ui.draw")
local Forge = require("src.ui.forge")
local Chip = require("src.ui.chip")
local C = Theme.c

local Tooltip = {}

local floor, max, min = math.floor, math.max, math.min

local DEFAULT_W = 248 -- §2.14 : « Width: 248px »
local PAD = 14        -- §2.14 : « padding 13–14px 15px »
local ARROW = 10      -- §2.14 : « Arrow: 10×10px »

-- Mesure la HAUTEUR nécessaire (pour dimensionner avant de baker). On reproduit la pile de l'overlay.
local function measureH(opts, innerW)
  local h = PAD
  -- en-tête (nom Cinzel)
  local nf = Theme.heading(15) or Theme.subhead(15)
  h = h + (nf and nf:getHeight() or 16) + 8
  -- barre de stats (encadré) : 1 ligne de valeurs + padding interne
  if opts.stats and #opts.stats > 0 then
    local sf = Theme.value(11) or Theme.label(11)
    h = h + (sf and sf:getHeight() or 12) + 14 + 8
  end
  -- nom de passif
  if opts.passive and opts.passive ~= "" then
    local pf = Theme.value(11) or Theme.label(11)
    h = h + (pf and pf:getHeight() or 12) + 6
  end
  -- chip d'affliction
  if opts.affKey then
    h = h + 18 + 4
  end
  -- prose (wrap)
  if opts.prose and opts.prose ~= "" then
    local prf = Theme.body(13) or Theme.bodyLight(13)
    if prf then
      local _, lines = prf:getWrap(opts.prose, innerW)
      h = h + #lines * prf:getHeight() + 4
    else
      h = h + 16
    end
  end
  return h + PAD
end

-- ── BAKE : mini-panneau forge (plaque + veines + cadre patiné + flèche) ─────────────────────────────
local function bakeTip(buf, W, H, p)
  local Eye = require("src.ui.eye")
  local B = 2
  -- matière + biseau (framedPlate = moteur de Frame.draw) — plaque pleine, liseré métal sobre.
  Forge.framedPlate(buf, W, H, { fill = true, th = B, seed = p.seed })
  -- FLÈCHE (petit losange métal qui déborde du bord) : on la pose DANS le tampon, sur le bord choisi, à ~24px
  -- du haut (« top:24px » de la maquette). C'est un coin tourné à 45° (port du clip-path rotate(45deg)).
  local ay = floor(min(H - ARROW, p.arrowY or 24) + 0.5)
  if p.arrow == "left" then
    for k = 0, ARROW - 1 do
      local span = (k < ARROW / 2) and k or (ARROW - 1 - k)
      for s = 0, span do
        buf:set(s, ay + k, s == span and { 8, 5, 3 } or { 22, 17, 29 })
      end
    end
  elseif p.arrow == "right" then
    for k = 0, ARROW - 1 do
      local span = (k < ARROW / 2) and k or (ARROW - 1 - k)
      for s = 0, span do
        buf:set(W - 1 - s, ay + k, s == span and { 8, 5, 3 } or { 22, 17, 29 })
      end
    end
  end
  -- veilleur (œil qui s'ouvre/se ferme en cycle, bas-droite, hors du contenu) : rend l'UI vivante.
  Eye.watcher(buf, W, H, p.t or 0, p.seed or 42, { fx = 0.9, fy = 0.88, r = 4, blood = 0.6 })
  return B
end

Tooltip._cache = {}

function Tooltip.draw(x, y, opts)
  opts = opts or {}
  x, y = floor(x), floor(y)
  local w = floor(opts.w or DEFAULT_W)
  local px = opts.px or Forge.PX
  local arrow = opts.arrow or "left"
  local t = opts.t or 0
  local innerW = w - 2 * PAD
  local h = floor(opts.h or measureH(opts, innerW))
  local id = opts.id or ("tip:" .. floor(x) .. "," .. floor(y) .. "x" .. floor(w))
  local seed = opts.seed or 42

  -- 1) BAKE du fond (cache par id ; re-bake si géométrie/arrow change ou pour animer le veilleur -> on
  --    re-bake chaque frame comme MonsterCard : 1 tooltip visible à la fois, c'est bon marché). Headless-safe.
  local aw, ah = max(1, floor(w / px)), max(1, floor(h / px))
  local e = Tooltip._cache[id]
  if not e or e.aw ~= aw or e.ah ~= ah then
    e = { widget = Forge.newWidget(aw, ah), aw = aw, ah = ah }
    Tooltip._cache[id] = e
  end
  e.image = Forge.render(e.widget, function(b, W, H, tt)
    bakeTip(b, W, H, { arrow = arrow, seed = seed, t = tt, arrowY = floor(24 / px) })
  end, t)
  Forge.blit(e.image, x, y, px)

  -- 2) OVERLAYS LISIBLES (no-op headless via Draw / Chip -> love.graphics absent sous le mock).
  if love and love.graphics and love.graphics.print then
    local cursorY = y + PAD
    local bodyX = x + PAD
    local rightX = x + w - PAD

    -- ── en-tête : NOM (Cinzel) à gauche + chip de famille à droite ──
    local nf = Theme.heading(15) or Theme.subhead(15)
    Draw.text(opts.name or "", bodyX, cursorY, C.ink, nf)
    if opts.fam then
      local ty = Theme.type(opts.fam)
      local cf = Theme.label(10) or Theme.value(10)
      local famName = (opts.fam:gsub("^%l", string.upper))
      love.graphics.setFont(cf)
      local cw = Chip.width({ label = famName, color = ty.color, font = cf, icon = false })
      Chip.draw(floor(rightX - cw), cursorY, { label = famName, color = ty.color, font = cf, icon = false })
    end
    cursorY = cursorY + (nf and nf:getHeight() or 16) + 8

    -- ── barre de STATS (encadré sobre + valeurs Space Mono, labels ink3 / valeurs ink) ──
    if opts.stats and #opts.stats > 0 then
      local sf = Theme.value(11) or Theme.label(11)
      local barH = (sf and sf:getHeight() or 12) + 14
      -- fond encastré sombre (#0a0810-ish via Theme.c.stone900) bordé iron, comme la maquette.
      Draw.rect(bodyX, cursorY, innerW, barH, C.stone900, C.iron, 1)
      -- compose les stats en flex « evenly » sur la largeur intérieure.
      if sf then
        love.graphics.setFont(sf)
        local n = #opts.stats
        local cellW = innerW / n
        local midY = cursorY + barH / 2
        for i = 1, n do
          local s = opts.stats[i]
          local ccx = bodyX + (i - 0.5) * cellW
          local lab = tostring(s.label or "")
          local val = tostring(s.value)
          local lw = sf:getWidth(lab .. " ")
          local vw = sf:getWidth(val)
          local total = lw + vw
          local sx = floor(ccx - total / 2)
          Draw.text(lab, sx, midY - sf:getHeight() / 2, C.ink3, sf)
          Draw.text(val, sx + lw, midY - sf:getHeight() / 2, C.ink, sf)
        end
      end
      cursorY = cursorY + barH + 8
    end

    -- ── nom de PASSIF (Space Mono OR) ──
    if opts.passive and opts.passive ~= "" then
      local pf = Theme.value(11) or Theme.label(11)
      Draw.text(opts.passive, bodyX, cursorY, C.gold, pf)
      cursorY = cursorY + (pf and pf:getHeight() or 12) + 6
    end

    -- ── chip d'AFFLICTION (le passif « se voit » : icône + nom + teinte) ──
    if opts.affKey then
      local cf = Theme.label(10) or Theme.value(10)
      Chip.draw(bodyX, cursorY, { key = opts.affKey, font = cf, h = 18 })
      cursorY = cursorY + 18 + 4
    end

    -- ── PROSE (Spectral ink2, wrap dans l'intérieur) ──
    if opts.prose and opts.prose ~= "" then
      local prf = Theme.body(13) or Theme.bodyLight(13)
      Draw.textWrap(opts.prose, bodyX, cursorY, innerW, C.ink2, prf, "left")
    end
    Draw.reset()
  end

  return x, y, w, h
end

return Tooltip
