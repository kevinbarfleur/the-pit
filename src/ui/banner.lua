-- src/ui/banner.lua
-- MOLÉCULE « bandeau de destin » (design-system §2.19) — le grand verdict sur l'arène assombrie :
--   • VICTORY   — mot OR (Jacquard), halo doré, sous-titre + score + hint.
--   • DEFEAT    — mot SANG (Jacquard), halo sang.
--   • ASCENSION — mot OS/ink (Jacquard), liseré laiton + lueur de braise montante.
-- C'est le SEUL endroit (avec le logotype) où la voix CÉRÉMONIALE Jacquard est employée — « les grands mots
-- du destin », rarissimes (cf. theme.lua / design-system §II). Double FILET gravé en haut et en bas du mot.
--
-- ── ARCHI ─────────────────────────────────────────────────────────────────────────────────────────
-- On BAKE la signature pixel (les deux filets métal + un voile de halo radial coloré selon kind) dans un
-- widget Forge caché par id ; le MOT et les lignes de texte sont dessinés en OVERLAY VIVANT (Jacquard pour
-- le mot, Space Mono pour sous-titre/hint, Spectral pour le score). Le mot pulse doucement (lueur de glow).
-- RENDER pur, espace DESIGN, HEADLESS-SAFE (bake pcall-gardé + overlays no-op sans police).
--
-- Banner.draw(x, y, w, kind, word, opts) :
--   x,y     coin haut-gauche en ESPACE DESIGN ; w = largeur (le bandeau fait une HAUTEUR fixe, voir H()).
--   kind    "victory" | "defeat" | "ascension"   (pilote couleur + halo).
--   word    le grand mot (déjà résolu i18n ; ex. "VICTORY"). Affiché tel quel en Jacquard.
--   opts = { subtitle?, score?, hint?, id?, t?, h? }
--     subtitle : kicker au-dessus du mot (Space Mono caps tracké, ink3).
--     score    : ligne sous le mot (Spectral, ink2) — ex. récap de combat.
--     hint     : pied (Space Mono, ink5) — ex. « [SPACE] continue ».
--     h        : hauteur (défaut 170, comme la maquette §2.19).
--   Retourne (cx, cy) = centre du bandeau (pour composer un overlay au-dessus si besoin).

local Theme = require("src.ui.theme")
local Draw = require("src.ui.draw")
local Forge = require("src.ui.forge")
local C = Theme.c

local Banner = {}

local floor, max, abs, sin = math.floor, math.max, math.abs, math.sin

local DEFAULT_H = 170 -- §2.19 : « height 170px »

-- Profil de couleur par kind : { word(floats), glow(octets bake), halo(octets bake) }.
local function kindProfile(kind)
  if kind == "defeat" then
    return C.bloodL, { 232, 72, 60 }, { 120, 20, 16 }
  elseif kind == "ascension" then
    return C.ink, { 216, 182, 94 }, { 196, 102, 58 } -- mot os/ink, halo de braise (ember)
  else -- victory (défaut)
    return C.gold, { 242, 217, 138 }, { 150, 40, 20 }
  end
end

-- ── BAKE : halo radial + double filet gravé (haut/bas du mot) ──────────────────────────────────────
local function bakeBanner(buf, W, H, p)
  local halo = p.halo
  local cxp, cyp = W / 2, H * 0.45 -- centre du halo (légèrement haut, comme la maquette)
  local maxd = math.sqrt(cxp * cxp + cyp * cyp)
  -- HALO radial doux (assombri vers les bords) : la lueur du verdict baigne le centre.
  for y = 0, H - 1 do
    for x = 0, W - 1 do
      local dx, dy = (x - cxp), (y - cyp)
      local d = math.sqrt(dx * dx + dy * dy) / maxd
      local a = max(0, 1 - d * 1.35)
      if a > 0.01 then
        buf:add(x, y, halo, a * (p.ascension and 0.16 or 0.13))
      end
    end
  end
  -- ASCENSION : remontée de braise au BAS (radial inférieur), plus chaude.
  if p.ascension then
    for y = floor(H * 0.55), H - 1 do
      for x = 0, W - 1 do
        local dx = (x - cxp) / (W * 0.5)
        local dy = (y - (H - 1)) / (H * 0.5)
        local d = math.sqrt(dx * dx + dy * dy)
        local a = max(0, 1 - d)
        if a > 0.01 then buf:add(x, y, { 196, 102, 58 }, a * 0.12) end
      end
    end
  end
  -- DOUBLE FILET gravé (haut/bas du mot) : deux lignes métal qui fadent vers les bords (port de drawBanner).
  local my = floor(H / 2 + 0.5)
  local span = floor(H * 0.30)
  for _, ry in ipairs({ -1, 1 }) do
    local yy = my + ry * span
    for x = 3, W - 4 do
      local a = 1 - abs(x - W / 2) / (W / 2 - 3)
      buf:set(x, yy, { 8 + (216 - 8) * 0.55 * a, 5 + (182 - 5) * 0.55 * a, 3 + (94 - 3) * 0.55 * a })
    end
    -- petite perle losange au centre de chaque filet (signature divider).
    Forge.diamond(buf, floor(W / 2 + 0.5), yy, 2, { 156, 122, 54 }, { 8, 5, 3 }, { 242, 217, 138 })
  end
