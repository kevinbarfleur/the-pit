-- feel-lab/lib/attacksprites.lua
-- ╔══════════════════════════════════════════════════════════════════════════════════════════════════╗
-- ║  SPRITES D'ATTAQUE PIXEL PAR TYPE DE DÉGÂT — semi-pixel NET, bakés une fois, glow-shader-ready.     ║
-- ╚══════════════════════════════════════════════════════════════════════════════════════════════════╝
--
-- DIRECTION (révisée) : PLUS de projectile qui traverse l'écran (les streaks tuent la lisibilité). Le coup
-- d'attaque = un ÉCLAT DE DÉPART à l'émetteur (cast/muzzle) + un IMPACT DIRECTIONNEL sur la cible (qui semble
-- venir de l'émetteur). L'IMPACT est la STAR : structure CŒUR clair/ivoire + HALO de couleur du type, pour que
-- le glow SHADER additif que game-feel pose par-dessus accroche bien. Silhouette lisible « directionnelle »
-- (game-feel l'oriente face à l'émetteur) ; assez de frames pour un bloom satisfaisant.
--
--   AS.cast(cause)   -> ÉCLAT DE DÉPART à l'émetteur (muzzle/cast flash, 2-3 frames coloré par type), ou nil.
--   AS.impact(cause) -> BURST D'IMPACT sur la cible — LA STAR. Cœur ivoire + halo de couleur, 4-5 frames.
--   AS.bolt(cause)   -> FRAPPE INSTANTANÉE posée SUR la cible (foudre = éclair zigzag ; physique = croissant
--                       de taille tranchant), ou nil.
--   AS.proj(cause)   -> DÉ-PRIORISÉ (plus de long voyage visible) : nil partout (gardé pour le contrat).
--   AS.tint(cause)   -> {r,g,b} teinte additive par défaut de la cause (= Theme.c afflictions), ou nil.
-- Une frame = { image=Image, w, h } (sortie de Sprite.bake). Une liste de frames = { frame, frame, ... }.
--
-- DA : même langage chromatique/formel que src/render/affliction_fx.lua / affliction_icons.lua — cœur BLANC +
-- halo de couleur (cf. les étincelles radiales/jaggedBolt cœur-blanc/halo-jaune du choc). Chars VIFS
-- (J/k/j/u/U/w) calés sur Theme.c (shock/burn/poison/bleed/rot) — cf. feel-lab/lib/palette.lua.
--
-- PIPELINE : on RÉUTILISE Sprite.bake (grille ASCII + palette -> Image nearest). Aucun pixel dessiné par
-- frame : tout baké UNE fois dans AS.load() (idempotent). Headless-safe : sans love.graphics, load() est un
-- no-op et les getters renvoient nil. game-feel CONSOMME via AS.cast/impact/bolt/proj/tint.

local Sprite  = require("lib.sprite")
local Palette = require("lib.palette")

local AS = {}

-- ════════════════════════════════════════════════════════════════════════════════════════════════════
-- GRILLES ASCII — '.' = transparent. Chars = clés de Palette (Wraeclast). Lignes du HAUT en premier.
-- Highlights vifs : J=choc, k=burn, j=poison, u=bleed(U=sombre), w=rot. W=cœur ivoire (commun à tous).
-- Toutes les planches d'IMPACT sont DIRECTIONNELLES : le « poids » penche vers la GAUCHE (côté émetteur),
-- la gerbe/éclats fusent vers la DROITE (sens du coup). game-feel oriente la planche face à l'émetteur.
-- ════════════════════════════════════════════════════════════════════════════════════════════════════

-- ════════════════════════════════════════════════════════════════════════════════════════════════════
-- ATTACK (PHYSIQUE) — PREMIÈRE CLASSE. Acier + sang. cast = étincelle d'acier au départ ; bolt = CROISSANT
-- de taille tranchant ; impact = GERBE acier/sang directionnelle (cœur ivoire, fil acier, projections sang).
-- ════════════════════════════════════════════════════════════════════════════════════════════════════
-- CAST attack : éclat d'acier au moment du swing (départ). Petit, net, gris-clair -> sang.
local G_ATTACK_CAST = {
  { "..W..", ".WSW.", "WSqSW", ".WSW.", "..W.." },
  { ".W.W.", "W.q.W", ".qWq.", "W.q.W", ".W.W." },
  { "q...q", "..W..", ".WSW.", "..W..", "q...q" },
}
-- BOLT attack : CROISSANT DE TAILLE tranchant (fil W ivoire -> S acier -> q/R sang). 3 frames : l'arc entre,
-- s'épaissit au plein swing (vrai « C »), puis se sanglote en gouttes. Premium, lecture « lame ».
local G_ATTACK_BOLT = {
  { -- frame 1 : fil de lame fin qui entre par le haut-droit
    ".......WS.",
    "......WSq.",
    ".....WSq..",
    ".....Sq...",
    "....Sq....",
    "...Sq.....",
    "..Sq......",
    "..q.......",
    "..........",
  },
  { -- frame 2 : plein swing — CROISSANT incurvé large, fil sanglant
    "....WWSq..",
    "..WWSSq...",
    ".WWSq.....",
    ".WSq......",
    "WWSq......",
    "WWSq......",
    ".WSq......",
    ".WWSq.....",
    "..WWSSq...",
  },
  { -- frame 3 : fin de course, l'arc se dissipe en gouttes de sang
    "....WSq...",
    "...WSq....",
    "..WSq.R...",
    "..Sq..R...",
    ".Sq..r....",
    ".q...r....",
    ".q..R.....",
    "....rR....",
    "...r......",
  },
}
-- IMPACT attack : GERBE D'ACIER + ÉCLABOUSSURE DE SANG. Cœur ivoire (flash métal) ; fil acier S au centre ;
-- éclats/gouttes de sang q/R/r projetés vers la DROITE (sens du coup). 5 frames : flash -> gerbe -> sang.
local G_ATTACK_IMPACT = {
  { -- 1 : flash de contact (cœur ivoire dense, amorce d'éclats)
    "..........",
    "....WW....",
    "...WSqW...",
    "..WSqqSW..",
    "..WSqqSW..",
    "...WSqW...",
    "....WW....",
    "..........",
    "..........",
    "..........",
  },
  { -- 2 : la gerbe s'ouvre — fil acier horizontal + premiers éclats
    "....W.....",
    "...WSq....",
    "..WSqSq...",
    ".WSqqqSqW.",
    "qSSqWWSqSq",
    ".WSqqqSqW.",
    "..WSqSq...",
    "...WSq....",
    "....q.....",
    "..........",
  },
  { -- 3 : APEX — éclats d'acier qui fusent à droite + sang qui jaillit
    "...W...q..",
    "..WS.q.R..",
    ".WSq.qSq..",
    "WSqWWqqSqR",
    "SqWWWWqSqq",
    "WSqWWqqSqR",
    ".WSq.qSq..",
    "..WS.q.R..",
    "...W...q..",
    ".......r..",
  },
  { -- 4 : retombée — surtout du sang projeté (l'acier s'éteint)
    "..R....q..",
    "...r.q.R..",
    "..q.qSq.r.",
    ".R.qWqq.qR",
    "..qWWWq.qq",
    ".R.qWqq.qR",
    "..q.qSq.r.",
    "...r.q.R..",
    "..R....q..",
    "....r..r..",
  },
  { -- 5 : gouttes finales qui s'égrènent (silhouette directionnelle, traîne à droite)
    ".R........",
    "...r....R.",
    "..R..r.r..",
    ".r..R..rR.",
    "....q.r..r",
    ".r..R..rR.",
    "..R..r.r..",
    "...r....R.",
    ".R......r.",
    "..........",
  },
}

-- ════════════════════════════════════════════════════════════════════════════════════════════════════
-- BURN (FEU) — braise orange + pointe jaune chaud. cast = bouffée de flamme ; impact = ÉCLOSION de flamme
-- (bloom) cœur ivoire/jaune -> orange -> braise éteinte. bolt = flammèche directe.
-- ════════════════════════════════════════════════════════════════════════════════════════════════════
local G_BURN_CAST = {
  { "..T..", ".TkT.", ".kWk.", "..o..", "..o.." },
  { ".T.T.", "TkWkT", ".kWk.", ".o.o.", "..o.." },
  { "T...T", ".k.k.", "..W..", ".o.o.", "o...o" },
}
local G_BURN_BOLT = {
  { "...T..", "..TWk.", ".TWkk.", ".kkko.", "..oo..", "..o..." },
  { "....T.", "..TWWk", ".TWkk.", "kkko..", ".oo...", ".o...." },
}
-- IMPACT burn : ÉCLOSION (bloom). Noyau ivoire/jaune chaud (W/T) -> corps orange (k) -> braise froide (o).
-- 5 frames : noyau -> couronne de langues -> floraison pleine -> braises projetées -> cendres.
local G_BURN_IMPACT = {
  { -- 1 : noyau chaud
    "..........",
    "....TT....",
    "...TWWT...",
    "..TWkkWT..",
    "..TWkkWT..",
    "...TWWT...",
    "....kk....",
    ".....o....",
    "..........",
    "..........",
  },
  { -- 2 : couronne qui s'ouvre, langues vers le haut
    "....T.....",
    "..T.WT.T..",
    "..TWkWkT..",
    ".TWkkkWkT.",
    "TkWkWWkWkT",
    ".TWkkkWkT.",
    "..kWkWko..",
    "...kooo...",
    "..o.o.o...",
    "..........",
  },
  { -- 3 : floraison pleine (APEX), pétales de flamme
    "..T.T.T...",
    ".TWkkkWT..",
    "T.WkWkW.T.",
    ".TkWWWkT..",
    "TkWWkWWkTo",
    ".TkWWWkT..",
    "T.kWkWk.o.",
    ".okkokko..",
    "..o.o.o.o.",
    ".o.....o..",
  },
  { -- 4 : braises projetées (la flamme s'effondre)
    ".k.....k..",
    "..k.T.k...",
    "...kWk....",
    "..o.k.o.o.",
    ".o..o..o..",
    "..o.o.o.o.",
    "o..o.o..o.",
    "..o..o..o.",
    ".o.....o..",
    "..........",
  },
  { -- 5 : cendres résiduelles (lueur mourante, directionnelle vers le haut)
    "...o......",
    ".o...o....",
    "....o...o.",
    "..o...o...",
    ".o..o...o.",
    "...o..o...",
    "..o....o..",
    ".o...o....",
    "....o.....",
    "..........",
  },
}

-- ════════════════════════════════════════════════════════════════════════════════════════════════════
-- SHOCK (FOUDRE) — jaune élec. cast = micro-arc qui s'amorce ; bolt = ÉCLAIR ZIGZAG dentelé scintillant ;
-- impact = ÉTOILE d'étincelles radiale (cœur ivoire -> branches jaunes).
-- ════════════════════════════════════════════════════════════════════════════════════════════════════
local G_SHOCK_CAST = {
  { "..J..", ".JWJ.", "JW.WJ", ".JWJ.", "..J.." },
  { "J.J.J", ".JWJ.", "JW.WJ", ".JWJ.", "J.J.J" },
  { "J...J", "..W..", ".JWJ.", "..W..", "J...J" },
}
local G_SHOCK_BOLT = {
  { -- 1
    "...JW..",
    "..JW...",
    "..WJ...",
    "...JW..",
    "...WJ..",
    "..JW...",
    ".JW....",
    ".W.....",
  },
  { -- 2 : coudes décalés (scintille)
    "...WJ..",
    "..WJ...",
    "..JW...",
    ".JW....",
    "..WJ...",
    "...JW..",
    "..JW...",
    "..W....",
  },
  { -- 3 : ramifié (petite fourche)
    "...JW..",
    "..JWJ..",
    "..WJ...",
    "..JW...",
    ".JWJ...",
    "..WJ...",
    "...JW..",
    "...W...",
  },
}
-- IMPACT shock : ÉTOILE radiale. Cœur ivoire (W) compact -> branches dentelées jaunes (J). 5 frames :
-- flash -> branches -> pleine étoile -> étincelles qui filent -> motes résiduelles.
local G_SHOCK_IMPACT = {
  { -- 1 : flash compact
    ".........",
    "....J....",
    "....W....",
    "..J.W.J..",
    "...WWW...",
    "..J.W.J..",
    "....W....",
    "....J....",
    ".........",
  },
  { -- 2 : croix qui s'allonge
    "....J....",
    "....W....",
    "..J.W.J..",
    "...WWW...",
    "JWWWWWWWJ",
    "...WWW...",
    "..J.W.J..",
    "....W....",
    "....J....",
  },
  { -- 3 : ÉTOILE pleine (APEX) — branches dentelées
    "..J.J.J..",
    "J..JWJ..J",
    ".J.JWJ.J.",
    "..JWWWJ..",
    "JWWWWWWWJ",
    "..JWWWJ..",
    ".J.JWJ.J.",
    "J..JWJ..J",
    "..J.J.J..",
  },
  { -- 4 : étincelles qui filent en diagonale
    "J.J...J.J",
    ".J.J.J.J.",
    "..J.W.J..",
    "...WWW...",
    ".J.WWW.J.",
    "...WWW...",
    "..J.W.J..",
    ".J.J.J.J.",
    "J.J...J.J",
  },
  { -- 5 : motes résiduelles qui s'éteignent
    "J.......J",
    "...J.J...",
    ".J.....J.",
    "....W....",
    "..J.W.J..",
    "....W....",
    ".J.....J.",
    "...J.J...",
    "J.......J",
  },
}

-- ════════════════════════════════════════════════════════════════════════════════════════════════════
-- POISON (vert toxique) — cast = crachat ; impact = SPLAT/flaque qui gicle (cœur ivoire -> vert).
-- ════════════════════════════════════════════════════════════════════════════════════════════════════
local G_POISON_CAST = {
  { "..z..", ".zjz.", "zjWjz", ".zjz.", "..z.." },
  { ".z.z.", "z.j.z", ".jWj.", "z.j.z", ".g.g." },
  { "z...z", "..W..", ".zjz.", "..g..", "g...g" },
}
-- IMPACT poison : SPLAT/FLAQUE. Cœur ivoire d'éclatement (W) -> corps vert vif (j) -> ombre (Z/g). Gouttes
-- qui giclent vers le haut puis flaque qui s'étale (bas). 5 frames.
local G_POISON_IMPACT = {
  { -- 1 : impact compact
    "..........",
    "....z.....",
    "...zjWz...",
    "..zjWWjz..",
    "..zjWWjz..",
    "...zjjz...",
    "....Zg....",
    "..........",
    "..........",
    "..........",
  },
  { -- 2 : éclatement, gouttes vers le haut
    "...z.z....",
    "..z.j.z...",
    "...zjWz...",
    "..zjWWjz..",
    ".zjWWWWjz.",
    "..zjWWjz..",
    "..ZjjjZg..",
    "...ZggZ...",
    "....g.....",
    "..........",
  },
  { -- 3 : APEX — couronne + flaque qui naît
    "z..z.z..z.",
    ".z.j.j.z..",
    "..zjWWjz..",
    ".zjWWWWjz.",
    "zjWWjjWWjz",
    ".zjWWWWjz.",
    ".ZjjjjjZg.",
    "ZZjjggjZgg",
    "..Zg.gZg..",
    "...g..g...",
  },
  { -- 4 : la flaque s'étale, retombées
    "z........z",
    "..z....z..",
    "....j.z...",
    "..zjWWjz..",
    ".zjjWWjjz.",
    "ZjjjjjjjZg",
    "ZZjjjjjZgg",
    "ZZZggggZgg",
    ".Zg.g.gZ..",
    "..........",
  },
  { -- 5 : flaque résiduelle + une bulle qui remonte
    "..........",
    "....z.....",
    "...zZz....",
    "..........",
    "..ZjjjZ...",
    ".ZjjjjjZg.",
    "ZZjjjjjZgg",
    "ZZZgggZggg",
    "..ZggZg...",
    "..........",
  },
}

-- ════════════════════════════════════════════════════════════════════════════════════════════════════
-- BLEED (cramoisi) — cast = gerbe rapide ; impact = ÉCLABOUSSURE de sang (cœur ivoire -> cramoisi -> sombre).
-- Plus « liquide projeté/net » que le poison : gouttes franches, peu de flaque.
-- ════════════════════════════════════════════════════════════════════════════════════════════════════
local G_BLEED_CAST = {
  { "..u..", ".uWu.", "uWqWu", ".uUu.", "..U.." },
  { ".u.u.", "u.W.u", ".uqu.", "u.U.u", ".r.r." },
  { "u...u", "..W..", ".uqu.", "..U..", "r...r" },
}
-- IMPACT bleed : ÉCLABOUSSURE. Cœur ivoire (W, flash de contact) -> gerbe cramoisie (u) -> sombre (U/r).
-- 5 frames : flash -> jets -> APEX (gouttes nettes projetées) -> retombée -> traces.
local G_BLEED_IMPACT = {
  { -- 1 : flash de contact
    "..........",
    "....WW....",
    "...WuqW...",
    "..WuqqUW..",
    "..WuqqUW..",
    "...WuUW...",
    "....UU....",
    "..........",
    "..........",
    "..........",
  },
  { -- 2 : premiers jets
    "....W.....",
    "...WuW....",
    "..Wuqu....",
    ".WuqqquW..",
    "uUUqWWuqUu",
    ".WuqqquW..",
    "..WuUu....",
    "...WuU....",
    "....U.....",
    "..........",
  },
  { -- 3 : APEX — gouttes nettes projetées (asymétrie directionnelle vers la droite)
    "..u....u..",
    ".u.W.u.U..",
    "..Wuqu.u..",
    ".WuqWquUu.",
    "uUqWWWquUu",
    ".WuqWquUu.",
    "..Wuqu.u..",
    ".u.W.u.U..",
    "..u....U..",
    ".......r..",
  },
  { -- 4 : retombée — gouttes sombres qui chutent
    ".U.....u..",
    "..r..u.U..",
    ".u..uqu.r.",
    "U..uWqu.uU",
    "...uWWu.uu",
    "U..uWqu.uU",
    ".u..uUu.r.",
    "..r..u.U..",
    ".U.....u..",
    "....r..r..",
  },
  { -- 5 : traces / petite flaque
    "U.......U.",
    "..r...r...",
    ".U..u..U..",
    "...uUu....",
    "..U.u.U.r.",
    ".UUUUU.U..",
    "rUUUUUU.r.",
    "..rUUr....",
    ".U.....r..",
    "..........",
  },
}

-- ════════════════════════════════════════════════════════════════════════════════════════════════════
-- ROT (violet nécrotique) — cast = bouffée de spores ; impact = ÉCLATEMENT de pustule en NUAGE de spores
-- (cœur ivoire -> violet vif -> ombre violette -> spores brunes). Visqueux/malade, mouches en fin.
-- ════════════════════════════════════════════════════════════════════════════════════════════════════
local G_ROT_CAST = {
  { "..w..", ".wMw.", "wMWMw", ".VvV.", "..N.." },
  { ".w.w.", "w.W.w", ".wMw.", "V.v.V", ".N.n." },
  { "w...w", "..W..", ".wMw.", "..V..", "N...n" },
}
-- IMPACT rot : ÉCLATEMENT en SPORES. Cœur ivoire (W) -> chair nécro vive (w) -> ombre violette (V/v) ->
-- spores brunes (N/n) qui dérivent. 5 frames : pustule -> elle crève -> nuage -> spores -> mouches/poussière.
local G_ROT_IMPACT = {
  { -- 1 : pustule tendue (cœur clair)
    "..........",
    "....w.....",
    "...wMWw...",
    "..wMWWMw..",
    "..wWWWMw..",
    "...wMVw...",
    "....Vv....",
    ".....N....",
    "..........",
    "..........",
  },
  { -- 2 : elle crève — premières spores
    "...w.w....",
    "..wMWMw...",
    ".wWWWWMw..",
    ".wMWWMVw..",
    "wMWWWWMVw.",
    ".wMVWMVw..",
    "..wMVVvN..",
    "...VvNn...",
    "....N.....",
    "..........",
  },
  { -- 3 : APEX — nuage de spores qui s'ouvre
    "w..w.w..N.",
    ".wMWMw.v..",
    "w.wWWWw.N.",
    ".wMWWWMVw.",
    "wMWWWWWMVN",
    ".wMVWWMVw.",
    "N.wMVvNv.N",
    ".vVvNnNv..",
    "N..n.n..N.",
    "..........",
  },
  { -- 4 : spores qui dérivent (poussière brune)
    "v....N....",
    "..M.v..N..",
    "....w...v.",
    "..v.N.M.N.",
    ".N..v.v...",
    "..n.N.n.N.",
    "v...v...N.",
    "..N...n...",
    ".v...N...v",
    "..........",
  },
  { -- 5 : mouches/poussière résiduelle (lecture « charogne »)
    "N........v",
    "...n...N..",
    ".v.....n..",
    "....N.....",
    "..n.v.N...",
    "....N.....",
    ".N.....n..",
    "...v.N....",
    "v.......N.",
    "..........",
  },
}

-- ════════════════════════════════════════════════════════════════════════════════════════════════════
-- BAKE — toutes les planches, une fois (idempotent). Headless-safe (Sprite.bake renvoie nil sans love).
-- ════════════════════════════════════════════════════════════════════════════════════════════════════

-- Teintes additives par cause (= Theme.c afflictions ; relues ICI de la palette pour ne pas coupler au Theme).
local function rgb(ch) local c = Palette[ch]; return c and { c[1], c[2], c[3] } or nil end
local TINT = {
  attack = rgb("u"), -- sang vif (le coup physique « saigne » ; halo cramoisi sous le shader)
  burn   = rgb("k"), -- braise orange #e0792e
  shock  = rgb("J"), -- jaune électrique #f2d24a
  poison = rgb("j"), -- vert toxique #93c12f
  bleed  = rgb("u"), -- cramoisi #d8475e
  rot    = rgb("w"), -- violet nécrotique #a86fc4
}

-- Tables de grilles par rôle. nil = ce rôle n'existe pas pour la cause.
-- PROJ dé-priorisé : nil partout (plus de voyage visible). Gardé pour la stabilité du contrat.
local PROJ_GRIDS = {
  attack = nil, burn = nil, shock = nil, poison = nil, bleed = nil, rot = nil,
}
local CAST_GRIDS = {
  attack = G_ATTACK_CAST,
  burn   = G_BURN_CAST,
  shock  = G_SHOCK_CAST,
  poison = G_POISON_CAST,
  bleed  = G_BLEED_CAST,
  rot    = G_ROT_CAST,
}
local IMPACT_GRIDS = {
  attack = G_ATTACK_IMPACT,    -- LA STAR (toute cause a un impact riche)
  burn   = G_BURN_IMPACT,
  shock  = G_SHOCK_IMPACT,
  poison = G_POISON_IMPACT,
  bleed  = G_BLEED_IMPACT,
  rot    = G_ROT_IMPACT,
}
local BOLT_GRIDS = {
  attack = G_ATTACK_BOLT,      -- croissant de taille (mêlée physique)
  burn   = G_BURN_BOLT,        -- flammèche directe
  shock  = G_SHOCK_BOLT,       -- éclair zigzag (frappe instantanée)
  poison = nil,
  bleed  = nil,
  rot    = nil,
}

local loaded = false
local BAKED = { proj = {}, cast = {}, impact = {}, bolt = {} }

local function bakeSet(grids)
  if not grids then return nil end
  local frames = {}
  for _, g in ipairs(grids) do
    local spr = Sprite.bake(g, Palette)
    if spr then frames[#frames + 1] = spr end
  end
  return (#frames > 0) and frames or nil
end

function AS.load()
  if loaded then return end                      -- idempotent
  if not (love and love.graphics and love.image) then return end -- headless : no-op (pas de bake)
  for _, cause in ipairs({ "attack", "burn", "shock", "poison", "bleed", "rot" }) do
    BAKED.proj[cause]   = bakeSet(PROJ_GRIDS[cause])
    BAKED.cast[cause]   = bakeSet(CAST_GRIDS[cause])
    BAKED.impact[cause] = bakeSet(IMPACT_GRIDS[cause])
    BAKED.bolt[cause]   = bakeSet(BOLT_GRIDS[cause])
  end
  loaded = true
end

-- ── Getters (tolèrent l'absence de bake : renvoient nil) ───────────────────────────────────────────
function AS.proj(cause)   return BAKED.proj[cause] end
function AS.cast(cause)   return BAKED.cast[cause] end
function AS.impact(cause) return BAKED.impact[cause] end
function AS.bolt(cause)   return BAKED.bolt[cause] end
function AS.tint(cause)   return TINT[cause] end

return AS
