-- src/gen/rarity.lua
-- DATA PURE (zéro love.*) : RANG de rareté (1..5) -> leviers VISUELS bornés & déterministes.
-- Le rang relit le `cost` d'une unité (R1=cost 1 chaff .. R5=cost 5 légendaire). Il ne touche JAMAIS
-- la SIM (firewall) : seulement l'échelle/ornement/glow/cadre côté génération+render.
--
-- Principe (recherche pixel-art + design) : la rareté se lit d'abord au CADRE (couleur/pips, façon
-- TFT/Hearthstone BG), puis au sprite (échelle + ornement + glow). Puissance DÉCOUPLÉE de la rareté.
-- Bornes : échelle plafonnée (~+35% h) pour ne pas masquer les voisins / casser le plateau 3×3.

local R = {}

-- scale    : facteur d'échelle du sprite au render (root). Quantifié, modeste.
-- ornament : nb d'excroissances « couronne » stampées au sommet (cornes/épines) -> prestance générative.
-- glow     : alpha d'un halo additif derrière le sprite (rangs hauts « rayonnent »). 0 = aucun.
local LEVELS = {
  [1] = { scale = 1.00, ornament = 0, glow = 0.00 },
  [2] = { scale = 1.00, ornament = 0, glow = 0.00 },
  [3] = { scale = 1.08, ornament = 1, glow = 0.00 },
  [4] = { scale = 1.18, ornament = 2, glow = 0.32 },
  [5] = { scale = 1.32, ornament = 3, glow = 0.55 },
}

-- Couleur de CADRE par rang (palette « Wraeclast » désaturée, floats 0..1). Canal primaire de rareté.
-- R1 cendre -> R2 bile -> R3 froid -> R4 sigil -> R5 or malsain. Sert aussi de teinte de glow.
local FRAME = {
  [1] = { 0.42, 0.40, 0.36 },
  [2] = { 0.40, 0.52, 0.34 },
  [3] = { 0.40, 0.60, 0.66 },
  [4] = { 0.55, 0.40, 0.66 },
  [5] = { 0.80, 0.62, 0.28 },
}

local function clamp(rank) return math.max(1, math.min(5, rank or 1)) end
R.clamp = clamp

function R.get(rank) return LEVELS[clamp(rank)] end
function R.frame(rank) return FRAME[clamp(rank)] end

-- ── TIER (rareté lisible par l'UI) : SOURCE UNIQUE couleur + nom. La couleur EST le cadre (FRAME) ; le nom
-- vit en i18n (Pit-caste, choix user 2026-06) -> R.tierNameKey donne la clé, le render fait T(key). Variantes
-- de couleur DÉRIVÉES (pures, floats 0..1) pour tag/pastille/glow, afin que tout l'UI parle la même rareté.
function R.tierNameKey(rank) return "tier." .. clamp(rank) .. ".name" end
function R.tierColor(rank) return FRAME[clamp(rank)] end
-- teinte assombrie (fond de tag / pastille discrète) : ~moitié de la couleur de cadre.
function R.tierDim(rank) local f = FRAME[clamp(rank)]; return { f[1] * 0.42, f[2] * 0.42, f[3] * 0.42 } end
-- teinte avivée (texte de tag / liseré de focus) : remonte la luminance sans cramer (clamp à 1).
function R.tierBright(rank)
  local f = FRAME[clamp(rank)]
  return { math.min(1, f[1] * 1.30 + 0.10), math.min(1, f[2] * 1.30 + 0.10), math.min(1, f[3] * 1.30 + 0.10) }
end

return R
