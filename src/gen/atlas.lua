-- src/gen/atlas.lua
-- ATLAS DE PARTS AUTHORED — bibliothèque de pièces dessinées MAIN (qualité-relique), DATA PURE.
-- Le moteur (src/gen/forge.lua) pioche une part par slot, la RECOLORE par famille, l'assemble
-- via le rig. Aucun love.*, aucune couleur de famille en dur : on dessine en RÔLES neutres,
-- la recoloration vit dans forge.lua (rôle -> caractère de palette, par famille/rampe).
--
-- ─────────────────────────── RÔLES (le vocabulaire neutre) ───────────────────────────
-- Chaque grille est peinte en rôles abstraits. forge.lua mappe rôle -> couleur réelle selon
-- la famille tirée (flesh/bone/order/arcane/abyss), en réutilisant les rampes de factions.lua :
--
--   O  contour            -> outline    (K, ou F adouci pour l'os)
--   1  body CLAIR         -> ramp[1]    (highlight de la silhouette, haut/face éclairée)
--   2  body MOYEN         -> ramp[2..3] (corps)
--   3  body SOMBRE        -> ramp[4]    (bas/creux/ombre portée)
--   s  shade creusé       -> shade      (orbite, sillon, jointure renfoncée — l'anatomie interne)
--   A  accent CLAIR       -> trim       (croc luisant, rivet, liseré, gemme allumée)
--   a  accent SOMBRE      -> accent/dim (ombre de l'accent, racine du croc, creux du rivet)
--   E  œil / pupille      -> accent vif (LE point focal — luit ; surchargé par l'effet de l'unité)
--   .  ou ' ' (espace)    -> TRANSPARENT (ne touche à RIEN — laisse passer le fond/les autres parts)
--
-- RÈGLE D'OR : zéro lettre de palette ici. Que des rôles, et que des STRINGS LITTÉRAUX (data pure :
-- aucune expression Lua dans une grille). Une part `flesh` recolorée `bone` reste lisible parce que
-- la STRUCTURE (contour fermé, ombrage interne, point focal) est authored, pas la couleur. C'est ce
-- qui distingue cet atlas du vieux creaturegen (anatomie aléatoire = brouillon).
--
-- ─────────────────────────── DIMENSIONS / PIVOTS (le moteur calcule le pivot) ───────────────────────────
-- forge.lua dérive le pivot de l'ancrage standard de chaque slot. L'atlas garantit cet ancrage :
--   head   8w × 5-8h   — cou/attache en BAS-CENTRE   (pivot bas-centre)
--   torso  8w × 8h     — base en BAS-CENTRE           (pivot bas-centre)
--   arm    3-5w × 7h   — épaule en HAUT               (pivot top, col centre)
--   legs   7-9w × 6h   — attache en HAUT              (pivot top-centre)
--   weapon 5w × 8h     — MANCHE en HAUT, tête en bas  (pivot top — le bras tient le manche)
--   host   10w × 8h    — base en BAS-CENTRE           (pivot bas-centre)
-- Les cornes/pointes/dards peuvent DÉPASSER le corps vers le haut/les côtés (cf. démon main) : voulu.
--
-- ─────────────────────────── TAGS ───────────────────────────
-- familles    : flesh bone order arcane abyss   (compatibilité chromatique — le recolor fait le pont)
-- body-plans  : humanoid robe deformed (bipèdes)  ·  blob eye (host mono-part)
-- Taguer GÉNÉREUSEMENT : chaque famille a >=1 option par slot. Bras/jambes/armes taguent tous les
-- bipèdes pertinents (ils se recolorent et s'emboîtent quel que soit le corps).

local Atlas = {}

-- ════════════════════════════════════════ HEADS (×8 — huit ÊTRES) ════════════════════════════════════════
-- 8w. Cou en bas-centre (colonnes 4-5). Chaque tête lit en ombre chinoise ET porte une anatomie interne.
Atlas.head = {

  -- 1) HEAUME À VISIÈRE (order) — casque fermé, fente oculaire, crête, joues rivetées, mentonnière.
  -- Focal : la fente 'E' (regard luisant sous l'acier).
  { name = "helm_visor",
    tags = { "order", "bone", "humanoid" },
    grid = {
      "  OOOO  ",
      " O1111O ",
      "O211112O",
      "O2EEEE2O", -- fente oculaire (le regard)
      "O2a22a2O",
      "O2A22A2O", -- rivets de joue
      " O3333O ",
      "  O33O  ", -- mentonnière -> cou bas-centre
    } },

  -- 2) CRÂNE CORNU (bone) — calotte osseuse, deux cornes qui DÉPASSENT, orbites creuses, crocs.
  -- Focal : l'orbite gauche allumée 'E'.
  { name = "skull_horned",
    tags = { "bone", "abyss", "deformed" },
    grid = {
      "OA    AO", -- pointes de cornes (dépassent le crâne)
      "Oa OO aO", -- fûts des cornes
      " O2OO2O ", -- racine des cornes
      "O211112O",
      "OsEOOssO", -- orbites (s) ; œil gauche luit (E)
      "O21OO12O", -- arête nasale
      "OAaOOaAO", -- crocs
      " O3OO3O ", -- mâchoire -> cou
    } },

  -- 3) CAPUCHE / COWL (arcane) — capuchon rabattu, visage dans l'ombre, deux braises pour yeux.
  -- Focal : les deux yeux 'E' au fond de la pénombre.
  { name = "cowl_hood",
    tags = { "arcane", "abyss", "robe" },
    grid = {
      "  O11O  ", -- pointe du capuchon
      " O1221O ",
      "O122221O",
      "O23ss32O", -- ombre sous le rebord
      "O2sEEs2O", -- yeux dans le noir (focal double)
      "O33ss33O", -- creux du visage
      " O3333O ", -- ouverture du col
      "  O33O  ",
    } },

  -- 4) GUEULE BÉANTE À CROCS (abyss/deformed) — pas d'yeux, une bouche dévorante de crocs imbriqués.
  -- Focal : le gosier sombre 's' bordé de crocs 'A'.
  { name = "maw_gaping",
    tags = { "abyss", "bone", "deformed" },
    grid = {
      " OO  OO ", -- arcades (front bas, bestial)
      "O22OO22O",
      "OAaOOaAO", -- crocs supérieurs
      "OssssssO", -- gosier
      "OssssssO",
      "OAaaaaAO", -- crocs inférieurs
      " O3333O ",
      "  O33O  ",
    } },

  -- 5) BRUTE À ARCADE LOURDE (flesh) — front bas, sourcil massif, yeux enfoncés, mâchoire lourde.
  -- Focal : l'œil droit 'E' sous l'arcade 's'.
  { name = "brute_brow",
    tags = { "flesh", "abyss", "humanoid" },
    grid = {
      " O1111O ",
      "O111111O", -- crâne bombé
      "O1ssss1O", -- arcade sourcilière (ombre)
      "O2sEsE2O", -- yeux enfoncés (droit allumé)
      "O222222O", -- pommettes
      "O2a22a2O", -- plis des joues
      " O3333O ", -- mâchoire massive
      "  O22O  ", -- cou épais
    } },

  -- 6) TÊTE BULBEUSE À YEUX MULTIPLES (arcane) — crâne renflé, trois yeux en triangle, peau veinée.
  -- Focal : l'œil central 'E' (les deux supérieurs en accent 'a').
  { name = "bulb_manyeye",
    tags = { "arcane", "abyss", "deformed" },
    grid = {
      " O1111O ",
      "O111111O",
      "O1a11a1O", -- deux yeux supérieurs
      "O112211O",
      "O12EE21O", -- œil central (focal)
      "O211112O",
      " O3333O ", -- menton fuyant
      "  O33O  ",
    } },

  -- 7) MUSEAU BESTIAL (flesh/abyss) — museau allongé, narine, crocs latéraux, oreilles dressées.
  -- Focal : l'œil 'E'. Museau qui avance vers le bas-droite.
  { name = "snout_beast",
    tags = { "flesh", "abyss", "deformed" },
    grid = {
      "O1O  O1O", -- oreilles dressées
      "O11OO11O",
      "O211112O",
      "O2sEs22O", -- œil enfoncé + front
      "Oa2222AO", -- pommette / début du museau
      " O2233sO", -- museau qui avance (narine s)
      " O3AaaaO", -- crocs latéraux sortants
      "  OO33O ", -- mâchoire -> cou
    } },

  -- 8) MASQUE MORTUAIRE À ORBITES CREUSES (bone/order) — face funéraire, orbites vides, bouche cousue.
  -- Focal : la lueur 'E' au fond de l'orbite gauche (l'autre éteinte 's').
  { name = "deathmask",
    tags = { "bone", "order", "humanoid" },
    grid = {
      " OOOOOO ",
      "O111111O", -- front lisse de masque
      "O1ssss1O", -- arête des orbites
      "OsEssssO", -- orbites profondes (gauche luit, droite éteinte)
      "O2ssss2O",
      "O2AaaA2O", -- bouche cousue (sutures)
      " O3333O ",
      "  O22O  ",
    } },

  -- ╔══════════════════════════════════════════════════════════════════════════════════════╗
  -- ║  SIGNATURE — pièce DISTINCTIVE qui altère la silhouette (« moment gants de boxe »).    ║
  -- ║  Pinnée à UNE espèce via Forge.PIN (déterministe). À voir en jeu : galerie [g].        ║
  -- ╚══════════════════════════════════════════════════════════════════════════════════════╝

  -- 9) HEAUME À HAUTE CRÊTE & ANTENNES (signature de `gravewarden`) — le « chevalier-insecte » : un
  -- grand cimier funéraire FENDU se dresse au-dessus du casque, flanqué de deux ANTENNES recourbées qui
  -- DÉPASSENT largement (la silhouette devient instantanément « gardien casqué cornu », jamais un soldat
  -- lambda). Visière baissée, fente oculaire qui luit. Accent (A/a/E) = thorns -> fallback bone = C :
  -- crête et lueur d'un BLEU SPECTRAL (le sentinelle des tombes). Focal : la fente 'E' sous l'acier.
  { name = "helm_crest_warden",
    tags = { "bone", "order", "humanoid" },
    grid = {
      "A  OO  A", -- bouts d'antennes (DÉPASSENT haut et large — recourbés vers le ciel)
      "a O11O a", -- racine du cimier + tiges d'antennes
      "OaO11OaO", -- fourreaux d'antennes contre le casque + base de la crête fendue
      " O1AA1O ", -- CIMIER : arête lumineuse (A) en éventail au sommet du heaume
      "O211112O", -- calotte du casque
      "O2EEEE2O", -- fente oculaire (le regard luit sous la visière)
      "O2A22A2O", -- joues rivetées (A)
      " OO33OO ", -- mentonnière -> cou bas-centre
    } },
}

