-- src/ui/relic_card.lua
-- MOLÉCULE « carte de relique » (design-system §2.13) — la fiche d'une relique, en deux états de mystère :
--   • identified : gemme losange (teinte de famille) + ŒIL au centre + NOM gravé (Cinzel) + « KNOWN EFFECT »
--     (prose Spectral, les VALEURS du texte d'effet en Space Mono sang) + flavor (Spectral italique).
--   • cryptic    : même charpente mais TEINTE VIOLETTE (rot), gemme HACHURÉE + « ? » central, nom « ? ? ? ».
--   • selected   : lueur ÉLEVÉE (la gemme pulse, le liseré s'allume) — la carte « rayonne » (offre 1-parmi-3).
--
-- ── ARCHI (cohérente avec MonsterCard / RelicPick) ────────────────────────────────────────────────
-- On BAKE la SIGNATURE PIXEL (cadre métal patiné + veines + gemme + œil + hachures cryptiques) dans un
-- widget Forge caché par id (Forge.newWidget/render/blit) ; on dessine le TEXTE en OVERLAY VIVANT (vraies
-- voix typographiques : Cinzel/Spectral/Space Mono) par-dessus, via les helpers Draw (UTF-8-safe). C'est le
-- parti pris du design system (Silkscreen baké = l'AVANT ; le contenu lisible = les polices vectorielles).
-- Les valeurs chiffrées de l'effet sont mises en Space Mono `bloodL` par un découpage par MOTS (jamais par
-- octet -> multi-octets sûrs) : un token « +15% » / « 2 » devient sang, le reste reste Spectral ink.
--
-- ── CONTRAT ───────────────────────────────────────────────────────────────────────────────────────
-- RENDER pur (love.graphics), espace DESIGN 1280×720 (sous Draw.begin). HEADLESS-SAFE : le bake Forge est
-- déjà pcall-gardé + no-op sous le mock ; les overlays texte no-op sans police. Ne touche AUCUNE couche SIM.
--
-- RelicCard.draw(x, y, w, h, opts) :
--   opts = {
--     state   = "identified" | "cryptic" | "selected"   (défaut "identified" ; "selected" => identifiée + lueur)
--     name    = nom de la relique (déjà résolu i18n)     -- ignoré en cryptic (affiche "? ? ?")
--     effect  = texte d'effet (déjà résolu i18n)          -- en cryptic, sert de prose énigmatique (Spectral it.)
--     flavor  = lore (déjà résolu i18n)
--     fam     = "flesh"|"order"|"bone"|"arcane"|"abyss"   (teinte de la gemme ; défaut "bone")
--     affKey  = clé d'affliction (poison/bleed/burn/rot/shock) -> silhouette dans la gemme (optionnel)
--     status  = "NEW"|"INKED"|"SEALED"|"CRYPTIC"           (badge d'état, §2.5 ; auto-déduit si absent)
--     id      = clé de cache stable (défaut = autoId positionnel)
--     t       = horloge (s) pour l'animation (gemme/œil/liseré qui pulsent)
--     mouse   = {mx,my} (le regard de l'œil suit le curseur, comme les boutons-œil)
--   }
-- Retourne (ix, iy, iw, ih) = la zone intérieure utile (sous le biseau), pour composer au-dessus si besoin.

local Theme = require("src.ui.theme")
local Draw = require("src.ui.draw")
local Forge = require("src.ui.forge")
local Chip = require("src.ui.chip")
local C = Theme.c

local RelicCard = {}

local floor, max, min, abs = math.floor, math.max, math.min, math.abs

-- Familles -> teinte de gemme (octets, pour le bake). Réutilise Forge.FAM (palette du kit, alignée Theme.types).
local function famColors(fam)
  local f = Forge.FAM[fam] or Forge.FAM.bone
  return f.c, f.d
end

-- Clé de cache positionnelle (les cartes sont à position fixe ; une liste scrollée DOIT passer opts.id).
local function autoId(x, y, w, h)
  return "rc:" .. floor(x) .. "," .. floor(y) .. "," .. floor(w) .. "x" .. floor(h)
end

-- ── BAKE de la signature pixel (dans le tampon Forge) ──────────────────────────────────────────────
-- On porte la charpente de drawRelicCard (forge-px.js) mais SANS le texte baké (Silkscreen) : cadre métal
-- + veines + gemme (identifiée = losange de famille + œil ; cryptique = hachures + « ? » baké discret).
local function bakeCard(buf, W, H, p)
  local Eye = require("src.ui.eye") -- (chargé par forge déjà ; require local = pas de cycle au top)
  local B = 3
  local cryptic = p.cryptic
  local sel = p.selected
  local t = p.t or 0
  -- La matière de la face (plaque convexe encastrée) + le biseau métal patiné viennent de framedPlate (le
  -- moteur de Frame.draw). TEINTE de la face : violette (cryptique) ou neutre (identifiée).
  local tint = cryptic and Forge.tintFrom(C.rot, 0.16) or nil
  Forge.framedPlate(buf, W, H, {
    fill = true, th = B, seed = p.seed, tint = tint,
    accentCol = cryptic and Forge.accentFrom(C.rot)
      or (sel and Forge.accentFrom(C.gold) or nil),
    gild = sel,
  })

  -- GEMME centrale (losange) + ŒIL (identifiée) OU hachures + « ? » (cryptique).
  local cx = W / 2
  local gy = floor(H * 0.20 + 0.5)
  local gr = max(5, floor(min(W, H) * 0.12 + 0.5))
  local g = sel and (0.6 + 0.4 * Forge.pulse(t, 1)) or (cryptic and 0.25 or 0.35)

  if cryptic then
    -- gemme HACHURÉE (repeating diag) + losange violet sombre + « ? » baké discret (la vraie typo « ? » est
    -- en overlay ; ici on pose juste une trame de mystère pour que la gemme ne soit pas vide).
    local rotC = { C.rot[1] * 255, C.rot[2] * 255, C.rot[3] * 255 }
    local rotD = { C.rot[1] * 120, C.rot[2] * 120, C.rot[3] * 120 }
    for y = -gr, gr do
      for x = -gr, gr do
        if abs(x) + abs(y) <= gr then
          local hatch = ((x + y) % 4 == 0)
          local edge = (abs(x) + abs(y) >= gr - 0.5)
          buf:set(floor(cx + x + 0.5), gy + y, edge and rotC or (hatch and rotD or { 20, 13, 26 }))
        end
      end
    end
    buf:add(floor(cx - gr * 0.3 + 0.5), gy - floor(gr * 0.3 + 0.5), rotC, 0.4)
  else
    -- gemme de FAMILLE : losange teinté (couleur de la famille) + ŒIL qui guette au centre.
    local fc, fd = famColors(p.fam)
    Forge.diamond(buf, cx, gy, gr,
      { fd[1] + (fc[1] - fd[1]) * 0.45, fd[2] + (fc[2] - fd[2]) * 0.45, fd[3] + (fc[3] - fd[3]) * 0.45 },
      { fc[1] + (255 - fc[1]) * (g * 0.5), fc[2] + (255 - fc[2]) * (g * 0.5), fc[3] + (255 - fc[3]) * (g * 0.5) },
      { 255, 255, 255 })
    -- œil au centre de la gemme : regard depuis le curseur si fourni (sinon dérive lente).
    local gaze = p.gaze
    Eye.draw(buf, floor(cx + 0.5), gy, max(3, floor(gr * 0.66 + 0.5)), g, g, t, (p.seed or 5) + 1,
      { blood = 0.5, squash = 0.72, gaze = gaze })
  end

  -- FILET sous la gemme/nom (séparateur, fade vers le centre) -> repère où commence le corps.
  local divY = floor(H * 0.46 + 0.5)
  for x = 6, W - 7 do
    local a = 1 - abs(x - cx) / ((W - 12) / 2)
    buf:set(x, divY, { 8 + 200 * 0.5 * a, 5 + 178 * 0.5 * a, 3 + 94 * 0.5 * a })
  end
  Forge.diamond(buf, floor(cx + 0.5), divY, 2, { 242, 217, 138 }, { 122, 94, 36 })
  return B
end

-- ── DRAW (bake + overlays typographiques) ──────────────────────────────────────────────────────────
RelicCard._cache = {}

function RelicCard.draw(x, y, w, h, opts)
  opts = opts or {}
  x, y, w, h = floor(x), floor(y), floor(w), floor(h)
  local state = opts.state or "identified"
  local cryptic = state == "cryptic"
  local selected = state == "selected"
  local px = opts.px or Forge.PX
  local id = opts.id or autoId(x, y, w, h)
  local t = opts.t or 0
  local seed = opts.seed
  if seed == nil then
    -- graine stable par carte (nom + famille) -> veines/patine fixes.
    local s = 0
    local src = (opts.name or "") .. "|" .. (opts.fam or "bone")
    for i = 1, #src do s = (s * 131 + src:byte(i)) % 999983 end
    seed = s % 9973
  end

  -- gaze (œil suit la souris) : curseur design -> art-local de cette carte.
  local gaze
  if (not cryptic) and opts.mouse then
    gaze = { (opts.mouse.mx - x) / px, (opts.mouse.my - y) / px }
  end

  -- 1) BAKE de la signature pixel (cache par id, re-bake si géométrie/état/horloge changent — la gemme
  --    pulse et l'œil bouge, donc on re-bake chaque frame comme MonsterCard : 1 carte visible à la fois en
  --    survol/offre, c'est bon marché). Headless-safe (render no-op sous le mock).
  local aw, ah = max(1, floor(w / px)), max(1, floor(h / px))
  local e = RelicCard._cache[id]
  if not e or e.aw ~= aw or e.ah ~= ah then
    e = { widget = Forge.newWidget(aw, ah), aw = aw, ah = ah }
    RelicCard._cache[id] = e
  end
  local B = 3
  e.image = Forge.render(e.widget, function(b, W, H, tt)
    B = bakeCard(b, W, H, { cryptic = cryptic, selected = selected, fam = opts.fam,
      affKey = opts.affKey, seed = seed, t = tt, gaze = gaze })
  end, t)
  Forge.blit(e.image, x, y, px)

  -- ZONE INTÉRIEURE (sous le biseau) pour le retour + le placement du texte.
  local ring = (B + (selected and 1 or 0)) * px
  local ix, iy = x + ring, y + ring
  local iw, ih = max(0, w - 2 * ring), max(0, h - 2 * ring)

  -- 2) OVERLAYS TYPOGRAPHIQUES (vraies voix ; no-op headless via Draw -> love.graphics absent sous le mock).
  if love and love.graphics and love.graphics.print then
    local cx = x + w / 2
    -- ── badge d'état (Space Mono caps, coin haut-droit) ──
    local status = opts.status or (cryptic and "CRYPTIC" or (selected and "NEW" or "INKED"))
    do
      local sf = Theme.label(9) or Theme.value(9)
      local stCol = cryptic and C.rot or (status == "NEW" and C.ctaText or C.gold)
      Draw.textTrackedL(status, x + w - 8 - (sf and sf:getWidth(status) or 0) - 2, y + 9, stCol, sf, 0.6)
    end

    -- ── NOM (Cinzel 700 ; cryptique = « ? ? ? » sourdine) ──
    local nameY = floor(y + h * 0.30 + 0.5)
    local nf = Theme.heading(16) or Theme.subhead(16)
    local nameStr = cryptic and "? ? ?" or (opts.name or "RELIC")
    local nameCol = cryptic and C.ink3 or C.ink
    Draw.textTrackedC(nameStr, cx, nameY, nameCol, nf, cryptic and 2 or 1)

    -- ── chip d'AFFLICTION (foyer de la relique) : centré sous le nom (identifiée seulement). « On voit
    -- l'affliction, on sait ce que c'est » — front-load du mot-clé via le registre unique (Chip). ──
    if (not cryptic) and opts.affKey then
      local cf = Theme.label(9) or Theme.value(9)
      local cw = Chip.width({ key = opts.affKey, font = cf, h = 16 })
      Chip.draw(floor(cx - cw / 2), floor(nameY + (nf and nf:getHeight() or 16) + 2), {
        key = opts.affKey, font = cf, h = 16,
      })
    end

    -- ── corps : sublabel + effet/prose + flavor ──
    local bodyX = floor(ix + 4)
    local bodyW = floor(iw - 8)
    local cursorY = floor(y + h * 0.52 + 0.5)

    if cryptic then
      -- prose énigmatique (Spectral italique, ink3) au lieu d'un effet lisible.
      local pf = Theme.flavor(13) or Theme.bodyItalic(13)
      local prose = opts.effect or "Its purpose hides beneath the surface."
      Draw.textWrap(prose, bodyX, cursorY, bodyW, C.ink3, pf, "left")
    else
      -- sublabel « KNOWN EFFECT » (Space Mono, ink4, tracké).
      local kf = Theme.labelSmall(9) or Theme.label(9)
      Draw.textTrackedL("KNOWN EFFECT", bodyX, cursorY, C.ink4, kf, 1.0)
      cursorY = cursorY + 14
      -- texte d'effet : Spectral ink, avec les VALEURS (tokens contenant un chiffre) en Space Mono `bloodL`.
      local effH = RelicCard._drawEffect(opts.effect or "", bodyX, cursorY, bodyW)
      cursorY = cursorY + effH + 6
    end

    -- flavor (Spectral italique, ink3) : ancré BAS (au-dessus du biseau inférieur). On MESURE le wrap pour
    -- caler le bloc juste au-dessus du bord, sans jamais empiéter sur l'effet déjà posé (max avec cursorY).
    if opts.flavor and opts.flavor ~= "" then
      local ff = Theme.flavor(12) or Theme.bodyItalic(12)
      local nLines, fh = 1, 12
      if ff then
        local _, lines = ff:getWrap(opts.flavor, bodyW)
        nLines = math.max(1, #lines)
        fh = ff:getHeight()
      end
      local flavY = max(cursorY, floor(y + h - ring - nLines * fh - 4))
      Draw.textWrap(opts.flavor, bodyX, flavY, bodyW, C.ink3, ff, "left")
    end
    Draw.reset()
  end

  return ix, iy, iw, ih
end

-- _drawEffect : pose le texte d'effet en Spectral `ink`, mais chaque MOT qui contient un CHIFFRE (« +15% »,
-- « 2 », « 40 » ...) est rendu en Space Mono 700 `bloodL` (les valeurs « ressortent »). Découpe par ESPACES
-- (jamais par octet -> les multi-octets restent intacts) ; wrap manuel borné à `limit`. Retourne la hauteur.
local function hasDigit(word)
  for i = 1, #word do
    local b = word:byte(i)
    if b >= 48 and b <= 57 then return true end -- '0'..'9'
  end
  return false
end

function RelicCard._drawEffect(effect, x, y, limit)
  if not (love and love.graphics and love.graphics.print) or effect == "" then return 0 end
  local proseF = Theme.body(14) or Theme.bodyLight(14)
  local valF = Theme.value(14) or Theme.label(14)
  if not proseF then return 0 end
  local lineH = proseF:getHeight()
  local spaceW = proseF:getWidth(" ")
  local cx, cy = x, y
  -- itère les mots séparés par espace (préserve UTF-8 : on ne coupe qu'aux espaces ASCII).
  for word in (effect .. " "):gmatch("(.-) ") do
    if word ~= "" then
      local isVal = hasDigit(word)
      local f = isVal and valF or proseF
      local col = isVal and C.bloodL or C.ink2
      love.graphics.setFont(f)
      local ww = f:getWidth(word)
      if cx > x and (cx + ww) > (x + limit) then -- wrap : passe à la ligne suivante
        cx = x; cy = cy + lineH
      end
      Draw.setColor(col)
      love.graphics.print(word, floor(cx + 0.5), floor(cy + 0.5))
      cx = cx + ww + spaceW
    end
  end
  Draw.reset()
  return (cy - y) + lineH
end

return RelicCard
