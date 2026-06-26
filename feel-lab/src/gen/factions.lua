-- src/gen/factions.lua
-- DATA PURE (zéro love.*) : profil de génération par faction. Décrit la SILHOUETTE (gabarit de
-- squelette), les RAMPES de palette, l'ASYMÉTRIE eldritch et les ACCENTS. Lu par creaturegen.lua.
--
-- Mapping (verrouillé par le créateur) :
--   flesh = humanoïde trapu, peau P/p/d + sang R/r, symétrique
--   order = humanoïde haut, fer I/i/A/a + or Y/y/T, symétrique
--   bone  = décharné, os S/s + contour F + bleu C, symétrique (fissures légères)
--   arcane= ROBE (sans legs), violet V/v/X/x + magenta M + bleu C, bâton vertical, asym moyenne
--   abyss = DIFFORME (sans weapon, armFront=griffe), brun D/O/o + sang R/H + vert E/G, asym forte
--
-- VARIÉTÉ INTRA-FACTION : `ramps` = LISTE de sous-rampes de la même famille (le générateur en pioche
-- une par RNG seedé). Chaque sous-rampe = { c1(clair)..c4(sombre) } ∈ palette.lua. La faction reste
-- reconnaissable (même famille chromatique) mais deux unités ont des teintes distinctes.
--
-- skeleton : "humanoid" | "robe" | "deformed".
-- outline : K partout ; F = contour adouci pour l'os.
-- accent  : couleur d'œil/détail par défaut (surchargée par l'effet de l'unité, cf. ramps.lua).
-- asym    : 0..1 = probabilité d'excroissances asymétriques (corne/tentacule/œil surnuméraire).

local F = {}

F.flesh = {
  skeleton = "humanoid",
  outline  = "K",
  ramps    = {
    { "P", "P", "p", "d" }, -- chair pâle
    { "P", "p", "p", "d" }, -- chair burinée (plus sombre)
    { "R", "p", "p", "d" }, -- chair sanguine (rougeoyante)
  },
  shade    = "d",
  accent   = "R",
  trim     = "L",
  asym     = 0.10, -- petites marques tolérées (cicatrice/encoche), pas de difformité lourde
  weapon   = "blade",
  details  = { "scar", "eye" },
}

F.order = {
  skeleton = "humanoid",
  outline  = "K",
  ramps    = {
    { "I", "I", "i", "a" }, -- fer clair
    { "A", "i", "i", "a" }, -- acier terne
    { "I", "i", "a", "a" }, -- plates noircies
  },
  shade    = "a",
  accent   = "T",
  trim     = "Y",
  asym     = 0.08,
  weapon   = "mace",
  details  = { "cross", "eye" },
}

F.bone = {
  skeleton = "humanoid",
  outline  = "F",
  ramps    = {
    { "S", "S", "s", "s" }, -- os propre
    { "S", "s", "s", "N" }, -- os crasseux (terre/N)
    { "I", "S", "s", "s" }, -- os blanchi (froid)
  },
  shade    = "s",
  accent   = "C",
  trim     = "s",
  asym     = 0.18, -- fissures, dents manquantes
  weapon   = "blade",
  details  = { "cavity", "eye", "scar" }, -- fêlures + lueur d'orbite + entaille
}

F.arcane = {
  skeleton = "robe",
  outline  = "K",
  ramps    = {
    { "V", "V", "v", "x" }, -- violet froid
    { "M", "V", "v", "x" }, -- violet-magenta (chaud)
    { "V", "v", "x", "x" }, -- violet ténébreux (sombre)
  },
  shade    = "x",
  accent   = "C",
  trim     = "M",
  asym     = 0.45,
  weapon   = "staff",
  details  = { "rune", "eye" },
}

F.abyss = {
  skeleton = "deformed",
  outline  = "K",
  ramps    = {
    { "O", "D", "o", "o" }, -- braise (brun ardent)
    { "R", "D", "H", "H" }, -- sang (rougeoyant sombre)
    { "E", "G", "g", "g" }, -- bile (vert maladif)
  },
  shade    = "o",
  accent   = "T",
  trim     = "R",
  asym     = 0.85,
  weapon   = nil,
  details  = { "horn", "tentacle", "eye" },
}

-- Repli si une faction inconnue est demandée : on traite comme flesh (humanoïde lisible).
function F.get(type)
  return F[type] or F.flesh
end

return F