-- ════════════════════════════════════════ TORSOS (×5) ════════════════════════════════════════
-- 8w. Base bas-centre. Épaules en haut (les bras s'ancrent aux coins hauts via le rig).
Atlas.torso = {

  -- 1) CUIRASSE À PLASTRON (order) — plates segmentées, sternum, rivets, ceinturon.
  { name = "cuirass_plate",
    tags = { "order", "bone", "humanoid" },
    grid = {
      " OOOOOO ",
      "O111111O", -- col de plastron
      "O1A11A1O", -- clavières rivetées
      "O212212O",
      "O21AA12O", -- sternum (accent central)
      "O222222O",
      "O3a33a3O", -- ceinturon
      " OOOOOO ",
    } },

  -- 2) CAGE THORACIQUE (bone) — côtes apparentes, vide entre les os, bassin.
  { name = "ribcage",
    tags = { "bone", "abyss", "humanoid" },
    grid = {
      " OOOOOO ",
      "O1OOOO1O", -- clavicules
      "OsOAAOsO", -- 1res côtes + sternum lumineux (focal : l'os-clé capte la lumière)
      "O1sOOs1O",
      "Os1OO1sO", -- alternance os/vide
      "O1sOOs1O",
      "O2s33s2O", -- bas de cage / bassin
      " OO33OO ",
    } },

  -- 3) DRAPÉ DE ROBE (arcane) — étoffe lourde, plis verticaux, col, broche centrale.
  { name = "robe_drape",
    tags = { "arcane", "order", "robe" },
    grid = {
      " OOOOOO ",
      "O1O11O1O", -- col ouvert
      "O121121O",
      "O1A2A21O", -- broche (accent)
      "O123321O", -- plis qui tombent
      "O213312O",
      "O323323O", -- ourlet
      " OOOOOO ",
    } },

  -- 4) TORSE DE CHAIR NU (flesh) — pectoraux, abdomen, nombril, flancs.
  { name = "torso_bare",
    tags = { "flesh", "abyss", "humanoid" },
    grid = {
      " OOOOOO ",
      "O111111O", -- épaules/cou
      "O12s2s1O", -- pectoraux (sillon central s)
      "O221A22O", -- cicatrice marquée (focal : entaille luisante sur le flanc)
      "O2s22s2O", -- côtes / flancs
      "O22ss22O", -- abdomen (nombril)
      "O3a33a3O", -- bas-ventre
      " OOOOOO ",
    } },

  -- 5) CHITINE À PLAQUES (abyss) — carapace segmentée, plaques chevauchantes, crête, suintement.
  { name = "chitin_plate",
    tags = { "abyss", "bone", "deformed" },
    grid = {
      " OOOOOO ",
      "O1AAaA1O", -- crête dorsale dentelée (accent asym)
      "O211112O",
      "Oa2222aO", -- bord de plaque (chevauchement)
      "O221122O",
      "Oa3333aO", -- 2e segment
      "O3s33s3O", -- suintement
      " OOOOOO ",
    } },
}