end

Banner._cache = {}

function Banner.draw(x, y, w, kind, word, opts)
  opts = opts or {}
  kind = kind or "victory"
  x, y, w = floor(x), floor(y), floor(w)
  local h = floor(opts.h or DEFAULT_H)
  local px = opts.px or Forge.PX
  local id = opts.id or ("bn:" .. kind .. ":" .. floor(x) .. "," .. floor(y) .. "x" .. floor(w))
  local t = opts.t or 0
  local wordCol, glow, halo = kindProfile(kind)
  local ascension = (kind == "ascension")

  -- 1) BAKE de la signature (halo + filets) — re-bake si géométrie/kind change (le halo est statique ;
  --    pas besoin de re-baker chaque frame -> on garde l'Image si la signature est stable). Headless-safe.
  local aw, ah = max(1, floor(w / px)), max(1, floor(h / px))
  local e = Banner._cache[id]
  if not e or e.aw ~= aw or e.ah ~= ah then
    e = { widget = Forge.newWidget(aw, ah), aw = aw, ah = ah }
    Banner._cache[id] = e
  end
  local sig = kind .. "|" .. aw .. "x" .. ah
  if e.sig ~= sig or not e.image then
    e.sig = sig
    e.image = Forge.render(e.widget, function(b, W, H, _)
      bakeBanner(b, W, H, { halo = halo, ascension = ascension })
    end, 0)
  end
  Forge.blit(e.image, x, y, px)

  local cx, cy = x + w / 2, y + h / 2

  -- 2) OVERLAYS (Jacquard pour le MOT, Space Mono/Spectral pour les lignes). No-op headless via Draw.
  if love and love.graphics and love.graphics.print then
    -- ── sous-titre (kicker) au-dessus du mot ──
    if opts.subtitle and opts.subtitle ~= "" then
      local sf = ascension and (Theme.flavor(12) or Theme.bodyItalic(12)) or (Theme.labelSmall(10) or Theme.label(10))
      Draw.textTrackedC(opts.subtitle, cx, floor(y + h * 0.16 + 0.5), C.ink3, sf, ascension and 0 or 2.0)
    end

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
      -- lueur additive (la couleur de glow rayonne autour du mot, pulse lente).
      if love.graphics.setBlendMode then
        local pulse = 0.5 + 0.5 * sin(t * 2.2)
        love.graphics.setBlendMode("add")
        love.graphics.setColor(glow[1] / 255, glow[2] / 255, glow[3] / 255, 0.18 + 0.12 * pulse)
        for _, o in ipairs({ { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 }, { 2, 0 }, { -2, 0 } }) do
          love.graphics.print(word, wx + o[1], wy + o[2])
        end
        love.graphics.setBlendMode("alpha")
      end
      -- le mot lui-même.
      Draw.setColor(wordCol)
      love.graphics.print(word, wx, wy)
    end

    -- ── score (sous le mot, Spectral) ──
    if opts.score and opts.score ~= "" then
      local scf = ascension and (Theme.label(12) or Theme.value(12)) or (Theme.body(13) or Theme.bodyLight(13))
      local scCol = ascension and C.gold or C.ink2
      Draw.textC(opts.score, cx, floor(y + h * 0.66 + 0.5), scCol, scf)
    end

    -- ── hint (pied, Space Mono ink5) ──
    if opts.hint and opts.hint ~= "" then
      local hf = Theme.labelSmall(9) or Theme.label(9)
      Draw.textTrackedC(opts.hint, cx, floor(y + h * 0.84 + 0.5), C.ink5, hf, 1.2)
    end
    Draw.reset()
  end

  return cx, cy
end

return Banner
