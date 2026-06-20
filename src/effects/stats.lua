-- src/effects/stats.lua
-- COUCHE DE MODIFICATEURS (SIM PURE) — la primitive qui débloque choc/poison-malus/aggro modifiables.
-- cf. docs/research/effects-amplification-modifiers.md, effects-design.md §1.A.
--
-- Une stat (dmg, valeur de bouclier, cd, aggro, dégâts-pris…) = `base` + une LISTE de `mods` empilables.
-- Formule (vérifiée PoE + Last Epoch) :
--     final = clamp( (base + Σflat) · (1 + Σincreased) · Π(1 + more) )
-- · `flat`      : ajout à plat (additif).
-- · `increased` : % qui s'ADDITIONNENT entre eux  -> COMMUTATIF -> ordre-indépendant -> DÉTERMINISME
--                 GRATUIT (aucun tri nécessaire ; on itère par index, jamais `pairs`).
-- · `more`      : % MULTIPLICATIFS (rares) -> Π(1+more).
--
-- Propriétés voulues :
-- · PUR (aucun love.*, aucun état global) -> testable headless, sérialisable.
-- · La `base` n'est JAMAIS mutée ; les mods sont des données externes -> compatible auras/snapshots.
-- · `mods == nil` (ou vide) -> renvoie `base` (éventuellement clampée/arrondie) -> GOLDEN INCHANGÉ tant
--   qu'aucun effet ne pose de mod. C'est ce qui rend l'adoption progressive sûre (ouvert/fermé).

local Stats = {}

local EMPTY = {} -- opts par défaut (lecture seule, jamais muté) -> pas d'alloc par appel

-- Constructeurs de mods (ergonomie pour les ops). Un mod = { kind, value }.
function Stats.flat(v) return { kind = "flat", value = v } end
function Stats.increased(v) return { kind = "increased", value = v } end
function Stats.more(v) return { kind = "more", value = v } end

-- Résout une stat. `mods` = ARRAY de mods (ou nil). `opts` = { min?, max?, round? = "floor"|"nearest" }.
function Stats.resolve(base, mods, opts)
  opts = opts or EMPTY
  local v = base
  if mods and #mods > 0 then
    local flat, inc, more = 0, 0, 1
    for i = 1, #mods do -- index numérique : ordre stable (déterminisme), pas de pairs
      local m = mods[i]
      local k = m.kind
      if k == "flat" then
        flat = flat + m.value
      elseif k == "increased" then
        inc = inc + m.value -- additif entre eux : commutatif
      elseif k == "more" then
        more = more * (1 + m.value) -- multiplicatif
      end
    end
    v = (base + flat) * (1 + inc) * more
  end
  if opts.min and v < opts.min then v = opts.min end
  if opts.max and v > opts.max then v = opts.max end
  local r = opts.round
  if r == "floor" then v = math.floor(v)
  elseif r == "nearest" then v = math.floor(v + 0.5) end
  return v
end

return Stats