-- ════════════════════════════════════════ ARMS (×4 — pool unique, armBack + armFront) ════════════════════════════════════════
-- Épaule en HAUT (le rig ancre le pivot top). Main/extrémité en bas. Largeur 3 (sauf griffe évasée).
Atlas.arm = {

  -- 1) BRAS BLINDÉ (order) — brassard segmenté, gantelet, rivets.
  { name = "arm_armored",
    tags = { "order", "bone", "humanoid", "robe" },
    grid = {
      "O1O", -- épaulière
      "O2O",
      "OAO", -- coude (rivet)
      "O2O",
      "O2O",
      "OaO", -- poignet
      "O3O", -- gantelet
    } },

  -- 2) BRAS OSSEUX (bone) — humérus fin, coude noué, main décharnée. Recoloré flesh = bras maigre nu.
  { name = "arm_bone",
    tags = { "bone", "flesh", "abyss", "humanoid", "robe", "deformed" },
    grid = {
      "O1O",
      "Os1", -- creux du biceps
      "O1O",
      "O2O", -- coude
      "1sO",
      "O2O",
      "OAO", -- doigts
    } },

  -- 3) GRIFFE À TROIS DARDS (abyss/deformed) — avant-bras qui s'achève en trois serres évasées (5w en bas).
  { name = "claw_three",
    tags = { "abyss", "flesh", "deformed", "humanoid", "bone" },
    grid = {
      " O1O ",
      " O2O ",
      " O2O ",
      " O3O ",
      "Aa3aA", -- la base des trois dards s'évase
      "AaAaA", -- trois dards distincts (clair/ombre alternés)
      "A A A", -- trois pointes (vide entre elles)
    } },

  -- 4) MANCHE DE ROBE (arcane) — manche large évasée, main pâle qui sort (4w en bas).
  { name = "sleeve_robe",
    tags = { "arcane", "order", "robe", "humanoid" },
    grid = {
      "O2O ",
      "O2O ",
      "O3O ",
      "O3O ",
      "O33O", -- évasement de la manche
      "O33O",
      " OAO", -- main pâle qui dépasse de l'étoffe (focal)
    } },
}

-- ════════════════════════════════════════ LEGS (×4) ════════════════════════════════════════
-- Attache en HAUT (pivot top-centre). Deux jambes séparées par une colonne transparente.
Atlas.legs = {

  -- 1) JAMBIÈRES (order) — cuissots blindés, genouillères, grèves, sabatons (9w).
  { name = "greaves_plate",
    tags = { "order", "bone", "humanoid" },
    grid = {
      "O11O O11O",
      "O22O O22O",
      "OAaO OAaO", -- genouillères (rivets)
      "O22O O22O",
      "O33O O33O",
      "OO3O OO3O", -- sabatons (pieds avancés)
    } },

  -- 2) JAMBES OSSEUSES (bone) — fémurs/tibias fins, genoux noués, pieds décharnés (7w).
  { name = "legs_bone",
    tags = { "bone", "abyss", "humanoid", "deformed" },
    grid = {
      "O1O O1O",
      "Os1 Os1",
      "O2O O2O", -- genou
      "1sO 1sO",
      "O2O O2O",
      "OAO OAO", -- pieds
    } },

  -- 3) BAS DE ROBE ÉVASÉ (arcane/robe) — pas de pieds : l'étoffe touche le sol, ourlet large (8w).
  { name = "robe_hem",
    tags = { "arcane", "order", "robe" },
    grid = {
      " OAAAAO ", -- ceinture/cordon de taille (focal : liseré clair)
      " O2222O ",
      "O122221O", -- l'étoffe s'évase
      "O212212O", -- plis
      "O323323O",
      "OO3333OO", -- ourlet lourd qui balaie le sol
    } },

  -- 4) PATTES DIGITIGRADES (abyss/deformed) — jambes bestiales, jarret inversé, serres (7w).
  { name = "legs_digit",
    tags = { "abyss", "flesh", "deformed", "humanoid" },
    grid = {
      "O2O O2O",
      "O3O O3O", -- cuisse
      "1sO 1sO", -- jarret (vers l'avant)
      "O2O O2O",
      "O3a O3a", -- canon
      "AaO AaO", -- serres (accent qui pointe en avant)
    } },
}

