-- src/ui/modal.lua
-- MODALE plein écran OPAQUE (brique design-system). Recouvre TOUT l'écran — fini l'overlay semi-transparent
-- qui laisse voir la scène derrière (« on voit à travers »). Structurée comme la home page : titre cérémonial
-- + tag d'issue + flavor sobre + une RANGÉE DE BOUTONS de choix. Le postfx onirique (bordures) reste actif.
--
-- RENDER pur, ESPACE DESIGN. Le caller la dessine dans son drawOverlay et hit-teste les rects de boutons
-- RENVOYÉS (mêmes ids que demandés) -> aucune dépendance à un état global. Headless-safe (Draw/Button le sont).
--
--   local res = Modal.draw(view, { title=.., tag=.., tagKind="victory", flavor=.., sub=..,
--                                  buttons = { {id="x", label="CONTINUE", variant="primary"}, ... },
--                                  mx=, my=, t= })
--   -- res.buttons = { {id, x, y, w, h}, ... } (ordre = celui demandé) ; Modal.hit(res.buttons, mx, my) -> id|nil

local Draw = require("src.ui.draw")
local Theme = require("src.ui.theme")
local Button = require("src.ui.button")
local Feel = require("src.ui.feel")

local Modal = {}

local BW, BH, GAP = 196, 50, 20 -- boutons de choix (largeur/hauteur/écart)

local function accentOf(c, kind)
  if kind == "victory" then return c.gold end
  if kind == "defeat" then return c.blood end
  return c.ink2
end

-- Dessine la modale plein écran. Renvoie { buttons = { {id,x,y,w,h}, ... } } pour le hit-test du caller.
function Modal.draw(view, opts)
  opts = opts or {}
  local c = Theme.c
  local W, H = Draw.W, Draw.H
  local cx = math.floor(W / 2)

  Draw.begin(view)
  -- 1) FOND PLEIN ÉCRAN **OPAQUE** : aucune scène ne transparaît (void = noir du puits). Voile sombre par-dessus
  --    pour un dégradé sobre (haut/bas plus noirs) sans casser l'opacité.
  Draw.rect(0, 0, W, H, { c.void[1], c.void[2], c.void[3], 1 })
  Draw.rect(0, 0, W, math.floor(H * 0.30), { 0, 0, 0, 0.35 })
  Draw.rect(0, math.floor(H * 0.70), W, math.ceil(H * 0.30), { 0, 0, 0, 0.35 })

  -- 2) COLONNE CENTRÉE : titre cérémonial + tag d'issue + filet + sous-titre (cause) + flavor.
  local y = math.floor(H / 2 - 132)
  if opts.title then
    Draw.textC(opts.title, cx, y, c.ink, Theme.display(46)); y = y + 54
  end
  if opts.tag then
    Draw.textC(opts.tag, cx, y, accentOf(c, opts.tagKind), Theme.label(15)); y = y + 26
  end
  -- filet laiton court, centré (structure)
  Draw.rect(cx - 70, y + 2, 140, 1, { c.brass[1], c.brass[2], c.brass[3], 0.8 }); y = y + 16
  if opts.sub then
    Draw.textC(opts.sub, cx, y, c.faint, Theme.labelSmall(12)); y = y + 22
  end
  if opts.flavor then
    Draw.textC(opts.flavor, cx, y, c.faint, Theme.flavor(16)); y = y + 26
  end
  Draw.finish()

  -- 3) RANGÉE DE BOUTONS centrée (sous le bloc texte) — chacun cliquable, juice Feel.
  local btns = opts.buttons or {}
  local n = #btns
  local total = n * BW + math.max(0, n - 1) * GAP
  local bx0 = math.floor(cx - total / 2)
  local by = math.floor(H / 2 + 86)
  local out = {}
  Draw.begin(view)
  for i = 1, n do
    local b = btns[i]
    local x = bx0 + (i - 1) * (BW + GAP)
    local hover = opts.mx and opts.mx >= x and opts.mx <= x + BW and opts.my >= by and opts.my <= by + BH or false
    Button.draw(x, by, BW, BH, b.variant or "secondary", b.label, {
      hover = hover, feel = Feel.state(b.id), id = b.id, t = opts.t,
      mouse = (opts.mx and b.variant == "primary") and { mx = opts.mx, my = opts.my } or nil,
    })
    out[i] = { id = b.id, x = x, y = by, w = BW, h = BH }
  end
  Draw.finish()
  return { buttons = out }
end

-- Hit-test pratique : renvoie l'id du bouton sous (mx,my), sinon nil.
function Modal.hit(buttons, mx, my)
  for _, r in ipairs(buttons or {}) do
    if mx >= r.x and mx <= r.x + r.w and my >= r.y and my <= r.y + r.h then return r.id end
  end
  return nil
end

return Modal
