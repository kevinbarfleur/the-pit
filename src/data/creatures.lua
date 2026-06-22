-- src/data/creatures.lua
-- (TABLE VIDE depuis le rollout « ALL IN » du 2026-06-22.)
--
-- Les 6 créatures DESSINÉES MAIN (marauder/skeleton/templar/bandit/witch/demon) ont été RETIRÉES : tout le
-- roster passe désormais par le GÉNÉRATEUR PAR PRIMITIVES v3 (src/gen/primgen.lua), résolu via le POINT DE
-- BASCULE UNIQUE `CreatureGen.cached` (cf. src/gen/creaturegen.lua). Les scènes (build/gallery/Grimoire) et le
-- render de combat (src/render/arena_draw.lua) font toutes `Creatures[id] or CreatureGen.cached(...)` :
-- avec cette table VIDE, `Creatures[id]` est toujours nil -> 100% des unités sont générées (les 6 comprises).
--
-- L'art authored d'origine est archivé tel quel dans `src/data/creatures_legacy.lua.bak` (HORS build : non
-- requis, non scanné par luacheck). Pour réintroduire une créature dessinée main : recopier sa def ici
-- (clé = id de l'unité) -> elle reprend la priorité sur le générateur dans toutes les scènes.

return {}