-- ════════════════════════════════════════ WEAPONS (×3) ════════════════════════════════════════
-- MANCHE EN HAUT (le bras tient le haut ; pivot top). Tête/pointe/gemme EN BAS. 5w.
-- NOTE : pas de weapon taguée `deformed` — VOULU. Le mapping verrouillé (factions.lua) fait que
-- `deformed` = abyss SANS arme : la griffe (armFront) EST l'attaque. Le forge ne doit pas piocher
-- d'arme pour un corps difforme (cf. démon main). Ce n'est pas un trou de couverture.
Atlas.weapon = {

  -- 1) ÉPÉE À LAME FINE (order/flesh) — pommeau, garde, lame effilée, gouttière.
  { name = "sword_fine",
    tags = { "order", "flesh", "bone", "humanoid" },
    grid = {
      " OAO ", -- pommeau (accent)
      " O2O ", -- poignée
      "OOOOO", -- garde / quillons
      " O1O ", -- forte de lame (tranchant clair capte la lumière)
      " O1O ",
      " O2O ",
      " O2O ", -- faible de lame
      " OsO ", -- pointe affinée
    } },

  -- 2) MASSE À TÊTE LOURDE (order/bone) — manche court, tête trapue cloutée en bas (poids visuel bas).
  { name = "mace_heavy",
    tags = { "order", "bone", "abyss", "humanoid" },
    grid = {
      " O2O ", -- manche (haut)
      " O2O ",
      " O2O ",
      "OOOOO", -- collet
      "OA2AO", -- tête : flasques cloutés
      "O222O",
      "OA2AO", -- pointes latérales
      " O3O ", -- masse qui pèse vers le bas
    } },

  -- 3) BÂTON À GEMME (arcane) — long fût, gemme sertie EN BAS qui luit (focal 'E'), griffes de serre.
  { name = "staff_gem",
    tags = { "arcane", "order", "robe", "bone" },
    grid = {
      " O2O ", -- haut du fût (tenu en haut)
      " O2O ",
      " O2O ",
      " O3O ",
      "Oa2aO", -- griffes qui enserrent la gemme
      "OAEAO", -- GEMME (focal entre deux accents)
      "Oa2aO",
      " O3O ", -- pointe basse
    } },
}

-- ════════════════════════════════════════ HOSTS (×5 — blobs + eyes, mono-part) ════════════════════════════════════════
-- 10w. Base bas-centre. Corps d'un seul tenant (pas de membres : le forge ne rige rien autour).
Atlas.host = {

  -- 1) OOZE À BULLES (blob) — goutte trapue, surface qui bouillonne (bulles = creux s + reflet A).
  { name = "ooze_bubbling",
    tags = { "abyss", "flesh", "arcane", "blob" },
    grid = {
      "   OOOO   ",
      "  O1111O  ", -- dôme (clair en haut)
      " O11AA11O ", -- reflet luisant
      "O1122221sO", -- une bulle (s) qui crève la surface
      "O21s221saO", -- bulles internes
      "O22112222O",
      " O322223O ", -- la masse retombe (sombre en bas)
      "  OO33OO  ", -- base étalée au sol
    } },

  -- 2) BLOB OCULÉ (blob) — masse molle parsemée d'yeux (un dominant 'E', satellites 'a').
  { name = "ooze_eyed",
    tags = { "abyss", "arcane", "flesh", "blob" },
    grid = {
      "  OOOOOO  ",
      " O111111O ",
      "O11a112a1O", -- deux yeux satellites
      "O1112E111O", -- œil dominant (focal)
      "O211a1112O", -- satellite
      "O22112212O",
      " O321a23O ", -- dernier satellite, masse qui s'affaisse
      "  OO33OO  ",
    } },

  -- 3) OOZE COULANT (blob) — goutte allongée qui dégouline, pseudopode étiré vers le bas.
  { name = "ooze_drip",
    tags = { "flesh", "abyss", "arcane", "blob" },
    grid = {
      "  OOOO    ",
      " O1A1O    ", -- reflet luisant sur le dôme (focal)
      "O11221O   ",
      "O12s221O  ", -- creux interne
      "O1222221O ",
      " O2232aO O", -- la masse retombe ; une goutte se détache à droite
      "  O33O OO ", -- pseudopode central qui s'amincit + goutte qui tombe
      "   OO    O", -- base + la goutte poursuit sa chute
    } },

  -- 4) GAZER — ŒIL UNIQUE (eye) — un seul GRAND globe, iris/pupille au centre, paupières charnues.
  { name = "gazer_great",
    tags = { "abyss", "arcane", "flesh", "eye" },
    grid = {
      "  OOOOOO  ",
      " O111111O ", -- paupière supérieure (chair)
      "O11AAAA11O", -- sclère lumineuse
      "O1AAEEAA1O", -- iris -> PUPILLE (focal absolu)
      "O1AAEEAA1O",
      "O11AAAA11O",
      " O322223O ", -- paupière inférieure
      "  OO33OO  ",
    } },

  -- 5) GAZER À SATELLITES (eye) — gros œil central + 4 yeux pédonculés sur tiges charnues (eldritch total).
  { name = "gazer_swarm",
    tags = { "abyss", "arcane", "eye" },
    grid = {
      "aEa    aEa", -- yeux pédonculés supérieurs (globe a-E-a en bout de tige)
      " O2O  O2O ", -- tiges charnues qui plongent vers le corps
      " O11AA11O ", -- haut du globe central
      "O1AAEEAA1O", -- œil central (focal absolu)
      "O1AAEEAA1O",
      " O11AA11O ",
      " O2O  O2O ", -- tiges inférieures
      "aEa OO aEa", -- satellites inférieurs + base au sol
      "Oa OOOO aO",
    } },

  -- ╔══════════════════════════════════════════════════════════════════════════════════════╗
  -- ║  SIGNATURE — pièce DISTINCTIVE qui altère la silhouette (« moment gants de boxe »).    ║
  -- ║  Pinnée à UNE espèce via Forge.PIN (déterministe). À voir en jeu : galerie [g].        ║
  -- ╚══════════════════════════════════════════════════════════════════════════════════════╝

  -- 6) ŒIL-TEMPÊTE COURONNÉ D'ARCS (signature de `thunderhead`) — un globe unique CEINT d'une couronne
  -- d'ÉCLAIRS en zig-zag qui jaillissent du pourtour et DÉPASSENT de tous côtés (la silhouette n'est plus
  -- un disque lisse mais un orage contenu dans un œil). Iris resserré et fixe. Accent = shock -> A=C (bleu
  -- froid, le fil de l'arc) / a=B (bleu PÂLE, l'étincelle vive en pointe) / E=C (la pupille électrisée).
  -- Focal : la pupille 'E' ; les pointes 'a' crépitent au bout de chaque arc (lecture « il va décharger »).
  { name = "gazer_storm_crown",
    tags = { "abyss", "arcane", "order", "eye" },
    grid = {
      "a  a  a  a", -- pointes d'éclairs (étincelles vives B — DÉPASSENT, la couronne crépite)
      "A aA a Aa ", -- arcs en zig-zag qui montent du globe (fil bleu C)
      " Aa OO aA ", -- les arcs prennent racine sur la calotte
      " O11AA11O ", -- haut du globe
      "AO1AEEA1Oa", -- arcs LATÉRAUX (A) + œil central (E focal) bordé d'éclat
      "aO1AEEA1OA", -- iris resserré, électrisé
      " O11AA11O ", -- bas du globe
      " Aa OO aA ", -- arcs inférieurs qui repartent vers le bas
      "a  OOOO  a", -- pointes basses + base ramassée (bas-centre)
    } },
}

