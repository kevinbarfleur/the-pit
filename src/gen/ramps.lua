-- src/gen/ramps.lua
-- DATA PURE (zéro love.*) : colorisation par GRADIENT VERTICAL sur une rampe de palette.
-- Idée (Sprites-as-a-Service / Slynyrd) : haut de la silhouette = clair, bas = sombre.
-- On reçoit une rampe ordonnée clair->sombre (4 crans) et on choisit le cran selon la
-- position verticale RELATIVE (0 = haut, 1 = bas) de la cellule dans la bbox pleine de la part.
--
-- Le but n'est PAS un dégradé lisse (illisible à 16px) mais 3-4 bandes franches : un pixel-art
-- propre a peu de valeurs par zone. On ajoute un léger ombrage de bord (shade) côté intérieur.

local R = {}

-- ramp = { c1(clair), c2, c3, c4(sombre) } ; y01 ∈ [0,1] (0 = haut de la part).
-- Renvoie le caractère de palette du body pour cette hauteur.
function R.bodyChar(ramp, y01)
  -- 4 bandes : [0,0.22)=highlight, [0.22,0.55)=clair, [0.55,0.82)=moyen, [0.82,1]=sombre.
  if y01 < 0.22 then return ramp[1] end
  if y01 < 0.55 then return ramp[2] end
  if y01 < 0.82 then return ramp[3] end
  return ramp[4]
end

-- Teinte des ACCENTS selon les effets de l'unité (data pure). On lit la 1re famille reconnue
-- dans la liste d'effets (ordre fixe ipairs) ; sinon on garde l'accent de faction.
--   poison->E/G, burn->O/D, bleed->R/r, rot->g/E, shock->C/B, regen->S/P
local EFFECT_ACCENT = {
  poison = { "E", "G" },
  burn   = { "O", "D" },
  bleed  = { "R", "r" },
  rot    = { "g", "E" },
  shock  = { "C", "B" },
  regen  = { "S", "P" },
}

-- effects = liste { {op=..., ...}, ... } (ou nil). fallback = caractère d'accent de la faction.
-- Renvoie { bright, dark } : 2 caractères pour l'œil/le détail (clair + ombre).
function R.accentFor(effects, fallback)
  if effects then
    for _, e in ipairs(effects) do
      local pair = e.op and EFFECT_ACCENT[e.op]
      if pair then return { pair[1], pair[2] } end
    end
  end
  return { fallback, fallback }
end

return R
