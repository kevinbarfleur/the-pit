-- src/ui/frame.lua
-- ENCADRÉ « forge » RÉUTILISABLE — la signature visuelle du jeu. C'est l'API STABLE que TOUTE l'UI appelle
-- (boutons de scène, cases, cartes, panneaux) ; depuis la refonte « Reliquary » son RENDU est le KIT MÉTAL
-- (src/ui/forge.lua, port de docs/pixel-art/forge-px.js) : biseau métal DUR (liseré iron net, haut/gauche
-- éclairés spec->base, bas/droite ombrés deep->mid), patine seedée, rivets de coin, plaque CONVEXE encastrée,
-- et — pour les HÉROS (gilded/selected/danger/drop) — un liseré d'accent INTERNE (laiton brossé) + GLINT de
-- coin + chanfreins. On GARDE la signature publique : Frame.draw(x,y,w,h,opts) -> (ix,iy,iw,ih).
--
-- L'encadré est BAKÉ une fois (cache Forge par id) et blité nearest -> aucun millier de rectangle()/frame ;
-- les call-sites héritent du look sans réécriture. La LUEUR de survol (state.glow) reste un voile VIVANT
-- (love.graphics, non baké) pour ne pas thrasher le cache au hover. Couche RENDER pure (espace design 1280×720,
-- sous Draw.begin). Headless-safe : Forge no-op proprement (le bake ne crashe pas sous le mock LÖVE).
--
-- TROIS NIVEAUX (décision « dorures réservées aux héros ») :
--   plain   -> liseré + plaque, biseau MINCE, jamais d'accent interne (listes denses, désactivé).
--   bevel   -> biseau métal complet, sans liseré d'accent interne. DÉFAUT.
--   gilded  -> biseau ÉPAISSI + liseré d'accent interne + glint + chanfreins : héros (CTA, sélection, R4-R5).
-- ÉTATS (Theme.state) : idle/hover/pressed/disabled/selected/danger/drop modulent biseau/plaque/accent.
--
-- `px` = taille de l'« art-pixel » en px design (défaut 2 -> granularité créatures). Le biseau fait `th`
-- art-px ; l'épaisseur design du cadre vaut donc th*px. Retourne la ZONE INTÉRIEURE (ix,iy,iw,ih).

local Theme = require("src.ui.theme")
local Forge = require("src.ui.forge")
local C = Theme.c

local Frame = {}

local floor = math.floor

-- Compteur d'ids ANONYMES : un site qui n'a pas fourni opts.id reçoit une clé de cache stable par POSITION
-- (x,y,w,h) — la grande majorité des encadrés sont à position fixe (HUD, cases, panneaux), donc cette clé est
-- stable d'une frame à l'autre. Un site qui RECYCLE une position (listes scrollées) DOIT passer opts.id pour
-- éviter les collisions de cache. (Le bake ne dépend que de la SIGNATURE, donc une collision = au pire un
-- re-bake, jamais un crash.)
local function autoId(x, y, w, h)
  return "f:" .. floor(x) .. "," .. floor(y) .. "," .. floor(w) .. "x" .. floor(h)
end

-- Résout opts.state (nom Theme.state OU descripteur table) -> table d'état.
local function resolveState(opts)
  return type(opts.state) == "table" and opts.state or Theme.stateOf(opts.state)
end

-- Construit la spec forge (framedPlate) depuis les opts publics. accent (couleur de rareté, floats 0..1) ->
-- triple {dark,mid,bright} via Forge.accentFrom. tint danger -> lavage de la plaque vers le sang.
local function forgeSpec(opts, st, px)
  local level = opts.level or "bevel"
  local flat = st.flat or level == "plain"
  local gild = (not flat) and (level == "gilded" or st.gild) and true or false
  -- couleur d'accent du liseré : override explicite > accent de l'état > or (héros) ; sobre sinon.
  local accentCol
  local accSrc = opts.accent or st.accent
  if gild or accSrc then accentCol = Forge.accentFrom(accSrc or C.gold) end
  -- lavage de plaque : danger (fond sang) ou tint explicite.
  local tint = opts.tint
  if not tint and st.fill == C.bloodDeep then tint = Forge.tintFrom(C.blood, 0.22) end
  return {
    fill = (opts.fill ~= false),                  -- fill=false -> cadre sur contenu (centre transparent)
    th = flat and 2 or 3,                          -- biseau mince (plain) / complet (bevel/gilded)
    gild = gild,
    inset = st.inset and true or nil,              -- pressed -> plaque enfoncée
    disabled = (st.flat and level ~= "plain") or st.text == C.ghost or nil, -- état désactivé (à plat + gris)
    accentCol = accentCol,
    tint = tint,
    seed = opts.seed,
    px = px,
  }, gild and 4 or (flat and 2 or 3) -- th effectif (gild = +1) pour le calcul de la zone intérieure