-- ╔══════════════════════════════════════════════════════════════════════════════════════╗
-- ║                     VAGUE 2 — BODY-PLANS MULTI-MEMBRES (append-only)                  ║
-- ║  Le moteur (forge.lua) RÉPÈTE/CHAÎNE les membres et place le tout. Ici on dessine UNE  ║
-- ║  part par catégorie ; les pivots suivent l'ANCRAGE standard (base = bas-centre, top =  ║
-- ║  haut). Mêmes rôles neutres, mêmes strings littéraux, zéro couleur de famille en dur.  ║
-- ╚══════════════════════════════════════════════════════════════════════════════════════╝

-- ════════════════════════════════════════ QUAD_BODY (×3 — corps de bête horizontal) ════════════════════════════════════════
-- 12-14w × 4-6h. Base BAS-CENTRE (le ventre repose ; les pattes s'ancrent sous les coins). Épines
-- dorsales autorisées à DÉPASSER en haut. Tête à l'avant-droit (le quad_head pend du coin droit).
Atlas.quad_body = {

  -- 1) DOS REPTILIEN (abyss/flesh) — échine épineuse, flancs écailleux, croupe lourde, amorce de queue.
  -- Focal : la crête d'épines 'A' qui dépasse (le saurien se hérisse).
  { name = "quad_back_reptile",
    tags = { "abyss", "flesh", "bone", "quad" },
    grid = {
      "   A  A  A    ", -- pointes d'épines dorsales (dépassent le dos)
      "  Oa OaO aO   ", -- fûts des épines
      " O1111111111O ", -- ligne de dos (clair en haut)
      "O212222222221O", -- flanc écailleux (sillons s plus bas)
      "O2s2222222s32O", -- côtes saillantes
      "O3a3333333a3aO", -- ventre + amorce de queue (a, à droite)
      " OO3OO  OO3OO ", -- attaches de pattes (avant / arrière) -> bas
    } },

  -- 2) ÉCHINE SQUELETTIQUE (bone) — colonne vertébrale apparente, côtes en arceaux, bassin osseux.
  -- Focal : la vertèbre-clé 'A' au garrot (capte la lumière).
  { name = "quad_spine_bone",
    tags = { "bone", "abyss", "quad" },
    grid = {
      "  O O O O O   ", -- apophyses épineuses (vertèbres pointant en haut)
      " O1O1O1O1O1O  ", -- crête de la colonne
      "O11A1111111O O", -- vertèbre-clé lumineuse (focal) au garrot
      "O1sO1sO1sO1s1O", -- arceaux de côtes (vides s entre les os)
      "O2OsO2OsO2s2sO", -- côtes basses
      " O3sOOsOOs33O ", -- bassin + ischions
      "  OO3O  O3OO  ", -- moignons de pattes -> bas
    } },

  -- 3) ÉCHINE MAMMIFÈRE (flesh) — dos musculeux trapu, garrot bossu, robe pleine, fanon.
  -- Focal : la cicatrice 'A' luisante sur l'épaule (bête burinée).
  { name = "quad_back_brute",
    tags = { "flesh", "abyss", "quad" },
    grid = {
      "   O11O       ", -- bosse du garrot (dépasse un peu)
      " O11111111O   ", -- ligne de dos pleine
      "O1111A111111O ", -- cicatrice d'épaule (focal)
      "O21122222221O ", -- masse des flancs
      "O2s2222222s2sO", -- pli musculaire (s) + croupe
      "O3a33333333a3O", -- ventre lourd (fanon a sous la gorge à droite)
      " OO3OO  OO3OO ", -- attaches de pattes -> bas
    } },
}

-- ════════════════════════════════════════ QUAD_HEAD (×3 — gueule baissée) ════════════════════════════════════════
-- 7-8w × 4-5h. Pivot HAUT (la nuque pend du corps vers l'avant ; le museau plonge en bas-droite).
Atlas.quad_head = {

  -- 1) GUEULE DE SAURIEN (abyss) — museau long, crocs imbriqués, œil fendu, naseau.
  -- Focal : l'œil 'E' haut sur le crâne (regard de prédateur).
  { name = "quad_head_saurian",
    tags = { "abyss", "flesh", "bone", "quad" },
    grid = {
      "OO1O    ", -- nuque (attache au corps, en haut)
      "O11sE1O ", -- crâne + œil fendu (focal)
      "O2222s1O", -- joue + naseau (s)
      "O3AaAaAO", -- rangée de crocs supérieurs
      " O3aAaaO", -- mâchoire + crocs inférieurs (museau plonge à droite)
    } },

  -- 2) MUFLE DE FAUVE (flesh) — museau court large, babines, crocs, truffe.
  -- Focal : l'œil 'E' enfoncé sous l'arcade 's'.
  { name = "quad_head_maw",
    tags = { "flesh", "abyss", "quad" },
    grid = {
      " OO1O   ", -- nuque (haut)
      "O1sE11O ", -- arcade (s) + œil enfoncé (focal)
      "O221122O", -- chanfrein
      "OAaAAaAO", -- babines retroussées sur les crocs
      " O3ss3O ", -- truffe / mâchoire baissée
    } },

  -- 3) CRÂNE DÉCHARNÉ (bone) — tête de mort animale, orbite creuse, dents nues, os du chanfrein.
  -- Focal : la lueur 'E' au fond de l'orbite.
  { name = "quad_head_bone",
    tags = { "bone", "abyss", "quad" },
    grid = {
      "OO1O    ", -- atlas/nuque (haut)
      "O1sEsO  ", -- orbite creuse (lueur E au fond)
      "O211s1O ", -- os du chanfrein (sillon s)
      "OsAAAAsO", -- dents nues alignées
      " OsaaasO", -- mandibule décharnée
    } },
}

