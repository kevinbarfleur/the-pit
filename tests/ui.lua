-- tests/ui.lua
-- Tests de la FONDATION UI (Phase 1) : Frame (encadré runique réutilisable) + Chip (pastille keyword) +
-- Keywords (registre des afflictions) + Theme.state (vocabulaire d'état). Couche RENDER -> tournée sous le
-- mock LÖVE (love.graphics/love.image stubés) : on vérifie la LOGIQUE pure (registre, op->clé, applied,
-- largeurs, vocabulaire d'état) et que le rendu ne CRASHE pas (smoke sur tous les niveaux/états).
--   Lancement : luajit tests/ui.lua
package.path = "./?.lua;" .. package.path
love = require("tests.mock_love")

local Theme = require("src.ui.theme")
local Frame = require("src.ui.frame")
local Chip = require("src.ui.chip")
local Keywords = require("src.ui.keywords")
local Forge = require("src.ui.forge")
local Layout = require("src.ui.layout")

local ok, err = pcall(function()
  -- ── Theme.state : vocabulaire d'état complet + repli sur idle ──
  for _, s in ipairs({ "idle", "hover", "pressed", "disabled", "selected", "danger", "drop" }) do
    local st = Theme.stateOf(s)
    assert(st and st.fill and st.text, "etat complet : " .. s)
  end
  assert(Theme.stateOf("inconnu") == Theme.state.idle, "etat inconnu -> idle")
  assert(Theme.state.hover.glow and Theme.state.hover.glow > 0, "hover a une lueur")
  assert(Theme.state.pressed.inset, "pressed est enfonce")
  assert(Theme.state.disabled.flat, "disabled est a plat")
  assert(Theme.state.danger.gild and Theme.state.selected.gild, "danger/selected sont gildes")

  -- ── Keywords : registre des afflictions ──
  assert(#Keywords.order == 5, "5 afflictions au registre")
  for _, k in ipairs(Keywords.order) do
    local a = Keywords.get(k)
    assert(a and a.color, "descripteur + couleur : " .. k)
    assert(Keywords.name(k) ~= "" and Keywords.name(k) ~= a.name, "nom i18n resolu : " .. k)
    assert(Keywords.blurb(k) ~= "", "phrase i18n : " .. k)
  end
  assert(Keywords.name("burn") == "BURN", "i18n burn")

  -- ── op -> affliction + applied(unit) (lit les effects, ordre canonique, dedup) ──
  assert(Keywords.opAffliction("poison") == "poison", "op poison")
  assert(Keywords.opAffliction("aura_grant_bleed") == "bleed", "op aura -> bleed")
  assert(Keywords.opAffliction("bonus_first") == nil, "op non-affliction -> nil")
  assert(Keywords.opAffliction("op_inconnue_d_un_autre_chantier") == nil, "op inconnue -> nil (defensif)")

  local u = { effects = {
    { trigger = "on_hit", op = "burn", params = { dps = 6 } },     -- volontairement avant poison...
    { trigger = "on_hit", op = "poison", params = { dps = 2 } },   -- ...pour verifier le tri canonique
    { trigger = "on_hit", op = "poison", params = { dps = 1 } },   -- doublon -> dedup
    { trigger = "on_attack", op = "bonus_first", params = { value = 8 } }, -- ignore (pas une affliction)
  } }
  local ap = Keywords.applied(u)
  assert(#ap == 2, "2 afflictions distinctes (poison+burn)")
  assert(ap[1] == "poison" and ap[2] == "burn", "ordre canonique (poison avant burn), dedup")
  assert(#Keywords.applied({}) == 0, "unite sans effets -> aucune affliction")
  assert(#Keywords.applied(nil) == 0, "nil -> aucune affliction (pas de crash)")

  -- ── Icône bakée (mock : image stub mais dimensions reelles de la grille) ──
  local ic = Keywords.icon("burn")
  assert(ic and ic.w > 0 and ic.h > 0, "icone burn bakee avec dimensions")
  assert(Keywords.icon("burn") == ic, "bake memoise (meme objet)")
  assert(Keywords.icon("pas_une_affliction") == nil, "cle inconnue -> nil")

  -- ── Frame : smoke des 3 niveaux + retour de la zone interieure ──
  local font = love.graphics.getFont()
  for _, lvl in ipairs({ "plain", "bevel", "gilded" }) do
    local ix, iy, iw, ih = Frame.draw(100, 100, 200, 60, { level = lvl, font = font })
    assert(iw > 0 and ih > 0, "zone interieure positive : " .. lvl)
    assert(ix >= 100 and iy >= 100, "zone interieure dans le cadre : " .. lvl)
  end
  -- Tous les etats ne crashent pas, label compris.
  for _, s in ipairs({ "idle", "hover", "pressed", "disabled", "selected", "danger", "drop" }) do
    Frame.button(0, 0, 120, 28, "TEST", { state = s, font = font })
  end
  -- Accent override (rareté) + fill=false (cadre sur contenu) + cadre dégénéré : robustes.
  Frame.draw(10, 10, 64, 64, { level = "gilded", accent = Theme.hex(0xccaa44), fill = false, font = font })
  Frame.draw(0, 0, 3, 3, { font = font })

  -- ── Chip : largeur coherente + smoke ──
  local wWithVal = Chip.width({ key = "burn", value = 6, font = font })
  local wNoVal = Chip.width({ key = "burn", font = font })
  assert(wWithVal > wNoVal, "la valeur ajoute de la largeur")
  local wNoIcon = Chip.width({ key = "burn", icon = false, font = font })
  assert(wNoIcon < wNoVal, "masquer l'icone reduit la largeur")
  Chip.draw(10, 10, { key = "poison", value = "2dps", font = font })
  local total = Chip.row(0, 0,
    { { key = "poison" }, { key = "bleed" }, { label = "CARRY", color = Theme.c.gold, icon = false } },
    { font = font })
  assert(total > 0, "rangee de chips : largeur totale > 0")

  -- ── Forge : kit « nightmare forge » (port de forge-px.js) ──────────────────────────────────────
  -- Sous le mock LÖVE : real()==false -> aucun bake (image/imageData nil), mais le tampon + tous les draw
  -- fns tournent sans crash (set/blend/add no-op si FFI absent ; harmless si présent). On vérifie la
  -- LOGIQUE pure (palettes, mesure de texte, état d'easing, widget construit) + smoke de chaque draw.
  assert(Forge.PX == 2, "PX = 2 par defaut (densite creatures : 1 art-px = 2 px ecran)")
  assert(type(Forge.ACCENTS.gold) == "table" and Forge.ACCENTS.violet, "palettes d'accent presentes")
  -- frameWeather : grit cisele seede, ne crashe pas (no-op headless ; bit-faithful sinon).
  do
    local wv = Forge.newWidget(40, 20)
    Forge.render(wv, function(b, W, H, t)
      Forge.frame(b, 0, 0, W - 1, H - 1, { t = 3, accent = true })
      Forge.frameWeather(b, 0, 0, W - 1, H - 1, 3, 7, nil, false)
    end, 1.0)
  end
  Forge.setAccent("violet"); Forge.setAccent("inconnu"); Forge.setAccent("gold") -- accent inconnu = no-op
  assert(Forge.FAM.flesh and Forge.AFFL.bleed and Forge.LIQ.mana, "palettes FAM/AFFL/LIQ portees")
  -- easing : converge vers la cible d'interaction (framerate-dependent elerp, comme le JS).
  local est = { hover = true, glow = 0, press = 0, eyeOpen = 0 }
  for _ = 1, 80 do Forge.easeBtn(est) end
  assert(est.glow > 0.5 and est.eyeOpen > 0.9, "easeBtn converge (glow+eyeOpen montent au survol)")
  -- widget : Image+ImageData alloues UNE FOIS (cache de taille) ; sous mock -> pas d'image (no bake).
  local w = Forge.newWidget(60, 13)
  assert(w.aw == 60 and w.ah == 13 and w.buf, "widget construit (dims + tampon)")
  assert((not Forge.real()) == (w.image == nil), "headless: pas de bake ; reel: image bakee")
  -- genEyes : deterministe (meme seed -> meme nuee), evite le label, borne 2..7.
  local eyes = Forge.genEyes(60, 11, 11, "DESCEND", 9)
  assert(#eyes >= 2 and #eyes <= 7, "genEyes : nuee bornee 2..7")
  -- render : chaque draw fn s'execute (ecrit le tampon) sans crash, sous mock comme reel.
  Forge.render(w, function(b, W, H, t) Forge.drawButton(b, W, H, 0, 1, 0.55, 11, "DESCEND", false, eyes, { 30, 5 }, 9, t) end, 1.2)
  local probes = {
    { 30, 30, function(b, W, H, t) Forge.drawOrb(b, W, H, 0.6, Forge.LIQ.blood, 101, t) end },
    { 60, 16, function(b, W, H, t) Forge.drawGauge(b, W, H, 0.16, { { frac = 0, color = Forge.AFFL.bleed.c, bmp = Forge.AFFL.bleed.bmp } }, t) end },
    { 56, 34, function(b, W, H, t) Forge.drawPanel(b, W, H, t, "GRIMOIRE") end },
    { 52, 30, function(b, W, H, t) Forge.drawTooltip(b, W, H, t, { { txt = "ASH-MAW", gold = true } }) end },
    { 46, 56, function(b, W, H, t) Forge.drawRelicCard(b, W, H, "selected", { name = "X", fam = "flesh", effect = "e", flavor = "f" }, t) end },
    { 72, 22, function(b, W, H, t) Forge.drawBanner(b, W, H, "VICTORY", "win", t) end },
    { 80, 6, function(b, W, H, t) Forge.drawDivider(b, W, H, t) end },
    { 14, 14, function(b, W, H, t) Forge.drawGem(b, W, H, true, t) end },
    { 18, 18, function(b, W, H, t) Forge.drawEyeRing(b, W, H, 0.9, 0.7, t, 3) end },
    { 12, 12, function(b, W, H, t) Forge.drawTypePip(b, W, H, "arcane", t) end },
    { 13, 8, function(b, W, H, t) Forge.drawLevelPips(b, W, H, 3, t) end },
    { 34, 11, function(b, W, H, t) Forge.drawEcoBtn(b, W, H, 0, 0.5, 1, "REROLL", 2, false, t) end },
    { 12, 12, function(b, W, H, t) Forge.drawIconBtn(b, W, H, 0, 0.5, 1, "sigil", t) end },
  }
  for _, p in ipairs(probes) do Forge.render(Forge.newWidget(p[1], p[2]), p[3], 1.3) end

  -- ── Layout : moteur flex (remplit EXACTEMENT, gouttières égales, stretch, no-hole). PUR (zero love). ──
  do
    local box = { x = 0, y = 0, w = 100, h = 50 }
    local r = Layout.row(box, { { flex = 1 }, { flex = 1 }, { flex = 1 } }, { gap = 4 })
    assert(#r == 3, "row : 3 enfants")
    assert(r[3].x + r[3].w == 100, "row : remplit EXACTEMENT la largeur (zero trou)")
    assert(r[2].x - (r[1].x + r[1].w) == 4 and r[3].x - (r[2].x + r[2].w) == 4, "row : gouttières ÉGALES")
    assert(r[1].h == 50 and r[2].h == 50, "row : align stretch remplit la hauteur croisée")
    -- fixed + flex : le flex absorbe le reste -> remplit pile.
    local r2 = Layout.row(box, { 20, { flex = 1 }, 20 }, { gap = 5 })
    assert(r2[1].w == 20 and r2[3].w == 20 and r2[3].x + r2[3].w == 100, "row : fixed+flex remplit pile")
    -- colonne : remplit la hauteur, stretch la largeur.
    local cc = Layout.column({ x = 0, y = 0, w = 40, h = 120 }, { { size = 14 }, { flex = 1 } }, { gap = 6 })
    assert(cc[1].h == 14 and cc[2].y + cc[2].h == 120, "column : remplit la hauteur (zero trou)")
    assert(cc[1].w == 40 and cc[2].w == 40, "column : align stretch remplit la largeur")
    -- justify center (sans flex) : contenu centré.
    local r3 = Layout.row({ x = 0, y = 0, w = 100, h = 10 }, { 20, 20 }, { gap = 10, justify = "center" })
    assert(r3[1].x == 25, "row : justify center")
    -- inset : sous-boîte rétrécie.
    local ins = Layout.inset({ x = 10, y = 10, w = 80, h = 60 }, 5)
    assert(ins.x == 15 and ins.w == 70, "inset : marge appliquée")
  end

  -- ── Forge.uiButton : pont STATEFUL (cache par id + easing + nuee). Headless-safe, ne crashe pas, et
  -- l'etat est PERSISTANT entre appels (le meme id reutilise le meme widget/etat). ──
  Forge.uiTick(1 / 60)
  -- cta (gros bouton-oeil) avec gaze depuis la souris design ; eco (avec cout) ; icon (sigil).
  Forge.uiButton("t.cta", 100, 600, 152, 60, "FIGHT",
    { tone = "cta", hover = true, mouse = { mx = 130, my = 620 }, fontSz = 9, eyeR = 7 })
  Forge.uiButton("t.eco", 300, 600, 100, 32, "REROLL", { tone = "eco", cost = 1, hover = false })
  Forge.uiButton("t.icon", 420, 600, 32, 32, "", { tone = "icon", cost = "sigil", hover = false })
  Forge.uiButton("t.dis", 460, 600, 152, 60, "SEALED", { tone = "cta", disabled = true })
  assert(Forge._btnCache["t.cta"], "uiButton : cache par id cree")
  local stBefore = Forge._btnCache["t.cta"].st.glow
  for _ = 1, 30 do Forge.uiButton("t.cta", 100, 600, 152, 60, "FIGHT", { tone = "cta", hover = true, mouse = { mx = 130, my = 620 } }) end
  assert(Forge._btnCache["t.cta"].st.glow >= stBefore, "uiButton : etat PERSISTE et s'ease au survol (meme id)")
  -- changement de label/disabled -> regenere la config (pas de crash).
  Forge.uiButton("t.cta", 100, 600, 152, 60, "PLACE A UNIT", { tone = "cta", disabled = true })

  -- ── LABEL VIVANT (Forge.label) : remplace le label BAKÉ -> il S'AFFICHE TOUJOURS, sans readback de glyphe
  -- ni cache à empoisonner (le bug des « boîtes laiton sans texte »). On vérifie : (1) Forge.label est
  -- appelable (overlay love.graphics, no-op headless) ; (2) le label N'EST PLUS baké -> drawButton/drawEcoBtn
  -- ne consomment plus textMask pour le texte (le label est dessiné par uiButton APRÈS le blit). ──
  assert(type(Forge.label) == "function", "Forge.label : overlay vivant present")
  assert(type(Forge.hexF) == "function", "Forge.hexF : hex -> floats 0..1 (couleur d'overlay)")
  do
    local f = Forge.hexF("#f0d68e")
    assert(f[1] > 0 and f[1] <= 1 and f[2] <= 1 and f[3] <= 1, "hexF : floats normalises 0..1")
  end
  -- smoke : tous les alignements + un glow de survol, sous le mock (no crash, pas de readback requis).
  Forge.label("FIGHT", 200, 600, 16, Forge.hexF("#f0d68e"), { bold = true, glow = 0.6 })
  Forge.label("REROLL", 200, 640, 16, Forge.hexF("#e8cd84"), {})
  Forge.label("1", 320, 640, 16, Forge.hexF("#e8dcc0"), { right = true })
  Forge.label("PLACE A UNIT", 200, 680, 16, Forge.hexF("#a4895a"), { bold = true })

  -- ── POLICE LISIBLE (read = Pixel Operator Bold) + opt read de Forge.label + Forge.coinAt (symbole de coût). ──
  -- Theme.read : rôle présent, hinting "mono" (crisp), shortcut + fichier déclarés. Pixel Operator (trait GRAS)
  -- remplace Jersey 15 (rejeté : trop fin -> floutait au scale non-entier 0.75). Sous le mock LÖVE, newFont est
  -- stubé -> on vérifie surtout la DÉCLARATION (rôle/fichier/hint), pas le rendu réel.
  assert(Theme.FONT_FILES.read and Theme.FONT_FILES.read:match("PixelOperator"), "Theme : police read = Pixel Operator")
  assert(Theme.HINT.read == "mono", "Theme : read en hinting mono (crisp nearest)")
  assert(type(Theme.read) == "function", "Theme.read : raccourci present")
  Theme.read(13); Theme.read(16) -- mémoïse sans crash (stub headless)
  -- Forge.label avec read : overlay vivant en police lisible (no crash, no readback).
  Forge.label("40", 200, 600, 20, Forge.hexF("#c2b39a"), { read = true, shadow = true })
  Forge.label("24", 200, 620, 15, Forge.hexF("#d9bd52"), { read = true, right = true })
  -- Forge.coinAt : pièce d'or dessinée direct (no-op headless / pcall-gardé), version éteinte aussi.
  assert(type(Forge.coinAt) == "function", "Forge.coinAt : symbole de coût present")
  Forge.coinAt(40, 40, 4, { 0.85, 0.74, 0.32 })
  Forge.coinAt(60, 40, 4, { 0.5, 0.4, 0.2 }, true) -- pièce éteinte (hors-budget)

  -- ── Forge.socket / uiSocket / uiPlate / diamondAt / accentFrom (cases & cartes du build). ──
  local acc = Forge.accentFrom({ 0.77, 0.63, 0.29 }) -- depuis Theme.c (floats 0..1)
  assert(acc.dark and acc.mid and acc.bright, "accentFrom : triple {dark,mid,bright}")
  assert(acc.mid[1] > 1, "accentFrom : converti en octets 0..255")
  local acc2 = Forge.accentFrom({ 200, 50, 50 }) -- deja en octets -> inchange
  assert(acc2.mid[1] == 200, "accentFrom : octets passes inchanges")
  -- uiSocket : cache par id + accent change -> re-bake ; sans accent -> sobre. Headless-safe.
  Forge.uiSocket("t.sock", 0, 0, 80, 80, { px = 2, accentCol = acc })
  assert(Forge._sockCache["t.sock"], "uiSocket : cache par id")
  Forge.uiSocket("t.sock", 0, 0, 80, 80, { px = 2, accentCol = nil }) -- accent retire -> re-bake
  Forge.uiSocket("t.sock", 0, 0, 80, 80, { px = 2, accentCol = acc, weather = false })
  -- uiPlate : fond plein cache par id ; etat disabled.
  Forge.uiPlate("t.plate", 0, 0, 140, 140, { px = 2 })
  Forge.uiPlate("t.plate", 0, 0, 140, 140, { px = 2, disabled = true })
  assert(Forge._plateCache["t.plate"], "uiPlate : cache par id")

  -- ── LAVAGE de rareté (A3/B5/B6) : tintFrom construit un descripteur { col octets, amt } depuis une
  -- couleur (floats OU octets) ; tintKey en fait une cle de cache STABLE (re-bake quand la teinte change,
  -- ex. survol). Le tint passe a plate/uiPlate/uiCard LAVE la pierre vers l'accent (subtil, baké). ──
  do
    local tf = Forge.tintFrom({ 0.55, 0.40, 0.66 }, 0.16) -- depuis Theme/Rarity (floats 0..1)
    assert(tf.col and tf.amt == 0.16, "tintFrom : { col, amt }")
    assert(tf.col[1] > 1, "tintFrom : couleur convertie en octets 0..255")
    local tf2 = Forge.tintFrom({ 200, 150, 70 }) -- deja en octets -> inchange, amt par defaut
    assert(tf2.col[1] == 200 and tf2.amt > 0, "tintFrom : octets inchanges + amt defaut")
    -- tintKey : nil/sans amt -> "none" ; teinte differente -> cle differente (declenche un re-bake).
    assert(Forge.tintKey(nil) == "none", "tintKey : nil -> none")
    assert(Forge.tintKey({ col = { 1, 2, 3 }, amt = 0 }) == "none", "tintKey : amt 0 -> none")
    local k1 = Forge.tintKey(tf)
    local k2 = Forge.tintKey(Forge.tintFrom({ 0.55, 0.40, 0.66 }, 0.30)) -- amt different (survol)
    assert(k1 ~= "none" and k1 ~= k2, "tintKey : teinte/amt different -> cle differente (re-bake)")
    -- uiPlate teinte : re-bake quand la teinte change (repos -> survol).
    Forge.uiPlate("t.plate.tint", 0, 0, 120, 120, { px = 2, tint = tf })
    local cfgRest = Forge._plateCache["t.plate.tint"] and Forge._plateCache["t.plate.tint"].cfg
    Forge.uiPlate("t.plate.tint", 0, 0, 120, 120, { px = 2, tint = Forge.tintFrom({ 0.55, 0.40, 0.66 }, 0.30) })
    assert(Forge._plateCache["t.plate.tint"].cfg ~= cfgRest, "uiPlate : teinte survol -> nouvelle cfg (re-bake)")
  end
  -- valueTag : plaque forge bordée (cadre baké) + label/valeur en OVERLAY VIVANT (toujours lisible). Cache
  -- par id ; re-bake si accent/taille change. Headless-safe (no crash, pas de readback requis pour le texte).
  Forge.valueTag("t.vtag", 0, 0, 64, 34, "HP", "40", { px = 2, accentCol = acc,
    labelColor = { 0.48, 0.41, 0.36 }, valueColor = { 0.85, 0.78, 0.55 } })
  assert(Forge._vtagCache["t.vtag"], "valueTag : cache par id")
  Forge.valueTag("t.vtag", 0, 0, 64, 34, "DMG", "12", { px = 2, accentCol = nil }) -- accent retiré -> re-bake
  Forge.valueTag("t.vtag2", 0, 0, 50, 30, "CD", "1.5s", { px = 2 }) -- défauts (couleurs laiton)
  -- diamondAt : draw direct (no-op headless, ne crashe pas).
  Forge.diamondAt(20, 20, 3, { 0.8, 0.7, 0.3 })

  -- (scène-showcase « Frameforge » retirée avec son fichier : le kit gritty legacy n'est plus exposé.)

  -- ── Forge.genEyes : NUÉE éparpillée (plusieurs yeux), keep-out du label, rayons variés bornés. ──
  local fW, fH, fpad, fEye = 120, 30, 5, 8
  local eA = Forge.genEyes(fW, fH, 7, "DESCEND", 8, { frameTh = 2, pad = fpad, eyeR = fEye })
  assert(#eA >= 2, "genEyes : une NUEE (>=2 yeux) sur un bouton large")
  -- zone de keep-out du label (mêmes bornes que genEyes) : aucun œil ne doit la chevaucher.
  local mW = require("src.ui.forge").measure("DESCEND", 8)
  local lkx0 = math.floor(fW / 2 - mW / 2) - fpad
  local lkx1 = math.floor(fW / 2 + mW / 2) + fpad
  local lky0 = math.floor(fH / 2 - 1) - 1 -- approx (la hauteur du masque ~ font) ; on garde une marge
  local lky1 = math.floor(fH / 2 + 1) + 1
  for _, e in ipairs(eA) do
    assert(e.r >= 3 and e.r <= fEye + 1, "rayon varie autour de eyeR, borne")
    -- jamais sur le texte : l'œil (ex±r, ey±r) ne recouvre pas la boite du label (avec marge).
    local overX = (e.ex + e.r > lkx0 and e.ex - e.r < lkx1)
    local overY = (e.ey + e.r > lky0 and e.ey - e.r < lky1)
    assert(not (overX and overY), "aucun oeil ne chevauche le label (keep-out)")
  end
  -- déterminisme : même seed -> même nuée.
  local eA2 = Forge.genEyes(fW, fH, 7, "DESCEND", 8, { frameTh = 2, pad = fpad, eyeR = fEye })
  assert(#eA2 == #eA, "genEyes deterministe (meme seed -> meme nombre d'yeux)")
  local eB = Forge.genEyes(76, 24, 7, "DESCEND", 8, 2) -- ancienne signature (frameTh=number)
  assert(type(eB) == "table", "genEyes retro-compat (frameTh nombre)")
  -- override de keep-out (labelW/labelH art-px) : la zone réservée au LABEL suit l'empreinte PASSÉE (pour un
  -- label vivant en AUTRE police que le masque baké) -> aucun œil ne chevauche cette boîte explicite.
  do
    local W2, slab2 = 100, 20
    local lw2, lh2 = 30, 9
    local eo = Forge.genEyes(W2, slab2, 4, "X", 8, { frameTh = 2, pad = 3, eyeR = 6, labelW = lw2, labelH = lh2 })
    local cy2 = slab2 / 2
    local kx0 = math.floor(W2 / 2 - lw2 / 2) - 3
    local kx1 = math.floor(W2 / 2 + lw2 / 2) + 3
    local ky0 = math.floor(cy2 - lh2 / 2) - 1
    local ky1 = math.floor(cy2 + lh2 / 2) + 1
    for _, e in ipairs(eo) do
      local overX = (e.ex + e.r > kx0 and e.ex - e.r < kx1)
      local overY = (e.ey + e.r > ky0 and e.ey - e.r < ky1)
      assert(not (overX and overY), "genEyes labelW/H : aucun oeil ne chevauche le keep-out explicite")
    end
  end

  -- ── src/ui/nightmare.lua : surcouche ONIRIQUE (bordures qui tanguent). RENDER pur, headless-safe : sous le
  -- mock LÖVE, love.graphics est stubé -> Nightmare.border/update ne crashent JAMAIS (no-op propre). On
  -- vérifie : module présent, update avance sans erreur, border smoke sur plusieurs tailles + opts. ──
  do
    local Nightmare = require("src.ui.nightmare")
    assert(type(Nightmare.border) == "function" and type(Nightmare.update) == "function",
      "nightmare : border + update exportés")
    Nightmare.update(1.0); Nightmare.update(0); Nightmare.update(-5) -- dt négatif clampé : pas d'erreur
    Nightmare.border(40, 40, 200, 80)                                 -- défauts
    Nightmare.border(0, 0, 120, 30, { amp = 1.4, alpha = 0.22, seed = 17, t = 2.3 })
    Nightmare.border(10, 10, 2, 2)                                    -- box dégénérée -> no-op (borné, pas de crash)
    Nightmare.border(10, 10, 64, 34, { tint = Theme.c.rot })
  end

  -- ── Forge.uiCtaEyes : nuée d'YEUX en OVERLAY (CTA cauchemardesque). REPOS (open<=0.02) -> no-op (rien) ;
  -- SURVOL (open>0) -> bake (cache par id) ; CLIC (react>0) -> écarquillement. Headless-safe (no crash, pas
  -- de bake sous le mock). Keep-out du label via labelW/labelH (les yeux évitent le texte vivant). ──
  do
    assert(type(Forge.uiCtaEyes) == "function", "forge : uiCtaEyes (nuée d'yeux en overlay)")
    -- repos : open=0 -> retourne false (aucun widget créé) -> le bouton reste PROPRE.
    assert(Forge.uiCtaEyes("t.eyes.rest", 0, 0, 128, 34, "FIGHT", { open = 0 }) == false,
      "uiCtaEyes : repos (open<=0.02) -> no-op (false)")
    assert(Forge._ctaEyeCache["t.eyes.rest"] == nil, "uiCtaEyes : repos -> aucun widget alloué")
    -- survol : open>0 -> crée le cache par id + génère la nuée (déterministe, seedée par l'id).
    Forge.uiTick(1 / 60)
    Forge.uiCtaEyes("t.eyes.hov", 100, 600, 128, 34, "FIGHT",
      { open = 0.6, react = 0, mouse = { mx = 130, my = 615 }, labelW = 20, labelH = 6, eyeR = 6 })
    local ce = Forge._ctaEyeCache["t.eyes.hov"]
    assert(ce and ce.eyes and #ce.eyes >= 1, "uiCtaEyes : survol -> nuée bakée (cache par id)")
    -- clic : react>0 -> écarquillement (re-bake), même nuée (placement stable tant que la config ne change pas).
    local nBefore = #ce.eyes
    Forge.uiCtaEyes("t.eyes.hov", 100, 600, 128, 34, "FIGHT",
      { open = 1, react = 0.8, mouse = { mx = 130, my = 615 }, labelW = 20, labelH = 6, eyeR = 6 })
    assert(#Forge._ctaEyeCache["t.eyes.hov"].eyes == nBefore, "uiCtaEyes : clic garde la même nuée (stable)")
  end

  -- ── Feel.seedOf : graine/phase STABLE par id (sème la nuée du CTA + désynchronise la respiration). ──
  do
    local Feel = require("src.ui.feel")
    assert(type(Feel.seedOf) == "function", "feel : seedOf exporté")
    assert(Feel.seedOf("menu.enter") == Feel.seedOf("menu.enter"), "feel.seedOf : stable pour un id donné")
    assert(Feel.seedOf("a") ~= Feel.seedOf("ab"), "feel.seedOf : ids différents -> graines différentes")
    assert(Feel.seedOf(nil) == 0, "feel.seedOf : nil -> 0 (pas de crash)")
  end

  -- ── Button.draw (variant primary) AVEC feel : exerce le câblage des YEUX (glow ouvre, flash réagit) + la
  -- bordure ONIRIQUE. Headless-safe (no crash). disabled -> ni yeux ni tangage (métal mort). ──
  do
    local Button = require("src.ui.button")
    -- repos (pas de feel) : pas d'yeux, juste le bouton propre + bordure onirique.
    Button.draw(0, 0, 128, 34, "primary", "FIGHT", {})
    -- survol : feel.glow>0 -> yeux qui s'ouvrent ; on passe la souris pour le gaze + t pour l'anim.
    Button.draw(0, 0, 128, 34, "primary", "FIGHT",
      { hover = true, id = "t.btn.live", feel = { glow = 0.7, lift = 3, squash = 0, flash = 0 },
        mouse = { mx = 60, my = 16 }, t = 1.2 })
    -- clic : feel.flash>0 -> les yeux réagissent (écarquillement) + flash de braise.
    Button.draw(0, 0, 128, 34, "primary", "FIGHT",
      { id = "t.btn.live", feel = { glow = 1, lift = 0, squash = 2, flash = 0.5 }, t = 1.3 })
    -- disabled : aucun œil, aucun tangage (chemin neutre) -> ne crashe pas.
    Button.draw(0, 0, 128, 34, "primary", "SEALED", { disabled = true, feel = { glow = 1, flash = 1 } })
    -- autres variantes : bordure onirique uniquement (pas d'yeux) -> smoke.
    Button.draw(0, 0, 128, 32, "secondary", "REFUSE", { hover = true })
    Button.draw(0, 0, 128, 30, "eco", "REROLL", { cost = 2 })
    Button.icon(0, 0, 34, "sigil", {})
  end

  -- ── src/ui/eye.lua : l'ŒIL signature EXTRAIT (réutilisé par boutons/panneaux/cartes/sceau). PUR (zéro
  -- love.*) -> on l'exerce DIRECTEMENT sur un tampon Forge (set/blend/add) : draw/ring/watcher ne crashent
  -- pas, et le clignement/regard sont déterministes (seed + t). Forge le re-exporte (compat). ──
  do
    local Eye = require("src.ui.eye")
    assert(type(Eye.draw) == "function" and type(Eye.ring) == "function" and type(Eye.watcher) == "function",
      "eye : draw/ring/watcher exportés")
    assert(Forge.drawEye == Eye.draw, "forge : drawEye délègue au module eye")
    assert(Forge.drawEyeRing == Eye.ring, "forge : drawEyeRing délègue à Eye.ring")
    local wv = Forge.newWidget(40, 40)
    Forge.render(wv, function(b, W, H, t)
      Eye.draw(b, W / 2, H / 2, 8, 1, 0.6, t, 3, { blood = 0.5, pupil = "slit", gaze = { 4, 4 } })
      Eye.draw(b, 8, 8, 4, 0.5, 0.2, t, 7, { pupil = "round" })
      Eye.ring(b, 18, 18, 0.9, 0.7, t, 5)
      Eye.watcher(b, W, H, t, 9, { r = 5 })
    end, 1.3)
    -- œil fermé (open=0) : ne crashe pas (chemin « couture de paupière »). Eye.draw(nil,...) = no-op garde.
    Forge.render(Forge.newWidget(20, 20), function(b, W, H, t) Eye.draw(b, W / 2, H / 2, 6, 0, 0, t, 1) end, 0.0)
    Eye.draw(nil, 0, 0, 4, 1, 0, 0, 0) -- buf nil -> no-op (pas de crash)

  -- ── Forge.afflShape / shapeAt : iconographie §III du design system. 7 silhouettes d'affliction (forme
  -- propre par famille) + 5 formes de TYPE pilotées par Theme.types[].pip. Smoke headless + clé inconnue. ──
    assert(type(Forge.afflShape) == "function" and Forge.AFFL_SHAPE, "forge : afflShape + registre de silhouettes")
    for _, k in ipairs({ "burn", "bleed", "poison", "rot", "shock", "regen", "shield" }) do
      assert(Forge.AFFL_SHAPE[k], "afflShape : silhouette présente pour " .. k)
      Forge.render(Forge.newWidget(14, 14), function(b, W, H, t) Forge.afflShape(b, W, H, k, t) end, 0.7)
    end
    Forge.render(Forge.newWidget(14, 14), function(b, W, H, t) Forge.afflShape(b, W, H, "pas_une_affl", t) end, 0.7) -- inconnue -> no-op
    -- shapeAt : chaque forme de Theme.types[].pip (bar/cross/diamond/star/disc) se dessine.
    assert(type(Forge.shapeAt) == "function", "forge : shapeAt (silhouette de type)")
    for _, name in ipairs({ "flesh", "order", "bone", "arcane", "abyss" }) do
      local pip = Theme.types[name].pip
      Forge.render(Forge.newWidget(14, 14), function(b, W, H, _) Forge.shapeAt(b, W / 2, H / 2, 5, pip, { 200, 120, 60 }, { 80, 40, 20 }) end, 0)
    end
  end

  -- ── Forge.uiFrame + Frame.draw INTÉGRÉ au kit métal : Frame.draw bake l'encadré forge (biseau dur +
  -- patine + rivets + plaque convexe + héros gildé) via Forge.uiFrame (cache par id, re-bake sur SIGNATURE).
  -- On vérifie : (1) uiFrame existe + cache par id ; (2) la signature change avec l'état (re-bake) mais PAS
  -- avec le hover-glow (overlay vivant) ; (3) Frame.draw retourne une zone intérieure saine pour tous les
  -- niveaux/états + les nouvelles options (id/seed/tint/fill=false/danger). Headless-safe. ──
  do
    assert(type(Forge.uiFrame) == "function", "forge : uiFrame (moteur de Frame.draw)")
    Forge.uiFrame("t.frame", 0, 0, 160, 60, { px = 2, gild = true, accentCol = Forge.accentFrom({ 0.8, 0.6, 0.3 }) })
    assert(Forge._frameCache["t.frame"], "uiFrame : cache par id")
    local sigGild = Forge._frameCache["t.frame"].sig
    Forge.uiFrame("t.frame", 0, 0, 160, 60, { px = 2, gild = false }) -- état change -> nouvelle signature
    assert(Forge._frameCache["t.frame"].sig ~= sigGild, "uiFrame : la signature change avec l'état (re-bake)")
    -- fill=false (cadre sur contenu) + tint (lavage de rareté) : signatures distinctes.
    Forge.uiFrame("t.frame.fo", 0, 0, 120, 56, { px = 2, fill = false, gild = true })
    Forge.uiFrame("t.frame.ti", 0, 0, 120, 56, { px = 2, tint = Forge.tintFrom({ 0.7, 0.2, 0.2 }, 0.2) })

    -- Frame.draw : toutes les combinaisons niveau×état retournent une zone intérieure positive et bornée.
    for _, lv in ipairs({ "plain", "bevel", "gilded" }) do
      for _, s in ipairs({ "idle", "hover", "pressed", "disabled", "selected", "danger", "drop" }) do
        local ix, iy, iw, ih = Frame.draw(40, 40, 200, 80, { level = lv, state = s, id = "tf." .. lv .. "." .. s })
        assert(iw > 0 and ih > 0 and ix >= 40 and iy >= 40, "Frame.draw zone interieure saine : " .. lv .. "/" .. s)
      end
    end
    -- nouvelles options : id explicite, seed de patine, accent de rareté, fill=false, tint.
    Frame.draw(10, 10, 64, 64, { level = "gilded", accent = Theme.hex(0xccaa44), fill = false, id = "tf.acc", seed = 9 })
    Frame.draw(0, 0, 8, 8, { id = "tf.tiny" }) -- cadre dégénéré (petit) : borné, ne crashe pas
    -- Frame.button : label vivant (overlay) sur tous les états (no crash, no readback).
    for _, s in ipairs({ "idle", "hover", "pressed", "disabled", "selected", "danger" }) do
      Frame.button(0, 0, 120, 30, "FORGE", { state = s, level = "bevel", font = font, id = "tfb." .. s })
    end
  end

  -- ── Forge.cardPanel / uiCard : fond de fiche monstre (plaque qui respire + cadre patiné). Headless-safe.
  do
    local wv = Forge.newWidget(150, 200)
    Forge.render(wv, function(b, W, H, t)
      Forge.cardPanel(b, W, H, t, { accentCol = Forge.accentFrom({ 200, 150, 70 }), rich = true, seed = 42 })
    end, 1.0)
    Forge.uiCard("t.card", 0, 0, 312, 380, { px = 2, seed = 5, rich = false })
    Forge.uiCard("t.card", 0, 0, 312, 380, { px = 2, seed = 5, rich = true, accentCol = Forge.accentFrom({ 0.8, 0.6, 0.3 }) })
    assert(Forge._cardCache["t.card"], "uiCard : cache par id cree")
    -- A3 : uiCard avec FOND LAVÉ vers la rareté (tint) -> re-bake chaque frame (la plaque respire), no crash.
    Forge.uiCard("t.card", 0, 0, 312, 380, { px = 2, seed = 5, tint = Forge.tintFrom({ 0.8, 0.6, 0.3 }, 0.16) })
  end

  -- ── Build : fiche monstre TCG MINIMALE (helpers PURS + smoke de rendu headless de la carte) ──────
  do
    local Build = require("src.scenes.build")
    -- helper PUR : valeur d'affliction depuis les params (dps/durée). Le rôle (roleOf) a été RETIRÉ de la
    -- carte (le joueur déduit tank/carry de la VIE + des capacités) -> plus de chip de rôle.
    assert(Build.roleOf == nil, "roleOf retiré (carte minimale : plus de chip de rôle)")
    assert(Build.afflValue({ dps = 6, dur = 180 }) == "6 dps 3s", "afflValue : dps + duree en secondes")
    assert(Build.afflValue({ dps = 2 }) == "2 dps", "afflValue : dps seul")
    assert(Build.afflValue({}) == nil, "afflValue : sans dps/dur -> nil")
    assert(Build.afflValue(nil) == nil, "afflValue : nil -> nil")

    -- helper PUR : tokenizeValues découpe une ligne en segments {text, sp, value} ; un segment "value" porte
    -- au moins un chiffre (+7%, 16, 1.5s) -> colorisation inline des valeurs sans toucher l'i18n.
    local toks = Build.tokenizeValues("takes +5% damage per stack (up to 5).")
    assert(#toks > 0, "tokenizeValues : segmente la ligne")
    local nVal, joined = 0, ""
    for _, t in ipairs(toks) do
      if t.value then nVal = nVal + 1 end
      joined = joined .. t.text .. t.sp
    end
    assert(nVal == 2, "tokenizeValues : 2 valeurs (+5%, 5)")
    assert(joined == "takes +5% damage per stack (up to 5).", "tokenizeValues : reconstruit la ligne a l'identique")
    -- mots non-valeur : aucun chiffre -> jamais marqués valeur (defensif).
    local plain = Build.tokenizeValues("forces the enemy front to strike it.")
    for _, t in ipairs(plain) do assert(not t.value, "tokenizeValues : prose pure -> aucune valeur") end
    -- valeur entre PARENTHÈSES « (6 dmg/s) » : « (6 » est une valeur, « dmg/s) » ne l'est pas.
    local paren = Build.tokenizeValues("Strikes burn (6 dmg/s) but the flame decays.")
    local pv = {}
    for _, t in ipairs(paren) do if t.value then pv[#pv + 1] = t.text end end
    assert(#pv == 1 and pv[1] == "(6", "tokenizeValues : valeur entre parentheses detectee, pas le mot suivant")

    -- Smoke : construit la scène, pose une unité à afflictions (burn) ET un héros (rank>=4), et dessine la
    -- fiche directement (hors hover) -> ne plante pas sous le mock LÖVE, golden non touché (RENDER pur).
    -- Couvre les STATS FRAMELESS (Forge.label, plus de value-tag bordée), le portrait SANS boîte noire, le
    -- fond LAVÉ par la rareté + les value-chips d'affliction.
    local Palette = require("src.core.palette")
    local b = Build.new(Palette, 320, 180, { goto = function() end })
    b.view = { ox = 0, oy = 0, scale = 4 }
    b.mx, b.my = 100, 60
    b:drawTooltip("emberling")     -- pose burn (value-chip + valeurs inline orange) + R2
    b:drawTooltip("plague_doctor") -- regen, R4 (cadre riche + œil + halo + fond teinté sigil)
    b:drawTooltip("marauder")      -- vanille, pas d'affliction, pas de family/rank (chemin neutre desc)
    b:drawTooltip("skull_colossus") -- R5 avec family (fond teinté or malsain)
    b:drawTooltip("stormlord")     -- CHOC : valeurs inline JAUNES + icône choc, flavor italique séparée
    b:drawTooltip("live_wire")     -- CHOC T1

    -- drawDescLine : tracé d'une ligne avec valeurs colorées + icône d'affliction (no crash sous le mock).
    -- chemin affliction (burn) ET chemin neutre (aff=nil -> ligne unie). maxW borne l'icône (pas de débord).
    b:drawDescLine("stacks 2 shock (+10% per stack, up to 16).", 20, 20, Theme.read(13), Theme.c.body, "shock", 290)
    b:drawDescLine("a plain mechanic line with no values here", 20, 40, Theme.read(13), Theme.c.body, nil, 290)
    b:drawDescLine("+5% only", 20, 60, Theme.read(13), Theme.c.body, "burn", 12) -- maxW serré -> icône omise

    -- drawShopCard (B4/B6 : pip de type GROS + survol). On câble une run-stub minimale (gold + shop) -> la
    -- carte se dessine au repos ET au survol sans crash (le fond teinté/hover vit dans drawBack, ici = cadre
    -- + pip + nom + coût). Couvre le pip type-coloré, le halo de survol, l'accent de liseré par type.
    b.host.run = { gold = 99, shop = { { id = "emberling", cost = 2 } } }
    local srect = b.shopSlots[1]
    b:drawShopCard(1, srect, b.host.run.shop[1], false) -- repos (pièce + prix read)
    b:drawShopCard(1, srect, b.host.run.shop[1], true)  -- survol (halo + liseré or)
    b.host.run.gold = 0                                  -- hors-budget (pièce éteinte)
    b:drawShopCard(1, srect, b.host.run.shop[1], false)
    b.host.run = nil

    -- HUD (drawRunBanner) : bandeau de run riche (reliques/or/vies/descente/round/slots/streak/tier) -> no crash.
    b:drawRunBanner({ gold = 12, wins = 3, round = 5, slots = 6, lives = 4, winStreak = 3, lossStreak = 0, shopTier = 3, relics = {} })
    b:drawRunBanner({ gold = 0, wins = 0, round = 1, slots = 3, lives = 1, winStreak = 0, lossStreak = 2, shopTier = 1, relics = {} })
    b:drawSigilBar() -- barre sigil/archétype (lit b.board.shape) -> no crash
    assert(b:shapeBtnRect(1) and b:shapeBtnRect(#require("src.board.shapes").order), "shapeBtnRect : rects de boutons de forme valides")

    -- AURAS (refonte build screen, phase 2) : resolveAuraLinks récolte les liens d'adjacence pour l'affichage ;
    -- drawAuraChips/drawAuraChip (icône Keywords + écusson shield) ne crashent pas headless.
    b.host.run = nil
    b.board:setShape("carre"); b.board:unlock(9); b:computeLayout()
    b:placeId(5, "templar"); b:placeId(4, "marauder"); b:placeId(6, "skeleton")
    local links = b:resolveAuraLinks()
    assert(#links >= 2, "resolveAuraLinks : templar(shield_aura) -> 2 voisins occupés = >=2 liens")
    assert(links[1].kind == "shield" and links[1].label:match("^%+%d"), "resolveAuraLinks : lien shield +N lisible")
    b:drawAuraChips({ auraLinks = links }) -- shield (écusson primitif)
    b:drawAuraChip(120, 120, "poison", "+50%") -- icône d'affliction (Keywords)
    b.slotRigs[5] = nil; b.board.slots[5].unit = nil; b:placeId(5, "gravewarden") -- taunt -> chemin badge TAUNT

    -- ── FIT-TO-BOX (anti-débordement des créatures) : rigBounds renvoie une boîte SAINE (repli headless,
    -- pas de canvas réel sous le mock) ; rigFitScale CONTIENT dans la boîte et RESPECTE maxScale (cap). ──
    local bnd = b:rigBounds("marauder")
    assert(bnd and bnd.w > 0 and bnd.h > 0 and bnd.bot, "rigBounds : boite { w, h, top, bot } valide")
    assert(b:rigBounds("marauder") == bnd, "rigBounds : memoise par id (meme objet)")
    -- cap par défaut = 1 (cases/cartes : on RÉTRÉCIT seulement, jamais d'agrandissement sauvage).
    local sCell = b:rigFitScale("marauder", 18, 18, 0.94)
    assert(sCell > 0 and sCell <= 1, "rigFitScale : borne (0,1] par défaut (case = downscale)")
    -- la créature TIENT dans la boîte : étendue*scale <= boîte (jamais coupée).
    assert(bnd.w * sCell <= 18 + 0.01 and bnd.h * sCell <= 18 + 0.01, "rigFitScale : contient (w,h) dans la case")
    -- maxScale autorise l'AGRANDISSEMENT (portrait de fiche : petit sprite -> remplit le logement).
    local sBig = b:rigFitScale("plague_doctor", 280, 72, 0.82, 3.5)
    assert(sBig > 1 and sBig <= 3.5, "rigFitScale : maxScale autorise l'upscale du portrait (cap respecté)")
  end

  -- ── CHUNK C : re-skin forge des scènes relicpick / menu / runover (construit+update+draw+souris/clavier
  -- headless sans crash ; golden inchangé car RENDER pur). On vérifie aussi le hit-test/layout (logique pure).
  local view = { ox = 0, oy = 0, scale = 4 }
  local Palette = require("src.core.palette")

  -- Relicpick : 3 cartes forge (Layout.row, gouttières égales) + BIND bouton-œil. host stub recoit le pick.
  do
    local Relicpick = require("src.scenes.relicpick")
    local picked = nil
    local host = { finishRelicPick = function(id) picked = id end }
    local rp = Relicpick.new(Palette, 320, 180, host, { choices = { "bloodstone", "ember_heart", "aegis" } })
    assert(#rp.cards == 3, "relicpick : 3 cartes")
    -- gouttières ÉGALES entre cartes (Layout.row) ; pas de carte hors-bande.
    assert(rp.cards[2].x - (rp.cards[1].x + rp.cards[1].w) == rp.cards[3].x - (rp.cards[2].x + rp.cards[2].w),
      "relicpick : cartes à gouttières égales")
    rp:update(1.0)
    rp:drawBack(view); rp:drawWorld(); rp:drawOverlay(view)
    -- survol d'une carte (coords virtuelles : centre de la carte 1 ÷4) -> hover ; clic -> sélection.
    local c1 = rp.cards[1]
    rp:mousemoved((c1.x + c1.w / 2) / 4, (c1.y + c1.h / 2) / 4)
    assert(rp.hover == 1, "relicpick : survol carte 1")
    rp:mousepressed((c1.x + c1.w / 2) / 4, (c1.y + c1.h / 2) / 4, 1)
    assert(rp.sel == 1, "relicpick : clic sélectionne la carte 1")
    rp:drawOverlay(view) -- carte sélectionnée = rich (œil) + BIND actif
    -- BIND : survol + clic -> confirme le pick.
    local bd = rp.bind
    rp:mousemoved((bd.x + bd.w / 2) / 4, (bd.y + bd.h / 2) / 4)
    assert(rp.bindHover, "relicpick : survol BIND")
    rp:mousepressed((bd.x + bd.w / 2) / 4, (bd.y + bd.h / 2) / 4, 1)
    rp:mousereleased()
    rp:update(60) -- ⭐ mûrit l'action différée (Feel) : le press du BIND est visible avant la confirmation
    assert(picked == "bloodstone", "relicpick : BIND confirme le pick de la carte 1 (apres differe)")
    rp:keypressed("2"); assert(rp.sel == 2, "relicpick : touche 2 sélectionne")
    rp:keypressed("return") -- confirme via clavier (no crash)
  end

  -- Menu : entrées = boutons forge (ENTER = cta), Layout.column centrée. host stub recoit les actions.
  do
    local Menu = require("src.scenes.menu")
    local went = nil
    local host = { newRun = function() went = "run" end, goto = function(n) went = n end }
    local mn = Menu.new(Palette, 320, 180, host)
    assert(#mn.items >= 5, "menu : entrées construites")
    for _, it in ipairs(mn.items) do assert(it.rect and it.rect.w > 0, "menu : chaque entrée a un rect de hit-test") end
    assert(mn.items[1].kind == "cta", "menu : ENTER = entrée HÉROS (kind cta)")
    -- LAYOUT : TOUTES les entrées tiennent à l'ÉCRAN (jamais coupées sous le pied @690) et restent SOUS le
    -- diviseur (444). Les entrées secondaires gardent une gouttière ÉGALE (rythme régulier) ET les rects de
    -- hit-test ne se CHEVAUCHENT PAS (gouttière >= 0 -> chaque pixel cliqué appartient à une seule entrée).
    for _, it in ipairs(mn.items) do
      assert(it.rect.y >= 444, "menu : entrée sous le diviseur (pas de chevauchement du titre)")
      assert(it.rect.y + it.rect.h <= 690, "menu : entrée AU-DESSUS du pied (jamais coupée hors écran)")
    end
    local sec = {} -- entrées non-CTA (secondaires + désactivées), dans l'ordre vertical
    for _, it in ipairs(mn.items) do if it.kind ~= "cta" then sec[#sec + 1] = it.rect end end
    table.sort(sec, function(a, b) return a.y < b.y end)
    if #sec >= 3 then
      local g1 = sec[2].y - (sec[1].y + sec[1].h)
      for k = 1, #sec - 1 do
        local gk = sec[k + 1].y - (sec[k].y + sec[k].h)
        assert(gk >= 0, "menu : rects de hit-test sans chevauchement (gouttière >= 0)")
        assert(math.abs(gk - g1) <= 1, "menu : gouttières ÉGALES entre entrées non-CTA")
      end
    end
    mn:update(1.0)
    mn:drawBack(view); mn:drawWorld(); mn:drawOverlay(view)
    -- CLIQUABILITÉ (le cœur) — survol + clic sur ENTER -> déclenche newRun. ⭐ ACTION DIFFÉRÉE (bible §4) :
    -- le clic ARME l'action (~160 ms) au lieu de la lancer au release. Le feedback est immédiat (mn.down) ;
    -- l'action fire dans mn:update(dt) quand le délai est écoulé -> on POMPE une grosse frame pour la mûrir.
    -- La souris arrive en VIRTUEL (centre du rect ÷4) ; le menu la repasse en design (×4) pour le hit-test.
    local r1 = mn.items[1].rect
    mn:mousemoved((r1.x + r1.w / 2) / 4, (r1.y + r1.h / 2) / 4)
    assert(mn.hover == 1, "menu : survol de ENTER")
    mn:mousepressed((r1.x + r1.w / 2) / 4, (r1.y + r1.h / 2) / 4, 1)
    assert(mn.down, "menu : pointer-down arme l'entrée (feedback immédiat)")
    assert(went == nil, "menu : l'action est DIFFÉRÉE (pas firée au press)")
    mn:drawOverlay(view)             -- pressé (squash + flash actifs)
    mn:mousereleased((r1.x + r1.w / 2) / 4, (r1.y + r1.h / 2) / 4, 1)
    assert(went == nil, "menu : le release NE re-déclenche PAS (anti double-fire)")
    mn:update(60)                    -- pompe ~1 s : le délai (~0,16 s) est écoulé -> l'action FIRE
    assert(went == "run", "menu : l'action différée de ENTER lance la run après le délai")
    -- CLIQUABILITÉ d'une entrée SECONDAIRE (preuve au-delà du CTA) : GRIMOIRE -> host.goto("grimoire").
    local gi
    for i, it in ipairs(mn.items) do if it.id == "grimoire" then gi = i end end
    local rg = mn.items[gi].rect
    went = nil
    mn:mousemoved((rg.x + rg.w / 2) / 4, (rg.y + rg.h / 2) / 4)
    assert(mn.hover == gi, "menu : survol de GRIMOIRE")
    mn:mousepressed((rg.x + rg.w / 2) / 4, (rg.y + rg.h / 2) / 4, 1)
    mn:mousereleased((rg.x + rg.w / 2) / 4, (rg.y + rg.h / 2) / 4, 1)
    mn:update(60)                    -- mûrit l'action différée
    assert(went == "grimoire", "menu : clic sur GRIMOIRE ouvre le grimoire (après le différé)")
    -- clavier : navigation + validation (action différée via Feel.fire) -> mûrir puis vérifier que ça agit.
    went = nil
    mn:keypressed("down"); mn:keypressed("up")
    -- repositionne le focus sur ENTER puis valide au clavier.
    mn.hover = 1; mn:keypressed("return")
    mn:update(60)
    assert(went == "run", "menu : validation clavier (return) déclenche l'action différée")
    -- entrée scellée (rites) : non hoverable / non cliquable.
    local sealed
    for i, it in ipairs(mn.items) do if it.id == "rites" then sealed = i end end
    local rs = mn.items[sealed].rect
    assert(mn:itemAt(rs.x + 1, rs.y + 1) == nil, "menu : entrée scellée ignorée au hit-test")
  end

  -- Runover : panneau forge + bannière (win/defeat) + bouton-œil de relance. host stub recoit newRun.
  do
    local Runover = require("src.scenes.runover")
    for _, res in ipairs({ "win", "lose" }) do
      local restarted = false
      local host = { newRun = function() restarted = true end }
      local ro = Runover.new(Palette, 320, 180, host,
        { result = res, run = { wins = 7, losses = 2, round = 12, level = 5 } })
      assert(ro.panel and ro.cta, "runover : panneau + bouton construits")
      ro:update(1.0)
      ro:drawBack(view); ro:drawWorld(); ro:drawOverlay(view)
      local cta = ro.cta
      ro:mousemoved((cta.x + cta.w / 2) / 4, (cta.y + cta.h / 2) / 4)
      assert(ro.ctaHover, "runover : survol du bouton de relance")
      ro:drawOverlay(view) -- bouton survolé (œil ouvert)
      ro:mousepressed((cta.x + cta.w / 2) / 4, (cta.y + cta.h / 2) / 4, 1)
      ro:mousereleased()
      ro:update(60) -- ⭐ mûrit l'action différée (Feel) : le press du CTA est visible avant la relance
      assert(restarted, "runover : clic relance la run (" .. res .. ", apres differe)")
    end
    -- relance clavier [r] (no crash).
    local ro2 = Runover.new(Palette, 320, 180, { newRun = function() end }, { result = "lose" })
    ro2:keypressed("r")
  end
end)

if ok then
  print("=> UI OK : Frame + Chip + Keywords + Theme.state + Forge (nightmare-forge kit).")
else
  print("=> UI FAIL :")
  print(err)
  os.exit(1)
end