end

-- Dessine l'encadré. opts = { id?, level, state, fill, accent, tint, px, seed, font }.
-- Retourne (ix, iy, iw, ih) = la zone intérieure utile (sous le biseau).
function Frame.draw(x, y, w, h, opts)
  opts = opts or {}
  x, y, w, h = floor(x), floor(y), floor(w), floor(h)
  local px = opts.px or 2
  local st = resolveState(opts)

  local spec, thEff = forgeSpec(opts, st, px)
  local id = opts.id or autoId(x, y, w, h)
  Forge.uiFrame(id, x, y, w, h, spec)

  -- ZONE INTÉRIEURE : sous le biseau (thEff art-px -> thEff*px design). Bornée à >= 0.
  local ring = thEff * px
  local ix, iy = x + ring, y + ring
  local iw, ih = math.max(0, w - 2 * ring), math.max(0, h - 2 * ring)

  -- LUEUR de survol : voile chaud VIVANT (non baké) sur l'intérieur — l'« émissif » qui monte au hover.
  local glow = st.glow or 0
  if glow > 0 and iw > 0 and ih > 0 and love and love.graphics then
    local g = love.graphics
    g.setColor(C.gold[1], C.gold[2], C.gold[3], 0.08 * glow)
    g.rectangle("fill", ix, iy, iw, ih)
    g.setColor(1, 1, 1, 1)
  end
  return ix, iy, iw, ih
end

-- Bouton : encadré + LABEL centré (h/v) en OVERLAY VIVANT (Forge.label -> vraie police, toujours lisible,
-- aucun readback de glyphe) + décalage « enfoncé » sur pressed. opts comme draw + font (police du label) et
-- text (couleur du label, override de l'état). Retourne la zone intérieure.
function Frame.button(x, y, w, h, label, opts)
  opts = opts or {}
  local ix, iy, iw, ih = Frame.draw(x, y, w, h, opts)
  if label and label ~= "" then
    local st = resolveState(opts)
    local font = opts.font or (love and love.graphics and love.graphics.getFont and love.graphics.getFont())
    local tcol = opts.text or st.text or C.body
    local dx = st.inset and (opts.px or 2) or 0
    if love and love.graphics and font then
      local g = love.graphics
      g.setFont(font)
      local tw = font:getWidth(label)
      local fh = font:getHeight()
      -- OMBRE portée (détache de la pierre) + label.
      local lx = floor(x + (w - tw) / 2 + dx + 0.5)
      local ly = floor(y + (h - fh) / 2 + dx + 0.5)
      g.setColor(0.04, 0.03, 0.02, 0.85)
      g.print(label, lx + 1, ly + 1)
      -- halo doré au survol (additif léger) : la lueur des runes héros sur le texte.
      local glow = st.glow or 0
      if glow > 0.02 and g.setBlendMode then
        g.setBlendMode("add")
        g.setColor(0.95, 0.82, 0.45, glow * 0.22)
        g.print(label, lx + 1, ly); g.print(label, lx - 1, ly); g.print(label, lx, ly + 1); g.print(label, lx, ly - 1)
        g.setBlendMode("alpha")
      end
      g.setColor(tcol[1], tcol[2], tcol[3], tcol[4] or 1)
      g.print(label, lx, ly)
      g.setColor(1, 1, 1, 1)
    end
  end
  return ix, iy, iw, ih
end

return Frame
