-- src/ui/button.lua
-- LES BOUTONS PROPRES du design system (.dc.html §2.1) — reproduction fidèle des cinq variantes du designer :
-- PRIMARY (sang, l'action unique), SECONDARY (laiton terni), ECO (compact + coût or), ICON (34×34), GHOST
-- (texte seul). Valeurs CSS EXACTES de docs/pixel-art/design-system-source.html (l.309-361). Labels Space Mono
-- trackés (Theme.label) -> NETS à toute résolution via Draw. AUCUN œil, AUCUN gritty : c'est la base propre,
-- la crasse viendra au shader. Couleurs via Theme + quelques hex spécifiques aux boutons (du .dc.html).
--
-- API : chaque fonction RENVOIE le rect cliquable { x, y, w, h } (espace design) pour le hit-test de la scène.
-- opts = { hover, pressed, disabled } (drapeaux d'état) + spécifiques (cost, kind). RENDER pur, headless-safe.

local Draw = require("src.ui.draw")
local Theme = require("src.ui.theme")
local Panel = require("src.ui.panel")
local Forge = require("src.ui.forge")
local PostFX = require("src.render.postfx") -- COLLECTEUR de rects : la distorsion onirique se confine aux BORDURES des box
local C = Theme.c
local H = Theme.hex

local Button = {}

-- Jeux de couleurs par variante/état : { dégradé top, dégradé bottom, couleur de label, [bordure] }.
local PRIMARY = {
  idle     = { H(0x7a1d16), H(0x4c130f), H(0xf3dcc6) },
  hover    = { H(0x9c281e), H(0x5e1812), H(0xf7e7d4) },
  pressed  = { H(0x43110d), H(0x5a1611), H(0xe9cbb6) },
  disabled = { C.stone800,  C.stone800,  C.ink5 },
}
local SECONDARY = {
  idle     = { H(0x1d1826), H(0x141019), C.ink2 },
  hover    = { H(0x272031), H(0x1a1622), C.ink },
  pressed  = { H(0x100d16), H(0x100d16), C.ink2 },
  disabled = { C.stone900,  C.stone900,  C.ink5 },
}
local ECO = {
  idle     = { H(0x221709), H(0x170f06), C.ink2, H(0x4a3514) },
  hover    = { H(0x33240e), H(0x231708), C.ink,  H(0x6a4a22) },
  pressed  = { H(0x1a1207), H(0x140d05), C.ink2, H(0x4a3514) },
  disabled = { H(0x130d07), H(0x130d07), C.ink5, H(0x2a2012) },
}
local ICONBG = { idle = { H(0x1d1826), H(0x141019) }, hover = { H(0x272031), H(0x1a1622) } }
local SHADOW = H(0x000000)

local SETS = { primary = PRIMARY, secondary = SECONDARY, eco = ECO }
local TRACK = { primary = 2.0, secondary = 1.7, eco = 1.3 } -- ~letter-spacing em × px
local PX = { primary = 13, secondary = 12, eco = 11 }

local function stateOf(opts)
  opts = opts or {}
  if opts.disabled then return "disabled" end
  if opts.pressed then return "pressed" end
  if opts.hover then return "hover" end
  return "idle"
end

local function fillRect(x, y, w, h, c)
  if not (love and love.graphics) then return end
  Draw.setColor(c); love.graphics.rectangle("fill", x, y, w, h); Draw.reset()
end

-- Bouton plein PRIMARY/SECONDARY/ECO. text en CAPITALES (la scène fournit déjà la casse i18n).
-- variant ∈ "primary"|"secondary"|"eco". Pour ECO : opts.cost = valeur d'or (losange + nombre à droite).
--
-- ⭐ JUICE (bible §4) : opts.feel = état Feel.state(id) (RENDER pur, piloté par dt) -> le bouton lit
--   { lift, squash, flash, glow } pour réagir « au doigt » : LIFT au survol (on bouge le bouton, pas de
--   scale qui casse la grille), SQUASH supplémentaire au press, FLASH bref de braise au DOWN, GLOW de halo
--   qui enfle. opts.feel ABSENT -> comportement d'origine EXACT (le design-system fige des états statiques).
function Button.draw(x, y, w, h, variant, text, opts)
  opts = opts or {}
  x, y, w, h = math.floor(x + 0.5), math.floor(y + 0.5), math.floor(w + 0.5), math.floor(h + 0.5)
  local set = SETS[variant] or SECONDARY
  local st = stateOf(opts)
  local s = set[st]
  local feel = opts.feel
  -- LIFT (survol) : remonte le bouton de quelques px ; SQUASH (press) : enfoncement piloté par feel (en plus
  -- du sink discret d'état). On planche pour rester pixel-net (positions entières) et borné (jamais > 4px).
  local lift = feel and math.floor((feel.lift or 0) + 0.5) or 0
  local squash = feel and math.floor((feel.squash or 0) + 0.5) or 0
  local press = ((st == "pressed") and 1 or 0) + squash -- translateY au press (état) + squash (feel)
  if press > 4 then press = 4 end
  local yy = y - lift + press           -- repos relevé par le survol, enfoncé par le press
  local hh = h - press
  PostFX.markBox(x, yy, w, hh) -- ★ enregistre la box RÉELLEMENT dessinée (lift/press inclus) -> l'anneau colle au bord

  if press == 0 then fillRect(x, yy + h - 1, w, 2, SHADOW) end -- ombre portée (relief 0 2px 0)
  Panel.vgrad(x, yy, w, hh, s[1], s[2])
  if st ~= "disabled" then fillRect(x + 1, yy + 1, w - 2, 1, { C.brassS[1], C.brassS[2], C.brassS[3], 0.10 }) end
  -- NOTE : le « tangage onirique » des bords n'est PLUS dessiné par bouton (ancienne polyligne ondulée retirée).
  -- Il est désormais porté globalement par le shader de distorsion d'UV de src/render/postfx.lua (les vrais
  -- pixels ondulent en périphérie ; centre net via masque radial) -> plus de ligne superposée.
  Draw.rect(x, yy, w, hh, nil, s[4] or C.iron, 1)
  -- HALO de survol/feel : sur le CTA, un liseré sang dont l'alpha enfle avec le glow (braise, pas blanc).
  local glow = feel and (feel.glow or 0) or 0
  if variant == "primary" and (st == "hover" or glow > 0.02) then
    local a = 0.22 + 0.30 * glow
    Draw.setColor(C.blood, math.min(0.6, a))
    if love and love.graphics then love.graphics.rectangle("line", x - 1, yy - 1, w + 2, hh + 2) end
    Draw.reset()
  end
  -- FLASH de press (bref) : voile additif de braise par-dessus la surface -> l'« impact » au DOWN.
  local flash = feel and (feel.flash or 0) or 0
  if flash > 0.01 and st ~= "disabled" and love and love.graphics then
    Draw.setColor(C.ember, math.min(0.5, flash))
    love.graphics.rectangle("fill", x + 1, yy + 1, w - 2, hh - 2)
    Draw.reset()
  end

  -- ⭐ YEUX CAUCHEMARDESQUES (CTA primary uniquement) : au SURVOL des yeux s'ouvrent à des positions seedées
  -- (jamais sur le texte : keep-out du label), pilotés par le glow ; au CLIC ils RÉAGISSENT (s'écarquillent +
  -- iris vif + regard) via le flash. Repos -> open≈0 -> no-op (bouton propre). Le label étant dessiné APRÈS,
  -- il reste TOUJOURS au-dessus des yeux. On passe l'EMPREINTE RÉELLE du label (Space Mono, en art-px) pour
  -- que le keep-out colle au texte AFFICHÉ. opts.id = clé de cache stable (sinon dérivée du texte+position).
  if variant == "primary" and st ~= "disabled" and (glow > 0.02 or flash > 0.01) then
    local epx = Forge.PX or 2 -- densité du blit des yeux (art-px -> px design)
    local lf = Theme.label(PX[variant] or 13)
    local lw = lf and Draw.textWidth(text, lf) or 0
    local ntrack = math.max(0, #tostring(text) - 1) * (TRACK[variant] or 1.5)
    local labelW = (lw + ntrack) / epx                       -- largeur du label vivant en ART-px
    local labelH = ((lf and lf.getHeight and lf:getHeight()) or 13) / epx -- hauteur en ART-px
    local eid = "btn.eyes." .. (opts.id or tostring(text) .. ":" .. x .. "," .. y)
    Forge.uiCtaEyes(eid, x, yy, w, hh, text, {
      open = glow, react = flash, mouse = opts.mouse, t = opts.t,
      labelW = labelW, labelH = labelH, eyeR = math.max(4, math.floor(hh / epx / 4)), pad = 3, frameTh = 2,
    })
  end

  local px = PX[variant] or 12
  local f = Theme.label(px)
  local fh = (f and f.getHeight and f:getHeight()) or px
  local ty = yy + (hh - fh) / 2
  -- ECO : on réserve la place du coût (losange + nombre) à droite du label, centré sur l'espace restant.
  local costW = (variant == "eco" and opts.cost ~= nil) and 22 or 0
  local cx = x + (w - costW) / 2
  if st ~= "disabled" then Draw.textTrackedC(text, cx, ty + 1, SHADOW, f, TRACK[variant] or 1.5) end -- ombre texte
  Draw.textTrackedC(text, cx, ty, s[3], f, TRACK[variant] or 1.5)
  if variant == "eco" and opts.cost ~= nil then
    local gx = x + w - 16
    if opts.disabled then
      Draw.textTrackedC(tostring(opts.cost), gx, ty, C.ink5, f, 0)
    else
      Forge.diamondAt(gx, yy + hh / 2, 3, C.gold, C.brassD)
      Draw.text(tostring(opts.cost), gx + 6, ty, C.gold, f)
    end
  end
  return { x = x, y = y, w = w, h = h }
end

-- GHOST : texte seul (REFUSE, [esc] back). Survol = encre vive + soulignement sang.
function Button.ghost(x, y, w, h, text, opts)
  opts = opts or {}
  x, y, w, h = math.floor(x + 0.5), math.floor(y + 0.5), math.floor(w + 0.5), math.floor(h + 0.5)
  local hover = opts.hover and not opts.disabled
  local col = opts.disabled and C.ink5 or (hover and C.ink or C.ink3)
  local f = Theme.label(11)
  local fh = (f and f.getHeight and f:getHeight()) or 11
  Draw.textTrackedC(text, x + w / 2, y + (h - fh) / 2, col, f, 1.3)
  if hover then
    local tw = Draw.textWidth(text, f)
    fillRect(x + (w - tw) / 2, y + h - 3, tw, 1, C.blood)
  end
  return { x = x, y = y, w = w, h = h }
end

-- Glyphe d'icône (sigil/prev/next/gear) centré, en brass-l. Dessiné net (vectoriel).
local function glyph(kind, cx, cy)
  if not (love and love.graphics) then return end
  Draw.setColor(C.brassL)
  if kind == "sigil" then
    love.graphics.push(); love.graphics.translate(cx, cy); love.graphics.rotate(math.pi / 4)
    love.graphics.rectangle("fill", -5, -5, 10, 10); love.graphics.pop()
  elseif kind == "prev" or kind == "next" then
    local d = (kind == "next") and 1 or -1
    love.graphics.setLineWidth(2)
    love.graphics.line(cx - 3 * d, cy - 5, cx + 3 * d, cy, cx - 3 * d, cy + 5)
    love.graphics.setLineWidth(1)
  else -- gear : disque + dents simplifiées
    love.graphics.circle("fill", cx, cy, 5)
    Draw.setColor(C.stone900); love.graphics.circle("fill", cx, cy, 2)
  end
  Draw.reset()
end

-- ICON 34×34 (ou size). kind ∈ "sigil"|"prev"|"next"|"gear".
function Button.icon(x, y, size, kind, opts)
  opts = opts or {}
  size = size or 34
  x, y = math.floor(x + 0.5), math.floor(y + 0.5)
  local st = (opts.hover and not opts.disabled) and "hover" or "idle"
  local bg = ICONBG[st]
  local press = (opts.pressed and not opts.disabled) and 1 or 0
  PostFX.markBox(x, y + press, size, size - press) -- ★ box réellement dessinée -> anneau de distorsion sur son bord
  Panel.vgrad(x, y + press, size, size - press, bg[1], bg[2])
  if not opts.disabled then fillRect(x + 1, y + 1 + press, size - 2, 1, { C.brassS[1], C.brassS[2], C.brassS[3], 0.10 }) end
  Draw.rect(x, y + press, size, size - press, nil, C.iron, 1)
  glyph(kind, x + size / 2, y + size / 2 + press)
  return { x = x, y = y, w = size, h = size }
end

return Button