-- ════════════════════════════════════════ QUAD_LEG (×3 — patte courte, le moteur en place 4) ════════════════════════════════════════
-- 3w × 4-5h. Pivot HAUT (l'épaule s'ancre sous le corps). Pied/serre en bas.
Atlas.quad_leg = {

  -- 1) PATTE GRIFFUE (abyss/flesh) — membre trapu, jarret, serres en avant.
  { name = "quad_leg_claw",
    tags = { "abyss", "flesh", "bone", "quad" },
    grid = {
      "O2O", -- épaule (haut)
      "O2O",
      "O3O", -- jarret
      "Oa3", -- canon
      "AaA", -- serres (accent qui mord le sol)
    } },

  -- 2) PATTE OSSEUSE (bone) — os fin, articulation nouée, pied décharné.
  { name = "quad_leg_bone",
    tags = { "bone", "abyss", "quad" },
    grid = {
      "O1O", -- épaule (haut)
      "Os1", -- creux de l'os
      "O2O", -- articulation
      "1sO",
      "OAO", -- ergot
    } },

  -- 3) SABOT LOURD (flesh) — patte massive de bête de somme, fanon, sabot fendu.
  { name = "quad_leg_hoof",
    tags = { "flesh", "abyss", "quad" },
    grid = {
      "O1O", -- épaule (haut)
      "O2O",
      "O2O", -- canon plein
      "O3a", -- paturon (fanon a)
      "OAO", -- sabot
    } },
}

-- ════════════════════════════════════════ MANTLE (×3 — bulbe céphalopode, YEUX MULTIPLES) ════════════════════════════════════════
-- 9-11w × 6-8h. Base BAS-CENTRE (les tentacules pendent sous le bulbe). Signature : grappe d'yeux.
Atlas.mantle = {

  -- 1) MANTEAU OCULÉ (abyss/arcane) — dôme charnu, trois yeux en triangle, manteau veiné.
  -- Focal : l'œil central 'E' (les deux hauts en satellites 'a').
  { name = "mantle_triclops",
    tags = { "abyss", "arcane", "flesh", "ceph" },
    grid = {
      "   OOOO   ",
      "  O1111O  ", -- sommet du dôme (clair)
      " O1a11a1O ", -- deux yeux supérieurs (satellites)
      "O11122111O", -- veines internes
      "O11sEEs11O", -- œil central béant (focal)
      "O21122112O",
      " O22ss22O ", -- base du manteau (s = renfoncement d'où sortent les bras)
      "  OO22OO  ",
    } },

  -- 2) MANTEAU À GRAPPE D'YEUX (abyss) — bulbe asymétrique, amas d'yeux d'un côté (eldritch).
  -- Focal : l'œil dominant 'E' ; les autres 'a' épars (regard composé).
  { name = "mantle_eyecluster",
    tags = { "abyss", "arcane", "ceph" },
    grid = {
      "  OOOOO   ",
      " O1111aO  ", -- un œil déjà sur le bord (asym)
      "O11aE11O  ", -- grappe : satellite + œil dominant (focal)
      "O1a112a1O ", -- amas d'yeux dispersés
      "O211a1112O",
      "O22112a12O", -- dernier satellite bas
      " O3sss23O ", -- ourlet du manteau (s)
      "  OO33OO  ",
    } },

  -- 3) CLOCHE DE MÉDUSE (arcane) — ombrelle translucide, nervures rayonnantes, ocelles au bord.
  -- Focal : l'ocelle 'E' au centre de l'ombrelle (les nervures 'A' rayonnent).
  { name = "mantle_medusa",
    tags = { "arcane", "abyss", "ceph" },
    grid = {
      "   OOOO   ",
      "  O1AA1O  ", -- nervure de crête (focal clair)
      " O1A11A1O ", -- nervures rayonnantes
      "O11A11A11O",
      "O1A1EE1A1O", -- ocelle central (focal)
      "O21A11A12O",
      " Oa2aa2aO ", -- bord frangé (ocelles secondaires a)
      "  OaOOaO  ", -- amorces de tentacules
    } },
}

-- ════════════════════════════════════════ TENTACLE (×3 — le moteur en place 4-6, ondulantes) ════════════════════════════════════════
-- 3w × 5-7h. Pivot HAUT (la racine s'ancre sous le manteau). S'affine et ventouse vers le bas.
Atlas.tentacle = {

  -- 1) BRAS À VENTOUSES (abyss) — tentacule charnu, ventouses alternées (accents), pointe effilée.
  { name = "tentacle_sucker",
    tags = { "abyss", "arcane", "flesh", "ceph" },
    grid = {
      "O2O", -- racine (haut)
      "Oa2", -- ventouse (accent ombré, asym)
      "O2O",
      "O2a", -- ventouse
      "Os2", -- creux
      "O3O",
      " O ", -- pointe qui s'amincit
    } },

  -- 2) FOUET FIN (arcane) — tentacule mince qui serpente, sans ventouse, pointe acérée.
  { name = "tentacle_whip",
    tags = { "arcane", "abyss", "ceph" },
    grid = {
      "O2O", -- racine (haut)
      "O2O",
      " 2O", -- ondulation (décalage à droite)
      "O2O",
      "O2 ", -- ondulation (décalage à gauche)
      "O3O",
      "OAO", -- pointe luisante
    } },

  -- 3) BRAS MASSUE (abyss) — tentacule épais qui s'élargit en massue cloutée au bout.
  { name = "tentacle_club",
    tags = { "abyss", "flesh", "ceph" },
    grid = {
      "O2O ", -- racine (haut)
      "O2O ",
      "O2O ",
      "Os2 ", -- jointure
      "OA2 ", -- la massue s'élargit (clou accent)
      "O22O", -- bulbe terminal (4w en bas — voulu)
      "Oa3O", -- dessous de la massue
    } },
}

