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
local Frameforge = require("src.scenes.frameforge")

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
  -- diamondAt : draw direct (no-op headless, ne crashe pas).
  Forge.diamondAt(20, 20, 3, { 0.8, 0.7, 0.3 })

  -- ── Frameforge : la scène-showcase construit + update + draw headless sans crash ──
  local hostStub = { name = "menu", menu = {} }
  local scene = Frameforge.new({}, 320, 180, hostStub)
  assert(#scene.cells > 0, "frameforge : cellules construites")
  local view = { ox = 0, oy = 0, scale = 4 }
  scene:update(1.0)
  scene:drawBack(view)
  scene:drawWorld()
  scene:drawOverlay(view)
  scene:mousemoved(24, 54)          -- survol (coords virtuelles) -> entre dans des cellules live
  scene:mousepressed(24, 54, 1)     -- clic
  scene:update(1.0)                 -- anime l'easing
  scene:drawOverlay(view)
  scene:mousereleased(24, 54, 1)
  scene:keypressed("tab")           -- cycle d'accent (no crash)

  -- ── TUNER : PX + tailles ; cycle de paramètre + ajustement -> change la valeur ET re-bake (no crash). ──
  assert(#scene.tuned > 0, "tuner : des boutons-heros tunables existent")
  assert(scene.tune.px == 2 and scene.tune.bw == 108 and scene.tune.bh == 30 and scene.tune.fontSz == 8
    and scene.tune.pad == 5 and scene.tune.eyeR == 8, "defauts small-first dense (PX2 108x30 font8 pad5 eye8)")
  -- param 1 = PX (densite ecran). L'ajuster change le PX d'affichage des boutons-heros (cell.px).
  assert(scene.tuneSel == 1, "param 1 = PX par defaut")
  scene:adjustTune(1)               -- PX 2 -> 3
  assert(scene.tune.px == 3, "adjustTune PX +1")
  for _, c in ipairs(scene.tuned) do assert(c.px == 3, "re-bake propage cell.px = PX tune") end
  scene:adjustTune(-1)              -- PX 3 -> 2
  assert(scene.tune.px == 2, "adjustTune PX -1")
  scene:keypressed("t")             -- selectionne BTN-W
  assert(scene.tuneSel == 2, "[t] cycle le parametre (-> BTN-W)")
  local before = scene.tune.bw
  scene:keypressed("up")            -- BTN-W +step (4)
  assert(scene.tune.bw == before + 4, "[up] ajuste BTN-W de step")
  scene:keypressed("down")
  assert(scene.tune.bw == before, "[down] revient")
  -- clamp aux bornes : on pousse fort dans les deux sens (max 160 / min 48 pour BTN-W).
  for _ = 1, 80 do scene:adjustTune(1) end
  assert(scene.tune.bw <= 160, "tune borne au max")
  for _ = 1, 80 do scene:adjustTune(-1) end
  assert(scene.tune.bw >= 48, "tune borne au min")
  scene:drawOverlay(view)           -- redessine page 1 avec le tuner apres re-bakes

  scene:keypressed("space")         -- page 2
  assert(scene.page == 2, "frameforge : [space] passe page 2")
  scene:drawOverlay(view)           -- dessine la page 2 (cadres/cartes/atomes) sans crash
  scene:mousemoved(40, 120); scene:mousepressed(40, 120, 1); scene:mousereleased(40, 120, 1)
  scene:keypressed("m")             -- retour menu (host stub)
  assert(hostStub.name == "menu", "frameforge : [m] revient au menu")

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

  -- ── Forge.cardPanel / uiCard : fond de fiche monstre (plaque qui respire + cadre patiné). Headless-safe.
  do
    local wv = Forge.newWidget(150, 200)
    Forge.render(wv, function(b, W, H, t)
      Forge.cardPanel(b, W, H, t, { accentCol = Forge.accentFrom({ 200, 150, 70 }), rich = true, seed = 42 })
    end, 1.0)
    Forge.uiCard("t.card", 0, 0, 312, 380, { px = 2, seed = 5, rich = false })
    Forge.uiCard("t.card", 0, 0, 312, 380, { px = 2, seed = 5, rich = true, accentCol = Forge.accentFrom({ 0.8, 0.6, 0.3 }) })
    assert(Forge._cardCache["t.card"], "uiCard : cache par id cree")
  end

  -- ── Build : fiche monstre TCG (helpers PURS + smoke de rendu headless de la carte) ──────────────
  do
    local Build = require("src.scenes.build")
    -- helpers PURS : rôle dérivé d'aggro/taunt + valeur d'affliction depuis les params.
    assert(Build.roleOf({ taunt = true }) == "tank", "taunt -> tank")
    assert(Build.roleOf({ aggro = 40 }) == "tank", "aggro>=30 -> tank")
    assert(Build.roleOf({ aggro = 5 }) == "carry", "aggro<=7 -> carry")
    assert(Build.roleOf({ aggro = 15 }) == "bruiser", "aggro intermediaire -> bruiser")
    assert(Build.roleOf({}) == "carry", "sans aggro (=0) -> carry")
    assert(Build.afflValue({ dps = 6, dur = 180 }) == "6 dps 3s", "afflValue : dps + duree en secondes")
    assert(Build.afflValue({ dps = 2 }) == "2 dps", "afflValue : dps seul")
    assert(Build.afflValue({}) == nil, "afflValue : sans dps/dur -> nil")
    assert(Build.afflValue(nil) == nil, "afflValue : nil -> nil")

    -- Smoke : construit la scène, pose une unité à afflictions (burn) ET un héros (rank>=4), et dessine la
    -- fiche directement (hors hover) -> ne plante pas sous le mock LÖVE, golden non touché (RENDER pur).
    local Palette = require("src.core.palette")
    local b = Build.new(Palette, 320, 180, { goto = function() end })
    b.view = { ox = 0, oy = 0, scale = 4 }
    b.mx, b.my = 100, 60
    b:drawTooltip("emberling")     -- pose burn (chip à valeurs) + R2 (cadre sobre)
    b:drawTooltip("plague_doctor") -- regen, R4 (cadre riche + œil + halo)
    b:drawTooltip("marauder")      -- vanille, pas d'affliction, pas de family/rank
    b:drawTooltip("skull_colossus") -- R5 avec family

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
    assert(picked == "bloodstone", "relicpick : BIND confirme le pick de la carte 1")
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
    for _, it in ipairs(mn.items) do assert(it.rect and it.rect.w > 0, "menu : chaque entrée a un rect Layout") end
    assert(mn.items[1].tone == "cta", "menu : ENTER = bouton-œil cta")
    -- LAYOUT (FIX overflow) : TOUTES les entrées tiennent à l'ÉCRAN (jamais coupées sous le pied @690) et
    -- restent SOUS le diviseur (444). Les entrées secondaires gardent une gouttière ÉGALE (rythme régulier).
    for _, it in ipairs(mn.items) do
      assert(it.rect.y >= 444, "menu : entrée sous le diviseur (pas de chevauchement du titre)")
      assert(it.rect.y + it.rect.h <= 690, "menu : entrée AU-DESSUS du pied (jamais coupée hors écran)")
    end
    local sec = {} -- entrées secondaires (hors CTA), dans l'ordre vertical
    for _, it in ipairs(mn.items) do if it.tone ~= "cta" then sec[#sec + 1] = it.rect end end
    table.sort(sec, function(a, b) return a.y < b.y end)
    if #sec >= 3 then
      local g1 = sec[2].y - (sec[1].y + sec[1].h)
      for k = 2, #sec - 1 do
        local gk = sec[k + 1].y - (sec[k].y + sec[k].h)
        assert(math.abs(gk - g1) <= 1, "menu : gouttières ÉGALES entre entrées secondaires")
      end
    end
    mn:update(1.0)
    mn:drawBack(view); mn:drawWorld(); mn:drawOverlay(view)
    -- survol + clic-relâché sur ENTER -> déclenche newRun.
    local r1 = mn.items[1].rect
    mn:mousemoved((r1.x + r1.w / 2) / 4, (r1.y + r1.h / 2) / 4)
    assert(mn.hover == 1, "menu : survol de ENTER")
    mn:mousepressed((r1.x + r1.w / 2) / 4, (r1.y + r1.h / 2) / 4, 1)
    mn:drawOverlay(view) -- pressé (active)
    mn:mousereleased((r1.x + r1.w / 2) / 4, (r1.y + r1.h / 2) / 4, 1)
    assert(went == "run", "menu : clic sur ENTER lance la run")
    mn:keypressed("down"); mn:keypressed("up"); mn:keypressed("return") -- navigation clavier (no crash)
    -- entrée scellée (rites) : non hoverable.
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
      assert(restarted, "runover : clic relance la run (" .. res .. ")")
    end
    -- relance clavier [r] (no crash).
    local ro2 = Runover.new(Palette, 320, 180, { newRun = function() end }, { result = "lose" })
    ro2:keypressed("r")
  end
end)

if ok then
  print("=> UI OK : Frame + Chip + Keywords + Theme.state + Forge (nightmare-forge kit) + Frameforge showcase.")
else
  print("=> UI FAIL :")
  print(err)
  os.exit(1)
end
