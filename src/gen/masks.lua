-- src/gen/masks.lua
-- DATA PURE (zéro love.*) : MASK MATRICES par squelette × part. Le mask BORNE la silhouette
-- (garantit la lisibilité) ; le générateur le remplit de façon seedée puis le miroir (symétrie),
-- détecte les bords (outline auto) et colorise (ramps.lua). Adapté de Dave Bollinger.
--
-- VARIÉTÉ INTRA-FACTION : chaque part offre PLUSIEURS variantes de silhouette (head/torso surtout).
-- creaturegen en choisit une par RNG seedé -> deux unités de même faction ont des formes distinctes.
-- Toutes les variantes restent lisibles et fidèles à la faction (la difformité reste MODÉRÉE pour
-- humanoid/robe ; abyss peut être plus irrégulier mais jamais gruyère).
--
-- On stocke la MOITIÉ GAUCHE de chaque part (colonnes de gauche vers l'axe de symétrie, à droite).
-- Le générateur produit la moitié droite par MIROIR -> silhouette symétrique. L'asymétrie eldritch
-- (arcane/abyss) est ajoutée APRÈS le miroir (excroissances d'un seul côté).
--
-- Rôles de cellule :
--   0 = toujours VIDE (transparent)
--   1 = body si rng < density (cellule "molle" : varie d'une créature à l'autre, BORD seulement)
--   3 = toujours BODY (cellule "dure" : garantit la silhouette, jamais trouée)
--   E = emplacement d'œil/détail (toujours body, marqué pour injection)
--
-- RÈGLE DE LISIBILITÉ : les cellules molles (1) ne vivent qu'au BORD extérieur (colonne de gauche,
-- coins, bas, sommet). À l'INTÉRIEUR tout est dur (3) : un "1" interne qui roule vide crée un trou
-- que l'edge-detection enveloppe de contour -> silhouette gruyère illisible.
--
-- Convention : la colonne la plus à DROITE de chaque demi-mask touche l'axe de symétrie.
-- `variants` = liste de demi-masks ; le générateur en pioche un (ipairs/index seedé).

local M = {}

-- ═══════════════════════════ HUMANOID (flesh/order/bone) ═══════════════════════════
M.humanoid = {
  head = { variants = {
    -- A : ronde standard
    {
      { 1, 3, 3, 3 },
      { 3, 3, 3, 3 },
      { 3, 3, "E", 3 },
      { 3, 3, 3, 3 },
      { 1, 3, 3, 3 },
    },
    -- B : anguleuse / mâchoire carrée (plus large en bas)
    {
      { 0, 3, 3, 3 },
      { 3, 3, 3, 3 },
      { 3, 3, "E", 3 },
      { 3, 3, 3, 3 },
      { 3, 3, 3, 3 },
    },
    -- C : haute / casquée (sommet allongé)
    {
      { 0, 1, 3, 3 },
      { 0, 3, 3, 3 },
      { 3, 3, 3, 3 },
      { 3, 3, "E", 3 },
      { 1, 3, 3, 3 },
    },
    -- D : trapue / massive (basse et large, front lourd) — 5 rangées pour une structure lisible.
    {
      { 3, 3, 3, 3 },
      { 3, 3, 3, 3 },
      { 3, 3, "E", 3 },
      { 3, 3, 3, 3 },
      { 1, 3, 3, 3 },
    },
  } },
  torso = { variants = {
    -- A : standard
    {
      { 1, 3, 3, 3 },
      { 3, 3, 3, 3 },
      { 3, 3, 3, 3 },
      { 3, 3, 3, 3 },
      { 1, 3, 3, 3 },
      { 1, 3, 3, 3 },
    },
    -- B : large d'épaules / cuirasse (épaules pleines, taille resserrée)
    {
      { 3, 3, 3, 3 },
      { 3, 3, 3, 3 },
      { 1, 3, 3, 3 },
      { 0, 3, 3, 3 },
      { 0, 3, 3, 3 },
      { 1, 3, 3, 3 },
    },
    -- C : étroit / décharné (mince partout)
    {
      { 0, 1, 3, 3 },
      { 0, 3, 3, 3 },
      { 0, 3, 3, 3 },
      { 0, 3, 3, 3 },
      { 0, 3, 3, 3 },
      { 0, 1, 3, 3 },
    },
    -- D : voûté / bossu (sommet asym léger, base large)
    {
      { 0, 3, 3, 3 },
      { 1, 3, 3, 3 },
      { 3, 3, 3, 3 },
      { 3, 3, 3, 3 },
      { 3, 3, 3, 3 },
      { 1, 3, 3, 3 },
    },
  } },
  armBack = { variants = { { { 3 }, { 3 }, { 3 }, { 3 }, { 3 } } } },
  armFront = { variants = { { { 3 }, { 3 }, { 3 }, { 3 }, { 3 } } } },
  legs = { variants = {
    -- A : jambes droites
    {
      { 3, 3, 0 },
      { 3, 3, 0 },
      { 3, 3, 0 },
      { 1, 3, 0 },
    },
    -- B : longues
    {
      { 3, 3, 0 },
      { 3, 3, 0 },
      { 3, 3, 0 },
      { 3, 3, 0 },
      { 1, 3, 0 },
    },
    -- C : trapues
    {
      { 3, 3, 0 },
      { 3, 3, 0 },
      { 1, 3, 0 },
    },
  } },
}

-- ═══════════════════════════ ROBE (arcane) : pas de legs, torse au sol ═══════════════════════════
M.robe = {
  head = { variants = {
    -- A : capuche pointue
    {
      { 0, 0, 1, 3 },
      { 0, 3, 3, 3 },
      { 3, 3, 3, 3 },
      { 3, 3, "E", 3 },
      { 3, 3, 3, 3 },
      { 0, 1, 3, 3 },
    },
    -- B : capuche large / arrondie
    {
      { 0, 1, 3, 3 },
      { 3, 3, 3, 3 },
      { 3, 3, 3, 3 },
      { 3, 3, "E", 3 },
      { 0, 3, 3, 3 },
      { 0, 0, 3, 3 },
    },
    -- C : tête nue / chauve (sans capuche pointue, crâne haut)
    {
      { 0, 0, 3, 3 },
      { 0, 3, 3, 3 },
      { 3, 3, 3, 3 },
      { 3, 3, "E", 3 },
      { 3, 3, 3, 3 },
      { 0, 3, 3, 3 },
    },
    -- D : capuche très longue (cornes de tissu)
    {
      { 0, 0, 0, 3 },
      { 0, 0, 3, 3 },
      { 0, 3, 3, 3 },
      { 3, 3, "E", 3 },
      { 3, 3, 3, 3 },
      { 0, 1, 3, 3 },
    },
  } },
  torso = { variants = {
    -- A : robe évasée
    {
      { 0, 0, 3, 3 },
      { 0, 3, 3, 3 },
      { 3, 3, 3, 3 },
      { 3, 3, 3, 3 },
      { 1, 3, 3, 3 },
      { 1, 3, 3, 3 },
      { 1, 3, 3, 3 },
    },
    -- B : robe droite / colonne
    {
      { 0, 3, 3, 3 },
      { 0, 3, 3, 3 },
      { 0, 3, 3, 3 },
      { 0, 3, 3, 3 },
      { 0, 3, 3, 3 },
      { 1, 3, 3, 3 },
    },
    -- C : robe à large traîne (très évasée en bas)
    {
      { 0, 0, 3, 3 },
      { 0, 0, 3, 3 },
      { 0, 3, 3, 3 },
      { 3, 3, 3, 3 },
      { 3, 3, 3, 3 },
      { 1, 3, 3, 3 },
      { 1, 3, 3, 3 },
    },
    -- D : courte / ramassée (acolyte)
    {
      { 0, 0, 3, 3 },
      { 0, 3, 3, 3 },
      { 3, 3, 3, 3 },
      { 1, 3, 3, 3 },
      { 1, 3, 3, 3 },
    },
  } },
  armBack = { variants = { { { 3 }, { 3 }, { 3 }, { 3 }, { 1 } } } },
  armFront = { variants = { { { 3 }, { 3 }, { 3 }, { 3 }, { 1 } } } },
}

-- ═══════════════════════════ DEFORMED (abyss) : pas d'arme, armFront = griffe ═══════════════════════════
-- NOTE BRUIT : on a SUPPRIMÉ les "1" internes qui créaient le damier KKDKDKDK frôlant la silhouette
-- trouée. Les cavités/yeux sont posés explicitement (E) ou par détail, pas par alternance plein/vide.
M.deformed = {
  head = { variants = {
    -- A : bulbe large
    {
      { 0, 1, 3, 3 },
      { 1, 3, 3, 3 },
      { 3, 3, 3, 3 },
      { 3, 3, "E", 3 },
      { 3, 3, 3, "E" },
      { 1, 3, 3, 3 },
    },
    -- B : crâne effilé vers le haut (corne naturelle)
    {
      { 0, 0, 3, 3 },
      { 0, 3, 3, 3 },
      { 3, 3, 3, 3 },
      { 3, 3, "E", 3 },
      { 3, 3, 3, 3 },
      { 1, 3, 3, 3 },
    },
    -- C : tête basse / gueule (large bas, yeux étagés)
    {
      { 3, 3, 3, 3 },
      { 3, 3, "E", 3 },
      { 3, 3, 3, "E" },
      { 3, 3, 3, 3 },
      { 1, 3, 3, 3 },
    },
    -- D : difforme haute (double bosse de crâne)
    {
      { 1, 0, 3, 3 },
      { 0, 3, 3, 3 },
      { 3, 3, 3, 3 },
      { 3, 3, "E", 3 },
      { 3, 3, 3, 3 },
      { 1, 3, 3, 3 },
    },
  } },
  torso = { variants = {
    -- A : tronc massif
    {
      { 1, 3, 3, 3 },
      { 3, 3, 3, 3 },
      { 3, 3, 3, 3 },
      { 3, 3, 3, 3 },
      { 1, 3, 3, 3 },
      { 1, 1, 3, 3 },
    },
    -- B : ventru (large milieu)
    {
      { 0, 3, 3, 3 },
      { 3, 3, 3, 3 },
      { 3, 3, 3, 3 },
      { 3, 3, 3, 3 },
      { 3, 3, 3, 3 },
      { 1, 3, 3, 3 },
    },
    -- C : maigre / côtelé
    {
      { 0, 1, 3, 3 },
      { 0, 3, 3, 3 },
      { 0, 3, 3, 3 },
      { 0, 3, 3, 3 },
      { 1, 3, 3, 3 },
      { 1, 1, 3, 3 },
    },
    -- D : épaulé large / trapu
    {
      { 3, 3, 3, 3 },
      { 3, 3, 3, 3 },
      { 1, 3, 3, 3 },
      { 1, 3, 3, 3 },
      { 1, 3, 3, 3 },
    },
  } },
  armBack = { variants = { { { 3 }, { 3 }, { 3 }, { 3 }, { 3 }, { 1 } } } },
  armFront = { variants = { { { 3 }, { 3 }, { 3 }, { 3 }, { 3 }, { 1 } } } },
  legs = { variants = {
    {
      { 3, 3, 0 },
      { 3, 3, 0 },
      { 1, 3, 0 },
    },
    {
      { 3, 3, 0 },
      { 3, 3, 0 },
      { 3, 3, 0 },
      { 1, 3, 0 },
    },
  } },
}

-- ═══════════════════════════ BLOB / OOZE : masse unique, pas de membres ═══════════════════════════
-- Silhouette = goutte large en bas, dôme bas, 1-2 yeux. Reconnaissable par sa MASSE informe. Cols=5
-- -> fullW=10 (squat &amp; large, contraste fort avec les bipèdes étroits). L'idle PULSE (sy/sx).
M.blob = {
  body = { variants = {
    -- A : goutte trapue
    {
      { 0, 0, 1, 3, 3 },
      { 0, 1, 3, 3, 3 },
      { 1, 3, 3, 3, 3 },
      { 3, 3, "E", 3, 3 },
      { 3, 3, 3, 3, 3 },
      { 1, 3, 3, 3, 3 },
    },
    -- B : lourde / haute (dôme bombé)
    {
      { 0, 1, 3, 3, 3 },
      { 1, 3, 3, 3, 3 },
      { 3, 3, 3, 3, 3 },
      { 3, 3, "E", 3, 3 },
      { 3, 3, 3, 3, 3 },
      { 3, 3, 3, 3, 3 },
      { 1, 3, 3, 3, 3 },
    },
    -- C : flaque basse (très large, écrasée)
    {
      { 0, 0, 1, 3, 3 },
      { 0, 1, 3, 3, 3 },
      { 3, 3, "E", 3, 3 },
      { 3, 3, 3, 3, 3 },
      { 1, 3, 3, 3, 3 },
    },
  } },
}

-- ═══════════════════════════ QUADRUPÈDE : corps HORIZONTAL bas + tête en façade ═══════════════════════════
-- Silhouette = corps large &amp; bas (cols=6 -> fullW=12) sur 4 pattes, tête basse au centre. Posture
-- radicalement non-bipède. Les 4 pattes &amp; la tête sont des parts ajoutées par le builder (pas dans le mask).
M.quadruped = {
  body = { variants = {
    -- A : tronc massif
    {
      { 1, 3, 3, 3, 3, 3 },
      { 3, 3, 3, 3, 3, 3 },
      { 3, 3, 3, 3, 3, 3 },
      { 1, 3, 3, 3, 3, 3 },
    },
    -- B : échine voûtée (bosse au garrot)
    {
      { 0, 1, 3, 3, 3, 3 },
      { 1, 3, 3, 3, 3, 3 },
      { 3, 3, 3, 3, 3, 3 },
      { 1, 3, 3, 3, 3, 3 },
    },
    -- C : longiligne (plus mince, prédateur)
    {
      { 1, 3, 3, 3, 3, 3 },
      { 3, 3, 3, 3, 3, 3 },
      { 1, 3, 3, 3, 3, 3 },
    },
  } },
  head = { variants = {
    -- A : gueule trapue
    {
      { 0, 3, 3, 3 },
      { 3, 3, "E", 3 },
      { 3, 3, 3, 3 },
      { 1, 3, 3, 3 },
    },
    -- B : long museau (mâchoire avancée)
    {
      { 0, 0, 3, 3 },
      { 3, 3, "E", 3 },
      { 3, 3, 3, 3 },
      { 3, 3, 3, 3 },
    },
  } },
}

-- ═══════════════════════════ CÉPHALOPODE : mantle bulbeux + couronne de tentacules ═══════════════════════════
-- Silhouette = manteau bombé/pointu EN HAUT (cols=5 -> fullW=10), yeux dans le tiers bas, tentacules
-- pendantes ajoutées par le builder. La famille phare grimdark (eldritch / Cthulhu). Idle = ondulation.
M.cephalopod = {
  mantle = { variants = {
    -- A : manteau arrondi
    {
      { 0, 0, 1, 3, 3 },
      { 0, 1, 3, 3, 3 },
      { 1, 3, 3, 3, 3 },
      { 3, 3, 3, 3, 3 },
      { 3, 3, "E", 3, 3 },
      { 3, 3, 3, 3, 3 },
    },
    -- B : manteau pointu (calmar)
    {
      { 0, 0, 0, 3, 3 },
      { 0, 0, 1, 3, 3 },
      { 0, 1, 3, 3, 3 },
      { 1, 3, 3, 3, 3 },
      { 3, 3, "E", 3, 3 },
      { 3, 3, 3, 3, 3 },
    },
    -- C : bulbe large (yeux hauts, gros front)
    {
      { 0, 1, 3, 3, 3 },
      { 1, 3, 3, 3, 3 },
      { 3, 3, "E", 3, 3 },
      { 3, 3, 3, 3, 3 },
      { 3, 3, 3, 3, 3 },
    },
  } },
}

-- ═══════════════════════════ SWARM : amas de petits corps (charognards / insectes) ═══════════════════════════
-- Silhouette = MASSE BASSE & LARGE (cols=6 -> fullW=12), TEXTURÉE par PLUSIEURS yeux étagés (E). On ne lit
-- PAS un corps unique mais un grouillement : 3-4 marqueurs E à hauteurs/colonnes variées (chaque E = un
-- petit corps). Trapue (haut bombé doux, base large à plat). Idle = micro-jitter désynchronisé par E + bob.
M.swarm = {
  core = { variants = {
    -- A : tas compact (yeux sur 2 rangées)
    {
      { 0, 0, 1, 3, 3, 3 },
      { 0, 1, 3, 3, "E", 3 },
      { 1, 3, "E", 3, 3, 3 },
      { 3, "E", 3, 3, "E", 3 },
      { 3, 3, 3, 3, 3, 3 },
      { 1, 3, 3, 3, 3, 3 },
    },
    -- B : nuée allongée (plus basse, 4 yeux dispersés)
    {
      { 0, 1, 3, 3, 3, 3 },
      { 1, 3, "E", 3, "E", 3 },
      { 3, "E", 3, 3, 3, 3 },
      { 3, 3, 3, 3, "E", 3 },
      { 1, 3, 3, 3, 3, 3 },
    },
    -- C : grappe haute (corps empilés, yeux étagés sur 3 niveaux)
    {
      { 0, 0, 1, 3, 3, 3 },
      { 0, 1, 3, "E", 3, 3 },
      { 1, 3, "E", 3, 3, 3 },
      { 3, 3, 3, 3, "E", 3 },
      { 3, "E", 3, 3, 3, 3 },
      { 1, 3, 3, 3, 3, 3 },
    },
  } },
}

-- ═══════════════════════════ SERPENT : chaîne verticale de segments décroissants ═══════════════════════════
-- Silhouette = COLONNE VERTICALE qui s'effile, gueule en haut. Le builder chaîne des `segmentN` (parent->enfant)
-- en décalant `at` G/D pour le S et en rétrécissant via dummyHalf décroissant ; la TÊTE (gueule + yeux) est un
-- mask à part. Reconnaissance : verticalité + ondulation. Têtes = mâchoires basses larges.
M.serpent = {
  head = { variants = {
    -- A : gueule trapue (mâchoire large)
    {
      { 0, 3, 3, 3 },
      { 3, 3, "E", 3 },
      { 3, 3, 3, 3 },
      { 1, 3, 3, 3 },
    },
    -- B : crâne effilé (museau qui monte)
    {
      { 0, 0, 3, 3 },
      { 0, 3, 3, 3 },
      { 3, 3, "E", 3 },
      { 3, 3, 3, 3 },
    },
    -- C : tête à fanons (yeux étagés)
    {
      { 0, 1, 3, 3 },
      { 3, 3, "E", 3 },
      { 3, 3, 3, "E" },
      { 1, 3, 3, 3 },
    },
  } },
}

-- ═══════════════════════════ ARACHNID : corps central compact + pattes rayonnantes ═══════════════════════════
-- Silhouette = corps RAMASSÉ (cols=4 -> fullW=8) sur 6-8 PATTES anguleuses en éventail (large empreinte au sol).
-- Les pattes (buildArm `legN`) sont posées par le builder de part et d'autre, positions seedées. Yeux groupés
-- bas sur le corps (regard d'araignée). Corps base-pivot (ornement dorsal). Reconnaissance : empreinte radiale.
M.arachnid = {
  body = { variants = {
    -- A : abdomen rond (yeux bas en grappe)
    {
      { 0, 1, 3, 3 },
      { 1, 3, 3, 3 },
      { 3, "E", 3, 3 },
      { 3, 3, "E", 3 },
      { 1, 3, 3, 3 },
    },
    -- B : corps trapu large (céphalothorax marqué)
    {
      { 1, 3, 3, 3 },
      { 3, 3, "E", 3 },
      { 3, 3, 3, "E" },
      { 1, 3, 3, 3 },
    },
    -- C : abdomen bombé haut (gros arrière-corps)
    {
      { 0, 0, 3, 3 },
      { 0, 3, 3, 3 },
      { 3, 3, "E", 3 },
      { 3, 3, 3, 3 },
      { 3, 3, 3, 3 },
      { 1, 3, 3, 3 },
    },
  } },
}

-- ═══════════════════════════ EYE : œil / orbe flottant ═══════════════════════════
-- Silhouette = DISQUE unique (cols=5 -> fullW=10), RIEN d'autre : la plus distincte du roster. Miroir bilatéral
-- + sommet/base arrondis = rondeur. Marqueur E central = la grosse pupille. Anneau de petits yeux (E
-- supplémentaires) sur les flancs aux variantes plus complexes. Orbe base-pivot ; flotte (anim + at).
M.eye = {
  orb = { variants = {
    -- A : orbe lisse (pupille centrale unique)
    {
      { 0, 0, 1, 3, 3 },
      { 0, 3, 3, 3, 3 },
      { 1, 3, 3, 3, 3 },
      { 3, 3, "E", 3, 3 },
      { 1, 3, 3, 3, 3 },
      { 0, 3, 3, 3, 3 },
      { 0, 0, 1, 3, 3 },
    },
    -- B : orbe à yeux satellites (anneau de regards)
    {
      { 0, 0, 1, 3, 3 },
      { 0, 1, 3, 3, 3 },
      { 1, 3, "E", 3, 3 },
      { 3, "E", 3, "E", 3 },
      { 1, 3, "E", 3, 3 },
      { 0, 1, 3, 3, 3 },
      { 0, 0, 1, 3, 3 },
    },
    -- C : orbe haut / ovale (pupille + œil sommital)
    {
      { 0, 0, 0, 3, 3 },
      { 0, 0, 3, 3, 3 },
      { 0, 1, 3, "E", 3 },
      { 1, 3, "E", 3, 3 },
      { 3, 3, "E", 3, 3 },
      { 1, 3, 3, 3, 3 },
      { 0, 0, 3, 3, 3 },
    },
  } },
}

function M.get(skeleton)
  return M[skeleton] or M.humanoid
end

return M