-- ════════════════════════════════════════ SERPENT_HEAD (×3 — capuchon dressé) ════════════════════════════════════════
-- 6-8w × 5-6h. Base BAS-CENTRE (le cou plonge vers le corps de segments). Cobra qui se cabre.
Atlas.serpent_head = {

  -- 1) COBRA À CAPUCHON (abyss) — coiffe évasée, yeux fixes, crocs, langue darde.
  -- Focal : les deux yeux 'E' (regard hypnotique).
  { name = "serpent_cobra",
    tags = { "abyss", "flesh", "arcane", "serpent" },
    grid = {
      " O1111O ", -- sommet du capuchon
      "O1a11a1O", -- ocelles du capuchon (motif a, asym léger)
      "O11EE11O", -- yeux fixes (focal double)
      "O211112O", -- museau
      " OAaaAO ", -- crocs
      "  Oa3O  ", -- gorge -> cou qui plonge (bas-centre)
    } },

  -- 2) VIPÈRE CORNUE (bone/abyss) — tête triangulaire osseuse, cornes sourcilières, crocs longs.
  -- Focal : l'œil fendu 'E' sous la corne.
  { name = "serpent_viper",
    tags = { "bone", "abyss", "serpent" },
    grid = {
      "OA    AO", -- cornes sourcilières (dépassent)
      "Oa1OO1aO", -- arcades
      "O1sEEs1O", -- yeux fendus (focal) en creux
      "O211112O", -- chanfrein
      " O3AA3O ", -- crochets à venin
      "  Oa3O  ", -- cou (bas-centre)
    } },

  -- 3) GUEULE BÉANTE (abyss) — tête de serpent mâchoire grande ouverte, gosier, crocs déployés.
  -- Focal : le gosier 's' cerné de crocs 'A' (l'avale-tout).
  { name = "serpent_gape",
    tags = { "abyss", "flesh", "serpent" },
    grid = {
      " O1aa1O ", -- haut du crâne (œil-points a)
      "O211112O",
      "OAassaAO", -- crocs supérieurs + amorce du gosier
      "OAssssAO", -- gosier béant
      "O3AaaA3O", -- crocs inférieurs
      "  Oa3O  ", -- cou (bas-centre)
    } },
}

-- ════════════════════════════════════════ SEGMENT (×3 — le moteur en chaîne 5-7, large→mince) ════════════════════════════════════════
-- 3-5w × 2-3h. Pivot HAUT (chaîné : chaque segment pend du précédent). Fournis plusieurs largeurs
-- (5w large, 3w mince) pour que le moteur effile le corps. Plaques/anneaux selon la famille.
Atlas.segment = {

  -- 1) ANNEAU LARGE (abyss/flesh) — segment épais avec bourrelet et pore latéral. 5w.
  { name = "segment_wide",
    tags = { "abyss", "flesh", "bone", "serpent", "worm" },
    grid = {
      "O111O", -- haut de l'anneau (attache, clair)
      "O2a2O", -- bourrelet + pore latéral (a)
      "O333O", -- dessous (sombre)
    } },

  -- 2) MAILLON MINCE (abyss/flesh) — segment étroit de queue, anneau simple. 3w.
  { name = "segment_thin",
    tags = { "abyss", "flesh", "bone", "serpent", "worm" },
    grid = {
      "O1O", -- haut (attache)
      "O2O", -- anneau
      "O3O", -- dessous
    } },

  -- 3) PLAQUE DORSALE (bone/abyss) — segment chitineux à arête centrale et bord chevauchant. 5w.
  { name = "segment_plate",
    tags = { "bone", "abyss", "worm", "serpent" },
    grid = {
      "Oa1aO", -- bord chevauchant (a) + arête centrale (1)
      "O2A2O", -- arête dorsale luisante (accent)
      "Oa3aO", -- dessous chevauchant
    } },
}

-- ════════════════════════════════════════ ARACHNID_BODY (×2 — céphalothorax, GRAPPE D'YEUX) ════════════════════════════════════════
-- 7-9w × 5-6h. Base BAS-CENTRE (l'abdomen repose ; les pattes s'ancrent sur les flancs hauts).
Atlas.arachnid_body = {

  -- 1) ARAIGNÉE OCULÉE (abyss) — céphalothorax bombé, RANGÉE de huit yeux, abdomen marqué.
  -- Focal : la paire d'yeux médians 'E' (les six autres en accents a).
  { name = "arachnid_eyed",
    tags = { "abyss", "flesh", "bone", "arachnid" },
    grid = {
      "  OOOOO  ",
      " OaEEaO  ", -- yeux médians (focal) + latéraux (a) — la grappe d'yeux
      " Oa222aO ", -- yeux postérieurs (a) sur le céphalothorax
      "O22ss22O ", -- sillon thoracique (s)
      "O3211123O", -- jonction abdomen
      " O332233O", -- abdomen bombé (asym)
      "  OO33O  ", -- filières -> bas-centre
    } },

  -- 2) ABDOMEN BLINDÉ (bone/abyss) — corps chitineux à plaque, chélicères, deux gros yeux.
  -- Focal : les deux yeux frontaux 'E' au-dessus des chélicères.
  { name = "arachnid_armored",
    tags = { "bone", "abyss", "arachnid" },
    grid = {
      " OO1OO   ",
      "O1EE11O  ", -- deux gros yeux frontaux (focal)
      "OAaAaAaO ", -- chélicères (crochets)
      "O211112O ", -- céphalothorax plaqué
      "Oa2222aO ", -- bord de plaque chevauchant
      "O3s33s3O ", -- abdomen (sillons s)
      " OO33OO  ", -- filières -> bas-centre
    } },

  -- ╔══════════════════════════════════════════════════════════════════════════════════════╗
  -- ║  SIGNATURE — pièce DISTINCTIVE qui altère la silhouette (« moment gants de boxe »).    ║
  -- ║  Pinnée à UNE espèce via Forge.PIN (déterministe). À voir en jeu : galerie [g].        ║
  -- ╚══════════════════════════════════════════════════════════════════════════════════════╝

  -- 3) PORTE-VENIN À ÉPINES (signature de `leech_thorn`) — l'écho DIRECT du screenshot Batomon : un
  -- SAC dorsal bombé et translucide, hérissé de DARDS qui DÉPASSENT haut, sourdant de venin. La grappe
  -- d'yeux glisse sous la masse (céphalothorax bas), pour que la silhouette se lise « araignée + sac
  -- gonflé sur le dos » d'un coup d'œil. Accent (A/a/E) = bleed -> R/r sur `leech_thorn` : dards SANGLANTS.
  -- Focal : l'œil médian 'E' sous le sac ; les pointes 'A' attirent l'œil vers le haut (le poison perle).
  { name = "arachnid_thornsac",
    tags = { "bone", "abyss", "flesh", "arachnid" },
    grid = {
      "  A  A A  ", -- pointes de dards (DÉPASSENT le sac — la menace pointe en l'air)
      " Oa OaO aO", -- fûts des dards plantés dans la membrane
      " O2A222A1O", -- DÔME du sac : membrane tendue + reflets de poison (A) qui perlent
      "O1222s221O", -- ventre du sac, gonflé (sillon s = veine sombre)
      "O2a2ss2a2O", -- attache du sac sur le thorax (creux s) + suintement (a)
      "O1OaEEaO1O", -- la grappe d'yeux émerge SOUS le sac (E médian = focal, a latéraux)
      " O22222O ", -- céphalothorax
      "  OO3OO  ", -- abdomen ramassé -> filières bas-centre
    } },
}

