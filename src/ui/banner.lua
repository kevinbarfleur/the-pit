-- src/ui/banner.lua
-- MOLÉCULE « bandeau de destin » (design-system §2.19) — le grand verdict sur l'arène assombrie :
--   • VICTORY   — mot OR (Jacquard), halo doré.
--   • DEFEAT    — mot SANG (Jacquard), halo sang.
--   • ASCENSION — mot OS/ink (Jacquard), liseré laiton + remontée de braise.
-- C'est le SEUL endroit (avec le logotype) où la voix CÉRÉMONIALE Jacquard est employée — « les grands mots
-- du destin », rarissimes (cf. theme.lua / design-system §II). Double FILET gravé encadre le mot (Dividers).
--
-- ── ARCHI — ENTIÈREMENT PROPRE (zéro Forge / zéro bake gritty) ──────────────────────────────────────
-- Le fond (voile radial coloré selon kind) est peint en bandes additives directes ; le cadre est un liseré
-- iron net (laiton pour l'ascension) ; le MOT et les lignes sont en OVERLAY VIVANT (Jacquard pour le mot,
-- avec une lueur additive pulsée ; Space Mono pour kicker/hint ; Spectral pour le score). Double filet
-- gravé (Dividers.brass) au-dessus et en dessous du mot. RENDER pur, espace DESIGN, HEADLESS-SAFE.
--
-- Banner.draw(x, y, w, kind, word, opts) :   (signature publique INCHANGÉE)
--   x,y     coin haut-gauche en ESPACE DESIGN ; w = largeur (le bandeau fait une HAUTEUR fixe, voir H()).
--   kind    "victory" | "defeat" | "ascension"   (pilote couleur + halo).
--   word    le grand mot (déjà résolu i18n ; ex. "VICTORY"). Affiché tel quel en Jacquard.
--   opts = { subtitle?, score?, hint?, t?, h?, id? (accepté, ignoré) }
--     subtitle : kicker au-dessus du mot (Space Mono caps tracké, ink3).
--     score    : ligne sous le mot (Spectral, ink2) — ex. récap de combat.
--     hint     : pied (Space Mono, ink5) — ex. « [SPACE] continue ».
--     t        : horloge (s) pour la lueur pulsée du mot (cosmétique).
--     h        : hauteur (défaut 170, comme la maquette §2.19).
--   Retourne (cx, cy) = centre du bandeau (pour composer un overlay au-dessus si besoin).

local Theme = require("src.ui.theme")
local Draw = require("src.ui.draw")
local Dividers = require("src.ui.dividers")
local C = Theme.c

local Banner = {}

local floor, max, sin = math.floor, math.max, math.sin

local DEFAULT_H = 170 -- §2.19 : « height 170px »

local function g() return love and love.graphics or nil end

-- Profil par kind : { word(floats label), halo(floats, voile additif), border(floats), ascension(bool) }.
local function kindProfile(kind)
  if kind == "defeat" then
    return C.bloodL, C.blood, C.iron, false
  elseif kind == "ascension" then
    return C.ink, C.ember, C.brass, true -- mot os/ink, halo de braise (ember), cadre laiton
  else -- victory (défaut)
    return C.gold, C.gold, C.iron, false
  end
end

-- Voile radial additif (la lueur du verdict baigne le centre/haut). Pour l'ascension, le foyer descend (la
-- braise remonte du bas). col = {r,g,b} floats. Échantillon en tuiles 2×2 (peu coûteux, doux à cette échelle).
local function radialGlow(x, y, w, h, col, alpha, fromBottom)
  local gr = g(); if not (gr and gr.setBlendMode) then return end
  local cx = x + w / 2
  local cyp = fromBottom and (y + h * 0.9) or (y + h * 0.42)
  local maxd = math.sqrt((w * 0.55) ^ 2 + (h * 0.7) ^ 2)
  gr.setBlendMode("add")
  for yy = 0, h - 1, 2 do
    for xx = 0, w - 1, 2 do
      local dx, dy = (x + xx) - cx, (y + yy) - cyp
      local d = math.sqrt(dx * dx + dy * dy) / maxd
      local a = max(0, 1 - d * 1.25)
      if a > 0.02 then
        gr.setColor(col[1], col[2], col[3], a * alpha)
        gr.rectangle("fill", x + xx, y + yy, 2, 2)
      end
    end
  end
  gr.setBlendMode("alpha")
  gr.setColor(1, 1, 1, 1)
