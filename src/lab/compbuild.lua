-- src/lab/compbuild.lua
-- BUILDER FIDÈLE : une composition (data, cf. src/data/compositions) -> une compo d'ARÈNE avec les AURAS
-- d'adjacence RÉSOLUES. C'est le pont du banc d'essai vers le combat.
--
-- ⚠️ RENDER-tainted : ce module CONSTRUIT un Build (une scène). Il est donc HORS firewall SIM — ne jamais
-- le require depuis src/combat|board|effects|run. Il réutilise `Build:buildComp`, le SEUL builder qui
-- résout les auras d'adjacence via le graphe du sigil (un builder naïf (col,row)->stats les sauterait et
-- MENTIRAIT sur les compos à aura). tools/sim.lua prouve que Build tourne headless (tests/mock_love).
--
-- PERF : construire un Build est lourd (rigs, ambient). Build UNE fois par composition ; ne JAMAIS
-- appeler dans une boucle de seeds (l'arène ne mute pas la compo -> on réutilise le résultat sur N matchs).

local Palette = require("src.core.palette")
local Build = require("src.scenes.build")

local Compbuild = {}

local STUB_HOST = { goto = function() end } -- Build.new exige un host avec goto ; inerte en headless.

-- Construit un Build headless avec la compo posée sur son sigil (slots 1..boardLevel débloqués = fidèle
-- au vrai plateau à ce niveau). Renvoie le Build (utile pour lire board/slots côté preview).
-- opts.commander : id d'unité-commandant (porteur de commandBonus) à poser au PIÉDESTAL -> son aura est
--   BUILD-RÉSOLUE par buildComp comme en jeu (team/role/tier/level/grant_team), via STUB_HOST sans run
--   (commanderUnlocked() -> true en sandbox). C'est la voie FIDÈLE : on ne ré-implémente pas resolveCommanderAura.
function Compbuild.build(comp, opts)
  local palette = (opts and opts.palette) or Palette
  local b = Build.new(palette, 320, 180, STUB_HOST)
  b.board:setShape(comp.sigil)
  b:computeLayout()
  b.board:unlock(comp.boardLevel or 9)
  for _, u in ipairs(comp.units) do
    b:placeId(u.slot, u.id, u.level or 1)
  end
  local cmd = (opts and opts.commander) or comp.commander
  if cmd then b.commanderSlot = { id = cmd, level = (opts and opts.commanderLevel) or comp.commanderLevel or 1 } end
  return b
end

-- Compo d'arène prête (auras résolues, stats×niveau, positions front/back). side : -1 gauche / 1 droite.
-- Reliques : si la compo en déclare (ou opts.relics), on applique leur effet RÉEL à la compo résolue (au
-- build, comme le run). opts.commander : pose un commandant au piédestal (cf. Compbuild.build).
function Compbuild.toComp(comp, side, opts)
  local b = Compbuild.build(comp, opts)
  local arenaComp = b:buildComp(side or -1)
  local relics = (opts and opts.relics) or comp.relics
  if relics and #relics > 0 then
    local Relics = require("src.data.relics")
    for _, rid in ipairs(relics) do
      if Relics[rid] then Relics.apply(arenaComp, Relics[rid]) end
    end
  end
  return arenaComp
end

return Compbuild
