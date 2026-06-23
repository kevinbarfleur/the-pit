-- tests/chronicle.lua
-- Modèle du JOURNAL (src/render/chronicle.lua) : agrégation des ticks de DoT en LIGNES VIVANTES,
-- entrées discrètes (frappe/propagation/mort), filtrage par type ET par équipe. Aucune love.graphics.

require("tests.mock_love") -- stub love (i18n/fonts) pour le headless

local Bus = require("src.core.bus")
local Chronicle = require("src.render.chronicle")

-- Faux arène minimal : le modèle ne lit que `bus` + l'horloge `t`.
local arena = { bus = Bus.new(), t = 0 }
local chron = Chronicle.new(arena)

local witch = { id = "witch", team = "left" }    -- joueur
local demon = { id = "demon", team = "right" }   -- adverse
local ghoul = { id = "skeleton", team = "right" } -- adverse (voisin)

-- 1) Pose de poison + 3 ticks -> UNE ligne vivante, total agrégé (jamais 4 entrées).
arena.t = 30;  arena.bus:emit("affliction_applied", { target = demon, source = witch, family = "poison", dps = 2, dur = 180, stacks = 1 })
arena.t = 60;  arena.bus:emit("damage", { target = demon, source = witch, cause = "poison", raw = 2, hp = 2 })
arena.t = 90;  arena.bus:emit("damage", { target = demon, source = witch, cause = "poison", raw = 2, hp = 2 })
arena.t = 120; arena.bus:emit("damage", { target = demon, source = witch, cause = "poison", raw = 2, hp = 2 })

-- 2) Une frappe = une entrée discrète.
arena.t = 130; arena.bus:emit("damage", { target = demon, source = witch, cause = "attack", raw = 10, hp = 10 })

-- 3) Réapplication de poison -> PAS de nouvelle entrée (refresh de la ligne vivante).
arena.t = 140; arena.bus:emit("affliction_applied", { target = demon, source = witch, family = "poison", dps = 2, dur = 180, stacks = 2 })

-- 4) Propagation (par l'adverse) + mort de la cible.
arena.t = 150; arena.bus:emit("spread", { from = demon, to = ghoul, family = "poison", magnitude = 4 })
arena.t = 160; arena.bus:emit("death", demon)

-- Vérifs structurelles
local nAff, nStrike, nSpread, nDeath, poison = 0, 0, 0, 0, nil
for _, e in ipairs(chron.entries) do
  if e.kind == "affliction" then nAff = nAff + 1; if e.family == "poison" then poison = e end
  elseif e.kind == "strike" then nStrike = nStrike + 1
  elseif e.kind == "spread" then nSpread = nSpread + 1
  elseif e.kind == "death" then nDeath = nDeath + 1 end
end
assert(nAff == 1, "une seule ligne vivante de poison (refresh != duplication), vu " .. nAff)
assert(poison.total == 6, "ticks agrégés 2+2+2 = 6, vu " .. tostring(poison.total))
assert(poison.killed, "la ligne se ferme à la mort de la cible")
assert(nStrike == 1 and nSpread == 1 and nDeath == 1, "frappe/propagation/mort = 1 chacune")

-- 5) Segments : non vides + l'acteur porte son équipe (pour la coloration au rendu).
local seg = chron:segments(poison)
assert(#seg >= 2, "segments non vides")
assert(seg[1].role == "actor" and seg[1].team == "left", "1er segment = acteur, équipe joueur")

-- 6) Filtrage combiné type ET équipe.
assert(#chron:visible({ affliction = true }, nil) == 1, "filtre type=afflictions -> 1")
assert(#chron:visible(nil, "left") == 2, "actions du JOUEUR (pose poison + frappe) -> 2")
assert(#chron:visible(nil, "right") == 2, "actions de l'ADVERSE (propagation + mort) -> 2")

print("=> CHRONICLE OK : agrégation lignes vivantes + entrées discrètes + filtrage type/équipe.")