end

function Banner.draw(x, y, w, kind, word, opts)
  opts = opts or {}
  kind = kind or "victory"
  x, y, w = floor(x), floor(y), floor(w)
  local h = floor(opts.h or DEFAULT_H)
  local t = opts.t or 0
  local wordCol, halo, border, ascension = kindProfile(kind)

  -- 1) FOND : base très sombre + voile radial coloré + cadre net. Tout propre (zéro bake Forge).
  Draw.rect(x, y, w, h, C.void, border, 1)
  radialGlow(x, y, w, h, halo, ascension and 0.18 or 0.16, false)
  if ascension then
    radialGlow(x, y, w, h, C.ember, 0.16, true) -- remontée de braise au bas
    -- liseré d'accent laiton interne (« inset 0 0 0 1px rgba(brass) » du §2.19).
    Draw.rect(x + 1, y + 1, w - 2, h - 2, nil, C.brass, 1)
  end

  local cx, cy = x + w / 2, y + h / 2

  -- 2) OVERLAYS. No-op headless via Draw.
  if love and love.graphics and love.graphics.print then
    -- ── sous-titre (kicker) au-dessus du mot ──
    if opts.subtitle and opts.subtitle ~= "" then
      local sf = ascension and (Theme.flavor(12) or Theme.bodyItalic(12)) or (Theme.labelSmall(10) or Theme.label(10))
      Draw.textTrackedC(opts.subtitle, cx, floor(y + h * 0.17 + 0.5), C.ink3, sf, ascension and 0 or 2.0)
    end

    -- ── double FILET gravé (au-dessus et en dessous du mot) — Dividers.brass, atome propre ──
    local span = floor(h * 0.20)
    Dividers.brass(cx, cy - span, floor(w * 0.58))
    Dividers.brass(cx, cy + span, floor(w * 0.58))

    -- ── LE MOT (Jacquard, taille ∝ hauteur) avec lueur pulsée (additive) ──
    local wpx = floor(h * (ascension and 0.30 or 0.32))
    local wf = Theme.display(wpx)
    if wf then
      love.graphics.setFont(wf)
      local ww = wf:getWidth(word)
      local wh = wf:getHeight()
      local wx = floor(cx - ww / 2 + 0.5)
      local wy = floor(cy - wh / 2 + 0.5)
      -- ombre portée (détache du fond).
      Draw.setColor({ 0.02, 0.01, 0.03, 1 })
      love.graphics.print(word, wx + 2, wy + 2)
      -- lueur additive (la couleur de halo rayonne autour du mot, pulse lente).
      if love.graphics.setBlendMode then
        local pulse = 0.5 + 0.5 * sin(t * 2.2)
        love.graphics.setBlendMode("add")
        love.graphics.setColor(halo[1], halo[2], halo[3], 0.18 + 0.12 * pulse)
        for _, o in ipairs({ { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 }, { 2, 0 }, { -2, 0 } }) do
          love.graphics.print(word, wx + o[1], wy + o[2])
        end
        love.graphics.setBlendMode("alpha")
      end
      -- le mot lui-même.
      Draw.setColor(wordCol)
      love.graphics.print(word, wx, wy)
    end

    -- ── score (sous le mot, Spectral ; ascension = Space Mono or) ──
    if opts.score and opts.score ~= "" then
      local scf = ascension and (Theme.label(12) or Theme.value(12)) or (Theme.body(13) or Theme.bodyLight(13))
      local scCol = ascension and C.gold or C.ink2
      Draw.textC(opts.score, cx, floor(y + h * 0.68 + 0.5), scCol, scf)
    end

    -- ── hint (pied, Space Mono ink5) ──
    if opts.hint and opts.hint ~= "" then
      local hf = Theme.labelSmall(9) or Theme.label(9)
      Draw.textTrackedC(opts.hint, cx, floor(y + h * 0.85 + 0.5), C.ink5, hf, 1.2)
    end
    Draw.reset()
  end

  return cx, cy
end

return Banner
