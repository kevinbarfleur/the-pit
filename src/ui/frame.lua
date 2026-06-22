-- src/ui/frame.lua
-- ENCADRÉ « runique » RÉUTILISABLE — la signature visuelle du jeu (biseau bronze + accents dorés),
-- extraite de render/healthbar.lua pour que TOUTE l'UI parle la même langue (boutons, cases, cartes,
-- panneaux). Couche RENDER pure (love.graphics) ; dessinée en ESPACE DESIGN 1280x720 (sous Draw.begin).
--
-- TROIS NIVEAUX d'intensité (décision « dorures réservées aux héros ») :
--   plain   -> liseré sombre + fond plat (listes denses, état désactivé).
--   bevel   -> biseau bronze (haut/gauche clairs, bas/droite sombres) : « métal ciselé », SANS or. Défaut.
--   gilded  -> biseau + STUDS dorés aux 4 coins + ergots latéraux : réservé aux héros (CTA, sélection, R4-R5).
--
-- ÉTATS interactifs (Theme.state) : idle/hover/pressed/disabled/selected/danger/drop modulent le biseau
--   (hover = bronze chaud + lueur interne ; pressed = biseau inversé + label enfoncé ; disabled = à plat ;
--    selected/danger = gildé forcé). Un SEUL vocabulaire d'état pour fini les hover gold/eco/blood divergents.
--
-- `px` = taille de l'« art-pixel » en px design (défaut 2) : épaisseur du liseré/biseau/stud -> chunkiness
--   alignée sur la barre de vie (scale ×2). Retourne la ZONE INTÉRIEURE (ix, iy, iw, ih) pour y poser le contenu.

local Theme = require("src.ui.theme")
local C = Theme.c
local H = Theme.hex

local Frame = {}

-- Bronzes de l'encadré (repris de render/healthbar : identité visuelle commune au jeu).
local OUT     = H(0x0a0608) -- liseré extérieur (presque noir, chaud)
local LIT     = H(0x82602a) -- métal éclairé (haut/gauche)
local DARK    = H(0x3a2a14) -- métal ombré (bas/droite)
local LIT_HOT = H(0xb0863a) -- métal survolé (bronze plus chaud)

-- Éclaircit c vers le blanc de t∈[0,1] (pour le stud haut, plus brillant que l'accent du bas).
local function lighten(c, t)
  return { c[1] + (1 - c[1]) * t, c[2] + (1 - c[2]) * t, c[3] + (1 - c[3]) * t, c[4] or 1 }
end

-- Pose un rectangle plein (coords planchées -> net). Ignore taille<=0 ou couleur absente.
local function fillRect(x, y, w, h, col, a)
  if w <= 0 or h <= 0 or not col then return end
  love.graphics.setColor(col[1], col[2], col[3], a or col[4] or 1)
  love.graphics.rectangle("fill", math.floor(x), math.floor(y), math.floor(w), math.floor(h))
end

-- Dessine l'encadré. opts = { level, state, fill, accent, px, font }.
--   level  : "plain"|"bevel"|"gilded" (défaut "bevel").
--   state  : nom (Theme.state) ou descripteur table (défaut "idle").
--   fill   : couleur intérieure (override) ; false = pas de fond (cadre sur contenu, ex. portrait).
--   accent : couleur des studs/ergots (override ; ex. couleur de rareté R5). Défaut = accent de l'état.
--   px     : art-pixel en px design (défaut 2).
-- Retourne (ix, iy, iw, ih) = la zone intérieure utile.
function Frame.draw(x, y, w, h, opts)
  opts = opts or {}
  local p = opts.px or 2
  x, y, w, h = math.floor(x), math.floor(y), math.floor(w), math.floor(h)

  local st = type(opts.state) == "table" and opts.state or Theme.stateOf(opts.state)
  local level = opts.level or "bevel"
  local flat = st.flat or level == "plain"
  local gild = (not flat) and (level == "gilded" or st.gild)
  local hot = (st.glow or 0) > 0

  local fill = opts.fill
  if fill == nil then fill = st.fill end
  if fill == nil then fill = C.panelDeep end
  local accent = opts.accent or st.accent or C.gold

  local ring = flat and p or (2 * p) -- épaisseur totale du cadre (liseré [+ biseau])
  local ix, iy = x + ring, y + ring
  local iw, ih = w - 2 * ring, h - 2 * ring

  -- INTÉRIEUR (fill=false -> on laisse passer le contenu sous-jacent).
  if fill then fillRect(ix, iy, iw, ih, fill) end

  -- LISERÉ extérieur sombre (toujours, sur les 4 bords).
  fillRect(x, y, w, p, OUT); fillRect(x, y + h - p, w, p, OUT)
  fillRect(x, y, p, h, OUT); fillRect(x + w - p, y, p, h, OUT)

  if not flat then
    -- BISEAU : haut/gauche clairs, bas/droite sombres. pressed -> inversé (lecture « enfoncé »).
    local litCol = hot and LIT_HOT or LIT
    local lit  = st.inset and DARK or litCol
    local dark = st.inset and litCol or DARK
    fillRect(x + p, y + p, w - 2 * p, p, lit)            -- haut
    fillRect(x + p, y + p, p, h - 2 * p, lit)            -- gauche
    fillRect(x + p, y + h - 2 * p, w - 2 * p, p, dark)   -- bas
    fillRect(x + w - 2 * p, y + p, p, h - 2 * p, dark)   -- droite

    if gild then
      -- STUDS dorés aux 4 coins (hauts plus brillants) + ergots runiques au milieu des flancs.
      local top = lighten(accent, 0.30)
      fillRect(x + p, y + p, p, p, top); fillRect(x + w - 2 * p, y + p, p, p, top)
      fillRect(x + p, y + h - 2 * p, p, p, accent); fillRect(x + w - 2 * p, y + h - 2 * p, p, p, accent)
      local midY = y + math.floor(h / 2) - p
      fillRect(x, midY, p, 2 * p, accent); fillRect(x + w - p, midY, p, 2 * p, accent)
    end
  end

  -- LUEUR interne au survol : voile chaud léger sur l'intérieur (pas de texture -> additif simple via alpha).
  if hot and iw > 0 and ih > 0 then
    love.graphics.setColor(C.gold[1], C.gold[2], C.gold[3], 0.07 * st.glow)
    love.graphics.rectangle("fill", ix, iy, iw, ih)
  end

  love.graphics.setColor(1, 1, 1, 1)
  return ix, iy, iw, ih
end

-- Bouton : encadré + label centré (h/v), avec décalage « enfoncé » sur l'état pressed. opts comme draw +
--   font (police du label) et text (couleur du label, override de l'état). Retourne la zone intérieure.
function Frame.button(x, y, w, h, label, opts)
  opts = opts or {}
  local ix, iy, iw, ih = Frame.draw(x, y, w, h, opts)
  if label then
    local st = type(opts.state) == "table" and opts.state or Theme.stateOf(opts.state)
    local font = opts.font or love.graphics.getFont()
    if font then love.graphics.setFont(font) end
    local tcol = opts.text or st.text or C.body
    local dx = st.inset and (opts.px or 2) or 0
    local tw = font and font:getWidth(label) or 0
    local fh = font and font:getHeight() or 0
    love.graphics.setColor(tcol[1], tcol[2], tcol[3], tcol[4] or 1)
    love.graphics.print(label,
      math.floor(x + (w - tw) / 2 + dx + 0.5),
      math.floor(y + (h - fh) / 2 + dx + 0.5))
    love.graphics.setColor(1, 1, 1, 1)
  end
  return ix, iy, iw, ih
end

return Frame
