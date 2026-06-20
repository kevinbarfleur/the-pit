-- src/i18n/en.lua
-- Locale ANGLAISE (langue par défaut & fallback). Table PLATE clé -> chaîne. Tout le texte affiché du
-- jeu vit ici. Ajouter une langue = copier ce fichier en `src/i18n/<code>.lua` et traduire les valeurs
-- (garder les clés et les marqueurs {name} ; ils sont réordonnables). Chaînes en ASCII (police LÖVE).
--
-- Conventions de clés : ui.* (chrome/HUD/boutons), scene.* (titres), result.*, runover.*, type.*,
-- shape.<sigil>.{label,archetype}, encounter.<key>.name, unit.<id>.{name,passive_name,passive_desc}.

return {
  -- meta
  ["ui.empty"] = "",

  -- chrome / HUD
  ["ui.title"] = "THE PIT",
  ["ui.quit"] = "[esc] quit",
  ["ui.fps"] = "FPS {n}",
  ["scene.build"] = "build",
  ["scene.combat"] = "combat",
  ["scene.runover"] = "run over",
  ["ui.hint_build"] = "[click-drag] buy/place  -  REROLL/LEVEL  -  [s] sigil  -  FIGHT",
  ["ui.hint_combat"] = "auto-battle in progress...",
  ["ui.hint_combat_end"] = "[click] back to build   [r] replay",
  ["ui.hint_runover"] = "[click] new run   -   [r] new run",

  -- build / shop
  ["ui.fight"] = "FIGHT",
  ["ui.reroll"] = "REROLL {n}g",
  ["ui.level_up"] = "LEVEL {n}g",
  ["ui.level_max"] = "MAX LEVEL",
  ["ui.cost"] = "{n}g",
  ["ui.hud"] = "GOLD {gold}    LIVES {lives}/{maxlives}    WINS {wins}/{target}    ROUND {round}    LEVEL {level} ({slots}/{maxslots} slots)",
  ["ui.win_streak"] = "WIN STREAK x{n}",
  ["ui.loss_streak"] = "LOSS STREAK x{n}",
  ["ui.placed_count"] = "{placed} placed  -  {active}/9 slots",
  ["ui.sigil_header"] = "{label}  -  {archetype}",

  -- tooltip
  ["ui.unit_header"] = "{name}  ({type})",
  ["ui.unit_stats"] = "HP {hp}    DMG {dmg}    CD {cd}",

  -- combat
  ["ui.vs"] = "vs  {name}",
  ["result.victory"] = "VICTORY",
  ["result.defeat"] = "DEFEAT",

  -- run over
  ["runover.win"] = "ASCENSION",
  ["runover.lose"] = "THE PIT KEEPS YOU",
  ["runover.stats"] = "{wins} wins  -  {losses} losses  -  {rounds} rounds  -  level {level}",

  -- unit types (clé mécanique -> libellé affiché)
  ["type.flesh"] = "Flesh",
  ["type.order"] = "Order",
  ["type.bone"] = "Bone",
  ["type.arcane"] = "Arcane",
  ["type.abyss"] = "Abyss",

  -- sigils (formes de plateau)
  ["shape.carre.label"] = "Novice's Square",
  ["shape.carre.archetype"] = "versatile",
  ["shape.croix.label"] = "Cross Sigil",
  ["shape.croix.archetype"] = "mono-carry",
  ["shape.anneau.label"] = "Ring Sigil",
  ["shape.anneau.archetype"] = "chain",
  ["shape.diamant.label"] = "Diamond Sigil",
  ["shape.diamant.archetype"] = "go-wide",
  ["shape.ligne.label"] = "Conduit Sigil",
  ["shape.ligne.archetype"] = "conduit",

  -- encounters (IA de seed)
  ["encounter.fallen_patrol.name"] = "FALLEN PATROL",
  ["encounter.drowned_choir.name"] = "DROWNED CHOIR",
  ["encounter.brood.name"] = "BROOD",

  -- units : nom + passif (nom & description). Mécanique = src/data/units.lua (effects).
  ["unit.marauder.name"] = "MARAUDER",
  ["unit.marauder.passive_name"] = "Brutality",
  ["unit.marauder.passive_desc"] = "+8 damage on its first strike of the fight.",
  ["unit.templar.name"] = "TEMPLAR",
  ["unit.templar.passive_name"] = "Bulwark",
  ["unit.templar.passive_desc"] = "Combat start: +14 shield to adjacent neighbors.",
  ["unit.skeleton.name"] = "SKELETON",
  ["unit.skeleton.passive_name"] = "Broken Bones",
  ["unit.skeleton.passive_desc"] = "Returns 3 damage to each attacker that strikes it.",
  ["unit.bandit.name"] = "BANDIT",
  ["unit.bandit.passive_name"] = "Nimble",
  ["unit.bandit.passive_desc"] = "Fast cadence (short cooldown). No notable passive.",
  ["unit.witch.name"] = "WITCH",
  ["unit.witch.passive_name"] = "Venom",
  ["unit.witch.passive_desc"] = "Its strikes poison: 2 dmg/s for 3s.",
  ["unit.demon.name"] = "DEMON",
  ["unit.demon.passive_name"] = "Leech",
  ["unit.demon.passive_desc"] = "Heals for 50% of damage dealt.",
}