-- ════════════════════════════════════════ SPIDER_LEG (×3 — anguleuse, le moteur en place 6-8 en éventail) ════════════════════════════════════════
-- 3w × 4-6h. Pivot HAUT (la hanche s'ancre au flanc du céphalothorax). Articulation coudée, pointe au sol.
Atlas.spider_leg = {

  -- 1) PATTE COUDÉE (abyss) — fémur puis tibia, coude marqué, pointe acérée.
  { name = "spider_leg_angled",
    tags = { "abyss", "flesh", "bone", "arachnid" },
    grid = {
      "O2O", -- hanche (haut)
      "O3O", -- fémur
      "Oa ", -- coude (l'articulation pointe en dehors)
      "1sO", -- tibia (repart en biais)
      "O2O",
      "OAO", -- pointe au sol (accent)
    } },

  -- 2) PATTE VELUE (flesh/abyss) — segment épais soyeux, soies latérales (accents), griffe.
  { name = "spider_leg_bristled",
    tags = { "flesh", "abyss", "arachnid" },
    grid = {
      "O2O", -- hanche (haut)
      "a2a", -- soies (accents latéraux)
      "O2O",
      "a3a", -- soies basses
      "O3O",
      "OAO", -- griffe
    } },

  -- 3) PATTE OSSEUSE (bone) — membre décharné anguleux, jointures nouées, ergot.
  { name = "spider_leg_bone",
    tags = { "bone", "abyss", "arachnid" },
    grid = {
      "O1O", -- hanche (haut)
      "Os1", -- creux
      "O2 ", -- jointure coudée
      " sO",
      "O2O",
      "OAO", -- ergot
    } },
}

-- ════════════════════════════════════════ SWARM_CORE (×3 — masse grouillante, yeux dispersés) ════════════════════════════════════════
-- 9-11w × 6-8h. Base BAS-CENTRE. Pas de membres rigides : une cohue de corps. Plusieurs 'E' ÉPARS
-- (petits yeux qui clignotent partout dans la masse). Doit lire comme un essaim, pas comme un blob lisse.
Atlas.swarm_core = {

  -- 1) GROUILLEMENT (abyss/flesh) — amas bouillonnant de petits corps, bulbes (s) et yeux dispersés.
  -- Focal diffus : plusieurs 'E' épars (l'essaim te fixe de partout).
  { name = "swarm_writhing",
    tags = { "abyss", "flesh", "arcane", "swarm" },
    grid = {
      "  OO OOOO ",
      " O1sE112O ", -- un œil + un corps qui crève la surface (s)
      "O1E1s11E1O", -- yeux épars dans la masse
      "O1s121s21O", -- bulbes grouillants (s)
      "O2E11s11sO", -- œil + creux
      "O1s2E1121O", -- œil bas
      " O2s1s2sEO", -- la cohue retombe (œil au bord)
      "  OO3O3OO ", -- base étalée (bas-centre)
    } },

  -- 2) NUÉE D'INSECTES (abyss) — essaim dense d'ailes/pattes (accents anguleux a) + yeux composés.
  -- Focal : 'E' épars parmi les éclats d'élytres 'a'.
  { name = "swarm_insects",
    tags = { "abyss", "arcane", "swarm" },
    grid = {
      " Oa OaaO  ",
      "OaEa1aEaO ", -- élytres anguleux (a) + yeux composés
      "O1aEa1a11O", -- éclats d'ailes dispersés
      "Oa11aEa1aO", -- œil au cœur de la nuée
      "O1aE1a1a1O", -- œil + pattes
      "Oa1a1aEa O", -- œil bas
      " O2a1a2aO ", -- la nuée s'épaissit en bas
      "  OO33OO  ", -- amorce au sol (bas-centre)
    } },

  -- 3) MASSE DE VERMINE (flesh/abyss) — grouillement charnu de vers/larves entrelacés, yeux laiteux.
  -- Focal : 'E' laiteux épars entre les corps mous (1/2 dominants, peu d'accents).
  { name = "swarm_vermin",
    tags = { "flesh", "abyss", "swarm" },
    grid = {
      "  OOOOOO  ",
      " O11E211O ", -- vers entrelacés + un œil
      "O1211E121O", -- larve qui crève la surface + œil
      "O11E21121O", -- masse molle + œil
      "O2112E122O", -- entrelacs + œil
      "O1221E121O", -- œil bas
      " O2211222O", -- la masse charnue retombe (asym)
      "  OO3223O ", -- base molle étalée (bas-centre)
    } },
}

return Atlas
